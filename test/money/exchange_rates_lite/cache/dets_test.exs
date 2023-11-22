defmodule Money.ExchangeRatesLite.Cache.DetsTest do
  use ExUnit.Case

  alias Money.ExchangeRatesLite.Cache.Config
  alias Money.ExchangeRatesLite.Cache.Dets

  @table :money_test_exchange_rates_cache_dets

  setup do
    config = Config.new!(name: MoneyTestExchangeRatesCacheDets, adapter: Dets)

    :ok = Dets.init(config)

    on_exit(fn ->
      Dets.terminate(config)
      cleanup_dets_files()
    end)

    [config: config]
  end

  defp cleanup_dets_files() do
    Dets.file_path(@table)
    |> Path.dirname()
    |> File.rm_rf!()
  end

  test "reads / writes as expected", %{config: config} do
    key = :foo

    assert nil == Dets.get(config, key)
    assert "bar" == Dets.put(config, key, "bar")
    assert "bar" == Dets.get(config, key)
  end
end
