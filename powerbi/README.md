# Power BI Report

## Overview

The Power BI report is the presentation layer of the Microsoft Fabric Analytics Platform.

It is implemented as a thin report connected to the curated Microsoft Fabric semantic model.

The reporting architecture is:

`Fabric Lakehouse Gold → Direct Lake Semantic Model → Power BI Report`

The report does not connect directly to the Bronze or Silver engineering layers.

---

## Report Architecture

The reporting solution separates responsibilities across three layers.

### Fabric Lakehouse

Responsible for:

- Data ingestion outputs
- Bronze processing
- Silver validation
- Gold dimensional modelling
- Analytical aggregations

### Semantic Model

Responsible for:

- Relationships
- Reusable DAX measures
- Analytical filtering
- Business logic
- Field organisation

### Power BI Report

Responsible for:

- Visualisation
- Navigation
- User interaction
- Analytical presentation

This keeps the report lightweight and avoids duplicating core analytical logic inside individual report pages.

---

## Semantic Model

The report uses six Gold-backed semantic-model tables.

### Dimensions

- Date
- Time
- Tariff
- Household

### Facts

- Daily Consumption
- Demand Pattern

The semantic model uses Direct Lake over the Fabric Lakehouse Gold tables.

Further model documentation is available in:

`../docs/semantic-model.md`

---

# Report Pages

The report contains four visible analytical pages.

---

## 1. Energy Consumption Overview

![Energy Consumption Overview](screenshots/01_energy-overview.png)

### Purpose

Provide an executive-level view of overall electricity consumption, household activity and data coverage.

### Key Metrics

- Total consumption: approximately 35.54M kWh
- Active households: 5,561
- Average daily household consumption: approximately 10.12 kWh
- Complete household-days: 98.83%
- Complete household-days: approximately 3.47M
- Incomplete household-days: approximately 41.05K

### Analysis

The page includes:

- Consumption trend
- Metric switching
- Standard vs Time-of-Use tariff mix
- Weekday vs weekend consumption behaviour
- Year filtering
- Tariff filtering
- Reset functionality

A field parameter allows the trend visual to switch between analytical measures such as:

- Total Consumption
- Average Daily Consumption
- Active Households

A report-page tooltip provides additional monthly consumption context.

---

## 2. Demand & Tariff Analysis

![Demand & Tariff Analysis](screenshots/02_demand-tariff.png)

### Purpose

Analyse intraday electricity demand and compare Standard and Time-of-Use household behaviour.

### Daily Demand Profile

The report presents electricity consumption across:

**48 half-hour time slots**

for Standard and Time-of-Use households.

Exploratory controls include:

- Year
- Tariff Type
- Time Band

### Dynamic Tariff Analysis

The lower section provides a fixed 2013 comparison using the supplied dynamic tariff schedule.

Average half-hour consumption:

| Band | Std | ToU | Difference |
|---|---:|---:|---:|
| High | 0.258 kWh | 0.226 kWh | -12.54% |
| Normal | 0.212 kWh | 0.194 kWh | -8.52% |
| Low | 0.216 kWh | 0.209 kWh | -3.39% |

The largest observed difference occurs during High tariff periods.

The report deliberately describes these results as observational.

It does not claim that dynamic pricing caused the consumption differences between the household groups.

---

## 3. Household Explorer

![Household Explorer](screenshots/03_household-explorer.png)

### Purpose

Allow detailed exploration of an individual household while retaining a comparison with the wider portfolio.

### Functionality

The page includes:

- Searchable single-select Household slicer
- Year filtering
- Household consumption KPIs
- Monthly consumption journey
- Weekday vs weekend behaviour
- Portfolio benchmark
- Reset functionality

### Example Household

The default household used during report QA is:

`MAC000002`

Example results:

| Metric | Result |
|---|---:|
| Household-days | 505 |
| Total consumption | ~6,095.67 kWh |
| Average daily consumption | ~12.07 kWh |
| Peak daily consumption | ~39.28 kWh |

