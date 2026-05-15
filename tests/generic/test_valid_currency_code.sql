{#
    Custom generic test: column values must exist in the fx_rates seed.
#}
{% test valid_currency_code(model, column_name) %}

    select {{ column_name }}
    from {{ model }}
    where {{ column_name }} is not null
      and {{ column_name }} not in (
          select currency_code from {{ ref('fx_rates') }}
      )

{% endtest %}
