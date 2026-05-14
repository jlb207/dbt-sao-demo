-- Analysis: supplier concentration risk. For each sales_region, what % of
-- net revenue is attributable to the top 5 suppliers? Used by procurement
-- to identify regions with concentration risk.

with supplier_revenue as (

    select
        fct_order_items.sales_region,
        fct_order_items.supplier_key,
        sum(fct_order_items.discounted_price) as net_revenue
    from {{ ref('fct_order_items') }} fct_order_items
    group by 1, 2

),

ranked as (

    select
        *,
        row_number() over (
            partition by sales_region
            order by net_revenue desc
        ) as supplier_rank,
        sum(net_revenue) over (
            partition by sales_region
        ) as region_net_revenue
    from supplier_revenue

)

select
    sales_region,
    sum(case when supplier_rank <= 5 then net_revenue else 0 end)             as top_5_net_revenue,
    max(region_net_revenue)                                                   as region_net_revenue,
    sum(case when supplier_rank <= 5 then net_revenue else 0 end)
        / nullif(max(region_net_revenue), 0)                                  as top_5_share
from ranked
group by 1
order by top_5_share desc
