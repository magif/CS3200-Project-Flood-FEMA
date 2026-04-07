/*
I have made exports of the 5 main queries used to make charts and for analysis in the poster in the [Exports] Folder
 FROM THE FULL DATASET
 Analysis and charts were made using python in the [Analysis and Charts] Folder
 */


use g13_project;
-- use g13_project_test;
-- if using convenience sample data file
SET SESSION sql_mode = '';
SET SESSION net_read_timeout = 360;
SET SESSION net_write_timeout = 360;


-- Query 1 Macro trend
    /*
     "Are floods fundamentally getting worse,
     more expensive, and deeper over the last four decades,
     or is the data just being skewed by inflation and minor nuisance claims?"

     Query looks to physical, objective metrics. It attempts to measure the character of the flooding over time.
     */
-- Analyzing Claims Over Time
-- macro-level temporal trends
WITH CPI_2020 AS (
    -- Anchor our inflation math
    SELECT cpi_value AS baseline FROM inflation_cpi WHERE cpi_year = 2020 LIMIT 1)
SELECT c.yearOfLoss,
       COUNT(c.id)                                                                    AS total_claims,

       -- REAL DOLLARS: to view 40-year financial trends
       SUM(
               (GREATEST(IFNULL(c.amountPaidOnBuildingClaim, 0), 0) +
                GREATEST(IFNULL(c.amountPaidOnContentsClaim, 0), 0))
                   * (c2020.baseline / i.cpi_value)
       )                                                                              AS real_total_paid_out_2020,

       -- WATER DEPTH FIX: Let's track severe flooding (> 1 foot above the main floor)
       -- rather than a flawed mathematical average
       SUM(CASE WHEN c.waterDepth >= 12 THEN 1 ELSE 0 END) / COUNT(c.id)              AS pct_severe_above_ground_floods,

       -- BASEMENT FIX: Track how many claims were primarily basement/crawlspace floods
       SUM(CASE WHEN c.waterDepth < 0 THEN 1 ELSE 0 END) / COUNT(c.id)                AS pct_basement_floods,

       SUM(CASE WHEN c.primaryResidenceIndicator = 1 THEN 1 ELSE 0 END) / COUNT(c.id) AS pct_primary_residence

FROM fima_nfip_claims c
         JOIN inflation_cpi i ON c.yearOfLoss = i.cpi_year
         CROSS JOIN CPI_2020 c2020
WHERE c.yearOfLoss IS NOT NULL
  AND c.yearOfLoss >= 1985
GROUP BY c.yearOfLoss, i.cpi_value, c2020.baseline
ORDER BY c.yearOfLoss ASC;




-- Query 2 Data per archetype
   /*
     What is the true, inflation-adjusted average cost of flood damage to buildings across
     different geographical environments (highly urbanized vs. natural/wetlands vs. mixed),
     when we only look at claims where actual damage was paid out?

     SAMPLE BACKUP WILL NOT RETURN ANY RESULTS, THE SAMPLE LACKS THE DATA TO COMPLETE THIS QUERY
     BUT IT DOES WORK WITH FULL DATA.
     */
-- Pre-Correlation Aggregation
-- aggregates claims data up to the (ZCTA, Year)
-- joins it  with the NaNDA land cover data via crosswalk table
WITH AnnualCPI AS (
    --  extract annual CPI
    SELECT cpi_year,
           AVG(cpi_value) AS avg_cpi
    FROM inflation_cpi
    GROUP BY cpi_year),
     CPI_2020 AS (
         -- Isolate the 2020 baseline for the cross join
         SELECT avg_cpi
         FROM AnnualCPI
         WHERE cpi_year = 2020),
     ClaimStatsByZipYear AS (
         -- STEP 1: Pre-aggregate claims down to just Zip + Year summaries.
         SELECT clean_zip,
                yearOfLoss,
                COUNT(id)                                                                 AS claim_count,
                -- Track claims that actually involved building damage to fix the denominator
                SUM(CASE WHEN IFNULL(amountPaidOnBuildingClaim, 0) > 0 THEN 1 ELSE 0 END) AS building_claim_count,
                SUM(GREATEST(IFNULL(amountPaidOnBuildingClaim, 0), 0))                    AS total_building_paid
         FROM fima_nfip_claims
         WHERE yearOfLoss IS NOT NULL
           AND reportedZipCode IS NOT NULL
         GROUP BY clean_zip, yearOfLoss),
     MappedClaims AS (
         -- STEP 2: Join the much smaller aggregated table to the crosswalk and CPI tables
         SELECT x.zcta,
                c.yearOfLoss,
                c.claim_count,
                c.building_claim_count,
                c.total_building_paid,
                -- Convert to 2020 dollars: Nominal * (CPI_2020 / CPI_CurrentYear)
                (c.total_building_paid * (c2020.avg_cpi / cpi.avg_cpi)) AS total_building_paid_2020
         FROM ClaimStatsByZipYear c
                  JOIN zip_to_zcta x ON c.clean_zip = x.zip_code
                  JOIN AnnualCPI cpi ON c.yearOfLoss = cpi.cpi_year
                  CROSS JOIN CPI_2020 c2020
         WHERE x.zcta IS NOT NULL),
     ZCTACategory AS (
         -- STEP 3: Define the archetypes
         SELECT ZCTA20,
                YEAR,
                CASE
                    WHEN PROP_DEV_HIINTENSITY + PROP_DEV_MEDINTENSITY > 0.5 THEN 'Highly Developed (>50%)'
                    WHEN PROP_WOODYWET + PROP_HERBWET + PROP_DECIDUOUSFOREST > 0.5 THEN 'Highly Natural/Wetland (>50%)'
                    ELSE 'Mixed/Other'
                    END AS land_archetype
         FROM nanda_land_cover)
