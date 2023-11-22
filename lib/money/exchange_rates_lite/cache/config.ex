defmodule Money.ExchangeRatesLite.Cache.Config do
  @enforce_keys [:name, :adapter]
  defstruct @enforce_keys

  @type options :: keyword()

  @type t :: %__MODULE__{
          name: atom(),
          adapter: atom()
        }

  @schema [
    name: [
      type: :atom,
      required: true
    ],
    adapter: [
      type: :atom,
      default: Money.ExchangeRatesLite.Cache.Ets
    ]
  ]

  @spec new!(options()) :: t()
  def new!(options) when is_list(options) do
    options
    |> NimbleOptions.validate!(@schema)
    |> as_struct()
  end

  defp as_struct(options) do
    struct(__MODULE__, options)
  end
end
