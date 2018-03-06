defmodule MoneySubscriptionTest do
  use ExUnit.Case

  test "plan change at end of period has no credit and correct billing dates" do
    p1 = %{interval: :day, interval_count: 30, price: Money.new(:USD, 100)}
    p2 = %{interval: :day, interval_count: 30, price: Money.new(:USD, 200)}

    changeset = Money.Subscription.change p1, p2, ~D[2018-03-01]

    assert changeset[:next_billing_amount] == Money.new(:USD, 200)
    assert changeset[:next_billing_date] == ~D[2018-03-31]
    assert changeset[:following_billing_date] == ~D[2018-04-30]
  end

  test "plan change at 50% of period has no credit and correct billing dates" do
    p1 = %{interval: :day, interval_count: 30, price: Money.new(:USD, 100)}
    p2 = %{interval: :day, interval_count: 30, price: Money.new(:USD, 200)}

    changeset = Money.Subscription.change p1, p2, ~D[2018-03-01], effective: ~D[2018-03-16]

    assert changeset[:next_billing_amount] == Money.new(:USD, "150.00")
    assert changeset[:next_billing_date] == ~D[2018-03-16]
    assert changeset[:following_billing_date] == ~D[2018-04-15]
    assert changeset[:credit_amount_applied] == Money.new(:USD, "50.00")

    assert Money.cmp!(
      Money.add!(changeset[:credit_amount_applied], changeset[:next_billing_amount]),
      p2.price) == :eq
  end

end