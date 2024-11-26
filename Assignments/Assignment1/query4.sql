-- Backfill query for actors_history_scd
-- Write a "backfill" query that can populate the entire actors_history_scd table in a single query.
WITH with_previous AS (
    SELECT
      actor,
      current_year,
      quality_class,
      is_active,
      LAG(quality_class, 1) OVER (
        PARTITION BY
          actor
        ORDER BY
          current_year ASC
      ) AS previous_quality_class,
      lag(is_active, 1) OVER (
        PARTITION BY
          actor
        ORDER BY
          current_year ASC
      ) AS previous_is_active
    FROM
      actors
  ),
  with_indicators AS (
    SELECT
      *,
      CASE
        WHEN previous_quality_class <> quality_class
        OR previous_is_active <> is_active THEN 1
        ELSE 0
      END AS change_indicator
    FROM
      with_previous
  )
SELECT
  actor,
  quality_class as quality_class,
  is_active as is_active,
  MIN(current_year) as start_date,
  MAX(current_year) as end_date,
  2020 as current_year
FROM
  with_indicators
GROUP BY
  actor,
  quality_class,
  is_active,
  current_year;
