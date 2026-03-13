-- DATA LEMUR 
WITH RankedSalaries AS (
  SELECT
    d.department_name,
    e.name,
    e.salary,
    DENSE_RANK() OVER (
      PARTITION BY e.department_id
      ORDER BY e.salary DESC
    ) AS salary_rank
  FROM employee AS e
  JOIN department AS d
    ON e.department_id = d.department_id
)
SELECT
  department_name,
  name,
  salary
FROM RankedSalaries
WHERE salary_rank <= 3
ORDER BY
  department_name ASC,
  salary DESC,
  name ASC;

-- Try it 1

select b.*,
       count(*) over (
         partition by SHAPE
       ) as bricks_per_shape,
       median ( weight ) over (
         partition by weight
       ) median_weight_per_shape
from   bricks b
order  by shape, weight, brick_id;

-- Try it 2

select b.brick_id, b.weight,
       round ( avg ( weight ) over (
         order by weight
       ), 2 ) running_average_weight
from   bricks b
order  by brick_id;

-- Try 3

select b.*,
       min ( colour ) over (
         order by brick_id
         rows BETWEEN 2 PRECEDING AND 1 PRECEDING
       ) as first_colour_two_prev,
       count (*) over (
         order by weight
         range BETWEEN CURRENT ROW AND 1 FOLLOWING
       ) as count_values_this_and_next
from   bricks b
order  by weight;

-- Try 4

with totals as (
  select b.*,
         sum ( weight ) over (
           PARTITION BY shape
         ) as weight_per_shape,
         sum ( weight ) over (
           ORDER BY brick_id
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
         ) as running_weight_by_id
  from   bricks b
)
select * from totals
where  weight_per_shape > 4
    AND running_weight_by_id > 4
order  by brick_id