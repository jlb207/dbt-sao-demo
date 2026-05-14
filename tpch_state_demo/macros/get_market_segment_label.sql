{#
    Resolve a raw market_segment code to its display label using the
    market_segment_labels seed. Wraps a coalesce so unknown codes fall through
    to the raw value.
#}
{% macro get_market_segment_label(market_segment_column) -%}
    coalesce(
        (
            select msl.display_label
            from {{ ref('market_segment_labels') }} msl
            where msl.market_segment = {{ market_segment_column }}
        ),
        {{ market_segment_column }}
    )
{%- endmacro %}
