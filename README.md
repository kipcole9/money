# Introduction to Money

Money implements a set of functions to store, retrieve and perform arithmetic
on a `%Money{}` type that is composed of a currency code and a currency amount.

Money is opinionated in the interests of serving as a dependable library
that can underpin accounting and financial applications.  Before release 1.0 it
can be expected that this contract may not be fully met.

How is this opinion expressed?

1. Money must always have both a amount and a currency code.

2. The currency code must always be a valid ISO4217 code.

3. Money arithmetic can only be performed when both operands are of the same currency.

4. Money amounts are represented as a `Decimal`.

5. Money can be serialised to the database as a composite Postgres type that includes both the amount and the currency. For MySQL, money is serialized into a json column with the amount converted to a string to preserve precision since json does not have a decimal type. Serialization is entirely optional.

6. All arithmetic functions work on a `Decimal`. No rounding occurs automatically (unless expressly called out for a function, as is the case for `Money.split/2`).

7. Explicit rounding obeys the rounding rules for a given currency. The rounding rules are defined by the Unicode consortium in its CLDR repository as implemented by the hex package [ex_cldr](https://hex.pm/packages/ex_cldr). These rules define the number of fractional digits for a currency and the rounding increment where appropriate.

8. Money output string formatting output using the hex package [ex_cldr](https://hex.pm/packages/ex_cldr) that correctly rounds to the appropriate number of fractional digits and to the correct rounding increment for currencies that have minimum cash increments (like the Swiss Franc and Australian Dollar)

## Prerequisities

* `ex_money` is supported on Elixir 1.5 and later only

## Exchange rates and currency conversion

Money includes a process to retrieve exchange rates on a periodic basis.  These exchange rates can then be used to support currency conversion.  This service is not started by default.  If started it will attempt to retrieve exchange rates every 5 minutes by default.

By default, exchange rates are retrieved from [Open Exchange Rates](http://openexchangerates.org) however any module that conforms to the `Money.ExchangeRates` behaviour can be configured.

An optional callback module can also be defined.  This module defines a `rates_retrieved/2` function that is invoked upon every successful retrieval of exchange rates.  This might be used to serialize exchange rate to a data store or to stream rates to other applications or systems.

## Configuration

`Money` provides a set of configuration keys to customize behaviour. The default configuration is:

    config :ex_money,
      exchange_rate_service: false,
      exchange_rates_retrieve_every: 300_000,
      delay_before_first_retrieval: 100,
      api_module: Money.ExchangeRates.OpenExchangeRates,
      callback_module: Money.ExchangeRates.Callback,
      retriever_options: nil
      log_failure: :warn,
      log_info: :info,
      log_success: nil

### Configuration key definitions

* `:exchange_rate_service` is a boolean that determines whether to automatically start the exchange rate retrieval service.  The default it `false`.

* `:exchange_rates_retrieve_every` defines how often the exchange rates are retrieved in milliseconds.  The default is 5 minutes (300,000 milliseconds)

* `:delay_before_first_retrieval` defines how quickly the retrieval service makes its first request for exchange rates.  The default is 100 milliseconds.  Any value that is not a positive integer means that no first retrieval is made.  Retrieval will continue on interval defined by `:retrieve_every`

* `:api_module` identifies the module that does the retrieval of exchange rates. This is any module that implements the `Money.ExchangeRates` behaviour.  The  default is `Money.ExchangeRates.OpenExchangeRates`

* `callback_module` defines a module that follows the `Money.ExchangeRates.Callback` behaviour whereby the function `rates_retrieved/2` is invoked after every successful retrieval of exchange rates.  The default is `Money.ExchangeRates.Callback`.

* `log_failure` defines the log level at which api retrieval errors are logged.  The default is `:warn`

* `log_success` defines the log level at which successful api retrieval notifications are logged.  The default is `nil` which means no logging.

* `log_info` defines the log level at which service startup messages are logged.  The default is `info`.

* `:retriever_options` is available for exchange rate retriever module developers as a place to add retriever-specific configuration information.  This information should be added in the `init/1` callback in the retriever module.  See `Money.ExchangeRates.OpenExchangeRates.init/1` for an example.

### Open Exchange Rates configuration

If you plan to use the provided Open Exchange Rates module to retrieve exchange rates then you should also provide the addition
  configuration key for `app_id`:

      config :ex_money,
        open_exchange_rates_app_id: "your_app_id"

  or configure it via environment variable, for example:

      config :ex_money,
        open_exchange_rates_app_id: {:system, "OPEN_EXCHANGE_RATES_APP_ID"}

  The default exchange rate retrieval module is provided in `Money.ExchangeRates.OpenExchangeRates` which can be used
  as a example to implement your own retrieval module for  other services.

### Managing the configuration at runtime

  During exchange rate service startup, the function `init/1` is called on the configuration exchange rate retrieval module.  This module is expected to return an updated configuration allowing a develop to customise how the configuration is to be managed.  See the implementation at `Money.ExchangeRates.OpenExchangeRates.init/1` for an example.

### Using Environment Variables in the configuration

Keys can also be configured to retrieve values from environment variables.  This lookup is done at runtime to facilitate deployment strategies.  If the value of a configuration key is `{:system, "some_string"}` then `"some_string"` is interpreted as an environment variable name which is passed to `System.get_env/2`.  An example configuration might be:

    config :ex_money,
      exchange_rate_service: {:system, "RATE_SERVICE"},
      exchange_rates_retrieve_every: {:system, "RETRIEVE_EVERY"},
      open_exchange_rates_app_id: {:system, "OPEN_EXCHANGE_RATES_APP_ID"}

## The Exchange rates service process supervision and startup

If the exchange rate service is configured to automatically start up (because the config key `exchange_rate_service` is set to `true`) then a supervisor process named `Money.ExchangeRates.Supervisor` is started which in turns starts a child `GenServer` called `Money.ExchangeRates.Retriever`.  It is `Money.ExchangeRates.Retriever` which will call the configured `api_module` to retrieve the rates.  It is also responsible for calling the configured `callback_module` after a successfull retrieval.

                                         +-----------------+
                                         |                 |
    +-------------+    +-----------+     |   api_module    |-> External Service
    |             |    |           |---> |                 |
    | Supervisor  |--->| Retriever |     +-----------------+
    |             |    |           |---> +-----------------+
    +-------------+    +-----------+     |                 |
                                         | callback_module |
                                         |                 |
                                         +-----------------+

On application start (or manual start if `:exchange_rate_service` is set to `false`), `Money.ExchangeRates.Retriever` will schedule the first retrieval to be executed after `:delay_before_first_retrieval` milliseconds and then each `:exchange_rates_retrieve_every` milliseconds thereafter.

## Using Ecto or other applications from within the callback module

If you provide your own callback module and that module depends on some other applications, like `Ecto`, already being started then automatically starting `Money.ExchangeRates.Supervisor` may not work since your `Ecto.Repo` is unlikely to have already been started.

In this situation the appropriate way to configure the exchange rates retrieval service is the following:

1. Set the configuration key `exchange_rate_service` to `false` to prevent automatic startup of the service.

2. Configure your `api_module`, `callback_module` and any other required configuration as appropriate

3. In your client application code, add the `Money.ExchangeRates.Supervisor` to the `children` configuration of your application.  For example, in an application that uses `Ecto` and where your `callback_module` is designed to save exchange rates to a database, your application may would look something like:

```elixir
defmodule Application do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [

      # Start your repo first so that it is running before your
      # exchange rates callback module is called
      supervisor(MoneyTest.Repo, []),

      # Include the Money.ExchangeRates.Supervisor in your application's
      # supervision tree.  This supervisor will start the child process
      # Money.ExchangeRates.Retriever
      supervisor(Money.ExchangeRates.Supervisor, [])
    ]

    opts = [strategy: :one_for_one, name: Application.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

## API Usage Examples

### Creating a %Money{} struct

     iex> Money.new(:USD, 100)
     #Money<:USD, 100>

     iex> Money.new(100, :USD)
     #Money<:USD, 100>

     iex> Money.new("CHF", 130.02)
     #Money<:CHF, 130.02>

     iex> Money.new("thb", 11)
     #Money<:THB, 11>

The canonical representation of a currency code is an `atom` that is a valid
[ISO4217](http://www.currency-iso.org/en/home/tables/table-a1.html) currency code. The amount of a `%Money{}` is represented by a `Decimal`.

Note that the arguments to `Money.new/2` can be supplied in either order.

### Optional ~M sigil

An optional sigil module is available to aid in creating %Money{} structs.  It needs to be imported before use:

    import Money.Sigil

    ~M[100]USD
    #> #Money<:USD, 100>

### Localised String formatting

See also `Money.to_string/2` and `Cldr.Number.to_string/2`):

    iex> Money.to_string Money.new("thb", 11)
    {:ok, "THB11.00"}

    iex> Money.to_string Money.new("USD", 234.467)
    {:ok, "$234.47"}

    iex> Money.to_string Money.new("USD", 234.467), format: :long
    {:ok, "234.47 US dollars"}

Note that the output is influenced by the locale in effect.  By default the localed used is that returned by `Cldr.get_current_local/0`.  Its default value is "en".  Additional locales can be configured, see `Cldr`.  The formatting options are defined in `Cldr.Number.to_string/2`.

### Arithmetic Functions

See also the module `Money.Arithmetic`:

    iex> m1 = Money.new(:USD, 100)
    #Money<:USD, 100>}

    iex> m2 = Money.new(:USD, 200)
    #Money<:USD, 200>}

    iex> Money.add(m1, m2)
    {:ok, #Money<:USD, 300>}

    iex> Money.add!(m1, m2)
    #Money<:USD, 300>

    iex> m3 = Money.new(:AUD, 300)
    #Money<:AUD, 300>

    iex> Money.add Money.new(:USD, 200), Money.new(:AUD, 100)
    {:error, {ArgumentError, "Cannot add monies with different currencies. Received :USD and :AUD."}}

    # Split a %Money{} returning the a dividend and a remainder. All
    # operations respect the number of fractional digits defined for a currency
    iex> m1 = Money.new(:USD, 100)
    #Money<:USD, 100>

    iex> Money.split(m1, 3)
    {#Money<:USD, 33.33>, #Money<:USD, 0.01>}

    # Rounding applies the currency definitions of CLDR as implemented in
    # the hex package [ex_cldr](https://hex.pm/packages/ex_cldr)
    iex> Money.round Money.new(:USD, 100.678)
    #Money<:USD, 100.68>

    iex> Money.round Money.new(:JPY, 100.678)
    #Money<:JPY, 101>

### Currency Conversion

A `%Money{}` struct can be converted to another currency using `Money.to_currency/3` or `Money.to_currency!/3`.  For example:

    iex> Money.to_currency Money.new(:USD,100), :AUD
    {:ok, #Money<:AUD, 136.4300>}

    iex> Money.to_currency Money.new(:USD, 100) , :AUDD, %{USD: Decimal.new(1), AUD: Decimal.new(0.7345)}
    {:error, {Cldr.UnknownCurrencyError, "Currency :AUDD is not known"}}

    iex> Money.to_currency! Money.new(:USD,100), :XXX
    ** (Money.ExchangeRateError) No exchange rate is available for currency :XXX

A user-defined map of exchange rates can also be supplied:

    iex> Money.to_currency Money.new(:USD,100), :AUD, %{USD: Decimal.new(1.0), AUD: Decimal.new(1.3)}
    #Money<:AUD, 130>

### Financial Functions

A set of basic financial functions are available in the module `Money.Financial`.   These functions are:

* Present value: `Money.Financial.present_value/3`
* Future value: `Money.Financial.future_value/3`
* Interest rate: `Money.Financial.interest_rate/3`
* Number of periods: `Money.Financial.periods/3`
* Payment amount: `Money.Financial.payment/3`
* Net Present Value of a set of cash flows: `Money.Financial.net_present_value/2`
* Internal rate of return: `Money.Financial.internal_rate_of_return/1`

For more detail see `Money.Financial`.

## Serializing to a Postgres database with Ecto

First generate the migration to create the custom type:

    mix money.gen.postgres.migration
    * creating priv/repo/migrations
    * creating priv/repo/migrations/20161007234652_add_money_with_currency_type_to_postgres.exs

Then migrate the database:

    mix ecto.migrate
    07:09:28.637 [info]  == Running MoneyTest.Repo.Migrations.AddMoneyWithCurrencyTypeToPostgres.up/0 forward
    07:09:28.640 [info]  execute "CREATE TYPE public.money_with_currency AS (currency_code char(3), amount numeric(20,8))"
    07:09:28.647 [info]  == Migrated in 0.0s

Create your database migration with the new type (don't forget to `mix ecto.migrate` as well):

```elixir
defmodule MoneyTest.Repo.Migrations.CreateLedger do
  use Ecto.Migration

  def change do
    create table(:ledgers) do
      add :amount, :money_with_currency
      timestamps()
    end
  end
end
```

Create your schema using the `Money.Ecto.Composite.Type` ecto type:

```elixir
defmodule Ledger do
  use Ecto.Schema

  schema "ledgers" do
    field :amount, Money.Ecto.Composite.Type

    timestamps()
  end
end
```

Insert into the database:

    iex> Repo.insert %Ledger{amount: Money.new(:USD, 100)}
    [debug] QUERY OK db=4.5ms
    INSERT INTO "ledgers" ("amount","inserted_at","updated_at") VALUES ($1,$2,$3)
    [{"USD", #Decimal<100>}, {{2016, 10, 7}, {23, 12, 13, 0}}, {{2016, 10, 7}, {23, 12, 13, 0}}]

Retrieve from the database:

    iex> Repo.all Ledger
    [debug] QUERY OK source="ledgers" db=5.3ms decode=0.1ms queue=0.1ms
    SELECT l0."amount", l0."inserted_at", l0."updated_at" FROM "ledgers" AS l0 []
    [%Ledger{__meta__: #Ecto.Schema.Metadata<:loaded, "ledgers">, amount: #<:USD, 100.00000000>,
      inserted_at: ~N[2017-02-21 00:15:40.979576],
      updated_at: ~N[2017-02-21 00:15:40.991391]}]

## Serializing to a MySQL (or other non-Postgres) database with Ecto

Since MySQL does not support composite types, the `:map` type is used which in MySQL is implemented as a `JSON` column.  The currency code and amount are serialised into this column.

```elixir
defmodule MoneyTest.Repo.Migrations.CreateLedger do
  use Ecto.Migration

  def change do
    create table(:ledgers) do
      add :amount, :map
      timestamps()
    end
  end
end
```

Create your schema using the `Money.Ecto.Map.Type` ecto type:

```elixir
defmodule Ledger do
  use Ecto.Schema

  schema "ledgers" do
    field :amount, Money.Ecto.Map.Type

    timestamps()
  end
end
```

Insert into the database:

    iex> Repo.insert %Ledger{amount_map: Money.new(:USD, 100)}
    [debug] QUERY OK db=25.8ms
    INSERT INTO "ledgers" ("amount_map","inserted_at","updated_at") VALUES ($1,$2,$3)
    RETURNING "id" [%{amount: "100", currency: "USD"},
    {{2017, 2, 21}, {0, 15, 40, 979576}}, {{2017, 2, 21}, {0, 15, 40, 991391}}]

    {:ok,
     %MoneyTest.Thing{__meta__: #Ecto.Schema.Metadata<:loaded, "ledgers">,
      amount: nil, amount_map: #Money<:USD, 100>, id: 3,
      inserted_at: ~N[2017-02-21 00:15:40.979576],
      updated_at: ~N[2017-02-21 00:15:40.991391]}}

Retrieve from the database:

    iex> Repo.all Ledger
    [debug] QUERY OK source="ledgers" db=16.1ms decode=0.1ms
    SELECT t0."id", t0."amount_map", t0."inserted_at", t0."updated_at" FROM "ledgers" AS t0 []
    [%Ledger{__meta__: #Ecto.Schema.Metadata<:loaded, "ledgers">,
      amount_map: #Money<:USD, 100>, id: 3,
      inserted_at: ~N[2017-02-21 00:15:40.979576],
      updated_at: ~N[2017-02-21 00:15:40.991391]}]

### Notes:

1.  In order to preserve precision of the decimal amount, the amount part of the `%Money{}` struct is serialised as a string. This is done because JSON serializes numeric values as either `integer` or `float`, neither of which would not preserve precision of a decimal value.

2.  The precision of the serialized string value of amount is affected by the setting of `Decimal.get_context`.  The default is 28 digits which should cater for your requirements.

3.  Serializing the amount as a string means that SQL query arithmetic and equality operators will not work as expected.  You may find that `CAST`ing the string value will restore some of that functionality.  For example:

```sql
    CAST(JSON_EXTRACT(amount_map, '$.amount') AS DECIMAL(20, 8)) AS amount;
```

## Installation

ex_money can be installed by:

  1. Adding `ex_money` to your list of dependencies in `mix.exs`:

```elixir
  def deps do
    [{:ex_money, "~> 0.8.3"}]
  end
```

## Why yet another Money package?

* Fully localized formatting and rounding using [ex_cldr](https://hex.pm/packages/ex_cldr)

* Provides serialization to Postgres using a composite type and MySQL using a JSON type that keeps both the currency code and the amount together removing a source of potential error

* Uses the `Decimal` type in Elixir and the Postgres `numeric` type to preserve precision.  For MySQL the amount is serialised as a string to preserve precision that might otherwise be lost if stored as a JSON numeric type (which is either an integer or a float)

* Includes a set of financial calculations (arithmetic and cash flow calculations) that follow solid rounding rules
