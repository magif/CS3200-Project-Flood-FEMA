-- DROP DATABASE IF EXISTS g13_project;
CREATE DATABASE  IF NOT EXISTS g13_project;
USE g13_project;

-- show variables;
-- show variables where variable_name like '%local%';
set global local_infile=ON;

Drop table if EXISTS zip_to_zcta;
CREATE TABLE zip_to_zcta (
    zip_code CHAR(5),
    po_name VARCHAR(50),
    state CHAR(2),
    zip_type VARCHAR(50),
    zcta CHAR(5),
    zip_join_type VARCHAR(50),
    PRIMARY KEY (zip_code)
);

LOAD DATA LOCAL INFILE 'C:\path to\ZIP Code to ZCTA Crosswalk.csv'
INTO TABLE zip_to_zcta
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(zip_code, po_name, state, zip_type, @zcta, zip_join_type)
SET zcta = NULLIF(@zcta, '');

-- truncate zip_to_zcta;

CREATE TABLE IF NOT EXISTS nanda_land_cover (
    ZCTA20 VARCHAR(5),
    YEAR INT,
    OPENWATER BIGINT,
    PROP_OPENWATER DECIMAL(15, 13),
    PER_ICESNOW BIGINT,
    PROP_PER_ICESNOW DECIMAL(15, 13),
    DEV_OPENSPACE BIGINT,
    PROP_DEV_OPENSPACE DECIMAL(15, 13),
    DEV_LOWINTENSITY BIGINT,
    PROP_DEV_LOWINTENSITY DECIMAL(15, 13),
    DEV_MEDINTENSITY BIGINT,
    PROP_DEV_MEDINTENSITY DECIMAL(15, 13),
    DEV_HIINTENSITY BIGINT,
    PROP_DEV_HIINTENSITY DECIMAL(15, 13),
    BARREN BIGINT,
    PROP_BARREN DECIMAL(15, 13),
    DECIDUOUSFOREST BIGINT,
    PROP_DECIDUOUSFOREST DECIMAL(15, 13),
    EVERGREENFOREST BIGINT,
    PROP_EVERGREENFOREST DECIMAL(15, 13),
    MIXEDFOREST BIGINT,
    PROP_MIXEDFOREST DECIMAL(15, 13),
    SHRUBSCRUB BIGINT,
    PROP_SHRUBSCRUB DECIMAL(15, 13),
    GRASSHERB BIGINT,
    PROP_GRASSHERB DECIMAL(15, 13),
    PASTUREHAY BIGINT,
    PROP_PASTUREHAY DECIMAL(15, 13),
    CULTCROPS BIGINT,
    PROP_CULTCROPS DECIMAL(15, 13),
    WOODYWET BIGINT,
    PROP_WOODYWET DECIMAL(15, 13),
    HERBWET BIGINT,
    PROP_HERBWET DECIMAL(15, 13),
    PRIMARY KEY (ZCTA20, YEAR)
);

-- Drop table if EXISTS fima_nfip_claims;
CREATE TABLE IF NOT EXISTS fima_nfip_claims (
    asOfDate DATETIME,
    amountPaidOnBuildingClaim DECIMAL(12,2),
    amountPaidOnContentsClaim DECIMAL(12,2),
    amountPaidOnIncreasedCostOfComplianceClaim DECIMAL(12,2),
    netBuildingPaymentAmount DECIMAL(12,2),
    netContentsPaymentAmount DECIMAL(12,2),
    agricultureStructureIndicator BOOLEAN,
    basementEnclosureCrawlspaceType SMALLINT,
    policyCount SMALLINT,
    crsClassificationCode SMALLINT,
    dateOfLoss DATETIME,
    elevatedBuildingIndicator BOOLEAN,
    elevationCertificateIndicator VARCHAR(255),
    elevationDifference INT,
    baseFloodElevation DECIMAL(6,1),
    ratedFloodZone VARCHAR(255),
    houseWorship BOOLEAN,
    locationOfContents SMALLINT,
    lowestAdjacentGrade DECIMAL(6,1),
    lowestFloorElevation DECIMAL(6,1),
    numberOfFloorsInTheInsuredBuilding SMALLINT,
    nonProfitIndicator BOOLEAN,
    obstructionType SMALLINT,
    occupancyType SMALLINT,
    originalConstructionDate DATE,
    originalNBDate DATE,
    postFIRMConstructionIndicator BOOLEAN,
    rateMethod VARCHAR(255),
    smallBusinessIndicatorBuilding BOOLEAN,
    totalBuildingInsuranceCoverage INT,
    totalContentsInsuranceCoverage INT,
    yearOfLoss SMALLINT,
    primaryResidenceIndicator BOOLEAN,
    buildingDamageAmount INT,
    buildingDeductibleCode VARCHAR(255),
    buildingPropertyValue INT,
    causeOfDamage VARCHAR(255),
    condominiumCoverageTypeCode VARCHAR(255),
    contentsDamageAmount INT,
    contentsDeductibleCode VARCHAR(255),
    contentsPropertyValue INT,
    disasterAssistanceCoverageRequired SMALLINT,
    eventDesignationNumber VARCHAR(255),
    ficoNumber SMALLINT,
    floodCharacteristicsIndicator SMALLINT,
    floodWaterDuration SMALLINT,
    floodproofedIndicator BOOLEAN,
    floodEvent VARCHAR(255),
    iccCoverage INT,
    netIccPaymentAmount DECIMAL(8,2),
    nfipRatedCommunityNumber VARCHAR(255),
    nfipCommunityNumberCurrent VARCHAR(255),
    nfipCommunityName VARCHAR(255),
    nonPaymentReasonContents VARCHAR(255),
    nonPaymentReasonBuilding VARCHAR(255),
    numberOfUnits SMALLINT,
    buildingReplacementCost BIGINT,
    contentsReplacementCost INT,
    replacementCostBasis VARCHAR(255),
    stateOwnedIndicator BOOLEAN,
    waterDepth SMALLINT,
    floodZoneCurrent VARCHAR(255),
    buildingDescriptionCode SMALLINT,
    rentalPropertyIndicator BOOLEAN,
    state VARCHAR(255),
    reportedCity VARCHAR(255),
    reportedZipCode VARCHAR(255),
    countyCode VARCHAR(255),
    censusTract VARCHAR(255),
    censusBlockGroupFips VARCHAR(255),
    latitude DECIMAL(9,1),
    longitude DECIMAL(9,1),
    id VARCHAR(255),
    PRIMARY KEY (id)
);

