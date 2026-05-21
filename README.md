# tpch_state_demo

A dbt project on Redshift's TPC-H sample data, built to demonstrate **state-aware orchestration (SAO)** on the **dbt Fusion engine** via the **dbt platform**. The environment is pre-configured for evaluators — your only job is to trigger changes and observe how the Full Build job reuses vs. rebuilds nodes.

The project exercises seeds, snapshots, macros, tests, exposures, and source freshness, so you can also use it to see how the full dbt surface composes around SAO.

---

## Getting started

You've been invited to a dbt platform account with Developer access to this project.

1. **Accept the dbt platform invite** from your email.
2. **Open this project** in the dbt platform.
3. **Open the IDE.** If prompted for development credentials, enter the shared Redshift username and password your account contact provided. If you're not prompted, the connection is already configured — skip ahead.

You can now edit code in the IDE, run macros from the IDE terminal, and trigger the **Full Build** job from the Jobs page. Everything else — connection, environments, source copies, and the job — is set up for you.

---

## Project structure

```
.
├── analyses/                # Compiled-only SQL for analyst exploration
├── macros/                  # Custom Jinja macros + generate_schema_name
├── models/
│   ├── _docs/               # Doc blocks (overview + reusable definitions)
│   ├── exposures/           # Downstream dashboards / ML / ops alerts
│   ├── intermediate/        # Business-logic joins (views)
│   ├── marts/               # Facts, dimensions, aggregates + unit tests
│   └── staging/             # 1:1 with TPC-H sources (views)
├── seeds/                   # Reference CSVs (region overrides, FX, labels)
├── snapshots/               # SCD2 snapshots (customers, suppliers)
├── tests/
│   ├── generic/             # Custom generic tests (not_negative, etc.)
│   └── *.sql                # Singular tests
├── dbt_project.yml
├── packages.yml
└── selectors.yml            # Named selectors used by dbt platform jobs
```

### DAG overview

```
seed: nation_region_overrides ─┐
seed: market_segment_labels ───┤
stg_tpch__regions ─┐            │
stg_tpch__nations ─┼────────────┼──► int_orders_enriched ──┬──► fct_orders ──────────┐
stg_tpch__customers┘            │            │              │                          ├──► agg_revenue_by_nation
stg_tpch__orders ───────────────┘            │              ├──► fct_order_items ──────┤
                                              │              └──► fct_returns           │
                                              │                                          ▼
stg_tpch__parts ───┐                          │                              agg_revenue_by_sales_region
stg_tpch__suppliers┼──► int_line_items_enriched
stg_tpch__line_items┘
```

Two terminal aggregates anchor the demo:

- **`agg_revenue_by_nation`** — terminal node of the original "long chain" rooted in line items.
- **`agg_revenue_by_sales_region`** — terminal node of the chain rooted in the `nation_region_overrides` seed. Editing the seed is the richest possible state-aware demo trigger.

Exposures (`finance_executive_dashboard`, `ops_returns_alert`, `customer_churn_model`, `supplier_scorecard`) show up downstream of these marts in lineage.

---

## Evaluating state-aware orchestration

This section is the entry point for prospects evaluating SAO. The environment is pre-configured — you trigger changes and observe what the **Full Build** job reuses vs. rebuilds.

### The Full Build job

`dbt build` (and `dbt source freshness`) runs as a single prod job called **Full Build**. On Fusion, this command is state-aware: it compares the current state against the previous run's artifacts and shows each node as either **reused** (output kept from the prior run) or **rebuilt** (modified or downstream of fresher sources).

The macros below and the Full Build job are your only interface with the data.

### Two source-freshness modes are live

- `orders` and `lineitem` use an explicit `loaded_at` column.
- The other six sources (`customer`, `nation`, `part`, `partsupp`, `region`, `supplier`) rely on Fusion's warehouse-metadata fallback via `get_relation_last_modified`.

### Four ways to trigger a cascade

| # | Change | Trigger | Cascade shown in Full Build log |
|---|---|---|---|
| 1 | Edit any `.sql` model in the dbt platform IDE and commit | Run **Full Build** | Modified node + descendants are *rebuilt*; everything else is *reused* |
| 2 | Edit `seeds/nation_region_overrides.csv` in the IDE and commit | Run **Full Build** | Widest cascade — through both terminal aggregates |
| 3 | In the IDE terminal: `dbt run-operation touch_raw_sources --args '{tables: [customer]}'` | Run **Full Build** | Chain downstream of `customer` is *rebuilt* (warehouse-metadata freshness path) |
| 4 | In the IDE terminal: `dbt run-operation insert_demo_source_row --args '{table: orders}'` | Run **Full Build** | Chain downstream of `orders` is *rebuilt* (loaded_at_field freshness path) |

