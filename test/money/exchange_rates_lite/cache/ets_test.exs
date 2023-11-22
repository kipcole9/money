defmodule Money.ExchangeRatesLite.Cache.EtsTest do
  use ExUnit.Case, async: true

  alias Money.ExchangeRatesLite.Cache.Config
  alias Money.ExchangeRatesLite.Cache.Ets

  @table :money_test_exchange_rates_cache_ets

  setup do
    config = Config.new!(name: MoneyTestExchangeRatesCacheEts, adapter: Ets)

    :ok = Ets.init(config)
    on_exit(fn -> Ets.terminate(config) end)

    [config: config]
  end

  test "reads / writes as expected", %{config: config} do
    key = :foo

    assert nil == Ets.get(config, key)
    assert "bar" == Ets.put(config, key, "bar")
    assert "bar" == Ets.get(config, key)
  end
end
