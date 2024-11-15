defmodule MoneySpreadNumbersTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  property "spread/2 works with number portions" do
    # Max length is small; apparently float generation in stream_data is notably slow.

    check all(
            portions <-
              list_of(one_of([float(min: 0.001, max: 1.0e16), positive_integer()]),
                min_length: 1,
                max_length: 10
              ),
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
