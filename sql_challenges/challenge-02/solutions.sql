SELECT * FROM movies
inner join Boxoffice
on movies.id=Boxoffice.Movie_id;

SELECT * FROM movies
inner join Boxoffice
on movies.id=Boxoffice.Movie_id
where International_sales> Domestic_sales;

SELECT * FROM movies
inner join Boxoffice
on movies.id=Boxoffice.Movie_id
order by Rating desc;

-------

SELECT DISTINCT Building_name
FROM Buildings
JOIN employees
ON Buildings.Building_name=Employees.Building;


SELECT * from Buildings


SELECT DISTINCT 
    Buildings.Building_name,
    Employees.Role
FROM Buildings
LEFT JOIN Employees
    ON Buildings.Building_name = Employees.Building
ORDER BY Buildings.Building_name;

-------
SELECT pages.page_id
FROM pages
LEFT JOIN page_likes
ON pages.page_id=page_likes.page_id
WHERE liked_date IS NULL 
order by page_id;
