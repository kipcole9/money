defmodule Money.ExchangeRatesLite.Cache do
  @moduledoc """
  Specification of the exchange rates cache.
  """

  alias __MODULE__.Config

  @type name :: atom()
  @type key :: any()
  @type value :: any()
  @type reason :: any()

  @doc """
  Initializes the cache.
  """
  @callback init(Config.t()) :: :ok | {:error, reason()}

  @doc """
  Terminates the cache.
  """
  @callback terminate(Config.t()) :: :ok | {:error, reason()}

  @doc """
  Gets a value by key from cache.
  """
  @callback get(Config.t(), key()) :: value()

  @doc """
  Puts a key/value pair into cache.
  """
  @callback put(Config.t(), key(), value()) :: value()

  @doc false
  def init(%Config{} = config) do
    config.adapter.init(config)
  end

  @doc false
  def terminate(%Config{} = config) do
    config.adapter.terminate(config)
  end

  @doc false
  def get(%Config{} = config, key) do
    config.adapter.get(config, key)
  end

  @doc false
  def put(%Config{} = config, key, value) do
    config.adapter.put(config, key, value)
  end
end
