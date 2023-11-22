defmodule Money.ExchangeRatesLite do
  @moduledoc """
  Defines a module which retrieves exchange rates from exchange rate services.

  ## Usage

  When used, the module expects `:otp_app` as an option, the `:otp_app` should point to
  an OTP application that holds related configuration. For example:

      defmodule MyApp.ExchangeRates do
        use Money.ExchangeRatesLite, otp_app: :my_app
      end

  Could be configured with:

      config :my_app, MyApp.ExchangeRates,
        adapter: Money.ExchangeRatesLite.Adapter.OpenExchangeRates,
        adapter_options: [
          app_id: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
        ]

  Per module configuration is also supported:

      defmodule MyApp.ExchangeRates do
        use Money.ExchangeRatesLite,
          otp_app: :my_app,
          adapter: Money.ExchangeRatesLite.Adapter.OpenExchangeRates,
          adapter_options: [
            app_id: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
          ]
      end

  Then, you can call it like this:

      iex> MyApp.ExchangeRates.latest_rates()
      iex> MyApp.ExchangeRates.historic_rates(~D[2023-11-18])

  ## Options

  * `:otp` specifies the OTP application that holds related configuration.

  * `:adapter` specifies the module to retrieve exchange rates. This can be any module that
    implements the `Money.ExchangeRatesLite.Adapter` behaviour. The default is
    `Money.ExchangeRatesLite.Adapter.OpenExchangeRates`.

  * `:adapter_options` specifies the options of `:adapter`.

  * `:http_client_adapter` specifies the module to cache exchange rates. This can be any module
    that implements the `Money.ExchangeRatesLite.HttpClient.Adapter` behaviour. The default is
    `Money.ExchangeRatesLite.HttpClient.Adapter.CldrHttp`.

  * `:http_client_options` specifies the options of `:http_client_adapter`.

  """

  @schema_options [
    otp_app: [
      type: :atom,
      required: true
    ],
    adapter: [
      type: :atom,
      default: Money.ExchangeRatesLite.Adapter.OpenExchangeRates
    ],
    adapter_options: [
      type: :keyword_list,
      default: []
    ],
    http_client_adapter: [
      type: :atom,
      default: Money.ExchangeRatesLite.HttpClient.Adapter.CldrHttp
    ],
    http_client_options: [
      type: :keyword_list,
      default: []
    ]
  ]

  alias Money.ExchangeRatesLite.Config
  alias Money.ExchangeRatesLite.Adapter
  alias Money.ExchangeRatesLite.HttpClient.Config, as: HttpClientConfig

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      alias Money.ExchangeRatesLite

      @otp_app Keyword.fetch!(opts, :otp_app)
      @module_opts opts

      @spec latest_rates() :: Adapter.result()
      def latest_rates() do
        ExchangeRatesLite.latest_rates(config())
      end

      @spec historic_rates(Date.t()) :: Adapter.result()
      def historic_rates(%Date{} = date) do
        ExchangeRatesLite.historic_rates(config(), date)
      end

      @spec config() :: keyword()
      def config() do
        opts = ExchangeRatesLite.merge_opts(@otp_app, __MODULE__, @module_opts)
        ExchangeRatesLite.build_config(opts)
      end
    end
  end

  @doc """
  Gets the latest exchange rates.
  """
  @spec latest_rates(Config.t()) :: Adapter.result()
  def latest_rates(%Config{} = config) do
    config.adapter.get_latest_rates(config)
  end

  @doc """
  Gets the historic exchange rates.
  """
  @spec historic_rates(Config.t(), Date.t()) :: Adapter.result()
  def historic_rates(%Config{} = config, %Date{} = date) do
    config.adapter.get_historic_rates(config, date)
  end

  @doc false
  def merge_opts(otp_app, module, module_opts) do
    Application.get_env(otp_app, module, [])
    |> Keyword.merge(module_opts)
  end

  @doc false
  def build_config(opts) do
    validated_opts = NimbleOptions.validate!(opts, @schema_options)

    adapter = Keyword.fetch!(validated_opts, :adapter)
    adapter_options = Keyword.fetch!(validated_opts, :adapter_options)
    http_client_adapter = Keyword.fetch!(validated_opts, :http_client_adapter)
    http_client_options = Keyword.fetch!(validated_opts, :http_client_options)

    http_client_config =
      HttpClientConfig.new!(
        adapter: http_client_adapter,
        adapter_options: http_client_options
      )

    Config.new!(
      adapter: adapter,
      adapter_options: adapter_options,
      http_client_config: http_client_config
    )
  end
end
