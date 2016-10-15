defmodule Money.Financial do
  @moduledoc false
  # Some algorithms from http://www.financeformulas.net
  alias Cldr.Number.Math

  defmacro __using__(_opts) do
    quote do
      @doc """
      Calculates the future value for a %Money{} present value, an interest rate
      and a number of periods.

      * `present_value` is a %Money{} representation of the present value

      * `interest_rate` is a float representation of an interest rate.  For
      example, 12% would be represented as `0.12`

      * `periods` in an integer number of periods

      ## Examples

          iex> Money.future_value Money.new(:USD, 10000), 0.08, 1
          #Money<:USD, 10800.00>

          iex> Money.future_value Money.new(:USD, 10000), 0.04, 2
          #Money<:USD, 10816.0000>

          iex> Money.future_value Money.new(:USD, 10000), 0.02, 4
          #Money<:USD, 10824.32160000>
      """
      @one Decimal.new(1)
      def future_value(%Money{currency: currency, amount: amount} = present_value, interest_rate, periods)
      when is_number(interest_rate) and is_number(periods) do
        fv = interest_rate
        |> Decimal.new
        |> Decimal.add(@one)
        |> Math.power(periods)
        |> Decimal.mult(amount)

        Money.new(currency, fv)
      end

      @doc """
      Calculates the future value for a list of cash flows and an interest rate.

      * `flows` is a list of tuples representing a cash flow.  Each flow is
      represented as a tuple of the form `{period, %Money{}}`

      * `interest_rate` is a float representation of an interest rate.  For
      example, 12% would be represented as `0.12`

      ## Example

          iex> Money.future_value([{4, Money.new(:USD, 10000)}, {5, Money.new(:USD, 10000)}, {6, Money.new(:USD, 10000)}], 0.13)
          #Money<:USD, 55548.605419090000>
      """
      def future_value(flows, interest_rate)

      def future_value({period, %Money{} = future_value}, interest_rate)
      when is_integer(period) and is_number(interest_rate) do
        future_value(future_value, interest_rate, period)
      end

      def future_value([{period, %Money{}} = flow | []], interest_rate)
      when is_integer(period) and is_number(interest_rate) do
        future_value(flow, interest_rate)
      end

      def future_value([{period, %Money{}} = flow | other_flows], interest_rate)
      when is_integer(period) and is_number(interest_rate) do
        Money.add(future_value(flow, interest_rate), future_value(other_flows, interest_rate))
      end

      @doc """
      Calculates the present value for %Money{} future value, an interest rate
      and a number of periods

      * `future_value` is a %Money{} representation of the future value

      * `interest_rate` is a float representation of an interest rate.  For
      example, 12% would be represented as `0.12`

      * `periods` in an integer number of periods

      ## Examples

          iex> Money.present_value Money.new(:USD, 100), 0.08, 2
          #Money<:USD, 85.73388203017832647462277092>

          iex> Money.present_value Money.new(:USD, 1000), 0.10, 20
          #Money<:USD, 148.6436280241436864020760472>
      """
      def present_value(%Money{currency: currency, amount: amount} = future_value, interest_rate, periods)
      when is_number(interest_rate) and interest_rate > 0 and is_number(periods) and periods > 0 do
        pv_1 = interest_rate
        |> Decimal.new
        |> Decimal.add(@one)
        |> Math.power(periods)

        pv = Decimal.div(@one, pv_1)
        |> Decimal.mult(amount)

        Money.new(currency, pv)
      end

      @doc """
      Calculates the present value for a list of cash flows and an interest rate.

      * `flows` is a list of tuples representing a cash flow.  Each flow is
      represented as a tuple of the form `{period, %Money{}}`

      * `interest_rate` is a float representation of an interest rate.  For
      example, 12% would be represented as `0.12`

      ## Example

          iex> Money.present_value([{4, Money.new(:USD, 10000)}, {5, Money.new(:USD, 10000)}, {6, Money.new(:USD, 10000)}], 0.13)
          #Money<:USD, 16363.97191111964880256655144>
      """
      def present_value(flows, interest_rate)

      def present_value({period, %Money{} = future_value}, interest_rate)
      when is_integer(period) and is_number(interest_rate) do
        present_value(future_value, interest_rate, period)
      end

      def present_value([{period, %Money{}} = flow | []], interest_rate)
      when is_integer(period) and is_number(interest_rate) do
        present_value(flow, interest_rate)
      end

      def present_value([{period, %Money{}} = flow | other_flows], interest_rate)
      when is_integer(period) and is_number(interest_rate) do
        Money.add(present_value(flow, interest_rate), present_value(other_flows, interest_rate))
      end

      @doc """
      Calculates the effective interest rate for a given %Money{} present value,
      a %Money{} future value and a number of periods.

      * `present_value` is a %Money{} representation of the present value

      * `future_value` is a %Money{} representation of the future value

      * `periods` is an integer number of periods

      ## Examples

          iex> Money.interest_rate Money.new(:USD, 10000), Money.new(:USD, 10816), 2
          #Decimal<0.04>

          iex> Money.interest_rate Money.new(:USD, 10000), Money.new(:USD, 10824.3216), 4
          #Decimal<0.02>
      """
      def interest_rate(%Money{currency: pv_currency, amount: pv_amount} = present_value,
                        %Money{currency: fv_currency, amount: fv_amount} = future_value,
                        periods)
      when pv_currency == fv_currency and is_number(periods) and periods > 0 do
        Decimal.div(fv_amount, pv_amount)
        |> Math.root(periods)
        |> Decimal.sub(@one)
      end

      @doc """
      Calculates the number of periods between a %Money{} present value and
      a %Money{} future value with a given interest rate.

      * `present_value` is a %Money{} representation of the present value

      * `future_value` is a %Money{} representation of the future value

      * `interest_rate` is a float representation of an interest rate.  For
      example, 12% would be represented as `0.12`

      ## Example

          iex> Money.periods Money.new(:USD, 1500), Money.new(:USD, 2000), 0.005
          #Decimal<57.68013595323872502502238648>
      """
      def periods(%Money{currency: pv_currency, amount: pv_amount} = present_value,
                  %Money{currency: fv_currency, amount: fv_amount} = future_value,
                  interest_rate)
      when pv_currency == fv_currency and is_number(interest_rate) and interest_rate > 0 do
        Decimal.div(Math.log(Decimal.div(fv_amount, pv_amount)),
                    Math.log(Decimal.add(@one, Decimal.new(interest_rate))))
      end

      @doc """
      Calculates the payment for a given loan or annuity given a %Money{}
      present value, an interest rate and a number of periods.

      * `present_value` is a %Money{} representation of the present value

      * `interest_rate` is a float representation of an interest rate.  For
      example, 12% would be represented as `0.12`

      * `periods` is an integer number of periods

      ## Example

          iex> Money.payment Money.new(:USD, 100), 0.12, 20
          #Money<:USD, 13.38787800396606622792492299>
      """
      def payment(%Money{currency: pv_currency, amount: pv_amount} = present_value,
                  interest_rate, periods)
      when is_number(interest_rate) and interest_rate > 0 and is_number(periods) and periods > 0 do
        interest_rate = Decimal.new(interest_rate)
        p1 = Decimal.mult(pv_amount, interest_rate)
        p2 = Decimal.sub(@one, Decimal.add(@one, interest_rate) |> Math.power(-periods))
        Money.new(pv_currency, Decimal.div(p1, p2))
      end
    end
  end
end