defmodule Money.ExchangeRates do
  @moduledoc """
  Implements a behaviour and functions to retrieve exchange rates
  from an exchange rate service.

  Configuration for the exchange rate service is defined
  in a `Money.ExchangeRates.Config` struct.  A default
  configuration is returned by `Money.ExchangeRates.default_config/0`.

  The default configuration is:

      config :ex_money,
        exchange_rate_service: false,
        exchange_rates_retrieve_every: 300_000,
        delay_before_first_retrieval: 100,
        api_module: Money.ExchangeRates.OpenExchangeRates,
        callback_module: Money.ExchangeRates.Callback,
        log_failure: :warn,
        log_info: :info,
        log_success: nil

  These keys are are defined as follows:

  * `:exchange_rate_service` is a boolean that determines whether to
    automatically start the exchange rate retrieval service.
    The default it false.

  * `:exchange_rates_retrieve_every` defines how often the exchange
    rates are retrieved in milliseconds. The default is 5 minutes
    (300,000 milliseconds)

  * `:delay_before_first_retrieval` defines how quickly the
    retrieval service makes its first request for exchange rates.
    The default is 100 milliseconds. Any value that is not a
    positive integer means that no first retrieval is made.
    Retrieval will continue on interval defined by `:retrieve_every`

  * `:api_module` identifies the module that does the retrieval of
    exchange rates. This is any module that implements the
    `Money.ExchangeRates` behaviour. The default is
    `Money.ExchangeRates.OpenExchangeRates`

  * `:callback_module` defines a module that follows the
    Money.ExchangeRates.Callback behaviour whereby the function
    `rates_retrieved/2` is invoked after every successful retrieval
    of exchange rates. The default is `Money.ExchangeRates.Callback`.

  * `:log_failure` defines the log level at which api retrieval
    errors are logged. The default is `:warn`

  * `:log_success` defines the log level at which successful api
    retrieval notifications are logged. The default is `nil` which
    means no logging.

  * `:log_info` defines the log level at which service startup messages
    are logged. The default is `:info`.

  * `:retriever_options` is available for exchange rate retriever
    module developers as a place to add retriever-specific configuration
    information.  This information should be added in the `init/1`
    callback in the retriever module.  See `Money.ExchangeRates.OpenExchangeRates.init/1`
    for an example.

  Keys can also be configured to retrieve values from environment
  variables. This lookup is done at runtime to facilitate deployment
  strategies. If the value of a configuration key is
  `{:system, "some_string"}` then "some_string" is interpreted as
  an environment variable name which is passed to System.get_env/2.

  An example configuration might be:

      config :ex_money,
        exchange_rate_service: {:system, "RATE_SERVICE"},
        exchange_rates_retrieve_every: {:system, "RETRIEVE_EVERY"},

  ## Open Exchange Rates

  If you plan to use the provided Open Exchange Rates module
  to retrieve exchange rates then you should also provide the additional
  configuration key for `app_id`:

      config :ex_money,
        open_exchange_rates_app_id: "your_app_id"

  or configure it via environment variable:

      config :ex_money,
        open_exchange_rates_app_id: {:system, "OPEN_EXCHANGE_RATES_APP_ID"}

  The default exchange rate retrieval module is provided in
  `Money.ExchangeRates.OpenExchangeRates` which can be used
  as a example to implement your own retrieval module for
  other services.

  ## Managing the configuration at runtime

  During exchange rate service startup, the function `init/1` is called
  on the configuration exchange rate retrieval module.  This module is
  expected to return an updated configuration allowing a developer to
  customise how the configuration is to be managed.  See the implementation
  at `Money.ExchangeRates.OpenExchangeRates.init/1` for an example.
  """

  @doc """
  Invoked to return the latest exchange rates from the configured
  exchange rate retrieval service.

  * `config` is an `%Money.ExchangeRataes.Config{}` struct

  Returns `{:ok, map_of_rates}` or `{:error, reason}`

  """
  @callback get_latest_rates(config :: Money.Config.t) :: {:ok, Map.t} | {:error, binary}

  @doc """
  Given the default configuration, returns an updated configuration at runtime
  during exchange rates service startup.

  This callback is optional.  If the callback is not defined, the default
  configuration returned by `Money.ExchangeRates.default_config/0` is used.

  * `config` is the configuration returned by `Money.ExchangeRates.default_config/0`

  The callback is expected to return a `%Money.ExchangeRates.Config{}` struct
  which may have been updated.  The configuration key `:retriever_options` is
  available for any service-specific configuration.
  """
  @callback init(config :: Money.Config.t) :: Money.Config.t
  @optional_callbacks init: 1

  require Logger
  alias Money.ExchangeRates.Retriever

  @default_retrieval_interval 300_000
  @default_delay_before_first_retrieval 100
  @default_callback_module Money.ExchangeRates.Callback
  @default_api_module Money.ExchangeRates.OpenExchangeRates

  @doc """
  Retiurns the configuratio for `ex_money` including the
  configuration merged from the configured exchange rates
  retriever module.
  """
  def config do
    if function_exported?(default_config().api_module, :init, 1) do
      config = default_config().api_module.init(default_config())
      Retriever.log(config, :info, "Initialized retrieval module #{inspect config.api_module}")
      config
    else
      default_config()
    end
  end

  # Defines the configuration for the exchange rates mechanism.
  defmodule Config do
    defstruct retrieve_every: nil, api_module: nil, callback_module: nil,
              log_levels: %{}, delay_before_first_retrieval: nil,
              retriever_options: nil
  end

  @doc """
  Returns the default configuration for the exchange rates retriever.
  """
  def default_config do
    %Config{
      api_module:
        Money.get_env(:api_module, @default_api_module, :module),
      callback_module:
        Money.get_env(:callback_module, @default_callback_module, :module),
      retrieve_every:
        Money.get_env(:exchange_rates_retrieve_every, @default_retrieval_interval, :integer),
      delay_before_first_retrieval:
        Money.get_env(:delay_before_first_retrieval, @default_delay_before_first_retrieval, :integer),
      log_levels: %{
        success: Money.get_env(:log_success, nil),
        info: Money.get_env(:log_info, :warn),
        failure: Money.get_env(:log_failure, :warn)
      }
    }
  end

  @doc """
  Forces retrieval of exchange rates

  Sends a message ot the exchange rate retrieval worker to request
  rates be retrieved.

  This function does not return exchange rates, for that see
  `Money.ExchangeRates.latest_rates/0`.
  """
  def retrieve() do
    case Process.whereis(Money.ExchangeRates.Retriever) do
      nil -> {:error, {Money.ExchangeRateError, "Exchange rate service does not appear to be running"}}
      pid -> Process.send(pid, :latest, [])
    end
  end

  @doc """
  Return the latest exchange rates.

  Returns:

  * `{:ok, rates}` if exchange rates are successfully retrieved.  `rates` is a map of
  exchange rates.

  * `{:error, reason}` if no exchange rates can be returned.
  """
  @spec latest_rates() :: {:ok, Map.t} | {:error, {Exception.t, binary}}
  def latest_rates do
    try do
      case :ets.lookup(:exchange_rates, :rates) do
        [{:rates, rates}] -> {:ok, rates}
        [] -> {:error, {Money.ExchangeRateError, "No exchange rates were found"}}
      end
    rescue
      ArgumentError ->
        Logger.error "Argument error getting exchange rates from ETS table"
        {:error, {Money.ExchangeRateError, "No exchange rates are available"}}
    end
  end

  @doc """
  Returns `true` if exchange rates are available
  and false otherwise.
  """
  @spec rates_available?() :: boolean
  def rates_available? do
    case latest_rates() do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  Return the timestamp of the last successful retrieval of exchange rates or
  `{:error, reason}` if no timestamp is known.

  ## Example

      Money.ExchangeRates.last_updated
      #> {:ok,
       %DateTime{calendar: Calendar.ISO, day: 20, hour: 12, microsecond: {731942, 6},
        minute: 36, month: 11, second: 6, std_offset: 0, time_zone: "Etc/UTC",
        utc_offset: 0, year: 2016, zone_abbr: "UTC"}}

  """
  @spec last_updated() :: {:ok, DateTime.t} | {:error, {Exception.t, binary}}
  def last_updated do
    case :ets.lookup(:exchange_rates, :last_updated) do
      [{:last_updated, timestamp}] ->
        {:ok, timestamp}
      [] ->
        Logger.error "Argument error getting last updated timestamp from ETS table"
        {:error, {Money.ExchangeRateError, "Last updated date is not known"}}
    end
  end

  @doc """
  Retrieves exchange rates from the configured exchange rate api module.

  This call is the public api to retrieve results from an external api service
  or other mechanism implemented by an api module.  This method is typically
  called periodically by `Money.ExchangeRates.Retriever.handle_info/2` but can
  called at any time by other functions.
  """
  def get_latest_rates(config \\ default_config()) do
    config.api_module.get_latest_rates(config)
  end
end
