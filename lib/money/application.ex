defmodule Money.Application do
  use Application
  alias Money.ExchangeRates
  require Logger

  @auto_start :auto_start_exchange_rate_service

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [supervisor(Money.ExchangeRates.Supervisor, [])]

    opts = [strategy: :one_for_one, name: Money.Supervisor]
    supervisor = Supervisor.start_link(children, opts)

    if start_exchange_rate_service?() do
      ExchangeRates.Supervisor.start_retriever()
    end

    supervisor
  end

  # Default is to not start the exchange rate service
  defp start_exchange_rate_service? do
    maybe_log_deprecation()

    start? = Money.get_env(@auto_start, true, :boolean)
    api_module = ExchangeRates.default_config().api_module
    api_module_present? = Code.ensure_loaded?(api_module)

    if !api_module_present? do
      Logger.error(
        "[ex_money] ExchangeRates api module #{api_module_name(api_module)} could not be loaded. " <>
          "  Does it exist?"
      )

      Logger.warn("ExchangeRates service will not be started.")
    end

    start? && api_module_present?
  end

  defp api_module_name(name) when is_atom(name) do
    name
    |> Atom.to_string()
    |> String.replace_leading("Elixir.", "")
  end

  @doc false
  def maybe_log_deprecation do
    case Application.fetch_env(:ex_money, :delay_before_first_retrieval) do
      {:ok, _} ->
        Logger.warn(
          "[ex_money] Configuration option :delay_before_first_retrieval is deprecated. " <>
            "Please remove it from your configuration."
        )

        Application.delete_env(:ex_money, :delay_before_first_retrieval)

      :error ->
        nil
    end

    case Application.fetch_env(:ex_money, :exchange_rate_service) do
      {:ok, start?} ->
        Logger.warn(
          "[ex_money] Configuration option :exchange_rate_service is deprecated " <>
            "in favour of :auto_start_exchange_rate_service.  Please " <>
            "update your configuration."
        )

        Application.put_env(:ex_money, :auto_start_exchange_rate_service, start?)
        Application.delete_env(:ex_money, :exchange_rate_service)

      :error ->
        nil
    end
  end
end
