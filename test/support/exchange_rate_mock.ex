defmodule Money.ExchangeRates.Test do
  @behaviour Money.ExchangeRates

  @app_id "app_id"
  @exr_url "https://openexchangerates.org/api"

  @latest_endpoint "/latest.json"
  @latest_url @exr_url <> @latest_endpoint <> "?app_id=" <> @app_id
  def init(config) do
    url    = @latest_url
    app_id = @app_id

    Map.put(config, :retriever_options, %{url: url, app_id: app_id})
  end

  def get_latest_rates(_config) do
    get_rates(@latest_url)
  end

  defp get_rates("invalid_url") do
    {:error, "bad url"}
  end

  defp get_rates("http:/something.com/unknown" = url) do
    {:error, "#{url} was not found"}
  end

  defp get_rates(@latest_url) do
    {:ok,
      %{AUD: Decimal.new(0.7), EUR: Decimal.new(1.2), USD: Decimal.new(1)}
    }
  end
end