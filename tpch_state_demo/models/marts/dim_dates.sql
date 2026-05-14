{{
    config(
        materialized = 'table',
        tags         = ['dimensions']
    )
}}

-- Date dimension covering the full TPC-H order date range (1992-01-01 onward),
-- plus a configurable forward buffer. Built from a generated date spine so
-- it has no upstream dependencies on the fact tables.

with date_spine as (

    {{ dbt_utils.date_spine(
        datepart = "day",
        start_date = "cast('" ~ var('date_spine_start') ~ "' as date)",
        end_date   = "cast('" ~ var('date_spine_end')   ~ "' as date)"
    ) }}

),

final as (

    select
        date_day                                                   as date_key,
        date_day                                                   as full_date,
        date_part('year',  date_day)::int                          as year_number,
        date_part('quarter', date_day)::int                        as quarter_number,
        date_part('month', date_day)::int                          as month_number,
        to_char(date_day, 'YYYY-MM')                               as year_month,
        date_part('day',   date_day)::int                          as day_of_month,
        date_part('dow',   date_day)::int                          as day_of_week,
        case
            when date_part('dow', date_day) in (0, 6) then false
            else true
        end                                                        as is_business_day,
        {{ order_date_truncated('date_day') }}                     as month_start

    from date_spine

)

select * from final
