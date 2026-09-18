# Lakehouse Design

## Overview

The Microsoft Fabric Analytics Platform uses a schema-enabled Fabric Lakehouse as the central analytical storage layer.

The Lakehouse combines OneLake file storage with Delta-backed analytical tables and supports PySpark processing, SQL access and Direct Lake semantic modelling from the same underlying data platform.

The solution follows a medallion architecture:

`Landing → Bronze → Silver → Gold`

Each layer has a clearly defined responsibility and progressively increases the analytical quality of the data.

---

## Lakehouse

**Lakehouse:** `SmartEnergyLakehouse`

The Lakehouse contains both:

- OneLake Files for landed source data
- Delta tables organised into Bronze, Silver and Gold schemas

This allows raw source acquisition and curated analytical tables to remain within the same Fabric data platform while maintaining logical separation between processing stages.

---

## Physical Structure

The implemented structure is:

```
SmartEnergyLakehouse
│
├── Files
│   ├── landing
│   │   ├── meter_readings
│   │   │   └── Small LCL Data
│   │   │       └── 168 CSV files
│   │   └── tariffs
│   │       └── Tariffs workbook
│   │
│   ├── bronze
│   │   └── meter_readings
│   │
│   └── development
│       └── meter_readings
│
└── Tables
    ├── bronze
    │   └── meter_readings
    │
    ├── silver
    │   ├── meter_readings
    │   └── rejected_meter_readings
    │
    └── gold
        ├── dim_household
        ├── dim_date
        ├── dim_time
        ├── dim_tariff
        ├── fact_daily_consumption
        ├── fact_demand_pattern
        └── tariff_schedule
```

The `Files/bronze/meter_readings` location reflects an earlier development path and is not the authoritative Bronze analytical store. The persisted Bronze dataset is the Delta table `bronze.meter_readings`.

---

## Landing Layer

### Purpose

The Landing layer provides the initial OneLake destination for externally acquired source files.

It separates source ingestion from downstream transformation.

### Meter Readings

Location:

`Files/landing/meter_readings/Small LCL Data/`

Contains:

- 168 CSV files
- Approximately 7.96 GB extracted
- Half-hourly smart-meter readings

### Tariff Reference

Location:

`Files/landing/tariffs/`

Contains the Excel tariff schedule used for 2013 dynamic tariff-band enrichment.

### Landing Design Principle

Files are retained close to their delivered source structure.

Business validation, deduplication and analytical modelling are deliberately deferred to later layers.

---

## Development Area

Location:

`Files/development/meter_readings/`

A development sample was used before executing transformations against the full dataset.

This allowed the project to:

- Inspect the source schema
- Identify invalid numeric values
- Analyse duplicate behaviour
- Develop Silver validation rules
- Test transformation logic
- Reduce unnecessary full-scale processing during development

Once the transformation rules were validated, the same design was applied to the complete Bronze dataset.

---

## Bronze Layer

### Table

`bronze.meter_readings`

### Purpose

Bronze provides a Delta-backed representation of the complete landed meter-reading dataset.

### Grain

**One row per source smart-meter reading**

### Processing

Bronze performs limited structural processing:

- Explicit source schema
- Source column normalisation where required for Delta compatibility
- Source-file lineage
- Ingestion timestamp
- Source-system metadata

The raw consumption value is preserved without applying Silver-level quality corrections.

### Scale

**167,932,474 rows**

### Why Delta at Bronze?

Persisting Bronze as Delta provides a structured Lakehouse table for downstream PySpark processing while retaining the source-level grain.

It also avoids repeatedly parsing all 168 source CSV files for each downstream transformation.

---

## Silver Layer

Silver represents the trusted reading-level dataset.

### `silver.meter_readings`

**Grain:** one validated Household × Reading Timestamp observation

Responsibilities:

- Standardised analytical column names
- Typed timestamp
- Numeric consumption
- Non-negative consumption validation
- Household validation
- Tariff-domain validation
- Business-key deduplication
- Derived date/time attributes
- Source lineage retention

Final row count:

**167,811,461**

### `silver.rejected_meter_readings`

Contains source records that fail the Silver validation contract.

Final rejected rows:

**5,560**

All persisted rejected records were classified as:

`INVALID_CONSUMPTION`

Rejected records are retained separately rather than silently discarded.

---

## Silver Business Key

The reading-level business key is:

`HouseholdID + ReadingTimestamp`

This key was selected because a household should have a single observation for a given half-hour reading timestamp.

The full-scale transformation identified:

**115,453 duplicate business-key records**

After deduplication:

**0 duplicate business keys remain in Silver.**

---

## Silver Reconciliation

The transformation is reconciled using:

`Bronze = Silver + Rejected + Duplicates Removed`

Result:

| Component | Rows |
|---|---:|
| Bronze | 167,932,474 |
| Rejected | 5,560 |
| Duplicates removed | 115,453 |
| Silver | 167,811,461 |
| Difference | 0 |

This ensures every Bronze record is accounted for.

---

## Silver Storage Profile

The final Silver Delta table contained:

- 167,811,461 rows
- 40 Delta data files
- Approximately 1.02 GiB of data files
- No physical partitioning

The landed CSV source occupied approximately 7.96 GB.

The difference in storage footprint reflects differences in storage format, encoding and compression and should not be interpreted directly as a measured query-performance improvement.

---

## Gold Layer

Gold transforms the validated reading-level data into analytical dimensions and aggregated facts.

The design follows a star-schema approach.

---

## Gold Dimensions

### `gold.dim_household`

