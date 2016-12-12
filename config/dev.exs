use Mix.Config

config :ex_money,
  open_exchange_rates_app_id: {:system, "OPEN_EXCHANGE_RATES_APP_ID"},
  open_exchange_rates_retrieve_every: 300_000,
  exchange_rate_service: true,
  log_failure: :warn,
  log_info: :info,
  log_success: :info,
  callback_module: Money.ExchangeRates.Callback

config :ex_cldr,
  locales: ["en", "root"]
