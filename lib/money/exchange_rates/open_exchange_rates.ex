defmodule Money.ExchangeRates.OpenExchangeRates do
  @moduledoc """
  Implements the `Money.ExchangeRates` for the Open Exchange
  Rates service.

  ## Required configuration:

  The configuration key `:open_exchange_rates_app_id` should be
  set to your `app_id`.  for example:

      config :ex_money,
        open_exchange_rates_app_id: "your_app_id"

  or configure it via environment variable:

      config :ex_money,
        open_exchange_rates_app_id: {:system, "OPEN_EXCHANGE_RATES_APP_ID"}

  It is also possible to configure an alternative base url for this
  service in case it changes in the future. For example:

      config :ex_money,
        open_exchange_rates_app_id: "your_app_id"
        open_exchange_rates_url: "https://openexchangerates.org/alternative_api"

  """
  @behaviour Money.ExchangeRates

  @open_exchange_rate_url "https://openexchangerates.org/api"

  @doc """
  Update the retriever configuration to include the requirements
  for Open Exchange Rates.  This function is invoked when the
  exchange rate service starts up, just after the ets table
  :exchange_rates is created.

  * `default_config` is the configuration returned by `Money.ExchangeRates.default_config/0`

  Returns the configuration either unchanged or updated with
  additional configuration specific to this exchange
  rates retrieval module.
  """
  def init(default_config) do
    url    = Money.get_env(:open_exchange_rates_url, @open_exchange_rate_url)
    app_id = Money.get_env(:open_exchange_rates_app_id, nil)

    Map.put(default_config, :retriever_options, %{url: url, app_id: app_id})
  end

  @doc """
  Retrieves the latest exchange rates from Open Exchange Rates site.

  * `config` is the retrieval configuration. When invoked from the
  exchange rates services this will be the config returned from
  `Money.ExchangeRates.OpenExchangeRates.config/1`

  Returns:

  * `{:ok, rates}` if the rates can be retrieved

  * `{:error, reason}` if rates cannot be retrieved

  Typically this function is called by the exchange rates retrieval
  service although it can be called outside that context as
  required.
  """
  @spec get_latest_rates(Money.ExchangeRates.Config.t) :: {:ok, Map.t} | {:error, String.t}
  def get_latest_rates(config) do
    url = config.retriever_options.url
    app_id = config.retriever_options.app_id

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
