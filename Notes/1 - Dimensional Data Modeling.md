### What is a dimension ?
Attributes of an entity (user's birthday, favorite food...)
Some of the dimensions may IDENTIFY an entity (user's ID, social security number, device id...) while others are just attributes

Flavours of dimensions : 
Slowly-changing that are time dependant (favorite food...) or fixed (birthday...)

### Knowing your consumer : who's going to be using the data ?
Data analysts / scientists : should be very easy to query, not many complex data types
Other data engineers : should be compact and harder to query, nested types are okay (master data)
ML models : depends on the model and how its trained 
Customers : should be a very easy to interpret chart

### OLTP vs OLAP vs master data
Online transaction processing : optimized for low-latency/low-volume queries, mainly used for software engineering
Online analytical processing : optimized for large volume, GROUP BY queries, minimizes JOINs mainly used for data engineering
Master Data : the middle ground, optimized for completeness of entity definitions, deduped

OLTP and OLAP is a continuum : 
Production database snapshots (app data) -> Master Data (taking all the production data sets, still normalized) -> OLAP Cubes (flatten the data) -> Metrics

### Cumulative table design : 
Components : 2 dataframes (yesterday and today) -> FULL OUTER JOIN the two data frames together -> COALESCE ids and unchanging dimensions to keep everything around, Compute comulation metrics (e.g. days since) and combine arrayd and changing values -> hang onto all of history
Usages : growth analytics, state transition tracking

### The compactness vs usability tradeoff
- The most usable tables have no complex data type and can easily be manipulated with WHERE and GROUP BY

- The most compact tables (not human readable) are compressed as small as possible and can't be queried directly

- The middle-ground tables use complex data types (e.g. ARRAY, MAP and STRUCT), making querying trickier but also compacting more


When would you use each type : 
- Most compact : online systems where latency and data volumes matter a lot where consumers are usually highly technical
- Middle-ground : upstream staging / master data where the majority of users are other data engineers
- Most usable : when analytics is the main consumer and the majority of consumers are less technical

### Struct vs Array vs Map
- Struct : table inside a table 
Keys are rigidly defined, compression is good
Values can be any type

- Map : 
Keys are loosely defined, compression is okay
Values all have to be the same type

- Array : 
Ordinal (list) datasets
List of values have to be all of the same type


### Temporal Cardinality Explosions of Dimensions : 
When you add a temporal aspect to your dimensions and the cardinality increases by at least 1 order of magnitude

Example : Airbnb has over 6 million listings
If we want to know the nightly pricing and availability of each night for the next year that 365  x 6M or about 2 billion nights
Should this dataset be : 
- Listing-level with an array of nights ?

- Night-level with 2 billion rows ?
If you explode it out and need to join other dimensions, Spark shuffle will ruin your compression

If you do the sorting right, Parquet will keep these two about the same size

Run-length encoding compression : probably the most important compression technique in big data right now, it's why Parquet file format has become so successful

### What are Common Table Expressions (CTEs)?
A Common Table Expression (CTE) is the result set of a query which exists temporarily and for use only within the context of a larger query. Much like a derived table, the result of a CTE is not stored and exists only for the duration of the query.

CTEs, like database views and derived tables, enable users to more easily write and maintain complex queries via increased readability and simplification. This reduction in complexity is achieved by deconstructing ordinarily complex queries into simple blocks to be used, and reused if necessary, in rewriting the query.

```sql
-- define CTE: 
WITH Cost_by_Month AS (SELECT campaign_id AS campaign,        TO_CHAR(created_date, 'YYYY-MM') AS month,        SUM(cost) AS monthly_cost FROM marketing WHERE created_date BETWEEN NOW() - INTERVAL '3 MONTH' AND NOW() GROUP BY 1, 2 ORDER BY 1, 2) 
-- use CTE in subsequent query:
SELECT campaign, avg(monthly_cost) as "Avg Monthly Cost" FROM Cost_by_Month GROUP BY campaign ORDER BY campaign
```