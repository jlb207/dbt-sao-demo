{% snapshot snp_tpch__customers %}

    {{
        config(
            target_schema = 'snapshots',
            unique_key    = 'customer_key',
            strategy      = 'check',
            check_cols    = ['account_balance', 'market_segment', 'customer_address']
        )
    }}

    select
        customer_key,
        customer_name,
        customer_address,
        nation_key,
        phone_number,
        account_balance,
        market_segment
    from {{ ref('stg_tpch__customers') }}

{% endsnapshot %}
