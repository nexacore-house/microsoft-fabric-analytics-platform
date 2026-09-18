# Technical Decisions

## Overview

This document records the principal architecture, data engineering and analytical modelling decisions made during the Microsoft Fabric Analytics Platform project.

The purpose is to make the reasoning behind the implementation explicit rather than presenting the final architecture without context.

The project was designed as a portfolio implementation using a large public smart-meter dataset. Decisions were based on the analytical requirements, characteristics of the source data and capabilities available within Microsoft Fabric.

---

# 1. Fabric Lakehouse as the Core Data Platform

## Decision

Use a Microsoft Fabric Lakehouse as the central storage and processing platform.

## Alternatives Considered

A separate SQL database or warehouse layer was considered as an additional analytical storage component.

## Reasoning

The workload is primarily:

- File-based
- Large-scale
- PySpark-oriented
- Delta-backed
- Analytical rather than transactional

The Lakehouse supports:

- OneLake storage
- PySpark processing
- Delta tables
- SQL Analytics Endpoint access
- Direct Lake semantic modelling

This allows the medallion architecture and reporting model to operate over the same Fabric-managed analytical storage.

## Outcome

A separate SQL database was not required for the implemented architecture.

SQL remains an important validation and exploration interface through the Lakehouse SQL Analytics Endpoint.

---

# 2. Separate Landing from Bronze

## Decision

Use a dedicated OneLake Landing area before Bronze processing.

Architecture:

`Source → Landing → Bronze`

rather than treating the incoming source files themselves as the final Bronze analytical table.

## Reasoning

Landing and Bronze have different responsibilities.

### Landing

Responsible for:

- Receiving external files
- Preserving delivered source data
- Separating ingestion from transformation

### Bronze

Responsible for:

- Applying an explicit structural schema
- Converting the source into Delta
- Adding lineage metadata
- Providing a stable input for downstream transformations

This separation creates a clearer boundary between file acquisition and analytical processing.

---

# 3. Use Fabric Data Factory for Source Ingestion

## Decision

Use the Fabric Data Factory pipeline `SmartEnergyIngestion` for external HTTP ingestion.

## Reasoning

Source retrieval is an orchestration concern rather than a business-transformation concern.

Using a pipeline separates:

`Data movement`

from:

`Data transformation`

The pipeline therefore handles source acquisition while notebooks handle profiling, validation and modelling.

This also demonstrates multiple Fabric workload components within a coherent architecture rather than implementing every stage inside notebooks.

---

# 4. Use PySpark for the Main Transformation Pipeline

## Decision

Use PySpark for Bronze, Silver and Gold engineering transformations.

## Reasoning

The complete Bronze dataset contains:

**167,932,474 records**

The transformation requirements include:

- Schema handling
- Type conversion
- Data-quality rules
- Rejected-record routing
- Window-based deduplication
- Derived attributes
- Large-scale aggregation
- Dimension construction
- Fact construction
- Reconciliation

PySpark provides a natural distributed processing interface for these operations within Fabric Lakehouse notebooks.

## SQL Role

SQL was deliberately retained for:

- Validation
- Exploration
- Analytical queries
- Independent inspection of persisted tables

The project therefore demonstrates both PySpark and SQL without unnecessarily duplicating the same transformation logic in both technologies.

---

# 5. Develop Transformation Rules on a Sample First

## Decision

Profile and develop Silver rules using a 1,000,000-row development sample before processing the complete dataset.

## Reasoning

Repeatedly processing more than 167 million rows while still discovering source-data behaviour would be inefficient.

Development profiling identified:

- 688 duplicate business-key records
- 29 invalid numeric consumption records
- Source values that were not Spark nulls but failed numeric conversion
- The expected half-hour reading structure

These findings directly informed the Silver validation contract.

## Outcome

Transformation logic was tested at development scale before being applied to the complete Bronze dataset.

---

# 6. Preserve Raw Consumption in Bronze

## Decision

Retain the source consumption value as:

`ConsumptionKWhRaw`

in Bronze rather than immediately replacing it with a numeric value.

## Reasoning

