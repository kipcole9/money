defmodule Money.ExchangeRates.OpenExchangeRates do
  @behaviour Money.ExchangeRates

  @dummy_app_id "not_configured"
  @app_id  Money.get_env(:open_exchange_rates_app_id, @dummy_app_id)
  @exr_url Money.get_env(:open_exchange_rates_url, "https://openexchangerates.org/api")

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
  @latest_endpoint "/latest.json"
  @latest_url @exr_url <> @latest_endpoint <> "?app_id="
  @spec get_latest_rates(String.t) :: {:ok, Map.t} | {:error, String.t}
  def get_latest_rates(app_id \\ @app_id)

  def get_latest_rates(@dummy_app_id) do
    {:error, "Open Exchange Rates app_id is not configured.  Rates are not retrieved."}
  end

  def get_latest_rates(app_id) do
    get_rates(@latest_url, app_id)
  end

  defp get_rates(url, app_id) when is_binary(url) do
    url <> app_id
    |> String.to_char_list
    |> get_rates
  end

  defp get_rates(url) when is_list(url) do
    require Logger

    case :httpc.request(url) do
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
