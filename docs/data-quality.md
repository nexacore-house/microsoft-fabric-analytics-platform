# Data Quality & Validation

## Overview

Data quality is treated as part of the engineering pipeline rather than as a reporting-only activity.

The Microsoft Fabric Analytics Platform validates data as it moves from Bronze through Silver and Gold, while retaining rejected records and reconciling transformation outcomes.

The validation approach covers:

- Source profiling
- Type validation
- Domain validation
- Duplicate detection
- Rejected-record preservation
- Record-count reconciliation
- Daily completeness
- Referential integrity
- Fact-grain uniqueness
- Consumption reconciliation

---

## Data Quality Flow

The principal validation flow is:

`Bronze → Validate → Reject Invalid Records → Deduplicate → Silver → Aggregate → Gold → QA`

Invalid records are not silently removed.

They are persisted separately in:

`silver.rejected_meter_readings`

Duplicate records are tracked as a separate transformation outcome.

---

# Development Profiling

Before processing the complete dataset, a 1,000,000-row development sample was profiled.

The profiling identified several important characteristics.

| Metric | Result |
|---|---:|
| Rows profiled | 1,000,000 |
| Distinct households | 30 |
| Exact duplicates | 688 |
| Duplicate Household + Timestamp keys | 688 |
| Invalid numeric consumption rows | 29 |
| Negative consumption rows | 0 |
| Minimum valid consumption | 0.0 kWh |
| Maximum valid consumption | 6.528 kWh |
| Average valid consumption | ~0.23958 kWh |

The profiling showed that values which were not Spark nulls could still fail numeric conversion.

This led to an explicit Silver rule:

**Invalid or non-numeric consumption must not be interpreted as zero.**

---

# Silver Validation Contract

A source record must pass the Silver validation contract before entering `silver.meter_readings`.

## Household Validation

`HouseholdID` must be present and non-empty.

Failure classification:

`MISSING_HOUSEHOLD`

---

## Timestamp Validation

The source timestamp must successfully parse into a valid `ReadingTimestamp`.

Failure classification:

`INVALID_TIMESTAMP`

---

## Consumption Validation

Consumption must:

- Successfully convert to numeric form
- Not be null after conversion
- Be greater than or equal to zero

Failure classification:

`INVALID_CONSUMPTION`

Missing or invalid consumption is not replaced with zero because doing so would create artificial electricity usage observations.

---

## Tariff Validation

The household tariff classification must belong to the expected domain:

- `Std`
- `ToU`

Failure classification:

`INVALID_TARIFF`

---

# Rejection Precedence

When assigning a single rejection reason, the validation logic uses the following precedence:

1. `MISSING_HOUSEHOLD`
2. `INVALID_TIMESTAMP`
3. `INVALID_CONSUMPTION`
4. `INVALID_TARIFF`

This provides deterministic classification when a record could potentially fail more than one validation condition.

---

# Rejected Records

Rejected records are persisted in:

`silver.rejected_meter_readings`

Full-scale result:

**5,560 rejected records**

Observed rejection distribution:

| Rejection Reason | Rows |
|---|---:|
| INVALID_CONSUMPTION | 5,560 |
| MISSING_HOUSEHOLD | 0 |
| INVALID_TIMESTAMP | 0 |
| INVALID_TARIFF | 0 |

Keeping rejected records provides an audit trail and makes the transformation outcome transparent.

---

# Duplicate Handling

## Business Key

The Silver reading-level business key is:

`HouseholdID + ReadingTimestamp`

A household should have only one validated observation for a given half-hour timestamp.

## Development Finding

The 1,000,000-row development sample contained:

**688 duplicate business-key records**

No conflicting duplicate values were identified in that sample.

## Full Dataset

Full-scale processing identified:

**115,453 duplicate records removed**

After Silver deduplication:

**0 duplicate HouseholdID + ReadingTimestamp keys remain**

Duplicates are tracked separately from invalid records because they represent a different data-quality condition.

---

# Bronze to Silver Reconciliation

The full transformation produced:

| Transformation Outcome | Rows |
|---|---:|
| Bronze input | 167,932,474 |
| Rejected | 5,560 |
| Duplicate records removed | 115,453 |
| Silver output | 167,811,461 |
| Unaccounted difference | 0 |

The reconciliation equation is:

`Bronze = Rejected + Duplicates Removed + Silver`

Therefore:

`167,932,474 = 5,560 + 115,453 + 167,811,461`

The difference is:

**0 records**

This provides explicit accounting for every Bronze record.

---

# Silver Post-Transformation QA

Independent QA checks were performed after the full Silver transformation.

Results:

| Validation | Result |
|---|---:|
| Duplicate business keys | 0 |
| Invalid consumption rows | 0 |
| Invalid tariff rows | 0 |
| Missing/invalid household records | 0 |
| Invalid timestamps | 0 |

The QA stage validates the persisted Silver output rather than relying only on transformation-time assumptions.

---

# Reading Interval Profiling

The source is primarily half-hourly.

Silver profiling showed that the overwhelming majority of consecutive household readings occur at 30-minute intervals.

The most common interval was:

**30 minutes — 167,780,495 occurrences**

Larger intervals also exist and represent gaps between available readings.

These gaps are one reason daily completeness is measured explicitly rather than assuming every household-day contains 48 readings.

---

# Daily Completeness

A complete household-day is expected to contain:

**48 half-hour readings**

Gold daily modelling retains both complete and partial days.

