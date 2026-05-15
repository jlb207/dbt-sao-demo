{% docs __overview__ %}

# tpch_state_demo

dbt project built on Redshift's TPC-H sample data and run on the **dbt Fusion engine** via the **dbt platform**. Designed to demonstrate **state-aware orchestration**: how `--select state:modified+` plus deferred artifacts let a CI run rebuild only the models affected by a change, rather than the full DAG.

## Layers

- **Sources** — raw TPC-H tables in the `tpch` schema (customer, orders, lineitem, supplier, part, partsupp, nation, region).
- **Seeds** — `nation_region_overrides`, `market_segment_labels`, `fx_rates`. Editing a seed is the fastest way to trigger a cascade.
- **Snapshots** — SCD2 history of customers and suppliers.
- **Staging** — 1:1 with sources, snake_case renames only.
- **Intermediate** — business-logic joins (orders × customer geography, line items × parts/suppliers).
- **Marts** — facts (orders, order_items, returns), dimensions (customers, suppliers, parts, dates), aggregates (revenue by nation and sales_region).
- **Exposures** — downstream dashboards, ML models, and ops alerts.

## State-aware demo path

The richest cascade in the project is rooted at `nation_region_overrides`:

`nation_region_overrides` → `int_orders_enriched` → `fct_orders`, `fct_order_items`, `fct_returns` → `agg_revenue_by_nation`, `agg_revenue_by_sales_region` → exposures

Moving a country between sales regions in the seed rebuilds every model on that chain — and the exposures show up in lineage as needing refresh.

{% enddocs %}
