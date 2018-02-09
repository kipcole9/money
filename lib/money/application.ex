defmodule Money.Application do
  use Application
  alias Money.ExchangeRates
  require Logger

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children =
      if start_exchange_rate_service?() do
        [supervisor(Money.ExchangeRates.Supervisor, [])]
      else
        []
      end

    opts = [strategy: :one_for_one, name: Money.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Default is to not start the exchange rate service
  defp start_exchange_rate_service? do
    maybe_log_deprecation()

    api_module = ExchangeRates.default_config().api_module
    api_module_present? = Code.ensure_loaded?(api_module)

    if !api_module_present? do
      Logger.error(
        "ExchangeRates api module #{api_module_name(api_module)} could not be loaded. " <>
          "  Does it exist?"
      )

      Logger.warn("ExchangeRates service will not be started.")
    end

    api_module_present?
  end

  defp api_module_name(name) when is_atom(name) do
    name
    |> Atom.to_string()
    |> String.replace_leading("Elixir.", "")
  end

  defp api_module_name(name) do
    name
  end

  @doc false
  def maybe_log_deprecation do
    case Application.fetch_env(:ex_money, :delay_before_first_retrieval) do
      {:ok, _} ->
        Logger.warn(
          "Configuration option :delay_before_first_retrieval is deprecated. " <>
          "Please remove it from your configuration."
        )

        Application.delete_env(:ex_money, :delay_before_first_retrieval)

      :error ->
        nil
    end

    case Application.fetch_env(:ex_money, :auto_start_exchange_rate_service) do
      {:ok, _} ->
        Logger.warn(
          "Configuration option :auto_start_exchange_rate_service is deprecated. " <>
          "Please remove it from your configuration. " <>
          "Use the :exchange_rates_retrieve_every option instead to define a retrieval period. "
        )

        Application.delete_env(:ex_money, :auto_start_exchange_rate_service)

      :error ->
        nil
    end

    case Application.fetch_env(:ex_money, :exchange_rate_service) do
      {:ok, _} ->
        Logger.warn(
          "Configuration option :exchange_rate_service is deprecated. " <>
          "Please remove it from your configuration. " <>
          "Use the :exchange_rates_retrieve_every option instead to define a retrieval period. "
        )

        Application.delete_env(:ex_money, :exchange_rate_service)

      :error ->
        nil
    end
  end
end
