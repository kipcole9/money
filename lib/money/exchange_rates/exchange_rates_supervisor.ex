defmodule Money.ExchangeRates.Supervisor do
  @moduledoc false

  use Supervisor
  alias Money.ExchangeRates

  @child_name ExchangeRates.Retriever

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: ExchangeRates.Supervisor)
  end

  def init(:ok) do
    supervise([retriever_spec()], strategy: :one_for_one)
  end

  def stop do
    Supervisor.stop(__MODULE__)
  end

  def start_retriever do
    Supervisor.restart_child(__MODULE__, @child_name)
  end

  def stop_retriever do
    Supervisor.terminate_child(__MODULE__, @child_name)
  end

  defp retriever_spec do
    worker(@child_name, [@child_name, ExchangeRates.config()])
  end

end
