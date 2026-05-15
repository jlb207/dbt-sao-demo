{#
    Convert a column expressed in cents to dollars, rounded to the given precision.
    Usage:
        {{ cents_to_dollars('extended_price', 2) }} as extended_price_usd
#}
{% macro cents_to_dollars(column_name, decimal_places=2) -%}
    round( ({{ column_name }})::numeric / 100, {{ decimal_places }} )
{%- endmacro %}
