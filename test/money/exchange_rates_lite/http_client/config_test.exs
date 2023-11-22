defmodule Money.ExchangeRatesLite.HttpClient.ConfigTest do
  use ExUnit.Case, async: true

  alias Money.ExchangeRatesLite.HttpClient.Config

  describe "new!/1" do
    test "creates a %Config{}" do
      assert %Config{} = Config.new!([])
    end

    test "handles default values of options" do
      assert %Config{
               adapter: Money.ExchangeRatesLite.HttpClient.Adapter.CldrHttp,
               adapter_options: [verify_peer: true]
             } = Config.new!([])
    end

    test "raises errors when giving bad options" do
      assert_raise NimbleOptions.ValidationError,
                   "unknown options [:unknown], valid options are: [:adapter]",
                   fn ->
                     Config.new!(unknown: true)
                   end
    end

    test "raises errors when giving bad adapter options" do
      assert_raise NimbleOptions.ValidationError,
                   "unknown options [:unknown], valid options are: [:verify_peer]",
                   fn ->
                     Config.new!(
                       adapter: Money.ExchangeRatesLite.HttpClient.Adapter.CldrHttp,
                       adapter_options: [unknown: true]
                     )
                   end
    end
  end
end
