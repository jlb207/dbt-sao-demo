{% docs tpch_keys_overview %}

## TPC-H key conventions

All TPC-H source tables use single-letter column prefixes (`c_`, `o_`, `l_`, `s_`, `p_`, `ps_`, `n_`, `r_`). Staging models strip the prefix and convert names to snake_case:

| Source        | Source key column | Staged column   |
|---------------|-------------------|-----------------|
| customer      | c_custkey         | customer_key    |
| orders        | o_orderkey        | order_key       |
| lineitem      | l_orderkey + l_linenumber | order_key + line_number (composite) |
| supplier      | s_suppkey         | supplier_key    |
| part          | p_partkey         | part_key        |
| partsupp      | ps_partkey + ps_suppkey | composite     |
| nation        | n_nationkey       | nation_key      |
| region        | r_regionkey       | region_key      |

All keys are integers in TPC-H. The renaming logic lives only in the `stg_` layer — intermediate and mart models work with clean column names.

{% enddocs %}

{% docs fct_orders %}

Order-level fact table. Each row represents one order with summary metrics rolled up from line items. Materialized incrementally (delete+insert on `order_key`).

**State-aware behavior:** In a full production run this builds completely. In a state-aware run triggered by a change to `int_orders_enriched` or `int_line_items_enriched`, only this model and its downstream descendants are re-executed.

{% enddocs %}

{% docs order_status_code %}

Three-letter order status from the TPC-H source:

- `O` — Open / pending fulfillment
- `F` — Fulfilled
- `P` — Partial

{% enddocs %}
