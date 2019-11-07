defmodule MoneyTest.Parse do
  use ExUnit.Case

  describe "Money.parse/2 " do
    test "parses with currency code in front" do
      assert Money.parse("USD 100") == Money.new(:USD, 100)
      assert Money.parse("USD100") == Money.new(:USD, 100)
      assert Money.parse("USD 100 ") == Money.new(:USD, 100)
      assert Money.parse("USD100 ") == Money.new(:USD, 100)
      assert Money.parse("USD 100.00") == Money.new(:USD, "100.00")
    end

    test "parses with a single digit amount" do
      assert Money.parse("USD 1") == Money.new(:USD, 1)
      assert Money.parse("USD1") == Money.new(:USD, 1)
      assert Money.parse("USD9") == Money.new(:USD, 9)
    end

    test "parses with currency code out back" do
      assert Money.parse("100 USD") == Money.new(:USD, 100)
      assert Money.parse("100USD") == Money.new(:USD, 100)
      assert Money.parse("100 USD ") == Money.new(:USD, 100)
      assert Money.parse("100USD ") == Money.new(:USD, 100)
      assert Money.parse("100.00USD") == Money.new(:USD, "100.00")
    end

    test "parsing with currency strings that are not codes" do
      assert Money.parse("australian dollar 12346.45") == Money.new(:AUD, "12346.45")
      assert Money.parse("12346.45 australian dollars") == Money.new(:AUD, "12346.45")
      assert Money.parse("12346.45 Australian Dollars") == Money.new(:AUD, "12346.45")
    end

    test "parses with locale specific separators" do
      assert Money.parse("100,00USD", locale: "de") == Money.new(:USD, "100.00")
    end

    test "parses euro (unicode symbol)" do
      assert Money.parse("99.99€") == Money.new(:EUR, "99.99")
    end

    test "currency filtering" do
      assert Money.parse("100 Mexican silver pesos") == Money.new(:MXP, 100)

      assert Money.parse("100 Mexican silver pesos", currency_filter: [:current]) ==
               {:error,
                {Money.UnknownCurrencyError,
                 "The currency \"Mexican silver pesos\" is unknown or not supported"}}
    end

    test "fuzzy matching of currencies" do
      assert Money.parse("100 eurosports", fuzzy: 0.8) == Money.new(:EUR, 100)

      assert Money.parse("100 eurosports", fuzzy: 0.9) ==
               {:error,
                {Money.UnknownCurrencyError,
                 "The currency \"eurosports\" is unknown or not supported"}}
    end

    test "parsing fails if no currency and no default currency" do
      assert Money.parse("100") ==
               {:error,
                {Money.Invalid,
                 "A currency code, symbol or description must be specified but was not found in \"100\""}}
    end

    test "parse with a default currency" do
      assert Money.parse("100", default_currency: :USD) == Money.new(:USD, 100)
      assert Money.parse("100", default_currency: "USD") == Money.new(:USD, 100)
      assert Money.parse("100", default_currency: "australian dollars") == Money.new(:AUD, 100)
    end

    test "parse with negative numbers" do
      assert Money.parse("-127,54 €", locale: "fr") == Money.new(:EUR, "-127.54")
      assert Money.parse("-127,54€", locale: "fr") == Money.new(:EUR, "-127.54")

      assert Money.parse("€ 127,54-", locale: "nl") == Money.new(:EUR, "-127.54")
      assert Money.parse("€127,54-", locale: "nl") == Money.new(:EUR, "-127.54")

      assert Money.parse("($127.54)", locale: "en") == Money.new(:USD, "-127.54")

      assert Money.parse("CHF -127.54", locale: "de-CH") == Money.new(:CHF, "-127.54")
      assert Money.parse("-127.54 CHF", locale: "de-CH") == Money.new(:CHF, "-127.54")

      assert Money.parse("kr-127,54", locale: "da") == Money.new(:DKK, "-127.54")
      assert Money.parse("kr -127,54", locale: "da") == Money.new(:DKK, "-127.54")
    end
  end
end
