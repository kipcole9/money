defmodule Money.Subscription do
  @moduledoc """
  Provides functions to upgrade and downgrade subscriptions
  from one plan to another.

  Since moving from one plan to another may requiring
  prorating the payment stream at the point of transition,
  this module is introduced to provide a single point of
  calculation of the proration in order to give clear focus
  to the issues of calculating the carry over amount or
  the carryover period at the point of plan change.

  ### Changing a subscription plan

  Changing a subscription plan requires the following
  information be provided:

  * The definition of the current plan
  * The definition of the new plan
  * The last billing date
  * The strategy for changing the plan which is either:
    * to have the effective date of the new plan be after
      the current billing period of the current plan
    * To change the plan immediately in which case there will
      be a credit on the current plan which needs to be applied
      to the new plan.

  See `Money.Subscription.change/4`

  ### When the new plan is effective at the end of the current billing period

  The first strategy simply finishes the current billing cycle before
  the new plan is introduced and therefore no proration is required.
  This is the default strategy when the current plan and the new plan
  have the same interval (`day`, `week, ...) and interval multiple
  (an integer nmber of intervals).

  ### When the new plan is effective immediately

  If the new plan is to be effective immediately then any credit
  balance remaining on the old plan needs to be applied to the
  new plan.  There are two options of applying the credit:

  1. Reduce the billing amount of the first period of the new plan
     be the amount of the credit left on the old plan. This means
     that the billing amount for the first period of the new plan
     will be different (less) than the billing amount for subsequent
     periods on the new plan.

  2. Extend the first period of the new plan by the interval amount
     that can be funded by the credit amount left on the old plan. In
     the situation where the credit amount does not fully fund an integral
     interval the additional interval can be truncated or rounded up to the next
     integral period.

  ### Plan definition

  This module, and `Money` in general, does not provide a full
  billing or subscription solution - its focus is to support a reliable
  means of calcuating the accounting outcome of a plan change only.
  Therefore the plan definition required by `Money.Subscription` can be
  any `Map.t` that includes the following fields:

  * `interval` which defines the billing interval for a plan. The value
    can be one of `day`, `week`, `month`, `year`.

  * `interval_count` which defines the number of `interval`s for the
    billing period.  This must be a positive integer.

  * `price` which is a `Money.t` representing the price of the plan
    to be paid each billing period.

  ### Billing in advance

  This module calculates all subscription changes on the basis
  that billing is done in advance.

  """

  @doc """
  Change plan from the current plan to a new plan.

  ## Arguments

  * `current_plan` is a map with at least the fields `interval`, `interval_count` and `price`
  * `new_plan` is a map with at least the fields `interval`, `interval_count` and `price`
  * `last_billing_date` is a `Date.t` or other map with the fields `year`, `month`,
    `day` and `calendar`
  * `options` is a keyword map of options the define how the change is to be made

  ## Options

  * `:effective` defines when the new plan comes into effect.  The values are `:immediately`,
    a `Date.t` or `:next_period`.  The default is `:next_period` if the current and new plans
    have the same `interval` and `interval_count`.  Otherwise the default is `:immediately`.

  * `:prorate` which determines how to prorate the current plan into the new plan.  The
    options are `:price` which will reduce the price of the first period of the new plan
    by the credit amount left on the old plan (this is the default). Or `:period` in which
    case the first period of the new plan is extended by the `interval` amount of the new
    plan that the credit on the old plan will fund.

  * `:round` determines whether when prorating the `:period` it is truncated or rounded up
    to the next nearest full `interval_count`. Valid values are `:down`, `:half_up`,
    `:half_even`, `:ceiling`, `:floor`, `:half_down`, `:up`.  The default is `:half_up`.

  ## Returns

  A `Map.t` with the following elements:

  * `:next_billing_date`
  * `:next_billing_amount`
  * `:following_billing_date`
  * `:credit_applied`
  * `:carry_forward`

  """
  @spec change(current_plan :: Map.t, new_plan :: Map.t, options :: Keyword.t) :: Map.t
  def change(current_plan, new_plan, last_billing_date, options \\ [])

  def change(current_plan, new_plan, last_billing_date, options) do
    options = options_from(options, default_options())
    change(current_plan, new_plan, last_billing_date, options[:effective], options)
  end

  def change(current_plan, new_plan, last_billing_date, :next_period, _options) do
    price = Map.get(new_plan, :price)
    next_billing_date = next_billing_date(current_plan, last_billing_date)
    zero = Money.zero(price.currency)

    %{
      next_billing_amount: price,
      next_billing_date: next_billing_date,
      following_billing_date: next_billing_date(current_plan, next_billing_date),
      credit_amount_applied: zero,
      credit_period_applied: 0,
      carry_forward: zero
    }
  end

  def change(current_plan, new_plan, last_billing_date, :immediately, options) do
    change(current_plan, new_plan, last_billing_date, Date.utc_today(), options)
  end

  def change(current_plan, new_plan, last_billing_date, effective_date, options) do
    credit = plan_credit(current_plan, last_billing_date, effective_date)
    prorate(new_plan, credit, last_billing_date, effective_date, options[:prorate], options)
  end

  # Reduce the price of the first period of the new plan by the
  # credit amount on the current plan
  def prorate(plan, credit_amount, _last_billing_date, effective_date, :price, _options) do
    prorate_price =
      Map.get(plan, :price)
      |> Money.sub!(credit_amount)
      |> Money.round

    zero = zero(plan)

    {next_billing_amount, carry_forward} =
      if Money.cmp(prorate_price, zero) == :lt do
        {zero, prorate_price}
      else
        {prorate_price, zero}
      end

    %{
      next_billing_date: effective_date,
      next_billing_amount: next_billing_amount,
      following_billing_date: next_billing_date(plan, effective_date),
      credit_amount_applied: credit_amount,
      credit_period_applied: 0,
      carry_forward: carry_forward
    }
  end

  # Extend the first period of the new plan by the amount of credit
  # on the current plan
  def prorate(plan, credit_amount, _last_billing_date, effective_date, :period, options) do
    {following_billing_date, credit_period} = extend_period(plan, credit_amount, effective_date, options)
    next_billing_amount = Map.get(plan, :price)

    %{
      next_billing_date: effective_date,
      next_billing_amount: next_billing_amount,
      following_billing_date: following_billing_date,
      credit_amount_applied: credit_amount,
      credit_period_applied: credit_period,
      carry_forward: zero(plan)
    }
  end

  def plan_credit(%{price: price} = plan, last_billing_date, effective_date \\ Date.utc_today) do
    last_billing_date
    |> fraction_period_remaining(plan, effective_date)
    |> multiply(price)
    |> Money.round
  end

  # Extend the billing period by the amount that
  # credit will fund on the plan.  The extension
  # needs to be expressed in whole plan 'interval'
  # units (day, week, month, year)
  def extend_period(plan, credit, effective_date, options) do
    price = Map.get(plan, :price)
    fraction_to_extend = Decimal.div(credit.amount, price.amount)
    decimal_interval = Decimal.new(plan[:interval_count])
    extended_interval_count =
      fraction_to_extend
      |> Decimal.mult(decimal_interval)
      |> Decimal.round(0, options[:round])
      |> Decimal.add(decimal_interval)
      |> Decimal.to_integer

    credit_period_applied = extended_interval_count - plan[:interval_count]
    first_period_plan = %{plan | interval_count: extended_interval_count}

    {next_billing_date(first_period_plan, effective_date), credit_period_applied}
  end

  def fraction_period_remaining(last_billing_date, plan, effective_date \\ Date.utc_today) do
    days_remaining(plan, last_billing_date, effective_date) / plan_days(last_billing_date, plan)
  end

  def plan_days(last_billing_date, plan) do
    plan
    |> next_billing_date(last_billing_date)
    |> days_difference(last_billing_date)
  end

  def days_remaining(plan, last_billing_date, effective_date \\ Date.utc_today) do
    plan
    |> next_billing_date(last_billing_date)
    |> days_difference(effective_date)
  end

  def next_billing_date(%{interval: :day, interval_count: count},
      %{year: year, month: month, day: day, calendar: calendar}) do

    {year, month, day} =
      (calendar.date_to_iso_days(year, month, day) + count)
      |> calendar.date_from_iso_days

    {:ok, date} = Date.new(year, month, day, calendar)
    date
  end

  def next_billing_date(%{interval: :week, interval_count: count}, last_billing_date) do
    next_billing_date(%{interval: :day, interval_count: count * 7}, last_billing_date)
  end

  def next_billing_date(%{interval: :month, interval_count: count},
      %{year: year, month: month, day: day, calendar: calendar} = last_billing_date) do
    months_in_year = months_in_year(last_billing_date)

    year = year + div(month + count, months_in_year)
    month = amod((month + count), months_in_year)
    day = min(day, calendar.days_in_month(year, month))

    {:ok, next_billing_date} = Date.new(year, month, day)
    next_billing_date
  end

  def next_billing_date(%{interval: :year, interval_count: count}, %{year: year} = last_billing_date) do
    %{last_billing_date | year: year + count}
  end

  def days_difference(
      %{year: year1, month: month1, day: day1, calendar: calendar1},
      %{year: year2, month: month2, day: day2, calendar: calendar2}) do
    calendar1.date_to_iso_days(year1, month1, day1) -
    calendar2.date_to_iso_days(year2, month2, day2)
  end

  ## Helpers

  defp multiply(fraction, price) do
    Money.mult!(price, fraction)
  end

  defp months_in_year(%{year: year, calendar: calendar}) do
    if function_exported?(calendar, :months_in_year, 1) do
      calendar.months_in_year(year)
    else
      12
    end
  end

  defp amod(x, y) do
    if (mod = rem(x, y)) == 0 do
      y
    else
      mod
    end
  end

  defp options_from(options, default_options) do
    default_options
    |> Keyword.merge(options)
    |> Enum.into(%{})
  end

  defp default_options do
    [effective: :next_period, prorate: :price, round: :half_even]
  end

  defp zero(plan) do
    plan
    |> Map.get(:price)
    |> Map.get(:currency)
    |> Money.zero
  end
end