-- STEP 4: Final Join and math
SELECT zc.land_archetype,
       SUM(mc.claim_count)                                                        AS total_claims_in_archetype,
       -- claims for actual damaged building
       NULLIF(SUM(mc.building_claim_count), 0)                                    AS true_total_claims_in_archetyp,
       --  original flawed nominal calculation
       SUM(mc.total_building_paid) / SUM(mc.claim_count)                          AS avg_nominal_payout_all_claims,
       --  2020 inflation adjustment (still diluted by all claims)
       SUM(mc.total_building_paid_2020) / SUM(mc.claim_count)                     AS avg_2020_payout_all_claims,
       --  original flawed nominal calculation for damaged buildings
       SUM(mc.total_building_paid) / NULLIF(SUM(mc.building_claim_count), 0)      AS true_nominal_payout_all_claims,
       -- The TRUE 2020 average payout for buildings that were actually damaged
       SUM(mc.total_building_paid_2020) / NULLIF(SUM(mc.building_claim_count), 0) AS true_avg_2020_building_payout
FROM MappedClaims mc
         JOIN ZCTACategory zc ON mc.zcta = zc.ZCTA20 AND mc.yearOfLoss = zc.YEAR
GROUP BY zc.land_archetype
ORDER BY true_avg_2020_building_payout DESC;




-- Query 3 imperv dev buckets
/*
"Does living in a concrete jungle mean your flood damage is more expensive to fix?"

Specifically, it attempts to determine if there is a correlation between the percentage of "impervious surfaces"
in a zip code (concrete, asphalt, heavily developed land where water cannot soak into the ground)
and the average inflation-adjusted payout for a flood claim.

 SAMPLE BACKUP WILL NOT RETURN ANY RESULTS, THE SAMPLE LACKS THE DATA TO COMPLETE THIS QUERY
     BUT IT DOES WORK WITH FULL DATA.
Subqeury will return results however for sample
 */

--  chart: The development % buckets -
-- percentage of "impervious surface" (Low + Med + High Intensity Development) for every ZCTA in a recent year (2020)
--  pairs it with the average claim payout, and groups them into 10% "buckets"
-- scatter plot buckets x, avg payout per claim y
--
-- ------------------------------------------------------------------------
-- STEP 1: Early Aggregation
--  squish millions of individual claims down into just a few thousand summary rows FIRST.

WITH ZipYearAgg AS (SELECT clean_zip,
                           yearOfLoss,
                           COUNT(id)                                              AS claim_count,
                           -- Dropped total_policies here because it's meaningless without the non-claim policies
                           SUM(GREATEST(IFNULL(amountPaidOnBuildingClaim, 0), 0) +
                               GREATEST(IFNULL(amountPaidOnContentsClaim, 0), 0)) AS nominal_paid
                    FROM fima_nfip_claims
                    WHERE yearOfLoss >= 1985
                    GROUP BY clean_zip, yearOfLoss),
     ZctaYearAgg AS (SELECT x.zcta,
                            z.yearOfLoss,
                            SUM(z.claim_count)  AS total_claims,
                            SUM(z.nominal_paid) AS nominal_paid
                     FROM ZipYearAgg z
                              JOIN zip_to_zcta x ON z.clean_zip = x.zip_code
                     GROUP BY x.zcta, z.yearOfLoss),
     LandCoverBuckets AS (SELECT ZCTA20,
                                 YEAR,
                                 ROUND((PROP_DEV_LOWINTENSITY + PROP_DEV_MEDINTENSITY + PROP_DEV_HIINTENSITY) * 10) *
                                 10 AS impervious_pct_bucket
                          FROM nanda_land_cover
                          WHERE YEAR >= 1985),
