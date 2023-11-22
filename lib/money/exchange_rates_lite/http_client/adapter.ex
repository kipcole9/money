defmodule Money.ExchangeRatesLite.HttpClient.Adapter do
  @moduledoc """
  Specification of the HTTP client adapter.
  """

  alias Money.ExchangeRatesLite.HttpClient.Config

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts], unquote: true do
      @schema_options opts[:schema_options] || []

      @behaviour unquote(__MODULE__)

      def schema_options(), do: @schema_options
    end
  end

  @type url :: binary()
  @type header :: {binary(), binary()}
  @type headers :: [header()]
  @type body :: binary()
  @type reason :: any()

  @callback get(Config.t(), url(), headers()) ::
              {:ok, headers(), body()}
              | {:not_modified, headers()}
              | {:error, reason()}

  @callback schema_options() :: NimbleOptions.schema()
end
