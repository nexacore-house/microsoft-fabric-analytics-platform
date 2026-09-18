# Solution Architecture

## Architecture Overview

The Microsoft Fabric Analytics Platform implements a medallion architecture for processing large-scale smart-meter electricity consumption data.

The solution combines Microsoft Fabric Data Factory, OneLake, Lakehouse, PySpark, Delta tables, the SQL Analytics Endpoint, a Direct Lake semantic model and Power BI.

The implemented flow is:

`London Datastore → Data Factory → OneLake Landing → Bronze → Silver → Gold`

From the Gold layer, the architecture supports two downstream consumption paths:

- **SQL Analytics Endpoint** — validation and analytical exploration
- **Direct Lake Semantic Model → Power BI** — governed reporting and interactive analysis

---

## Solution Architecture Diagram

![Microsoft Fabric Analytics Platform Architecture](../architecture/fabric-analytics-architecture.png)

---

## 1. Source Layer

### London Datastore

The source is the London Smart Meter dataset published through the London Datastore.

The project uses:

- Partitioned smart-meter CSV files
- A separate Excel tariff reference workbook

The partitioned archive provides the large-scale meter-reading workload, while the tariff workbook provides the dynamic 2013 High, Normal and Low tariff schedule.

### Source Characteristics

- 168 smart-meter CSV files
- Approximately 7.96 GB extracted
- 167,932,474 source readings processed
- Half-hourly electricity consumption
- Standard (`Std`) and Time-of-Use (`ToU`) households

---

## 2. Ingestion Layer

### Fabric Data Factory

A Microsoft Fabric Data Factory pipeline named:

`SmartEnergyIngestion`

is used to ingest the public source files.

The pipeline copies the source archive from HTTP into the Fabric Lakehouse landing area.

The tariff workbook is also ingested as reference data.

### Why Data Factory?

Data Factory separates source acquisition from transformation logic.

This allows the architecture to maintain a clear boundary between:

1. External source retrieval
2. Raw data landing
3. Lakehouse transformation

The ingestion pipeline therefore focuses on movement of source data rather than analytical transformation.

---

## 3. OneLake Landing Zone

The extracted source files are retained in the Lakehouse Files area before transformation.

Example structure:

`Files/landing/meter_readings/`

`Files/landing/tariffs/`

The landing zone preserves the source files at their original practical grain and provides a recoverable starting point for downstream processing.

No business-level cleaning is performed in the landing zone.

---

## 4. Bronze Layer

### Table

`bronze.meter_readings`

The Bronze layer converts the landed CSV dataset into a Delta-backed Lakehouse table.

### Bronze Responsibilities

Bronze performs only the minimum structural processing required to persist the source safely:

- Apply an explicit raw schema
- Normalise the source consumption column name for Delta compatibility
- Preserve the raw consumption value
- Add source-file lineage
- Add ingestion metadata
- Persist the complete dataset as Delta

### Lineage Metadata

Bronze includes:

- `SourceFilePath`
- `SourceFileName`
- `IngestionTimestamp`
- `SourceSystem`

### Bronze Scale

**167,932,474 records**

Bronze intentionally retains source-quality issues. Validation and business-level cleaning are performed in Silver.

---

## 5. Silver Layer

### Tables

`silver.meter_readings`

`silver.rejected_meter_readings`

The Silver layer creates the validated analytical representation of the smart-meter readings.

### Silver Responsibilities

PySpark transformations:

- Standardise column names
- Parse timestamps
- Convert consumption to numeric form
- Validate household identifiers
- Validate tariff values
- Reject invalid consumption
- Reject negative consumption
- Detect duplicate business keys
- Remove duplicate readings
- Derive reusable date/time attributes
- Preserve rejected records for audit

### Business Key

`HouseholdID + ReadingTimestamp`

### Reconciliation

The full transformation produced:

| Outcome | Rows |
|---|---:|
| Bronze | 167,932,474 |
| Rejected | 5,560 |
| Duplicates removed | 115,453 |
| Silver | 167,811,461 |
| Unaccounted difference | 0 |

This reconciliation provides an auditable transition from Bronze to Silver.

---

## 6. Gold Layer

The Gold layer converts the validated reading-level dataset into a dimensional analytical model.

### Dimensions

- `gold.dim_household`
- `gold.dim_date`
- `gold.dim_time`
- `gold.dim_tariff`

### Analytical Facts

#### Daily Consumption

`gold.fact_daily_consumption`

**Grain:** Household × Date

