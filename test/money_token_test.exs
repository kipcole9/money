defmodule Money.DigitalToken.Test do
  use ExUnit.Case, async: true

  test "Creating digital token money" do
    assert %Money{} = Money.new("BTC", "100")
    assert %Money{} = Money.new("ETH", 100)
    assert %Money{} = Money.new("Terra", 100)
    assert %Money{} = Money.new("4H95J0R2X", "100.234235")
  end

  test "Formatting digital token" do
    assert {:ok, "₿ 100.234235"} = Money.to_string(Money.new("BTC", "100.234235"))
  end
end
