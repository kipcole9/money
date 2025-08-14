defmodule Money.DigitalToken.Test do
  use ExUnit.Case, async: true

  test "Creating digital token money" do
    assert %Money{} = Money.new("BTC", "100")
    assert %Money{} = Money.new("ETH", 100)
    assert %Money{} = Money.new("Terra", 100)
    assert %Money{} = Money.new("4H95J0R2X", "100.234235")
  end

  # The regex engine in OTP 28 now recognises ₿ as a
  # currency symbol so we get a slightly different result
  # on that release and later.

  if System.otp_release() < "28" do
    test "Formatting digital token" do
      assert {:ok, "₿100.234235"} = Money.to_string(Money.new("BTC", "100.234235"))
    end
  else
    test "Formatting digital token" do
      assert {:ok, "₿\u00A0100.234235"} = Money.to_string(Money.new("BTC", "100.234235"))
    end
  end
end
