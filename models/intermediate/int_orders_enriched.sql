-- Enriches each order with customer, nation, and region context.
-- This model is the primary join point between orders and the customer geography hierarchy.
-- Changing stg_tpch__customers or stg_tpch__nations will cascade a rebuild here
-- and downstream to fct_orders — a good state-aware orchestration demo target.

with orders as (

    select * from {{ ref('stg_tpch__orders') }}

),

customers as (

    select * from {{ ref('stg_tpch__customers') }}

),

nations as (

    select * from {{ ref('stg_tpch__nations') }}

),

regions as (

    select * from {{ ref('stg_tpch__regions') }}

),

sales_region_overrides as (

    -- Internal go-to-market region mapping. Editing nation_region_overrides.csv
    -- cascades a state-aware rebuild through every model downstream of this CTE.
    select * from {{ ref('nation_region_overrides') }}

),

customer_geography as (

    select
        customers.customer_key,
        customers.customer_name,
        customers.market_segment,
        customers.account_balance,
        nations.nation_name                                  as customer_nation,
        regions.region_name                                  as customer_region,
        coalesce(sales_region_overrides.sales_region,
                 regions.region_name)                        as sales_region
        'test' as                                            as test         

    from customers
    left join nations
        on customers.nation_key = nations.nation_key
    left join regions
        on nations.region_key = regions.region_key
    left join sales_region_overrides
        on nations.nation_name = sales_region_overrides.nation_name

),

final as (

    select
        orders.order_key,
        orders.customer_key,
        orders.order_date,
        orders.status_code,
        orders.priority_code,
        orders.total_price,
        orders.clerk_name,
        orders.ship_priority,
        customer_geography.customer_name,
        customer_geography.market_segment,
        customer_geography.account_balance,
        customer_geography.customer_nation,
        customer_geography.customer_region,
        customer_geography.sales_region

    from orders
    left join customer_geography
        on orders.customer_key = customer_geography.customer_key

)

select * from final
