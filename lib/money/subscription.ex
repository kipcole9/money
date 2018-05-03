defmodule Money.Subscription do
  @moduledoc """
  Provides functions to create, upgrade and downgrade subscriptions
  from one plan to another.

  Since moving from one plan to another may require
  prorating the payment stream at the point of transition,
  this module is introduced to provide a single point of
  calculation of the proration in order to give clear focus
  to the issues of calculating the carry-over amount or
  the carry-over period at the point of plan change.

  ### Defining a subscription

  A subscription records this current state and history of
  all plans assigned over time to a subscriber.  The definition
  is deliberately minimal to simplify integration into applications
  that have a specific implementation of a subscription.

  A new subscription is created with `Money.Subscription.new/3`
  which has the following attributes:

  * `plan` which defines the initial plan for the subscription.
  This option is required.

  * `effective_date` which determines the effective date of
  the inital plan.  This option is required.

  * `options` which include `:created_at` and `:id` with which
    a subscription may be annotated

  ### Changing a subscription plan

  Changing a subscription plan requires the following
  information be provided:

  * A Subscription or the definition of the current plan

  * The definition of the new plan

  * The strategy for changing the plan which is either:

    * to have the effective date of the new plan be after
      the current interval of the current plan

    * To change the plan immediately in which case there will
      be a credit on the current plan which needs to be applied
      to the new plan.

  See `Money.Subscription.change_plan/3`

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

  * `interval` which defines the time interval for a plan. The value
    can be one of `day`, `week`, `month` or `year`.

  * `interval_count` which defines the number of `interval`s for the
    current plan interval.  This must be a positive integer.

  * `price` which is a `Money.t` representing the price of the plan
    to be paid each interval count.

  ### Billing in advance

  This module calculates all subscription changes on the basis
  that billing is done in advance.  This primarily affects the
  calculation of plan credit when a plan changes.  The assumption
  is that the period from the start of the current interval to
  the point of change has been consumed and therefore the credit
  is based upon that period of the plan that has not yet been
  consumed.

  If the calculation was based upon "payment in arrears" then
  the credit would actually be a debit since the part of the
  current period consumed has not yet been paid.

  """

  alias Money.Subscription.{Change, Plan}

  @typedoc "An id that uniquely identifies a subscription"
  @type id :: term()

  @typedoc "A Money.Subscription type"
  @type t :: %__MODULE__{id: id(), plans: list({Change.t(), Plant.t()}), created_at: DateTime.t()}

  @doc """
  A `struct` defining a subscription

  * `:id` any term that uniquely identifies this subscription

  * `:plans` is a list of `{change, plan}` tuples that record the history
    of plans assigned to this subscription

  * `:created_at` records the `DateTime.t` when the subscription was created

  """
  defstruct id: nil,
            plans: [],
            created_at: nil

  @doc """
  Creates a new subscription.

  ## Arguments

  * `plan` is any `Money.Subscription.Plan.t` the defines the initial plan

  * `effective_date` is a `Date.t` that represents the effective
    date of the initial plan. This defines the start of the first interval

  * `options` is a keyword list of options

  ## Options

  * `:id` is any term that an application can use to uniquely identify
    this subscription.  It is not used in any function in this module.

  * `:created_at` is a `DateTime.t` that records the timestamp when
    the subscription was created.  The default is `DateTime.utc_now/0`

  ## Returns

  * `{:ok, Money.Subscription.t}` or

  * `{:error, {exception, message}}`

  """
  @since "2.3.0"
  @spec new(plan :: Plan.t(), effective_date :: Date.t(), Keyword.t()) :: {:ok, Subscription.t()} | {:error, Exceiption.t(), String.t()}
  def new(plan, effective_date, options \\ [])

  def new(
        %{price: _price, interval: _interval} = plan,
        %{year: _year, month: _month, day: _day, calendar: _calendar} = effective_date,
        options
      ) do
    options =
      default_subscription_options()
      |> Keyword.merge(options)

    next_interval_starts = next_interval_starts(plan, effective_date, options)
    first_billing_amount = plan.price

    changes = %Change{
      first_interval_starts: effective_date,
      next_interval_starts: next_interval_starts,
      first_billing_amount: first_billing_amount,
      credit_amount_applied: Money.zero(first_billing_amount),
      credit_amount: Money.zero(first_billing_amount),
      carry_forward: Money.zero(first_billing_amount)
    }

    subscription =
      struct(__MODULE__, options)
      |> Map.put(:plans, [{changes, plan}])

    {:ok, subscription}
  end

  def new(%{price: _price, interval: _interval}, effective_date, _options) do
    {:error, {Subscription.DateError, "The effective date #{inspect(effective_date)} is invalid."}}
  end

  def new(plan, %{year: _, month: _, day: _, calendar: _}, _options) do
    {:error, {Subscription.PlanError, "The plan #{inspect(plan)} is invalid."}}
  end

  @doc """
  Creates a new subscription or raises an exception.

  ## Arguments

  * `plan` is any `Money.Subscription.Plan.t` the defines the initial plan

  * `effective_date` is a `Date.t` that represents the effective
    date of the initial plan. This defines the start of the first interval

  * `:options` is a keyword list of options

  ## Options

  * `:id` is any term that an application can use to uniquely identify
    this subscription.  It is not used in any function in this module.

  * `:created_at` is a `DateTime.t` that records the timestamp when
    the subscription was created.  The default is `DateTime.utc_now/0`

  ## Returns

  * A `Money.Subscription.t` or

  * raises an exception

  """
  @spec new!(plan :: Plan.t(), effective_date :: Date.t(), Keyword.t()) :: Subscription.t() | no_return()
  def new!(plan, effective_date, options \\ []) do
    case new(plan, effective_date, options) do
      {:ok, subscription} -> subscription
      {:error, {exception, message}} -> raise exception, message
    end
  end

  defp default_subscription_options do
    [
      created_at: DateTime.utc_now()
    ]
  end

  @doc """
  Retrieve the plan that is currently in affect.

  The plan in affect is not necessarily the first
  plan in the list.  We may have upgraded plans to
  be in affect at some later time.

  ## Arguments

  * `subscription` is a `Money.Subscription.t` or any
    map that provides the field `:plans`

  ## Returns

  * The `Money.Subscription.Plan.t` that is the plan currently in affect or
    `nil`

  """
  @since "2.3.0"
  @spec current_plan(Subscription.t() | map, Keyword.t()) :: Plan.t() | nil
  def current_plan(subscription, options \\ [])

  def current_plan(%{plans: []}, _options) do
    nil
  end

  def current_plan(%{plans: [h | t]}, options) do
    if current_plan?(h, options) do
      h
    else
      current_plan(%{plans: t}, options)
    end
  end

  # Because we walk the list from most recent to oldest, the first
  # plan that has a start date less than or equal to the current
  # date is the one we want
  defp current_plan?({%Change{first_interval_starts: start_date}, _}, options) do
    today = options[:today] || Date.utc_today()
    Date.compare(start_date, today) in [:lt, :eq]
  end

  @doc """
  Returns a `boolean` indicating if there is a pending plan.

  A pending plan is one where the subscription has changed
  plans but the plan is not yet in effect.  There can only
  be one pending plan.

  ## Arguments

  * `:subscription` is any `Money.Subscription.t`

  * `:options` is a keyword list of options

  ## Options

  * `:today` is a `Date.t` that represents the effective
    date used to determine is there is a pending plan.
    The default is `Date.utc_today/1`.

  ## Returns

  * Either `true` or `false`

  """

  @since "2.3.0"
  @spec plan_pending?(Subscription.t(), Keyword.t()) :: boolean()
  def plan_pending?(%{plans: [{changes, _plan} | _t]}, options \\ []) do
    today = options[:today] || Date.utc_today()
    Date.compare(changes.first_interval_starts, today) == :gt
  end

  @doc """
  Cancel a subscription's pending plan.

  A pending plan arise when a a `Subscription.change_plan/3` has
  been executed but the effective date is in the future.  Only
  one plan may be pending at any one time so that if
  `Subscription.change_plan/3` is attemtped a second time an
  error tuple will be returned.

  `Subscription.cancel_pending_plan/2`
  can be used to roll back the pending plan change.

  ## Arguments

  * `:subscription` is any `Money.Subscription.t`

  * `:options` is a `Keyword.t`

  ## Options

  * `:today` is a `Date.t` that represents today.
    The default is `Date.utc_today`

  ## Returns

  * An updated `Money.Subscription.t` which may or may not
  have had a pending plan.  If it did have a pending plan
  that plan is deleted.  If there was no pending plan then
  the subscription is returned unchanged.

  """
  @since "2.3.0"
  @spec cancel_pending_plan(Subscription.t(), Keyword.t()) :: Subscription.t()
  def cancel_pending_plan(%{plans: [_plan | other_plans]} = subscription, options \\ []) do
    if plan_pending?(subscription, options) do
      %{subscription | plans: other_plans}
    else
      subscription
    end
  end

  @doc """
  Returns the start date of the current plan.

  ## Arguments

  * `subscription` is a `Money.Subscription.t` or any
    map that provides the field `:plans`

  ## Returns

  * The start `Date.t` of the current plan

  """
  @since "2.3.0"
  @spec current_plan_start_date(Subscription.t()) :: Date.t()
  def current_plan_start_date(%{plans: _plans} = subscription) do
    case current_plan(subscription) do
      {changes, _plan} -> changes.first_interval_starts
      _ -> nil
    end
  end

  @doc """
  Returns the first date of the current interval of a plan.

  ## Arguments

  * `:subscription_or_changeset` is any`Money.Subscription.t` or
    a `{Change.t, Plan.t}` tuple

  * `:options` is a keyword list of options

  ## Options

  * `:today` is a `Date.t` that represents today.
    The default is `Date.utc_today`

  ## Returns

  * The `Date.t` that is the first date of the current interval

  """
  @since "2.3.0"
  @spec current_interval_start_date(Subscription.t() | {Change.t(), Plan.t()} | map(), Keyword.t()) ::
          Date.t()
  def current_interval_start_date(subscription_or_changeset, options \\ [])

  def current_interval_start_date(%{plans: _plans} = subscription, options) do
    case current_plan(subscription, options) do
      {changes, plan} ->
        current_interval_start_date({changes, plan}, options)

      _ ->
        {:error,
         {Money.Subscription.NoCurrentPlan, "There is no current plan for the subscription"}}
    end
  end

  def current_interval_start_date({%Change{first_interval_starts: start_date}, plan}, options) do
    next_interval_starts = next_interval_starts(plan, start_date)
    options = Keyword.put_new(options, :today, Date.utc_today())

    case compare_range(options[:today], start_date, next_interval_starts) do
      :between ->
        start_date

      :less ->
        current_interval_start_date(
          {%Change{first_interval_starts: next_interval_starts}, plan},
          options
        )

      :greater ->
        {:error,
         {Money.Subscription.NoCurrentPlan, "The plan is not current for #{inspect(start_date)}"}}
    end
  end

  defp compare_range(date, current, next) do
    cond do
      Date.compare(date, current) in [:gt, :eq] and Date.compare(date, next) == :lt ->
        :between

      Date.compare(current, date) == :lt ->
        :less

      Date.compare(next, date) == :gt ->
        :greater
    end
  end

  @doc """
  Returns the latest plan for a subscription.

  The latest plan may not be in affect since
  its start date may be in the future.

  ## Arguments

  * `subscription` is a `Money.Subscription.t` or any
    map that provides the field `:plans`

  ## Returns

  * The `Money.Subscription.Plan.t` that is the most recent
    plan - whether or not it is the currently active plan.

  """
  @since "2.3.0"
  @spec latest_plan(Subscription.t() | map()) :: {Change.t(), Plan.t()}
  def latest_plan(%{plans: [h | _t]}) do
    h
  end

  @doc """
  Change plan from the current plan to a new plan.

  ## Arguments

  * `subscription_or_plan` is either a `Money.Subscription.t` or `Money.Subscription.Plan.t`
    or a map with the same fields

  * `new_plan` is a `Money.Subscription.Plan.t` or a map with at least the fields
    `interval`, `interval_count` and `price`

  * `current_interval_started` is a `Date.t` or other map with the fields `year`, `month`,
    `day` and `calendar`

  * `options` is a keyword list of options the define how the change is to be made

  ## Options

  * `:effective` defines when the new plan comes into effect.  The values are `:immediately`,
    a `Date.t` or `:next_period`.  The default is `:next_period`.  Note that the date
    applied in the case of `:immediately` is the date returned by `Date.utc_today`.

  * `:prorate` which determines how to prorate the current plan into the new plan.  The
    options are `:price` which will reduce the price of the first period of the new plan
    by the credit amount left on the old plan (this is the default). Or `:period` in which
    case the first period of the new plan is extended by the `interval` amount of the new
    plan that the credit on the old plan will fund.

  * `:round` determines whether when prorating the `:period` it is truncated or rounded up
    to the next nearest full `interval_count`. Valid values are `:down`, `:half_up`,
    `:half_even`, `:ceiling`, `:floor`, `:half_down`, `:up`.  The default is `:up`.

  * `:first_interval_started` determines the anchor day for monthly billing.  For
    example if a monthly plan starts on January 31st then the next period will start
    on February 28th (or 29th).  The period following that should, however, be March 31st.
    If `subscription_or_plan` is a `Money.Subscription.t` then the `:first_interval_started`
    is automatically populated from the subscription. If `:first_interval_started` is
    `nil` then the date defined by `:effective` is used.

  ## Returns

  A `Money.Subscription.Change.t` with the following elements:

  * `:first_interval_starts` which is the start date of the first interval for the new
    plan

  * `:first_billing_amount` is the amount to be billed, net of any credit, at
    the `:first_interval_starts`

  * `:next_interval_starts` is the start date of the next interval after the `
    first interval `including any `credit_days_applied`

  * `:credit_amount` is the amount of unconsumed credit of the current plan

  * `:credit_amount_applied` is the amount of credit applied to the new plan. If
    the `:prorate` option is `:price` (the default) then `:first_billing_amount`
    is the plan `:price` reduced by the `:credit_amount_applied`. If the `:prorate`
    option is `:period` then the `:first_billing_amount` is the plan `price` and
    the `:next_interval_date` is extended by the `:credit_days_applied`
    instead.

  * `:credit_days_applied` is the number of days credit applied to the first
    interval by adding days to the `:first_interval_starts` date.

  * `:credit_period_ends` is the date on which any applied credit is consumed or `nil`

  * `:carry_forward` is any amount of credit carried forward to a subsequent period.
    If non-zero, this amount is a negative `Money.t`. It is non-zero when the credit
    amount for the current plan is greater than the `:price` of the new plan.  In
    this case the `:first_billing_amount` is zero.

  ## Returns

  * `{:ok, updated_subscription}` or

  * `{:error, {exception, message}}`

  ## Examples

      # Change at end of the current period so no proration
      iex> current = Money.Subscription.Plan.new!(Money.new(:USD, 10), :month, 1)
      iex> new = Money.Subscription.Plan.new!(Money.new(:USD, 10), :month, 3)
      iex> Money.Subscription.change_plan current, new, current_interval_started: ~D[2018-01-01]
      {:ok, %Money.Subscription.Change{
        carry_forward: Money.zero(:USD),
        credit_amount: Money.zero(:USD),
        credit_amount_applied: Money.zero(:USD),
        credit_days_applied: 0,
        credit_period_ends: nil,
        next_interval_starts: ~D[2018-05-01],
        first_billing_amount: Money.new(:USD, 10),
        first_interval_starts: ~D[2018-02-01]
      }}

      # Change during the current plan generates a credit amount
      iex> current = Money.Subscription.Plan.new!(Money.new(:USD, 10), :month, 1)
      iex> new = Money.Subscription.Plan.new!(Money.new(:USD, 10), :month, 3)
      iex> Money.Subscription.change_plan current, new, current_interval_started: ~D[2018-01-01], effective: ~D[2018-01-15]
      {:ok, %Money.Subscription.Change{
        carry_forward: Money.zero(:USD),
        credit_amount: Money.new(:USD, "5.49"),
        credit_amount_applied: Money.new(:USD, "5.49"),
        credit_days_applied: 0,
        credit_period_ends: nil,
        next_interval_starts: ~D[2018-04-15],
        first_billing_amount: Money.new(:USD, "4.51"),
        first_interval_starts: ~D[2018-01-15]
      }}

      # Change during the current plan generates a credit period
      iex> current = Money.Subscription.Plan.new!(Money.new(:USD, 10), :month, 1)
      iex> new = Money.Subscription.Plan.new!(Money.new(:USD, 10), :month, 3)
      iex> Money.Subscription.change_plan current, new, current_interval_started: ~D[2018-01-01], effective: ~D[2018-01-15], prorate: :period
      {:ok, %Money.Subscription.Change{
        carry_forward: Money.zero(:USD),
        credit_amount: Money.new(:USD, "5.49"),
        credit_amount_applied: Money.zero(:USD),
        credit_days_applied: 50,
        credit_period_ends: ~D[2018-03-05],
        next_interval_starts: ~D[2018-06-04],
        first_billing_amount: Money.new(:USD, 10),
        first_interval_starts: ~D[2018-01-15]
      }}

  """
  @since "2.3.0"
  @spec change_plan(
          subscription_or_plan :: __MODULE__.t() | Plan.t(),
          new_plan :: Plan.t(),
          options :: Keyword.t()
        ) :: {:ok, Change.t() | Subscription.t()} | {:error, {Exception.t(), String.t()}}

  def change_plan(subscription_or_plan, new_plan, options \\ [])

  def change_plan(
        %{plans: [{changes, %{price: %Money{currency: currency}} = current_plan} | _] = plans} =
          subscription,
        %{price: %Money{currency: currency}} = new_plan,
        options
      ) do
    options =
      options
      |> Keyword.put(:first_interval_started, changes.first_interval_starts)
      |> Keyword.put(:current_interval_started, current_interval_start_date(subscription, options))
      |> change_plan_options_from(default_options())
      |> Enum.into(Keyword.new())

    if plan_pending?(subscription, options) do
      {:error,
       {Money.Subscription.PlanPending, "Can't change plan when a new plan is already pending"}}
    else
      {:ok, changes} = change_plan(current_plan, new_plan, options)
      updated_subscription = %__MODULE__{subscription | plans: [{changes, new_plan} | plans]}
      {:ok, updated_subscription}
    end
  end

  def change_plan(
        %{price: %Money{currency: currency}} = current_plan,
        %{price: %Money{currency: currency}} = new_plan,
        options
      ) do
    options = change_plan_options_from(options, default_options())
    change_plan(current_plan, new_plan, options[:effective], options)
  end

  @doc """
  Change plan from the current plan to a new plan.

  Retuns the plan or raises an exception on error.

  See `Money.Subscription.change_plan/3` for the description
  of arguments, options and return.

  """
  @since "2.3.0"
  @spec change_plan!(
          subscription_or_plan :: __MODULE__.t() | Plan.t(),
          new_plan :: Plan.t(),
          options :: Keyword.t()
        ) :: Change.t() | no_return()

  def change_plan!(subscription_or_plan, new_plan, options \\ []) do
    case change_plan(subscription_or_plan, new_plan, options) do
      {:ok, changeset} -> changeset
      {:error, {exception, message}} -> raise exception, message
    end
  end

  # Change the plan at the end of the current plan interval.  This requires
  # no proration and is therefore the easiest to calculate.
  defp change_plan(current_plan, new_plan, :next_period, options) do
    price = Map.get(new_plan, :price)

    first_interval_starts =
      next_interval_starts(current_plan, options[:current_interval_started], options)

    zero = Money.zero(price.currency)

    {:ok,
     %Change{
       first_billing_amount: price,
       first_interval_starts: first_interval_starts,
       next_interval_starts: next_interval_starts(new_plan, first_interval_starts, options),
       credit_amount_applied: zero,
       credit_amount: zero,
       credit_days_applied: 0,
       credit_period_ends: nil,
       carry_forward: zero
     }}
  end

  defp change_plan(current_plan, new_plan, :immediately, options) do
    change_plan(current_plan, new_plan, options[:today], options)
  end

  defp change_plan(current_plan, new_plan, effective_date, options) do
    credit = plan_credit(current_plan, effective_date, options)
    {:ok, prorate(new_plan, credit, effective_date, options[:prorate], options)}
  end

  # Reduce the price of the first interval of the new plan by the
  # credit amount on the current plan
  defp prorate(plan, credit_amount, effective_date, :price, options) do
    prorate_price =
      Map.get(plan, :price)
      |> Money.sub!(credit_amount)
      |> Money.round(rounding_mode: options[:round])

    zero = zero(plan)

    {first_billing_amount, carry_forward} =
      if Money.cmp(prorate_price, zero) == :lt do
        {zero, prorate_price}
      else
        {prorate_price, zero}
      end

    %Change{
      first_interval_starts: effective_date,
      first_billing_amount: first_billing_amount,
      next_interval_starts: next_interval_starts(plan, effective_date, options),
      credit_amount: credit_amount,
      credit_amount_applied: Money.add!(credit_amount, carry_forward),
      credit_days_applied: 0,
      credit_period_ends: nil,
      carry_forward: carry_forward
    }
  end

  # Extend the first interval of the new plan by the amount of credit
  # on the current plan
  defp prorate(plan, credit_amount, effective_date, :period, options) do
    {next_interval_starts, days_credit} =
      extend_period(plan, credit_amount, effective_date, options)

    first_billing_amount = Map.get(plan, :price)
    credit_period_ends = Date.add(effective_date, days_credit - 1)

    %Change{
      first_interval_starts: effective_date,
      first_billing_amount: first_billing_amount,
      next_interval_starts: next_interval_starts,
      credit_amount: credit_amount,
      credit_amount_applied: zero(plan),
      credit_days_applied: days_credit,
      credit_period_ends: credit_period_ends,
      carry_forward: zero(plan)
    }
  end

  defp plan_credit(%{price: price} = plan, effective_date, options) do
    plan_days = plan_days(plan, effective_date, options)
    price_per_day = Decimal.div(price.amount, Decimal.new(plan_days))

    days_remaining =
      days_remaining(plan, options[:current_interval_started], effective_date, options)

    price_per_day
    |> Decimal.mult(Decimal.new(days_remaining))
    |> Money.new(price.currency)
    |> Money.round(rounding_mode: options[:round])
  end

  # Extend the interval by the amount that
  # credit will fund on the new plan in days.
  defp extend_period(plan, credit, effective_date, options) do
    price = Map.get(plan, :price)
    plan_days = plan_days(plan, effective_date, options)
    price_per_day = Decimal.div(price.amount, Decimal.new(plan_days))

    credit_days_applied =
      credit.amount
      |> Decimal.div(price_per_day)
      |> Decimal.round(0, options[:round])
      |> Decimal.to_integer()

    next_interval_starts =
      next_interval_starts(plan, effective_date, options)
      |> Date.add(credit_days_applied)

    {next_interval_starts, credit_days_applied}
  end

  @doc """
  Returns number of days in a plan interval.

  ## Arguments

  * `plan` is any `Money.Subscription.Plan.t`

  * `current_interval_started` is any `Date.t`

  ## Returns

  The number of days in a plan interval.

  ## Examples

      iex> plan = Money.Subscription.Plan.new! Money.new!(:USD, 100), :month, 1
      iex> Money.Subscription.plan_days plan, ~D[2018-01-01]
      31
      iex> Money.Subscription.plan_days plan, ~D[2018-02-01]
      28
      iex> Money.Subscription.plan_days plan, ~D[2018-04-01]
      30

  """
  @since "2.3.0"
  @spec plan_days(Plan.t(), Date.t(), Keyword.t()) :: integer()
  def plan_days(plan, current_interval_started, options \\ []) do
    plan
    |> next_interval_starts(current_interval_started, options)
    |> Date.diff(current_interval_started)
  end

  @doc """
  Returns number of days remaining in a plan interval.

  ## Arguments

  * `plan` is any `Money.Subscription.Plan.t`

  * `current_interval_started` is a `Date.t`

  * `effective_date` is a `Date.t` after the
    `current_interval_started` and before the end of
    the `plan_days`

  ## Returns

  The number of days remaining in a plan interval

  ## Examples

      iex> plan = Money.Subscription.Plan.new! Money.new!(:USD, 100), :month, 1
      iex> Money.Subscription.days_remaining plan, ~D[2018-01-01], ~D[2018-01-02]
      30
      iex> Money.Subscription.days_remaining plan, ~D[2018-02-01], ~D[2018-02-02]
      27

  """
  @since "2.3.0"
  @spec days_remaining(Plan.t(), Date.t(), Date.t(), Keyword.t()) :: integer
  def days_remaining(plan, current_interval_started, effective_date, options \\ []) do
    plan
    |> next_interval_starts(current_interval_started, options)
    |> Date.diff(effective_date)
  end

  @doc """
  Returns the next interval start date for a plan.

  ## Arguments

  * `plan` is any `Money.Subscription.Plan.t`

  * `:current_interval_started` is the `Date.t` that
    represents the start of the current interval

  ## Returns

  The next interval start date as a `Date.t`.

  ## Example

      iex> plan = Money.Subscription.Plan.new!(Money.new!(:USD, 100), :month)
      iex> Money.Subscription.next_interval_starts(plan, ~D[2018-03-01])
      ~D[2018-04-01]

      iex> plan = Money.Subscription.Plan.new!(Money.new!(:USD, 100), :day, 30)
      iex> Money.Subscription.next_interval_starts(plan, ~D[2018-02-01])
      ~D[2018-03-03]

  """
  @since "2.3.0"
  @spec next_interval_starts(Plan.t(), Date.t(), Keyword.t() | Map.t()) :: Date.t()
  def next_interval_starts(plan, current_interval_started, options \\ [])

  def next_interval_starts(
        %{interval: :day, interval_count: count},
        %{
          year: _year,
          month: _month,
          day: _day,
          calendar: _calendar
        } = current_interval_started,
        _options
      ) do
    Date.add(current_interval_started, count)
  end

  def next_interval_starts(
        %{interval: :week, interval_count: count},
        current_interval_started,
        options
      ) do
    next_interval_starts(
      %{interval: :day, interval_count: count * 7},
      current_interval_started,
      options
    )
  end

  def next_interval_starts(
        %{interval: :month, interval_count: count} = plan,
        %{year: year, month: month, day: day, calendar: calendar} = current_interval_started,
        options
      ) do
    options = if is_list(options), do: options, else: Enum.into(options, %{})
    months_in_this_year = months_in_year(current_interval_started)

    {year, month} =
      if count + month <= months_in_this_year do
        {year, month + count}
      else
        months_left_this_year = months_in_this_year - month
        plan = %{plan | interval_count: count - months_left_this_year - 1}
        current_interval_started = %{current_interval_started | year: year + 1, month: 1, day: day}
        date = next_interval_starts(plan, current_interval_started, options)
        {Map.get(date, :year), Map.get(date, :month)}
      end

    day =
      year
      |> calendar.days_in_month(month)
      |> min(max(day, preferred_day(options)))

    {:ok, next_interval_starts} = Date.new(year, month, day, calendar)
    next_interval_starts
  end

  def next_interval_starts(
        %{interval: :year, interval_count: count},
        %{year: year} = current_interval_started,
        _options
      ) do
    %{current_interval_started | year: year + count}
  end

  ## Helpers

  @default_months_in_year 12
  defp months_in_year(%{year: year, calendar: calendar}) do
    if function_exported?(calendar, :months_in_year, 1) do
      calendar.months_in_year(year)
    else
      @default_months_in_year
    end
  end

  defp change_plan_options_from(options, default_options) do
    options =
      default_options
      |> Keyword.merge(options)
      |> Enum.into(%{})

    require_options!(options, [:effective, :current_interval_started])
    Map.put_new(options, :first_interval_started, options[:current_interval_started])
  end

  defp default_options do
    [effective: :next_period, prorate: :price, round: :up, today: Date.utc_today()]
  end

  defp zero(plan) do
    plan
    |> Map.get(:price)
    |> Map.get(:currency)
    |> Money.zero()
  end

  defp require_options!(options, [h | []]) do
    unless options[h] do
      raise_change_plan_options_error(h)
    end
  end

  defp require_options!(options, [h | t]) do
    if options[h] do
      require_options!(options, t)
    else
      raise_change_plan_options_error(h)
    end
  end

  defp raise_change_plan_options_error(opt) do
    raise ArgumentError, "change_plan requires the the option #{inspect(opt)}"
  end

  defp preferred_day(%{first_interval_started: %{day: day}}) do
    day
  end

  defp preferred_day(_options) do
    -1
  end
end
