defmodule Money.ExchangeRates.Supervisor do
  @moduledoc """
  Functions to manage the starting, stopping,
  deleting and restarting of the Exchange
  Rates Retriever.
  """

  use Supervisor
  alias Money.ExchangeRates

  @child_name ExchangeRates.Retriever

  @doc false
  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: ExchangeRates.Supervisor)
  end

  @doc false
  def init(:ok) do
    Supervisor.init([], strategy: :one_for_one)
  end

  @doc """
  Returns a boolean indicating of the
  retriever process is configured and
  running
  """
  def retriever_running? do
    !!Process.whereis(@child_name)
  end

  @doc """
  Returns the status of the exchange rates
  retriever.  The returned value is one of:

  * `:running` if the service is running. In this
    state the valid action is `Money.ExchangeRates.Service.stop/0`
  * `:stopped` if it is stopped. In this state
    the valid actions are `Money.ExchangeRates.restart/0`
    or `Money.ExchangeRates.delete/0`
  * `:not_started` if it is not configured
    in the supervisor and is not running.  In
    this state the only valid action is
    `Money.ExchangeRates.Supervisor.start_retriever/1`

  """
  def retriever_status do
    cond do
      !!Process.whereis(@child_name) -> :running
      configured?(@child_name) -> :stopped
      true -> :not_started
    end
  end

  defp configured?(child) do
    Money.ExchangeRates.Supervisor
    |> Supervisor.which_children()
    |> Enum.any?(fn {name, _pid, _type, _args} -> name == child end)
  end

  @doc """
  Starts the exchange rates retriever

  ## Arguments

  * `config` is a `%Money.ExchangeRages.Config{}`
    struct returned by `Money.ExchangeRates.config/0`
    and adjusted as required.  The default is
    `Money.ExchangeRates.config/0`

  """
  def start_retriever(config \\ ExchangeRates.config()) do
    Supervisor.start_child(__MODULE__, retriever_spec(config))
  end

  @doc """
  Stop the exchange rates retriever.
  """
  def stop_retriever do
    Supervisor.terminate_child(__MODULE__, @child_name)
  end

  @doc """
  Restarts a stopped retriever.

  See also `Money.ExchangeRates.Retriever.stop/0`
  """
  def restart_retriever do
    Supervisor.restart_child(__MODULE__, @child_name)
  end

  @doc """
  Deleted the retriever child specification from
  the exchange rates supervisor.

  This is primarily of use if you want to change
  the configuration of the retriever after it is
  stopped and before it is restarted.

  In this situation the sequence of calls would be:

  ```
  iex> Money.ExchangeRates.Retriever.stop
  iex> Money.ExchangeRates.Retriever.delete
  iex> Money.ExchangeRates.Retriever.start(config)
  ```

  """
  def delete_retriever do
    Supervisor.delete_child(__MODULE__, @child_name)
  end

  defp retriever_spec(config) do
    %{id: @child_name, start: {@child_name, :start_link, [@child_name, config]}}
  end

end
