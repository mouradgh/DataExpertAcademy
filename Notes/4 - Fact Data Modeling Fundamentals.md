### Introduction
Fact data is the biggest data you'll work with, it's much bigger (usually 10-100x) than dimensions 
It's every event that a user does
It's important to be careful when modeling fact data, because when poorly modeled it can drive the cost exponentially

### What is a fact ?
Think of it as something that happened : 
- A user logs in to an app
- A transaction is made
- You run a mile with your smartwatch
Facts are not slowly changing, which makes them easier to model than dimensions in some respects.

### How does fact modeling work ?
Normalization vs Denormalization :
- Noramalized : don't have any dimensional attributes, just IDs to join to get that information
- Denormalized : bring in some dimensional attributes for quicker analysis at the cost of more storage

Fact data and raw logs are not the same :
- Raw logs : ugly schemas designed for online systems, potentially contains duplicates and quality errors, usually have shorter retention
- Fact data : nice column names, quality guarantees like uniqueness/not null/... , usually have longer retentition

Who, What, Where, When, How ?
- Who fields are usually pushed out as IDs (this user clicked this button)
- Where fields can be modeled with IDs, but more likely bring in dimensions, especially if they're high cardinality like "device_id"
- How fields are very similar to "Where" (He used an iPhone to make this click)
- What fields are fundamentally part of the nature of the fact (SENT, GENERATED, CLICKED, DELIVERED...)
- When fields are mostly "event_timestamp" of "event_date"

### How does logging fit into fact data ?
Logging brings in all the critical context for your fact data
Don't log everything, only what you really need
Logging should conform to values specified by the online teams (Apache Thrift)

### Potential options when working with high volume
- Sampling : doesn't work for all use cases, works best for metric-driven use-cases where imprecision isn't an issue
- Bucketing : fact data can be bucketed by one of the important dimensions (usually user). Bucket joins can be much faster than shuffle joins. Sorted-merge Bucket (SMB) joins can do joins without Shuffle at all
## How long should you hold onto fact data ?
High volumes make fact data much more costly to hold onto for a long time
Big tech had an interesting approach : 
- Any fact tables < 10 TBs, retention didn't matter much
- Anonymisation of facts usually happened after 60-90 days, the data would be moved to a new table with the PII stripped
- Any fact tables > 100 TBs, short retention (14 days of less)
## Deduplication of fact data
Facts can often be duplicated : you can click a notification multiple times
Intraday deduping options : 
- Streaming : allows you to capture most duplicates in a very efficient manner, 15 minute to hourly windows are a sweet spot 
- Microbatch
Example : **[Microbatch Hourly Deduped Tutorial]([[https://github.com/EcZachly/microbatch-hourly-deduped-tutorial]] )**

### Use case : NBA games
CREATE TABLE fct_game_details (  
    dim_game_date DATE,  
    dim_season INTEGER,  
    dim_team_id INTEGER,  
    dim_player_id INTEGER,  
    dim_player_name TEXT,  
    dim_start_position TEXT,  
    dim_is_playing_at_home BOOLEAN,  
    dim_did_not_play BOOLEAN,  
    dim_did_not_dress BOOLEAN,  
    dim_not_with_team BOOLEAN,  
    m_minutes REAL, --m stands for measure  
    m_fgm INTEGER,  
    m_fga INTEGER,  
    m_fg3m INTEGER,  
    m_fg3a INTEGER,  
    m_ftm INTEGER,  
    m_fta INTEGER,  
    m_oreb INTEGER,  
    m_dreb INTEGER,  
    m_reb INTEGER,  
    m_ast INTEGER,  
    m_stl INTEGER,  
    m_blk INTEGER,  
    m_turnovers INTEGER,  
    m_pf INTEGER,  
    m_pts INTEGER,  
    m_plus_minus INTEGER,  
    PRIMARY KEY (dim_game_date, dim_player_id, dim_team_id)  
);  
  
INSERT INTO fct_game_details  
WITH deduped AS (  
    SELECT g.game_date_est,  
           g.season,  
           g.home_team_id,  
        gd.*, row_number() over (partition by gd.game_id, team_id, player_id ORDER BY g.game_date_est) as row_num  
    FROM game_details gd  
    JOIN games g ON gd.game_id = g.game_id  
)  
SELECT  
    game_date_est,  
    season,  
    team_id,  
    player_id,  
    player_name,  
    start_position,  
    team_id = home_team_id AS dim_is_playing_at_home,  
    COALESCE(position('DNP' in comment), 0) > 0 as dim_did_not_play,  
    COALESCE(position('DND' in comment), 0) > 0 as dim_did_not_dress,  
    COALESCE(position('NWT' in comment), 0) > 0 as dim_not_with_team,  
    CAST(split_part(min, ':', 1) AS REAL) + CAST(split_part(min, ':', 2) AS REAL)/60 as minutes,  
    fgm,  
    fga,  
    fg3m,  
    fg3a,  
    ftm,  
    fta,  
    oreb,  
    dreb,  
    reb,  
    ast,  
    stl,  
    blk,  
    "TO" AS turnovers,  
    pf,  
    pts,  
    plus_minus  
FROM deduped  
WHERE row_num = 1;