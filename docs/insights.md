# Analytical Insights

## Overview

The Microsoft Fabric Analytics Platform processes 167.9 million source smart-meter readings into curated analytical datasets covering household electricity consumption, daily behaviour, intraday demand and tariff patterns.

This document summarises the principal analytical findings produced from the validated Gold model.

The findings should be interpreted within the limitations of the source data. In particular, comparisons between Standard and Time-of-Use households are observational and do not establish causal effects of tariff pricing.

---

# 1. Overall Energy Consumption

Across the validated observation period, the platform contains:

| Metric | Result |
|---|---:|
| Total consumption | 35,539,823.31 kWh |
| Household-days | 3,510,403 |
| Active households | 5,561 |
| Average consumption per household-day | 10.12 kWh |
| Maximum household daily consumption | 332.56 kWh |

The dataset therefore represents approximately:

**35.54 million kWh of validated electricity consumption**

across more than:

**3.51 million household-days**

---

# 2. Dataset Coverage

The validated readings cover:

`23 November 2011 → 28 February 2014`

The observation period includes:

- Partial 2011
- Full 2012
- Full 2013
- Partial 2014

This distinction is important when interpreting annual totals.

2011 and 2014 should not be compared directly with the complete 2012 and 2013 calendar years as equivalent full-year periods.

---

# 3. Annual Consumption

Observed annual results are:

| Year | Total Consumption (kWh) | Avg Household-Day (kWh) | Active Households |
|---|---:|---:|---:|
| 2011* | 103,874.41 | 12.19 | 411 |
| 2012 | 12,488,667.30 | 9.88 | 5,549 |
| 2013 | 19,615,738.61 | 10.11 | 5,528 |
| 2014* | 3,331,542.98 | 11.18 | 5,108 |

`* 2011 and 2014 are partial observation years.`

The annual totals primarily reflect both consumption and the amount of dataset coverage available in each year.

For this reason, average household-day consumption is generally more appropriate than raw totals when comparing periods with different coverage.

---

# 4. Standard vs Time-of-Use Households

The validated population contains:

| Tariff Type | Households | Total Consumption (kWh) | Avg Household-Day (kWh) |
|---|---:|---:|---:|
| Std | 4,438 | 28,833,441.02 | 10.28 |
| ToU | 1,123 | 6,706,382.28 | 9.50 |

Time-of-Use households recorded lower average daily consumption than Standard households across the overall observation period.

Approximate averages:

- Standard: **10.28 kWh per household-day**
- Time-of-Use: **9.50 kWh per household-day**

This represents an observed difference of approximately:

**7.6%**

However, this comparison does not establish that the tariff itself caused the difference.

The two household groups may differ in characteristics that are not represented in the analytical dataset.

---

# 5. Weekday vs Weekend Behaviour

Average household daily consumption differs between weekdays and weekends.

| Day Type | Total Consumption (kWh) | Avg Household-Day (kWh) | Household-Days |
|---|---:|---:|---:|
| Weekday | 25,084,348.89 | 9.99 | 2,511,584 |
| Weekend | 10,455,474.42 | 10.47 | 998,819 |

Weekend average daily consumption was approximately:

**4.8% higher**

than weekday average daily consumption.

This indicates a measurable difference in household consumption behaviour between working-week and weekend periods within the dataset.

---

# 6. Intraday Demand

The source data records electricity consumption at half-hour intervals.

The Gold Demand Pattern fact retains this analytical structure through:

**48 half-hour slots per day**

This allows the Power BI report to show how average consumption changes throughout the day and how those patterns differ between Standard and Time-of-Use households.

The demand model uses a weighted average:

`Total Consumption / Reading Count`

rather than an unweighted average of already aggregated averages.

This ensures each underlying reading contributes appropriately to the result.

---

# 7. 2013 Dynamic Tariff Schedule

The supplied tariff reference covers the full 2013 calendar year.

It contains:

**17,520 half-hour tariff periods**

calculated as:

`365 days × 48 periods = 17,520`

Distribution:

| Dynamic Band | Half-Hour Periods |
|---|---:|
| Normal | 15,072 |
| Low | 1,660 |
| High | 788 |

The schedule is dynamic rather than a simple fixed daily High/Normal/Low clock pattern.

This means tariff classification must be joined using the actual date and half-hour period rather than inferred only from time of day.

---

# 8. Standard vs ToU During Dynamic Tariff Bands

For 2013, average half-hour consumption was compared between Standard and Time-of-Use households within the same dynamic tariff periods.

| Band | Std Avg kWh | ToU Avg kWh | ToU vs Std |
|---|---:|---:|---:|
| High | 0.258 | 0.226 | -12.54% |
| Normal | 0.212 | 0.194 | -8.52% |
| Low | 0.216 | 0.209 | -3.39% |

Time-of-Use households recorded lower average half-hour consumption than Standard households in all three dynamic tariff bands.

The largest observed difference occurred during:

**High tariff periods — approximately 12.5% lower**

followed by:

- Normal — approximately 8.5% lower
- Low — approximately 3.4% lower

This pattern is consistent with differences in demand behaviour between the household groups.

It should not be interpreted as proof that dynamic pricing caused the difference.

---

# 9. Important Demand-Response Limitation

Looking only at Time-of-Use households provides an important qualification.

