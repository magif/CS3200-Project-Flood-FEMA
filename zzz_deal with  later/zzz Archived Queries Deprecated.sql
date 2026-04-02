/*
 like chart 1  but now inflation adjusted
  multiple charts to gain from ths
 */
WITH ZctaAgg AS (
    -- Grouping our fast, pre-calculated View data
    SELECT x.zcta,
           COUNT(v.id)                 AS total_claims,
           SUM(v.policyCount)          AS total_policies,
           SUM(v.real_total_paid_2020) AS total_real_payouts
    FROM vw_fima_claims_real_dollars v
             JOIN zip_to_zcta x ON v.clean_zip = x.zip_code
    WHERE v.yearOfLoss = 2020
    GROUP BY x.zcta),
     ImperviousBuckets AS (SELECT ZCTA20,
                                  ROUND((PROP_DEV_LOWINTENSITY + PROP_DEV_MEDINTENSITY + PROP_DEV_HIINTENSITY) * 10) *
                                  10 AS impervious_pct_bucket
                           FROM nanda_land_cover
                           WHERE YEAR = 2020)
SELECT i.impervious_pct_bucket                             AS `Percent Impervious Surface`,
       SUM(z.total_claims)                                 AS `Total Claims`,
       (SUM(z.total_claims) / SUM(z.total_policies)) * 100 AS `Claims per 100 Policies`,
       SUM(z.total_real_payouts) / SUM(z.total_claims)     AS `Average Payout (2020 Dollars)`,
       SUM(z.total_real_payouts)                           AS 'Total Payouts (2020 Dollars)'
FROM ImperviousBuckets i
         JOIN ZctaAgg z ON i.ZCTA20 = z.zcta
GROUP BY i.impervious_pct_bucket
ORDER BY i.impervious_pct_bucket;
/*
 some analysis
 Claims per 100 Policies is frequency rate controls for population density,
 levels the playing field we can actually compare a sprawling rural county to a dense downtown block.

 Our initial hypothesis " As a specific neighborhood's percentage of impervious surface increases, there is a statistically verifiable spike in flood insurance claims"
 is blown up by this data above
 */

-- original chart 1
WITH ZipAgg AS (
    -- Aggregate early to prevent timeouts
    SELECT clean_zip,
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


-- orginal chart 2
WITH ZipCauseAgg AS (SELECT clean_zip,
                            yearOfLoss,
                            causeOfDamage,
                            COUNT(id) as claim_count
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


-- deprecated as bad
-- 3rd chart: Controlling for the Storms (The Proxy for Rainfall Data)
WITH EventZipAgg AS (
    -- Pre-aggregate to Zip and Event Level to save memory.
    -- COALESCE grabs the official Event Number. If missing, it grabs the Event Name.
    SELECT COALESCE(
                   NULLIF(TRIM(eventDesignationNumber), ''),
                   NULLIF(TRIM(floodEvent), '')
           )                                                      AS storm_id,
           MAX(floodEvent)                                        AS friendly_name,
           yearOfLoss,
           clean_zip,
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


-- 1st chart: The development % buckets -- deprecated for better ver

WITH ZipAgg AS (
    -- Aggregate early to prevent timeouts
    SELECT clean_zip,
           COUNT(id)                                              AS claim_count,
           SUM(GREATEST(IFNULL(policyCount, 1), 1))               AS total_policies_in_area, -- Prevent divide by zero
           SUM(GREATEST(IFNULL(amountPaidOnBuildingClaim, 0), 0)) AS total_paid
    FROM fima_nfip_claims
    WHERE yearOfLoss = 2020 -- Filter to a specific recent year, else we do chronological errors
    GROUP BY clean_zip),
     ZctaAgg AS ( -- route the postal ZIP codes  crosswalk table to  ZCTA boundaries.
         SELECT x.zcta,
                SUM(z.claim_count)          as claims,
                SUM(z.total_paid)           as payouts, -- Bc many ZIP codes can map to a single ZCTA
                SUM(total_policies_in_area) as policies
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
SELECT i.impervious_pct_bucket                 AS `Percent Impervious Surface`,
       SUM(z.claims)                           AS `Total Claims`,
       SUM(z.payouts) / SUM(z.claims)          AS `Average Payout Per Claim ($)`,
       SUM(z.payouts)                          AS 'Total Payouts',
       -- NEW METRIC: Claim Frequency Rate (Claims per 100 policies)
       (SUM(z.claims) / SUM(z.policies)) * 100 AS `Claims per 100 Policies`

FROM ImperviousBuckets i
         JOIN ZctaAgg z ON i.ZCTA20 = z.zcta
GROUP BY i.impervious_pct_bucket
ORDER BY i.impervious_pct_bucket;

