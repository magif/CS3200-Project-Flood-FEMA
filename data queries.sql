use g13_project;
SET SESSION sql_mode = '';
SET SESSION net_read_timeout = 360;
SET SESSION net_write_timeout = 360;

-- Analyzing Claims Over Time
-- macro-level temporal trends
SELECT yearOfLoss,
       COUNT(id)                                                                  AS total_claims,
       -- Filtering out the negative uncashed checks using GREATEST
       SUM(GREATEST(IFNULL(amountPaidOnBuildingClaim, 0), 0) +
           GREATEST(IFNULL(amountPaidOnContentsClaim, 0), 0))                     AS total_paid_out,
       AVG(waterDepth)                                                            AS average_water_depth_inches,
       -- What percentage of claims were primary residences?
       SUM(CASE WHEN primaryResidenceIndicator = 1 THEN 1 ELSE 0 END) / COUNT(id) AS pct_primary_residence
FROM fima_nfip_claims
WHERE yearOfLoss IS NOT NULL
  AND yearOfLoss >= 1985 -- Aligning with NaNDA's start year
GROUP BY yearOfLoss
ORDER BY yearOfLoss ASC;


-- Pre-Correlation Aggregation
-- aggregates claims data up to the (ZCTA, Year)
-- joins it  with the NaNDA land cover data via crosswalk table

-- zip from fima data cleaned to remove postal specific after -  9 rows exist, ughhh
-- + removes the rows without a zip code to reference, ie a lot
-- also the 60 rows of <5 digit zips
WITH CleanedClaims AS (SELECT LEFT(TRIM(reportedZipCode), 5)                    AS clean_zip,
                              yearOfLoss,
                              id,
                              GREATEST(IFNULL(amountPaidOnBuildingClaim, 0), 0) AS building_paid,
                              GREATEST(IFNULL(amountPaidOnContentsClaim, 0), 0) AS contents_paid,
                              waterDepth
                       FROM fima_nfip_claims
                       WHERE yearOfLoss IS NOT NULL),
     AggregatedClaims AS (
         -- Route the cleaned ZIP codes through the crosswalk to get the ZCTA
         SELECT x.zcta                                 AS mapped_zcta,
                c.yearOfLoss                           AS claim_year,
                COUNT(c.id)                            AS total_claims,
                SUM(c.building_paid + c.contents_paid) AS total_damage_paid,
                AVG(c.waterDepth)                      AS avg_water_depth
         FROM CleanedClaims c
                  JOIN
              zip_to_zcta x ON c.clean_zip = x.zip_code
         WHERE x.zcta IS NOT NULL
         GROUP BY x.zcta,
                  c.yearOfLoss)
-- join the aggregated claims to the Land Cover dataset
SELECT lc.YEAR,
       lc.ZCTA20,
       -- Dependent Variables (Claims)
       IFNULL(ac.total_claims, 0)      AS total_claims,
       IFNULL(ac.total_damage_paid, 0) AS total_damage_paid,
       ac.avg_water_depth,

       -- Independent Variables (Land Cover Proportions)
       lc.PROP_DEV_HIINTENSITY,
       lc.PROP_DEV_MEDINTENSITY,
       lc.PROP_DEV_OPENSPACE,
       lc.PROP_OPENWATER,
       lc.PROP_WOODYWET,
       lc.PROP_HERBWET
FROM nanda_land_cover lc
         LEFT JOIN
     AggregatedClaims ac ON lc.ZCTA20 = ac.mapped_zcta AND lc.YEAR = ac.claim_year
ORDER BY lc.YEAR, lc.ZCTA20;

