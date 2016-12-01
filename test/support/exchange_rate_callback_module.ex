defmodule Money.ExchangeRates.CallbackTest do
  @behaviour Money.ExchangeRates.Callback

  def rates_retrieved(_rates, _retrieved_at) do
    IO.puts "Rates Retrieved"
    :ok
  end
end
