defmodule Money do
  @moduledoc """
  Money implements a set of functions to store, retrieve and perform arithmetic
  on a %Money{} type that is composed of a currency code and a currency amount.

  Money is very opinionated in the interests of serving as a dependable library
  that can underpin accounting and financial applications.  In its initial
  release it can be expected that this contract may not be fully met.

  How is this opinion expressed:

  1. Money must always have both a amount and a currency code.

  2. The currency code must always be valid.

  3. Money arithmetic can only be performed when both operands are of the
  same currency.

  4. Money amounts are represented as a `Decimal`.

  5. Money is serialised to the database as a custom Postgres composite type
  that includes both the amount and the currency. Therefore for Ecto
  serialization Postgres is assumed as the data store. Serialization is
  entirely optional and Ecto is not a package dependency.

  6. All arithmetic functions work in fixed point decimal.  No rounding
  occurs automatically (unless expressly called out for a function).

  7. Explicit rounding obeys the rounding rules for a given currency.  The
  rounding rules are defined by the Unicode consortium in its CLDR
  repository as implemented by the hex package `ex_cldr`.  These rules
  define the number of fractional digits for a currency and the rounding
  increment where appropriate.
  """

  @typedoc """
  Money is composed of an atom representation of an ISO4217 currency code and
  a `Decimal` representation of an amount.
  """
  @type t :: %Money{currency: atom, amount: Decimal}
  defstruct currency: nil, amount: nil

  # Default mode for rounding is :half_even, also known
  # as bankers rounding
  @default_rounding_mode :half_even

  use Application
  use Money.Arithmetic
  use Money.Financial
  use Money.Currency.Conversion

  alias Cldr.Currency

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = if get_env(:exchange_rate_service, true) and Code.ensure_loaded?(HTTPoison) do
      [ supervisor(Money.ExchangeRates.Supervisor, []) ]
    else
      []
    end

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Money.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc """
  Returns a %Money{} struct from a tuple consistenting of a currency code and
  a currency amount.  The format of the argument is a 2-tuple where:

  * `currency_code` is an ISO4217 three-character upcased binary

  * `amount` is an integer, float or Decimal

  This function is typically called from Ecto when it's loading a %Money{}
  struct from the database.

  ## Example

      Money.new({"USD", 100})
      #Money<:USD, 100>
  """
  @spec new({binary, number}) :: Money.t
  def new(money_tuple)
  def new({currency_code, amount}) when is_binary(currency_code) do
    currency_code = Currency.normalize_currency_code(currency_code)

    validate_currency_code!(currency_code)
    %Money{amount: Decimal.new(amount), currency: currency_code}
  end

  @doc """
  Returns a %Money{} struct from a currency code and a currency amount.

  * `currency_code` is an ISO4217 three-character upcased binary or atom

  * `amount` is an integer, float or Decimal

  ## Examples

      iex> Money.new(:USD, 100)
      #Money<:USD, 100>

      iex> Money.new("USD", 100)
      #Money<:USD, 100>

      iex> Money.new("thb", 500)
      #Money<:THB, 500>

      iex> Money.new(500, "thb")
      #Money<:THB, 500>

      iex> Money.new("EUR", Decimal.new(100))
      #Money<:EUR, 100>
  """
  @spec new(number, binary) :: Money.t
  def new(currency_code, amount) when is_binary(currency_code) do
    currency_code
    |> Currency.normalize_currency_code
    |> new(amount)
  end

  def new(amount, currency_code) when is_binary(currency_code) do
    new(currency_code, amount)
  end

  def new(amount, currency_code) when is_number(amount) and is_atom(currency_code) do
    validate_currency_code!(currency_code)
    %Money{amount: Decimal.new(amount), currency: currency_code}
  end

  def new(currency_code, amount) when is_atom(currency_code) and is_number(amount) do
    validate_currency_code!(currency_code)
    %Money{amount: Decimal.new(amount), currency: currency_code}
  end

  def new(%Decimal{} = amount, currency_code) when is_atom(currency_code) do
    validate_currency_code!(currency_code)
    %Money{amount: amount, currency: currency_code}
  end

  def new(currency_code, %Decimal{} = amount) when is_atom(currency_code) do
    validate_currency_code!(currency_code)
    %Money{amount: amount, currency: currency_code}
  end

  @doc """
  Returns a formatted string representation of a `Money{}`.

  Formatting is performed according to the rules defined by CLDR. See
  `Cldr.Number.to_string/2` for formatting options.  The default is to format
  as a currency which applies the appropriate rounding and fractional digits
  for the currency.

  ## Examples

      iex> Money.to_string Money.new(:USD, 1234)
      "$1,234.00"

      iex> Money.to_string Money.new(:JPY, 1234)
      "¥1,234"

      iex> Money.to_string Money.new(:THB, 1234)
      "THB1,234.00"

      iex> Money.to_string Money.new(:USD, 1234), format: :long
      "1,234.00 US dollars"
  """
  def to_string(%Money{} = money, options \\ []) do
    options = merge_options(options, [currency: money.currency])
    Cldr.Number.to_string(money.amount, options)
  end

  @doc """
  Returns the amount part of a `Money{}` as a `Decimal`

  ## Example

      iex> m = Money.new("USD", 100)
      iex> Money.to_decimal(m)
      #Decimal<100>
  """
  def to_decimal(%Money{amount: amount}) do
    amount
  end

  def get_env(key, default \\ nil) do
    case env = Application.get_env(:ex_money, key, default) do
      {:system, env_key} ->
        System.get_env(env_key)
      _ ->
        env
    end
  end

  ## Helpers

  defp validate_currency_code!(currency_code) do
    if Currency.known_currency?(currency_code) do
      currency_code
    else
      raise Money.UnknownCurrencyError,
        "The currency code #{inspect currency_code} is not known"
    end
  end

  defp merge_options(options, required) do
    Keyword.merge(options, required, fn _k, _v1, v2 -> v2 end)
  end

  defimpl String.Chars do
    def to_string(v) do
      Money.to_string(v)
    end
  end

  defimpl Inspect, for: Money do
    def inspect(money, _opts) do
      "#Money<#{inspect money.currency}, #{Decimal.to_string(money.amount)}>"
    end
  end

  if Code.ensure_compiled?(Phoenix.HTML.Safe) do
    defimpl Phoenix.HTML.Safe, for: Money do
      def to_iodata(money) do
        Phoenix.HTML.Safe.to_iodata(to_string(money))
      end
    end
  end
end
