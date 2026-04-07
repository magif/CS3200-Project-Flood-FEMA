USE g13_project;

-- =======================================================================================
-- QUERY 1: (Normalized Damage Severity by Archetype) -- not working
-- =======================================================================================
-- This query abandons absolute dollar payouts and instead calculates the
-- percentage of building value destroyed, segmented by environmental archetype.
-- We filter out rows with missing or zero property values to prevent divide-by-zero errors.

WITH ClaimAgg AS (
    -- PERFORMANCE FIX: Aggregate the 2.5 million claims down to the ZCTA-Year level FIRST.
    -- This shrinks the dataset from millions of rows to a few thousand before the expensive JOINs.
    SELECT z.zcta,
           c.yearOfLoss,
           COUNT(c.id)                                                                                  AS total_claims,
           SUM(GREATEST(IFNULL(c.amountPaidOnBuildingClaim, 0), 0) +
               GREATEST(IFNULL(c.amountPaidOnContentsClaim, 0), 0))                                     AS total_payout,
           SUM(((GREATEST(IFNULL(c.amountPaidOnBuildingClaim, 0), 0) +
                 GREATEST(IFNULL(c.amountPaidOnContentsClaim, 0), 0)) / c.buildingPropertyValue) *
               100)                                                                                     AS sum_pct_destroyed
    FROM fima_nfip_claims c
             JOIN zip_to_zcta z ON c.clean_zip = z.zip_code
    WHERE z.zip_join_type = 'Zip matches ZCTA'
      AND c.buildingPropertyValue > 0
      AND c.yearOfLoss >= 1985
    GROUP BY z.zcta, c.yearOfLoss),
     YearCrosswalk AS (
         -- PERFORMANCE FIX: Calculate the year mapping once for the ~40 unique loss years,
         -- rather than running a subquery for all millions of individual claims.
         SELECT distinct_years.yearOfLoss,
                MAX(n.YEAR) AS nanda_year
         FROM (SELECT DISTINCT yearOfLoss FROM fima_nfip_claims WHERE yearOfLoss >= 1985) distinct_years
                  JOIN (SELECT DISTINCT YEAR FROM nanda_land_cover) n ON n.YEAR <= distinct_years.yearOfLoss
         GROUP BY distinct_years.yearOfLoss),
     ArchetypeData AS (SELECT ZCTA20,
                              YEAR,
                              -- Define the archetypes using the NaNDA data proportions
                              CASE
                                  WHEN PROP_DEV_HIINTENSITY >= 0.5 THEN '1. Concrete Jungle (High Intensity)'
                                  WHEN PROP_DEV_LOWINTENSITY + PROP_DEV_MEDINTENSITY + PROP_DEV_HIINTENSITY >= 0.5
                                      THEN '2. Suburban Sprawl'
                                  WHEN PROP_WOODYWET + PROP_HERBWET >= 0.5 THEN '3. Swamp/Wetland'
                                  WHEN PROP_DECIDUOUSFOREST + PROP_EVERGREENFOREST + PROP_MIXEDFOREST +
                                       PROP_SHRUBSCRUB >= 0.5 THEN '4. Forest/Wildland (Natural Sponge)'
                                  ELSE '5. Mixed/Transition Zone'
                                  END AS environment_type
                       FROM nanda_land_cover)
SELECT a.environment_type,
       SUM(m.total_claims)                            AS total_claims,
       SUM(m.total_payout) / SUM(m.total_claims)      AS avg_absolute_payout,
       -- THE CRITICAL METRIC: What percentage of the building was physically destroyed?
       SUM(m.sum_pct_destroyed) / SUM(m.total_claims) AS avg_percent_value_destroyed
FROM ClaimAgg m
-- Join through our tiny crosswalk table instead of a correlated subquery
         JOIN YearCrosswalk yc ON m.yearOfLoss = yc.yearOfLoss
         JOIN ArchetypeData a ON m.zcta = a.ZCTA20 AND yc.nanda_year = a.YEAR
GROUP BY a.environment_type
HAVING SUM(m.total_claims) > 500 -- Filter for statistical significance
ORDER BY avg_percent_value_destroyed DESC;


-- =======================================================================================
-- QUERY 2: The Sprawl Delta (Longitudinal Analysis using Window Functions) -- WORKING
-- =======================================================================================
-- We use LAG() to identify which specific ZCTAs
-- paved over the most natural land between 2001 and 2011, and then analyze
-- if their claim frequency spiked in the following decade (2012-2022).

