{{
    config(
        materialized = 'incremental',
        unique_key   = 'order_key',
        incremental_strategy = 'delete+insert',
        tags         = ['finance', 'orders']
    )
}}

-- Order-level fact table. Each row represents one order with summary metrics
-- rolled up from line items.
--
-- STATE-AWARE DEMO NOTE:
-- This model is incremental (delete+insert on order_key). In a full production
-- run it builds completely. In a state-aware run triggered by a change to
-- int_orders_enriched or int_line_items_enriched, only this model and its
-- downstream sibling agg_revenue_by_nation will be re-executed.

with orders as (

    select * from {{ ref('int_orders_enriched') }}

    {% if is_incremental() %}
        -- Only process orders newer than the latest already loaded.
        -- On first run (full build), this filter is skipped.
        where order_date > (select max(order_date) from {{ this }})
    {% endif %}

),

line_item_summary as (

    select
        order_key,
        count(*)                        as line_item_count,
        sum(extended_price)             as gross_revenue,
        sum(discounted_price)           as net_revenue,
        sum(net_price)                  as net_revenue_after_tax,
        sum(quantity)                   as total_quantity,
        min(ship_date)                  as first_ship_date,
        max(ship_date)                  as last_ship_date,
        avg(discount_percentage)        as avg_discount_rate

    from {{ ref('int_line_items_enriched') }}
    group by 1

),

final as (

    select
        orders.order_key,
        orders.customer_key,
        orders.customer_name,
        orders.customer_nation,
        orders.customer_region,
        orders.sales_region,
        orders.market_segment,
        orders.order_date,
        orders.status_code,
        orders.priority_code,
        orders.total_price,
        orders.clerk_name,
        line_item_summary.line_item_count,
        line_item_summary.gross_revenue,
        line_item_summary.net_revenue,
        line_item_summary.net_revenue_after_tax,
        line_item_summary.total_quantity,
        line_item_summary.avg_discount_rate,
        line_item_summary.first_ship_date,
        line_item_summary.last_ship_date

    from orders
    left join line_item_summary
        on orders.order_key = line_item_summary.order_key

)

select * from final
