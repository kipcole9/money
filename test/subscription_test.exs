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

  describe "change/4" do
    test "should get days to add to subscription upgrade" do
      today = ~D[2018-02-14]

      old = %{
        price: Money.new(:CHF, Decimal.new(130)),
        interval: :month,
        interval_count: 3,
      }
      new = %{
        price: Money.new(:CHF, Decimal.new(180)),
        interval: :month,
        interval_count: 6,
      }

      assert %{
        carry_forward: Money.zero(:CHF),
        credit_amount_applied: Money.new(:CHF, Decimal.new("67.20")),
        credit_days_applied: 68,
        credit_period_ends: ~D[2018-04-22],
        following_billing_date: ~D[2018-10-21],
        next_billing_amount: new.price,
        next_billing_date: today
        } == Money.Subscription.change(old, new, ~D[2018-01-01], effective: today, prorate: :period)
    end

    test "should get days to add to subscription upgrade when upgrading the same day" do
      today = ~D[2018-01-01]

      old = %{
        price: Money.new(:CHF, Decimal.new(130)),
        interval: :month,
        interval_count: 3,
      }
      new = %{
        price: Money.new(:CHF, Decimal.new(180)),
        interval: :month,
        interval_count: 6,
      }

      assert %{
        carry_forward: Money.zero(:CHF),
        credit_amount_applied: Money.new(:CHF, Decimal.new("130.00")),
        credit_days_applied: 131,
        credit_period_ends: ~D[2018-05-11],
        following_billing_date: ~D[2018-11-11],
        next_billing_amount: new.price,
        next_billing_date: today
        } == Money.Subscription.change(old, new, today, effective: today, prorate: :period)
    end

    test "should get at least 1 day when subscription upgrade is from a very low subscription to a very high one" do
      today = ~D[2018-01-14]

      old = %{
        price: Money.new(:CHF, Decimal.new("0.5")),
        interval: :month,
        interval_count: 1,
      }
      new = %{
        price: Money.new(:CHF, Decimal.new(1000)),
        interval: :month,
        interval_count: 36,
      }

      assert %{
        carry_forward: Money.zero(:CHF),
        credit_amount_applied: Money.new(:CHF, Decimal.new("0.30")),
        credit_days_applied: 1,
        credit_period_ends: ~D[2018-01-14],
        following_billing_date: ~D[2021-01-15],
        next_billing_amount: new.price,
        next_billing_date: today
        } == Money.Subscription.change(old, new, ~D[2018-01-01], effective: today, prorate: :period)
    end
  end
end