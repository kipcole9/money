defmodule Money.ExchangeRates.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: Money.ExchangeRates.Supervisor)
  end

  def init(:ok) do
    children = [
      worker(Money.ExchangeRates.Retriever, [Money.ExchangeRates.Retriever])
    ]

    supervise(children, strategy: :one_for_one)
  end
end