CREATE TABLE fima_nfip_claims_staging (
	asOfDate DATETIME,
    amountPaidOnBuildingClaim DECIMAL(12,2),
    amountPaidOnContentsClaim DECIMAL(12,2),
    amountPaidOnIncreasedCostOfComplianceClaim DECIMAL(12,2),
    netBuildingPaymentAmount DECIMAL(12,2),
    netContentsPaymentAmount DECIMAL(12,2),
    agricultureStructureIndicator BOOLEAN,
    basementEnclosureCrawlspaceType SMALLINT,
    policyCount SMALLINT,
    crsClassificationCode SMALLINT,
    dateOfLoss DATETIME,
    elevatedBuildingIndicator BOOLEAN,
    elevationCertificateIndicator VARCHAR(255),
    elevationDifference INT,
    baseFloodElevation DECIMAL(6,1),
    ratedFloodZone VARCHAR(255),
    houseWorship BOOLEAN,
    locationOfContents SMALLINT,
    lowestAdjacentGrade DECIMAL(6,1),
    lowestFloorElevation DECIMAL(6,1),
    numberOfFloorsInTheInsuredBuilding SMALLINT,
    nonProfitIndicator BOOLEAN,
    obstructionType SMALLINT,
    occupancyType SMALLINT,
    originalConstructionDate DATE,
    originalNBDate DATE,
    postFIRMConstructionIndicator BOOLEAN,
    rateMethod VARCHAR(255),
    smallBusinessIndicatorBuilding BOOLEAN,
    totalBuildingInsuranceCoverage INT,
    totalContentsInsuranceCoverage INT,
    yearOfLoss SMALLINT,
    primaryResidenceIndicator BOOLEAN,
    buildingDamageAmount INT,
    buildingDeductibleCode VARCHAR(255),
    buildingPropertyValue INT,
    causeOfDamage VARCHAR(255),
    condominiumCoverageTypeCode VARCHAR(255),
    contentsDamageAmount INT,
    contentsDeductibleCode VARCHAR(255),
    contentsPropertyValue INT,
    disasterAssistanceCoverageRequired SMALLINT,
    eventDesignationNumber VARCHAR(255),
    ficoNumber SMALLINT,
    floodCharacteristicsIndicator SMALLINT,
    floodWaterDuration SMALLINT,
    floodproofedIndicator BOOLEAN,
    floodEvent VARCHAR(255),
    iccCoverage INT,
    netIccPaymentAmount DECIMAL(8,2),
    nfipRatedCommunityNumber VARCHAR(255),
    nfipCommunityNumberCurrent VARCHAR(255),
    nfipCommunityName VARCHAR(255),
    nonPaymentReasonContents VARCHAR(255),
    nonPaymentReasonBuilding VARCHAR(255),
    numberOfUnits SMALLINT,
    buildingReplacementCost BIGINT,
    contentsReplacementCost INT,
    replacementCostBasis VARCHAR(255),
    stateOwnedIndicator BOOLEAN,
    waterDepth SMALLINT,
    floodZoneCurrent VARCHAR(255),
    buildingDescriptionCode SMALLINT,
    rentalPropertyIndicator BOOLEAN,
    state VARCHAR(255),
    reportedCity VARCHAR(255),
    reportedZipCode VARCHAR(255),
    countyCode VARCHAR(255),
    censusTract VARCHAR(255),
    censusBlockGroupFips VARCHAR(255),
    latitude DECIMAL(9,1),
    longitude DECIMAL(9,1),
    id VARCHAR(255)
    -- DO NOT set a Primary Key here
) ENGINE=MyISAM;

