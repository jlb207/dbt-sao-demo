{{
    config(
        materialized = 'incremental',
        unique_key   = 'order_item_key',
        incremental_strategy = 'delete+insert',
        tags         = ['finance', 'orders']
    )
}}

-- Line-item level fact table. Most granular mart in the project.
-- Used for part- and supplier-level revenue analysis.
--
-- STATE-AWARE DEMO NOTE:
-- Modifying int_line_items_enriched (e.g. changing the net_price formula)
-- will trigger a state-aware rebuild of this model. Because agg_revenue_by_nation
-- refs this model, it will also be queued for rebuild — demonstrating the
-- full downstream cascade from a single logical change.

with line_items as (

    select * from {{ ref('int_line_items_enriched') }}

),

orders as (

    select
        order_key,
        order_date,
        customer_key,
        customer_nation,
        customer_region,
        sales_region,
        status_code as order_status

    from {{ ref('int_orders_enriched') }}

    {% if is_incremental() %}
        where order_date > (select max(order_date) from {{ this }})
    {% endif %}

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(
            ['line_items.order_key', 'line_items.line_number']
        ) }}                            as order_item_key,

        -- keys
        line_items.order_key,
        line_items.line_number,
        line_items.part_key,
        line_items.supplier_key,

        -- order context
        orders.order_date,
        orders.customer_key,
        orders.customer_nation,
        orders.customer_region,
        orders.sales_region,
        orders.order_status,

        -- part and supplier attributes
        line_items.part_name,
        line_items.brand,
        line_items.part_type,
        line_items.manufacturer,
        line_items.retail_price,
        line_items.supplier_name,
        line_items.supplier_nation,

        -- revenue measures
        line_items.quantity,
        line_items.extended_price,
        line_items.discount_percentage,
        line_items.tax_rate,
        line_items.discounted_price,
        line_items.net_price,

        -- logistics
        line_items.return_flag,
        line_items.ship_date,
        line_items.ship_mode

    from line_items
    inner join orders
        on line_items.order_key = orders.order_key

)

select * from final
