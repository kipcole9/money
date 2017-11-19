defmodule Money.ExchangeRates.Retriever do
  @moduledoc """
  Implements a `GenServer` to retrieve exchange rates from
  a configured retrieveal module on a periodic basis.  By default exchange
  rates are retrieved from [Open Exchange Rates](http://openexchangerates.org).

  Retrieved data is stored in an `:ets` table.

  By default the period of execution is 5 minutes (300_000 microseconds). The
  period of retrieval is configured in `config.exs` or the appropriate
  environment configuration.  For example:

      config :ex_money,
        open_exchange_rates_app_id: "app_id_string",
        open_exchange_rates_retrieve_every: 300_000
  """

  use GenServer

  require Logger
  alias Money.ExchangeRates

  def start_link(name, config) do
    GenServer.start_link(__MODULE__, config, name: name)
  end

  def init(config) do
    log(config, :info, "Starting exchange rate retrieval service")
    initialize_ets_table()

    log(config, :info, log_init_message(config.retrieve_every))
    schedule_work(0)
    schedule_work(config.retrieve_every)

    if config.preload_historic_rates do
      log(config, :info, "Preloading historic rates for #{inspect config.preload_historic_rates}")
      schedule_work(config.preload_historic_rates)
    end

    {:ok, config}
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
    Logger.error "Invalid message for ExchangeRates.Retriever: #{inspect message}"
    {:noreply, config}
  end

  def retrieve_latest_rates(%{callback_module: callback_module} = config) do
    case ExchangeRates.get_latest_rates(config) do
      {:ok, rates} ->
        retrieved_at = DateTime.utc_now
        store_latest_rates(rates, retrieved_at)
        apply(callback_module, :latest_rates_retrieved, [rates, retrieved_at])
        log(config, :success, "Retrieved latest exchange rates successfully")
        {:ok, rates}
      {:error, reason} ->
        log(config, :failure, "Could not retrieve latest exchange rates: #{inspect reason}")
        {:error, reason}
    end
  end

  def retrieve_historic_rates(%Date{} = date, %{callback_module: callback_module} = config) do
    case ExchangeRates.get_historic_rates(date, config) do
      {:ok, rates} ->
        store_historic_rates(rates, date)
        apply(callback_module, :historic_rates_retrieved, [rates, date])
        log(config, :success,
          "Retrieved historic exchange rates for #{Date.to_string(date)} successfully")
        {:ok, rates}
      {:error, reason} ->
        log(config, :failure, "Could not retrieve historic exchange rates " <>
                              "for #{Date.to_string(date)}: #{inspect reason}")
        {:error, reason}
    end
  end

  defp schedule_work(delay_ms) when is_integer(delay_ms) do
    Process.send_after(self(), :latest_rates, delay_ms)
  end

  defp schedule_work(%Date{calendar: Calendar.ISO} =  date) do
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

  defp initialize_ets_table do
    :ets.new(:exchange_rates, [:named_table, read_concurrency: true])
  end

  defp store_latest_rates(rates, retrieved_at) do
    :ets.insert(:exchange_rates, {:latest_rates, rates})
    :ets.insert(:exchange_rates, {:last_updated, retrieved_at})
  end

  defp store_historic_rates(rates, date) do
    :ets.insert(:exchange_rates, {date, rates})
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

    "Rates will be retrieved now and then every #{every} #{plural_every}."
  end

  defp seconds(milliseconds) do
    seconds = div(milliseconds, 1000)
    plural = if seconds == 1, do: "second", else: "seconds"
    {seconds, plural}
  end
end
