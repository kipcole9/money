defmodule Money.ExchangeRatesLite.HttpClientTest do
  use ExUnit.Case

  alias Money.ExchangeRatesLite.HttpClient
  alias Money.ExchangeRatesLite.HttpClient.Config

  setup do
    config = Config.new!(name: MoneyTestExchangeRatesHttpClient)

    :ok = HttpClient.init(config)
    on_exit(fn -> HttpClient.terminate(config) end)

    [config: config]
  end

  test "ETS table for caching ETag is created" do
    assert :ets.info(MoneyTestExchangeRatesHttpClient.ETag) != :undefined
  end

  test "get/3 is ETag-sensitive", %{config: config} do
    etag = :rand.uniform(1_000_000)
    url = "https://httpbin.org/etag/#{etag}"

    assert {:ok, _body} = HttpClient.get(config, url)
    assert {:ok, :not_modified} = HttpClient.get(config, url)
  end
end
