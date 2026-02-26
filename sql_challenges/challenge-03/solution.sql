select max(Years_employed) from Employees;

SELECT avg(Years_employed), *
FROM employees
group by Role;

SELECT sum(Years_employed),*
FROM employees
group by building;


SELECT count(*)
FROM employees
where Role='Artist';

SELECT count(*),*
FROM employees
GROUP BY Role;

SELECT sum(Years_employed)
FROM employees
Where Role='Engineer';

-- Try 1

select count(shape) as number_of_shapes,
        stddev(distinct weight) as distinct_weight_stddev
from   bricks;

-- Try 2

select shape,sum(weight)as shape_weight
from   bricks
group by shape;


-- Try 3

select shape, sum ( weight )
from   bricks
group by shape
having sum(weight)<4;