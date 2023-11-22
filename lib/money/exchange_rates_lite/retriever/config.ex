defmodule Money.ExchangeRatesLite.Retriever.Config do
  alias Money.ExchangeRatesLite.HttpClient.Config, as: HttpClientConfig

  @enforce_keys [:name, :adapter, :adapter_options, :http_client_config]
  defstruct @enforce_keys

  @type options :: keyword()
  @type t :: %__MODULE__{
          name: atom(),
          adapter: module(),
          adapter_options: keyword(),
          http_client_config: HttpClientConfig.t()
        }

  @schema_main_options [
    name: [
      type: :atom,
      required: true
    ],
    adapter: [
      type: :atom,
      default: Money.ExchangeRatesLite.Retriever.OpenExchangeRates
    ],
    http_client_config: [
      type: {:struct, HttpClientConfig},
      required: true
    ]
  ]

  @spec new!(options()) :: t()
  def new!(options) when is_list(options) do
    {adapter_options, main_options} = Keyword.pop(options, :adapter_options, [])

    main_options = NimbleOptions.validate!(main_options, @schema_main_options)
    adapter = Keyword.fetch!(main_options, :adapter)

    schema_adapter_options = adapter.schema_options()
    adapter_options = NimbleOptions.validate!(adapter_options, schema_adapter_options)

    as_struct([{:adapter_options, adapter_options} | main_options])
  end

  defp as_struct(options) do
    struct(__MODULE__, options)
  end
end
