### Difference with relational DM
It's RELATIONSHIP focused, not ENTITY focused
Shines to show how things are connected
Trade-off : you don't have a schema around the property, the schemas are very flexible in graphs

Usual graph database model :
- Identifier : STRING
- Type : STRING
- Properties : MAP<STRING, STRING>

### Additive dimensions 
A dimension is additive over a specific window of time, if and only if, the grain of data over that window can only ever be one value at a time!

Additive dimensions mean that you don't "double count"

Example of additive dimension : Age, the population is equal to 20 year olds + 30 year olds + ...
Example of non-additive dimension : Number of active users != # web users + # android users + # iphone users

### When should you use enums ?
Enums get you :
- built in data quality, if you get a value that is not in the enums, the pipeline fails
- built in static fields
- built in documentation

Enumerations make amazing sub partitions because : 
- you have an exhaustive list
- they chunk up the big data problem into manageable pieces
Enums are great for low-to-medium cardinality
Rule of thumb : less than 50

### What type of use cases is this enum pattern useful?
Whenever you have tons of sources mapping to a shared schema 
- Airbnb: - Unit Economics (fees, coupons, credits, insurance, infrastructure cost, taxes, etc) - 
- Netflix: - Infrastructure Graph (applications, databases, servers, code bases, CI/CD jobs, etc) 
- Facebook - Family of Apps (oculus, instagram, facebook, messenger, whatsapp, threads, etc)
### How to model data from disparate sources into a shared schema ?
Flexible schema : leverage multiple map data types

Benefits :
- You don’t have to run ALTER TABLE commands 
- You can manage a lot more columns 
- Your schemas don’t have a ton of “NULL” columns 
- “Other_properties” column is pretty awesome for rarely-used-but-needed columns  

Drawbacks :
- Compression is usually worse (especially if you use JSON) 
- Readability, queryability

### Use case : NBA 
```sql
CREATE TYPE vertex_type  
    AS ENUM ('player', 'team', 'game');  
  
CREATE TYPE edge_type  
    AS ENUM ('plays_against',  
        'shares_team',  
        'plays_in', --plays in a game  
        'plays_on'); --plays on a team  
  
CREATE TABLE vertices (  
    identifier TEXT,  
    type vertex_type,  
    properties JSON,  
    PRIMARY KEY (identifier, type)  
);  
  
CREATE TABLE edges (  
  subject_identifier TEXT,  
  subject_type vertex_type,  
  object_identifier TEXT,  
  object_type vertex_type,  
  edge_type edge_type,  
  properties JSON,  
  PRIMARY KEY (subject_identifier,  
              subject_type,  
              object_identifier,  
              object_type,  
              edge_type  
              )  
);  
  
-- Games  
INSERT INTO vertices  
SELECT game_id AS identifier,  
       'game'::vertex_type AS type,  
       json_build_object(  
    'pts_home', pts_home,  
       'pts_away', pts_away,  
       'winning_team', CASE WHEN home_team_wins = 1 THEN home_team_id ELSE visitor_team_id END  
       ) as properties  
FROM games;  
  
-- Players  
INSERT INTO vertices  
WITH players_agg AS (  
SELECT  
    player_id AS identifier,  
    MAX(player_name) AS player_name,  
    COUNT(1) as number_of_games,  
    SUM(pts) as total_points,  
    ARRAY_AGG(DISTINCT team_id) AS teams  
FROM game_details  
GROUP BY player_id  
)  
SELECT identifier,  
       'player'::vertex_type,  
       json_build_object('player_name', player_name,  
       'number_of_game', number_of_games,  
       'total_points', total_points,  
       'teams', teams  
        )  
FROM players_agg;  
  
-- Teams  
INSERT INTO vertices  
WITH teams_deduped AS (  
    SELECT *, ROW_NUMBER() OVER(PARTITION BY team_id) as row_num  
    FROM teams  
)  
SELECT  
    team_id AS identifier,  
    'team'::vertex_type AS type,  
    json_build_object(  
    'abbreviation', abbreviation,  
    'nickname', nickname,  
    'city', city,  
    'arena', arena,  
    'year_founded', yearfounded  
    )  
FROM teams_deduped  
WHERE row_num = 1;  
  
INSERT INTO edges  
WITH games_deduped AS (  
    SELECT *, row_number() over (PARTITION BY game_id, player_id) AS row_num  
    FROM game_details  
)  
SELECT  
    player_id AS subject_identifier,  
    'player'::vertex_type as subject_type,  
    game_id AS object_identifier,  
    'game'::vertex_type AS obkect_type,  
    'plays_in'::edge_type AS edge_type,  
    json_build_object(  
    'start_position', start_position,  
    'pts', pts,  
    'team_id', team_id,  
    'team_abbreviation', team_abbreviation  
    ) as properties  
FROM games_deduped  
WHERE row_num = 1;  
  
  
INSERT INTO edges  
WITH games_deduped AS (  
    SELECT *, row_number() over (PARTITION BY game_id, player_id) AS row_num  
    FROM game_details  
),  
    filtered AS (  
        SELECT * FROM games_deduped  
                 WHERE row_num = 1  
    ),  
    aggregated AS (  
       SELECT  
       f1.player_id AS subject_player_id,  
       MAX(f1.player_name) AS subject_player_name,  
       f2.player_id AS object_player_id,  
       MAX(f2.player_name) AS object_player_name,  
       CASE WHEN f1.team_abbreviation = f2.team_abbreviation THEN 'shares_team'::edge_type  
        ELSE 'plays_against'::edge_type END AS edge_type,  
    COUNT(1) AS num_games,  
    SUM(f1.pts) AS subject_points,  
    SUM(f2.pts) AS object_points  
    FROM filtered f1 JOIN filtered f2  
    ON f1.game_id = f2.game_id  
    AND f1.player_name <> f2.player_name  
    WHERE f1.player_name > f2.player_name  
    GROUP BY f1.player_id,  
       f2.player_id,  
       CASE WHEN f1.team_abbreviation = f2.team_abbreviation THEN 'shares_team'::edge_type  
        ELSE 'plays_against'::edge_type END  
    )  
SELECT  
    subject_player_id AS subject_identifier,  
    'player'::vertex_type AS subject_type,  
     object_player_id AS object_identifier,  
    'player'::vertex_type AS object_type,  
    edge_type AS edge_type,  
    json_build_object(  
    'num_games', num_games,  
    'subject_points', subject_points,  
    'object_points', object_points  
    ) AS properties  
  
FROM aggregated;  
  
SELECT  
    v.properties->>'player_name',  
    e.object_identifier,  
    CAST(v.properties->>'total_points' AS REAL) / CAST(v.properties->>'number_of_game' AS REAL) AS avg_pts  
FROM  
    vertices v  
JOIN edges e  
    ON e.subject_identifier = v.identifier  
    AND e.subject_type = v.type  
WHERE e.object_type = 'player'::vertex_type;
```