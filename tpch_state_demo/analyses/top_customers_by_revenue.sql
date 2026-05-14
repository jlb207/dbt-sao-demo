-- Analysis: top 50 customers by net revenue, with their geography and segment.
-- Useful for marketing / account management quarterly reviews.

with customer_revenue as (

    select
        fct_orders.customer_key,
        sum(fct_orders.net_revenue) as lifetime_net_revenue,
        count(*)                    as order_count

    from {{ ref('fct_orders') }} fct_orders
    group by 1

)

select
    customer_revenue.customer_key,
    dim_customers.customer_name,
    dim_customers.market_segment_label,
    dim_customers.nation_name,
    dim_customers.sales_region,
    customer_revenue.order_count,
    customer_revenue.lifetime_net_revenue

from customer_revenue
inner join {{ ref('dim_customers') }} dim_customers
    on customer_revenue.customer_key = dim_customers.customer_key
order by customer_revenue.lifetime_net_revenue desc
limit 50
