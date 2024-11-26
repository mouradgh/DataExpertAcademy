-- The query that populates the actors table one year at a time
WITH yesterday AS(
    SELECT * FROM actors
             WHERE current_year = 1973
),
    today AS (
    SELECT
                actorid,
                actor,
                array_agg(row(film, votes, rating, filmid)::films) as films,
                year,
                avg(rating) as rating
    FROM actor_films
    WHERE year = 1974
    GROUP BY actorid, actor, year
    )

SELECT
    COALESCE(t.actorid, y.actorid) AS actorid,
    COALESCE(t.year, y.current_year + 1) AS current_year,
    COALESCE(t.actor, y.actor) AS actor,

    CASE WHEN y.films IS NULL
    THEN t.films
    WHEN y.films IS NOT NULL THEN y.films || t.films
    ELSE y.films
    END as films,

    CASE WHEN t.year IS NOT NULL THEN
        CASE WHEN t.rating > 8 THEN 'star'
            WHEN t.rating > 7 THEN 'good'
            WHEN t.rating > 6 THEN 'average'
            ELSE 'bad'
        END::quality_class
        ELSE y.quality_class
    END as quality_class,

    CASE WHEN t.year IS NOT NULL then TRUE
        ELSE FALSE
    END as is_active
FROM today t
    FULL OUTER JOIN yesterday y
ON t.actorid = y.actorid;