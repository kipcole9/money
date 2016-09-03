defmodule Money do

  @type t :: %Money{ currency: String.t , value: Decimal }
  defstruct currency: nil, value: nil

  # Tuple form comes from the database
  def new({currency_code, value}) do
    validate_currency_code!(currency_code)
    %Money{value: Decimal.new(value), currency: currency_code}
  end

  def new(value, currency_code) when is_number(value) and is_binary(currency_code) do
    validate_currency_code!(currency_code)
    %Money{value: Decimal.new(value), currency: currency_code}
  end

  def new(currency_code, value) when is_binary(currency_code) and is_number(value) do
    validate_currency_code!(currency_code)
    %Money{value: Decimal.new(value), currency: currency_code}
  end

  def new(%Decimal{} = value, currency_code) when is_binary(currency_code) do
    validate_currency_code!(currency_code)
    %Money{value: value, currency: currency_code}
  end

  def new(currency_code, %Decimal{} = value) when is_binary(currency_code) do
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

end

