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
  service althouhg it can be called outside that context as
  required.
  """

  @dummy_app_id "not_configured"

  @spec get_latest_rates(String.t) :: {:ok, Map.t} | {:error, String.t}
  def get_latest_rates(app_id \\ @dummy_app_id) do
    url    = Money.get_env(:open_exchange_rates_url, "https://openexchangerates.org/api")
    app_id = Money.get_env(:open_exchange_rates_app_id, app_id)

    get_rates(url, app_id)
  end

  defp get_rates(_url, @dummy_app_id) do
    {:error, "Open Exchange Rates app_id is not configured.  Rates are not retrieved."}
  end
  defp get_rates(url, app_id) do
    get_rates(url <> "/latest.json?app_id=" <> app_id)
  end

  defp get_rates(url) do
    case :httpc.request(String.to_char_list(url)) do
      {:ok, {{_version, 200, 'OK'}, _headers, body}} ->
        %{"base" => _base, "rates" => rates} = Poison.decode!(body)

        decimal_rates = rates
        |> Cldr.Map.atomize_keys
        |> Enum.map(fn {k, v} -> {k, Decimal.new(v)} end)

        {:ok, decimal_rates}

      {_, {{_version, code, message}, _headers, _body}} ->
        {:error, "#{code} #{message}"}

      {:error, {:failed_connect, [{_, {_host, _port}}, {_, _, sys_message}]}} ->
        {:error, sys_message}
    end
  end
end
