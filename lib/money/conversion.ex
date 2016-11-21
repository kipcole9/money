defmodule Money.Currency.Conversion do
  @moduledoc false

  defmacro __using__(_opts) do
    quote location: :keep do
      alias Cldr.Currency

      @doc """
      Convert `money` from one currency to another.

      * `money` is a %Money{} struct

      * `currency` is a valid currency code.  An exception is raised if the
      currency code is invalid or if there is no known exchange rate.

      * `rates` is a `Map` of currency rates where the map key is an upcase
      atom and the value is a decimal convertion factor.  The default is the
      latest available exchange rates from [Open Exchange Rates](http://openexchangerates.org)

      `to_currency` converts one money amount to another currency via a map of
      currency conversion values.

      ##Example

          #> Money.to_currency Money.new(:USD, 100), :AUD

      """
      def to_currency(money, to_currency, rates \\ Money.ExchangeRates.latest_rates())

      def to_currency(%Money{currency: currency} = money, to_currency, rates)
      when currency == to_currency do
        money
      end

      def to_currency(%Money{} = money, to_currency, %{} = rates)
      when is_atom(to_currency) do
        to_currency(money, to_currency, {:ok, rates })
      end

      def to_currency(%Money{currency: currency, amount: amount}, to_currency, {:ok, rates})
      when is_atom(to_currency) do
        validate_currency_code!(to_currency)
        validate_rate_exists!(to_currency, rates)

        base_rate = rates[currency]
        conversion_rate = rates[to_currency]

        converted_amount = amount
        |> Decimal.div(base_rate)
        |> Decimal.mult(conversion_rate)

        Money.new(converted_amount, to_currency)
      end

      def to_currency(%Money{currency: currency, amount: amount}, to_currency, :error) do
        :error
      end

      defp validate_rate_exists!(currency, rates) do
        if is_nil(rates[currency]) do
          raise Money.ExchangeRateError, "No exchange rate is available for currency #{inspect currency}"
        end
      end
    end
  end
end