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

-- zip from fima data cleaned to remove postal specific after - 
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
/*
WITH ZCTACategory AS (
    SELECT 
        ZCTA20,
        YEAR,
        CASE 
            WHEN PROP_DEV_HIINTENSITY + PROP_DEV_MEDINTENSITY > 0.5 THEN 'Highly Developed (>50%)'
            WHEN PROP_WOODYWET + PROP_HERBWET + PROP_DECIDUOUSFOREST > 0.5 THEN 'Highly Natural/Wetland (>50%)'
            ELSE 'Mixed/Other'
        END AS land_archetype
    FROM nanda_land_cover
)
SELECT 
    zc.land_archetype,
    COUNT(DISTINCT c.id) AS total_claims_in_archetype,
    SUM(GREATEST(IFNULL(c.amountPaidOnBuildingClaim, 0), 0)) / COUNT(DISTINCT c.id) AS avg_payout_per_claim
FROM 
    fima_nfip_claims c
JOIN 
    zip_to_zcta x ON LEFT(TRIM(c.reportedZipCode), 5) = x.zip_code
JOIN 
    ZCTACategory zc ON x.zcta = zc.ZCTA20 AND c.yearOfLoss = zc.YEAR
GROUP BY 
    zc.land_archetype
ORDER BY 
    avg_payout_per_claim DESC;
    */


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
