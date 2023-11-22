defmodule Money.ExchangeRatesLite.Cache.Dets do
  @doc """
  Money.ExchangeRatesLite.Cache adapter for `:dets`.
  """

  alias Money.ExchangeRatesLite.Cache.Config

  @behaviour Money.ExchangeRatesLite.Cache

  @impl true
  def init(%Config{} = config) do
    file = file_path(config.name)
    :ok = ensure_parent_dir(file)
    {:ok, _name} = :dets.open_file(config.name, file: file)

    :ok
  end

  @impl true
  def terminate(%Config{} = config) do
    :dets.close(file_path(config.name))
  end

  @impl true
  def get(%Config{} = config, key) do
    case :dets.lookup(config.name, key) do
      [{^key, value}] -> value
      [] -> nil
    end
  end

  @impl true
  def put(%Config{} = config, key, value) do
    :dets.insert(config.name, {key, value})
    value
  end

  @doc false
  def file_path(name) do
    Path.join([:code.priv_dir(:ex_money), "exchange_rates_cache", Macro.to_string(name)])
    |> String.to_charlist()
  end

  defp ensure_parent_dir(file) do
    file
    |> Path.dirname()
    |> File.mkdir_p()
  end
end
