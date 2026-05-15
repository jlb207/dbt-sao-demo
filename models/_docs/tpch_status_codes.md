{% docs return_flag %}

Line item return status:

- `R` — Returned by the customer
- `A` — Accepted (delivered, no return)
- `N` — Not yet shipped / status unknown

`fct_returns` filters on `return_flag = 'R'`.

{% enddocs %}

{% docs market_segment %}

TPC-H market segment for a customer. One of:

- `AUTOMOBILE`
- `BUILDING`
- `FURNITURE`
- `HOUSEHOLD`
- `MACHINERY`

`dim_customers` resolves these to friendly labels via the `market_segment_labels` seed.

{% enddocs %}
