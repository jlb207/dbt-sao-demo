{{
    config(
        materialized = 'table',
        tags         = ['dimensions']
    )
}}

-- Part dimension. Joins part master data with aggregated supplier metrics
-- (supplier count, min/avg supply cost, total available quantity).

with parts as (

    select * from {{ ref('stg_tpch__parts') }}

),

part_suppliers as (

    select
        part_key,
        count(distinct supplier_key)            as supplier_count,
        min(supply_cost)                        as min_supply_cost,
        avg(supply_cost)                        as avg_supply_cost,
        max(supply_cost)                        as max_supply_cost,
        sum(available_quantity)                 as total_available_quantity

    from {{ ref('stg_tpch__part_suppliers') }}
    group by 1

),

final as (

    select
        parts.part_key,
        parts.part_name,
        parts.manufacturer,
        parts.brand,
        parts.part_type,
        parts.part_size,
        parts.container_type,
        parts.retail_price,
        coalesce(part_suppliers.supplier_count, 0)            as supplier_count,
        part_suppliers.min_supply_cost,
        part_suppliers.avg_supply_cost,
        part_suppliers.max_supply_cost,
        coalesce(part_suppliers.total_available_quantity, 0)  as total_available_quantity,
        case
            when parts.retail_price - part_suppliers.avg_supply_cost is null then null
            else parts.retail_price - part_suppliers.avg_supply_cost
        end                                                   as avg_margin

    from parts
    left join part_suppliers
        on parts.part_key = part_suppliers.part_key

)

select * from final
