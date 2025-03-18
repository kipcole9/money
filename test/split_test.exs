defmodule Money.SplitTest do
  use ExUnit.Case
  use ExUnitProperties

  property "check Money.split/3 always generates a non-negative remainder" do
    check all(
        amount <- StreamData.float(min: 0.01, max: 9999.99),
        parts <- StreamData.integer(2..10),
        rounding <- StreamData.integer(0..7),
        max_runs: 1_000) do
      money = Money.from_float(:USD, Float.round(amount, rounding))
      {split, remainder} = Money.split(money, parts)
      assert Money.compare(remainder, Money.zero(:USD)) in [:gt, :eq]
      assert Money.compare(Money.add!(Money.mult!(split, parts), remainder), money) == :eq
    end
  end

end