defmodule Money.Arithmetic do
  @moduledoc false

  defmacro __using__(_opts) do
    quote location: :keep do
      import Kernel, except: [div: 2, round: 1]
      alias Cldr.Currency

      @doc """
      Add two `Money` values.

      ## Example

          iex> Money.add Money.new(:USD, 200), Money.new(:USD, 100)
          #Money<:USD, 300>
      """
      @spec add(Money.t, Money.t) :: Money.t
      def add(%Money{currency: code_a, amount: amount_a}, %Money{currency: code_b, amount: amount_b})
      when code_a == code_b do
        %Money{currency: code_a, amount: Decimal.add(amount_a, amount_b)}
      end

      def add(%Money{currency: code_a, amount: amount_a}, %Money{currency: code_b, amount: amount_b}) do
        raise ArgumentError, message: "Cannot add two %Money{} with different currencies. " <>
          "Received #{inspect code_a} and #{inspect code_b}."
      end

      @doc """
      Subtract one `Money` value struct from another.

      ## Example

          iex> Money.sub Money.new(:USD, 200), Money.new(:USD, 100)
          #Money<:USD, 100>
      """
      def sub(%Money{currency: code_a, amount: amount_a}, %Money{currency: code_b, amount: amount_b})
      when code_a == code_b do
        %Money{currency: code_a, amount: Decimal.sub(amount_a, amount_b)}
      end

      def sub(%Money{currency: code_a, amount: amount_a}, %Money{currency: code_b, amount: amount_b}) do
        raise ArgumentError, message: "Cannot subtract two %Money{} with different currencies. " <>
          "Received #{inspect code_a} and #{inspect code_b}."
      end

      @doc """
      Multiply a `Money` value by a number.

      * `money` is a %Money{} struct

      * `number` is an integer or float

      > Note that multipling one %Money{} by another is not supported.

      ## Example

          iex> Money.mult Money.new(:USD, 200), 2
          #Money<:USD, 400>
      """
      @spec mult(Money.t, number) :: Money.t
      def mult(%Money{currency: code, amount: amount}, number) when is_number(number) do
        %Money{currency: code, amount: Decimal.mult(amount, Decimal.new(number))}
      end

      def mult(%Money{} = money, number) do
        raise ArgumentError, message: "Cannot multiply a %Money{} by #{inspect number}"
      end

      @doc """
      Divide a `Money` value by a number.

      * `money` is a %Money{} struct

      * `number` is an integer or float

      > Note that dividing one %Money{} by another is not supported.

      ## Example

          iex> Money.div Money.new(:USD, 200), 2
          #Money<:USD, 100>
      """
      @spec div(Money.t, number) :: Money.t
      def div(%Money{currency: code, amount: amount}, number) when is_number(number) do
        %Money{currency: code, amount: Decimal.div(amount, Decimal.new(number))}
      end

      def div(%Money{} = money, other) do
        raise ArgumentError, message: "Cannot divide a %Money{} by #{inspect other}"
      end

      @doc """
      Returns a boolean indicating if two `Money` values are equal

      ## Example

          iex> Money.equal? Money.new(:USD, 200), Money.new(:USD, 200)
          true

          iex> Money.equal? Money.new(:USD, 200), Money.new(:USD, 100)
          false
      """
      @spec equal?(Money.t, Money.t) :: boolean
      def equal?(%Money{currency: code_a, amount: amount_a}, %Money{currency: code_b, amount: amount_b})
      when code_a == code_b do
        Decimal.equal?(amount_a, amount_b)
      end

      def equal?(_, _) do
        false
      end

      @doc """
      Compares two `Money` values numerically. If the first number is greater
      than the second :gt is returned, if less than :lt is returned, if both
      numbers are equal :eq is returned.

      ## Examples

          iex> Money.cmp Money.new(:USD, 200), Money.new(:USD, 100)
          :gt

          iex> Money.cmp Money.new(:USD, 200), Money.new(:USD, 200)
          :eq

          iex> Money.cmp Money.new(:USD, 200), Money.new(:USD, 500)
          :lt
      """
      def cmp(%Money{currency: code_a, amount: amount_a}, %Money{currency: code_b, amount: amount_b})
      when code_a == code_b do
        Decimal.cmp(amount_a, amount_b)
      end

      @doc """
      Compares two `Money` values numerically. If the first number is greater
      than the second #Integer<1> is returned, if less than Integer<-1> is
      returned. Otherwise, if both numbers are equal Integer<0> is returned.

      ## Examples

          iex> Money.compare Money.new(:USD, 200), Money.new(:USD, 100)
          1

          iex> Money.compare Money.new(:USD, 200), Money.new(:USD, 200)
          0

          iex> Money.compare Money.new(:USD, 200), Money.new(:USD, 500)
          -1
      """
      def compare(%Money{currency: code_a, amount: amount_a}, %Money{currency: code_b, amount: amount_b})
      when code_a == code_b do
        Decimal.compare(amount_a, amount_b)
        |> Decimal.to_integer
      end

      @doc """
      Split a `Money` value into a number of parts maintaining the currency's
      precision and rounding and ensuring that the parts sum to the original
      amount.

      * `money` is a `%Money{}` struct

      * `parts` is an integer number of parts into which the `money` is split

      Returns a tuple `{dividend, remainder}` as the function result
      derived as follows:

      1. Round the money amount to the required currency precision using
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
      Round a `Money` value into the acceptable range for the defined currency.

      * `money` is a `%Money{}` struct

      * `opts` is a keyword list with the following keys:

        * `:rounding_mode` that defines how the number will be rounded.  See
        `Decimal.Context`.  The default is `:half_even` which is also known
        as "banker's rounding"

        * `:cash` which determines whether the rounding is being applied to
        an accounting amount or a cash amount.  Some currencies, such as the
        :AUD and :CHF have a cash unit increment minimum which requires
        a different rounding increment to an arbitrary accounting amount. The
        default is `false`.

      There are two kinds of rounding applied:

      1.  Round to the appropriate number of fractional digits

      2. Apply an appropriate rounding increment.  Most currencies
      round to the same precision as the number of decimal digits, but some
      such as :AUD and :CHF round to a minimum such as 0.05 when its a cash
      amount.

      ## Examples

          iex> Money.round Money.new(123.7456, :CHF), cash: true
          #Money<:CHF, 125>

          iex> Money.round Money.new(123.7456, :CHF)
          #Money<:CHF, 123.75>

          Money.round Money.new(123.7456, :JPY)
          #Money<:JPY, 124>
      """
      def round(%Money{} = money, opts \\ []) do
        round_to_decimal_digits(money, opts)
        |> round_to_nearest(opts)
      end

      defp round_to_decimal_digits(%Money{currency: code, amount: amount}, opts \\ []) do
        rounding_mode = Keyword.get(opts, :rounding_mode, @default_rounding_mode)
        currency = Currency.for_code(code)
        rounding = if opts[:cash], do: currency.cash_digits, else: currency.digits
        rounded_amount = Decimal.round(amount, rounding, rounding_mode)
        %Money{currency: code, amount: rounded_amount}
      end

      defp round_to_nearest(%Money{currency: code, amount: amount} = money, opts \\ []) do
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

        rounded_amount = money.amount
        |> Decimal.div(rounding)
        |> Decimal.round(0, rounding_mode)
        |> Decimal.mult(rounding)

        %Money{currency: money.currency, amount: rounded_amount}
      end
    end
  end
end