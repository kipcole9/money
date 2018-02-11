use Mix.Config

config :ex_money, Money.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "kip",
  database: "money_dev",
  hostname: "localhost",
  pool_size: 10

config :ex_money, ecto_repos: [Money.Repo]

config :ex_money,
  exchange_rates_retrieve_every: :never,
  open_exchange_rates_app_id: {:system, "OPEN_EXCHANGE_RATES_APP_ID"},
  api_module: Money.ExchangeRates.Api.Test,
  log_failure: nil,
  log_info: nil

config :ex_cldr,
  default_locale: "en",
  locales: ["en", "root"]
