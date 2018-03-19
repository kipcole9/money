defmodule Money.Subscription.Change do
  @moduledoc """
  Defines the structure of a plan changeset.

  * `:next_billing_date` which is the next billing date for the new
    plan

  * `:next_billing_amount` is the amount to be billed, net of any credit, at
    the `:next_billing_date`

  * `:following_billing_date` is the the billing date after the `:next_billing_date`
    including any `credit_days_applied`

  * `:credit_amount` is the amount of unconsumed credit of the current plan

  * `:credit_amount_applied` is the amount of credit applied to the new plan. If
    the `:prorate` option is `:price` (the default) the next `:next_billing_amount`
    is the plan `:price` reduced by the `:credit_amount_applied`. If the `:prorate`
    option is `:period` then the `:next_billing_amount` is not adjusted.  In this
    case the `:following_billing_date` is extended by the `:credit-days_applied`
    instead.

  * `:credit_days_applied` is the number of days credit applied to the next billing
    by adding days to the `:following_billing_date`.

  * `:credit_period_ends` is the date on which any applied credit is consumed or `nil`

  * `:carry_forward` is any amount of credit carried forward to a subsequent period.
    If non-zero this amount is a negative `Money.t`. It is non-zero when the credit
    amount for the current plan is greater than the price of the new plan.  In
    this case the `:next_billing_amount` is zero.

  """

  defstruct [
    next_billing_amount: Decimal.new(0),
    first_interval_starts: nil,
    following_interval_starts: nil,
    credit_amount_applied: Decimal.new(0),
    credit_amount: Decimal.new(0),
    credit_days_applied: 0,
    credit_period_ends: nil,
    carry_forward: Decimal.new(0)
  ]
end
