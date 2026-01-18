defmodule Money.CustomCurrencyTest do
  use ExUnit.Case

  setup do
    {:ok, _pid} = Cldr.Currency.start_link()
    {:ok, _currency} = Cldr.Currency.new(:ABCD, name: "ABCD", digits: 0)
    :ok
  end

  test "Exchange rate conversion for a custom currency fails" do
    m1 = Money.new(:ABCD, 10)

    assert  Money.to_currency(m1, :USD) ==
      {:error,
        {Money.ExchangeRateError, "No exchange rate is available for currency :ABCD"}}
  end

  test "Exchange rate conversion for a custom currency succeeds" do
    m1 = Money.new(:ABCD, 10)

    assert {:ok, m2} = Money.to_currency(m1, :USD, %{ABCD: 10, USD: 1})
    assert m2 == Money.new(:USD, "1.0")
  end
end