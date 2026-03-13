--lesson 1
-Find the title of each film 
SELECT Title FROM movies;

-Find the director of each film
SELECT Director FROM movies;

-Find the title and director of each film
SELECT Title, Director FROM movies;

-Find the title and year of each film 
SELECT Title, Year FROM movies;

-Find all the information about each film
SELECT * FROM movies;



--lesson 2
-Find the movie with a row id of 6 

SELECT Id, Title FROM movies WHERE Id=6;

- Find the movies released in the years between 2000 and 2010

SELECT Title FROM movies WHERE Year BETWEEN 2000 AND 2010;

-Find the movies not released in the years between 2000 and 2010

SELECT Title FROM movies WHERE Year NOT BETWEEN 2000 AND 2010;

-Find the first 5 Pixar movies and their release year

SELECT Title FROM movies WHERE Id  BETWEEN 1 AND 5;



-- lesson 3

- Find all the Toy Story movies

SELECT Title FROM movies WHERE Title LIKE "%Toy Story%";

- Find all the movies (and director) not directed by John Lasseter

SELECT Title FROM movies WHERE Director LIKE "%John Lasseter%";

-Find all the movies (and director) not directed by John Lasseter

SELECT Title, Director FROM movies WHERE Director NOT LIKE "%John Lasseter%";

- Find all the WALL-* movies
SELECT Title FROM movies WHERE Title LIKE "WALL-_";

-- lesson 4
- List all directors of Pixar movies (alphabetically), without duplicates 
SELECT DISTINCT Director FROM movies ORDER BY Director ASC;

- List the last four Pixar movies released (ordered from most recent to least)
SELECT Title FROM movies ORDER BY Year DESC LIMIT 4 OFFSET -1;

-List the first five Pixar movies sorted alphabetically
SELECT Title FROM movies ORDER BY Title ASC LIMIT 4 OFFSET 0;

- List the next five Pixar movies sorted alphabetically
SELECT Title FROM movies ORDER BY Title ASC LIMIT 5 OFFSET 5 ;

-- lesson 5
-List all the Canadian cities and their populations
SELECT City, Population FROM north_american_cities WHERE Country LIKE "%Canada%";

-Order all the cities in the United States by their latitude from north to south
SELECT City FROM north_american_cities WHERE Country LIKE "%United States%" ORDER BY Latitude DESC;

- List all the cities west of Chicago, ordered from west to east
SELECT City FROM north_american_cities WHERE Longitude < (SELECT Longitude FROM north_american_cities WHERE City ="Chicago") ORDER BY Longitude ASC

-List the two largest cities in Mexico (by population)
SELECT City FROM north_american_cities WHERE Country = "Mexico"ORDER BY population DESC LIMIT 2;

-List the third and fourth largest cities (by population) in the United States and their population
SELECT City FROM north_american_cities WHERE Country = "United States" ORDER BY Population DESC LIMIT 2 OFFSET 2 ;