WITH SprawlOverTime AS (SELECT ZCTA20,
                               YEAR,
                               (PROP_DEV_LOWINTENSITY + PROP_DEV_MEDINTENSITY + PROP_DEV_HIINTENSITY) AS total_impervious,
                               -- Look at the previous recorded year's impervious surface percentage
                               LAG(PROP_DEV_LOWINTENSITY + PROP_DEV_MEDINTENSITY + PROP_DEV_HIINTENSITY)
                                   OVER (PARTITION BY ZCTA20 ORDER BY YEAR)                           AS prev_impervious
                        FROM nanda_land_cover
                        WHERE YEAR IN (2001, 2011)),
     RapidPavingZctas AS (SELECT ZCTA20,
                                 (total_impervious - prev_impervious) AS impervious_growth_pct
                          FROM SprawlOverTime
                          WHERE YEAR = 2011
                            AND prev_impervious IS NOT NULL
                            -- SYNTAX & PERFORMANCE FIX: Standardized logic away from an illegal HAVING clause
                            AND (total_impervious - prev_impervious) > 0.05),
     ClaimSpikes AS (SELECT z.zcta,
                            -- Claims before the rapid paving (1990-2000)
                            SUM(CASE WHEN c.yearOfLoss BETWEEN 1990 AND 2000 THEN 1 ELSE 0 END) AS claims_pre_paving,
                            -- Claims after the rapid paving (2012-2022)
                            SUM(CASE WHEN c.yearOfLoss BETWEEN 2012 AND 2022 THEN 1 ELSE 0 END) AS claims_post_paving
                     FROM fima_nfip_claims c
                              JOIN zip_to_zcta z ON c.clean_zip = z.zip_code
                         -- PERFORMANCE FIX (Predicate Pushdown): Only aggregate claims for the handful of ZCTAs that rapidly paved!
                              JOIN RapidPavingZctas r ON z.zcta = r.ZCTA20
                     WHERE z.zip_join_type = 'Zip matches ZCTA'
                     GROUP BY z.zcta)
SELECT r.ZCTA20                                AS `ZCTA Code`,
       ROUND(r.impervious_growth_pct * 100, 2) AS `Impervious Growth (%)`,
       c.claims_pre_paving                     AS `Claims (1990-2000)`,
       c.claims_post_paving                    AS `Claims (2012-2022)`,
       -- Calculate the multiplier of how much worse flooding got after development
       CASE
           WHEN c.claims_pre_paving = 0 THEN NULL -- Prevent divide by zero
           ELSE ROUND(c.claims_post_paving / c.claims_pre_paving, 2)
           END                                 AS `Post-Paving Claim Multiplier`
FROM RapidPavingZctas r
         JOIN ClaimSpikes c ON r.ZCTA20 = c.zcta
-- Only look at areas that actually had baseline claims to compare against
WHERE c.claims_pre_paving > 10
ORDER BY `Post-Paving Claim Multiplier` DESC;


-- =======================================================================================
-- QUERY 3: Inflation-Adjusted Macro Trends with Cross-Join Optimization - not working
-- =======================================================================================
-- If you STILL need to show absolute macro-trends over time, do not calculate CPI
-- dynamically per row. Cross join a single baseline CPI value and apply it at the sum.

WITH YearlyAgg AS (
    -- PERFORMANCE FIX: Aggregate the ~2.5 million rows down to ~40 rows BEFORE joining anything.
    SELECT yearOfLoss,
           COUNT(id)                                              AS total_claims,
           SUM(GREATEST(IFNULL(amountPaidOnBuildingClaim, 0), 0) +
               GREATEST(IFNULL(amountPaidOnContentsClaim, 0), 0)) AS nominal_payout
    FROM fima_nfip_claims
    WHERE yearOfLoss >= 1985
    GROUP BY yearOfLoss),
     BaselineCPI AS (
         -- Get exactly one value: the 2020 CPI
         SELECT cpi_value AS target_cpi
         FROM inflation_cpi
         WHERE cpi_year = 2020
         LIMIT 1)
SELECT y.yearOfLoss,
       y.total_claims,
       y.nominal_payout,

       -- Real 2020 Dollars Sum: (Nominal) * (Target CPI / Historical CPI)
       y.nominal_payout * (b.target_cpi / i.cpi_value) AS real_payout_2020_dollars

FROM YearlyAgg y
         JOIN inflation_cpi i ON y.yearOfLoss = i.cpi_year
         CROSS JOIN BaselineCPI b
ORDER BY y.yearOfLoss ASC;