Bronze should preserve source fidelity.

Invalid numeric source values were a known data-quality characteristic.

Converting or replacing those values too early would reduce the ability to distinguish:

- Original source value
- Parsing outcome
- Silver validation result

Numeric conversion therefore occurs as part of the Silver validation process.

---

# 7. Do Not Treat Invalid Consumption as Zero

## Decision

Reject invalid/non-numeric consumption rather than replacing it with `0`.

## Reasoning

Zero is a valid electricity-consumption value.

Replacing an invalid reading with zero would transform an unknown or malformed source value into a valid analytical observation.

That would change the meaning of the data.

## Outcome

Invalid consumption records are assigned:

`INVALID_CONSUMPTION`

and retained in the rejected-record dataset.

---

# 8. Preserve Rejected Records

## Decision

Persist invalid records in:

`silver.rejected_meter_readings`

rather than simply filtering them out.

## Reasoning

Discarding invalid records would make the transformation harder to audit.

Persisting them supports:

- Rejection analysis
- Record-count reconciliation
- Troubleshooting
- Transparent data-quality reporting

## Outcome

**5,560 records** were retained as rejected records.

All observed full-scale rejects were classified as:

`INVALID_CONSUMPTION`

---

# 9. Track Duplicates Separately from Rejects

## Decision

Treat duplicate business-key records separately from validation failures.

## Business Key

`HouseholdID + ReadingTimestamp`

## Reasoning

A duplicate reading is conceptually different from an invalid reading.

For example:

- Invalid consumption fails a validation rule.
- A duplicate may contain otherwise valid values but represents repeated business-key information.

Combining both conditions under a generic rejection count would reduce transparency.

## Outcome

Full processing identified:

**115,453 duplicate records removed**

while:

**5,560 invalid records**

were retained separately.

The complete Bronze-to-Silver reconciliation produced zero unaccounted records.

---

# 10. Retain Partial Household-Days

## Decision

Do not remove household-days containing fewer than 48 validated readings.

Instead, calculate:

`IsCompleteDay`

## Reasoning

Incomplete days are a genuine characteristic of the source dataset.

Removing them would:

- Reduce transparency
- Change aggregate coverage
- Hide missing-reading behaviour

Keeping them allows analysts to decide whether completeness is relevant to a particular analysis.

## Outcome

Gold contains:

- 3,469,352 complete household-days
- 41,051 partial household-days

Overall completeness:

**98.83%**

---

# 11. Use Two Gold Fact Tables

## Decision

Create two purpose-built analytical facts instead of exposing one universal reading-level fact.

### Daily Consumption

Grain:

`Household × Date`

### Demand Pattern

Grain:

`Date × Half-Hour × Tariff`

## Reasoning

The analytical requirements operate at different grains.

Household analysis requires household identity but does not require every half-hour reading.

Demand analysis requires half-hour detail but can be aggregated across individual households.

Using separate facts provides appropriate grains for both workloads.

## Outcome

Silver:

**167,811,461 rows**

becomes:

- Daily Consumption: **3,510,403 rows**
- Demand Pattern: **79,454 rows**

without removing the underlying Silver dataset from the Lakehouse.

---

# 12. Do Not Expose Silver Directly to Power BI

## Decision

Use curated Gold tables as the semantic-model source.

## Reasoning

The Power BI requirements do not require direct interactive access to all 167.8 million Silver readings.

Gold provides:

- Business-oriented grains
- Conformed dimensions
- Reduced technical complexity
- Smaller analytical structures
- Clearer semantic relationships

Silver remains available for engineering and future analytical requirements.

---

# 13. Use a Star-Schema Semantic Model

## Decision

Build the reporting model around four dimensions and two facts.

Dimensions:

- Date
- Time
- Tariff
- Household

Facts:

- Daily Consumption
- Demand Pattern

## Reasoning

The dimensional model provides clear analytical grains and predictable filtering behaviour.

Relationships use:

- One-to-many cardinality
- Single-direction dimension-to-fact filtering

No bidirectional relationships were required.

---

# 14. No Direct Tariff-to-Household Relationship

