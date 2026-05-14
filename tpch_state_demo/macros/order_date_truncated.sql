{#
    Return year-month bucket for an order_date column. Centralizes the bucketing
    logic so revenue aggregations across the project stay consistent.
#}
{% macro order_date_truncated(order_date_column) -%}
    date_trunc('month', {{ order_date_column }})::date
{%- endmacro %}