Paths 1 and 2 demonstrate code/seed changes. Paths 3 and 4 demonstrate upstream-data changes — path 3 exercises the lighter-touch warehouse-metadata integration, path 4 exercises the conventional `loaded_at` column integration most ELT pipelines already populate.

### Macros (the only data-manipulation interface)

Run from the dbt platform IDE terminal.

| Macro | Purpose | Required args | Optional args |
|---|---|---|---|
| `touch_raw_sources` | Simulate an upstream reload on a metadata-freshness source | `tables: [customer\|nation\|part\|partsupp\|region\|supplier]` | `method: truncate_reload \| noop_insert \| recreate` |
| `insert_demo_source_row` | Insert a new unique row with `loaded_at = now()` into a loaded_at_field source | `table: orders \| lineitem` | `count: N` |

Each macro logs what it did and prompts the next step. A third macro, `create_raw_sources`, performed the one-time setup that's already been done.

### What to look for in the Full Build run log

After any of the four triggers:

- The modified/fresher node and its descendants show as **rebuilt**.
- Every unrelated staging, intermediate, mart, seed, and snapshot node shows as **reused**.
- A baseline Full Build with no triggered change rebuilds nothing — every node is reused.

In a project this size the time savings are modest — the demo's value is the mechanism. At production scale, the same reused/rebuilt logic applies to a much larger graph.

### Sample cascades to expect (paths 1 and 2)

- **Edit `seeds/nation_region_overrides.csv`** → `nation_region_overrides` (seed) → `int_orders_enriched` → `fct_orders`, `fct_order_items`, `fct_returns`, `dim_customers`, `dim_suppliers` → `agg_revenue_by_nation`, `agg_revenue_by_sales_region`. Widest cascade.
- **Edit `models/intermediate/int_line_items_enriched.sql`** → `int_line_items_enriched` → `fct_order_items`, `fct_returns` → both aggregates. `fct_orders`, all staging, both dimensions, and `dim_dates` are reused.
- **Edit `models/staging/stg_tpch__customers.sql`** → customer chain only. `agg_revenue_by_sales_region` rebuilds (via `int_orders_enriched`); `fct_order_items` and `agg_revenue_by_nation` are reused.
- **Add a column to `models/marts/dim_dates.sql`** → just `dim_dates` rebuilds. Smallest possible cascade.

---

## Tests and selectors

The Full Build job runs every test in the project (generic, singular, and unit). Tests on reused nodes are skipped along with the node itself. Named selectors live in `selectors.yml` (`finance_only`, `marts_and_downstream`, `ci_slim`, `nightly_full_refresh`) if you want to scope ad-hoc runs from the IDE, but no selector is required for the demo.

---

## Model materialization summary

| Model | Type | Incremental key |
|---|---|---|
| stg_tpch__* (8 models) | view | — |
| int_orders_enriched | view | — |
| int_line_items_enriched | view | — |
| fct_orders | incremental | order_key |
| fct_order_items | incremental | order_item_key |
| fct_returns | incremental | order_item_key |
| dim_customers, dim_suppliers, dim_parts, dim_dates | table | — |
| agg_revenue_by_nation | incremental | nation_name + order_year + order_month |
| agg_revenue_by_sales_region | incremental | sales_region + order_year + order_month |

---

## Conventions

- **Naming** — `stg_<source>__<entity>`, `int_<entity>_<verb>`, `fct_<entity>`, `dim_<entity>`, `agg_<entity>_by_<grain>`.
- **Schemas** — `staging`, `intermediate`, `marts`, `seeds`, `snapshots`. In non-prod targets, schemas are prefixed with the developer's target schema (see `macros/generate_schema_name.sql`).
- **Tags** — `staging`, `intermediate`, `finance`, `orders`, `returns`, `revenue`, `dimensions`, `reference`.
- **Owners** — set via `meta: owner:` on each model. The values come from `vars:` in `dbt_project.yml`.

---

## Notes on the TPC-H schema

Redshift loads TPC-H sample data into a schema called `tpch`. The source tables use single-letter column prefixes (e.g. `c_custkey`, `o_orderkey`, `l_extendedprice`). All staging models rename these to readable snake_case — that renaming lives only in the `stg_` layer, keeping intermediate and mart models clean.

See `models/_docs/tpch_keys.md` for the full key mapping.