-- Identifying High-Risk vs. High-Resilience Areas
-- categorizes ZCTAs into "Highly Developed" vs "Highly Natural (Wetlands/Forests)"
-- and compares their average payout per claim.
WITH ClaimStatsByZipYear AS (
-- STEP 1: Pre-aggregate claims down to just Zip + Year summaries.
-- stops MySQL from trying to evaluate string functions on every single row during the JOIN.
    SELECT LEFT(TRIM(reportedZipCode), 5)                         AS clean_zip,
           yearOfLoss,
           COUNT(id)                                              AS claim_count,
           SUM(GREATEST(IFNULL(amountPaidOnBuildingClaim, 0), 0)) AS total_building_paid
    FROM fima_nfip_claims
    WHERE yearOfLoss IS NOT NULL
      AND reportedZipCode IS NOT NULL
    GROUP BY LEFT(TRIM(reportedZipCode), 5), yearOfLoss),
     MappedClaims AS (
-- STEP 2: Join the much smaller aggregated table to the crosswalk
         SELECT x.zcta,
                c.yearOfLoss,
                c.claim_count,
                c.total_building_paid
         FROM ClaimStatsByZipYear c
                  JOIN
              zip_to_zcta x ON c.clean_zip = x.zip_code
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
       SUM(mc.claim_count)                               AS total_claims_in_archetype,
       SUM(mc.total_building_paid) / SUM(mc.claim_count) AS avg_payout_per_claim
FROM MappedClaims mc
         JOIN
     ZCTACategory zc ON mc.zcta = zc.ZCTA20 AND mc.yearOfLoss = zc.YEAR
GROUP BY zc.land_archetype
ORDER BY avg_payout_per_claim DESC;



--  Queries for Visualizations

-- 1st chart: The development % buckets
-- percentage of "impervious surface" (Low + Med + High Intensity Development) for every ZCTA in a recent year (2020)
--  pairs it with the average claim payout, and groups them into 10% "buckets"
-- scatter plot buckets x, avg payout per claim y
--

WITH ZipAgg AS (
    -- Aggregate early to prevent timeouts
    SELECT LEFT(TRIM(reportedZipCode), 5)                         AS clean_zip,
           COUNT(id)                                              AS claim_count,
           SUM(GREATEST(IFNULL(amountPaidOnBuildingClaim, 0), 0)) AS total_paid
    FROM fima_nfip_claims
    WHERE yearOfLoss = 2020 -- Filter to a specific recent year, else we do chronological errors
    GROUP BY clean_zip),
     ZctaAgg AS ( -- route the postal ZIP codes  crosswalk table to  ZCTA boundaries.
         SELECT x.zcta,
                SUM(z.claim_count) as claims,
                SUM(z.total_paid)  as payouts -- Bc many ZIP codes can map to a single ZCTA
         FROM ZipAgg z
                  JOIN zip_to_zcta x ON z.clean_zip = x.zip_code
         GROUP BY x.zcta),
     ImperviousBuckets AS (SELECT ZCTA20,
                                  -- Calculate total concrete/asphalt and round to nearest 10% for easy charting
                                  ROUND((PROP_DEV_LOWINTENSITY + PROP_DEV_MEDINTENSITY + PROP_DEV_HIINTENSITY) * 10) *
                                  10 AS impervious_pct_bucket
                           -- If a ZCTA is 42% concrete, X by 10 makes it 4.2. Rounding it makes it 4. X by 10 makes it 40
                           FROM nanda_land_cover
                           WHERE YEAR = 2020 -- change this number and the one above to get year by year stats, this query is static
     )
SELECT i.impervious_pct_bucket        AS `Percent Impervious Surface`,
       SUM(z.claims)                  AS `Total Claims`,
       SUM(z.payouts) / SUM(z.claims) AS `Average Payout Per Claim ($)`,
       SUM(z.payouts)                 AS 'Total Payouts'
FROM ImperviousBuckets i
         JOIN ZctaAgg z ON i.ZCTA20 = z.zcta
GROUP BY i.impervious_pct_bucket
ORDER BY i.impervious_pct_bucket;
/*
 translated claims (ZctaAgg) and join them to the concrete buckets (ImperviousBuckets).
 sum up all the claims that landed in the 10% bucket, sum up all their payouts,
 and then divide the two to get the true average payout for that specific level of urban sprawl.
 */

/*
 Anyways some analysis: concrete changes the behavior of the flood
 initial hypothesis [that more concrete equals higher average claim payouts] was wrong, oop, a good thing though
 DON'T CONFUSE severity (average payout) with frequency (number of claims).
 urban sprawl doesn't necessarily create catastrophic payouts, but it creates a massive volume of low-level claims
 Right now, our chart is skewed because there is simply way more 10% concrete land in the US than 100% concrete land.

 If we can show that 100% concrete ZCTAs generate more claims per 1,000 homes than 10% concrete ZCTAs, we'd have our smoking gun.
 but thats like a lot more work soo, Use this Chart 1 data to set the stage about how complex the hydrology
 Chart 3 controls for the storm events, which strips out all this noise and gives a more control over area variables,
 theres just more claims for higher concrete areas when major flood events occur, denser more population to make said claims


 More on severity:
 High Concrete (80-100%): This is a dense urban center.
 Concrete creates flash floods because storm drains get overwhelmed.
 But what does an urban flash flood actually look like?
 It's usually 3 inches of dirty water backing up into a guy's basement.
 It's an annoying $12,000 fix. It's like a hydrological paper cut.

 Low Concrete (0-10%): This is rural land, forests, and wetlands.
 When a house out here floods, it's not because of a clogged street drain.
 It's because a river breached its banks or a hurricane pushed a 12-foot storm surge into a coastal marsh.
 The house doesn't get 3 inches of water; it gets washed off its foundation.
 It's a catastrophic, $50,000+ in damages
 */


-- 2nd chart: Flash Flooding vs. River Flooding
/*
 Urban sprawl doesn't just cause more flooding; it causes different types of flooding.
 Flash floods (FEMA Code 4: Accumulation of rainfall) happen when concrete prevents drainage
 River floods (FEMA Code 2) happen everywhere.
 */
-- Visual: Two bars for each environment archetype. One showing the % of floods caused by rainfall accumulation,
-- and one showing the % caused by river overflow.

-- x = flood type
--  group value by enviroment type
-- y = total incidents (sum)

-- pie chart instead actuall
-- group by envirotype
-- value - total incidenct or % total
-- flood type
WITH ZipCauseAgg AS (SELECT LEFT(TRIM(reportedZipCode), 5) AS clean_zip,
                            yearOfLoss,
                            causeOfDamage,
                            COUNT(id)                      as claim_count
                     FROM fima_nfip_claims
                     WHERE causeOfDamage IN ('2', '4') -- 2 = River overflow, 4 = Rainfall Accumulation (Flash Flooding)
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
                                   ELSE 'Mixed' END AS environment_type
                        FROM nanda_land_cover)
SELECT l.environment_type,
       CASE
           WHEN c.causeOfDamage = '2' THEN 'River/Stream Overflow'
           ELSE 'Flash Flood (Rain Accumulation)' END AS flood_type,
       SUM(c.claims)                                  as total_incidents
FROM ZctaCauseAgg c
         JOIN LandArchetypes l ON c.zcta = l.ZCTA20 AND c.yearOfLoss = l.YEAR
WHERE l.environment_type != 'Mixed'
GROUP BY l.environment_type, flood_type
ORDER BY l.environment_type, flood_type;
--
/*
 short analysis
 flash flood (rain accumulation) has more incidents in high concrete areas vs river/stream overflow
 natural areas just have less incident claims from both are relatively equal compareds to diff in concrete zones
 */


-- 3rd chart: Controlling for the Storms (The Proxy for Rainfall Data)
-- Since we don't have precipitation data cuz the noaa data is way harder to work with w/o dealig with GIS software
-- use eventDesignationNumber to group claims by the exact same storm.
-- This acts as our control variable
-- grouped bar chart comparing average payouts between different environments, grouped by major storm events.
WITH EventZipAgg AS (
    -- Pre-aggregate to Zip and Event Level to save memory.
    -- COALESCE grabs the official Event Number. If missing, it grabs the Event Name.
    SELECT COALESCE(
                   NULLIF(TRIM(eventDesignationNumber), ''),
                   NULLIF(TRIM(floodEvent), '')
           )                                                      AS storm_id,
           MAX(floodEvent)                                        AS friendly_name,
           yearOfLoss,
           LEFT(TRIM(reportedZipCode), 5)                         AS clean_zip,
           COUNT(id)                                              AS claim_count,
           SUM(GREATEST(IFNULL(amountPaidOnBuildingClaim, 0), 0)) AS total_paid
    FROM fima_nfip_claims
    WHERE
      -- Rule 1: Must have at least one identifier
        COALESCE(NULLIF(TRIM(eventDesignationNumber), ''), NULLIF(TRIM(floodEvent), '')) IS NOT NULL
      -- Rule 2: Explicitly reject generic "bucket" terms that group unrelated storms together
      AND (floodEvent IS NULL OR floodEvent NOT IN (
                                                    'Flooding', 'Storm', 'Not a named storm', 'Thunderstorms',
                                                    'Severe flooding', 'Torrential rain', 'Severe Storms and Flooding'
        ))
    GROUP BY COALESCE(NULLIF(TRIM(eventDesignationNumber), ''), NULLIF(TRIM(floodEvent), '')),
             yearOfLoss,
             clean_zip),
     EventZctaAgg AS (SELECT e.storm_id,
                             MAX(e.friendly_name) AS floodEventName,
                             e.yearOfLoss,
                             x.zcta,
                             SUM(e.claim_count)   as claims,
                             SUM(e.total_paid)    as payouts
                      FROM EventZipAgg e
                               JOIN zip_to_zcta x ON e.clean_zip = x.zip_code
                      GROUP BY e.storm_id, e.yearOfLoss, x.zcta),
     LandArchetypes AS (
         -- Think of these categories as a spectrum of "Hydrological Sponges" vs "Concrete Shields".
         SELECT ZCTA20,
                YEAR,
                CASE
                    -- WETLANDS: The Ultimate Sponge for Water.
                    WHEN PROP_WOODYWET + PROP_HERBWET >= 0.25 THEN '1. Wetland Buffer (High Absorption)'
                    -- THE CONCRETE ZONE: Over 50% solid pavement or heavy dense housing.
                    WHEN PROP_DEV_HIINTENSITY + PROP_DEV_MEDINTENSITY >= 0.5 THEN '2. Dense Urban (Concrete Shield)'
                    -- SUBURBAN SPRAWL: The asphalt spiderweb.
                    WHEN PROP_DEV_LOWINTENSITY + PROP_DEV_MEDINTENSITY + PROP_DEV_HIINTENSITY >= 0.5
                        THEN '3. Suburban Sprawl'
                    -- NATURAL SPONGE: Deep roots and un-compacted soil.
                    WHEN PROP_DECIDUOUSFOREST + PROP_EVERGREENFOREST + PROP_MIXEDFOREST + PROP_SHRUBSCRUB >= 0.5
                        THEN '4. Forest/Wildland (Natural Sponge)'
                    -- AGRICULTURAL: Farm fields.
                    WHEN PROP_PASTUREHAY + PROP_CULTCROPS >= 0.5 THEN '5. Agricultural/Rural (Moderate Runoff)'
                    -- THE SEMI-DEVELOPED: Everything else.
                    ELSE '6. Mixed/Transition Zone'
                    END AS environment_type
         FROM nanda_land_cover)
SELECT e.storm_id,
       e.floodEventName,
       l.environment_type,
       SUM(e.claims)                  as total_claims,
       SUM(e.payouts) / SUM(e.claims) as avg_payout
FROM EventZctaAgg e
         JOIN LandArchetypes l ON e.zcta = l.ZCTA20 AND e.yearOfLoss = l.YEAR
GROUP BY e.storm_id, e.floodEventName, l.environment_type
-- Filter for major events with significant sample sizes to avoid statistical noise
HAVING SUM(e.claims) > 100
ORDER BY floodEventName, l.environment_type;

/*
 challenge the basic assumption that "concrete = highest payouts."
 Concrete causes the highest volume of individual flooding incidents (flash floods).
 But building in swamps and living at the bottom of the city's concrete runoff pipe
 causes the most expensive, catastrophic damage.
 */