{{
    config(
        materialized = 'incremental',
        unique_key   = ['nation_name', 'order_year', 'order_month'],
        incremental_strategy = 'delete+insert',
        tags         = ['finance', 'revenue']
    )
}}

-- Monthly revenue summary by customer nation. A good high-level reporting table
-- for the prospect to query directly.
--
-- STATE-AWARE DEMO NOTE:
-- This model sits at the end of the longest DAG chain in the project:
--   stg_tpch__line_items
--     → int_line_items_enriched
--       → fct_order_items
--         → agg_revenue_by_nation (here)
--
-- A change anywhere in that chain will cause dbt to rebuild every model in it
-- when using `--select state:modified+`. This is the model to point to when
-- showing the prospect the full cascade in the run logs.

with order_items as (

    select
        order_key,
        order_date,
        customer_nation,
        quantity,
        extended_price,
        discounted_price,
        net_price,
        discount_percentage

    from {{ ref('fct_order_items') }}

    {% if is_incremental() %}
        -- Re-process the last full month plus anything newer to handle
        -- late-arriving data without a full refresh.
        where order_date >= (
            select dateadd('month', -1, date_trunc('month', max(order_date)))
            from {{ this }}
        )
    {% endif %}

),

final as (

    select
        customer_nation                             as nation_name,
        date_part('year',  order_date)::int         as order_year,
        date_part('month', order_date)::int         as order_month,
        count(distinct order_key)                   as order_count,
        sum(quantity)                               as total_quantity,
        sum(extended_price)                         as gross_revenue,
        sum(discounted_price)                       as net_revenue,
        sum(net_price)                              as net_revenue_after_tax,
        avg(discount_percentage)                    as avg_discount_rate

    from order_items
    group by 1, 2, 3

)

select * from final
