# tpch_state_demo

A dbt project built on Redshift's TPC-H sample data, designed to run on the
**dbt Fusion engine** via the **dbt platform**, and structured to demonstrate
**state-aware orchestration** to a prospective customer. Changes anywhere in
the project produce a visible, meaningful cascade of downstream rebuilds —
making state-aware run behavior easy to show in run logs and lineage.

This project is intentionally "kitchen sink" — it exercises seeds, snapshots,
macros, custom tests, unit tests, analyses, exposures, doc blocks, hooks,
selectors, and source freshness — so the demo can pivot from "what does
state-aware do?" into "how do all the dbt project surfaces compose?"

---

## Prerequisites

- A Redshift cluster with the TPC-H sample data loaded (schema: `tpch`)
- A dbt platform account with the Redshift connection configured
- A development and a production environment in the dbt platform, with the
  Fusion engine selected
- This repository connected to the dbt platform as a project

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

## One-time setup

### 1. Point sources at your Redshift database

Open `models/staging/_tpch__sources.yml` and set `database` to your Redshift database name (default is `dev`).

### 2. Install packages

```bash
dbt deps
```

### 3. Load seeds and snapshots

```bash
dbt seed
dbt snapshot
```

### 4. First full build

```bash
dbt build
```

This builds every model, runs every test, generates the manifest, and seeds the artifact baseline that the state-aware job will defer to.

---

## dbt platform job configuration

#### Job 1 — Production Full Build

| Setting | Value |
|---|---|
| Name | `Production — Full Build` |
| Environment | Production |
| Commands | `dbt build` |
| Schedule | Nightly (or run manually to seed the baseline) |
| Generate docs | Yes |
| **Generate artifacts** | **Yes** (this is the state baseline) |

#### Job 2 — State-Aware Incremental Run

| Setting | Value |
|---|---|
| Name | `State-Aware — Modified Only` |
| Environment | Production (or a separate CI environment) |
| Commands | `dbt build --selector state_changed` |
| **Defer to** | `Production — Full Build` (under Advanced → Artifacts) |
| Schedule | On-demand or triggered by a Git push |

The `state_changed` selector lives in `selectors.yml` and resolves to "everything modified vs. the deferred artifact, plus all downstream nodes."

---

## Demo walkthrough — the rich path

Pick the change that best matches the story you're telling. Each one produces a different shape of cascade.

### Path A — Edit a seed (widest cascade)

Edit `seeds/nation_region_overrides.csv` and move one country to a different `sales_region` (e.g. UNITED KINGDOM from EMEA to NORTH AMERICA).

```bash
dbt build --selector state_changed
```

Cascade:

1. `nation_region_overrides` (seed)
2. `int_orders_enriched`
3. `fct_orders`, `fct_order_items`, `fct_returns`, `dim_customers`, `dim_suppliers`
4. `agg_revenue_by_nation`, `agg_revenue_by_sales_region`
5. Downstream exposures flagged stale in the dbt platform lineage view

Out of ~22 resources, 8–10 rebuild. The rest don't.

### Path B — Edit revenue logic (the original demo)

Edit `models/intermediate/int_line_items_enriched.sql` — change the `net_price` formula. State-aware rebuilds:

1. `int_line_items_enriched`
2. `fct_order_items`, `fct_returns`
3. `agg_revenue_by_nation`, `agg_revenue_by_sales_region`

`fct_orders`, all staging models, both dimensions, and `dim_dates` do NOT rebuild.

### Path C — Edit a staging column rename

Edit `models/staging/stg_tpch__customers.sql`. Cascade is the customer chain only — `agg_revenue_by_sales_region` rebuilds (joins via int_orders_enriched), but `fct_order_items` and `agg_revenue_by_nation` do not.

### Path D — Add a new column to dim_dates

State-aware rebuilds: just `dim_dates`. Nothing else uses it directly — the smallest possible cascade.

---

## What didn't run (for the prospect)

After triggering any state-aware run, scroll the run logs and point out what stayed green/skipped:

- All unmodified staging models
- The other intermediate model
- All marts not downstream of the change
- Snapshots — only rebuild on `dbt snapshot`
- Seeds — only rebuild on `dbt seed`

In a real customer project with 200–500 models, this pattern reduces CI/CD run time from 30–60 minutes to under 5 minutes for typical day-to-day changes.

---

## Selector reference

`selectors.yml` defines named selectors used by jobs and the IDE:

| Selector | Use |
|---|---|
| `state_changed` | Main state-aware job — modified + downstream |
| `finance_only` | All finance-tagged models + parents |
| `marts_and_downstream` | Marts layer plus exposures |
| `ci_slim` | State-aware minus snapshots and heavy-tagged models |
| `nightly_full_refresh` | Full rebuild target for the nightly batch |

Invoke a selector with:

```bash
dbt build --selector state_changed
dbt ls   --selector finance_only
```

---

## Tests

- **Generic tests** — `unique`, `not_null`, `accepted_values`, `relationships` (from dbt core) + `not_negative`, `valid_currency_code` (custom, in `tests/generic/`).
- **Singular tests** — `tests/assert_fct_orders_gross_gte_net.sql`, `tests/assert_agg_revenue_months_complete.sql`.
- **Unit tests** — `models/marts/_marts__unit_tests.yml` covers `fct_orders` aggregation and `fct_returns` filtering. Unit tests run against mocked inputs and do not require the warehouse.

```bash
dbt test                          # all tests
dbt test --select fct_orders      # node-scoped
dbt test --selector state_changed # state-aware tests only
```

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
