{#
    Custom generic test: fail when a numeric column has any value < 0.
    Usage:
        columns:
          - name: gross_revenue
            tests:
              - not_negative
#}
{% test not_negative(model, column_name) %}

    select {{ column_name }}
    from {{ model }}
    where {{ column_name }} < 0

{% endtest %}
