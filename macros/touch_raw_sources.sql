{% macro touch_raw_sources(tables=none, method='truncate_reload') %}
  {#-
    Simulates a fresh upstream load against the copied raw source tables
    by updating their last-modified metadata in Redshift. After running
    this, `dbt source freshness` will see those sources as newer than
    the prior run, and `dbt build --select source_status:fresher+` will
    cascade rebuilds downstream — the state-aware demo moment.

    Args:
      tables (list): explicit list of source table names to touch.
        Required; this macro intentionally does not touch everything by
        default so demo cascades are scoped.
      method (str): how to bump last-modified. One of:
        - 'truncate_reload' (default): TRUNCATE + INSERT ... SELECT * FROM
          the original sample_data_dev source. Closest to a real ELT
          loader's behavior and reliably updates SVV_TABLE_INFO.modified.
        - 'noop_insert': INSERT INTO ... SELECT * FROM <self> WHERE 1=0.
          Faster (no data movement) but Redshift may or may not bump
          modified for a zero-row insert depending on cluster behavior.
        - 'recreate': DROP + CREATE TABLE AS. Most authentic but slow on
          large tables (lineitem).

    Examples:
      # Most realistic: simulate a customer-table reload from upstream
      dbt run-operation touch_raw_sources --args '{tables: [customer]}'

      # Fast smoke test against multiple tables
      dbt run-operation touch_raw_sources --args '{tables: [customer, orders], method: noop_insert}'
  -#}

  {% if tables is none or tables | length == 0 %}
    {% do exceptions.raise_compiler_error("touch_raw_sources requires an explicit tables list, e.g. --args '{tables: [customer]}'.") %}
  {% endif %}

  {% set valid_methods = ['truncate_reload', 'noop_insert', 'recreate'] %}
  {% if method not in valid_methods %}
    {% do exceptions.raise_compiler_error("method must be one of " ~ valid_methods ~ ", got: " ~ method) %}
  {% endif %}

  {% set source_db     = var('raw_source_external_database') %}
  {% set source_schema = var('raw_source_external_schema') %}
  {% set target_db     = var('raw_source_database', target.database) %}
  {% set target_schema = var('raw_source_schema') %}

  {% for t in tables %}
    {% set fqn = target_db ~ "." ~ target_schema ~ "." ~ t %}
    {% set src_fqn = source_db ~ "." ~ source_schema ~ "." ~ t %}

    {% if method == 'truncate_reload' %}
      {% do log("Truncate + reload " ~ fqn ~ " from " ~ src_fqn ~ ".", info=true) %}
      {% do run_query("truncate table " ~ fqn) %}
      {% do run_query("insert into " ~ fqn ~ " select * from " ~ src_fqn) %}

    {% elif method == 'noop_insert' %}
      {% do log("No-op insert against " ~ fqn ~ " to bump last-modified.", info=true) %}
      {% do run_query("insert into " ~ fqn ~ " select * from " ~ fqn ~ " where 1=0") %}

    {% elif method == 'recreate' %}
      {% do log("Drop + recreate " ~ fqn ~ " from " ~ src_fqn ~ ".", info=true) %}
      {% do run_query("drop table if exists " ~ fqn) %}
      {% do run_query("create table " ~ fqn ~ " as select * from " ~ src_fqn) %}
    {% endif %}
  {% endfor %}

  {% do log("Done. Next: run `dbt source freshness`, then `dbt build --select source_status:fresher+` to see the cascade.", info=true) %}
{% endmacro %}
