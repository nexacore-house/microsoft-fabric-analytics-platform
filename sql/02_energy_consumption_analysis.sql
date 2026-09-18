/*
===============================================================================
Project: Microsoft Fabric Analytics Platform
Script: 02_energy_consumption_analysis.sql
Purpose:
    Analyse electricity consumption patterns from the Gold Daily Consumption
    fact through the Microsoft Fabric SQL Analytics Endpoint.

Analysis:
    - Overall consumption KPIs
    - Consumption by tariff type
    - Annual consumption patterns
    - Weekday versus weekend behaviour
    - Daily data completeness

Notes:
    - Queries are read-only.
    - 2011 and 2014 represent partial years in the source dataset.
    - Tariff comparisons are observational and should not be interpreted
      as evidence that tariff type caused differences in consumption.
===============================================================================
*/


-- =============================================================================
-- 1. OVERALL CONSUMPTION KPIs
-- =============================================================================

SELECT
    COUNT(*) AS HouseholdDays,
    SUM(f.DailyConsumptionKWh) AS TotalConsumptionKWh,
    AVG(f.DailyConsumptionKWh) AS AvgConsumptionPerHouseholdDayKWh,
    MAX(f.DailyConsumptionKWh) AS MaxHouseholdDailyConsumptionKWh,
    COUNT(DISTINCT f.HouseholdKey) AS ActiveHouseholds
FROM gold.fact_daily_consumption AS f;

-- =============================================================================
-- 2. CONSUMPTION BY HOUSEHOLD TARIFF TYPE
-- =============================================================================

SELECT
    t.TariffType,
    COUNT(DISTINCT f.HouseholdKey) AS Households,
    SUM(f.DailyConsumptionKWh) AS TotalConsumptionKWh,
    AVG(f.DailyConsumptionKWh) AS AvgDailyConsumptionKWh
FROM gold.fact_daily_consumption AS f
INNER JOIN gold.dim_tariff AS t
    ON f.TariffKey = t.TariffKey
GROUP BY
    t.TariffType
ORDER BY
    t.TariffType;

  -- =============================================================================
-- 3. ANNUAL CONSUMPTION PATTERNS
-- =============================================================================

SELECT
    d.Year,
    SUM(f.DailyConsumptionKWh) AS TotalConsumptionKWh,
    AVG(f.DailyConsumptionKWh) AS AvgDailyConsumptionKWh,
    COUNT(DISTINCT f.HouseholdKey) AS ActiveHouseholds,
    COUNT(*) AS HouseholdDays
FROM gold.fact_daily_consumption AS f
INNER JOIN gold.dim_date AS d
    ON f.DateKey = d.DateKey
GROUP BY
    d.Year
ORDER BY
    d.Year;

  /*
Interpretation note:
2011 and 2014 are partial observation years in the source dataset.
Their total consumption should therefore not be directly compared with
the complete 2012 and 2013 calendar years as equivalent annual totals.
*/

-- =============================================================================
-- 4. WEEKDAY VS WEEKEND CONSUMPTION
-- =============================================================================

SELECT
    CASE
        WHEN d.DayOfWeek IN ('Saturday', 'Sunday')
            THEN 'Weekend'
        ELSE 'Weekday'
    END AS DayType,

    SUM(f.DailyConsumptionKWh) AS TotalConsumptionKWh,
    AVG(f.DailyConsumptionKWh) AS AvgDailyConsumptionKWh,
    COUNT(*) AS HouseholdDays

FROM gold.fact_daily_consumption AS f
INNER JOIN gold.dim_date AS d
    ON f.DateKey = d.DateKey

GROUP BY
    CASE
        WHEN d.DayOfWeek IN ('Saturday', 'Sunday')
            THEN 'Weekend'
        ELSE 'Weekday'
    END

ORDER BY
    DayType;

-- =============================================================================
-- 5. WEEKEND VS WEEKDAY AVERAGE DIFFERENCE
-- =============================================================================

WITH DayTypeConsumption AS
(
    SELECT
        CASE
            WHEN d.DayOfWeek IN ('Saturday', 'Sunday')
                THEN 'Weekend'
            ELSE 'Weekday'
        END AS DayType,
        AVG(f.DailyConsumptionKWh) AS AvgDailyConsumptionKWh

    FROM gold.fact_daily_consumption AS f
    INNER JOIN gold.dim_date AS d
        ON f.DateKey = d.DateKey

    GROUP BY
        CASE
            WHEN d.DayOfWeek IN ('Saturday', 'Sunday')
                THEN 'Weekend'
            ELSE 'Weekday'
        END
),

DayTypePivot AS
(
    SELECT
        MAX(
            CASE WHEN DayType = 'Weekday'
                THEN AvgDailyConsumptionKWh
            END
        ) AS WeekdayAvgKWh,

        MAX(
            CASE WHEN DayType = 'Weekend'
                THEN AvgDailyConsumptionKWh
            END
        ) AS WeekendAvgKWh

    FROM DayTypeConsumption
)

SELECT
    WeekdayAvgKWh,
    WeekendAvgKWh,

    (
        (WeekendAvgKWh - WeekdayAvgKWh)
        / WeekdayAvgKWh
    ) * 100 AS WeekendDifferencePct

FROM DayTypePivot;

-- =============================================================================
-- 6. DAILY READING COMPLETENESS
-- =============================================================================

SELECT
    CASE
        WHEN IsCompleteDay = 1
            THEN 'Complete'
        ELSE 'Partial'
    END AS CompletenessStatus,

    COUNT(*) AS HouseholdDays,

    CAST(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER ()
        AS DECIMAL(10, 2)
    ) AS PercentageOfHouseholdDays

FROM gold.fact_daily_consumption

GROUP BY
    IsCompleteDay

ORDER BY
    IsCompleteDay DESC;

    /*
===============================================================================
ANALYTICAL NOTES

Validated observations from the Gold Daily Consumption fact:

1. The dataset represents approximately 35.54 million kWh across
   3.51 million household-days.

2. Standard households recorded approximately 10.28 kWh average daily
   consumption compared with approximately 9.50 kWh for ToU households.

3. Weekend household-day consumption averaged approximately 4.8% higher
   than weekday household-day consumption.

4. Approximately 98.83% of household-days contain all 48 expected
   half-hour readings.

5. Tariff comparisons are observational. Household characteristics,
   participation selection and other factors may contribute to measured
   differences; these queries do not establish causal effects.

6. 2011 and 2014 are partial observation years and should not be treated
   as equivalent full-year comparisons with 2012 and 2013.
===============================================================================
*/