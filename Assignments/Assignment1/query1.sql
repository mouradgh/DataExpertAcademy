-- Creating the array type that will be used in the films field of the actor table
CREATE TYPE films AS (
    film TEXT,
    votes INTEGER,
    rating REAL,
    filmid TEXT
);

-- Creating a type for the quality_class field of the actor table
CREATE TYPE quality_class AS ENUM('star', 'good', 'average', 'bad');

-- Creating the actors table
CREATE TABLE actors (
    actorid TEXT,
    current_year INTEGER,
    actor TEXT,
    films films[],
    quality_class quality_class,
    is_active BOOLEAN,
    PRIMARY KEY (actorid, current_year)
);
