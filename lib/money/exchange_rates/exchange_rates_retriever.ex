defmodule Money.ExchangeRates.Retriever do
  @moduledoc """
  Implements a `GenServer` to retrieve exchange rates from
  a configured retrieveal module on a periodic or on demand basis.

  By default exchange rates are retrieved from [Open Exchange Rates](http://openexchangerates.org).

  The default period of execution is 5 minutes (300_000 milliseconds). The
  period of retrieval is configured in `config.exs` or the appropriate
  environment configuration.  For example:

      config :ex_money,
        retrieve_every: 300_000

  """

  use GenServer
  require Logger

  @etag_cache :etag_cache

  @doc """
  Starts the exchange rates retrieval service
  """
  def start(config \\ Money.ExchangeRates.config()) do
    Money.ExchangeRates.Supervisor.start_retriever(config)
  end

  @doc """
  Stop the exchange rates retrieval service.

  The service can be restarted with `restart/0`.
  """
  def stop do
    Money.ExchangeRates.Supervisor.stop_retriever()
  end

  @doc """
  Restart the exchange rates retrieval service
  """
  def restart do
    Money.ExchangeRates.Supervisor.restart_retriever()
  end

  @doc """
  Delete the exchange rates retrieval service

  The service can be started again with `start/1`
  """
  def delete do
    Money.ExchangeRates.Supervisor.delete_retriever()
  end

  @doc false
  def start_link(name, config \\ Money.ExchangeRates.config()) do
    GenServer.start_link(__MODULE__, config, name: name)
  end

  @doc """
  Forces retrieval of the latest exchange rates

  Sends a message ot the exchange rate retrieval worker to request
  current rates be retrieved and stored.

  Returns:

  * `{:ok, rates}` if exchange rates request is successfully sent.

  * `{:error, reason}` if the request cannot be send.

  This function does not return exchange rates, for that see
  `Money.ExchangeRates.latest_rates/0` or
  `Money.ExchangeRates.historic_rates/1`.

  """
  def latest_rates() do
    case Process.whereis(__MODULE__) do
      nil -> {:error, exchange_rate_service_error()}
      _pid -> GenServer.call(__MODULE__, :latest_rates)
    end
  end

  @doc """
  Forces retrieval of historic exchange rates for a single date

  * `date` is a date returned by `Date.new/3` or any struct with the
    elements `:year`, `:month` and `:day` or

  * a `Date.Range.t` created by `Date.range/2` that specifies a
    range of dates to retrieve

  Returns:

  * `{:ok, rates}` if exchange rates request is successfully sent.

  * `{:error, reason}` if the request cannot be send.

  Sends a message ot the exchange rate retrieval worker to request
  historic rates for a specified date or range be retrieved and
  stored.

  This function does not return exchange rates, for that see
  `Money.ExchangeRates.latest_rates/0` or
  `Money.ExchangeRates.historic_rates/1`.

  """
  def historic_rates(%Date{calendar: Calendar.ISO} = date) do
    case Process.whereis(__MODULE__) do
      nil -> {:error, exchange_rate_service_error()}
      _pid -> GenServer.call(__MODULE__, {:historic_rates, date})
    end
  end

  def historic_rates(%{year: year, month: month, day: day}) do
    case Date.new(year, month, day) do
      {:ok, date} -> historic_rates(date)
      error -> error
    end
  end

  def historic_rates(%Date.Range{first: from, last: to}) do
    historic_rates(from, to)
  end

  @doc """
  Forces retrieval of historic exchange rates for a range of dates

  * `from` is a date returned by `Date.new/3` or any struct with the
    elements `:year`, `:month` and `:day`.

  * `to` is a date returned by `Date.new/3` or any struct with the
    elements `:year`, `:month` and `:day`.

  Returns:

  * `{:ok, rates}` if exchange rates request is successfully sent.

  * `{:error, reason}` if the request cannot be send.

  Sends a message to the exchange rate retrieval process for each
  date in the range `from`..`to` to request historic rates be
  retrieved.

  """
  def historic_rates(%Date{calendar: Calendar.ISO} = from, %Date{calendar: Calendar.ISO} = to) do
    case Process.whereis(__MODULE__) do
      nil ->
        {:error, exchange_rate_service_error()}

      _pid ->
        for date <- Date.range(from, to) do
          historic_rates(date)
        end
    end
  end

  def historic_rates(%{year: y1, month: m1, day: d1}, %{year: y2, month: m2, day: d2}) do
    with {:ok, from} <- Date.new(y1, m1, d1),
         {:ok, to} <- Date.new(y2, m2, d2) do
      historic_rates(from, to)
    end
  end

  @doc """
  Updated the configuration for the Exchange Rate
  Service

  """
  def reconfigure(%Money.ExchangeRates.Config{} = config) do
    GenServer.call(__MODULE__, {:reconfigure, config})
  end

  @doc """
  Return the current configuration of the Exchange Rates
  Retrieval service

  """
  def config do
    GenServer.call(__MODULE__, :config)
  end

  @doc """
  Retrieve exchange rates from an external HTTP
  service.

  This function is primarily intended for use by
  an exchange rates api module.
  """
  def retrieve_rates(url, config) when is_binary(url) do
    url
    |> String.to_charlist()
    |> retrieve_rates(config)
  end

  def retrieve_rates(url, config) when is_list(url) do
    headers = if_none_match_header(url)

    :httpc.request(:get, {url, headers}, https_opts(config, url), [])
    |> process_response(url, config)
  end

  defp process_response({:ok, {{_version, 200, 'OK'}, headers, body}}, url, config) do
    rates = config.api_module.decode_rates(body)
    cache_etag(headers, url)
    {:ok, rates}
  end

  defp process_response({:ok, {{_version, 304, 'Not Modified'}, headers, _body}}, url, _config) do
    cache_etag(headers, url)
    {:ok, :not_modified}
  end

  defp process_response({_, {{_version, code, message}, _headers, _body}}, _url, _config) do
    {:error, {Money.ExchangeRateError, "#{code} #{message}"}}
  end

  defp process_response({:error, {:failed_connect, [{_, {_host, _port}}, {_, _, sys_message}]}}, url, _config) do
    {:error, {Money.ExchangeRateError, "Failed to connect to #{url}: #{inspect sys_message}"}}
  end

  defp process_response({:error, {:tls_alert, {:certificate_expired, _message}}}, url, _config) do
    {:error, {Money.ExchangeRateError, "Certificate for #{inspect(url)} has expired"}}
  end

  defp if_none_match_header(url) do
    case get_etag(url) do
      {etag, date} ->
        [
          {'If-None-Match', etag},
          {'If-Modified-Since', date}
        ]

      _ ->
        []
    end
  end

  defp cache_etag(headers, url) do
    etag = :proplists.get_value('etag', headers)
    date = :proplists.get_value('date', headers)

    if etag?(etag, date) do
      :ets.insert(@etag_cache, {url, {etag, date}})
    else
      :ets.delete(@etag_cache, url)
    end
  end

  defp get_etag(url) do
    case :ets.lookup(@etag_cache, url) do
      [{^url, cached_value}] -> cached_value
      [] -> nil
    end
  end

  defp etag?(etag, date) do
    etag != :undefined && date != :undefined
  end

  #
  # Server implementation
  #

  @doc false
  def init(config) do
    :erlang.process_flag(:trap_exit, true)
    config.cache_module.init()

    if is_integer(config.retrieve_every) do
      log(config, :info, log_init_message(config.retrieve_every))
      schedule_work(0)
      schedule_work(config.retrieve_every)
    end

    if config.preload_historic_rates do
      log(config, :info, "Preloading historic rates for #{inspect(config.preload_historic_rates)}")
      schedule_work(config.preload_historic_rates, config.cache_module)
    end

    if :ets.info(@etag_cache) == :undefined do
      :ets.new(@etag_cache, [:named_table, :public])
    end

    {:ok, config}
  end

  @doc false
  def terminate(:normal, config) do
    config.cache_module.terminate()
  end

  @doc false
  def terminate(:shutdown, config) do
    config.cache_module.terminate()
  end

  @doc false
  def terminate(other, _config) do
    Logger.error("[ExchangeRates.Retriever] Terminate called with unhandled #{inspect(other)}")
  end

  @doc false
  def handle_call(:latest_rates, _from, config) do
    {:reply, retrieve_latest_rates(config), config}
  end

  @doc false
  def handle_call({:historic_rates, date}, _from, config) do
    {:reply, retrieve_historic_rates(date, config), config}
  end

  @doc false
  def handle_call({:reconfigure, new_configuration}, _from, config) do
    config.cache_module.terminate()
    {:ok, new_config} = init(new_configuration)
    {:reply, new_config, new_config}
  end

  @doc false
  def handle_call(:config, _from, config) do
    {:reply, config, config}
  end

  @doc false
  def handle_call(:stop, _from, config) do
    {:stop, :normal, :ok, config}
  end

  @doc false
  def handle_call({:stop, reason}, _from, config) do
    {:stop, reason, :ok, config}
  end

  @doc false
  def handle_info(:latest_rates, config) do
    retrieve_latest_rates(config)
    schedule_work(config.retrieve_every)
    {:noreply, config}
  end

  @doc false
  def handle_info({:historic_rates, %Date{calendar: Calendar.ISO} = date}, config) do
    retrieve_historic_rates(date, config)
    {:noreply, config}
  end

  @doc false
  def handle_info(:stop, config) do
    {:stop, :normal, config}
  end

  @doc false
  def handle_info({:stop, reason}, config) do
    {:stop, reason, config}
  end

  @doc false
  def handle_info(message, config) do
    Logger.error("Invalid message for ExchangeRates.Retriever: #{inspect(message)}")
    {:noreply, config}
  end

  defp retrieve_latest_rates(%{callback_module: callback_module} = config) do
    case config.api_module.get_latest_rates(config) do
      {:ok, :not_modified} ->
        log(config, :success, "Retrieved latest exchange rates successfully. Rates unchanged.")
        {:ok, config.cache_module.latest_rates()}

      {:ok, rates} ->
        retrieved_at = DateTime.utc_now()
        config.cache_module.store_latest_rates(rates, retrieved_at)
        apply(callback_module, :latest_rates_retrieved, [rates, retrieved_at])
        log(config, :success, "Retrieved latest exchange rates successfully")
        {:ok, rates}

      {:error, reason} ->
        log(config, :failure, "Could not retrieve latest exchange rates: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp retrieve_historic_rates(date, %{callback_module: callback_module} = config) do
    case config.api_module.get_historic_rates(date, config) do
      {:ok, :not_modified} ->
        log(config, :success, "Historic exchange rates for #{Date.to_string(date)} are unchanged")
        {:ok, config.cache_module.historic_rates(date)}

      {:ok, rates} ->
        config.cache_module.store_historic_rates(rates, date)
        apply(callback_module, :historic_rates_retrieved, [rates, date])

        log(
          config,
          :success,
          "Retrieved historic exchange rates for #{Date.to_string(date)} successfully"
        )

        {:ok, rates}

      {:error, reason} ->
        log(
          config,
          :failure,
          "Could not retrieve historic exchange rates " <>
            "for #{Date.to_string(date)}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp schedule_work(delay_ms) when is_integer(delay_ms) do
    Process.send_after(self(), :latest_rates, delay_ms)
  end

  defp schedule_work(%Date.Range{} = date_range, cache_module) do
    for date <- date_range do
      schedule_work(date, cache_module)
    end
  end

  # Don't retrieve historic rates if they are
  # already cached.  Note that this is only
  # called at retriever initialization, not
  # through the public api.
  #
  # This depends on:
  # 1. The cache is persistent, like Cache.Dets
  # 2. The assumption that historic rates don't change
  # A persistent cache will reduce the number of
  # external API calls and it means the cache
  # will survive restarts both intentional and
  # unintentional
  defp schedule_work(%Date{calendar: Calendar.ISO} = date, cache_module) do
    case cache_module.historic_rates(date) do
      {:ok, _rates} ->
        :ok

      {:error, _} ->
        Process.send(self(), {:historic_rates, date}, [])
    end
  end

  defp schedule_work({%Date{} = from, %Date{} = to}, cache_module) do
    schedule_work(Date.range(from, to), cache_module)
  end

  defp schedule_work(date_string, cache_module) when is_binary(date_string) do
    parts = String.split(date_string, "..")

    case parts do
      [date] -> schedule_work(Date.from_iso8601(date), cache_module)
      [from, to] -> schedule_work({Date.from_iso8601(from), Date.from_iso8601(to)}, cache_module)
    end
  end

  # Any non-numeric value, or non-date value means
  # we don't schedule work - ie there is no periodic
  # retrieval
  defp schedule_work(_, _cache_module) do
    :ok
  end

  @doc false
  def log(%{log_levels: log_levels}, key, message) do
    case Map.get(log_levels, key) do
      nil ->
        nil

      log_level ->
        Logger.log(log_level, message)
    end
  end

  defp log_init_message(every) do
    {every, plural_every} = seconds(every)

    "Exchange Rates will be retrieved now and then every #{every} #{plural_every}."
  end

  defp seconds(milliseconds) do
    seconds = div(milliseconds, 1000)
    plural = if seconds == 1, do: "second", else: "seconds"
    {seconds, plural}
  end

  defp exchange_rate_service_error do
    {Money.ExchangeRateError, "Exchange rate service does not appear to be running"}
  end

  #### Certificate verification

  @certificate_locations [
    # Configured cacertfile
    Application.get_env(Cldr.Config.app_name(), :cacertfile),

    # Populated if hex package CAStore is configured
    if(Code.ensure_loaded?(CAStore), do: CAStore.file_path()),

    # Populated if hex package certfi is configured
    if(Code.ensure_loaded?(:certifi),
      do: :certifi.cacertfile() |> List.to_string()
    ),

    # Debian/Ubuntu/Gentoo etc.
    "/etc/ssl/certs/ca-certificates.crt",

    # Fedora/RHEL 6
    "/etc/pki/tls/certs/ca-bundle.crt",

    # OpenSUSE
    "/etc/ssl/ca-bundle.pem",

    # OpenELEC
    "/etc/pki/tls/cacert.pem",

    # CentOS/RHEL 7
    "/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem",

    # Open SSL on MacOS
    "/usr/local/etc/openssl/cert.pem",

    # MacOS, OpenBSD & Alpine Linux
    "/etc/ssl/cert.pem"
  ]
  |> Enum.reject(&is_nil/1)

  @doc """
  Returns the certificate store to be used when
  retrieving exchange rates.

  """
  def certificate_store do
    @certificate_locations
    |> Enum.find(&File.exists?/1)
    |> raise_if_no_cacertfile
    |> :erlang.binary_to_list()
  end

  defp raise_if_no_cacertfile(nil) do
    raise RuntimeError, """
    No certificate trust store was found.
    Tried looking for: #{inspect(@certificate_locations)}

    A certificate trust store is required in
    order to download locales for your configuration.

    Since ex_cldr could not detect a system
    installed certificate trust store one of the
    following actions may be taken:

    1. Install the hex package `castore`. It will
       be automatically detected after recompilation.

    2. Install the hex package `certifi`. It will
       be automatically detected after recomilation.

    3. Specify the location of a certificate trust store
       by configuring it in `config.exs`:

       config :ex_cldr,
         cacertfile: "/path/to/cacertfile",
         ...

    """
  end

  defp raise_if_no_cacertfile(file) do
    file
  end

  # See https://erlef.github.io/security-wg/secure_coding_and_deployment_hardening/ssl.html

  @otp_version :otp_release |> :erlang.system_info() |> List.to_integer

  if @otp_version > 21 do
    defp https_opts(%Money.ExchangeRates.Config{verify_peer: true}, _url) do
      [
        ssl: [
          verify: :verify_peer,
          cacertfile: certificate_store(),
          depth: 99,
          log_level: :alert,
          log_alert: true,
          customize_hostname_check: [
            match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
          ]
        ]
      ]
    end
  else
    defp https_opts(%Money.ExchangeRates.Config{verify_peer: true}, _url) do
      host = url |> :uri_string.parse() |> Map.fetch!(:host)

      [
        ssl: [
          verify: :verify_peer,
          verify_fun: {&:ssl_verify_hostname.verify_fun/3, check_hostname: host},
          cacertfile: certificate_store(),
          server_name_indication: host,
          reuse_sessions: false,
          depth: 99
        ]
      ]
    end
  end

  defp https_opts(%Money.ExchangeRates.Config{verify_peer: false}, _url) do
    []
  end

end
