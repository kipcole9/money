defmodule Money.ExchangeRates.Callback do
  @moduledoc """
  Default exchange rates retrieval callback module.

  When exchange rates are successfully retrieved, the function
  `rates_retrieved/2` is called to perform any desired serialization or
  proocessing.
  """

  @doc """
  Defines the behaviour to retrieve exchange rates from an external
  data source.
  """
  @callback rates_retrieved(%{}, %DateTime{}) :: :ok

  @doc """
  Callback function invoked when exchange rates are retrieved.
  """
  @spec rates_retrieved(%{}, %DateTime{}) :: :ok
  def rates_retrieved(_rates, _retrieved_at) do
    :ok
  end
end