{% snapshot snp_tpch__suppliers %}

    {{
        config(
            target_schema = 'snapshots',
            unique_key    = 'supplier_key',
            strategy      = 'check',
            check_cols    = ['account_balance', 'supplier_address']
        )
    }}

    select
        supplier_key,
        supplier_name,
        supplier_address,
        nation_key,
        phone_number,
        account_balance
    from {{ ref('stg_tpch__suppliers') }}

{% endsnapshot %}
