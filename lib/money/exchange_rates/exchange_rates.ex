defmodule Money.ExchangeRates do
  @moduledoc """
  Implements functions to retrieve exchange rates from Open Exchange Rates.

  An `app_id` is required and is configured in `config.exs` of the appropriate
  environment configuration file.  The `app_id` can be configured as either
  a string or as a tuple `{:system, "shell variable name"}` to ease runtime
  retrieval of the `app_id`.

  ##Example configurations:

      config :ex_money,
        open_exchange_rates_app_id: "app_id_string",
        open_exchange_rates_retrieve_every: 360_000

      config :ex_money,
        open_exchange_rates_app_id: {:system, "OPEN_EXCHANGE_RATES_APP_ID"},
        open_exchange_rates_retrieve_every: 360_000
  """

  @app_id Money.get_env(:open_exchange_rates_app_id)
  @exr_url "https://openexchangerates.org/api"

  if is_nil(@app_id) do
    raise ArgumentError, message: "An Open Exchange Rates app_id must be configured in config.exs"
  end

  @doc """
  Return the latest exchange rates.

  Returns:

  * `{:ok, rates}` if exchange rates are successfully retrieved.  `rates` is a map of
  exchange rate converstion.

  * `:error` if no exchange rates are available
  """
  def latest_rates do
    case :ets.lookup(:exchange_rates, :rates) do
      [{:rates, rates}] -> {:ok, rates}
      [] -> :error
    end
  end

  @doc """
  Retrieves the latest exchange rates from Open Exchange Rates site.

  Returns:

  * `{:ok, rates}` is the rates can be retrieved

  * `{:error, reason}` if rates cannot be retrieved
  """
  @latest_endpoint "/latest.json"
  @latest_url @exr_url <> @latest_endpoint <> "?app_id=" <> @app_id
  def get_latest_rates do
    get_rates(@latest_url)
  end

  defp get_rates(url) do
    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        %{"base" => base, "rates" => rates} = Poison.decode!(body)

        decimal_rates = rates
        |> Cldr.Map.atomize_keys
        |> Enum.map(fn {k, v} -> {k, Decimal.new(v)} end)

        {:ok, decimal_rates}
      {:ok, %HTTPoison.Response{status_code: 404}} ->
        {:error, "#{url} was not found"}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end
end