### What is Apache Spark ?
Spark is a distributed compute framework that allows you to process very large amount of data efficiently. It's the successor of MapReduce, Hadoop and Hive.

### Why is Spark so good ?
- Spark leverages RAM much more effectively than previous iterations of distributed compute (way faster than Hive/JAVA MR/etc)
- Spark is storage agnostic, allowing a decoupling of storage and compute
- Spark has a huge community of developers so StackOverflow/ChatGPT will help you troubleshoot

### When is Spark not so good ?
- If nobody else in the team/company knows Spark
- If the company already uses something else a lot (BigQuery, Snowflake...), it's better to have 20 big query pipelines than 19 bigquert pipelines and 1 spark pipeline

### How does Spark work ?
Spark has a few pieces to it, if Spark was a basketball team, it would be :

- The plan : the play/strategy
This is the transformation you describe in Python, Scala or SQL
The plan is evaluated lazily : execution only happens when it needs to
When does execution need to happen : writing output or when part the plan depends on the data itself (e.g. calling dataframe.colleect() to determin the next set of transformations)

- The driver : the coach of the team
The driver reads the plan
Important Spark driver settings : spark.driver.memory / spark.driver.memoryOverheadFactor
The rest of the settings shouldn't be touched
The driver determines when to actually start executing the job and stop being lazy, how to join datasets, as well as how much parallelism each step needs

- The executors : the players 
The driver passes the plan to the executors who do the actual work (transform, filter, aggregate...)
The settings that should be defined : spark.executor.memory - a low number lay cause "spill to disk" which will cause your job to slow down / spark.executor.cores - default is 4, shouldn't go higher than 6 / spark.executor.memoryOverheadFactor - usually 10%

### The types of JOINs in Spark
- Shuffle sort-merge join : the least performant, but useful because it's the most versatile and always works, especially when both sides of the join are large
- Broadcast hash join : Works well if one side of the join in small
- Bucket joins : a join without shuffle

### Is Shuffle good or bad ? 
At low-to-medium volume it's really good and makes lives easier
At high volumes >10Tb it's painful and better avoided

### How to minimize shuffle at high volumes ?
- Bucket the data if multiple JOINs or aggregations are happening downstream 
- Spark has the ability to bucket data to minimize or eliminate the need for shuffle when doing JOINs
- Bucket joins are very efficient but have drawbacks, the main drawback is the initial parallelism = number of buckets. Bucket joins only work if the two tables number of buckets are multiples of each other : always use powers of 2 for # of buckets

### Shuffle and Skew
Sometimes some partitions have dramatically more data than other, this can happen because there aren't enough partitions or the natural way the data is (Beyonce gets a lot more notifications than the average Facebook user)

You can tell that your data is skewed if your job is getting to 99%, taking forever and then failing.

To avoid that, you can do a box and whiskers plot of the data to see if there's any extreme outliers

You can deal with skew in multiple ways :
- Adaptive query execution - only in Spark 3+ : Set spark.sql.adaptive.enabled = True 
- Salting the GROUP BY = best option before Spark 3 : Group by a random number, aggregate + group by again. Be careful with things like AVG, break it into SUM and COUNT and divide
- One side of the pipeline that processes the outliers (Beyonce) and another side that processes everyone else
- Use explain() to show the join strategies that Spark will take

```Python
df.withColumn("salt_random_column", (rand * n).cast(IntegerType))
.groupBy(groupByFields, "salt_random_column")
.agg(aggFields)
.groupBy(groupByFields)
.agg(aggFields)

```
### How can Spark read data ?
- From the lake : Delta Lake, Apache Iceberg, Hive metastore...
- From an RDBMS : Postgres, Oracle...
- From an API : make a REST call and turn into data, not advised if you're making multiple calls
- From a flat file : CSV, JSON...

### Spark output datasets
The output should almost always be partitioned on "date" which is the execution date of the pipeline

### Lab 
```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import expr, col, lit
spark = SparkSession.builder.appName("Jupyter").getOrCreate()

spark

df = spark.read.option("header", "true") \
.csv("/home/iceberg/data/events.csv") \
.withColumn("event_date", expr("DATE_TRUNC('day', event_time)"))

# Use take instead of collect to not cause an out of memory error
df.join(df, lit(1) == lit(1)).take(5)

# Split the data by event_date
sorted = df.repartition(10, col("event_date")) \
# sortWithinPartitions - Will sort locally in each partition
# sort - Global sort of the data, as far back as you can go, it's very slow
        .sortWithinPartitions(col("event_date"), col("host"), col("browser_family")) \
        .withColumn("event_time", col("event_time").cast("timestamp")) \

sorted.explain()
sorted.show()
```

```sql
CREATE DATABASE IF NOT EXISTS bootcamp

CREATE TABLE IF NOT EXISTS bootcamp.events (
    url STRING,
    referrer STRING,
    browser_family STRING,
    os_family STRING,
    device_family STRING,
    host STRING,
    event_time TIMESTAMP,
    event_date DATE
)
USING iceberg
PARTITIONED BY (years(event_date));

CREATE TABLE IF NOT EXISTS bootcamp.events_sorted (
    url STRING,
    referrer STRING,
    browser_family STRING,
    os_family STRING,
    device_family STRING,
    host STRING,
    event_time TIMESTAMP,
    event_date DATE
)
USING iceberg;

CREATE TABLE IF NOT EXISTS bootcamp.events_unsorted (
    url STRING,
    referrer STRING,
    browser_family STRING,
    os_family STRING,
    device_family STRING,
    host STRING,
    event_time TIMESTAMP,
    event_date DATE
)
USING iceberg;
```

```python
start_df = df.repartition(4, col("event_date")).withColumn("event_time", col("event_time").cast("timestamp")) \
    

first_sort_df = start_df.sortWithinPartitions(col("event_date"), col("browser_family"), col("host"))

sorted = df.repartition(10, col("event_date")) \
        .sortWithinPartitions(col("event_date")) \
        .withColumn("event_time", col("event_time").cast("timestamp")) \

start_df.write.mode("overwrite").saveAsTable("bootcamp.events_unsorted")
first_sort_df.write.mode("overwrite").saveAsTable("bootcamp.events_sorted")
sorted.write.mode("overwrite").saveAsTable("bootcamp.events")
```

```sql
SELECT SUM(file_size_in_bytes) as size, COUNT(1) as num_files, 'sorted' 
FROM demo.bootcamp.events_sorted.files

UNION ALL
SELECT SUM(file_size_in_bytes) as size, COUNT(1) as num_files, 'unsorted' 
FROM demo.bootcamp.events_unsorted.files
```

