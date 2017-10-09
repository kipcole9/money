defmodule Money.Application do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = if start_exchange_rate_service?() do
      [supervisor(Money.ExchangeRates.Supervisor, [])]
    else
      []
    end

    opts = [strategy: :one_for_one, name: Money.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Default is to not start the exchange rate service
  defp start_exchange_rate_service? do
    Money.get_env(:exchange_rate_service, false)
  end

end