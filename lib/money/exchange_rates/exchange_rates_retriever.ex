defmodule Money.ExchangeRates.Retriever do
  @moduledoc """
  Implements a `GenServer` to retrieve exchange rates from
  a configured retrieveal module on a periodic or on demand basis.

  By default exchange rates are retrieved from [Open Exchange Rates](http://openexchangerates.org).

  The default period of execution is 5 minutes (300_000 milliseconds). The
  period of retrieval is configured in `config.exs` or the appropriate
  environment configuration.  For example:

      config :ex_money,
        retrieve_every: 300_000

  """

  use GenServer

  require Logger
  alias Money.ExchangeRates.Cache

  def start(name \\ __MODULE__, config \\ Money.ExchangeRates.config()) do
    start_link(name, config)
  end

  def start_link(name, config \\ Money.ExchangeRates.config()) do
    GenServer.start_link(__MODULE__, config, name: name)
  end

  @doc """
  Forces retrieval of the latest exchange rates

  Sends a message ot the exchange rate retrieval worker to request
  current rates be retrieved and stored.

  Returns:

  * `{:ok, rates}` if exchange rates request is successfully sent.

  * `{:error, reason}` if the request cannot be send.

  This function does not return exchange rates, for that see
  `Money.ExchangeRates.latest_rates/0` or
  `Money.ExchangeRates.historic_rates/1`.

  """
  def latest_rates() do
    case Process.whereis(Money.ExchangeRates.Retriever) do
      nil -> {:error, exchange_rate_service_error()}
      _pid -> GenServer.call(__MODULE__, :latest_rates)
    end
  end

  @doc """
  Forces retrieval of historic exchange rates for a single date

  * `date` is a date returned by `Date.new/3` or any struct with the
    elements `:year`, `:month` and `:day` or

  * a `Date.Range.t` created by `Date.range/2` that specifies a
    range of dates to retrieve

  Returns:

  * `{:ok, rates}` if exchange rates request is successfully sent.

  * `{:error, reason}` if the request cannot be send.

  Sends a message ot the exchange rate retrieval worker to request
  historic rates for a specified date or range be retrieved and
  stored.

  This function does not return exchange rates, for that see
  `Money.ExchangeRates.latest_rates/0` or
  `Money.ExchangeRates.historic_rates/1`.

  """
  def historic_rates(%Date{calendar: Calendar.ISO} = date) do
    case Process.whereis(__MODULE__) do
      nil -> {:error, exchange_rate_service_error()}
      _pid -> GenServer.call(__MODULE__, {:historic_rates, date})
    end
  end

  def historic_rates(%{year: year, month: month, day: day}) do
    case Date.new(year, month, day) do
      {:ok, date} -> historic_rates(date)
      error -> error
    end
  end

  def historic_rates(%Date.Range{first: from, last: to}) do
    historic_rates(from, to)
  end

  @doc """
  Forces retrieval of historic exchange rates for a range of dates

  * `from` is a date returned by `Date.new/3` or any struct with the
    elements `:year`, `:month` and `:day`.

  * `to` is a date returned by `Date.new/3` or any struct with the
    elements `:year`, `:month` and `:day`.

  Returns:

  * `{:ok, rates}` if exchange rates request is successfully sent.

  * `{:error, reason}` if the request cannot be send.

  Sends a message to the exchange rate retrieval process for each
  date in the range `from`..`to` to request historic rates be
  retrieved.

  """
  def historic_rates(%Date{calendar: Calendar.ISO} = from, %Date{calendar: Calendar.ISO} = to) do
    case Process.whereis(__MODULE__) do
      nil ->
        {:error, exchange_rate_service_error()}

      _pid ->
        for date <- Date.range(from, to) do
          GenServer.call(__MODULE__, {:historic_rates, date})
        end
    end
  end

  def historic_rates(%{year: y1, month: m1, day: d1}, %{year: y2, month: m2, day: d2}) do
    with {:ok, from} <- Date.new(y1, m1, d1),
         {:ok, to} <- Date.new(y2, m2, d2) do
      historic_rates(from, to)
    end
  end

  @doc """
  Updated the configuration for the Exchange Rate
  Service

  """
  def reconfigure(%Money.ExchangeRates.Config{} = config) do
    GenServer.call(__MODULE__, {:reconfigure, config})
  end

  #
  # Server implementation
  #

  def init(config) do
    Cache.init()

    if is_integer(config.retrieve_every) do
      log(config, :info, log_init_message(config.retrieve_every))
      schedule_work(0)
      schedule_work(config.retrieve_every)
    end

    if config.preload_historic_rates do
      log(config, :info, "Preloading historic rates for #{inspect(config.preload_historic_rates)}")
      schedule_work(config.preload_historic_rates)
    end

    {:ok, config}
  end

  def handle_call(:latest_rates, _from, config) do
    {:reply, retrieve_latest_rates(config), config}
  end

  def handle_call({:historic_rates, date}, _from, config) do
    {:reply, retrieve_historic_rates(date, config), config}
  end

  def handle_call({:reconfigure, new_configuration}, _from, _config) do
    {:reply, init(new_configuration)}
  end

  def handle_info(:latest_rates, config) do
    retrieve_latest_rates(config)
    schedule_work(config.retrieve_every)
    {:noreply, config}
  end

  def handle_info({:historic_rates, %Date{calendar: Calendar.ISO} = date}, config) do
    retrieve_historic_rates(date, config)
    {:noreply, config}
  end

  def handle_info(message, config) do
    Logger.error("Invalid message for ExchangeRates.Retriever: #{inspect(message)}")
    {:noreply, config}
  end

  defp retrieve_latest_rates(%{callback_module: callback_module} = config) do
    case config.api_module.get_latest_rates(config) do
      {:ok, :not_modified} ->
        log(config, :success, "Retrieved latest exchange rates successfully. Rates unchanged.")
        {:ok, Cache.latest_rates()}

      {:ok, rates} ->
        retrieved_at = DateTime.utc_now()
        Cache.store_latest_rates(rates, retrieved_at)
        apply(callback_module, :latest_rates_retrieved, [rates, retrieved_at])
        log(config, :success, "Retrieved latest exchange rates successfully")
        {:ok, rates}

      {:error, reason} ->
        log(config, :failure, "Could not retrieve latest exchange rates: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp retrieve_historic_rates(date, %{callback_module: callback_module} = config) do
    case config.api_module.get_historic_rates(date, config) do
      {:ok, rates} ->
        Cache.store_historic_rates(rates, date)
        apply(callback_module, :historic_rates_retrieved, [rates, date])

        log(
          config,
          :success,
          "Retrieved historic exchange rates for #{Date.to_string(date)} successfully"
        )

        {:ok, rates}

      {:error, reason} ->
        log(
          config,
          :failure,
          "Could not retrieve historic exchange rates " <>
            "for #{Date.to_string(date)}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp schedule_work(delay_ms) when is_integer(delay_ms) do
    Process.send_after(self(), :latest_rates, delay_ms)
  end

  defp schedule_work(%Date{calendar: Calendar.ISO} = date) do
    Process.send(self(), {:historic_rates, date}, [])
  end

  defp schedule_work(%Date.Range{} = date_range) do
    for date <- date_range do
      Process.send(self(), {:historic_rates, date}, [])
    end
  end

  defp schedule_work({%Date{} = from, %Date{} = to}) do
    schedule_work(Date.range(from, to))
  end

  defp schedule_work(date_string) when is_binary(date_string) do
    parts = String.split(date_string, "..")

    case parts do
      [date] -> schedule_work(Date.from_iso8601(date))
      [from, to] -> schedule_work({Date.from_iso8601(from), Date.from_iso8601(to)})
    end
  end

  # Any non-numeric value, or non-date value means
  # we don't schedule work - ie there is no periodic
  # retrieval
  defp schedule_work(_) do
    :ok
  end

  def log(%{log_levels: log_levels}, key, message) do
    case Map.get(log_levels, key) do
      nil ->
        nil

      log_level ->
        Logger.log(log_level, message)
    end
  end

  defp log_init_message(every) do
    {every, plural_every} = seconds(every)

    "Exchange Rates will be retrieved now and then every #{every} #{plural_every}."
  end

  defp seconds(milliseconds) do
    seconds = div(milliseconds, 1000)
    plural = if seconds == 1, do: "second", else: "seconds"
    {seconds, plural}
  end

  defp exchange_rate_service_error do
    {Money.ExchangeRateError, "Exchange rate service does not appear to be running"}
  end
end