Its average daily consumption is approximately:

**19.2% above the portfolio average**

under the corresponding report context.

The portfolio benchmark removes the selected Household filter while retaining relevant analytical context.

---

## 4. Data Quality & Pipeline Observability

![Data Quality & Pipeline Observability](screenshots/04_data-quality.png)

### Purpose

Expose key engineering and data-quality outcomes alongside the business-facing analysis.

### Pipeline Flow

The page summarises:

`Landing → Bronze → Silver → Gold`

with key volumes:

| Stage | Result |
|---|---:|
| Landing | 168 files / ~7.96 GB |
| Bronze | 167.93M records |
| Silver | 167.81M records |
| Gold Daily Fact | 3.51M rows |
| Gold Demand Fact | 79.45K rows |

### Silver Quality Outcomes

- 5,560 invalid records
- 115,453 duplicate records removed
- 0 unaccounted records

All persisted invalid records were classified as:

`INVALID_CONSUMPTION`

### Daily Completeness

- Complete: 3,469,352 household-days
- Incomplete: 41,051 household-days
- Complete rate: 98.83%

### Gold Model Integrity

- 0 missing dimension keys
- 0 duplicate fact-grain keys
- Negligible consumption reconciliation variance
- Referential integrity checks passed

---

# Interaction Design

The report includes controlled interactions appropriate to each analytical page.

Examples include:

- Year filtering
- Tariff filtering
- Household single selection
- Time-band filtering
- Field-parameter metric switching
- Reset bookmarks
- Report-page tooltip
- Page navigation

The fixed 2013 tariff study on the Demand & Tariff Analysis page is intentionally isolated from exploratory slicers where required to preserve its analytical context.

---

# Visual Design

The report uses a consistent presentation system:

- Dark navigation rail
- Light report canvas
- White analytical modules
- Consistent KPI cards
- Restrained visual hierarchy
- Consistent terminology and unit formatting

Technical and pipeline labels are separated visually from business-facing analytical content.

---

# Report QA

Functional QA was completed across all report pages.

Validation included:

- Page navigation
- Slicer behaviour
- Reset bookmarks
- Field parameter switching
- Household single selection
- Portfolio benchmarking
- Tariff-band behaviour
- Tooltip behaviour
- Measure outputs
- Visual interactions

The report was frozen for portfolio documentation after final functional QA passed.

---

# PBIX Availability

The `.pbix` file is not included in this public repository.

The report is a thin Power BI report connected to a Microsoft Fabric semantic model. Opening the PBIX outside the associated Fabric environment would not provide independent access to the underlying semantic model or Lakehouse data.

The repository therefore provides:

- Report screenshots
- Semantic-model documentation
- DAX design explanations
- PySpark notebooks
- SQL validation scripts
- Architecture documentation
- A representative source-data sample

This provides a reviewable portfolio implementation without publishing environment-specific Fabric dependencies.

---

# Screenshots

The repository includes:

```text
powerbi/screenshots/
├── 01_energy-overview.png
├── 02_demand-tariff.png
├── 03_household-explorer.png
└── 04_data-quality.png
```

These screenshots represent the final report state after functional QA.

---

# Technology

The reporting layer demonstrates:

- Microsoft Fabric
- Fabric Lakehouse
- Direct Lake
- Power BI semantic modelling
- DAX
- Star-schema modelling
- Field parameters
- Report-page tooltips
- Bookmarks
- Interactive filtering
- Thin-report architecture

---

# Summary

The Power BI report is the final analytical interface over the Fabric platform.

Rather than treating Power BI as the entire solution, the project positions reporting as the final layer of a broader architecture:

`Source → Ingestion → OneLake → Bronze → Silver → Gold → Semantic Model → Power BI`

This allows the report to focus on analysis and user experience while the underlying Fabric platform handles ingestion, transformation, data quality and analytical modelling.