/*
===============================================================================
Project: Microsoft Fabric Analytics Platform
Script: 04_data_quality_validation.sql
Purpose:
    Validate data quality, reconciliation and model integrity across the
    analytical layers exposed through the Microsoft Fabric SQL Analytics
    Endpoint.

Validation:
    - Silver data quality
    - Rejected-record analysis
    - Gold daily completeness
    - Gold referential integrity
    - Fact-grain uniqueness
    - Cross-fact consumption reconciliation

Notes:
    - Queries are read-only.
    - Transformation and rejection logic is implemented with PySpark.
    - SQL provides an independent validation interface over persisted tables.
===============================================================================
*/

-- =============================================================================
-- 1. SILVER DATA QUALITY COUNTS
-- =============================================================================

SELECT
    (SELECT COUNT(*) FROM silver.meter_readings) AS ValidSilverRows,
    (SELECT COUNT(*) FROM silver.rejected_meter_readings) AS RejectedRows;

-- =============================================================================
-- 2. REJECTED RECORDS BY REASON
-- =============================================================================

SELECT
    RejectionReason,
    COUNT(*) AS RejectedRows
FROM silver.rejected_meter_readings
GROUP BY
    RejectionReason
ORDER BY
    RejectedRows DESC;

-- =============================================================================
-- 3. SILVER BUSINESS-KEY UNIQUENESS
-- =============================================================================

SELECT
    HouseholdID,
    ReadingTimestamp,
    COUNT(*) AS DuplicateCount
FROM silver.meter_readings
GROUP BY
    HouseholdID,
    ReadingTimestamp
HAVING COUNT(*) > 1;

-- =============================================================================
-- 4. SILVER CONSUMPTION VALIDATION
-- =============================================================================

SELECT
    COUNT(*) AS InvalidConsumptionRows
FROM silver.meter_readings
WHERE
    ConsumptionKWh IS NULL
    OR ConsumptionKWh < 0;

-- =============================================================================
-- 5. SILVER TARIFF DOMAIN VALIDATION
-- =============================================================================

SELECT
    COUNT(*) AS InvalidTariffRows
FROM silver.meter_readings
WHERE
    TariffType IS NULL
    OR TariffType NOT IN ('Std', 'ToU');

-- =============================================================================
-- 6. GOLD DAILY COMPLETENESS
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

-- =============================================================================
-- 7. DAILY FACT REFERENTIAL INTEGRITY
-- =============================================================================

SELECT
    SUM(
        CASE WHEN h.HouseholdKey IS NULL
            THEN 1 ELSE 0
        END
    ) AS MissingHouseholdKeys,

    SUM(
        CASE WHEN d.DateKey IS NULL
            THEN 1 ELSE 0
        END
    ) AS MissingDateKeys,

    SUM(
        CASE WHEN t.TariffKey IS NULL
            THEN 1 ELSE 0
        END
    ) AS MissingTariffKeys

FROM gold.fact_daily_consumption AS f

LEFT JOIN gold.dim_household AS h
    ON f.HouseholdKey = h.HouseholdKey

LEFT JOIN gold.dim_date AS d
    ON f.DateKey = d.DateKey

LEFT JOIN gold.dim_tariff AS t
    ON f.TariffKey = t.TariffKey;

-- =============================================================================
-- 8. DEMAND FACT REFERENTIAL INTEGRITY
-- =============================================================================

SELECT
    SUM(
        CASE WHEN d.DateKey IS NULL
            THEN 1 ELSE 0
        END
    ) AS MissingDateKeys,

    SUM(
        CASE WHEN tm.TimeKey IS NULL
            THEN 1 ELSE 0
        END
    ) AS MissingTimeKeys,

    SUM(
        CASE WHEN t.TariffKey IS NULL
            THEN 1 ELSE 0
        END
    ) AS MissingTariffKeys

FROM gold.fact_demand_pattern AS f

