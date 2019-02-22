defmodule MoneyTest.Performance do
  use ExUnit.Case

  # This is fixed to a single machine spec which is not good.
  # A proper approach is required.

  # @acceptable_limit 76_000
  # @acceptable_tolerance 0.02
  # @iterations 1000
  # @acceptable_range trunc(@acceptable_limit * (1 - @acceptable_tolerance))..
  #                   trunc(@acceptable_limit * (1 + @acceptable_tolerance))
  #
  # test "that performance on rounding hasn't degraded" do
  #   m = Money.new(:USD, "2.04")
  #   {millseconds, :ok} = :timer.tc(fn ->
  #     Enum.each(1..@iterations, fn _x ->
  #       Money.round(m)
  #     end)
  #   end)
  #   assert millseconds in @acceptable_range
  # end
end