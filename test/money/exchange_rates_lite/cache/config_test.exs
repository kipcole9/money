defmodule Money.ExchangeRatesLite.Cache.ConfigTest do
  use ExUnit.Case, async: true

  alias Money.ExchangeRatesLite.Cache.Config

  describe "new!/1" do
    test "creates a %Config{}" do
      assert %Config{name: MoneyTestExchangeRatesCache} =
               Config.new!(name: MoneyTestExchangeRatesCache)
    end

    test "handles default values of options" do
      assert %Config{
               name: MoneyTestExchangeRatesCache,
               adapter: Money.ExchangeRatesLite.Cache.Ets
             } = Config.new!(name: MoneyTestExchangeRatesCache)
    end

    test "raises errors when required options missing" do
      assert_raise NimbleOptions.ValidationError,
                   "required :name option not found, received options: []",
                   fn ->
                     Config.new!([])
                   end
    end
  end
end
