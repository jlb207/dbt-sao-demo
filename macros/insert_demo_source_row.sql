{% macro insert_demo_source_row(table, count=1) %}
  {#-
    Inserts one or more new rows into a raw source table that has a
    loaded_at column (orders, lineitem). Each row gets a fresh primary
    key (max + 1, incrementing), valid TPC-H-shaped values for the
    other required columns, and CURRENT_TIMESTAMP for loaded_at — so
    the loaded_at_field-based check in `dbt source freshness` sees the
    table as newer than the prior run, and `dbt build --select
    source_status:fresher+` cascades through any model downstream of it.

    Companion to touch_raw_sources, which targets the metadata-freshness
    sources (the six without loaded_at_field). This macro targets the
    loaded_at_field sources, so the same SAO demo loop works for both
    freshness modes.

    Args:
      table (str): which source table to insert into. 'orders' or 'lineitem'.
      count (int, optional): how many rows to insert. Default 1.

    Examples:
      # One row in orders
      dbt run-operation insert_demo_source_row --args '{table: orders}'

      # Three new lineitems in one call
      dbt run-operation insert_demo_source_row --args '{table: lineitem, count: 3}'
  -#}

  {% set supported = ['orders', 'lineitem'] %}
  {% if table not in supported %}
    {% do exceptions.raise_compiler_error("insert_demo_source_row supports " ~ supported ~ ". Got: " ~ table) %}
  {% endif %}
  {% if count < 1 %}
    {% do exceptions.raise_compiler_error("count must be >= 1. Got: " ~ count) %}
  {% endif %}

  {% set target_db     = var('raw_source_database') %}
  {% set target_schema = var('raw_source_schema') %}
  {% set fqn = target_db ~ "." ~ target_schema ~ "." ~ table %}

  {#- Pull the current max PK once; each generated row gets max + i + 1. -#}
  {% if table == 'orders' %}
    {% set pk_col = 'o_orderkey' %}
  {% else %}
    {% set pk_col = 'l_orderkey' %}
  {% endif %}

  {% set max_pk_result = run_query("select coalesce(max(" ~ pk_col ~ "), 0) from " ~ fqn) %}
  {% set max_pk = max_pk_result.rows[0][0] %}

  {#- Build a single multi-row INSERT statement for efficiency. -#}
  {% set values_rows = [] %}
  {% for i in range(count) %}
    {% set new_pk = max_pk + i + 1 %}

    {% if table == 'orders' %}
      {% set row %}
        (
          {{ new_pk }},
          1,
          'O',
          100.00,
          current_date,
          '1-URGENT',
          'Clerk#000000001',
          0,
          'Demo insert via insert_demo_source_row',
          current_timestamp
        )
      {% endset %}
    {% else %}
      {% set row %}
        (
          {{ new_pk }},
          1,
          1,
          1,
          10,
          100.00,
          0.05,
          0.08,
          'N',
          'O',
          current_date + 7,
          current_date + 14,
          current_date + 10,
          'DELIVER IN PERSON',
          'AIR',
          'Demo insert via insert_demo_source_row',
          current_timestamp
        )
      {% endset %}
    {% endif %}

    {% do values_rows.append(row) %}
  {% endfor %}

  {% if table == 'orders' %}
    {% set column_list %}
      o_orderkey, o_custkey, o_orderstatus, o_totalprice, o_orderdate,
      o_orderpriority, o_clerk, o_shippriority, o_comment, loaded_at
    {% endset %}
  {% else %}
    {% set column_list %}
      l_orderkey, l_partkey, l_suppkey, l_linenumber, l_quantity,
      l_extendedprice, l_discount, l_tax, l_returnflag, l_linestatus,
      l_shipdate, l_commitdate, l_receiptdate, l_shipinstruct,
      l_shipmode, l_comment, loaded_at
    {% endset %}
  {% endif %}

  {% set insert_sql %}
    insert into {{ fqn }} (
      {{ column_list }}
    )
    values
    {{ values_rows | join(",\n") }}
  {% endset %}

  {% do run_query(insert_sql) %}

  {% set first_pk = max_pk + 1 %}
  {% set last_pk = max_pk + count %}
  {% do log(
    "Inserted " ~ count ~ " row(s) into " ~ fqn ~
    " with " ~ pk_col ~ " in [" ~ first_pk ~ ", " ~ last_pk ~ "] and loaded_at = now.",
    info=true
  ) %}
  {% do log("Next: dbt source freshness  →  dbt build --select source_status:fresher+", info=true) %}
{% endmacro %}
