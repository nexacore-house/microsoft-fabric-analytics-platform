# Semantic Model

## Overview

The Microsoft Fabric Analytics Platform uses a Direct Lake semantic model built over the curated Gold layer of `SmartEnergyLakehouse`.

The semantic model provides the reusable analytical layer between the Fabric Lakehouse and the Power BI report.

It contains:

- 4 dimensions
- 2 fact tables
- 6 active one-to-many relationships
- Reusable DAX measures
- Business-friendly formatting and field organisation

Bronze and Silver tables are deliberately excluded from the reporting model.

---

## Model Architecture

The semantic model contains six tables:

### Dimensions

- Date
- Time
- Tariff
- Household

### Facts

- Daily Consumption
- Demand Pattern

Conceptually:

```text
                    ┌─────────────┐
                    │  Household  │
                    └──────┬──────┘
                           │
                           ▼
                    ┌───────────────┐
              ┌────►│     Daily     │◄────┐
              │     │  Consumption  │     │
              │     └───────────────┘     │
              │                           │
         ┌────┴────┐                 ┌────┴────┐
         │  Date   │                 │ Tariff  │
         └────┬────┘                 └────┬────┘
              │                           │
              │     ┌───────────────┐     │
              └────►│    Demand     │◄────┘
                    │    Pattern    │
                    └───────▲───────┘
                            │
                       ┌────┴────┐
                       │  Time   │
                       └─────────┘
```

The model follows a star-schema approach with shared Date and Tariff dimensions across the relevant facts.

---

# Dimension Tables

## Date

Source:

`gold.dim_date`

Purpose:

- Calendar filtering
- Trend analysis
- Annual analysis
- Monthly analysis
- Weekday/weekend analysis

The Date dimension filters both analytical facts.

Relationships:

`Date[DateKey] → Daily Consumption[DateKey]`

`Date[DateKey] → Demand Pattern[DateKey]`

---

## Time

Source:

`gold.dim_time`

Purpose:

- Half-hour demand analysis
- Intraday profiles
- Time-of-day analysis

The Time dimension applies only to the Demand Pattern fact.

Relationship:

`Time[TimeKey] → Demand Pattern[TimeKey]`

This is intentional because the Daily Consumption fact has already been aggregated above half-hour grain.

---

## Tariff

Source:

`gold.dim_tariff`

Purpose:

- Standard versus Time-of-Use analysis
- Shared tariff filtering across both facts

Relationships:

`Tariff[TariffKey] → Daily Consumption[TariffKey]`

`Tariff[TariffKey] → Demand Pattern[TariffKey]`

Tariff contains the household tariff classification:

- `Std`
- `ToU`

It does not represent the dynamic High, Normal and Low tariff schedule.

---

## Household

Source:

`gold.dim_household`

Purpose:

- Household selection
- Household-level exploration
- Portfolio comparison

Relationship:

`Household[HouseholdKey] → Daily Consumption[HouseholdKey]`

Household does not connect to Demand Pattern because the Demand Pattern fact is aggregated across households.

---

# Fact Tables

## Daily Consumption

Source:

`gold.fact_daily_consumption`

Grain:

**Household × Date**

Rows:

**3,510,403**

Used for:

- Total consumption
- Average household daily consumption
- Active households
- Household trends
- Weekday/weekend behaviour
- Household benchmarking
- Daily completeness

This is the primary fact for household and daily analysis.

---

## Demand Pattern

Source:

`gold.fact_demand_pattern`

Grain:

**Date × Half-Hour Time Slot × Tariff**

Rows:

**79,454**

Used for:

- 48-slot daily demand profiles
- Intraday consumption analysis
- Standard vs Time-of-Use comparison
- Dynamic tariff-band analysis
- Demand-response observations

This fact contains the enriched `TariffBand` attribute used for the 2013 High, Normal and Low analysis.

---

# Relationships

The model contains exactly six active relationships.

| From | To | Cardinality | Filter Direction |
|---|---|---|---|
| Date | Daily Consumption | 1:* | Single |
| Date | Demand Pattern | 1:* | Single |
| Household | Daily Consumption | 1:* | Single |
| Tariff | Daily Consumption | 1:* | Single |
| Tariff | Demand Pattern | 1:* | Single |
| Time | Demand Pattern | 1:* | Single |

All relationships filter from dimensions to facts.

No bidirectional relationships are required.

---

# Why There Is No Tariff-to-Household Relationship

`dim_household` contains tariff information originating from the validated data, but the semantic model does not require a direct:

`Tariff → Household`

relationship.

Tariff filtering of analytical measures occurs through the fact tables.

Adding another active relationship between Tariff and Household could introduce an unnecessary alternative filter path around the Daily Consumption fact.

The model therefore retains the simpler star-schema filtering structure.

---

# Why Bronze and Silver Are Excluded

Bronze contains approximately:

**167.93 million rows**

Silver contains approximately:

**167.81 million rows**

These tables serve engineering and validation purposes and are not required directly by the Power BI analytical experience.

The semantic model uses purpose-built Gold tables instead.

This provides:

- Clear business-facing grains
- Fewer exposed technical fields
- Simpler relationships
- Smaller analytical tables
- Centralised business logic
- Separation between engineering and reporting concerns

---

# Why `tariff_schedule` Is Excluded

`gold.tariff_schedule` is a Gold reference table used during engineering enrichment.

Its High, Normal and Low classification has already been incorporated into:

`gold.fact_demand_pattern[TariffBand]`

The report therefore does not need to expose the reference table separately.