-- Truncate fima_nfip_claims_staging;
-- ------------------------------------
ALTER TABLE fima_nfip_claims_staging DISABLE KEYS;

LOAD DATA LOCAL INFILE 'C:\path to\FimaNfipClaimsV2.csv'
INTO TABLE fima_nfip_claims_staging
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    agricultureStructureIndicator, asOfDate, basementEnclosureCrawlspaceType, policyCount,
    crsClassificationCode, dateOfLoss, elevatedBuildingIndicator, elevationCertificateIndicator,
    elevationDifference, baseFloodElevation, ratedFloodZone, houseWorship, locationOfContents,
    lowestAdjacentGrade, lowestFloorElevation, numberOfFloorsInTheInsuredBuilding, nonProfitIndicator,
    obstructionType, occupancyType, originalConstructionDate, originalNBDate, amountPaidOnBuildingClaim,
    amountPaidOnContentsClaim, amountPaidOnIncreasedCostOfComplianceClaim, postFIRMConstructionIndicator,
    rateMethod, smallBusinessIndicatorBuilding, totalBuildingInsuranceCoverage, totalContentsInsuranceCoverage,
    yearOfLoss, primaryResidenceIndicator, buildingDamageAmount, buildingDeductibleCode, netBuildingPaymentAmount,
    buildingPropertyValue, causeOfDamage, condominiumCoverageTypeCode, contentsDamageAmount, contentsDeductibleCode,
    netContentsPaymentAmount, contentsPropertyValue, disasterAssistanceCoverageRequired, eventDesignationNumber,
    ficoNumber, floodCharacteristicsIndicator, floodWaterDuration, floodproofedIndicator, floodEvent, iccCoverage,
    netIccPaymentAmount, nfipRatedCommunityNumber, nfipCommunityNumberCurrent, nfipCommunityName,
    nonPaymentReasonContents, nonPaymentReasonBuilding, numberOfUnits, buildingReplacementCost,
    contentsReplacementCost, replacementCostBasis, stateOwnedIndicator, waterDepth, floodZoneCurrent,
    buildingDescriptionCode, rentalPropertyIndicator, state, reportedCity, reportedZipCode, countyCode,
    censusTract, censusBlockGroupFips, latitude, longitude, id
);

ALTER TABLE fima_nfip_claims_staging ENABLE KEYS;

-- DROP TABLE fima_nfip_claims_staging;

-- 1. Tell MySQL to relax just enough so we can search for the bad dates without it throwing an error
SET SQL_SAFE_UPDATES = 0;
SET SESSION sql_mode = '';
SET SESSION net_read_timeout = 3600;
SET SESSION net_write_timeout = 3600;

-- 2. Grab the fix four date columns in the staging area
UPDATE fima_nfip_claims_staging
SET originalConstructionDate = NULL
WHERE originalConstructionDate = '0000-00-00';

UPDATE fima_nfip_claims_staging
SET originalNBDate = NULL
WHERE originalNBDate = '0000-00-00';

UPDATE fima_nfip_claims_staging
SET dateOfLoss = NULL
WHERE dateOfLoss = '0000-00-00';

UPDATE fima_nfip_claims_staging
SET asOfDate = NULL
WHERE asOfDate = '0000-00-00';

-- 3. The data is cleaned. loads into nicer table
INSERT INTO fima_nfip_claims
SELECT * FROM fima_nfip_claims_staging
ORDER BY id;

SET SESSION net_read_timeout = 30;
SET SESSION net_write_timeout = 30;


-- 2. Run Data Loads
-- TRUNCATE nanda_land_cover;

LOAD DATA LOCAL INFILE 'c:\ path to \\ICPSR_38598 2020\\DS0004\\38598-0004-Data.tsv'
INTO TABLE nanda_land_cover
FIELDS TERMINATED BY '\t'
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS; -- Skips the header row

-- TRUNCATE fima_nfip_claims;

/*
LOAD DATA LOCAL INFILE 'C:\\Users\\magif\\Downloads\\FimaNfipClaimsV2.csv'
INTO TABLE fima_nfip_claims
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

Actually impossibly slow, use staging db then move into nfip
*/

