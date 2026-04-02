use g13_project;

-- Upgrading your Macro-Level Trends Query to use Real Dollars (2020 Baseline)
WITH BaseCPI AS (
    -- Grab the CPI for our target year (2020) to act as our baseline multiplier
    SELECT AVG(cpi_value) as cpi_2020
    FROM inflation_cpi
    WHERE cpi_year = 2020)
SELECT c.yearOfLoss,
       COUNT(c.id)                                              AS total_claims,

       -- Nominal (Unadjusted) Payout
       SUM(GREATEST(IFNULL(c.amountPaidOnBuildingClaim, 0), 0) +
           GREATEST(IFNULL(c.amountPaidOnContentsClaim, 0), 0)) AS nominal_paid_out,

       -- Real (Inflation-Adjusted) Payout
       -- Formula: Nominal Amount * (Target Year CPI / Loss Year CPI)
       SUM(
               (GREATEST(IFNULL(c.amountPaidOnBuildingClaim, 0), 0) +
                GREATEST(IFNULL(c.amountPaidOnContentsClaim, 0), 0))
                   * (b.cpi_2020 / i.cpi_value)
       )                                                        AS real_paid_out_2020_dollars

FROM fima_nfip_claims c
         JOIN inflation_cpi i ON c.yearOfLoss = i.cpi_year
         CROSS JOIN BaseCPI b
WHERE c.yearOfLoss IS NOT NULL
  AND c.yearOfLoss >= 1985
GROUP BY c.yearOfLoss
ORDER BY c.yearOfLoss ASC;


-- Aggregating total financial loss by County to aid municipal planners
SELECT f.`State Name`,
       f.`County Name`,
       COUNT(c.id)                                              AS total_claims,
       SUM(GREATEST(IFNULL(c.amountPaidOnBuildingClaim, 0), 0)) AS total_building_damage
FROM fima_nfip_claims c
         JOIN fips_code_refs f
              ON c.countyCode = f.`StCnty FIPS Code` -- Assuming countyCode in FIMA matches the full FIPS
WHERE c.yearOfLoss = 2020
GROUP BY f.`State Name`, f.`County Name`
ORDER BY total_building_damage DESC
LIMIT 20;

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



--
CREATE OR REPLACE VIEW vw_fima_claims_real_dollars AS
SELECT c.id,
       c.clean_zip, -- Using our new high-speed column!
       c.countyCode,
       c.yearOfLoss,
       c.waterDepth,
       c.policyCount,

       -- The Nominal (Unadjusted) Total
       (GREATEST(IFNULL(c.amountPaidOnBuildingClaim, 0), 0) +
        GREATEST(IFNULL(c.amountPaidOnContentsClaim, 0), 0)) AS nominal_total_paid,

       -- The Real (Inflation-Adjusted to 2020) Total
       ROUND(
               (GREATEST(IFNULL(c.amountPaidOnBuildingClaim, 0), 0) +
                GREATEST(IFNULL(c.amountPaidOnContentsClaim, 0), 0))
                   * ((SELECT cpi_value FROM inflation_cpi WHERE cpi_year = 2020 LIMIT 1) / i.cpi_value)
           , 2)                                              AS real_total_paid_2020

FROM fima_nfip_claims c
         JOIN inflation_cpi i ON c.yearOfLoss = i.cpi_year
WHERE c.yearOfLoss IS NOT NULL;
-- ---


/*
 like chart 1 but now inflation adjusted
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



/*
 chart 1 on steroids, now is time series to 1985 instead of stattic year
 */
-- ------------------------------------------------------------------------
-- STEP 1: Early Aggregation
-- We squish millions of individual claims down into just a few thousand summary rows FIRST.
WITH ZipYearAgg AS (SELECT clean_zip,
                           yearOfLoss,
                           COUNT(id)                                              AS claim_count,
                           SUM(policyCount)                                       AS total_policies,
                           -- Keep it in nominal dollars for now to avoid expensive row-by-row math
                           SUM(GREATEST(IFNULL(amountPaidOnBuildingClaim, 0), 0) +
                               GREATEST(IFNULL(amountPaidOnContentsClaim, 0), 0)) AS nominal_paid
                    FROM fima_nfip_claims
                    WHERE yearOfLoss >= 1985
                    GROUP BY clean_zip, yearOfLoss),

-- STEP 2: The Crosswalk Join
-- Now we join our tiny, pre-packed box of data to the crosswalk table, instead of joining millions of raw rows.
     ZctaYearAgg AS (SELECT x.zcta,
                            z.yearOfLoss,
                            SUM(z.claim_count)    AS total_claims,
                            SUM(z.total_policies) AS total_policies,
                            SUM(z.nominal_paid)   AS nominal_paid
                     FROM ZipYearAgg z
                              JOIN zip_to_zcta x ON z.clean_zip = x.zip_code
                     GROUP BY x.zcta, z.yearOfLoss),

