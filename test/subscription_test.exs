defmodule MoneySubscriptionTest do
  use ExUnit.Case
  alias Money.Subscription.Plan
  alias Money.Subscription.Change
  alias Money.Subscription

  doctest Money.Subscription
  doctest Money.Subscription.Plan

  test "plan change at end of period has no credit and correct billing dates" do
    p1 = %{interval: :day, interval_count: 30, price: Money.new(:USD, 100)}
    p2 = %{interval: :day, interval_count: 30, price: Money.new(:USD, 200)}

    changeset = Money.Subscription.change_plan(p1, p2, current_interval_started: ~D[2018-03-01])

    assert changeset.first_billing_amount == Money.new(:USD, 200)
    assert changeset.first_interval_starts == ~D[2018-03-31]
    assert changeset.next_interval_starts == ~D[2018-04-30]
  end

  test "plan change on January 31th should preserve 31th even past february" do
    p1 = %{interval: :month, interval_count: 1, price: Money.new(:USD, 100)}
    p2 = %{interval: :month, interval_count: 1, price: Money.new(:USD, 200)}

    changeset = Money.Subscription.change_plan(p1, p2,
      current_interval_started: ~D[2018-01-30],
      first_interval_started: ~D[2017-12-31])

    assert changeset.first_billing_amount == Money.new(:USD, 200)
    assert changeset.first_interval_starts == ~D[2018-02-28]
    assert changeset.next_interval_starts == ~D[2018-03-31]
  end

  test "plan change at 50% of period has no credit and correct billing dates" do
    p1 = %{interval: :day, interval_count: 30, price: Money.new(:USD, 100)}
    p2 = %{interval: :day, interval_count: 30, price: Money.new(:USD, 200)}

    changeset =
      Money.Subscription.change_plan(
        p1,
        p2,
        current_interval_started: ~D[2018-03-01],
        effective: ~D[2018-03-16]
      )

    assert changeset.first_billing_amount == Money.new(:USD, "150.00")
    assert changeset.first_interval_starts == ~D[2018-03-16]
    assert changeset.next_interval_starts == ~D[2018-04-15]
    assert changeset.credit_amount_applied == Money.new(:USD, "50.00")

    assert Money.cmp!(
             Money.add!(changeset.credit_amount_applied, changeset.first_billing_amount),
             p2.price
           ) == :eq
  end

  test "should get days to add to subscription upgrade" do
    today = ~D[2018-02-14]

    old = %{
      price: Money.new(:CHF, Decimal.new(130)),
      interval: :month,
      interval_count: 3
    }

    new = %{
      price: Money.new(:CHF, Decimal.new(180)),
      interval: :month,
      interval_count: 6
    }

    assert %Change{
             carry_forward: Money.zero(:CHF),
             credit_amount: Money.new(:CHF, "67.20"),
             credit_amount_applied: Money.zero(:CHF),
             credit_days_applied: 68,
             credit_period_ends: ~D[2018-04-22],
             next_interval_starts: ~D[2018-10-21],
             first_billing_amount: new.price,
             first_interval_starts: today
           } ==
             Money.Subscription.change_plan(
               old,
               new,
               current_interval_started: ~D[2018-01-01],
               effective: today,
               prorate: :period
             )
  end

  test "should get days to add to subscription upgrade when upgrading the same day" do
    today = ~D[2018-01-01]

    old = %{
      price: Money.new(:CHF, Decimal.new(130)),
      interval: :month,
      interval_count: 3
    }

    new = %{
      price: Money.new(:CHF, Decimal.new(180)),
      interval: :month,
      interval_count: 6
    }

    assert %Change{
             carry_forward: Money.zero(:CHF),
             credit_amount: Money.new(:CHF, Decimal.new("130.00")),
             credit_amount_applied: Money.zero(:CHF),
             credit_days_applied: 131,
             credit_period_ends: ~D[2018-05-11],
             next_interval_starts: ~D[2018-11-09],
             first_billing_amount: new.price,
             first_interval_starts: today
           } ==
             Money.Subscription.change_plan(
               old,
               new,
               current_interval_started: today,
               effective: today,
               prorate: :period
             )
  end

  test "should get at least 1 day when subscription upgrade is from a very low subscription to a very high one" do
    today = ~D[2018-01-14]

    old = Money.Subscription.Plan.new!(Money.new(:CHF, Decimal.new("0.5")), :month)
    new = Money.Subscription.Plan.new!(Money.new(:CHF, Decimal.new(1000)), :month, 36)

    assert %Change{
             carry_forward: Money.zero(:CHF),
             credit_amount: Money.new(:CHF, "0.30"),
             credit_amount_applied: Money.zero(:CHF),
             credit_days_applied: 1,
             credit_period_ends: ~D[2018-01-14],
             next_interval_starts: ~D[2021-01-15],
             first_billing_amount: new.price,
             first_interval_starts: today
           } ==
             Money.Subscription.change_plan(
               old,
               new,
               current_interval_started: ~D[2018-01-01],
               effective: today,
               prorate: :period
             )
  end

  test "that a carry forward is generated when credit is greater than price" do
    p1 = Plan.new!(Money.new(:USD, 1000), :day, 20)
    p2 = Plan.new!(Money.new(:USD, 10), :day, 10)

    changeset =
      Subscription.change_plan(
        p1,
        p2,
        current_interval_started: ~D[2018-01-01],
        effective: ~D[2018-01-05]
      )

    assert changeset == %Change{
             carry_forward: Money.new(:USD, "-790.00"),
             credit_amount: Money.new(:USD, "800.00"),
             credit_amount_applied: Money.new(:USD, "10.00"),
             credit_days_applied: 0,
             credit_period_ends: nil,
             next_interval_starts: ~D[2018-01-15],
             first_billing_amount: Money.zero(:USD),
             first_interval_starts: ~D[2018-01-05]
           }
  end

  test "that month rollover works at end of month when next month is shorter" do
    assert Money.Subscription.next_interval_starts(
             %{interval: :month, interval_count: 1},
             ~D[2018-01-31]
           ) == ~D[2018-02-28]
  end

  @tag :sub
  test "That we can create a subscription" do
    Subscription.new Plan.new!(Money.new(:USD, 200), :month, 3), ~D[2018-01-01]
  end
end
