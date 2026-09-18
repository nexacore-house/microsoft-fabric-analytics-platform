# Data Dictionary

## Overview

This data dictionary documents the principal tables and fields used in the Microsoft Fabric Analytics Platform.

The platform follows a medallion architecture:

`Bronze → Silver → Gold`

Bronze preserves source-level data and lineage, Silver provides validated reading-level data, and Gold provides dimensional structures designed for analytics and Power BI.

---

# Bronze Layer

## `bronze.meter_readings`

**Grain:** One row per source smart-meter reading

**Row count:** 167,932,474

The Bronze table preserves the source-level meter readings while adding ingestion and lineage metadata.

| Column | Type | Description |
|---|---|---|
| LCLid | String | Pseudonymous household identifier from the source dataset |
| stdorToU | String | Source household tariff classification: `Std` or `ToU` |
| DateTime | String | Raw source reading timestamp |
| ConsumptionKWhRaw | String | Raw half-hour consumption value preserved from the source |
| SourceFilePath | String | Path of the source file processed by Fabric |
| SourceFileName | String | Name of the source CSV file |
| IngestionTimestamp | Timestamp | Timestamp associated with Bronze ingestion |
| SourceSystem | String | Source-system identifier |

The source consumption column was normalised to `ConsumptionKWhRaw` for Delta compatibility while retaining the original value.

---

# Silver Layer

## `silver.meter_readings`

**Grain:** One validated household reading per timestamp

**Business key:** `HouseholdID + ReadingTimestamp`

**Row count:** 167,811,461

The Silver table contains validated, typed and deduplicated smart-meter readings.

| Column | Type | Description |
|---|---|---|
| HouseholdID | String | Standardised pseudonymous household identifier |
| TariffType | String | Household tariff classification: `Std` or `ToU` |
| ReadingTimestamp | Timestamp | Parsed smart-meter reading timestamp |
| ConsumptionKWh | Double | Validated electricity consumption for the half-hour reading |
| ReadingDate | Date | Calendar date derived from the reading timestamp |
| ReadingYear | Integer | Calendar year |
| ReadingMonth | Integer | Calendar month number |
| ReadingDay | Integer | Day of month |
| ReadingHour | Integer | Hour of day |
| DayOfWeek | String | Day-of-week label |
| SourceFileName | String | Source CSV filename retained for lineage |
| IngestionTimestamp | Timestamp | Ingestion metadata retained from Bronze |
| SourceSystem | String | Source-system identifier |

### Validation Rules

A Silver record must satisfy the implemented validation contract:

- Household identifier is present
- Timestamp can be parsed
- Consumption is numeric
- Consumption is non-negative
- Tariff type is `Std` or `ToU`
- Household + Timestamp business key is unique after deduplication

---

## `silver.rejected_meter_readings`

**Purpose:** Preserve records that fail the Silver validation contract.

**Row count:** 5,560

The rejected dataset retains invalid source records for audit rather than silently discarding them.

It contains the relevant source fields together with a rejection reason assigned during Silver processing.

### Rejection Reason Precedence

The transformation supports:

1. `MISSING_HOUSEHOLD`
2. `INVALID_TIMESTAMP`
3. `INVALID_CONSUMPTION`
4. `INVALID_TARIFF`

For the full processed dataset, all 5,560 rejected records were classified as:

`INVALID_CONSUMPTION`

Duplicate records are tracked separately from validation rejects.

---

# Gold Layer

## `gold.dim_household`

**Grain:** One row per household

**Row count:** 5,561

| Column | Description |
|---|---|
| HouseholdKey | Surrogate key used by the Gold model |
| HouseholdID | Pseudonymous source household identifier |
| TariffKey | Key linking the household to its tariff classification |
| TariffType | Household tariff classification (`Std` or `ToU`) |

`HouseholdKey` is generated deterministically during Gold dimension construction.

Each household in the validated dataset belongs to one tariff type.

---

## `gold.dim_date`

**Grain:** One row per calendar date

**Row count:** 829

**Coverage:** 23 November 2011 to 28 February 2014

The dimension provides reusable calendar attributes for trend, annual and weekday/weekend analysis.

Important fields include:

| Column | Description |
|---|---|
| DateKey | Integer date key used by Gold facts |
| Date | Calendar date |
| Year | Calendar year |
| Month | Calendar month number |
| MonthName | Calendar month name |
| Day | Day of month |
| DayOfWeek | Day-of-week label |
| DayOfWeekNumber | Numeric weekday ordering attribute |

Additional calendar attributes may be included in the physical dimension for reporting and sorting.

---

## `gold.dim_time`

**Grain:** One row per half-hour time slot

**Row count:** 48

**Coverage:** `00:00` to `23:30`

| Column | Description |
|---|---|
| TimeKey | Numeric key representing the half-hour slot |
| TimeLabel | Display label for the half-hour period |
| Hour | Hour of day |
| Minute | Minute component (`0` or `30`) |
| HalfHourSlot | Sequential half-hour slot |
| TimeBand | General time-of-day grouping |

Example TimeKey values include:

