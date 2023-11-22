defmodule Money.ExchangeRatesLite.HttpClient.Adapter.CldrHttpTest do
  use ExUnit.Case

  use ExUnit.Case, async: true

  alias Money.ExchangeRatesLite.HttpClient.Config
  alias Money.ExchangeRatesLite.HttpClient.Adapter.CldrHttp

  setup do
    config = Config.new!([])
    [config: config]
  end

  describe "get/3" do
    test "requests an url", %{config: config} do
      assert {:ok, _headers, _body} = CldrHttp.get(config, "https://httpbin.org/status/200", [])
    end

    test "handles the headers", %{config: config} do
      assert {:ok, _headers, body} =
               CldrHttp.get(config, "https://httpbin.org/headers", [{"x-custom", ""}])

      assert body =~ ~r/x-custom/i
    end
  end
end
