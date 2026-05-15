-- Singular test: gross_revenue must be >= net_revenue on every order.
-- Discounts can only reduce revenue, never increase it.
select
    order_key,
    gross_revenue,
    net_revenue
from {{ ref('fct_orders') }}
where net_revenue > gross_revenue