-- STEP 3: Land Cover Buckets
     LandCoverBuckets AS (SELECT ZCTA20,
                                 YEAR,
                                 ROUND((PROP_DEV_LOWINTENSITY + PROP_DEV_MEDINTENSITY + PROP_DEV_HIINTENSITY) * 10) *
                                 10 AS impervious_pct_bucket
                          FROM nanda_land_cover
                          WHERE YEAR >= 1985) -- nanda data doesn't extend before here

-- STEP 4: Final Join & Late Math
SELECT z.yearOfLoss                                                   AS `Year`,
       l.impervious_pct_bucket                                        AS `Percent Impervious Surface`,
       SUM(z.total_claims)                                            AS `Total Claims`,

       -- Added NULLIF to prevent fatal divide-by-zero errors if a rural zip has 0 policies
       (SUM(z.total_claims) / NULLIF(SUM(z.total_policies), 0)) * 100 AS `Claims per 100 Policies`,

       -- LATE MATH: We apply the inflation multiplier at the very end.
       -- Instead of calculating inflation 2,000,000 times, we only calculate it ~400 times (40 Years x 10 Buckets)
       (SUM(z.nominal_paid) * (
           (SELECT cpi_value FROM inflation_cpi WHERE cpi_year = 2020 LIMIT 1) / i.cpi_value
           )) / NULLIF(SUM(z.total_claims), 0)                        AS `Average Payout (2020 Dollars)`,

       (SUM(z.nominal_paid) * (
           (SELECT cpi_value FROM inflation_cpi WHERE cpi_year = 2020 LIMIT 1) / i.cpi_value
           ))                                                         AS `Total Payouts (2020 Dollars)`

FROM ZctaYearAgg z
         JOIN LandCoverBuckets l ON z.zcta = l.ZCTA20 AND z.yearOfLoss = l.YEAR
         JOIN inflation_cpi i ON z.yearOfLoss = i.cpi_year
GROUP BY z.yearOfLoss, l.impervious_pct_bucket, i.cpi_value
ORDER BY z.yearOfLoss DESC, l.impervious_pct_bucket;



WITH ZipYearAgg AS (
    SELECT clean_zip,
           yearOfLoss,
           COUNT(id) AS claim_count,
           -- Dropped total_policies here because it's meaningless without the non-claim policies
           SUM(GREATEST(IFNULL(amountPaidOnBuildingClaim, 0), 0) +
               GREATEST(IFNULL(amountPaidOnContentsClaim, 0), 0)) AS nominal_paid
    FROM fima_nfip_claims
    WHERE yearOfLoss >= 1985
    GROUP BY clean_zip, yearOfLoss
),
ZctaYearAgg AS (
    SELECT x.zcta,
           z.yearOfLoss,
           SUM(z.claim_count)  AS total_claims,
           SUM(z.nominal_paid) AS nominal_paid
    FROM ZipYearAgg z
    JOIN zip_to_zcta x ON z.clean_zip = x.zip_code
    GROUP BY x.zcta, z.yearOfLoss
),
LandCoverBuckets AS (
    SELECT ZCTA20,
           YEAR,
           ROUND((PROP_DEV_LOWINTENSITY + PROP_DEV_MEDINTENSITY + PROP_DEV_HIINTENSITY) * 10) * 10 AS impervious_pct_bucket
    FROM nanda_land_cover
    WHERE YEAR >= 1985
),
-- NEW: Isolate the 2020 CPI value cleanly
CPI_2020 AS (
    SELECT cpi_value AS cpi_2020_baseline
    FROM inflation_cpi
    WHERE cpi_year = 2020
    LIMIT 1
)
SELECT z.yearOfLoss                                  AS `Year`,
       l.impervious_pct_bucket                       AS `Percent Impervious Surface`,
       SUM(z.total_claims)                           AS `Total Claims`,

       -- Average payout per FILED claim (Building + Contents combined)
       (SUM(z.nominal_paid) * (c2020.cpi_2020_baseline / i.cpi_value)) / NULLIF(SUM(z.total_claims), 0)
                                                     AS `Avg Payout per Claim (2020 Dollars)`,

       -- Total payouts adjusted to 2020 dollars
       SUM(z.nominal_paid) * (c2020.cpi_2020_baseline / i.cpi_value)
                                                     AS `Total Payouts (2020 Dollars)`

FROM ZctaYearAgg z
-- WARNING: If NANDA doesn't have every year, you will lose claims data here.
-- You may need to use a LEFT JOIN or map claim years to the *closest* NANDA year.
JOIN LandCoverBuckets l ON z.zcta = l.ZCTA20 AND z.yearOfLoss = l.YEAR
JOIN inflation_cpi i ON z.yearOfLoss = i.cpi_year
CROSS JOIN CPI_2020 c2020
GROUP BY z.yearOfLoss, l.impervious_pct_bucket, i.cpi_value, c2020.cpi_2020_baseline
ORDER BY z.yearOfLoss DESC, l.impervious_pct_bucket;
