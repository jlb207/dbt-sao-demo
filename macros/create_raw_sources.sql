{% macro create_raw_sources(tables=none, full_refresh=false) %}
  {#-
    Materializes copies of the TPC-H sample tables from
    sample_data_dev.tpch into a user-owned schema, so the copies expose
    a real last-modified timestamp via Redshift's SVV_TABLE_INFO. That
    is what dbt source freshness reads through get_relation_last_modified
    when a source has no loaded_at_field set, enabling state-aware
    orchestration via metadata freshness.

    Args:
      tables (list, optional): explicit list of source table names to
        create. Defaults to the project var 'raw_source_tables'. Pass a
        smaller list to scope a demo to specific tables.
      full_refresh (bool): when true, drops any existing copy before
        recreating. Default false uses CREATE TABLE IF NOT EXISTS, which
        leaves prior copies alone.

    Examples:
      # Create every table listed in raw_source_tables
      dbt run-operation create_raw_sources

      # Scope down to two tables
      dbt run-operation create_raw_sources --args '{tables: [customer, nation]}'

      # Force-rebuild one table
      dbt run-operation create_raw_sources --args '{tables: [orders], full_refresh: true}'
  -#}

  {% set source_db     = var('raw_source_external_database') %}
  {% set source_schema = var('raw_source_external_schema') %}
  {% set target_db     = var('raw_source_database', target.database) %}
  {% set target_schema = var('raw_source_schema') %}
  {% set default_tables = var('raw_source_tables') %}
  {% set selected = tables if tables is not none else default_tables %}

  {% if selected | length == 0 %}
    {% do exceptions.raise_compiler_error("No tables selected. Set 'raw_source_tables' in dbt_project.yml or pass --args '{tables: [...]}'.") %}
  {% endif %}

  {% do log("Ensuring schema " ~ target_db ~ "." ~ target_schema ~ " exists.", info=true) %}
  {% do run_query("create schema if not exists " ~ target_db ~ "." ~ target_schema) %}

  {% for t in selected %}
    {% if full_refresh %}
      {% do log("Dropping " ~ target_db ~ "." ~ target_schema ~ "." ~ t, info=true) %}
      {% do run_query("drop table if exists " ~ target_db ~ "." ~ target_schema ~ "." ~ t) %}
    {% endif %}

    {#-
      Redshift does not support CREATE TABLE IF NOT EXISTS ... AS SELECT
      (CTAS + IF NOT EXISTS is a PostgreSQL 9.5+ feature; Redshift forked
      from PG 8.0.2). Check existence explicitly via adapter.get_relation
      and skip when the table is already there.
    -#}
    {% set existing = adapter.get_relation(database=target_db, schema=target_schema, identifier=t) %}

    {% if existing is none %}
      {% do log("Creating " ~ target_db ~ "." ~ target_schema ~ "." ~ t ~ " from " ~ source_db ~ "." ~ source_schema ~ "." ~ t, info=true) %}
      {% set create_sql %}
        create table {{ target_db }}.{{ target_schema }}.{{ t }} as
        select * from {{ source_db }}.{{ source_schema }}.{{ t }}
      {% endset %}
      {% do run_query(create_sql) %}
    {% else %}
      {% do log("Skipping " ~ target_db ~ "." ~ target_schema ~ "." ~ t ~ " — already exists. Pass full_refresh=true to recreate.", info=true) %}
    {% endif %}
  {% endfor %}

  {% do log("Done. Next: run `dbt source freshness` to confirm metadata-based freshness produces a result for each copied table.", info=true) %}
{% endmacro %}
