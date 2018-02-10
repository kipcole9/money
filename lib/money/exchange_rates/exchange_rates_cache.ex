defmodule Money.ExchangeRates.Cache do
  require Logger

  @ets_table :exchange_rates
  @cache Application.get_env(:ex_money, :exchange_rates_cache, :ets)
  @dets_path Path.join(:code.priv_dir(:ex_money), ".exchange_rates")
             |> String.to_charlist()

  def init do
    do_init(@cache)
  end

  defp do_init(:ets) do
    if :ets.info(@ets_table) == :undefined do
      :ets.new(@ets_table, [
        :named_table,
        :public,
        read_concurrency: true
      ])
    else
      @ets_table
    end
  end

  defp do_init(:dets) do
    {:ok, name} = :dets.open_file(@ets_table, file: @dets_path)
    name
  end

  defp do_init(other) do
    raise ArgumentError,
          "ex_money configuration key :cache #{inspect(other)} is invalid. " <>
            " It must be either :ets or :dets.  The default is :ets."
  end

  def shutdown do
    :dets.close(@ets_table)
  end

  def latest_rates do
    case get(:latest_rates) do
      nil ->
        {:error, {Money.ExchangeRateError, "No exchange rates were found"}}

      rates ->
        rates
    end
  end

  def historic_rates(%Date{calendar: Calendar.ISO} = date) do
    case get(date) do
      nil ->
        {:error,
         {Money.ExchangeRateError, "No exchange rates for #{Date.to_string(date)} were found"}}

      rates ->
        rates
    end
  end

  def historic_rates(%{year: year, month: month, day: day}) do
    {:ok, date} = Date.new(year, month, day)
    historic_rates(date)
  end

  def last_updated do
    case get(:last_updated) do
      nil ->
        Logger.error("Argument error getting last updated timestamp from ETS table")
        {:error, {Money.ExchangeRateError, "Last updated date is not known"}}

      last_updated ->
        last_updated
    end
  end

  def store_latest_rates(rates, retrieved_at) do
    put(:latest_rates, rates)
    put(:last_updated, retrieved_at)
  rescue
    ArgumentError ->
      Logger.error("Failed to store latest rates")
  end

  def store_historic_rates(rates, date) do
    put(date, rates)
  end

  def get(key) do
    case @cache.lookup(@ets_table, key) do
      [{^key, value}] -> value
      [] -> nil
    end
  end

  def put(key, value) do
    @cache.insert(@ets_table, {key, value})
  end
end
