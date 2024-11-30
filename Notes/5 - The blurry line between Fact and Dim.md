### Is it a Fact or a Dimension ?
- Did a user login today ? The log in event would be a fact that informs the "dim_is_active" dimension VS the stat "dim_is_activated" which is something that is state-driven, not activity driven
- You can aggregate facts and turn them into dimensions : is this person a "high engager" or "low engager" ? CASE WHEN to bucketize aggregated facts can be very useful to reduce the cardinality (5 to 10 buckets is the sweet spot). A goog way is to slice by percentiles (0 to 20, 20 to 40...)

### Properties of Facts vs Dimensions
Dimensions : 
- Usually show in GROUP BY when doing analytics
- Can be "high cardinality" or "low cardinality"
- Generally come from a snapshot of state

Facts :
- Usually aggregated when doing analytics by things like SUM, AVG, COUNT...
- Almost always higher volume than dimensions, although some fact sources are low-volume, think "rare events"
- Generally come from events and logs

### Airbnb example
Is the price of a night on Airbnb a fact or dimension ?
The host can set the price, which sounds like an event
It can easily be SUM, AVG, COUNT'd like regular facts
Prices on Airbnb are double, therefore extremely high carinality

Despite all of this, the price is modeled as a dimension at Airbnb, it's an attribute (state) of a night

The fact in this case would be the host changing the setting that impacted the price

### Boolean/Existence-based Fact/Dimensions
- dim_is_active, dim_bought_something, etc : these are usually on the daily/hour grain
- dim_has_ever_booked, dim_ever_active, dim_ever_labeled_fake : these "ever" dimensions look to see if there has "ever" been a log, and once it flips one way, it never goes back. It's an interesting, simple and powerful feature for machine learning. For example, an Airbnb host with active listings who has never been booked, looks sketchier over time
- days_since_last_active, days_since_signup... : Very common in retention analytical patterns (lookup J curves for more details)

### Categorical Fact/Dimensions
Scoring class : A dimension that is derived from fact data. Example : Good, average, bad
Often calculated with CASE WHEN logic and "bucketizing". Example : Airbnb superhost

### The extremely efficient Date List data structure
A Datelist Int is a data structure that encodes multiple days of user activity in a single integer value (usually a BIGINT)

Imagine a cumulated schema like 'user_cumulated' with a column dates_active which is an array of all the recent days that a user was active
You can turn that into a structure like datelist_int = 1000011 where each number represents a day of the week, and 1 being active and 0 inactive 
Extremely efficient way to manage user growth
 [Max Sung's explanation](https://www.linkedin.com/pulse/datelist-int-efficient-data-structure-user-growth-max-sung/)
### Lab : track user activity 
```sql
CREATE TABLE users_cumulated (  
    user_id TEXT,  
    -- The list of date in the past where the user was active  
    dates_active DATE[],  
    -- The current date for the user  
    date DATE,  
    PRIMARY KEY (user_id, date)  
);  
  
INSERT INTO users_cumulated  
WITH yesterday AS(  
    SELECT *  
    FROM users_cumulated  
    WHERE date = DATE('2023-01-30')  
),  
    today AS(  
    SELECT  
        CAST(user_id AS TEXT),  
        DATE(CAST(event_time AS TIMESTAMP)) AS date_active  
    FROM events  
    WHERE DATE(CAST(event_time AS TIMESTAMP)) = DATE('2023-01-31')  
    AND user_id IS NOT NULL  
    GROUP BY user_id, DATE(CAST(event_time AS TIMESTAMP))  
    )  
SELECT  
    COALESCE(t.user_id, y.user_id) AS user_id,  
    CASE WHEN y.dates_active IS NULL THEN ARRAY[t.date_active]  
        WHEN t.date_active IS NULL THEN y.dates_active  
        ELSE ARRAY[t.date_active] || y.dates_active  
        END  
        as dates_active,  
    COALESCE(t.date_active, y.date + Interval '1 day') AS date  
FROM today t  
FULL OUTER JOIN yesterday y  
ON t.user_id = y.user_id;  
  
  
-- Turn the dates_active from an array into a date list of 30 days  
WITH users AS (  
    SELECT * FROM users_cumulated  
    WHERE date = DATE('2023-01-31')  
),  
    series AS (  
        SELECT * FROM  
             generate_series(DATE('2023-01-01'), DATE('2023-01-31'), INTERVAL '1 day') as series_date  
    ),  
    place_holder_ints AS (SELECT CASE WHEN  
        dates_active @> ARRAY [DATE(series_date)]  
        --  
        THEN CAST(POW(2, 32 - (date - DATE(series_date))) AS BIGINT)  
        ELSE 0  
        END as placeholder_int_value,  
                                 *  
                          FROM users  
                                   CROSS JOIN series)  
SELECT  
    user_id,  
    CAST(CAST(SUM(placeholder_int_value) AS BIGINT) AS BIT(32)),  
    BIT_COUNT(CAST(CAST(SUM(placeholder_int_value) AS BIGINT) AS BIT(32))) > 0 AS dim_is_monthly_active,  
    BIT_COUNT(CAST('11111110000000000000000000000000' AS BIT(32)) & CAST(CAST(SUM(placeholder_int_value) AS BIGINT) AS BIT(32))) > 0 AS dim_is_weekly_active,  
    BIT_COUNT(CAST('10000000000000000000000000000000' AS BIT(32)) & CAST(CAST(SUM(placeholder_int_value) AS BIGINT) AS BIT(32))) > 0 AS dim_is_daily_active  
FROM place_holder_ints  
GROUP BY user_id  
;
```