-- Isolate the 2020 CPI value cleanly
     CPI_2020 AS (SELECT cpi_value AS cpi_2020_baseline
                  FROM inflation_cpi
                  WHERE cpi_year = 2020
                  LIMIT 1)
SELECT z.yearOfLoss            AS `Year`,
       l.impervious_pct_bucket AS `Percent Impervious Surface`,
       SUM(z.total_claims)     AS `Total Claims`,

       -- Average payout per FILED claim (Building + Contents combined)
       (SUM(z.nominal_paid) * (c2020.cpi_2020_baseline / i.cpi_value)) / NULLIF(SUM(z.total_claims), 0)
                               AS `Avg Payout per Claim (2020 Dollars)`,

       -- Total payouts adjusted to 2020 dollars
       SUM(z.nominal_paid) * (c2020.cpi_2020_baseline / i.cpi_value)
                               AS `Total Payouts (2020 Dollars)`

FROM ZctaYearAgg z
         JOIN LandCoverBuckets l ON z.zcta = l.ZCTA20 AND z.yearOfLoss = l.YEAR
         JOIN inflation_cpi i ON z.yearOfLoss = i.cpi_year
         CROSS JOIN CPI_2020 c2020
GROUP BY z.yearOfLoss, l.impervious_pct_bucket, i.cpi_value, c2020.cpi_2020_baseline
ORDER BY z.yearOfLoss DESC, l.impervious_pct_bucket;
/*
 some analysis

some
Extreme Events Drive Payout Spikes:
 The data shows massive spikes in specific years,
 corresponding to major national disasters. katrina 2005
    - 2005 was the most catastrophic year in the dataset, with $23.15 billion in total payouts (in 2020 dollars) and 276,326 claims.
    - Other high-impact years include 2017 ($11.18 billion), 2012 ($10.62 billion), and 2016 ($4.79 billion).
    - 2022 also stands out with a high average payout per claim of $77,284, nearly double the average of the previous year.

 Development Level Correlates with Claim Severity:
 While moderately developed areas (10-20% impervious surface) account for the highest total volume of claims,
 highly developed areas see more expensive individual claims.
    - The 10% impervious surface bucket has the highest total payouts overall at $15.56 billion across all years.
    - The Average Payout per Claim generally increases with the percentage of impervious surface.
        For example, claims in areas with 70% impervious surface average $59,750, compared to $28,840 in areas with 0% impervious surface.

 Claim Volume Concentration:
 A large portion of the total claims and payouts are concentrated
 in areas with low-to-moderate development (0-20% impervious surface),
 likely reflecting the higher density of residential properties in these zones.
    - Areas with 10% impervious surface alone account for over 416,000 claims.
    - Areas with 0% impervious surface follow with 318,269 claims.
 */




-- Query 4 flash v river flood
-- 2nd chart: Flash Flooding vs. River Flooding
/*
 "Does paving over nature change the way an area floods,
 turning traditional river overflows into concrete-trapped flash floods?"

 attempts to answer this by looking at the ratio of "Rain Accumulation" claims versus "River Overflow" claims,
 comparing areas that are heavily paved against areas that are mostly natural,
 and calculating the percentage makeup of each disaster type within those specific environments.

 ie Urban sprawl doesn't just cause more flooding; it causes different types of flooding.
 Flash floods (FEMA Code 4: Accumulation of rainfall) happen when concrete prevents drainage
 River floods (FEMA Code 2) happen everywhere.


 SAMPLE BACKUP WILL NOT RETURN ANY RESULTS, THE SAMPLE LACKS THE DATA TO COMPLETE THIS QUERY
     BUT IT DOES WORK WITH FULL DATA.
1st & 3rd Subqeury will return results however for sample
 */