**Rows:** 3,510,403

Designed for:

- Household analysis
- Daily consumption
- Trend analysis
- Completeness monitoring
- Weekday/weekend behaviour
- Portfolio benchmarking

#### Demand Pattern

`gold.fact_demand_pattern`

**Grain:** Date × Half-Hour Time Slot × Tariff

**Rows:** 79,454

Designed for:

- Intraday demand profiles
- Half-hour consumption analysis
- Standard vs Time-of-Use comparisons
- Dynamic tariff-band analysis

### Reference Table

`gold.tariff_schedule`

The tariff schedule contains the validated 2013 dynamic High, Normal and Low half-hour tariff classifications.

It is used to enrich the Demand Pattern fact but is not exposed directly to the reporting semantic model.

---

## 7. Why Aggregate the Gold Facts?

The Silver layer contains more than 167 million reading-level records.

The reporting requirements do not require every individual reading to be exposed directly to Power BI.

Instead, Gold introduces analytical grains aligned with the reporting use cases.

This provides:

- Clear fact-table grains
- Smaller analytical datasets
- Simpler semantic modelling
- Reduced unnecessary reading-level detail
- Reusable business measures

The design is therefore driven by analytical requirements rather than exposing the entire Silver dataset simply because it is available.

---

## 8. SQL Analytics Endpoint

The Fabric Lakehouse SQL Analytics Endpoint provides a relational SQL interface over the persisted Delta tables.

In this project SQL is used for:

- Gold model validation
- Data-quality validation
- Consumption analysis
- Tariff analysis
- Demand-pattern exploration
- Reconciliation checks

SQL is **not** used as an intermediate transformation layer between Gold and the semantic model.

The transformation path remains:

`Landing → Bronze → Silver → Gold`

with PySpark responsible for the main engineering transformations.

---

## 9. Direct Lake Semantic Model

The curated Gold model is exposed through a Direct Lake semantic model.

The semantic model contains:

### Dimensions

- Date
- Time
- Tariff
- Household

### Facts

- Daily Consumption
- Demand Pattern

Six active one-to-many relationships connect the dimensions to the appropriate facts.

The model deliberately excludes Bronze and Silver tables from the reporting layer.

The tariff schedule reference is also excluded because its analytical attributes have already been incorporated into the Demand Pattern fact.

---

## 10. Power BI Reporting Layer

A thin Power BI report connects to the Fabric semantic model.

The report contains four analytical pages:

1. Energy Consumption Overview
2. Demand & Tariff Analysis
3. Household Explorer
4. Data Quality & Pipeline Observability

This separates report presentation from the underlying analytical model and allows the Fabric semantic model to remain the reusable source of business logic.

---

## 11. Technology Responsibilities

| Technology | Responsibility |
|---|---|
| London Datastore | Public source data |
| Fabric Data Factory | Source ingestion |
| OneLake | Centralised Fabric storage |
| Lakehouse | Data organisation and Delta tables |
| PySpark | Profiling, validation, transformation and aggregation |
| Delta | Bronze, Silver and Gold table storage |
| SQL Analytics Endpoint | Validation and analytical exploration |
| Direct Lake Semantic Model | Reusable analytical model |
| Power BI | Interactive reporting |

---

## 12. Architecture Principles

The implementation follows several design principles.

### Separation of Responsibilities

Ingestion, transformation, validation, modelling and reporting are treated as separate concerns.

### Data Quality Before Reporting

Invalid and duplicate records are addressed before Gold modelling.

### Auditability

Rejected records are retained and transformation counts are reconciled.

### Fit-for-Purpose Grain

Gold facts are designed around analytical requirements rather than simply reproducing the Silver grain.

### Reusable Semantic Layer

Business measures and relationships are centralised in the semantic model rather than duplicated across report pages.

### Transparent Analytical Limitations

Tariff comparisons are treated as observational and do not imply that pricing caused differences in household behaviour.

---

## Architecture Summary

The final architecture is:

`Public Source`

↓

`Fabric Data Factory`

↓

`OneLake Landing`

↓

`Bronze Delta`

↓

`Silver Validated Delta`

↓

`Gold Dimensional Model`

From Gold:

`Gold → SQL Analytics Endpoint → Validation / Exploration`

and:

`Gold → Direct Lake Semantic Model → Power BI`

This design demonstrates an end-to-end Microsoft Fabric analytical workflow while maintaining clear boundaries between ingestion, engineering, validation, semantic modelling and reporting.