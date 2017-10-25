defmodule Money.ExchangeRates.OpenExchangeRates do
  @behaviour Money.ExchangeRates

  @doc """
  Retrieves the latest exchange rates from Open Exchange Rates site.

  * `app_id` is a valid Open Exchange Rates app_id.  Defaults to the
  configured `app_id` in `config.exs`

  Returns:

  * `{:ok, rates}` if the rates can be retrieved

  * `{:error, reason}` if rates cannot be retrieved

  Typically this function is called by the exchange rates retrieval
  service although it can be called outside that context as
  required.
  """

  @open_exchange_rate_url "https://openexchangerates.org/api"

  @spec get_latest_rates(Money.ExchangeRates.Config.t) :: {:ok, Map.t} | {:error, String.t}
  def get_latest_rates(_config) do
    url    = Money.get_env(:open_exchange_rates_url, @open_exchange_rate_url)
    app_id = Money.get_env(:open_exchange_rates_app_id, nil)

    get_rates(url, app_id)
  end

  defp get_rates(_url, nil) do
    {:error, "Open Exchange Rates app_id is not configured.  Rates are not retrieved."}
  end

  @latest_rates "/latest.json"
  defp get_rates(url, app_id) do
    get_rates(url <> @latest_rates <> "?app_id=" <> app_id)
  end

  defp get_rates(url) do
    case :httpc.request(String.to_charlist(url)) do
      {:ok, {{_version, 200, 'OK'}, _headers, body}} ->
        %{"base" => _base, "rates" => rates} = Poison.decode!(body)

        decimal_rates = rates
        |> Cldr.Map.atomize_keys
        |> Enum.map(fn {k, v} -> {k, Decimal.new(v)} end)
        |> Enum.into(%{})

        {:ok, decimal_rates}

      {_, {{_version, code, message}, _headers, _body}} ->
        {:error, "#{code} #{message}"}

      {:error, {:failed_connect, [{_, {_host, _port}}, {_, _, sys_message}]}} ->
        {:error, sys_message}
    end
  end
end