Average ToU consumption by band was approximately:

| Band | ToU Avg Half-Hour Consumption |
|---|---:|
| High | 0.2256 kWh |
| Low | 0.2090 kWh |
| Normal | 0.1939 kWh |

Within the ToU population itself, High-band consumption was not the lowest.

Compared with Normal periods, ToU High-period average consumption was approximately:

**16.3% higher**

This means the analysis should not make a simple claim such as:

> High tariff prices reduced absolute consumption during High periods.

The underlying periods occur at different times and under different demand conditions.

The more defensible finding is that:

**ToU households recorded lower average consumption than Standard households during equivalent 2013 dynamic tariff-band periods, with the largest measured difference occurring during High periods.**

---

# 10. Household-Level Variation

Portfolio averages can hide substantial differences between individual households.

The Household Explorer therefore allows a single household to be analysed independently and compared with the wider portfolio.

For the default example household used during report QA (`MAC000002`), the report showed approximately:

| Metric | Result |
|---|---:|
| Household-days | 505 |
| Total consumption | 6,095.67 kWh |
| Average daily consumption | 12.07 kWh |
| Peak daily consumption | 39.28 kWh |

Its average daily consumption was approximately:

**19.2% above the portfolio average**

under the corresponding report context.

This illustrates why both portfolio-level and household-level views are useful.

---

# 11. Household Weekday/Weekend Example

For the same example household, average consumption was approximately:

- Weekday: **11.76 kWh**
- Weekend: **12.85 kWh**

Weekend consumption was approximately:

**9.3% higher**

for this household.

This is larger than the overall portfolio weekend difference of approximately 4.8%, demonstrating that individual household behaviour can differ materially from the aggregate pattern.

The example should not be assumed to represent every household.

---

# 12. Data Completeness

The Gold Daily Consumption fact contains:

**3,510,403 household-days**

of which:

| Status | Household-Days |
|---|---:|
| Complete | 3,469,352 |
| Partial | 41,051 |

Overall completeness:

**98.83%**

A complete day contains the expected:

**48 half-hour readings**

The remaining 1.17% of household-days are retained and explicitly identified rather than removed from the analytical model.

This allows data coverage to remain visible when interpreting consumption results.

---

# 13. Data Quality Findings

Full processing identified:

- **5,560 invalid source records**
- **115,453 duplicate records removed**
- **0 duplicate Silver business keys after processing**
- **0 invalid Silver tariff records**
- **0 invalid Silver consumption records after validation**
- **0 missing Gold dimension references**
- **0 duplicate Gold fact-grain keys**

All 5,560 rejected records were classified as:

`INVALID_CONSUMPTION`

Bronze-to-Silver reconciliation accounted for every source record.

---

# 14. Analytical Scale Reduction

The platform converts:

**167,811,461 validated Silver readings**

into two reporting-oriented Gold facts:

| Gold Fact | Rows |
|---|---:|
| Daily Consumption | 3,510,403 |
| Demand Pattern | 79,454 |

This is not data loss.

The Gold tables intentionally aggregate the validated readings to analytical grains aligned with the reporting requirements.

The complete validated reading-level dataset remains available in Silver.

---

# 15. Key Findings

The principal analytical findings from the implemented dataset are:

1. The validated dataset contains approximately **35.54 million kWh** across **3.51 million household-days**.

2. Average household daily consumption is approximately **10.12 kWh**.

3. Weekend average household-day consumption is approximately **4.8% higher** than weekday consumption.

4. Standard households recorded approximately **10.28 kWh** average daily consumption compared with approximately **9.50 kWh** for Time-of-Use households.

5. During the 2013 dynamic tariff schedule, ToU households recorded lower average half-hour consumption than Standard households across High, Normal and Low periods.

6. The largest 2013 Std-versus-ToU difference occurred during High periods at approximately **12.5%**.

7. High-period consumption within the ToU group itself was not the lowest band, so the results do not demonstrate a simple causal reduction from higher tariff periods.

8. **98.83%** of household-days contain the expected 48 validated readings.

9. The engineering pipeline reconciles all Bronze records into validated Silver, rejected records and duplicate removals with **zero unaccounted records**.

---

# Analytical Limitations

The analysis should be interpreted with several limitations.

## Observational Dataset

Standard and Time-of-Use households were not treated as identical populations within this project.

Observed differences should therefore not be interpreted automatically as tariff effects.

## Partial Years

2011 and 2014 contain partial dataset coverage.

Their raw totals are not directly comparable with complete calendar years.

## Tariff Schedule Coverage

Dynamic High, Normal and Low classifications are available only for 2013 from the supplied tariff reference workbook.

## Household Characteristics

The analytical dataset does not contain sufficient household demographic or property information to explain all differences in consumption.

## Missing Readings

Approximately 1.17% of household-days are incomplete.

These observations are retained and flagged rather than silently removed.

---

# Conclusion

The analysis demonstrates how a large smart-meter dataset can be transformed into several levels of useful information:

`167.9M source records`

↓

`167.8M validated readings`

↓

`Household daily behaviour`

+

`Half-hour demand patterns`

↓

`Power BI analytical insights`

The strongest value of the platform is not a single consumption metric. It is the combination of scalable data engineering, explicit data quality, appropriate analytical grains and transparent interpretation of the resulting patterns.