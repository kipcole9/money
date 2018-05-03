defmodule Money.Subscription.Plan do
  @moduledoc """
  Defines a standard subscription plan data structure.
  """

  @typedoc "A plan interval type."
  @type interval :: :day | :week | :month | :year

  @typedoc "A integer interval count for a plan."
  @type interval_count :: non_neg_integer

  @doc """
  Defines the structure of a subscription plan.
  """
  defstruct price: nil,
            interval: nil,
            interval_count: nil

  @interval [:day, :week, :month, :year]

  @doc """
  Returns `{:ok, Money.Subscription.Plan.t}` or an `{:error, reason}`
  tuple.

  ## Arguments

  * `:price` is any `Money.t`

  * `:interval` is the period of the plan.  The valid intervals are
  `  `:day`, `:week`, `:month` or ':year`.

  * `:interval_count` is an integer count of the number of `:interval`s
    of the plan.  The default is `1`

  ## Returns

  A `Money.Subscription.Plan.t`

  ## Examples

      iex> Money.Subscription.Plan.new Money.new(:USD, 100), :month, 1
      {:ok,
       %Money.Subscription.Plan{
         interval: :month,
         interval_count: 1,
         price: Money.new(:USD, 100)
       }}

      iex> Money.Subscription.Plan.new Money.new(:USD, 100), :month
      {:ok,
       %Money.Subscription.Plan{
         interval: :month,
         interval_count: 1,
         price: Money.new(:USD, 100)
       }}

      iex> Money.Subscription.Plan.new Money.new(:USD, 100), :day, 30
      {:ok,
       %Money.Subscription.Plan{
         interval: :day,
         interval_count: 30,
         price: Money.new(:USD, 100)
       }}

      iex> Money.Subscription.Plan.new 23, :day, 30
      {:error, {Money.Invalid, "Invalid subscription plan definition"}}

  """
  @spec new(Money.t(), interval(), interval_count()) :: {:ok, Plan.t()} | {:error, Exception.t(), String.t()}
  def new(price, interval, interval_count \\ 1)

  def new(%Money{} = price, interval, interval_count)
      when interval in @interval and is_integer(interval_count) do
    {:ok, %__MODULE__{price: price, interval: interval, interval_count: interval_count}}
  end

  def new(_price, _interval, _interval_count) do
    {:error, {Money.Invalid, "Invalid subscription plan definition"}}
  end

  @doc """
  Returns `{:ok, Money.Subscription.Plan.t}` or raises an
  exception.

  Takes the same arguments as `Money.Subscription.Plan.new/3`.

  ## Example

      iex> Money.Subscription.Plan.new! Money.new(:USD, 100), :day, 30
      %Money.Subscription.Plan{
        interval: :day,
        interval_count: 30,
        price: Money.new(:USD, 100)
      }

  """
  @spec new!(Money.t(), interval(), interval_count()) :: Plan.t() | no_return()
  def new!(price, interval, interval_count \\ 1)

  def new!(price, interval, interval_count) do
    case new(price, interval, interval_count) do
      {:ok, plan} -> plan
      {:error, {exception, reason}} -> raise exception, reason
    end
  end
end
