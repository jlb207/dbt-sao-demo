{#
    Emit a single log line at the end of every run with target + invocation info.
    Wired up via the on-run-end hook in dbt_project.yml.
#}
{% macro log_run_metadata() %}
    {% if execute %}
        {% do log(
            "[tpch_state_demo] target=" ~ target.name
            ~ " schema=" ~ target.schema
            ~ " invocation_id=" ~ invocation_id
            ~ " models_run=" ~ (results | length),
            info=true
        ) %}
    {% endif %}
{% endmacro %}
