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
  exchange_rates_retrieve_every: 300_000,
  open_exchange_rates_app_id: {:system, "OPEN_EXCHANGE_RATES_APP_ID"},
  api_module: Money.ExchangeRates.Test,
  log_failure: :warn,
  log_info: nil,
  callback_module: Money.ExchangeRates.CallbackTest,
  delay_before_first_retrieval: 5

config :ex_cldr,
  default_locale: "en",
  locales: ["en", "root"]