## Decision

Do not add an active semantic relationship between Tariff and Household.

## Reasoning

Tariff already filters analytical results through the fact tables.

Adding another relationship could create an unnecessary alternative filter path around Daily Consumption.

The model therefore maintains the simpler star-schema structure.

---

# 15. Use Direct Lake for the Semantic Model

## Decision

Build the Power BI semantic model using Direct Lake over the Gold Lakehouse tables.

## Architecture

`Gold Delta Tables → Direct Lake Semantic Model → Power BI`

## Reasoning

The Gold datasets already reside in Fabric-managed Delta storage and are designed specifically for reporting.

Direct Lake provides a natural Fabric-native serving path without introducing a separate imported copy solely for the portfolio report.

---

# 16. Keep SQL Endpoint Outside the Reporting Transformation Path

## Decision

Use the SQL Analytics Endpoint for validation and exploration, but not as an intermediate transformation layer between Gold and Power BI.

## Reasoning

The main engineering pipeline is already:

`Landing → Bronze → Silver → Gold`

with PySpark responsible for transformations.

The semantic model can consume the Gold Lakehouse tables through Direct Lake.

Therefore the SQL Endpoint does not need to become an artificial additional processing stage simply to demonstrate SQL.

## Outcome

SQL has a clear and meaningful role:

- Gold validation
- Data-quality checks
- Consumption analysis
- Demand analysis
- Tariff analysis

---

# 17. Use Weighted Demand Averages

## Decision

When aggregating Demand Pattern fact rows, calculate average consumption using:

`SUM(TotalConsumptionKWh) / SUM(ReadingCount)`

rather than:

`AVG(AverageConsumptionKWh)`

## Reasoning

Each Demand Pattern row can represent a different number of underlying household readings.

Taking a simple average of pre-aggregated averages would give each fact row equal weight regardless of its underlying observation count.

The weighted calculation preserves the contribution of the original readings.

---

# 18. Enrich Demand Fact with Tariff Band

## Decision

Incorporate the dynamic tariff classification into:

`gold.fact_demand_pattern`

rather than requiring the semantic model to expose `gold.tariff_schedule`.

## Reasoning

The tariff schedule is an engineering reference dataset.

The report requires the resulting classification:

- High
- Normal
- Low

but does not need the reference table itself.

Enriching the Demand Pattern fact simplifies the reporting model.

Periods outside the 2013 schedule are represented as:

`Not Applicable`

---

# 19. Restrict Dynamic Tariff Analysis to 2013

## Decision

Use High, Normal and Low dynamic tariff analysis only for calendar year 2013.

## Reasoning

The supplied tariff workbook covers:

`2013-01-01 00:00 → 2013-12-31 23:30`

It contains exactly:

**17,520 half-hour periods**

The smart-meter readings span a wider period, but applying the 2013 tariff schedule to other years would not be supported by the supplied reference data.

---

# 20. Do Not Hard-Code Tariff Prices into Gold

## Decision

Do not add High, Normal and Low tariff prices to the Gold model.

## Reasoning

The supplied `Tariffs.xlsx` workbook contains the dynamic band schedule but does not contain the tariff rates themselves.

Although tariff rates are described in external source documentation, introducing them into the analytical model would mix separately documented information with the supplied reference dataset.

The implemented Gold enrichment therefore remains limited to the schedule classification actually contained in the workbook.

---

# 21. Treat Tariff Results as Observational

## Decision

Do not claim that Time-of-Use pricing caused changes in electricity consumption.

## Observed Result

During 2013, ToU households recorded lower average half-hour consumption than Standard households across all three dynamic tariff bands.

The approximate differences were:

| Band | ToU vs Std |
|---|---:|
| High | -12.5% |
| Normal | -8.5% |
| Low | -3.4% |

## Limitation

The dataset is observational.

Differences could also reflect:

- Household characteristics
- Trial participant selection
- Time-of-day usage patterns
- Behaviour existing before tariff assignment
- Other unobserved factors

The report therefore presents the measured association without claiming causal impact.

---

# 22. Do Not Interpret Partial Years as Full-Year Trends