Results:

| Completeness | Household-Days |
|---|---:|
| Complete | 3,469,352 |
| Partial | 41,051 |
| Total | 3,510,403 |

Complete household-days:

**98.83%**

Partial household-days:

**1.17%**

Partial days are retained because removing them would hide a genuine characteristic of the source data.

The `IsCompleteDay` flag allows report consumers to identify or filter these observations where appropriate.

---

# Gold Dimension Validation

All Gold dimensions were checked for duplicate keys.

| Dimension | Duplicate Keys |
|---|---:|
| `dim_household` | 0 |
| `dim_date` | 0 |
| `dim_time` | 0 |
| `dim_tariff` | 0 |

Final dimension counts:

| Dimension | Rows |
|---|---:|
| Household | 5,561 |
| Date | 829 |
| Time | 48 |
| Tariff | 2 |

---

# Gold Referential Integrity

## Daily Consumption Fact

`gold.fact_daily_consumption`

Validated dimension references:

- HouseholdKey
- DateKey
- TariffKey

Result:

**0 missing dimension references**

## Demand Pattern Fact

`gold.fact_demand_pattern`

Validated dimension references:

- DateKey
- TimeKey
- TariffKey

Result:

**0 missing dimension references**

---

# Gold Fact-Grain Validation

## Daily Consumption

Expected grain:

`HouseholdKey + DateKey`

Duplicate grain keys:

**0**

## Demand Pattern

Expected grain:

`DateKey + TimeKey + TariffKey`

Duplicate grain keys:

**0**

This confirms that each fact table conforms to its documented analytical grain.

---

# Consumption Reconciliation

Consumption was reconciled between the validated Silver readings and both Gold analytical facts.

## Silver

Total consumption:

**35,539,823.306363 kWh**

## Gold Daily Consumption

Total consumption:

**35,539,823.306385 kWh**

Approximate difference from Silver:

**-0.000022 kWh**

## Gold Demand Pattern

Total consumption:

**35,539,823.306385 kWh**

The observed differences are negligible relative to the approximately 35.54 million kWh total and are consistent with floating-point aggregation behaviour.

No material consumption was lost during Gold aggregation.

---

# Tariff Schedule Validation

The supplied tariff reference workbook was independently profiled before enrichment.

Results:

| Validation | Result |
|---|---:|
| Rows | 17,520 |
| Start | 2013-01-01 00:00 |
| End | 2013-12-31 23:30 |
| Distinct timestamps | 17,520 |
| Duplicate timestamps | 0 |
| Interval | 30 minutes |
| Missing periods | 0 |

The expected annual schedule is:

`365 days × 48 half-hour periods = 17,520`

Tariff-band distribution:

| Band | Periods |
|---|---:|
| Normal | 15,072 |
| Low | 1,660 |
| High | 788 |

The schedule therefore provides complete half-hour coverage for calendar year 2013.

---

# Tariff Enrichment QA

The tariff schedule was joined to the Demand Pattern fact using:

`DateKey + TimeKey`

After enrichment:

| Validation | Result |
|---|---:|
| Original Demand Pattern rows | 79,454 |
| Enriched Demand Pattern rows | 79,454 |
| Duplicate fact keys | 0 |
| Null TariffBand values | 0 |
| Consumption change | Negligible / none materially |

Tariff-band distribution in the enriched fact:

| TariffBand | Rows |
|---|---:|
| Not Applicable | 44,414 |
| Normal | 30,144 |
| Low | 3,320 |
| High | 1,576 |

For 2013:

**35,040 classified fact rows**

This corresponds to:

`17,520 half-hour periods × 2 household tariff groups = 35,040`

---

# SQL Validation

The Fabric SQL Analytics Endpoint provides an additional read-only validation interface over the persisted Lakehouse tables.

The repository contains:

- `01_gold_model_validation.sql`
- `02_energy_consumption_analysis.sql`
- `03_demand_pattern_analysis.sql`
- `04_data_quality_validation.sql`

SQL is used to independently inspect persisted outcomes such as:

- Table counts
- Dimension uniqueness
- Fact-grain uniqueness
- Referential integrity
- Completeness
- Consumption totals
- Tariff analysis

The main transformation logic remains implemented in PySpark.

---

# Reporting Observability

Data-quality outcomes are surfaced in the Power BI report through:

**Data Quality & Pipeline Observability**

The page presents key engineering outcomes including:

- 168 landed source files
- 167.93M Bronze records
- 167.81M Silver records
- 5,560 rejected records
- 115,453 duplicate records removed
- 98.83% complete household-days
- 0 missing Gold dimension keys
- 0 duplicate Gold fact keys
- Reconciled pipeline status

This makes data quality visible alongside business-facing analysis rather than leaving it only inside engineering notebooks.

---

# Validation Summary

The implemented data-quality framework achieved:

- 167,932,474 Bronze records accounted for
- 5,560 invalid records preserved for audit
- 115,453 duplicate records removed
- 167,811,461 validated Silver records
- 0 unaccounted Bronze-to-Silver records
- 0 duplicate Silver business keys
- 0 invalid Silver consumption records
- 0 invalid Silver tariff values
- 98.83% complete household-days
- 0 missing Gold dimension references
- 0 duplicate Gold fact-grain keys
- Silver and Gold consumption reconciled within negligible floating-point variance

The approach combines prevention, rejection, reconciliation and post-transformation validation rather than relying on a single data-cleaning step.