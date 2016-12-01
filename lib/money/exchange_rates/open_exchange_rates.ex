defmodule Money.ExchangeRates.OpenExchangeRates do
  @behaviour Money.ExchangeRates

  @app_id Money.get_env(:open_exchange_rates_app_id, "")
  @api_module Money.get_env(:api_module, __MODULE__)
  @exr_url "https://openexchangerates.org/api"

  if @app_id == "" and @api_module == __MODULE__ do
    raise ArgumentError, message: "An Open Exchange Rates app_id must be configured in config.exs"
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
        %{"base" => _base, "rates" => rates} = Poison.decode!(body)

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