WITH ZipCauseAgg AS (SELECT clean_zip,
                            yearOfLoss,
                            causeOfDamage,
                            COUNT(id) as claim_count
                     FROM fima_nfip_claims
                     WHERE causeOfDamage IN ('2', '4') -- 2 = River overflow, 4 = Rainfall Accumulation
                     GROUP BY clean_zip, yearOfLoss, causeOfDamage),
     ZctaCauseAgg AS (SELECT x.zcta, z.yearOfLoss, z.causeOfDamage, SUM(z.claim_count) as claims
                      FROM ZipCauseAgg z
                               JOIN zip_to_zcta x ON z.clean_zip = x.zip_code
                      GROUP BY x.zcta, z.yearOfLoss, z.causeOfDamage),
     LandArchetypes AS (SELECT ZCTA20,
                               YEAR,
                               CASE
                                   WHEN PROP_DEV_HIINTENSITY + PROP_DEV_MEDINTENSITY > 0.4 THEN 'High Concrete'
                                   WHEN PROP_WOODYWET + PROP_HERBWET + PROP_DECIDUOUSFOREST > 0.4 THEN 'High Natural'
                                   ELSE 'Mixed'
                                   END AS environment_type
                        FROM nanda_land_cover),
-- Store your raw aggregates in a temporary result
     RawIncidents AS (SELECT l.environment_type,
                             CASE
                                 WHEN c.causeOfDamage = '2' THEN 'River/Stream Overflow'
                                 ELSE 'Flash Flood (Rain Accumulation)'
                                 END       AS flood_type,
                             SUM(c.claims) as total_incidents
                      FROM ZctaCauseAgg c
                               JOIN LandArchetypes l ON c.zcta = l.ZCTA20 AND c.yearOfLoss = l.YEAR
                      WHERE l.environment_type != 'Mixed'
                      GROUP BY l.environment_type, flood_type)
-- Use a window function to calculate the percentage makeup
SELECT environment_type,
       flood_type,
       total_incidents,
       ROUND((total_incidents * 100.0) / SUM(total_incidents) OVER (PARTITION BY environment_type),
             1) AS percent_of_environment
FROM RawIncidents
ORDER BY environment_type, flood_type;

/*
 short analysis
 flash flood (rain accumulation) has more incidents in high concrete areas vs river/stream overflow
 Both bars will be exactly the same height (100%),  stripping away the distraction that "High Concrete has way more claims overall."
    "High Concrete" bar will have a larger relative chunk of (Flash Floods),
    while the "High Natural" bar has more (River Overflow). (although do consider majority of land is not directly next to rivers)
 */





-- Query 5 Controlling for the Storms

/*
"If we force the weather to be a constant, which type of environment is naturally
    the most expensive to repair after a flood?"

The core problem this query solves is the "missing variable" of rainfall data.
If an urban area has $50,000 average payouts and a forested area has $20,000 average payouts,
you don't know if the urban area is inherently more vulnerable due to concrete,
or if it just happened to get hit by much worse storms over the last 30 years.

By grouping the claims by the exact same eventDesignationNumber (e.g., Hurricane Harvey, Superstorm Sandy),
the query uses the storm itself as a control variable.


 SAMPLE BACKUP WILL NOT RETURN ANY RESULTS, THE SAMPLE LACKS THE DATA TO COMPLETE THIS QUERY
     BUT IT DOES WORK WITH FULL DATA.
4th Subqeury will return results however for sample
 */

-- 3rd chart: Controlling for the Storms (The Proxy for Rainfall Data)
-- Since we don't have precipitation data cuz the noaa data is way harder to work with w/o dealig with GIS software
-- use eventDesignationNumber to group claims by the exact same storm.
-- This acts as our control variable
-- grouped bar chart comparing average payouts between different environments, grouped by major storm events.

