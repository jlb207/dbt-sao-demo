-- Enriches each line item with part and supplier detail, plus pre-calculated revenue fields.
-- Revenue calculations here (discounted_price, net_price) propagate downstream to
-- fct_order_items and agg_revenue_by_nation. Editing a formula in this model
-- will trigger rebuilds of both mart models in a state-aware run.

with line_items as (

    select * from {{ ref('stg_tpch__line_items') }}

),

parts as (

    select * from {{ ref('stg_tpch__parts') }}

),

suppliers as (

    select * from {{ ref('stg_tpch__suppliers') }}

),

supplier_nations as (

    select * from {{ ref('stg_tpch__nations') }}

),

final as (

    select
        -- keys
        line_items.order_key,
        line_items.part_key,
        line_items.supplier_key,
        line_items.line_number,

        -- measures
        line_items.quantity,
        line_items.extended_price,
        line_items.discount_percentage,
        line_items.tax_rate,

        -- calculated revenue fields
        line_items.extended_price
            * (1 - line_items.discount_percentage)                              as discounted_price,
        line_items.extended_price
            * (1 - line_items.discount_percentage)
            * (1 + line_items.tax_rate)                                         as net_price,

        -- logistics
        line_items.return_flag,
        line_items.line_status,
        line_items.ship_date,
        line_items.commit_date,
        line_items.receipt_date,
        line_items.ship_instructions,
        line_items.ship_mode,

        -- part attributes
        parts.part_name,
        parts.manufacturer,
        parts.brand,
        parts.part_type,
        parts.retail_price,

        -- supplier attributes
        suppliers.supplier_name,
        supplier_nations.nation_name as supplier_nation

    from line_items
    left join parts
        on line_items.part_key = parts.part_key
    left join suppliers
        on line_items.supplier_key = suppliers.supplier_key
    left join supplier_nations
        on suppliers.nation_key = supplier_nations.nation_key

)

select * from final
