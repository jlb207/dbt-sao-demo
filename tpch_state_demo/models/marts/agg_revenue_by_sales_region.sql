{{
    config(
        materialized = 'incremental',
        unique_key   = ['sales_region', 'order_year', 'order_month'],
        incremental_strategy = 'delete+insert',
        tags         = ['finance', 'revenue']
    )
}}

-- Monthly revenue rolled up by internal sales_region (from the
-- nation_region_overrides seed). Sits at the end of the longest DAG branch
-- that begins at the seed:
--
--   nation_region_overrides (seed)
--     → int_orders_enriched
--       → fct_order_items
--         → agg_revenue_by_sales_region (here)
--
-- Editing the seed cascades all the way to this model under
-- `dbt build --select state:modified+`.

with order_items as (

    select
        order_key,
        order_date,
        sales_region,
        quantity,
        extended_price,
        discounted_price,
        net_price,
        discount_percentage

    from {{ ref('fct_order_items') }}

    {% if is_incremental() %}
        where order_date >= dateadd(
            'month', -1,
            date_trunc('month', (select max(order_date) from {{ this }}))
        )
    {% endif %}

),

final as (

    select
        sales_region,
        date_part('year',  order_date)::int             as order_year,
        date_part('month', order_date)::int             as order_month,
        count(distinct order_key)                       as order_count,
        sum(quantity)                                   as total_quantity,
        sum(extended_price)                             as gross_revenue,
        sum(discounted_price)                           as net_revenue,
        sum(net_price)                                  as net_revenue_after_tax,
        avg(discount_percentage)                        as avg_discount_rate

    from order_items
    group by 1, 2, 3

)

select * from final
