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

    delay = config.delay_before_first_retrieval
    case delay do
      delay when is_integer(delay) and delay > 0 ->
        log(config, :info, log_init_message(delay, config.retrieve_every))
        schedule_work(delay)
      _ ->
        log(config, :info, log_init_message(config.retrieve_every))
        schedule_work(config.retrieve_every)
    end

    {:ok, config}
  end

  def handle_info(:latest, config) do
    retrieve_latest_rates(config)
    schedule_work(config.retrieve_every)
    {:noreply, config}
  end

  def retrieve_latest_rates(%{callback_module: callback_module} = config) do
    case ExchangeRates.get_latest_rates(config) do
      {:ok, rates} ->
        retrieved_at = DateTime.utc_now
        store_rates(rates, retrieved_at)
        apply(callback_module, :rates_retrieved, [rates, retrieved_at])
        log(config, :success, "Retrieved exchange rates successfully")
        {:ok, rates}
      {:error, reason} ->
        log(config, :failure, "Could not retrieve exchange rates: #{inspect reason}")
        {:error, reason}
    end
  end

  defp schedule_work(delay_ms) do
    Process.send_after(self(), :latest, delay_ms)
  end

  defp initialize_ets_table do
    :ets.new(:exchange_rates, [:named_table, read_concurrency: true])
  end

  defp store_rates(rates, retrieved_at) do
    :ets.insert(:exchange_rates, {:rates, rates})
    :ets.insert(:exchange_rates, {:last_updated, retrieved_at})
  end

  def log(%{log_levels: log_levels}, key, message) do
    case Map.get(log_levels, key) do
      nil ->
        nil
      log_level ->
        Logger.log(log_level, message)
    end
  end

  defp log_init_message(delay, every) when delay < 1_000 do
    {every, plural_every} = seconds(every)

    "Rates will be retrieved in #{delay} milliseconds " <>
    "and then every #{every} #{plural_every}."
  end

  defp log_init_message(delay, every) do
    {delay, plural_delay} = seconds(delay)
    {every, plural_every} = seconds(every)

    "Rates will be retrieved in #{delay} #{plural_delay} " <>
    "and then every #{every} #{plural_every}."
  end

  defp log_init_message(every) do
    {every, plural_every} = seconds(every)
    "Rates will be retrieved every #{every} #{plural_every}."
  end

  defp seconds(milliseconds) do
    seconds = div(milliseconds, 1000)
    plural = if seconds == 1, do: "second", else: "seconds"
    {seconds, plural}
  end
end
