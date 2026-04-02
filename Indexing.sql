use g13_project;

SHOW INDEX FROM fima_nfip_claims;
SHOW INDEX FROM zip_to_zcta;
SHOW INDEX FROM nanda_land_cover;
    

-- Indexing the Claims table
CREATE INDEX idx_zip_year ON fima_nfip_claims (reportedZipCode, yearOfLoss);

-- Adding dedicated index on yearOfLoss to optimize queries grouping and filtering by yearOfLoss
CREATE INDEX idx_year_of_loss ON fima_nfip_claims (yearOfLoss);


-- index just the zcta
CREATE INDEX idx_zcta ON zip_to_zcta (zcta); 


-- Indexing the Mapping table
CREATE INDEX idx_ztz_lookup ON zip_to_zcta (zip_code, zcta);

-- A reverse index zc->zip
CREATE INDEX idx_ztz_reverse ON zip_to_zcta (zcta, zip_code);


