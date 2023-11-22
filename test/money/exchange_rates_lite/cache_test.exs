defmodule Money.ExchangeRatesLite.CacheTest do
  use ExUnit.Case

  alias Money.ExchangeRatesLite.Cache
  alias Money.ExchangeRatesLite.Cache.Config

  setup do
    config = Config.new!(name: MoneyTestExchangeRatesCache)

    :ok = Cache.init(config)
    on_exit(fn -> Cache.terminate(config) end)

    [config: config]
  end

  test "reads / writes as expected", %{config: config} do
    key = :foo

    assert nil == Cache.get(config, key)
    assert "bar" == Cache.put(config, key, "bar")
    assert "bar" == Cache.get(config, key)
  end
end
