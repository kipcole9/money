defmodule Money.ExchangeRatesLite do
  @moduledoc """
  A GenServer for retrieving exchange rates.

  ## Basic Usage

  Before running a `Money.ExchangeRatesLite` instance, you should provide configuration. Put some
  base configuration within config file:

      config :my_app, Money.ExchangeRatesLite,
        name: MyApp.ExchangeRates,
        retriever_adapter: Money.ExchangeRatesLite.Retriever.OpenExchangeRates,
        retriever_options: [
          app_id: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
        ],
        cache_adapter: Money.ExchangeRatesLite.Cache.Ets,
        retrieve_every: 300_000

  A `Money.ExchangeRatesLite` instance is a `GenServer` and should be included in a supervision
  tree. The easiest way to do that is to add it to your application's supervisor directly:

      # lib/my_app/application.ex
      def start(_type, _args) do
        children = [
          # ...
          {Money.ExchangeRatesLite, Application.fetch_env!(:my_app, Money.ExchangeRatesLite)}
          # ...
        ]

        Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
      end

  Then, you can call it like this:

      iex> Money.ExchangeRatesLite.last_updated(MyApp.ExchangeRates)
      iex> Money.ExchangeRatesLite.latest_rates(MyApp.ExchangeRates)
      iex> Money.ExchangeRatesLite.historic_rates(MyApp.ExchangeRates, ~D[2023-11-18])

  If you think above calls are too verbose, you can wrap them as you need. For example:

      defmodule MyApp.ExchangeRates do
        def last_updated(), do: Money.ExchangeRatesLite.last_updated(MyApp.ExchangeRates)
        def latest_rates(), do: Money.ExchangeRatesLite.latest_rates(MyApp.ExchangeRates)
        def historic_rates(date),
          do: Money.ExchangeRatesLite.historic_rates(MyApp.ExchangeRates, date)
      end

  That's it.

  ## Advanced Usage

  By default, `Money.ExchangeRatesLite` runs in `:single` mode, which will create dedicated cache
  based on the `:name` option. If you run multiple `Money.ExchangeRatesLite` instances (which is
  very common when using pool manager), each instance will have its own separate cache. Typically,
  this is not what you want.

  In order to share cache between multiple `Money.ExchangeRatesLite` instances,
  `Money.ExchangeRatesLite` provides `:shared` mode.

  ## Options

  * `:mode` specifies the running mode. Available modes are `:single` and `:shared`. The default
    is `:single`.

  * `:name` specifies the name for `:single` mode. In `:single` mode, all the caches are created
    based on this name.

  * `:shared_name` specifies the shared name for `:shared` mode. In `:shared` mode, all the caches
    are created based on this name.

  * `:retriever_adapter` specifies the module to retrieve exchange rates. This can be any
    module that implements the `Money.ExchangeRatesLite.Retriever` behaviour. The default is
    `Money.ExchangeRatesLite.Retriever.OpenExchangeRates`.

  * `:retriever_options` specifies the options of `:retriever_adapter`.

  * `:cache_adapter` specifies the module to cache exchange rates. This can be any module that
    implements the `Money.ExchangeRatesLite.Cache` behaviour. The default is
    `Money.ExchangeRatesLite.Cache.Ets`.

  * `:http_client_adapter` specifies the module to cache exchange rates. This can be any module
    that implements the `Money.ExchangeRatesLite.HttpClient` behaviour. The default is
    `Money.ExchangeRatesLite.HttpClient.CldrHttp`.

  * `:http_client_options` specifies the options of `:http_client_adapter`.

  * `:retrieve_every` specifies how often the exchange rates are retrieved in milliseconds.
    The default is 5 minutes (300,000 milliseconds).

  * `:preload_historic_rates` specifies a `%Date{}` or a `%Date.Range{}`, that will be
    retrieved when the server starts up.
    The default is `nil` meaning no historic rates are preloaded.

  * `:log_level_success` specifies the log level at which successful api retrieval are logged.
    The default is `nil` which means no logging.

  * `:log_level_failure` specifies the log level at which api retrieval errors are logged.
    The default is `:warning`.

  * `:log_level_info` specifies the log level at which server startup messages are logged.
    The default is `:info`.

  """

  @schema_options [
    mode: [
      type: {:in, [:single, :shared]},
      default: :single
    ],
    name: [
      type: :atom
    ],
    shared_name: [
      type: :atom
    ],
    retriever_adapter: [
      type: :atom,
      default: Money.ExchangeRatesLite.Retriever.OpenExchangeRates
    ],
    retriever_options: [
      type: :keyword_list,
      default: []
    ],
    cache_adapter: [
      type: :atom,
      default: Money.ExchangeRatesLite.Cache.Ets
    ],
    http_client_adapter: [
      type: :atom,
      default: Money.ExchangeRatesLite.HttpClient.CldrHttp
    ],
    http_client_options: [
      type: :keyword_list,
      default: []
    ],
    retrieve_every: [
      type: :integer,
      default: 300_000
    ],
    preload_historic_rates: [
      type: {:or, [nil, {:struct, Date}, {:struct, Date.Range}]},
      default: nil
    ],
    log_level_success: [
      type: :atom,
      default: nil
    ],
    log_level_failure: [
      type: :atom,
      default: :warning
    ],
    log_level_info: [
      type: :atom,
      default: :info
    ]
  ]

  use GenServer
  require Logger
  alias Money.ExchangeRatesLite.Cache
  alias Money.ExchangeRatesLite.Cache.Config, as: CacheConfig
  alias Money.ExchangeRatesLite.HttpClient
  alias Money.ExchangeRatesLite.HttpClient.Config, as: HttpClientConfig
  alias Money.ExchangeRatesLite.Retriever
  alias Money.ExchangeRatesLite.Retriever.Config, as: RetrieverConfig

  @type exchange_rates :: map()
  @type reason :: term()

  @doc """
  Starts an instance of Money.ExchangeRatesLite.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    init_arg =
      opts
      |> NimbleOptions.validate!(@schema_options)
      |> check_mode!(:single, :name)
      |> check_mode!(:shared, :shared_name)

    options = Keyword.take(init_arg, [:name])
    GenServer.start_link(__MODULE__, init_arg, options)
  end

  defp check_mode!(opts, mode, name_key) do
    current_mode = Keyword.fetch!(opts, :mode)
    name = Keyword.get(opts, name_key)

    if current_mode == mode && !name do
      raise(
        ArgumentError,
        "#{inspect(name_key)} must be provided when :mode is set to #{inspect(mode)}"
      )
    end

    opts
  end

  @doc """
  Gets the %DateTime{} of the last successful retrieval of latest exchange rates.
  """
  @spec last_updated(GenServer.server()) :: {:ok, DateTime.t()} | {:error, reason()}
  def last_updated(server) do
    GenServer.call(server, :last_updated)
  end

  @doc """
  Gets the latest exchange rates.
  """
  @spec latest_rates(GenServer.server()) :: {:ok, exchange_rates()} | {:error, reason()}
  def latest_rates(server) do
    GenServer.call(server, :latest_rates)
  end

  @doc """
  Gets the historic exchange rates specified by date.
  """
  @spec historic_rates(GenServer.server(), Date.t()) :: {:ok, exchange_rates()} | {:error, reason()}
  def historic_rates(server, %Date{} = date) do
    GenServer.call(server, {:historic_rates, date})
  end

  @impl true
  def init(init_arg) do
    mode = Keyword.fetch!(init_arg, :mode)

    name =
      case mode do
        :single -> Keyword.fetch!(init_arg, :name)
        :shared -> Keyword.fetch!(init_arg, :shared_name)
      end

    retriever_adapter = Keyword.fetch!(init_arg, :retriever_adapter)
    retriever_options = Keyword.fetch!(init_arg, :retriever_options)
    cache_adapter = Keyword.fetch!(init_arg, :cache_adapter)
    http_client_adapter = Keyword.fetch!(init_arg, :http_client_adapter)
    http_client_options = Keyword.fetch!(init_arg, :http_client_options)
    retrieve_every = Keyword.fetch!(init_arg, :retrieve_every)
    preload_historic_rates = Keyword.fetch!(init_arg, :preload_historic_rates)
    log_level_success = Keyword.fetch!(init_arg, :log_level_success)
    log_level_failure = Keyword.fetch!(init_arg, :log_level_failure)
    log_level_info = Keyword.fetch!(init_arg, :log_level_info)

    cache_config = CacheConfig.new!(name: name, adapter: cache_adapter)

    http_client_config =
      HttpClientConfig.new!(
        name: name,
        adapter: http_client_adapter,
        adapter_options: http_client_options
      )

    retriever_config =
      RetrieverConfig.new!(
        name: name,
        adapter: retriever_adapter,
        adapter_options: retriever_options,
        http_client_config: http_client_config
      )

    state = %{
      cache_config: cache_config,
      retriever_config: retriever_config,
      retrieve_every: retrieve_every,
      preload_historic_rates: preload_historic_rates,
      log_level_success: log_level_success,
      log_level_failure: log_level_failure,
      log_level_info: log_level_info
    }

    with :ok <- Cache.init(cache_config),
         :ok <- HttpClient.init(http_client_config) do
      schedule_retrieve({:latest_rates, :init}, state)
      schedule_retrieve({:historic_rates, :init}, state)

      {:ok, state}
    else
      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def terminate(reason, state) when reason in [:normal, :shutdown] do
    %{
      cache_config: cache_config,
      http_client_config: http_client_config
    } = state

    with :ok <- Cache.terminate(cache_config),
         :ok <- HttpClient.terminate(http_client_config) do
      :ok
    end
  end

  @impl true
  def terminate(reason, _state) do
    Logger.error("[#{__MODULE__}] Terminate called with unhandled #{inspect(reason)}")
  end

  @impl true
  def handle_call(:latest_rates, _from, state) do
    reply =
      case get_cache_latest_rates(state) do
        nil ->
          retrieve_latest_rates(state)

        rates ->
          {:ok, rates}
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_call(:last_updated, _from, state) do
    reply =
      case get_cache_last_updated(state) do
        nil ->
          {:error, {__MODULE__, "Last updated date is unknown"}}

        last_updated ->
          {:ok, last_updated}
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_call({:historic_rates, date}, _from, state) do
    reply =
      case get_cache_historic_rates(state, date) do
        nil ->
          retrieve_historic_rates(state, date)

        rates ->
          {:ok, rates}
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_info(:latest_rates, state) do
    retrieve_latest_rates(state)
    schedule_retrieve({:latest_rates, :next}, state)
    {:noreply, state}
  end

  @impl true
  def handle_info({:historic_rates, date}, state) do
    retrieve_historic_rates(state, date)
    {:noreply, state}
  end

  defp retrieve_latest_rates(state) do
    %{retriever_config: retriever_config} = state

    case Retriever.get_latest_rates(retriever_config) do
      {:ok, :not_modified} ->
        log(state, :success, "Latest exchange rates are unchanged")
        {:ok, get_cache_latest_rates(state)}

      {:ok, rates} ->
        log(state, :success, "Latest exchange rates are retrieved")
        last_updated = DateTime.utc_now()
        put_cache_last_updated(state, last_updated)
        put_cache_latest_rates(state, rates)
        {:ok, rates}

      {:error, reason} ->
        log(state, :failure, "Could not retrieve latest exchange rates: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp retrieve_historic_rates(state, date) do
    %{retriever_config: retriever_config} = state

    case Retriever.get_historic_rates(retriever_config, date) do
      {:ok, :not_modified} ->
        log(state, :success, "Historic exchange rates for #{Date.to_string(date)} are unchanged")
        {:ok, get_cache_historic_rates(state, date)}

      {:ok, rates} ->
        log(state, :success, "Historic exchange rates for #{Date.to_string(date)} are retrieved")
        put_cache_historic_rates(state, date, rates)
        {:ok, rates}

      {:error, reason} ->
        log(
          state,
          :failure,
          "Could not retrieve historic exchange rates for #{date}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp log(state, type, message) do
    level = Map.get(state, :"log_level_#{type}")
    if level, do: Logger.log(level, message)
  end

  defp get_cache_last_updated(state) do
    %{cache_config: cache_config} = state
    Cache.get(cache_config, :last_updated)
  end

  defp put_cache_last_updated(state, %DateTime{} = datetime) do
    %{cache_config: cache_config} = state
    Cache.put(cache_config, :last_updated, datetime)
  end

  defp get_cache_latest_rates(state) do
    %{cache_config: cache_config} = state
    Cache.get(cache_config, :latest_rates)
  end

  defp put_cache_latest_rates(state, rates) do
    %{cache_config: cache_config} = state
    Cache.put(cache_config, :latest_rates, rates)
  end

  defp get_cache_historic_rates(state, %Date{} = date) do
    %{cache_config: cache_config} = state
    Cache.get(cache_config, date)
  end

  defp put_cache_historic_rates(state, %Date{} = date, rates) do
    %{cache_config: cache_config} = state
    Cache.put(cache_config, date, rates)
  end

  defp schedule_retrieve({:latest_rates, :init}, state) do
    %{retrieve_every: retrieve_every} = state
    seconds = div(retrieve_every, 1000)
    log(state, :info, "Latest exchange rates will be retrieved now and then every #{seconds}s")
    Process.send(self(), :latest_rates, [])
  end

  defp schedule_retrieve({:latest_rates, :next}, state) do
    Process.send_after(self(), :latest_rates, state.retrieve_every)
  end

  defp schedule_retrieve(
         {:historic_rates, :init},
         %{preload_historic_rates: nil} = _state
       ) do
    :ok
  end

  # Don't retrieve historic rates if they are already cached.
  #
  # This depends on two assumptions:
  # 1. The cache is persistent across restarts, like `Money.ExchangeRates.Cache.Dets`.
  # 2. The historic rates don't change over time.
  defp schedule_retrieve(
         {:historic_rates, :init},
         %{preload_historic_rates: %Date{} = date} = state
       ) do
    case get_cache_historic_rates(state, date) do
      nil ->
        Process.send(self(), {:historic_rates, date}, [])

      _ ->
        :ok
    end
  end

  defp schedule_retrieve(
         {:historic_rates, :init},
         %{preload_historic_rates: %Date.Range{} = date_range} = state
       ) do
    for date <- date_range do
      case get_cache_historic_rates(state, date) do
        nil ->
          Process.send(self(), {:historic_rates, date}, [])

        _ ->
          :ok
      end
    end
  end
end
