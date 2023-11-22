defmodule Money.ExchangeRatesLite.HttpClient.Config do
  @enforce_keys [:adapter, :adapter_options]
  defstruct @enforce_keys

  @type options :: keyword()

  @type t :: %__MODULE__{
          adapter: module(),
          adapter_options: keyword()
        }

  @schema_main_options [
    adapter: [
      type: :atom,
      default: Money.ExchangeRatesLite.HttpClient.Adapter.CldrHttp
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
