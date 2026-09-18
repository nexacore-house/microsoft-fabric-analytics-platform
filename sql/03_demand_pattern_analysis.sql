/*
===============================================================================
Project: Microsoft Fabric Analytics Platform
Script: 03_demand_pattern_analysis.sql
Purpose:
    Analyse half-hour electricity demand patterns and tariff behaviour using
    the Gold Demand Pattern fact through the Microsoft Fabric SQL Analytics
    Endpoint.

Analysis:
    - Half-hour demand profile
    - Standard vs Time-of-Use demand
    - Dynamic High / Normal / Low tariff bands
    - 2013 Std vs ToU tariff-band comparison
    - Demand-response observations

Notes:
    - Queries are read-only.
    - Dynamic tariff-band analysis is restricted to 2013 because the supplied
      tariff schedule covers calendar year 2013.
    - Results are observational and do not establish causal effects of pricing.
===============================================================================
*/

-- =============================================================================
-- 1. HALF-HOUR DEMAND PROFILE
-- =============================================================================

SELECT
    tm.TimeKey,
    tm.TimeLabel,
    SUM(f.TotalConsumptionKWh) AS TotalConsumptionKWh,
    SUM(f.TotalConsumptionKWh)
        / NULLIF(SUM(f.ReadingCount), 0) AS AvgConsumptionPerReadingKWh,
    SUM(f.ReadingCount) AS ReadingCount
FROM gold.fact_demand_pattern AS f
INNER JOIN gold.dim_time AS tm
    ON f.TimeKey = tm.TimeKey
GROUP BY
    tm.TimeKey,
    tm.TimeLabel
ORDER BY
    tm.TimeKey;

/*
Average demand is calculated as total consumption divided by total readings.

This avoids an unweighted "average of averages" across aggregated fact rows
that may represent different numbers of household observations.
*/

-- =============================================================================
-- 2. HALF-HOUR DEMAND PROFILE BY TARIFF TYPE
-- =============================================================================

SELECT
    tm.TimeKey,
    tm.TimeLabel,
    t.TariffType,

    SUM(f.TotalConsumptionKWh)
        / NULLIF(SUM(f.ReadingCount), 0)
        AS AvgConsumptionPerReadingKWh,

    SUM(f.TotalConsumptionKWh) AS TotalConsumptionKWh,
    SUM(f.ReadingCount) AS ReadingCount

FROM gold.fact_demand_pattern AS f

INNER JOIN gold.dim_time AS tm
    ON f.TimeKey = tm.TimeKey

INNER JOIN gold.dim_tariff AS t
    ON f.TariffKey = t.TariffKey

GROUP BY
    tm.TimeKey,
    tm.TimeLabel,
    t.TariffType

ORDER BY
    tm.TimeKey,
    t.TariffType;

-- =============================================================================
-- 3. 2013 DYNAMIC TARIFF-BAND PROFILE
-- =============================================================================

SELECT
    f.TariffBand,
    t.TariffType,

    SUM(f.TotalConsumptionKWh)
        / NULLIF(SUM(f.ReadingCount), 0)
        AS AvgConsumptionPerReadingKWh,

    SUM(f.TotalConsumptionKWh) AS TotalConsumptionKWh,
    SUM(f.ReadingCount) AS ReadingCount

FROM gold.fact_demand_pattern AS f

INNER JOIN gold.dim_date AS d
    ON f.DateKey = d.DateKey

INNER JOIN gold.dim_tariff AS t
    ON f.TariffKey = t.TariffKey

WHERE
    d.Year = 2013
    AND f.TariffBand IN ('High', 'Normal', 'Low')

GROUP BY
    f.TariffBand,
    t.TariffType

ORDER BY
    CASE f.TariffBand
        WHEN 'High' THEN 1
        WHEN 'Normal' THEN 2
        WHEN 'Low' THEN 3
        ELSE 4
    END,
    t.TariffType;

-- =============================================================================
-- 4. STD VS TOU DIFFERENCE BY DYNAMIC TARIFF BAND
-- =============================================================================

