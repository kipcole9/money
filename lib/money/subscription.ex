defmodule Money.Subscription do
  @moduledoc """
  Provides functions to upgrade and downgrade subscriptions
  from one plan to another.

  Since moving from one plan to another may require
  prorating the payment stream at the point of transition,
  this module is introduced to provide a single point of
  calculation of the proration in order to give clear focus
  to the issues of calculating the carry-over amount or
  the carry-over period at the point of plan change.

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

  The first strategy simply finishes the current billing period before
  the new plan is introduced and therefore no proration is required.
  This is the default strategy.

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
    can be one of `day`, `week`, `month` or `year`.

  * `interval_count` which defines the number of `interval`s for the
    billing period.  This must be a positive integer.

  * `price` which is a `Money.t` representing the price of the plan
    to be paid each billing period.

  ### Billing in advance

  This module calculates all subscription changes on the basis
  that billing is done in advance.  This primarily affects the
  calculation of plan credit when a plan changes.  The assumption
  is that the period from the start of the plan to the point
  of change has been consumed and therefore the credit is based
  upon that period of the plan that has not yet been consumed.

  If the calculation was based upon "payment in arrears" then
  the credit would actually be a debit since the part of the
  current period consumed has not yet been paid for.

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
    Note that the date applied in the case of `:immediately` is the date returned by
    `Date.utc_today`.

  * `:prorate` which determines how to prorate the current plan into the new plan.  The
    options are `:price` which will reduce the price of the first period of the new plan
    by the credit amount left on the old plan (this is the default). Or `:period` in which
    case the first period of the new plan is extended by the `interval` amount of the new
    plan that the credit on the old plan will fund.

  * `:round` determines whether when prorating the `:period` it is truncated or rounded up
    to the next nearest full `interval_count`. Valid values are `:down`, `:half_up`,
    `:half_even`, `:ceiling`, `:floor`, `:half_down`, `:up`.  The default is `:up`.

  ## Returns

  A `Map.t` with the following elements:

  * `:next_billing_date` which is the next billing date derived from the option
    `:effective` given to `change/4`

  * `:next_billing_amount` is the amount to be billed, net of any credit, at
    the `:next_billing_date`

  * `:following_billing_date` is the the billing date after the `:next_billing_date`
    including any `credit_days_applied`

  * `:credit_amount_applied` is the amount of credit applied to the new plan. If
    the `:prorate` option is `:price` (the default) the next `:next_billing_amount`
    is the plan `:price` reduced by the `:credit_amount_applied`. If the `:prorate`
    option is `:period` then the `:next_billing_amount` is not adjusted.  In this
    case the `:following_billing_date` is extended by the `:credit-days_applied`
    instead.

  * `:credit_days_applied` is the number of days credit applied to the next billing
    by adding days to the `:following_billing_date`.

  * `:credit_period_ends` is the date on which any applied credit is consumed

  * `:carry_forward` is any amount of credit carried forward to a subsequent period.
    This applied when the credit amount for the current plan is greater than the price
    of the new plan.  In this case the `:next_billing_amount` is zero.

  """
  @spec change(current_plan :: Map.t(), new_plan :: Map.t(), options :: Keyword.t()) :: Map.t()
  def change(current_plan, new_plan, last_billing_date, options \\ [])

  def change(
        %{price: %Money{currency: currency}} = current_plan,
        %{price: %Money{currency: currency}} = new_plan,
        last_billing_date,
        options
      ) do
    options = options_from(options, default_options())
    change(current_plan, new_plan, last_billing_date, options[:effective], options)
  end

  # Change the plan at the end of the current billing period.  This requires
  # no proration and is therefore the easiest to caculate.
  defp change(current_plan, new_plan, last_billing_date, :next_period, _options) do
    price = Map.get(new_plan, :price)
    next_billing_date = next_billing_date(current_plan, last_billing_date)
    zero = Money.zero(price.currency)

    %{
      next_billing_amount: price,
      next_billing_date: next_billing_date,
      following_billing_date: next_billing_date(current_plan, next_billing_date),
      credit_amount_applied: zero,
      credit_days_applied: 0,
      credit_period_ends: nil,
      carry_forward: zero
    }
  end

  defp change(current_plan, new_plan, last_billing_date, :immediately, options) do
    change(current_plan, new_plan, last_billing_date, Date.utc_today(), options)
  end

  defp change(current_plan, new_plan, last_billing_date, effective_date, options) do
    credit = plan_credit(current_plan, last_billing_date, effective_date, options)
    prorate(new_plan, credit, last_billing_date, effective_date, options[:prorate], options)
  end

  # Reduce the price of the first period of the new plan by the
  # credit amount on the current plan
  defp prorate(plan, credit_amount, _last_billing_date, effective_date, :price, options) do
    prorate_price =
      Map.get(plan, :price)
      |> Money.sub!(credit_amount)
      |> Money.round(rounding_mode: options[:round])

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
      credit_days_applied: 0,
      credit_period_ends: nil,
      carry_forward: carry_forward
    }
  end

  # Extend the first period of the new plan by the amount of credit
  # on the current plan
  defp prorate(plan, credit_amount, _last_billing_date, effective_date, :period, options) do
    {following_billing_date, days_credit} =
      extend_period(plan, credit_amount, effective_date, options)

    next_billing_amount = Map.get(plan, :price)
    credit_period_ends = add_days(effective_date, days_credit - 1)

    %{
      next_billing_date: effective_date,
      next_billing_amount: next_billing_amount,
      following_billing_date: following_billing_date,
      credit_amount_applied: credit_amount,
      credit_days_applied: days_credit,
      credit_period_ends: credit_period_ends,
      carry_forward: zero(plan)
    }
  end

  defp plan_credit(%{price: price} = plan, last_billing_date, effective_date, options) do
    plan_days = plan_days(plan, effective_date)
    price_per_day = Decimal.div(price.amount, Decimal.new(plan_days))
    days_remaining = days_remaining(plan, last_billing_date, effective_date)

    price_per_day
    |> Decimal.mult(Decimal.new(days_remaining))
    |> Money.new(price.currency)
    |> Money.round(rounding_mode: options[:round])
  end

  # Extend the billing period by the amount that
  # credit will fund on the new plan in days.
  defp extend_period(plan, credit, effective_date, options) do
    price = Map.get(plan, :price)
    plan_days = plan_days(plan, effective_date)
    price_per_day = Decimal.div(price.amount, Decimal.new(plan_days))

    credit_days_applied =
      credit.amount
      |> Decimal.div(price_per_day)
      |> Decimal.round(0, options[:round])
      |> Decimal.to_integer()

    following_billing_date =
      next_billing_date(plan, effective_date)
      |> add_days(credit_days_applied)

    {following_billing_date, credit_days_applied}
  end

  @doc """
  Returns number of days in the plan period

  ## Arguments

  * `plan` is any `Money.Subscription.Plan.t`

  * `last_billing_date` is a `Date.t`

  ## Returns

  The number of days in the billing period

  ## Examples

      iex> plan = Money.Subscription.Plan.new! Money.new!(:USD, 100), :month, 1
      iex> Money.Subscription.plan_days plan, ~D[2018-01-01]
      31
      iex> Money.Subscription.plan_days plan, ~D[2018-02-01]
      28
      iex> Money.Subscription.plan_days plan, ~D[2018-04-01]
      30

  """
  @spec days_remaining(Money.Subscription.Plan.t, Date.t) :: integer
  def plan_days(plan, last_billing_date) do
    plan
    |> next_billing_date(last_billing_date)
    |> days_difference(last_billing_date)
  end

  @doc """
  Returns number of days remaining in the plan period

  ## Arguments

  * `plan` is any `Money.Subscription.Plan.t`

  * `last_billing_date` is a `Date.t`

  * `effective_date` is a `Date.t` after the
    `last_billing_date` and before the end of
    the `plan_days`

  ## Returns

  The number of days remaining in the billing period

  ## Examples

      iex> plan = Money.Subscription.Plan.new! Money.new!(:USD, 100), :month, 1
      iex> Money.Subscription.days_remaining plan, ~D[2018-01-01], ~D[2018-01-02]
      30
      iex> Money.Subscription.days_remaining plan, ~D[2018-02-01], ~D[2018-02-02]
      27

  """
  @spec days_remaining(Money.Subscription.Plan.t, Date.t, Date.t) :: integer
  def days_remaining(plan, last_billing_date, effective_date \\ Date.utc_today()) do
    plan
    |> next_billing_date(last_billing_date)
    |> days_difference(effective_date)
  end

  @doc """
  Returns the next billing date for a plan

  ## Arguments

  * `plan` is a `Money.Subscription.Plan.t`

  * `last_billing_date` is the date of the last bill that
    represents the start of the billing period

  ## Returns

  The next billing date as a `Date.t`.

  ## Example

      iex> plan = Money.Subscription.Plan.new!(Money.new!(:USD, 100), :month)
      iex> Money.Subscription.next_billing_date(plan, ~D[2018-03-01])
      ~D[2018-04-01]

      iex> plan = Money.Subscription.Plan.new!(Money.new!(:USD, 100), :day, 30)
      iex> Money.Subscription.next_billing_date(plan, ~D[2018-02-01])
      ~D[2018-03-03]

  """
  @spec next_billing_date(Money.Subscription.Plan.t, Date.t) :: Date.t
  def next_billing_date(%{interval: :day, interval_count: count}, %{
        year: year,
        month: month,
        day: day,
        calendar: calendar
      }) do
    {year, month, day} =
      (calendar.date_to_iso_days(year, month, day) + count)
      |> calendar.date_from_iso_days

    {:ok, date} = Date.new(year, month, day, calendar)
    date
  end

  def next_billing_date(%{interval: :week, interval_count: count}, last_billing_date) do
    next_billing_date(%{interval: :day, interval_count: count * 7}, last_billing_date)
  end

  def next_billing_date(
        %{interval: :month, interval_count: count} = plan,
        %{year: year, month: month, day: day, calendar: calendar} = last_billing_date
      ) do
    months_in_this_year = months_in_year(last_billing_date)

    {year, month} =
      if count + month <= months_in_this_year do
        {year, month + count}
      else
        months_left_this_year = months_in_this_year - month
        plan = %{plan | interval_count: count - months_left_this_year - 1}
        last_billing_date = %{last_billing_date | year: year + 1, month: 1, day: day}
        date = next_billing_date(plan, last_billing_date)
        {Map.get(date, :year), Map.get(date, :month)}
      end

    {:ok, next_billing_date} = Date.new(year, month, day, calendar)
    next_billing_date
  end

  def next_billing_date(
        %{interval: :year, interval_count: count},
        %{year: year} = last_billing_date
      ) do
    %{last_billing_date | year: year + count}
  end

  @doc """
  Returns the number of days between two dates

  ## Arguments

  * `date_1` is a `Date.t`

  * `date_2` is a `Date.t`

  ## Returns

  * `days`, an integer number of days between two dates

  ## Example

      iex> Money.Subscription.days_difference ~D[2018-02-28], ~D[2018-01-01]
      58

      iex> Money.Subscription.days_difference ~D[2018-02-28], ~D[2018-02-01]
      27

  """
  @spec days_difference(date_1 :: Date.t(), date_2 :: Date.t()) :: days :: integer
  def days_difference(%{year: year1, month: month1, day: day1, calendar: calendar1}, %{
        year: year2,
        month: month2,
        day: day2,
        calendar: calendar2
      }) do
    calendar1.date_to_iso_days(year1, month1, day1) -
      calendar2.date_to_iso_days(year2, month2, day2)
  end

  @doc """
  Adds a number of days to a date

  ## Arguments

  * `date` is a `Date.t`

  * `days` in an integer number of days

  ## Returns

  * `new_date` is a date `days` later than `date`

  ## Examples

      iex> Money.Subscription.add_days ~D[2018-02-01], 27
      ~D[2018-02-28]

      iex> Money.Subscription.add_days ~D[2018-01-01], 30
      ~D[2018-01-31]

  """
  @spec add_days(date :: Date.t(), days :: integer) :: new_date :: Date.t()
  def add_days(%{year: year, month: month, day: day, calendar: calendar}, days) do
    {year, month, day} =
      (calendar.date_to_iso_days(year, month, day) + days)
      |> calendar.date_from_iso_days

    {:ok, date} = Date.new(year, month, day, calendar)
    date
  end

  ## Helpers

  defp months_in_year(%{year: year, calendar: calendar}) do
    if function_exported?(calendar, :months_in_year, 1) do
      calendar.months_in_year(year)
    else
      12
    end
  end

  defp options_from(options, default_options) do
    default_options
    |> Keyword.merge(options)
    |> Enum.into(%{})
  end

  defp default_options do
    [effective: :next_period, prorate: :price, round: :up]
  end

  defp zero(plan) do
    plan
    |> Map.get(:price)
    |> Map.get(:currency)
    |> Money.zero()
  end
end