LEFT JOIN gold.dim_date AS d
    ON f.DateKey = d.DateKey

LEFT JOIN gold.dim_time AS tm
    ON f.TimeKey = tm.TimeKey

LEFT JOIN gold.dim_tariff AS t
    ON f.TariffKey = t.TariffKey;

-- =============================================================================
-- 9. FACT GRAIN UNIQUENESS
-- =============================================================================

-- Expected: zero rows
SELECT
    HouseholdKey,
    DateKey,
    COUNT(*) AS DuplicateCount
FROM gold.fact_daily_consumption
GROUP BY
    HouseholdKey,
    DateKey
HAVING COUNT(*) > 1;


-- Expected: zero rows
SELECT
    DateKey,
    TimeKey,
    TariffKey,
    COUNT(*) AS DuplicateCount
FROM gold.fact_demand_pattern
GROUP BY
    DateKey,
    TimeKey,
    TariffKey
HAVING COUNT(*) > 1;

-- =============================================================================
-- 10. CROSS-LAYER CONSUMPTION RECONCILIATION
-- =============================================================================

WITH SilverTotal AS
(
    SELECT
        SUM(ConsumptionKWh) AS TotalConsumptionKWh
    FROM silver.meter_readings
),

DailyTotal AS
(
    SELECT
        SUM(DailyConsumptionKWh) AS TotalConsumptionKWh
    FROM gold.fact_daily_consumption
),

DemandTotal AS
(
    SELECT
        SUM(TotalConsumptionKWh) AS TotalConsumptionKWh
    FROM gold.fact_demand_pattern
)

SELECT
    s.TotalConsumptionKWh AS SilverConsumptionKWh,
    d.TotalConsumptionKWh AS DailyFactConsumptionKWh,
    p.TotalConsumptionKWh AS DemandFactConsumptionKWh,

    s.TotalConsumptionKWh
        - d.TotalConsumptionKWh AS SilverVsDailyDifferenceKWh,

    s.TotalConsumptionKWh
        - p.TotalConsumptionKWh AS SilverVsDemandDifferenceKWh

FROM SilverTotal AS s
CROSS JOIN DailyTotal AS d
CROSS JOIN DemandTotal AS p;

-- =============================================================================
-- 11. GOLD MODEL ROW COUNTS
-- =============================================================================

SELECT 'dim_household' AS TableName, COUNT(*) AS RowCount
FROM gold.dim_household

UNION ALL
SELECT 'dim_date', COUNT(*)
FROM gold.dim_date

UNION ALL
SELECT 'dim_time', COUNT(*)
FROM gold.dim_time

UNION ALL
SELECT 'dim_tariff', COUNT(*)
FROM gold.dim_tariff

UNION ALL
SELECT 'fact_daily_consumption', COUNT(*)
FROM gold.fact_daily_consumption

UNION ALL
SELECT 'fact_demand_pattern', COUNT(*)
FROM gold.fact_demand_pattern;

/*
===============================================================================
VALIDATION SUMMARY

Validated outcomes:

- 167,811,461 records retained in the validated Silver layer
- 5,560 invalid records retained separately for audit
- All persisted rejected records classified as INVALID_CONSUMPTION
- 0 duplicate Silver HouseholdID + ReadingTimestamp business keys
- 0 invalid Silver consumption values
- 0 invalid Silver tariff values
- 3,469,352 complete household-days
- 41,051 partial household-days
- 98.83% daily completeness
- 0 missing Gold dimension references
- 0 duplicate Gold fact-grain keys
- Silver and both Gold facts reconcile with only negligible
  floating-point aggregation variance

The duplicate-removal count of 115,453 is captured during the PySpark Silver
transformation and reconciliation process. It is not reconstructed here unless
the transformation audit metric is persisted independently.

These SQL checks provide an additional read-only validation layer over the
persisted Lakehouse model.
===============================================================================
*/
