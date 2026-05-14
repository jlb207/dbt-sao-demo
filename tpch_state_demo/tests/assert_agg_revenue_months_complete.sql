-- Singular test: every (nation, year) in agg_revenue_by_nation should have
-- 12 monthly buckets once a year is complete (treating the max year as
-- in-progress and excluding it from the check).
with month_counts as (

    select
        nation_name,
        order_year,
        count(distinct order_month) as month_count

    from {{ ref('agg_revenue_by_nation') }}
    where order_year < (select max(order_year) from {{ ref('agg_revenue_by_nation') }})
    group by 1, 2

)

select *
from month_counts
where month_count <> 12