WITH TariffBandConsumption AS
(
    SELECT
        f.TariffBand,
        t.TariffType,

        SUM(f.TotalConsumptionKWh)
            / NULLIF(SUM(f.ReadingCount), 0)
            AS AvgConsumptionPerReadingKWh

    FROM gold.fact_demand_pattern AS f

    INNER JOIN gold.dim_date AS d
        ON f.DateKey = d.DateKey

    INNER JOIN gold.dim_tariff AS t
        ON f.TariffKey = t.TariffKey

    WHERE
        d.Year = 2013
        AND f.TariffBand IN ('High', 'Normal', 'Low')

    GROUP BY
        f.TariffBand,
        t.TariffType
),

BandComparison AS
(
    SELECT
        TariffBand,

        MAX(
            CASE
                WHEN TariffType = 'Std'
                    THEN AvgConsumptionPerReadingKWh
            END
        ) AS StdAvgKWh,

        MAX(
            CASE
                WHEN TariffType = 'ToU'
                    THEN AvgConsumptionPerReadingKWh
            END
        ) AS ToUAvgKWh

    FROM TariffBandConsumption

    GROUP BY
        TariffBand
)

SELECT
    TariffBand,
    StdAvgKWh,
    ToUAvgKWh,

    (
        (ToUAvgKWh - StdAvgKWh)
        / NULLIF(StdAvgKWh, 0)
    ) * 100 AS ToUVsStdDifferencePct

FROM BandComparison

ORDER BY
    CASE TariffBand
        WHEN 'High' THEN 1
        WHEN 'Normal' THEN 2
        WHEN 'Low' THEN 3
        ELSE 4
    END;

-- =============================================================================
-- 5. TOU CONSUMPTION ACROSS DYNAMIC TARIFF BANDS
-- =============================================================================

SELECT
    f.TariffBand,

    SUM(f.TotalConsumptionKWh)
        / NULLIF(SUM(f.ReadingCount), 0)
        AS AvgConsumptionPerReadingKWh,

    SUM(f.ReadingCount) AS ReadingCount

FROM gold.fact_demand_pattern AS f

INNER JOIN gold.dim_date AS d
    ON f.DateKey = d.DateKey

INNER JOIN gold.dim_tariff AS t
    ON f.TariffKey = t.TariffKey

WHERE
    d.Year = 2013
    AND t.TariffType = 'ToU'
    AND f.TariffBand IN ('High', 'Normal', 'Low')

GROUP BY
    f.TariffBand

ORDER BY
    CASE f.TariffBand
        WHEN 'High' THEN 1
        WHEN 'Normal' THEN 2
        WHEN 'Low' THEN 3
        ELSE 4
    END;

-- =============================================================================
-- 6. TARIFF-BAND COVERAGE IN DEMAND FACT
-- =============================================================================

SELECT
    TariffBand,
    COUNT(*) AS FactRows
FROM gold.fact_demand_pattern
GROUP BY
    TariffBand
ORDER BY
    FactRows DESC;

-- =============================================================================
-- 7. VALIDATE 2013 CLASSIFIED FACT ROWS
-- =============================================================================

SELECT
    COUNT(*) AS Classified2013FactRows
FROM gold.fact_demand_pattern AS f
INNER JOIN gold.dim_date AS d
    ON f.DateKey = d.DateKey
WHERE
    d.Year = 2013
    AND f.TariffBand IN ('High', 'Normal', 'Low');

/*
2013 tariff schedule validation:

17,520 half-hour tariff periods
×
2 household tariff types (Std and ToU)
=
35,040 classified Demand Pattern fact rows
*/

/*
===============================================================================
ANALYTICAL NOTES

2013 dynamic tariff-band analysis shows:

1. ToU households recorded lower average half-hour consumption than Standard
   households across all three dynamic tariff bands.

2. The largest observed difference occurred during High periods:
      High:   approximately 12.5% lower
      Normal: approximately 8.5% lower
      Low:    approximately 3.4% lower

3. Within ToU households themselves, High-band average consumption was not the
   lowest of the three tariff bands.

4. These results are consistent with differences in demand behaviour between
   the Standard and ToU household groups, but they do not establish that
   dynamic pricing caused those differences.

5. The source data is observational. Household characteristics, participant
   selection, time-of-day demand patterns and other unobserved factors may
   contribute to the measured differences.

6. Dynamic tariff-band analysis is restricted to 2013 because the supplied
   tariff reference schedule covers that calendar year.
===============================================================================
*/