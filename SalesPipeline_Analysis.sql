/* DATABASE CREATION */

CREATE DATABASE salesforce;
USE salesforce;

/* IMPORT DATA */

-- Accounts, products and sales_teams tables are imported using 'Import wizard' option

-- Creating table schema for sales_pipeline table
CREATE TABLE sales_pipeline(
opportunity_id varchar(255),
sales_agent varchar(255),	
product	varchar(255),
account	varchar(255),
deal_stage varchar(255),	
engage_date	varchar(255),
close_date varchar(255),
close_value varchar(255)
);

-- Importing data into sales_pipeline table

-- Enable the local_infile parameter to permit local data loading 
SHOW VARIABLES LIKE 'local_infile';
SET GLOBAL local_infile = 1; 

-- Load data
LOAD DATA LOCAL INFILE 'C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\sales_pipeline.csv'
INTO TABLE sales_pipeline
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

/* DATA CLEANING */

-- ACCOUNTS TABLE
SELECT Column_name, Data_type 
FROM information_schema.columns
WHERE table_Name='accounts';

SELECT * FROM accounts;

-- Identifying duplicate records
WITH duplicate_cte AS (SELECT *,
ROW_NUMBER() OVER(PARTITION BY account)
AS row_num
FROM accounts)
SELECT * FROM duplicate_cte WHERE row_num>1;
-- No duplicate records are present

-- Identifying missing values
SELECT * FROM accounts 
WHERE account IS NULL OR account = '';
-- No missing values are present in the primary column


-- PRODUCTS TABLE
SELECT Column_name, Data_type 
FROM information_schema.columns
WHERE table_Name='products';

SELECT * FROM products;
-- No data cleaning is required for products table

-- SALES_TEAMS TABLE
SELECT Column_name, Data_type 
FROM information_schema.columns
WHERE table_Name='sales_teams';

SELECT * FROM sales_teams;

-- Identifying duplicate records
WITH duplicate_cte AS (SELECT *,
ROW_NUMBER() OVER(PARTITION BY sales_agent)
AS row_num
FROM sales_teams)
SELECT * FROM duplicate_cte WHERE row_num>1;
-- No duplicate records are present in the table

-- Identifying missing values
SELECT * FROM sales_teams 
WHERE sales_agent IS NULL OR sales_agent='';
-- No missing values are present in the primary column

-- SALES_PIPELINE TABLE

SELECT Column_name, Data_type 
FROM information_schema.columns
WHERE table_Name='sales_pipeline';
-- Column datatype need to be changed for engage_date, close_date, close_value columns

SELECT * FROM sales_pipeline;

-- Identifying duplicate records
WITH duplicate_cte AS (SELECT *,
ROW_NUMBER() OVER(PARTITION BY opportunity_id)
AS row_num
FROM sales_pipeline)
SELECT * FROM duplicate_cte WHERE row_num>1;
-- No duplicate records are present in the table

-- Identifying missing values
SELECT * FROM sales_pipeline 
WHERE 
opportunity_id IS NULL OR opportunity_id ='';
-- No missing values are present in the primary column

-- Checking for empty values
SELECT * FROM sales_pipeline 
WHERE 
sales_agent IS NULL OR sales_agent='' OR
product IS NULL OR product='' OR
`account` IS  NULL OR `account`='';

-- Updating empty values to NULL in account column
UPDATE sales_pipeline SET `account` = Null WHERE account='';

SELECT * 
FROM sales_pipeline
WHERE close_value NOT REGEXP '^[0-9]+$' AND close_value IS NOT NULL;
-- Empty values are present in close_value column which needs to be handled

-- Updating empty values to NULL in close_value column
UPDATE sales_pipeline
SET close_value = NULL WHERE close_value NOT REGEXP '^[0-9]+$' AND close_value IS NOT NULL;


-- Correcting data type

-- Formatting date values to supported date format
SELECT engage_date, STR_TO_DATE(engage_date, '%d-%m-%Y'), close_date, STR_TO_DATE(close_date, '%d-%m-%Y')
FROM sales_pipeline;

UPDATE sales_pipeline 
SET 
    engage_date = CASE 
        WHEN engage_date = '' THEN NULL 
        ELSE STR_TO_DATE(engage_date, '%d-%m-%Y') 
    END,
    close_date = CASE 
        WHEN close_date = '' THEN NULL 
        ELSE STR_TO_DATE(close_date, '%d-%m-%Y') 
    END;

