defmodule Money.ExchangeRatesLite.Cache.Ets do
  @doc """
  Money.ExchangeRatesLite.Cache adapter for `:ets`.
  """

  alias Money.ExchangeRatesLite.Cache.Config

  @behaviour Money.ExchangeRatesLite.Cache

  @impl true
  def init(%Config{} = config) do
    if :ets.info(config.name) == :undefined do
      :ets.new(config.name, [
        :named_table,
        :public,
        read_concurrency: true
      ])
    end

    :ok
  end

  @impl true
  def terminate(%Config{} = _config) do
    :ok
  end

  @impl true
  def get(%Config{} = config, key) do
    case :ets.lookup(config.name, key) do
      [{^key, value}] -> value
      [] -> nil
    end
  end

  @impl true
  def put(%Config{} = config, key, value) do
    true = :ets.insert(config.name, {key, value})
    value
  end
end
