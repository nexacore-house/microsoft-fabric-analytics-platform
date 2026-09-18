# Business Requirements

## Project Overview

The Microsoft Fabric Analytics Platform is an end-to-end analytics solution for analysing large-scale smart-meter electricity consumption data.

The platform processes more than 167 million half-hourly meter readings through a Microsoft Fabric medallion architecture and provides curated analytical datasets for consumption, household, demand-pattern and tariff analysis.

The project demonstrates how Microsoft Fabric can be used to ingest, transform, validate, model and analyse a large public dataset using OneLake, Lakehouse, PySpark, Delta, SQL and Power BI.

---

## Business Scenario

Energy consumption data is typically generated at a much finer grain than traditional business reporting data.

Half-hourly smart-meter readings provide valuable analytical opportunities, but the raw data presents several challenges:

- Large data volumes
- Multiple source files
- Invalid consumption values
- Duplicate meter readings
- Incomplete household-days
- Different household tariff groups
- Dynamic Time-of-Use tariff periods
- A need for both household-level and demand-pattern analysis

The solution therefore requires more than a reporting layer. It needs a structured data platform capable of transforming raw meter readings into validated and reusable analytical datasets.

---

## Business Objective

Build a scalable analytical architecture in Microsoft Fabric that converts raw smart-meter readings into trusted Gold datasets and exposes them through a semantic model for Power BI analysis.

The solution should support both business analysis and transparent data-quality monitoring.

---

## Analytical Requirements

The platform must support analysis of:

### Energy Consumption

- Total electricity consumption
- Average household daily consumption
- Consumption trends over time
- Active households
- Year and tariff comparisons

### Household Behaviour

- Individual household consumption history
- Weekday versus weekend behaviour
- Household daily consumption
- Household comparison against the wider portfolio

### Demand Patterns

- Half-hour electricity demand
- Demand variation throughout the day
- Standard versus Time-of-Use household behaviour
- Demand by time band

### Dynamic Tariff Analysis

For the 2013 tariff schedule:

- High tariff periods
- Normal tariff periods
- Low tariff periods
- Standard versus Time-of-Use consumption differences

Tariff analysis must remain observational. The platform should not infer that tariff pricing caused changes in household consumption.

---

## Data Quality Requirements

The platform must:

- Validate household identifiers
- Validate reading timestamps
- Validate numeric electricity consumption
- Reject negative consumption values
- Validate the expected `Std` / `ToU` tariff domain
- Detect duplicate Household + Timestamp business keys
- Preserve rejected records for audit
- Track duplicate removals separately
- Reconcile record counts between transformation stages
- Measure household-day completeness
- Validate Gold dimension references
- Validate fact-table grain uniqueness

---

## Data Engineering Requirements

The solution must implement:

- Automated source ingestion using Fabric Data Factory
- OneLake as the central data storage layer
- A Bronze, Silver and Gold medallion architecture
- Delta-backed Lakehouse tables
- PySpark-based transformations
- Explicit data-quality rules
- Reconciliation checks
- Dimensional Gold modelling
- Aggregated analytical fact tables
- SQL-based validation and exploration
- A reusable semantic model for Power BI

---

## Gold Model Requirements

The Gold layer must provide conformed dimensions for:

- Household
- Date
- Time
- Tariff

Two analytical fact tables are required.

### Daily Consumption Fact

**Grain:** one row per Household × Date

Used for:

- Daily consumption
- Household trends
- Portfolio benchmarks
- Completeness analysis
- Weekday/weekend behaviour

### Demand Pattern Fact

**Grain:** one row per Date × Half-Hour Time Slot × Tariff Type

Used for:

- Intraday demand profiles
- Half-hour consumption behaviour
- Standard versus Time-of-Use comparisons
- Dynamic tariff-band analysis

---

## Reporting Requirements

The Power BI solution should provide four analytical views:

1. **Energy Consumption Overview**
2. **Demand & Tariff Analysis**
3. **Household Explorer**
4. **Data Quality & Pipeline Observability**

The report should use the curated Gold model rather than directly querying raw Bronze or Silver data.

---

## Data Volume

The implemented solution processes:

| Metric | Value |
|---|---:|
| Source CSV files | 168 |
| Extracted source size | ~7.96 GB |
| Bronze records | 167,932,474 |
| Silver records | 167,811,461 |
| Rejected records | 5,560 |
| Duplicate records removed | 115,453 |
| Households | 5,561 |
| Daily Consumption fact | 3,510,403 rows |
| Demand Pattern fact | 79,454 rows |

---

## Success Criteria

The implementation is considered successful when:

- All source files are successfully ingested
- Bronze records reconcile with the source ingestion
- Invalid records are identified and retained for audit
- Duplicate readings are removed from Silver
- Silver reconciliation produces zero unaccounted records
- Gold facts contain no unresolved dimension keys
- Gold facts contain no duplicate grain keys
- Consumption totals reconcile across Silver and Gold within negligible floating-point variance
- Daily completeness is measurable
- The semantic model supports the required Power BI analysis
- Data-quality outcomes are visible alongside business analysis

---

## Scope

This project is a portfolio implementation demonstrating an end-to-end Microsoft Fabric analytics architecture using a large public dataset.

It is not presented as a production deployment for an energy supplier. Production implementation would require additional operational considerations including security design, deployment pipelines, monitoring, service-level objectives, governance, cost management and source-system integration.