WITH MajorStorms AS (
    -- STEP 1: Identify storms that were actually "Major" across ALL areas
    -- This prevents us from deleting effective environments later.
    SELECT COALESCE(NULLIF(TRIM(eventDesignationNumber), ''), NULLIF(TRIM(floodEvent), '')) AS storm_id
    FROM fima_nfip_claims
    WHERE COALESCE(NULLIF(TRIM(eventDesignationNumber), ''), NULLIF(TRIM(floodEvent), '')) IS NOT NULL
      AND (floodEvent IS NULL OR floodEvent NOT IN (
                                                    'Flooding', 'Storm', 'Not a named storm', 'Thunderstorms',
                                                    'Severe flooding', 'Torrential rain', 'Severe Storms and Flooding'))
    GROUP BY COALESCE(NULLIF(TRIM(eventDesignationNumber), ''), NULLIF(TRIM(floodEvent), ''))
    HAVING COUNT(id) > 500 -- The storm must have caused at least 500 claims total
),
     EventZipAgg AS (
         -- STEP 2: Pre-aggregate only for our Major Storms
         SELECT COALESCE(NULLIF(TRIM(eventDesignationNumber), ''), NULLIF(TRIM(floodEvent), '')) AS storm_id,
                MAX(floodEvent)                                                                  AS friendly_name,
                yearOfLoss,
                clean_zip,
                COUNT(id)                                                                        AS total_claims,
                -- Only count claims that had actual building damage for our denominator
                SUM(CASE WHEN IFNULL(amountPaidOnBuildingClaim, 0) > 0 THEN 1 ELSE 0 END)        AS building_claim_count,
                SUM(GREATEST(IFNULL(amountPaidOnBuildingClaim, 0), 0))                           AS total_building_paid
         FROM fima_nfip_claims
         WHERE COALESCE(NULLIF(TRIM(eventDesignationNumber), ''), NULLIF(TRIM(floodEvent), '')) IN
               (SELECT storm_id FROM MajorStorms)
         GROUP BY 1, 3, 4),
     EventZctaAgg AS (
         -- STEP 3: Crosswalk Join
         SELECT e.storm_id,
                MAX(e.friendly_name)        AS floodEventName,
                e.yearOfLoss,
                x.zcta,
                SUM(e.total_claims)         as total_claims,
                SUM(e.building_claim_count) as building_claim_count,
                SUM(e.total_building_paid)  as total_building_paid
         FROM EventZipAgg e
                  JOIN zip_to_zcta x ON e.clean_zip = x.zip_code
         GROUP BY e.storm_id, e.yearOfLoss, x.zcta),
     LandArchetypes AS (
         -- STEP 4: Land Archetypes
         SELECT ZCTA20,
                YEAR,
                CASE
                    WHEN PROP_WOODYWET + PROP_HERBWET >= 0.25 THEN '1. Wetland Buffer (High Absorption)'
                    WHEN PROP_DEV_HIINTENSITY + PROP_DEV_MEDINTENSITY >= 0.5 THEN '2. Dense Urban (Concrete Shield)'
                    WHEN PROP_DEV_LOWINTENSITY + PROP_DEV_MEDINTENSITY + PROP_DEV_HIINTENSITY >= 0.5
                        THEN '3. Suburban Sprawl'
                    WHEN PROP_DECIDUOUSFOREST + PROP_EVERGREENFOREST + PROP_MIXEDFOREST + PROP_SHRUBSCRUB >= 0.5
                        THEN '4. Forest/Wildland (Natural Sponge)'
                    WHEN PROP_PASTUREHAY + PROP_CULTCROPS >= 0.5 THEN '5. Agricultural/Rural (Moderate Runoff)'
                    ELSE '6. Mixed/Transition Zone'
                    END AS environment_type
         FROM nanda_land_cover),
     CPI_2020 AS (SELECT cpi_value AS baseline FROM inflation_cpi WHERE cpi_year = 2020 LIMIT 1)
-- STEP 5: Final Join & Real Math
SELECT e.storm_id,
       e.floodEventName,
       e.yearOfLoss,
       l.environment_type,
       SUM(e.total_claims)                                           as total_incidents,

       -- Calculate True Average Payout in 2020 Dollars
       (SUM(e.total_building_paid) * (c2020.baseline / i.cpi_value)) /
       NULLIF(SUM(e.building_claim_count), 0)                        AS avg_building_payout_2020_dollars,
       (SUM(e.total_building_paid) * (c2020.baseline / i.cpi_value)) AS total_building_payout_2020_dollars

FROM EventZctaAgg e
         JOIN LandArchetypes l ON e.zcta = l.ZCTA20 AND e.yearOfLoss = l.YEAR
         JOIN inflation_cpi i ON e.yearOfLoss = i.cpi_year
         CROSS JOIN CPI_2020 c2020
GROUP BY e.storm_id, e.floodEventName, e.yearOfLoss, l.environment_type, i.cpi_value, c2020.baseline
ORDER BY e.storm_id, l.environment_type;

/*
 short analysis
 yes this query is inherently flawed as the control variable: A named storm does not distribute water evenly.
 our methodology cannot definitively prove that the urban payouts are higher because of the concrete.
 They might just be higher because coastal urban centers take the direct, Category 4 hit from the ocean,
 while the forests get the Category 1 leftovers a day later.

 But noaa data is way more dificult to work with than expected, so we're this is closest control within our data.'
 */