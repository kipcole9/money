defmodule Money.ExchangeRatesLite.Retriever.OpenExchangeRates do
  @moduledoc """
  Money.ExchangeRatesLite.Retriever adapter for [Open Exchange Rates](https://openexchangerates.org/).

  ## Options

    * `app_id` (required)
    * `base_url` - the url to use as the API endpoint. Default value is
      `"https://openexchangerates.org/api"`.

  """

  use Money.ExchangeRatesLite.Retriever,
    schema_options: [
      app_id: [
        type: :string,
        required: true
      ],
      base_url: [
        type: :string,
        default: "https://openexchangerates.org/api"
      ]
    ]

  alias Money.ExchangeRatesLite.HttpClient
  alias Money.ExchangeRatesLite.Retriever.Config

  @impl true
  def get_latest_rates(%Config{} = config) do
    url = "#{base_url(config)}/latest.json?app_id=#{app_id(config)}"

    config.http_client_config
    |> HttpClient.get(url)
    |> handle_response()
  end

  @impl true
  def get_historic_rates(%Config{} = config, date) do
    date_string = Date.to_string(date)
    url = "#{base_url(config)}/historical/#{date_string}.json?app_id=#{app_id(config)}"

    config.http_client_config
    |> HttpClient.get(url)
    |> handle_response()
  end

  defp handle_response(response) do
    case response do
      {:ok, body} when is_binary(body) -> {:ok, decode_body(body)}
      other -> other
    end
  end

  defp decode_body(body) do
    %{"base" => _base, "rates" => rates} = Money.json_library().decode!(body)

    rates
    |> Cldr.Map.atomize_keys()
    |> Enum.map(fn
      {k, v} when is_float(v) -> {k, Decimal.from_float(v)}
      {k, v} when is_integer(v) -> {k, Decimal.new(v)}
    end)
    |> Enum.into(%{})
  end

  defp app_id(config), do: Keyword.fetch!(config.adapter_options, :app_id)
  defp base_url(config), do: Keyword.fetch!(config.adapter_options, :base_url)
end