`0, 30, 100, 130, ... 2300, 2330`

---

## `gold.dim_tariff`

**Grain:** One row per household tariff type

**Row count:** 2

| Column | Description |
|---|---|
| TariffKey | Surrogate/key value used by Gold facts |
| TariffType | `Std` or `ToU` |

The two values represent:

- `Std` — Standard tariff household
- `ToU` — Time-of-Use tariff household

This household classification is different from the dynamic High, Normal and Low tariff schedule.

---

# Gold Fact Tables

## `gold.fact_daily_consumption`

**Grain:** One row per Household × Date

**Row count:** 3,510,403

**Business grain key:** `HouseholdKey + DateKey`

| Column | Description |
|---|---|
| HouseholdKey | Foreign key to `dim_household` |
| DateKey | Foreign key to `dim_date` |
| TariffKey | Foreign key to `dim_tariff` |
| DailyConsumptionKWh | Total household electricity consumption for the date |
| AverageHalfHourlyKWh | Average consumption across available half-hour readings |
| PeakHalfHourlyKWh | Maximum half-hour consumption recorded during the household-day |
| MinimumHalfHourlyKWh | Minimum half-hour consumption recorded during the household-day |
| ReadingCount | Number of validated readings contributing to the household-day |
| ExpectedReadingCount | Expected number of half-hour readings for a complete day |
| IsCompleteDay | Indicates whether the household-day contains the expected 48 readings |

### Completeness

`ExpectedReadingCount = 48`

A household-day with 48 validated half-hour readings is classified as complete.

Observed results:

| Status | Rows |
|---|---:|
| Complete | 3,469,352 |
| Partial | 41,051 |

Overall complete household-days:

**98.83%**

---

## `gold.fact_demand_pattern`

**Grain:** One row per Date × Half-Hour Time Slot × Tariff Type

**Row count:** 79,454

**Business grain key:** `DateKey + TimeKey + TariffKey`

| Column | Description |
|---|---|
| DateKey | Foreign key to `dim_date` |
| TimeKey | Foreign key to `dim_time` |
| TariffKey | Foreign key to `dim_tariff` |
| TotalConsumptionKWh | Total consumption for the fact grain |
| AverageConsumptionKWh | Average household consumption represented by the aggregated row |
| PeakHouseholdConsumptionKWh | Highest household reading represented by the fact row |
| ReadingCount | Number of underlying validated readings |
| DistinctHouseholds | Number of households represented |
| TariffBand | Dynamic tariff-band classification where available |

### Weighted Average Requirement

When aggregating multiple Demand Pattern rows, average consumption should be calculated using:

`SUM(TotalConsumptionKWh) / SUM(ReadingCount)`

rather than taking an unweighted average of `AverageConsumptionKWh`.

This preserves the weighting of the underlying household readings.

---

# Tariff Reference

## `gold.tariff_schedule`

**Grain:** One row per Date × Half-Hour Time Slot for 2013

**Row count:** 17,520

| Column | Description |
|---|---|
| TariffDateTime | Original tariff schedule timestamp |
| DateKey | Date key used for enrichment |
| TimeKey | Half-hour time key used for enrichment |
| TariffBand | Dynamic tariff classification: `High`, `Normal` or `Low` |

The table contains:

| Tariff Band | Half-Hour Periods |
|---|---:|
| Normal | 15,072 |
| Low | 1,660 |
| High | 788 |
| **Total** | **17,520** |

The schedule covers the full 2013 calendar year:

`365 × 48 = 17,520 half-hour periods`

---

# Tariff Terminology

Two different tariff concepts are used in the model.

## Household Tariff Type

Stored in `dim_tariff`:

- `Std`
- `ToU`

This describes the tariff group assigned to a household.

## Dynamic Tariff Band

Stored in the enriched Demand Pattern fact:

- `High`
- `Normal`
- `Low`
- `Not Applicable`

High, Normal and Low describe the dynamic tariff schedule for 2013.

`Not Applicable` represents demand periods outside the supplied 2013 tariff schedule.

These concepts should not be used interchangeably.

---

# Model Relationships

The reporting semantic model uses six active one-to-many relationships:

| Dimension | Fact | Key |
|---|---|---|
| Date | Daily Consumption | DateKey |
| Date | Demand Pattern | DateKey |
| Household | Daily Consumption | HouseholdKey |
| Tariff | Daily Consumption | TariffKey |
| Tariff | Demand Pattern | TariffKey |
| Time | Demand Pattern | TimeKey |

Relationships use single-direction filtering from dimensions to facts.

There is intentionally no direct Tariff → Household relationship in the semantic model.

---

# Data Quality Summary

The final curated model achieved:

- 0 duplicate Silver business keys
- 0 invalid Silver consumption rows
- 0 invalid Silver tariff rows
- 0 missing Gold dimension keys
- 0 duplicate Gold fact-grain keys
- 98.83% complete household-days
- Silver and Gold consumption totals reconciled within negligible floating-point aggregation variance

This dictionary documents the analytical structures used by the project while the accompanying notebooks contain the detailed PySpark implementation and validation logic.