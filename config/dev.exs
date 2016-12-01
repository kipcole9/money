use Mix.Config

config :ex_money,
  open_exchange_rates_app_id: {:system, "OPEN_EXCHANGE_RATES_APP_ID"},
  open_exchange_rates_retrieve_every: 360_000,
  exchange_rate_service: true,
  callback_module: Money.ExchangeRates.Callback
