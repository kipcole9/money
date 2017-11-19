defmodule Money.ExchangeRatesTestHelper do
  alias Money.ExchangeRates
  def start_service do
    ExchangeRates.Retriever.start_link(ExchangeRates.Retriever, ExchangeRates.config)
  end
end