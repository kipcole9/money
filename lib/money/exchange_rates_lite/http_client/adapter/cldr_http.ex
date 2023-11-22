defmodule Money.ExchangeRatesLite.HttpClient.Adapter.CldrHttp do
  @moduledoc """
  HTTP client adapter for `Cldr.Http`.
  """

  use Money.ExchangeRatesLite.HttpClient.Adapter,
    schema_options: [
      verify_peer: [
        type: :boolean,
        default: true
      ]
    ]

  alias Money.ExchangeRatesLite.HttpClient.Config

  @impl true
  def get(%Config{} = config, url, headers) do
    verify_peer = Keyword.fetch!(config.adapter_options, :verify_peer)
    headers = format_request_headers(headers)

    Cldr.Http.get_with_headers({url, headers}, verify_peer: verify_peer)
    |> case do
      {:ok, headers, body} ->
        {:ok, format_response_headers(headers), format_response_body(body)}

      {:not_modified, headers} ->
        {:not_modified, format_response_headers(headers)}

      other ->
        other
    end
  end

  defp format_request_headers(headers) do
    Enum.map(headers, fn {key, value} -> {to_charlist(key), value} end)
  end

  defp format_response_headers(headers) do
    Enum.map(headers, fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  defp format_response_body(body) do
    to_string(body)
  end
end
