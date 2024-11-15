defmodule MoneySpreadMoneyStructsTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  property "spread/2 works with Money.t() portions" do
    check all(
            portions <- list_of(integer(1..1000), min_length: 1, max_length: 100),
            spread_pennies <- positive_integer(),
            max_runs: 1_000
          ) do
      code = :usd
      amount = Money.from_integer(spread_pennies, code)
      portions = Enum.map(portions, &Money.from_integer(&1, code))

      splits = Money.spread(portions, amount)

      {:ok, sum} = Money.sum(splits)
      assert Money.equal?(sum, amount)
    end
  end
end
