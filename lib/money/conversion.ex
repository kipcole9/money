defmodule Money.Currency.Conversion do
  @moduledoc false

  defmacro __using__(_opts) do
    quote location: :keep do
      alias Cldr.Currency

      @doc """
      Convert `money` from one currency to another.

      * `money` is a %Money{} struct

      * `to_currency` is a valid currency code into which the `money` is converted

      * `rates` is a `Map` of currency rates where the map key is an upcase
      atom and the value is a Decimal conversion factor.  The default is the
      latest available exchange rates returned from `Money.ExchangeRates.latest_rates()`

      ## Examples

          iex(5)> Money.to_currency Money.new(:USD, 100) , :AUD, %{USD: Decimal.new(1), AUD: Decimal.new(0.7345)}
          #Money<:AUD, 73.4500>

          iex(6)> Money.to_currency Money.new(:USD, 100) , :AUDD, %{USD: Decimal.new(1), AUD: Decimal.new(0.7345)}
          {:error, {Cldr.UnknownCurrencyError, "Currency :AUDD is not known"}}

          iex(8)> Money.to_currency Money.new(:USD, 100) , :CHF, %{USD: Decimal.new(1), AUD: Decimal.new(0.7345)}
          {:error, "No exchange rate is available for currency :CHF"}
      """
      def to_currency(money, to_currency, rates \\ Money.ExchangeRates.latest_rates())

      def to_currency(%Money{currency: currency} = money, to_currency, rates)
      when currency == to_currency do
        money
      end

      def to_currency(%Money{currency: currency} = money, to_currency, %{} = rates)
      when is_atom(to_currency) or is_binary(to_currency) do
        with {:ok, to_code} <- Money.validate_currency_code(to_currency) do
          if currency == to_code, do: money, else: to_currency(money, to_currency, {:ok, rates})
        else
          {:error, _} = error -> error
        end
      end

      def to_currency(%Money{currency: currency, amount: amount}, to_currency, {:ok, rates})
      when is_atom(to_currency) or is_binary(to_currency) do
        with {:ok, code} <- Money.validate_currency_code(to_currency),
             {:ok, base_rate} <- get_rate(currency, rates),
             {:ok, conversion_rate} <- get_rate(to_currency, rates) do

          converted_amount = amount
          |> Decimal.div(base_rate)
          |> Decimal.mult(conversion_rate)

          Money.new(to_currency, converted_amount)
        else
          {:error, _} = error -> error
        end
      end

      def to_currency(%Money{currency: currency, amount: amount}, to_currency, error) do
        error
      end

      def get_rate(currency, rates) do
        if rate = rates[currency] do
          {:ok, rate}
        else
          {:error, "No exchange rate is available for currency #{inspect currency}"}
        end
      end
    end
  end
end