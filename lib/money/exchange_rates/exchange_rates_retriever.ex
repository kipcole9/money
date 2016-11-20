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
  @retrieve_every Money.get_env(:open_exchange_rates_retrieve_every, 360_000)

   def start_link(name) do
     GenServer.start_link(__MODULE__, [], name: name)
   end

   def init([]) do
     initialize_ets_table()
     do_retrieve_rates()
     schedule_work()
     {:ok, []}
   end

   def handle_info(:latest, _state) do
     state = do_retrieve_rates()
     schedule_work()
     {:noreply, state}
   end

   defp do_retrieve_rates do
     case Money.ExchangeRates.get_latest_rates() do
       {:ok, rates} ->
         :ets.insert(:exchange_rates, {:rates, rates})
         :ets.insert(:exchange_rates, {:last_updated, DateTime.utc_now})
         log(:success, "#{__MODULE__}: Retrieved exchange rates successfully")
       {:error, reason} ->
         log(:failure, "#{__MODULE__}: Error retrieving rates from Open Exchange Rates: #{inspect reason}")
     end
   end

   defp schedule_work do
     Process.send_after(self(), :latest, @retrieve_every)
   end

   defp initialize_ets_table do
     :ets.new(:exchange_rates, [:named_table, read_concurrency: true])
   end

   defp log(:success, message) do
     require Logger

     if level = Application.get_env(:ex_money, :log_success, nil) do
       Logger.log(level, message)
     end
   end

   defp log(:failure, message) do
     require Logger

     if level = Application.get_env(:ex_money, :log_failure, :warn) do
       Logger.log(level, message)
     end
   end
 end