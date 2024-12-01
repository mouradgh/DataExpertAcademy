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
