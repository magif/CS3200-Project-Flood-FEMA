create table fima_nfip_claims
(
    asOfDate                                   datetime       null,
    amountPaidOnBuildingClaim                  decimal(12, 2) null,
    amountPaidOnContentsClaim                  decimal(12, 2) null,
    amountPaidOnIncreasedCostOfComplianceClaim decimal(12, 2) null,
    netBuildingPaymentAmount                   decimal(12, 2) null,
    netContentsPaymentAmount                   decimal(12, 2) null,
    agricultureStructureIndicator              tinyint(1)     null,
    basementEnclosureCrawlspaceType            smallint       null,
    policyCount                                smallint       null,
    crsClassificationCode                      smallint       null,
    dateOfLoss                                 datetime       null,
    elevatedBuildingIndicator                  tinyint(1)     null,
    elevationCertificateIndicator              varchar(255)   null,
    elevationDifference                        int            null,
    baseFloodElevation                         decimal(6, 1)  null,
    ratedFloodZone                             varchar(255)   null,
    houseWorship                               tinyint(1)     null,
    locationOfContents                         smallint       null,
    lowestAdjacentGrade                        decimal(6, 1)  null,
    lowestFloorElevation                       decimal(6, 1)  null,
    numberOfFloorsInTheInsuredBuilding         smallint       null,
    nonProfitIndicator                         tinyint(1)     null,
    obstructionType                            smallint       null,
    occupancyType                              smallint       null,
    originalConstructionDate                   date           null,
    originalNBDate                             date           null,
    postFIRMConstructionIndicator              tinyint(1)     null,
    rateMethod                                 varchar(255)   null,
    smallBusinessIndicatorBuilding             tinyint(1)     null,
    totalBuildingInsuranceCoverage             int            null,
    totalContentsInsuranceCoverage             int            null,
    yearOfLoss                                 smallint       null,
    primaryResidenceIndicator                  tinyint(1)     null,
    buildingDamageAmount                       int            null,
    buildingDeductibleCode                     varchar(255)   null,
    buildingPropertyValue                      int            null,
    causeOfDamage                              varchar(255)   null,
    condominiumCoverageTypeCode                varchar(255)   null,
    contentsDamageAmount                       int            null,
    contentsDeductibleCode                     varchar(255)   null,
    contentsPropertyValue                      int            null,
    disasterAssistanceCoverageRequired         smallint       null,
    eventDesignationNumber                     varchar(255)   null,
    ficoNumber                                 smallint       null,
    floodCharacteristicsIndicator              smallint       null,
    floodWaterDuration                         smallint       null,
    floodproofedIndicator                      tinyint(1)     null,
    floodEvent                                 varchar(255)   null,
    iccCoverage                                int            null,
    netIccPaymentAmount                        decimal(8, 2)  null,
    nfipRatedCommunityNumber                   varchar(255)   null,
    nfipCommunityNumberCurrent                 varchar(255)   null,
    nfipCommunityName                          varchar(255)   null,
    nonPaymentReasonContents                   varchar(255)   null,
    nonPaymentReasonBuilding                   varchar(255)   null,
    numberOfUnits                              smallint       null,
    buildingReplacementCost                    bigint         null,
    contentsReplacementCost                    int            null,
    replacementCostBasis                       varchar(255)   null,
    stateOwnedIndicator                        tinyint(1)     null,
    waterDepth                                 smallint       null,
    floodZoneCurrent                           varchar(255)   null,
    buildingDescriptionCode                    smallint       null,
    rentalPropertyIndicator                    tinyint(1)     null,
    state                                      varchar(255)   null,
    reportedCity                               varchar(255)   null,
    reportedZipCode                            varchar(255)   null,
    countyCode                                 varchar(255)   null,
    censusTract                                varchar(255)   null,
    censusBlockGroupFips                       varchar(255)   null,
    latitude                                   decimal(9, 1)  null,
    longitude                                  decimal(9, 1)  null,
    id                                         varchar(255)   not null
        primary key,
    clean_zip                                  char(5) as (left(trim(`reportedZipCode`), 5)) stored
);

create index idx_fima_clean_zip
    on fima_nfip_claims (clean_zip);

create index idx_year_of_loss
    on fima_nfip_claims (yearOfLoss);

create index idx_zip_year
    on fima_nfip_claims (reportedZipCode, yearOfLoss);

create table fips_code_refs
(
    `State Name`           text null,
    `County Name`          text null,
    `City Name`            text null,
    `State Code`           text null,
    `State FIPS Code`      text null,
    `County Code`          text null,
    `StCnty FIPS Code`     text null,
    `City Code`            text null,
    `StCntyCity FIPS Code` text null
);

create table inflation_cpi
(
    observation_date date           not null
        primary key,
    cpi_value        decimal(10, 3) null,
    cpi_year         int as (year(`observation_date`)) stored
);

create table nanda_land_cover
(
    ZCTA20                varchar(5)      not null,
    YEAR                  int             not null,
    OPENWATER             bigint          null,
    PROP_OPENWATER        decimal(15, 13) null,
    PER_ICESNOW           bigint          null,
    PROP_PER_ICESNOW      decimal(15, 13) null,
    DEV_OPENSPACE         bigint          null,
    PROP_DEV_OPENSPACE    decimal(15, 13) null,
    DEV_LOWINTENSITY      bigint          null,
    PROP_DEV_LOWINTENSITY decimal(15, 13) null,
    DEV_MEDINTENSITY      bigint          null,
    PROP_DEV_MEDINTENSITY decimal(15, 13) null,
    DEV_HIINTENSITY       bigint          null,
    PROP_DEV_HIINTENSITY  decimal(15, 13) null,
    BARREN                bigint          null,
    PROP_BARREN           decimal(15, 13) null,
    DECIDUOUSFOREST       bigint          null,
    PROP_DECIDUOUSFOREST  decimal(15, 13) null,
    EVERGREENFOREST       bigint          null,
    PROP_EVERGREENFOREST  decimal(15, 13) null,
    MIXEDFOREST           bigint          null,
    PROP_MIXEDFOREST      decimal(15, 13) null,
    SHRUBSCRUB            bigint          null,
    PROP_SHRUBSCRUB       decimal(15, 13) null,
    GRASSHERB             bigint          null,
    PROP_GRASSHERB        decimal(15, 13) null,
    PASTUREHAY            bigint          null,
    PROP_PASTUREHAY       decimal(15, 13) null,
    CULTCROPS             bigint          null,
    PROP_CULTCROPS        decimal(15, 13) null,
    WOODYWET              bigint          null,
    PROP_WOODYWET         decimal(15, 13) null,
    HERBWET               bigint          null,
    PROP_HERBWET          decimal(15, 13) null,
    primary key (ZCTA20, YEAR)
);

create table zip_to_zcta
(
    zip_code      char(5)     not null
        primary key,
    po_name       varchar(50) null,
    state         char(2)     null,
    zip_type      varchar(50) null,
    zcta          char(5)     null,
    zip_join_type varchar(50) null
);

create index idx_zcta
    on zip_to_zcta (zcta);

create index idx_ztz_lookup
    on zip_to_zcta (zip_code, zcta);

create index idx_ztz_reverse
    on zip_to_zcta (zcta, zip_code);


