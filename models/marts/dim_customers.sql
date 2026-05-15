{{
    config(
        materialized = 'table',
        tags         = ['dimensions']
    )
}}

-- Customer dimension. Denormalizes customer with nation, region, and the
-- internal sales_region from the nation_region_overrides seed. Display label
-- for market_segment is resolved via the get_market_segment_label macro.

with customers as (

    select * from {{ ref('stg_tpch__customers') }}

),

nations as (

    select * from {{ ref('stg_tpch__nations') }}

),

regions as (

    select * from {{ ref('stg_tpch__regions') }}

),

sales_regions as (

    select * from {{ ref('nation_region_overrides') }}

),

final as (

    select
        customers.customer_key,
        customers.customer_name,
        customers.customer_address,
        customers.phone_number,
        customers.account_balance,
        customers.market_segment,
        {{ get_market_segment_label('customers.market_segment') }}  as market_segment_label,
        nations.nation_name,
        regions.region_name,
        coalesce(sales_regions.sales_region, regions.region_name)   as sales_region

    from customers
    left join nations
        on customers.nation_key = nations.nation_key
    left join regions
        on nations.region_key = regions.region_key
    left join sales_regions
        on nations.nation_name = sales_regions.nation_name

)

select * from final