**Rows:** 5,561

**Grain:** one row per household

Provides:

- HouseholdKey
- HouseholdID
- TariffKey
- TariffType

A deterministic surrogate-key strategy is used for `HouseholdKey`.

---

### `gold.dim_date`

**Rows:** 829

**Grain:** one row per calendar date

Coverage:

`2011-11-23 → 2014-02-28`

Provides reusable calendar attributes for analytical filtering and grouping.

---

### `gold.dim_time`

**Rows:** 48

**Grain:** one row per half-hour time slot

Represents:

`00:00 → 23:30`

Provides:

- TimeKey
- TimeLabel
- Hour
- Minute
- HalfHourSlot
- TimeBand

---

### `gold.dim_tariff`

**Rows:** 2

Represents:

- Standard (`Std`)
- Time-of-Use (`ToU`)

This dimension represents the household tariff classification and should not be confused with the dynamic High, Normal and Low tariff schedule.

---

## Gold Daily Consumption Fact

### Table

`gold.fact_daily_consumption`

### Grain

**Household × Date**

### Rows

**3,510,403**

### Measures Stored at Fact Grain

- DailyConsumptionKWh
- AverageHalfHourlyKWh
- PeakHalfHourlyKWh
- MinimumHalfHourlyKWh
- ReadingCount
- ExpectedReadingCount
- IsCompleteDay

### Dimension Keys

- HouseholdKey
- DateKey
- TariffKey

### Completeness

A complete household-day contains exactly:

**48 half-hour readings**

Results:

| Status | Household-Days |
|---|---:|
| Complete | 3,469,352 |
| Partial | 41,051 |

Complete:

**98.83%**

Partial days remain in the analytical model and are explicitly identified rather than removed.

---

## Gold Demand Pattern Fact

### Table

`gold.fact_demand_pattern`

### Grain

**Date × Half-Hour Time Slot × Tariff**

### Rows

**79,454**

### Analytical Fields

- TotalConsumptionKWh
- AverageConsumptionKWh
- PeakHouseholdConsumptionKWh
- ReadingCount
- DistinctHouseholds
- TariffBand

### Dimension Keys

- DateKey
- TimeKey
- TariffKey

This fact supports intraday demand analysis without exposing the complete Silver reading-level dataset to the semantic model.

---

## Tariff Schedule Reference

### Table

`gold.tariff_schedule`

### Grain

**Date × Half-Hour Time Slot**

### Rows

**17,520**

The table represents the complete 2013 dynamic tariff schedule:

`365 days × 48 half-hour periods = 17,520`

Band distribution:

| Tariff Band | Periods |
|---|---:|
| Normal | 15,072 |
| Low | 1,660 |
| High | 788 |

The schedule is used to enrich `gold.fact_demand_pattern`.

Periods outside the 2013 schedule are represented in the fact as:

`Not Applicable`

The reference table itself is not exposed directly to the semantic model.

---

## Why Two Gold Facts?

The reporting requirements operate at two substantially different analytical grains.

### Household Analysis

Household and daily trend analysis requires:

`Household × Date`

This is provided by `fact_daily_consumption`.

### Demand Analysis

Intraday demand analysis requires:

`Date × Half-Hour × Tariff`

This is provided by `fact_demand_pattern`.

Trying to support both requirements through a single fact would either retain unnecessary reading-level volume or create an unsuitable grain for one of the analytical use cases.

The two-fact design therefore aligns physical Gold modelling with the actual reporting requirements.

---

## Why Not Expose Silver Directly?

Silver contains more than 167 million reading-level records.

The Power BI report does not require household-level half-hour readings for every analytical page.

Aggregating into purpose-built Gold facts provides:

- Explicit analytical grains
- Smaller semantic-model inputs
- Simpler relationships
- Clearer measure behaviour
- Separation between engineering and reporting datasets

Silver remains available for engineering validation and future analytical requirements without becoming the default reporting interface.

---

## Why Lakehouse?

A Fabric Lakehouse was selected because the solution is centred on:

- Large file-based source ingestion
- PySpark transformation
- Delta-backed medallion tables
- OneLake storage
- SQL access to curated tables
- Direct Lake semantic modelling

This allows engineering and BI workloads to operate over the same Fabric-managed analytical storage.

A separate SQL database was therefore not required for this implementation.

---

## Partitioning Decision

The Silver table was not physically partitioned.

Partitioning was not introduced solely for architectural appearance because the project did not establish a workload-specific requirement that justified a partitioning strategy.

Instead, the solution uses purpose-built Gold aggregations to reduce the amount of reading-level data required by downstream analytics.

In a production workload, partitioning and table-maintenance decisions would be evaluated against actual ingestion patterns, query predicates, file sizes and operational performance measurements.

---

## Gold Validation

Before semantic modelling, Gold was validated for:

- Dimension-key uniqueness
- Missing dimension references
- Fact-grain duplicates
- Consumption reconciliation
- Daily completeness

Results:

- **0** duplicate dimension keys
- **0** missing dimension references
- **0** duplicate fact-grain keys
- Consumption reconciled to Silver with negligible floating-point variance

---

## Design Summary

The Lakehouse design progressively converts raw source files into trusted analytical structures:

`Landing`

Source-file preservation

↓

`Bronze`

Delta-backed source representation

↓

`Silver`

Validated, typed and deduplicated reading-level data

↓

`Gold`

Conformed dimensions and purpose-built analytical facts

This structure provides a clear separation between ingestion, data engineering and business-facing analytics while keeping all stages within Microsoft Fabric and OneLake.