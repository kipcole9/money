defmodule Money.Subscription.Plan do
  @moduledoc """
  Defines a standard subscription plan data structure.
  """

  @typedoc "A plan interval type."
  @type interval :: :day | :week | :month | :year

  @typedoc "A integer interval count for a plan."
  @type interval_count :: non_neg_integer

  @typedoc "A Subscription Plan"
  @type t :: %__MODULE__{
          price: Money.t() | nil,
          interval: interval,
          interval_count: interval_count
        }

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

  ### Arguments

  * `:price` is any `Money.t`

  * `:interval` is the period of the plan.  The valid intervals are
  `  `:day`, `:week`, `:month` or ':year`.

  * `:interval_count` is an integer count of the number of `:interval`s
    of the plan.  The default is `1`

  ### Returns

  A `Money.Subscription.Plan.t`

  ### Examples

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
  @spec new(Money.t(), interval(), interval_count()) ::
          {:ok, t()} | {:error, {module(), String.t()}}

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

  ##@ Example

      iex> Money.Subscription.Plan.new! Money.new(:USD, 100), :day, 30
      %Money.Subscription.Plan{
        interval: :day,
        interval_count: 30,
        price: Money.new(:USD, 100)
      }

  """
  @spec new!(Money.t(), interval(), interval_count()) :: t() | no_return()
  def new!(price, interval, interval_count \\ 1)

  def new!(price, interval, interval_count) do
    case new(price, interval, interval_count) do
      {:ok, plan} -> plan
      {:error, {exception, reason}} -> raise exception, reason
    end
  end

  if Code.ensure_loaded?(Cldr.Unit) do
    import Kernel, except: [to_string: 1]

    @doc """
    Return a localised string representation of a subscription
    plan.

    ### Arguments

    * Any `Money.Subscription.Plan.t/1` as returned from
      `Money.Subscription.Plan.new/3`.

    * `options` is a keyword list of options.

    ### Options

    * See `Cldr.Unit.to_string/1` for available options.

    ### Returns

    * `{:ok, localized_string}` or

    * `{:error, reason}`

    ### Examples

        iex> {:ok, plan} = Money.Subscription.Plan.new(Money.new(:USD, 10), :year)
        iex> Money.Subscription.Plan.to_string(plan)
        {:ok, "$10.00 per year"}
        iex> Money.Subscription.Plan.to_string(plan, locale: :ja)
        {:ok, "$10.00毎年"}
        iex> Money.Subscription.Plan.to_string(plan, locale: :de, style: :narrow)
        {:ok, "10,00\u00A0$/J"}

        iex> {:ok, plan} = Money.Subscription.Plan.new(Money.new(:USD, 10), :day, 30)
        iex> Money.Subscription.Plan.to_string(plan)
        {:ok, "$10.00 per 30 days"}
        iex> Money.Subscription.Plan.to_string(plan, locale: :de)
        {:ok, "10,00\u00A0$ pro 30 Tage"}
        iex> Money.Subscription.Plan.to_string(plan, locale: :de, style: :short)
        {:ok, "10,00\u00A0$/30 Tg."}

    """
    @doc since: "5.22.0"
    def to_string(%__MODULE__{} = plan, options \\ []) do
      backend = Keyword.get_lazy(options, :backend, &Money.default_backend/0)

      plan
      |> unit_from_plan()
      |> Cldr.Unit.new!(plan.price.amount)
      |> Cldr.Unit.to_string(backend, options)
    end

    def to_string!(%__MODULE__{} = plan, options \\ []) do
      case to_string(plan, options) do
        {:ok, string} -> string
        {:error, {exception, reason}} -> raise exception, reason
      end
    end

    defp unit_from_plan(%__MODULE__{interval_count: 1} = plan) do
      %{price: amount, interval: interval} = plan
      "curr-#{amount.currency}-per-#{interval}"
    end

    defp unit_from_plan(%__MODULE__{interval_count: interval_count} = plan) do
      %{price: amount, interval: interval} = plan
      "curr-#{amount.currency}-per-#{interval_count}-#{interval}"
    end
  end
end
