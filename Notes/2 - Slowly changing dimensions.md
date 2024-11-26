#### What is a SDC ?
A SDC is an attribute that drifts over time, like your favorite food as a kid is usually not the same as a adult, unlike your birthday that never changes
SDC helps track values, the dimensions have a time frame

#### What is idempotency ?
Tracking SDC is important for Idempotency : the ability for your data pipeline to produce the same results in all environments regardless of when its ran, which is critical
Pipelines should produce the same results, regardless of :
- the day/hour you run it
- how many times you run it

#### What can make a pipeline non-idempotent ?
- INSERT INTO without TRUNCATE : always use MERGE or INSERT OVERWRITE instead, otherwise you'll keep duplicating the data (INSERT INTO should be voided even with TRUNCATE)
- Using 'start_date >' without a corresponding 'end_date <'
- Not using a full set of partition sensors 
- Not using depends_on_past for cumulative pipelines
- Relying on the "latest" partition of a not properly modeled SCD table
- Relying on the "latest" partition of anything else

#### What are the other options to model change ?
- Singular snapshot : latest snapshot or Daily/Monthly/Yearly snapshot
- Daily partitioned snapshots
- SCD types 1, 2 ,3

#### Is SCD a good way to model your data ?
It depends how slowly changing are the dimensions
Basically SCD is a way of collapsing daily snapshots based on whether the data changed from day to day, instead of having 365 rows that say I'm 30, you have 1 row that says you're 30 from January 1st to December 13st

#### Types of SCD : 
- Type 0 : the value never changes
- Type 1 : You only care about the latest value, never should be used because it makes the pipeline not idempotent
- Type 2 : You care about what the value was from "start_date" to "end_date"
Current values usually have an end date that either NULL or very far into the future (9999-12-31). There's also usually a boolean "is_current" column. 
It's hard to use since there's more than 1 row per dimension. It's the only type of SCD that is purely idempotent 
- Type 3 : You only care about the "original" and "current" value
It's a middle ground that only has 1 row per dimension, but at the same time you lose the history. It's only partially idempotent

#### Ways to load SCD2 data
- Load the entire history in one query : inefficient but simble
- Incrementally load the data after the previous SCD is generated : efficient but cumbersome
### What are Windows functions in SQL ?
https://www.youtube.com/watch?v=y1KCM8vbYe4

Window functions perform  aggregate operations on groups of rows, but they produce a result for each row 

Example : this query allows to compare a player's number of points during a season to the average of all players, as well as his previous year's and next year's number of points

```sql
SELECT player_name,  
       pts,  
       AVG(pts) OVER (PARTITION BY season),  
       LAG(pts) OVER (PARTITION BY player_name ORDER BY player_name, season ASC) as pts_previous_season,  
       LEAD(pts) OVER (PARTITION BY player_name ORDER BY player_name, season ASC) as pts_next_season,  
       season  
FROM player_seasons;
```