-- Modifying the data types of the columns
ALTER TABLE sales_pipeline
MODIFY COLUMN engage_date date,
MODIFY COLUMN close_date date,
MODIFY COLUMN close_value int;

/* ESTABLISHING RELATIONSHIP BETWEEN TABLES */

-- Adding primary key on account column in products table
ALTER TABLE accounts 
MODIFY COLUMN `account` VARCHAR(255);
ALTER TABLE accounts 
ADD CONSTRAINT PK_account 
PRIMARY KEY (`account`);


-- Adding primary key on product column in products table
ALTER TABLE products 
MODIFY COLUMN `product` VARCHAR(255);
ALTER TABLE products 
ADD CONSTRAINT PK_product
PRIMARY KEY (product);

-- Adding primary key on sales_agent column in sales_teams table
ALTER TABLE sales_teams 
MODIFY COLUMN sales_agent VARCHAR(255);
ALTER TABLE sales_teams 
ADD CONSTRAINT PK_salesAgent 
PRIMARY KEY (sales_agent);

-- Establishing relationship between accounts and sales_pipeline table 
ALTER TABLE sales_pipeline
ADD CONSTRAINT FK_account
FOREIGN KEY(`account`) REFERENCES accounts(`account`);

-- Establishing relationship between products and sales_pipeline table 
ALTER TABLE sales_pipeline
ADD CONSTRAINT FK_product
FOREIGN KEY(product) REFERENCES products(product);

SELECT product
FROM sales_pipeline
WHERE product NOT IN (SELECT product FROM products);

-- Changing 'GTXPro' to 'GTX Pro' in product column in sales_pipeline table
UPDATE sales_pipeline
SET product = 'GTX Pro' WHERE product = 'GTXPro';

-- Establishing relationship between products and sales_pipeline table 
ALTER TABLE sales_pipeline
ADD CONSTRAINT FK_agent
FOREIGN KEY(sales_agent) REFERENCES sales_teams(sales_agent);

/* UNDERSTANDING THE DATA */

-- Accounts table

SELECT * FROM accounts;

SELECT COUNT(DISTINCT account) AS No_Of_Companies,
COUNT(DISTINCT sector) AS No_Of_sectors,
COUNT(DISTINCT office_location) AS No_Of_locations
FROM accounts;

-- Products table
SELECT COUNT(DISTINCT product) AS No_Of_products,
COUNT(DISTINCT series) AS No_Of_series,
MIN(sales_price) AS Min_SalesPrice,
MAX(sales_price) AS MAX_SalesPrice
FROM products;

-- Sales_team Table
SELECT COUNT(DISTINCT sales_agent) AS No_Of_agents,
COUNT(DISTINCT regional_office) AS No_Of_regionalOffices
FROM sales_teams;

SELECT DISTINCT regional_office FROM sales_teams;

-- Sales_pipeline Table

SELECT DISTINCT deal_stage FROM sales_pipeline;

SELECT COUNT(DISTINCT opportunity_id) AS Total_deals,
COUNT(CASE WHEN deal_stage='Won' THEN opportunity_id ELSE NULL END)AS Won_Deals,
COUNT(CASE WHEN deal_stage='Lost' THEN opportunity_id ELSE NULL END) AS Lost_Deals,
COUNT(CASE WHEN deal_stage='Engaging' THEN opportunity_id ELSE NULL END) AS Engaging_Deals,
COUNT(CASE WHEN deal_stage='Prospecting' THEN opportunity_id ELSE NULL END) AS Prospecting_Deals
FROM sales_pipeline;

/* Data summary:
- Companies: 85 across 10 sectors and 15 locations  
- Products: 7 products in 3 series, with prices ranging from $55 to $26,768.  
- Sales Teams: 35 agents operating from 3 regional offices (Central, East, West).  
- Deals: 8,800 total:
  - Won: 4,238  
  - Lost: 2,473  
  - Engaging: 1,589  
  - Prospecting: 500  
  */

/* KEY METRICS */

-- Deal Close Rate
SELECT (COUNT(CASE WHEN deal_stage = 'Won' THEN 1 END) / COUNT(*)) * 100 AS deal_close_rate
FROM sales_pipeline;

-- Average deal value
SELECT AVG(close_value) AS average_deal_value
FROM sales_pipeline
WHERE deal_stage = 'Won';

-- Average time to close
SELECT AVG(DATEDIFF(close_date, engage_date)) AS average_time_to_close
FROM sales_pipeline
WHERE deal_stage IN ('Won', 'Lost') AND engage_date IS NOT NULL AND close_date IS NOT NULL;

