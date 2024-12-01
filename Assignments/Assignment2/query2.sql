-- A DDL for a user_devices_cumulated table
CREATE TABLE user_devices_cumulated (
    user_id text,
    device_id text,
    browser_type text,
    -- The list of date in the past where the device was active
    device_activity_datelist DATE[],
    -- The current date for the device
    date Date,
    PRIMARY KEY (user_id, device_id, browser_type, date)
);