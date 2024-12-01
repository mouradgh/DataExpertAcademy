-- A cumulative query to generate device_activity_datelist from events
INSERT INTO user_devices_cumulated
WITH yesterday AS(
    SELECT *
    FROM user_devices_cumulated
    WHERE date = DATE('2023-01-03')
),
    today AS(
    SELECT
        CAST(e.user_id AS TEXT) as user_id,
        CAST(e.device_id AS TEXT) as device_id,
        d.browser_type,
        DATE(CAST(event_time AS TIMESTAMP)) AS device_activity_datelist
    FROM events e
	JOIN devices d
	on e.device_id  = d.device_id
    WHERE DATE(CAST(event_time AS TIMESTAMP)) = DATE('2023-01-04')
    AND user_id IS NOT NULL
    GROUP BY e.user_id, e.device_id, d.browser_type, DATE(CAST(event_time AS TIMESTAMP))
    )
SELECT
    COALESCE(t.user_id, y.user_id) AS user_id,
    COALESCE(t.device_id, y.device_id) AS device_id,
    COALESCE(t.browser_type, y.browser_type) AS browser_type,
    CASE WHEN y.device_activity_datelist IS NULL THEN ARRAY[t.device_activity_datelist]
        WHEN t.device_activity_datelist IS NULL THEN y.device_activity_datelist
        ELSE ARRAY[t.device_activity_datelist] || y.device_activity_datelist
        END
        as device_activity_datelist,
    COALESCE(t.device_activity_datelist, y.date + Interval '1 day') AS date
FROM today t
FULL OUTER JOIN yesterday y
ON t.user_id = y.user_id;

