defmodule Money.ExchangeRatesLite.HttpClient.ConfigTest do
  use ExUnit.Case, async: true

  alias Money.ExchangeRatesLite.HttpClient.Config

  describe "new!/1" do
    test "creates a %Config{}" do
      assert %Config{name: MoneyTestExchangeRatesHttpClient} =
               Config.new!(name: MoneyTestExchangeRatesHttpClient)
    end

    test "handles default values of options" do
      assert %Config{
               name: MoneyTestExchangeRatesHttpClient,
               adapter: Money.ExchangeRatesLite.HttpClient.CldrHttp,
               adapter_options: [verify_peer: true]
             } = Config.new!(name: MoneyTestExchangeRatesHttpClient)
    end

    test "raises errors when giving bad options" do
      assert_raise NimbleOptions.ValidationError,
                   "required :name option not found, received options: []",
                   fn ->
                     Config.new!([])
                   end
    end

    test "raises errors when giving bad adapter options" do
      assert_raise NimbleOptions.ValidationError,
                   "unknown options [:unknown], valid options are: [:verify_peer]",
                   fn ->
                     Config.new!(
                       name: MoneyTestExchangeRatesHttpClient,
                       adapter: Money.ExchangeRatesLite.HttpClient.CldrHttp,
                       adapter_options: [unknown: true]
                     )
                   end
    end
  end
end
