defmodule MoneySpreadIntegerTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  test "spread/2 works with a single integer as number of portions" do
    check all(
            portions <- integer(1..300),
            spread_pennies <- positive_integer(),
            max_runs: 1_000
          ) do
      amount = Money.from_integer(spread_pennies, :usd)
      splits = Money.spread(portions, amount)

      {:ok, sum} = Money.sum(splits)
      assert Money.equal?(sum, amount)
    end
  end
end
