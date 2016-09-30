defmodule Money.Arithmetic do
  @moduledoc """
  Arithmetic functions for %Money{}
  """

  defmacro __using__(_opts) do
    quote do
      alias Cldr.Currency

      def add(%Money{currency: code_a, value: value_a}, %Money{currency: code_b, value: value_b})
      when code_a == code_b do
        %Money{currency: code_a, value: Decimal.add(value_a, value_b)}
      end

      def sub(%Money{currency: code_a, value: value_a}, %Money{currency: code_b, value: value_b})
      when code_a == code_b do
        %Money{currency: code_a, value: Decimal.sub(value_a, value_b)}
      end

      def mult(%Money{currency: code, value: value}, integer) when is_integer(integer) do
        %Money{currency: code, value: Decimal.mult(value, Decimal.new(integer))}
      end

      def div(%Money{currency: code, value: value}, integer) when is_integer(integer) do
        %Money{currency: code, value: Decimal.div(value, Decimal.new(integer))}
      end

      def equal?(%Money{currency: code_a, value: value_a}, %Money{currency: code_b, value: value_b})
      when code_a == code_b do
        Decimal.equal?(value_a, value_b)
      end

      def cmp(%Money{currency: code_a, value: value_a}, %Money{currency: code_b, value: value_b})
      when code_a == code_b do
        Decimal.cmp(value_a, value_b)
      end

      def compare(%Money{currency: code_a, value: value_a}, %Money{currency: code_b, value: value_b})
      when code_a == code_b do
        Decimal.compare(value_a, value_b)
      end

      @doc """
      Round a %Money{} into the acceptable range for the defined currency.

      There are two kinds of rounding applied:

      1.  Is to round to the appropriate number of fractional digits

      2.  Its to apply an appropriate rounding increment.  Most currencies
      round to the same precision as the number of decimal digits. But some
      currencies, like Swiss Francs, round to some other increment.
      """
      def round(%Money{} = money, opts \\ []) do
        round_to_decimal_digits(money, opts)
        |> round_to_nearest(opts)
      end

      defp round_to_decimal_digits(%Money{currency: code, value: value}, opts \\ []) do
        rounding_mode = Keyword.get(opts, :rounding_mode, @default_rounding_mode)
        currency = Currency.for_code(code)
        rounding = if opts[:cash], do: currency.cash_digits, else: currency.digits
        rounded_value = Decimal.round(value, rounding, rounding_mode)
        %Money{currency: code, value: rounded_value}
      end

      def round_to_nearest(%Money{currency: code, value: value} = money, opts \\ []) do
        currency  = Currency.for_code(code)
        increment = if opts[:cash], do: currency.cash_rounding, else: currency.rounding
        do_round_to_nearest(money, increment, opts)
      end

      defp do_round_to_nearest(money, 0, opts) do
        money
      end

      defp do_round_to_nearest(money, increment, opts) do
        rounding_mode = Keyword.get(opts, :rounding_mode, @default_rounding_mode)
        rounding = Decimal.new(increment)

        rounded_value = money
        |> Decimal.div(rounding)
        |> Decimal.round(0, rounding_mode)
        |> Decimal.mult(rounding)

        %Money{currency: money.code, value: rounded_value}
      end
    end
  end
end