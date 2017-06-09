defmodule Money.ExchangeRates.Retriever do
  @moduledoc """
  Implements a `GenServer` to retrieve exchange rates from
  a configured retrieveal module on a periodic basis.  By default exchange
  rates are retrieved from [Open Exchange Rates](http://openexchangerates.org).

  Retrieved data is stored in an `:ets` table.

  By default the period of execution is 5 minutes (360_000 microseconds). The
  period of retrieval is configured in `config.exs` or the appropriate
  environment configuration.  For example:

      config :ex_money,
        open_exchange_rates_app_id: "app_id_string",
        open_exchange_rates_retrieve_every: 360_000
  """

  use GenServer

  require Logger

  @default_retrieval_interval 360_000
  @default_callback_module Money.ExchangeRates.Callback

  defmodule Config do
    defstruct retrieve_every: nil,
              callback_module: nil,
              log_levels: %{}
  end

  def start_link(name) do
    state = %Config{
      retrieve_every: Money.get_env(:exchange_rates_retrieve_every, @default_retrieval_interval),
      callback_module: Money.get_env(:callback_module, @default_callback_module),
      log_levels: %{
        success: Money.get_env(:log_success, nil),
        info: Money.get_env(:log_info, :warn),
        failure: Money.get_env(:log_failure, :warn)
      }
    }

    GenServer.start_link(__MODULE__, state, name: name)
  end

   def init(state) do
     log(state, :info, "Starting exchange rate retrieval service")
     log(state, :info, "Rates will be retrieved every #{div(state.retrieve_every, 1000)} seconds.")

     initialize_ets_table()

     do_retrieve_rates(state)
     schedule_work(state.retrieve_every)

     {:ok, state}
   end

   def handle_info(:latest, state) do
     do_retrieve_rates(state)
     schedule_work(state.retrieve_every)
     {:noreply, state}
   end

  def do_retrieve_rates(%{callback_module: callback_module} = state) do
    case Money.ExchangeRates.get_latest_rates() do
      {:ok, rates} ->
        retrieved_at = DateTime.utc_now
        store_rates(rates, retrieved_at)
        apply(callback_module, :rates_retrieved, [rates, retrieved_at])
        log(state, :success, "Retrieved exchange rates successfully")
      {:error, reason} ->
        log(state, :failure, "Error retrieving exchange rates: #{inspect reason}")
    end
    state
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

  defp log(%{log_levels: log_levels}, key, message) do
    case Map.get(log_levels, key) do
      nil ->
        nil
      log_level ->
        Logger.log(log_level, message)
    end
  end

 end
