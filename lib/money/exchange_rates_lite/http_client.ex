defmodule Money.ExchangeRatesLite.HttpClient do
  @moduledoc """
  Specification of the HTTP client.

  This HTTP client is Etag-sensitive, which means it will cache and use the Etag
  related headers automatically.
  """

  alias __MODULE__.Config

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
  @type result ::
          {:ok, body()}
          | {:ok, :not_modified}
          | {:error, {module(), reason()}}

  @callback get(Config.t(), url(), headers()) ::
              {:ok, headers(), body()}
              | {:not_modified, headers()}
              | {:error, reason()}

  @doc false
  def init(%Config{} = config) do
    table = etag_cache_table(config)

    if :ets.info(table) == :undefined do
      :ets.new(table, [:named_table, :public])
    end

    :ok
  end

  @doc false
  def terminate(%Config{} = _config) do
    :ok
  end

  @doc false
  @spec get(Config.t(), url(), headers()) :: result()
  def get(%Config{} = config, url, headers \\ []) do
    headers = build_headers(config, url, headers)

    config
    |> config.adapter.get(url, headers)
    |> handle_response(config, url)
  end

  defp build_headers(config, url, headers) do
    case get_etag(config, url) do
      {etag, date} ->
        [
          {"If-None-Match", etag},
          {"If-Modified-Since", date}
          | headers
        ]

      _ ->
        headers
    end
  end

  defp handle_response({:ok, headers, body}, config, url) do
    record_etag(config, url, headers)
    {:ok, body}
  end

  defp handle_response({:not_modified, headers}, config, url) do
    record_etag(config, url, headers)
    {:ok, :not_modified}
  end

  defp handle_response({:error, reason}, _config, _url) do
    {:error, {__MODULE__, "#{inspect(reason)}"}}
  end

  defp get_etag(config, url) do
    table = etag_cache_table(config)

    case :ets.lookup(table, url) do
      [{^url, value}] -> value
      [] -> nil
    end
  end

  defp record_etag(config, url, headers) do
    table = etag_cache_table(config)

    etag = :proplists.get_value("etag", headers)
    date = :proplists.get_value("date", headers)

    if valid_etag?(etag, date) do
      :ets.insert(table, {url, {etag, date}})
    else
      :ets.delete(table, url)
    end
  end

  defp etag_cache_table(%Config{} = config) do
    Module.concat(config.name, "ETag")
  end

  defp valid_etag?(etag, date) do
    etag != :undefined && date != :undefined
  end
end
