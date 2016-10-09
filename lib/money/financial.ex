defmodule Money.Financial do
  @moduledoc false
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
      when is_number(interest_rate) and is_number(periods) do
        pv_1 = interest_rate
        |> Decimal.new
        |> Decimal.add(@one)
        |> Math.power(periods)

        pv = Decimal.div(@one, pv_1)
        |> Decimal.mult(amount)

        Money.new(currency, pv)
      end

      @doc """
      Calculates the effective interest rate for a given %Money{} present value,
      a %Money{} future value and a number of periods.

      * `present_value` is a %Money{} representation of the present value

      * `future_value` is a %Money{} representation of the future value

      * `periods` in an integer number of periods

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
    end
  end
end