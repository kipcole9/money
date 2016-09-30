defmodule Money do
  @moduledoc """
  Money implements a set of functions to store, retrieve and perform arithmetic
  on a %Money{} type that is composed of a currency code and a currency value.

  Money is very opinionated in the interests of serving as a dependable library
  that can underpin accounting and financial applications.  In its initial
  release it can be expected that this contract may not be fully met.  But
  thats the contract.

  How is this opinion expressed:

  1. Money must always have both a value and a currency code.

  2. The currency code must always be valid.

  3. Money arithmetic can only be performed when both operands are of the
  same currency.

  4. Money values are stored as a `Decimal`.

  5. Money is serialised to the database as a custom Postgres type that includes
  both the value and the currency.  Therefore for serialization Postgres is
  assumed as the data store.

  6. All arithmetic functions work in un-rounded fixed point.  No rounding
  occurs automatically (unless expressly called out for a function).

  7. Explicit rounding obeys the rounding rules for a given currency.  The
  rounding rules are defined by the Unicode consortium in its CLDR
  repository as implemented by the hex package `ex_cldr`.  These rules
  define the number of fractional digits for a currency and the rounding
  increment where appropriate.
  """

  @opaque t :: %Money{currency: atom, value: Decimal}
  defstruct currency: nil, value: nil

  # Decimal fractional digits
  @rounding 8

  # Default mode for rounding is :half_even, also known
  # as bankers rounding
  @default_rounding_mode :half_even

  use Money.Arithmetic

  @doc """
  Returns the number of fractional digits to which money is rounded.

  This value is used to set the fractional digits in the Postgres migration
  and for rounding purposes.
  """
  def rounding do
    @rounding
  end

  # Tuple form comes from the database
  def new({currency_code, value}) do
    validate_currency_code!(currency_code)
    %Money{value: Decimal.new(value), currency: currency_code}
  end

  def new(value, currency_code) when is_number(value) and is_binary(currency_code) do
    currency_code
    |> String.downcase
    |> String.to_existing_atom
    |> new(value)
  end

  def new(currency_code, value) when is_number(value) and is_binary(currency_code) do
    new(value, currency_code)
  end

  def new(value, currency_code) when is_number(value) and is_atom(currency_code) do
    validate_currency_code!(currency_code)
    %Money{value: Decimal.new(value), currency: currency_code}
  end

  def new(currency_code, value) when is_atom(currency_code) and is_number(value) do
    validate_currency_code!(currency_code)
    %Money{value: Decimal.new(value), currency: currency_code}
  end

  def new(%Decimal{} = value, currency_code) when is_binary(currency_code) do
    validate_currency_code!(currency_code)
    %Money{value: value, currency: currency_code}
  end

  def new(currency_code, %Decimal{} = value) when is_atom(currency_code) do
    validate_currency_code!(currency_code)
    %Money{value: value, currency: currency_code}
  end

  def to_string(%Money{} = money, options \\ []) do
    options = merge_options(options, [currency: money.currency])
    Cldr.Number.to_string(money.value, options)
  end

  defp validate_currency_code!(currency_code) do
    if Cldr.Currency.known_currency?(currency_code) do
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
      Money.to_string(money)
    end
  end
end