This keeps the semantic model focused on fields required by report consumers.

---

# Direct Lake

The semantic model uses Direct Lake over the Fabric Lakehouse Gold tables.

The architecture is:

`Gold Delta Tables → Direct Lake Semantic Model → Power BI`

The SQL Analytics Endpoint is available alongside the semantic model for SQL validation and exploration, but it is not an intermediate reporting transformation layer.

---

# Measure Design

Measures are designed according to the grain of the underlying fact.

A measure should use the fact that correctly represents the analytical question.

---

## Daily Consumption Measures

Daily and household measures use the Daily Consumption fact.

Examples include:

- Total Consumption
- Household Days
- Average Daily Consumption
- Active Households
- Complete Household Days
- Incomplete Household Days
- Complete Day %
- Peak Household Daily Consumption

Conceptually:

```text
Total Consumption
=
SUM(Daily Consumption[DailyConsumptionKWh])
```

and:

```text
Average Daily Consumption
=
Total Consumption / Household Days
```

This preserves the Household × Date grain of the fact.

---

# Demand Measures

Intraday measures use the Demand Pattern fact.

A critical design consideration is the calculation of average consumption.

The Demand Pattern table is already aggregated.

Therefore, taking:

```text
AVERAGE(Demand Pattern[AverageConsumptionKWh])
```

across multiple fact rows could create an unweighted average of pre-aggregated averages.

Instead, the semantic model calculates the weighted result conceptually as:

```text
SUM(Demand Pattern[TotalConsumptionKWh])
/
SUM(Demand Pattern[ReadingCount])
```

This preserves the contribution of the underlying readings.

---

# Fact-Specific Measures

Some business concepts exist at more than one analytical grain.

For example, consumption can be analysed:

- Daily by household
- Half-hourly by tariff

The semantic model therefore uses fact-appropriate measures rather than attempting to force all calculations through one fact table.

This is especially important when Time or TariffBand filters are involved because those attributes apply to the Demand Pattern fact rather than the Daily Consumption fact.

---

# Household Benchmarking

The Household Explorer compares the selected household against the overall portfolio.

The selected household measure responds to the Household slicer.

The portfolio benchmark deliberately removes the Household filter while retaining other applicable report context.

Conceptually:

```text
Portfolio Average
=
CALCULATE(
    [Avg Daily Consumption],
    REMOVEFILTERS(Household)
)
```

This allows a selected household to be compared with the wider population under the relevant report context.

---

# Defensive Household Selection

Selected-household measures use a single-household check such as:

`HASONEVALUE(Household[HouseholdID])`

This prevents a household-specific KPI from returning a misleading value if multiple households are selected.

The report itself uses a single-select Household slicer, but the measure logic remains defensive.

---

# Dynamic Tariff Analysis

Dynamic tariff-band analysis uses:

`Demand Pattern[TariffBand]`

Values include:

- High
- Normal
- Low
- Not Applicable

The High, Normal and Low schedule applies to 2013.

The lower tariff-study section of the Demand & Tariff Analysis page is intentionally fixed to the appropriate 2013 analytical context rather than being affected by every exploratory slicer on the page.

This separates:

- Exploratory demand analysis
- Fixed 2013 tariff comparison

within the same report page.

---

# Field Parameters

The Energy Consumption Overview uses a field parameter to allow the user to switch the trend visual between analytical perspectives such as:

- Total Consumption
- Average Daily Consumption
- Active Households

This provides controlled metric switching without duplicating multiple trend visuals.

---

# Model Usability

Technical keys are hidden from normal report consumption where appropriate.

Display fields are used for slicers and visual axes, while key columns remain available for relationships.

Examples include:

- Date labels instead of DateKey
- TimeLabel instead of TimeKey
- TariffType instead of TariffKey
- HouseholdID instead of HouseholdKey

Sort settings are configured where necessary to maintain chronological ordering.

---

# Semantic Model QA

The semantic model was functionally validated through the Power BI report.

Testing covered:

- Date filtering
- Tariff filtering
- Household single selection
- Half-hour demand filtering
- Field-parameter switching
- Reset bookmarks
- Household benchmarking
- Tariff-band analysis
- Report-page tooltip behaviour
- Page navigation

All four report pages passed final functional QA before the report was frozen for portfolio documentation.

---

# Reporting Pages

The semantic model supports four report pages.

## 1. Energy Consumption Overview

Provides:

- Overall energy KPIs
- Data coverage
- Consumption trend
- Tariff mix
- Weekday/weekend behaviour

## 2. Demand & Tariff Analysis

Provides:

- 48-slot demand profile
- Standard vs ToU comparison
- 2013 High / Normal / Low analysis
- Demand-response observations

## 3. Household Explorer

Provides:

- Individual household selection
- Household consumption journey
- Weekday/weekend behaviour
- Portfolio benchmark comparison

## 4. Data Quality & Pipeline Observability

Provides:

- Medallion pipeline volumes
- Rejected records
- Duplicate removals
- Daily completeness
- Gold model integrity
- Reconciliation status

---

# Design Summary

The semantic model intentionally exposes only the curated analytical structures required by Power BI.

The design separates two analytical grains:

`Household × Date`

and:

`Date × Half-Hour × Tariff`

Shared conformed dimensions provide consistent filtering, while fact-specific measures preserve the meaning of each grain.

The final reporting path is:

`Fabric Lakehouse Gold → Direct Lake Semantic Model → Thin Power BI Report`

This keeps data engineering logic in the Lakehouse, reusable analytical logic in the semantic model and presentation logic in the Power BI report.