defmodule Money.Arithmetic do
  @moduledoc """
  Arithmetic functions for %Money{}
  """

  defmacro __using__(_opts) do
    quote do
      import Kernel, except: [div: 2, round: 1]
      alias Cldr.Currency

      @doc """
      Add two `%Money{}` structs.

      ## Example

          Money.add Money.new(:USD, 200), Money.new(:USD, 100)
          $300.00
      """
      @spec add(Money.t, Money.t) :: Money.t
      def add(%Money{currency: code_a, value: value_a}, %Money{currency: code_b, value: value_b})
      when code_a == code_b do
        %Money{currency: code_a, value: Decimal.add(value_a, value_b)}
      end

      def add(%Money{currency: code_a, value: value_a}, %Money{currency: code_b, value: value_b}) do
        raise ArgumentError, message: "Cannot add two %Money{} with different currencies. " <>
          "Received #{inspect code_a} and #{inspect code_b}."
      end

      @doc """
      Subtract one `%Money{}` struct from another.

      ## Example

          Money.sub Money.new(:USD, 200), Money.new(:USD, 100)
          $100.00
      """
      def sub(%Money{currency: code_a, value: value_a}, %Money{currency: code_b, value: value_b})
      when code_a == code_b do
        %Money{currency: code_a, value: Decimal.sub(value_a, value_b)}
      end

      def sub(%Money{currency: code_a, value: value_a}, %Money{currency: code_b, value: value_b}) do
        raise ArgumentError, message: "Cannot subtract two %Money{} with different currencies. " <>
          "Received #{inspect code_a} and #{inspect code_b}."
      end

      @doc """
      Multiply a `%Money{}` by a number.

      * `money` is a %Money{} struct

      * `number` is an integer or float

      > Note that multipling one %Money{} by another is not supported.

      ## Example

          Money.mult Money.new(:USD, 200), 2
          $400.00
      """
      @spec mult(Money.t, number) :: Money.t
      def mult(%Money{currency: code, value: value}, number) when is_number(number) do
        %Money{currency: code, value: Decimal.mult(value, Decimal.new(number))}
      end

      def mult(%Money{} = money, number) do
        raise ArgumentError, message: "Cannot multiply a %Money{} by #{inspect number}"
      end

      @doc """
      Divide a `%Money{}` by a number.

      * `money` is a %Money{} struct

      * `number` is an integer or float

      > Note that dividing one %Money{} by another is not supported.

      ## Example

          Money.div Money.new(:USD, 200), 2
          $100.00
      """
      @spec div(Money.t, number) :: Money.t
      def div(%Money{currency: code, value: value}, number) when is_number(number) do
        %Money{currency: code, value: Decimal.div(value, Decimal.new(number))}
      end

      def div(%Money{} = money, other) do
        raise ArgumentError, message: "Cannot divide a %Money{} by #{inspect other}"
      end

      @doc """
      Returns a boolean indicating if two `%Money{}` structs are equal
      """
      @spec equal?(Money.t, Money.t) :: boolean
      def equal?(%Money{currency: code_a, value: value_a}, %Money{currency: code_b, value: value_b})
      when code_a == code_b do
        Decimal.equal?(value_a, value_b)
      end

      def equal?(_, _) do
        false
      end

      def cmp(%Money{currency: code_a, value: value_a}, %Money{currency: code_b, value: value_b})
      when code_a == code_b do
        Decimal.cmp(value_a, value_b)
      end

      def cmp(%Money{currency: code_a, value: value_a}, _) do
        :ne
      end

      def compare(%Money{currency: code_a, value: value_a}, %Money{currency: code_b, value: value_b})
      when code_a == code_b do
        Decimal.compare(value_a, value_b)
      end

      def compare(%Money{currency: code_a, value: value_a}, _) do
        :ne
      end

      @doc """
      Split a `%Money{}` amount into a number of parts maintaining the currency's
      precision and rounding and ensuring that the parts sum to the original
      value.

      * `money` is a `%Money{}` struct

      * `parts` is an integer number of parts into which the `money` is split

      Returns a tuple `{dividend, remainder}` as the function result
      derived as follows:

      1. Round the money value to the required currency precision using
      `Money.round/1`

      2. Divide the result of step 1 by the integer divisor

      3. Round the result of the division to the precision of the currency
      using `Money.round/1`

      4. Return two numbers: the result of the division and any remainder
      that could not be applied given the precision of the currency.

      ## Examples

          Money.split Money.new(123.5, :JPY), 3
          {¥41, ¥1}

          Money.split Money.new(123.4, :JPY), 3
          {¥41, ¥0}

          Money.split Money.new(123.7, :USD), 9
          {$13.74, $0.04}
      """
      def split(%Money{} = money, parts) when is_integer(parts) do
        rounded_money = Money.round(money)
        div = rounded_money
        |> Money.div(parts)
        |> round

        remainder = sub(rounded_money, mult(div, parts))
        {div, remainder}
      end

      @doc """
      Round a %Money{} struct into the acceptable range for the defined currency.

      * `money` is a `%Money{}` struct

      * `opts` is a keyword list with the following keys:

        * `:rounding_mode` that defines how the number will be rounded.  See
        `Decimal.Context`.  The default is `:half_even` which is also known
        as "banker's rounding"

        * `:cash` which determines whether the rounding is being applied to
        an accounting amount or a cash amount.  Some currencies, such as the
        :AUD and :CHF have a cash unit increment minimum which requires
        a different rounding increment to an arbitrary accounting value. The
        default is `false`.

      There are two kinds of rounding applied:

      1.  Round to the appropriate number of fractional digits

      2. Apply an appropriate rounding increment.  Most currencies
      round to the same precision as the number of decimal digits, but some
      such as :AUD and :CHF round to a minimum such as 0.05 when its a cash
      value.

      ## Examples

          Money.round Money.new(123.7456, :CHF), cash: true
          CHF125.00

          Money.round Money.new(123.7456, :CHF)
          CHF123.75

          Money.round Money.new(123.7456, :JPY)
          ¥124
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

      defp round_to_nearest(%Money{currency: code, value: value} = money, opts \\ []) do
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

        rounded_value = money.value
        |> Decimal.div(rounding)
        |> Decimal.round(0, rounding_mode)
        |> Decimal.mult(rounding)

        %Money{currency: money.currency, value: rounded_value}
      end
    end
  end
end