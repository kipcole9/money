defmodule Money.CustomCurrencyTest do
  use ExUnit.Case

  test "Exchange rate conversion for a custom currency fails" do
    m1 = Money.new(:ABCD, 10)

    assert Money.to_currency(m1, :USD) ==
             {:error, {Money.ExchangeRateError, "No exchange rate is available for currency :ABCD"}}
  end

  test "Exchange rate conversion for a custom currency succeeds" do
    m1 = Money.new(:ABCD, 10)

    assert {:ok, m2} = Money.to_currency(m1, :USD, %{ABCD: 10, USD: 1})
    assert m2 == Money.new(:USD, "1.0")
  end

  test "creating a custom currency" do
    assert {:ok, %Localize.Currency{code: :XNEW}} =
             Money.Currency.new(:XNEW, name: "New Currency", digits: 2)

    assert Money.new(:XNEW, 100) == Money.new(:XNEW, "100")
  end

  test "creating a custom currency with extended code" do
    assert {:ok, %Localize.Currency{code: :QFFP}} =
             Money.Currency.new(:QFFP, name: "Frequent Flyer Points", digits: 0)

    assert Money.new(:QFFP, 500) == Money.new(:QFFP, "500")
  end

  test "validation rejects ISO codes" do
    assert {:error, %Money.CurrencyAlreadyDefinedError{}} =
             Money.Currency.new(:USD, name: "US Dollar")
  end

  test "validation rejects duplicate custom codes" do
    assert {:error, %Money.CurrencyAlreadyDefinedError{}} =
             Money.Currency.new(:ABCD, name: "Duplicate ABCD")
  end

  test "validation rejects invalid code format" do
    assert {:error, %Money.UnknownCurrencyError{}} =
             Money.Currency.new(:AB, name: "Too short")
  end

  test "validation requires a name" do
    assert {:error, _} = Money.Currency.new(:XZZZ)
  end

  test "custom currencies appear in known_currencies" do
    assert :ABCD in Money.known_currencies()
  end

  test "private_currencies returns custom currencies" do
    currencies = Money.Currency.private_currencies()
    assert %Localize.Currency{code: :ABCD} = currencies[:ABCD]
  end

  test "private_currency_codes returns custom currency codes" do
    assert :ABCD in Money.Currency.private_currency_codes()
  end

  test "currency_for_code returns custom currency" do
    assert {:ok, %Localize.Currency{code: :ABCD}} = Money.Currency.currency_for_code(:ABCD)
  end
end
