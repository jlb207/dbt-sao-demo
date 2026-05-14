{{
    config(
        materialized = 'table',
        tags         = ['dimensions']
    )
}}

-- Supplier dimension. Denormalizes supplier with nation, region, and
-- internal sales_region from the nation_region_overrides seed.

with suppliers as (

    select * from {{ ref('stg_tpch__suppliers') }}

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
        suppliers.supplier_key,
        suppliers.supplier_name,
        suppliers.supplier_address,
        suppliers.phone_number,
        suppliers.account_balance,
        nations.nation_name,
        regions.region_name,
        coalesce(sales_regions.sales_region, regions.region_name)   as sales_region

    from suppliers
    left join nations
        on suppliers.nation_key = nations.nation_key
    left join regions
        on nations.region_key = regions.region_key
    left join sales_regions
        on nations.nation_name = sales_regions.nation_name

)

select * from final
