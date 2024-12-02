### What is shuffling ?
Data shuffling is a process in modern data pipelines where the data is randomly redistributed across different partitions to enable parallel processing and better performance

There a highly parallelizable queries, and others not so much :
- Exetremely parallel : SELECT, FROM, WHERE. These queries are infinitely scalable. If you had a billion rows and a billion machines, each machine can have one row and it will be very quick to retrieve all the data

- Kind of parallel : GROUP BY, JOIN, HAVING

- Not parallel : ORDER BY. The most painful keyword in SQL, the only way to sort 1 million rows scattered on 1 million machines is if all the data gets passed to one machine, that's the opposite of parallel. Using ORDER BY should be on tables with thousands rows, not millions or more.
### How to make GROUP BY more efficient ?
Give GROUP BY some buckets and guarantees
Reduce the data volume as much as you can

### How reduced fact data modeling gives you superpowers
- Fact data often has this schema : user_id, event_time, action, date_partition. Very high volume, 1 row per event
- Daily aggregate often has this schema : user_id, action_count, date_partition. Medium sized volume, 1 row per user per day
- Reduced fact take this one step further: user_id, action_count Array, month_start_partition, year_start_partition. Low volume, 1 row per user per month/year

Impact on analysis : Multi-year analyses took hours instead of weeks