## Decision

Treat 2011 and 2014 as partial observation periods.

## Reasoning

Dataset coverage is:

`2011-11-23 → 2014-02-28`

Therefore:

- 2011 contains only the end of the year
- 2014 contains only the beginning of the year

Raw annual totals for those years are not directly comparable with the complete 2012 and 2013 periods.

This limitation is retained in SQL analysis and project documentation.

---

# 23. Do Not Add Partitioning Without Evidence

## Decision

Do not physically partition Silver simply to demonstrate partitioning.

## Reasoning

Partitioning should be based on actual:

- Query patterns
- Data distribution
- Ingestion strategy
- File characteristics
- Measured performance

The project did not establish sufficient workload evidence to justify a specific partitioning design.

Gold aggregation already substantially reduces the reading-level volume required for reporting.

## Production Consideration

A production implementation would benchmark representative workloads before selecting partition columns or maintenance strategies.

---

# 24. Do Not Claim Storage Reduction as Query Performance

## Observation

The landed CSV source occupies approximately:

**7.96 GB**

The Silver Delta data files occupy approximately:

**1.02 GiB**

## Decision

Do not describe this difference as a measured query-performance improvement.

## Reasoning

The formats use different:

- Encoding
- Compression
- Physical representation
- Metadata structures

A smaller storage footprint does not by itself prove a specific query-performance gain.

Performance claims require workload benchmarking.

---

# 25. Keep the Power BI Report Thin

## Decision

Use a thin Power BI report connected to the Fabric semantic model.

## Reasoning

The architecture separates responsibilities:

### Lakehouse

Data engineering and Gold modelling

### Semantic Model

Relationships and reusable analytical measures

### Power BI Report

Visual presentation and interaction

This avoids embedding core business logic independently into the report file.

---

# 26. Surface Data Quality in the Report

## Decision

Include a dedicated:

**Data Quality & Pipeline Observability**

page.

## Reasoning

Data quality should not be visible only to the engineer who built the pipeline.

Surfacing:

- Bronze volume
- Silver volume
- Rejected records
- Duplicate removals
- Completeness
- Gold integrity
- Reconciliation

makes the analytical pipeline more transparent to report reviewers.

---

# 27. Keep the Full Dataset Out of GitHub

## Decision

Do not publish the complete source dataset in the repository.

## Reasoning

The extracted source contains:

- 168 CSV files
- Approximately 7.96 GB
- 167.9 million records

The original dataset is publicly accessible from its publisher.

Duplicating the entire dataset inside GitHub would add significant repository size without improving the reproducibility of the project.

## Repository Approach

The repository contains:

- Source instructions
- A small representative sample
- PySpark notebooks
- SQL scripts
- Architecture documentation
- Power BI screenshots

---

# 28. Treat the Project as a Portfolio Implementation

## Decision

Describe the solution accurately as an end-to-end Microsoft Fabric analytics implementation rather than as a production energy platform.

## Reasoning

The project demonstrates substantial engineering capabilities, including processing more than 167 million source records.

However, a production implementation would require additional areas such as:

- Identity and access design
- Environment separation
- CI/CD
- Deployment pipelines
- Operational alerting
- Service-level objectives
- Cost monitoring
- Data governance
- Disaster recovery
- Production source-system integration

Avoiding unsupported production claims makes the portfolio evidence stronger and more credible.

---

# Decision Summary

The final architecture reflects several consistent principles:

- Use each Fabric component for a clear purpose
- Separate ingestion from transformation
- Preserve source fidelity before validation
- Never silently discard invalid data
- Reconcile transformation outcomes
- Model Gold around analytical requirements
- Keep engineering tables out of the reporting model
- Use SQL where it adds genuine validation value
- Avoid unnecessary optimisation claims
- Distinguish observed relationships from causal conclusions
- Document limitations alongside technical achievements

The result is an end-to-end Fabric architecture that demonstrates ingestion, large-scale PySpark processing, medallion modelling, data quality, SQL validation, Direct Lake semantic modelling and Power BI reporting without adding components solely for architectural complexity.