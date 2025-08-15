defmodule Money.Protocol.Test do
  use ExUnit.Case

  test "Money with format options with String.Chars protocol" do
    assert to_string(Money.new!(:USD, 100, fractional_digits: 4)) == "$100.0000"
  end

  test "Money with format options with Cldr.Chars protocol" do
    assert Cldr.to_string(Money.new!(:USD, 100, fractional_digits: 4)) == "$100.0000"
  end

  test "Subscription with String.Chars" do
    {:ok, plan} = Money.Subscription.Plan.new Money.new(:USD, 10), :year
    assert "$10.00 per year" = to_string(plan)
  end
end
