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

    test "parses digital tokens" do
      assert Money.new("BTC", "100") == Money.parse("100 BTC")
      assert Money.new("BTC", "100") == Money.parse("100 Bitcoin")
      assert Money.new("BTC", "100") == Money.parse("BTC 100")
      assert Money.new("BTC", "100") == Money.parse("Bitcoin 100")
    end

    test "parsing with currency strings that are not codes" do
      assert Money.parse("australian dollar 12346.45") == Money.new(:AUD, "12346.45")
      assert Money.parse("12346.45 australian dollars") == Money.new(:AUD, "12346.45")
      assert Money.parse("12346.45 Australian Dollars") == Money.new(:AUD, "12346.45")
      assert Money.parse("12 346 dollar australien", locale: "fr") == Money.new(:AUD, 12346)
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
      assert Money.parse("100", default_currency: false) ==
               {:error,
                {Money.Invalid,
                 "A currency code, symbol or description must be specified but was not found in \"100\""}}
    end

    test "parse with locale determining currency" do
      assert Money.parse("100", locale: "en") == Money.new(:USD, 100)
      assert Money.parse("100", locale: "de") == Money.new(:EUR, 100)
    end

    test "parse with a default currency" do
      assert Money.parse("100", default_currency: :USD) == Money.new(:USD, 100)
      assert Money.parse("100", default_currency: "USD") == Money.new(:USD, 100)
      assert Money.parse("100", default_currency: "australian dollars") == Money.new(:AUD, 100)
    end

    test "with locale overrides" do
      # A locale that has a regional override. The regional override
      # takes precedence and hence the currency is USD
      assert Money.parse("100", locale: "zh-Hans-u-rg-uszzzz") == Money.new(:USD, 100)

      # A locale that has a regional override and a currency
      # override uses the currency override as precedent over
      # the regional override. In this case, EUR
      assert Money.parse("100", locale: "zh-Hans-u-rg-uszzzz-cu-eur") == Money.new(:EUR, 100)
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

    test "de locale" do
      assert Money.parse("1.127,54 €", locale: "de") == Money.new(:EUR, "1127.54")
    end

    test "Round trip parsing" do
      assert Money.parse("1 127,54 €", locale: "fr") ==
               Money.new!(:EUR, "1127.54")
               |> Money.to_string!(locale: "fr")
               |> Money.parse(locale: "fr")
    end

    test "parsing strings that have `.` in them" do
      assert Money.parse("4.200,00 kr.", locale: "da") == Money.new(:DKK, "4200.00")
    end

    test "parse a string that has RTL markers" do
      assert Money.parse("\u200F1.234,56\u00A0د.م.\u200F", locale: "ar-MA") ==
      Money.new(:MAD, "1234.56")
    end
  end
end
