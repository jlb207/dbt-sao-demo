-- Analysis: month-over-month revenue trend at the sales_region level.
-- Run with `dbt compile --select monthly_revenue_trend` and inspect
-- target/compiled/.../analyses/monthly_revenue_trend.sql.
--
-- Analyses are NOT materialized — they compile to SQL the analyst can paste
-- into a query editor or BI tool.

with monthly as (

    select
        sales_region,
        order_year,
        order_month,
        net_revenue

    from {{ ref('agg_revenue_by_sales_region') }}

),

with_lag as (

    select
        *,
        lag(net_revenue) over (
            partition by sales_region
            order by order_year, order_month
        ) as prev_month_net_revenue
    from monthly

)

select
    sales_region,
    order_year,
    order_month,
    net_revenue,
    prev_month_net_revenue,
    net_revenue - prev_month_net_revenue                                as mom_delta,
    case
        when prev_month_net_revenue is null or prev_month_net_revenue = 0 then null
        else (net_revenue - prev_month_net_revenue) / prev_month_net_revenue
    end                                                                 as mom_pct_change
from with_lag
order by sales_region, order_year, order_month
