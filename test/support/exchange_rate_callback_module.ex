defmodule Money.ExchangeRates.CallbackTest do
  @behaviour Money.ExchangeRates.Callback

  def init do
  end

  def latest_rates_retrieved(_rates, _retrieved_at) do
    IO.puts("Latest Rates Retrieved")
    :ok
  end

  def historic_rates_retrieved(_rates, _date) do
    IO.puts("Historic Rates Retrieved")
    :ok
  end
end
