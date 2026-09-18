/*
===============================================================================
Project: Microsoft Fabric Analytics Platform
Script: 01_gold_model_validation.sql
Purpose:
    Validate the Gold dimensional model through the Microsoft Fabric
    SQL Analytics Endpoint.

    These queries provide an independent SQL validation layer over the
    Delta-backed Gold tables created with PySpark.

Platform:
    Microsoft Fabric SQL Analytics Endpoint

Notes:
    - Gold transformations are performed with PySpark.
    - SQL is used for validation, reconciliation and analytical exploration.
    - Queries are read-only and do not modify Lakehouse data.
===============================================================================
*/


-- =============================================================================
-- 1. GOLD TABLE ROW COUNTS
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

-- =============================================================================
-- 2. DAILY CONSUMPTION FACT SUMMARY
-- =============================================================================

SELECT
    COUNT(*) AS HouseholdDays,
    SUM(DailyConsumptionKWh) AS TotalConsumptionKWh,
    AVG(DailyConsumptionKWh) AS AvgConsumptionPerHouseholdDayKWh,
    MAX(DailyConsumptionKWh) AS MaxHouseholdDailyConsumptionKWh,
    SUM(
        CASE
            WHEN IsCompleteDay = 1 THEN 1
            ELSE 0
        END
    ) AS CompleteHouseholdDays
FROM gold.fact_daily_consumption;

-- =============================================================================
-- 3. DIMENSION KEY UNIQUENESS
-- =============================================================================

SELECT
    HouseholdKey,
    COUNT(*) AS DuplicateCount
FROM gold.dim_household
GROUP BY HouseholdKey
HAVING COUNT(*) > 1;


SELECT
    DateKey,
    COUNT(*) AS DuplicateCount
FROM gold.dim_date
GROUP BY DateKey
HAVING COUNT(*) > 1;


SELECT
    TimeKey,
    COUNT(*) AS DuplicateCount
FROM gold.dim_time
GROUP BY TimeKey
HAVING COUNT(*) > 1;


SELECT
    TariffKey,
    COUNT(*) AS DuplicateCount
FROM gold.dim_tariff
GROUP BY TariffKey
HAVING COUNT(*) > 1;

-- =============================================================================
-- 4. FACT GRAIN UNIQUENESS
-- =============================================================================

-- Daily Consumption grain:
-- one row per Household × Date

SELECT
    HouseholdKey,
    DateKey,
    COUNT(*) AS DuplicateCount
FROM gold.fact_daily_consumption
GROUP BY
    HouseholdKey,
    DateKey
HAVING COUNT(*) > 1;


-- Demand Pattern grain:
-- one row per Date × Half-Hour Time Slot × Tariff

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