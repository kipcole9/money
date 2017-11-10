use Mix.Config

config :ex_money,
  exchange_rate_service: true,
  open_exchange_rates_app_id: {:system, "OPEN_EXCHANGE_RATES_APP_ID"},
  exchange_rates_retrieve_every: 300_000,
  callback_module: Money.ExchangeRates.Callback,
  log_failure: :warn,
  log_info: :info,
  log_success: :info

config :ex_cldr,
  locales: ["en", "root"]