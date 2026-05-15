{{
    config(
        materialized = 'incremental',
        unique_key   = 'order_item_key',
        incremental_strategy = 'delete+insert',
        tags         = ['finance', 'returns']
    )
}}

-- Returned line items only (return_flag = 'R'). Used by the customer service
-- and finance teams to track returns volume by part, supplier, and nation.
--
-- STATE-AWARE DEMO NOTE:
-- This is a second downstream branch off int_line_items_enriched. A change to
-- the line item revenue logic will rebuild fct_order_items AND fct_returns AND
-- agg_revenue_by_nation in a single state-aware pass — a wider cascade than
-- the original three-model demo.

with line_items as (

    select * from {{ ref('int_line_items_enriched') }}
    where return_flag = 'R'

),

orders as (

    select
        order_key,
        order_date,
        customer_key,
        customer_nation,
        customer_region,
        sales_region

    from {{ ref('int_orders_enriched') }}

    {% if is_incremental() %}
        where order_date > (select max(order_date) from {{ this }})
    {% endif %}

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(
            ['line_items.order_key', 'line_items.line_number']
        ) }}                                            as order_item_key,

        line_items.order_key,
        line_items.line_number,
        line_items.part_key,
        line_items.supplier_key,

        orders.order_date,
        orders.customer_key,
        orders.customer_nation,
        orders.customer_region,
        orders.sales_region,

        line_items.part_name,
        line_items.brand,
        line_items.supplier_name,
        line_items.supplier_nation,

        line_items.quantity                             as returned_quantity,
        line_items.extended_price                       as returned_gross_amount,
        line_items.discounted_price                     as returned_net_amount,
        line_items.receipt_date                         as return_receipt_date

    from line_items
    inner join orders
        on line_items.order_key = orders.order_key

)

select * from final
