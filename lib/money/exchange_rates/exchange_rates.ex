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
        open_exchange_rates_retrieve_every: 300_000

      config :ex_money,
        open_exchange_rates_app_id: {:system, "OPEN_EXCHANGE_RATES_APP_ID"},
        open_exchange_rates_retrieve_every: 300_000
  """

  @doc """
  Defines the behaviour to retrieve exchange rates from an external
  data source
  """
  @callback get_latest_rates() :: {:ok, %{}} | {:error, binary}

  require Logger

  # Defines the configuration for the exchange rates mechanism.
  defmodule Config do
    defstruct retrieve_every: nil, callback_module: nil, log_levels: %{}
  end

  @default_retrieval_interval 300_000
  @default_callback_module Money.ExchangeRates.Callback
  @default_api_module Money.ExchangeRates.OpenExchangeRates

  @doc """
  Returns the configuration for the exchange rates retriever.
  """
  def config do
    %Config{
      retrieve_every: Money.get_env(:exchange_rates_retrieve_every, @default_retrieval_interval),
      callback_module: Money.get_env(:callback_module, @default_callback_module),
      log_levels: %{
        success: Money.get_env(:log_success, nil),
        info: Money.get_env(:log_info, :warn),
        failure: Money.get_env(:log_failure, :warn)
      }
    }
  end

  @doc """
  Return the latest exchange rates.

  Returns:

  * `{:ok, rates}` if exchange rates are successfully retrieved.  `rates` is a map of
  exchange rate converstion.

  * `{:error, reason}` if no exchange rates can be returned.
  """
  def latest_rates do
    try do
      case :ets.lookup(:exchange_rates, :rates) do
        [{:rates, rates}] -> {:ok, rates}
        [] -> {:error, "No exchange rates were found"}
      end
    rescue
      ArgumentError ->
        Logger.error "Argument error getting exchange rates from ETS table"
        {:error, "No exchange rates are available"}
    end
  end

  @doc """
  Return the timestamp of the last successful retrieval of exchange rates or
  `{:error, reason}` if no timestamp is known.

  ##Example:

      Money.ExchangeRates.last_updated
      #> {:ok,
       %DateTime{calendar: Calendar.ISO, day: 20, hour: 12, microsecond: {731942, 6},
        minute: 36, month: 11, second: 6, std_offset: 0, time_zone: "Etc/UTC",
        utc_offset: 0, year: 2016, zone_abbr: "UTC"}}
  """
  def last_updated do
    case :ets.lookup(:exchange_rates, :last_updated) do
      [{:last_updated, timestamp}] ->
        {:ok, timestamp}
      [] ->
        Logger.error "Argument error getting last updated timestamp from ETS table"
        {:error, "Last updated date is not known"}
    end
  end

  @doc """
  Retrieves exchange rates from the configured exchange rate api module.

  This call is the public api to retrieve results from an external api service
  or other mechanism implemented by an api module.  This method is typically
  called periodically by `Money.ExchangeRates.Retriever.handle_info/2` but can
  called at any time by other functions.
  """
  def get_latest_rates do
    Money.get_env(:api_module, @default_api_module).get_latest_rates()
  end
end
