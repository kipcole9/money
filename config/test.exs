use Mix.Config

config :ex_money, Money.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "kip",
  database: "money_dev",
  hostname: "localhost",
  pool_size: 10

config :ex_money,
  ecto_repos: [Money.Repo]

config :ex_money,
  exchange_rate_service: false,
  open_exchange_rates_retrieve_every: 360_000,
  api_module: Money.ExchangeRates.Test,
  log_failure: :warn,
  callback_module: Money.ExchangeRates.CallbackTest
