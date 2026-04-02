USE g13_project;
set global local_infile = 1;


create table if not exists fips_code_refs
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


CREATE TABLE if not exists inflation_cpi
(
    observation_date DATE           NOT NULL,
    cpi_value        DECIMAL(10, 3) NULL,

    cpi_year         INT GENERATED ALWAYS AS (YEAR(observation_date)) STORED,
    -- woah a stored function

    PRIMARY KEY (observation_date)
);

/*
 The formula to adjust historical money to current money is:
 Original Amount * (Current Year CPI / Historical Year CPI)
 */

-- insert load file stuff here
LOAD DATA LOCAL INFILE '/path/to/your/downloaded/CPIAUCSL.csv'
    INTO TABLE inflation_cpi
    FIELDS TERMINATED BY ','
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n' -- Note: If you are on Windows, you might need '\r\n'
    IGNORE 1 ROWS
    (observation_date, cpi_value);
-- 2026 data will be 0 as year is not over yet


LOAD DATA LOCAL INFILE '/path/to/your/downloaded/CPIAUCSL.csv'
    INTO TABLE fips_code_refs
    FIELDS TERMINATED BY ','
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS
    (
     `State Name`, `County Name`, `City Name`, `State Code`, `State FIPS Code`, `County Code`, `StCnty FIPS Code`,
     `City Code`, `StCntyCity FIPS Code`
        );
