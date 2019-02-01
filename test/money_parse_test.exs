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

    test "parses with currency code out back" do
      assert Money.parse("100 USD") == Money.new(:USD, 100)
      assert Money.parse("100USD") == Money.new(:USD, 100)
      assert Money.parse("100 USD ") == Money.new(:USD, 100)
      assert Money.parse("100USD ") == Money.new(:USD, 100)
      assert Money.parse("100.00USD") == Money.new(:USD, "100.00")
    end

    test "parses with locale specific separators" do
      assert Money.parse("100,00USD", locale: "de") == Money.new(:USD, "100.00")
    end

    test "parsing fails" do
      assert Money.parse("100") ==
               {:error,
                {Money.Invalid, "A currency code must be specified but was not found in \"100\""}}

      assert Money.parse("EUR") ==
               {:error, {Money.Invalid, "An amount must be specified but was not found in \"EUR\""}}

      assert Money.parse("EUR 100 USD") ==
               {:error,
                {Money.Invalid,
                 "A currency code can only be specified once. Found both \"EUR\" and \"USD\"."}}

      string = "EUR 100 And some bogus extra stuff"

      assert {:error, {Money.Invalid, "Could not parse \"" <> string <> "\"."}} ==
               Money.parse(string)

      string = "100 EUR And some bogus extra stuff"

      assert {:error, {Money.Invalid, "Could not parse \"" <> string <> "\"."}} ==
               Money.parse(string)
    end
  end
end