/* Insights:
- Deal close rate - 48.1591
- Average deal value - 2360.9094
- Average time to close -  47.9854
*/

/* ANALYSIS */

/*Identifying High-Growth Accounts*/
 
/*Question: Which accounts (companies) have the highest revenue growth potential 
based on their year of establishment and sector?*/

WITH SectorAnalysis AS (
    SELECT 
        sector,
        ROUND(AVG(revenue),2) AS avg_sector_revenue,
        MAX(revenue) AS max_sector_revenue
    FROM accounts
    GROUP BY sector
),
RankedAccounts AS (
    SELECT 
        a.year_established,
        a.sector,
        a.account,
        a.revenue,
        sa.avg_sector_revenue,
        sa.max_sector_revenue,
        RANK() OVER (PARTITION BY a.sector ORDER BY a.year_established DESC, a.revenue ASC) AS growth_rank
    FROM accounts a
    JOIN SectorAnalysis sa ON a.sector = sa.sector
    WHERE a.year_established > 2000 -- Filter for newer companies
)
SELECT 
    year_established,
    sector,
    account,
    revenue,
    avg_sector_revenue,
    max_sector_revenue 
FROM RankedAccounts
WHERE growth_rank = 1 -- Select the top-ranked company in each sector
ORDER BY sector, year_established DESC;

/* Product Affordability Analysis */

/* Which product series offers the most affordable options, and how do they compare to premium ones? */

WITH SeriesPricing AS (
    SELECT 
        series,
        ROUND(AVG(sales_price)) AS avg_price,
        MIN(sales_price) AS min_price,
        MAX(sales_price) AS max_price
    FROM products
    GROUP BY series
)
SELECT 
    series,
    avg_price AS average_price,
    min_price AS minimum_price,
    max_price AS maximum_price,
    RANK() OVER (ORDER BY avg_price ASC) AS affordability_rank
FROM SeriesPricing
ORDER BY affordability_rank;

/* Sales Team Efficiency */

/* Which regional offices have the most efficient sales teams in terms of sales_agent-to-revenue ratios? 
Analysis: Combine the sales agent and accounts tables (using hypothetical revenue link) and calculate performance metrics.
*/

/*
Observation:
- There's no direct field that ties sales agents to specific accounts or their revenues
Requirement:
- If there’s a mapping of sales agents to specific accounts, we can use that to establish a valid join
Alternate possible solution:
- We can use Sales Pipeline Table
- The table has the data connecting agents to accounts, we can use it as the intermediary.
*/

-- Checking if null values effect the results
SELECT * FROM sales_pipeline WHERE account IS NULL AND deal_stage='WON';
SELECT * FROM sales_pipeline WHERE close_value IS NULL AND deal_stage='WON';
-- Null values will not effect the results 

WITH agent_account AS (SELECT regional_office, st.sales_agent, `account`,  COALESCE(sp.close_value, 0) AS close_value
FROM sales_teams st
LEFT JOIN sales_pipeline sp ON st.sales_agent = sp.sales_agent)

SELECT regional_office, COUNT(DISTINCT sales_agent) AS total_sales_agents,
ROUND(SUM(close_value)) AS total_revenue,
ROUND(SUM(close_value) / NULLIF(COUNT(DISTINCT sales_agent), 0)) AS revenue_per_agent
FROM agent_account
GROUP BY regional_office
ORDER BY revenue_per_agent DESC;


/* Market Saturation Insight */

/* Question: Which office locations are underrepresented by the number of accounts compared to the regional market potential? */

/* Observation:
- Data is inadequate
- To gain insights about underrepresented accounts we'll need additional data points that represent regional market potential
*/

/* Industry-Specific Revenue Leaders */

/* Which sector has the highest average revenue per company, and how does it vary by location? */
WITH cte AS (
SELECT sector, office_location, ROUND(AVG(revenue), 2) AS average_revenue
FROM accounts
GROUP BY sector, office_location
)
SELECT sector, office_location, average_revenue
FROM cte
WHERE sector IN (
SELECT sector FROM cte WHERE 
average_revenue = (SELECT MAX(average_revenue) FROM cte))
ORDER BY average_revenue DESC;

-- Revenue by secor and location
SELECT sector, office_location, ROUND(AVG(revenue),2) AS average_revenue
FROM accounts
GROUP BY sector, office_location
ORDER BY sector, average_revenue DESC;

















