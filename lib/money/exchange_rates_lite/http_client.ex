defmodule Money.ExchangeRatesLite.HttpClient do
  @moduledoc """
  A multi-adapter，ETag-sensitive HTTP client.
  """

  alias __MODULE__.Config

  @ets_cache_table __MODULE__.ETag

  @type url :: binary()
  @type header :: {binary(), binary()}
  @type headers :: [header()]
  @type body :: binary()
  @type reason :: any()
  @type result ::
          {:ok, body()}
          | {:ok, :not_modified}
          | {:error, {module(), reason()}}

  @doc false
  @spec get(Config.t(), url(), headers()) :: result()
  def get(%Config{} = config, url, headers \\ []) do
    headers = build_headers(url, headers)

    config
    |> config.adapter.get(url, headers)
    |> handle_response(url)
  end

  defp build_headers(url, headers) do
    case get_etag(url) do
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

  defp handle_response({:ok, headers, body}, url) do
    put_etag(url, headers)
    {:ok, body}
  end

  defp handle_response({:not_modified, headers}, url) do
    put_etag(url, headers)
    {:ok, :not_modified}
  end

  defp handle_response({:error, reason}, _url) do
    {:error, {__MODULE__, "#{inspect(reason)}"}}
  end

  defp ensure_cache_table() do
    if :ets.info(@ets_cache_table) == :undefined do
      :ets.new(@ets_cache_table, [:named_table, :public])
    end

    :ok
  end

  defp get_etag(url) do
    ensure_cache_table()

    case :ets.lookup(@ets_cache_table, url) do
      [{^url, value}] -> value
      [] -> nil
    end
  end

  defp put_etag(url, headers) do
    ensure_cache_table()

    etag = :proplists.get_value("etag", headers)
    date = :proplists.get_value("date", headers)

    if valid_etag?(etag, date) do
      :ets.insert(@ets_cache_table, {url, {etag, date}})
    else
      :ets.delete(@ets_cache_table, url)
    end
  end

  defp valid_etag?(etag, date) do
    etag != :undefined && date != :undefined
  end
end
