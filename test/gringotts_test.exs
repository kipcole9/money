defmodule Money.GringottsTest do
  use ExUnit.Case

  alias Gringotts.Money, as: MoneyProtocol
  describe "Gringotts.Money protocol implementation" do
    test "currency is an upcase String.t" do
      the_currency = MoneyProtocol.currency(Money.new(0, :USD))
      assert match?(currency when is_binary(currency), the_currency)
      assert the_currency == String.upcase(the_currency)
    end

    test "to_integer" do
      assert match?({"EUR", 4200, -2}, MoneyProtocol.to_integer(Money.new(42, :EUR)))
      assert match?({"BHD", 42_000, -3}, MoneyProtocol.to_integer(Money.new(42, :BHD)))
      assert match?({"BHD", 42_007, -3}, MoneyProtocol.to_integer(Money.new("42.0066", :BHD)))
    end

    test "to_string" do
      assert match?({"EUR", "42"}, MoneyProtocol.to_string(Money.new("42.00", :EUR)))
      assert match?({"EUR", "42"}, MoneyProtocol.to_string(Money.new(42, :EUR)))
      assert match?({"EUR", "42.01"}, MoneyProtocol.to_string(Money.new("42.0064", :EUR)))
      assert match?({"BHD", "42.006"}, MoneyProtocol.to_string(Money.new("42.006", :BHD)))
    end
  end
end