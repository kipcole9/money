# Introduction to Money
![Build Status](http://sweatbox.noexpectations.com.au:8080/buildStatus/icon?job=money)
[![Hex pm](http://img.shields.io/hexpm/v/ex_money.svg?style=flat)](https://hex.pm/packages/ex_money)
[![License](https://img.shields.io/badge/license-Apache%202-blue.svg)](https://github.com/kipcole9/money/blob/master/LICENSE)

Money implements a set of functions to store, retrieve, convert and perform arithmetic
on a `%Money{}` type that is composed of an ISO 4217 currency code and a currency amount.

Money is opinionated in the interests of serving as a dependable library
that can underpin accounting and financial applications.

How is this opinion expressed?

1. Money must always have both a amount and a currency code.

2. The currency code must always be a valid [ISO4217](https://www.iso.org/iso-4217-currency-codes.html) code. [Current](https://www.currency-iso.org/en/home/tables/table-a1.html) and [historical](https://www.currency-iso.org/en/home/tables/table-a3.html) currency codes can be used.  See the [ISO Currency](https://www.currency-iso.org/en/home/tables.html) for more information. You can also identify the relevant codes by:

   * `Money.known_currencies/0` returns all the currency codes known to `Money`
   * `Money.known_current_currencies/0` returns the currency codes currently in use
   * `Money.known_historic_currencies/0` returns the list of historic currency codes
   * `Money.known_tender_currencies/0` returns the list of currencies known to be legal tender

3. Money arithmetic can only be performed when both operands are of the same currency.

4. Money amounts are represented as a `Decimal`.

5. Money can be serialised to the database as a composite Postgres type that includes both the amount and the currency. For MySQL, money is serialized into a json column with the amount converted to a string to preserve precision since json does not have a decimal type. Serialization is entirely optional.

6. All arithmetic functions work on a `Decimal`. No rounding occurs automatically (unless expressly called out for a function, as is the case for `Money.split/2`).

7. Explicit rounding obeys the rounding rules for a given currency. The rounding rules are defined by the Unicode consortium in its CLDR repository as implemented by the hex package [ex_cldr](https://hex.pm/packages/ex_cldr). These rules define the number of fractional digits for a currency and the rounding increment where appropriate.

8. Money output string formatting output using the hex package [ex_cldr](https://hex.pm/packages/ex_cldr) that correctly rounds to the appropriate number of fractional digits and to the correct rounding increment for currencies that have minimum cash increments (like the Swiss Franc and Australian Dollar)

## Prerequisities

* `Money` is supported on Elixir 1.5 and later only

## Exchange rates and currency conversion

Money includes a process to retrieve exchange rates on a periodic basis.  These exchange rates can then be used to support currency conversion.  This service is not started by default.  If started it will attempt to retrieve exchange rates every 5 minutes by default.

By default, exchange rates are retrieved from [Open Exchange Rates](http://openexchangerates.org) however any module that conforms to the `Money.ExchangeRates` behaviour can be configured.

An optional callback module can also be defined.  This module defines a `rates_retrieved/2` function that is invoked upon every successful retrieval of exchange rates.  This might be used to serialize exchange rate to a data store or to stream rates to other applications or systems.

## Configuration

`Money` provides a set of configuration keys to customize behaviour. The default configuration is:

    config :ex_money,
      exchange_rates_retrieve_every: 300_000,
      api_module: Money.ExchangeRates.OpenExchangeRates,
      callback_module: Money.ExchangeRates.Callback,
      exchange_rates_cache_module: Money.ExchangeRates.Cache.Ets,
      preload_historic_rates: nil,
      retriever_options: nil,
      log_failure: :warn,
      log_info: :info,
      log_success: nil,
      json_library: Cldr.Config.json_library()

**Note** that `ex_money` does not define a json library dependency and therefore it is the users responsibility to configure a required json library as a dependency in the applications `mix.exs`.

### Configuration key definitions

* `:exchange_rates_retrieve_every` defines how often the exchange rates are retrieved in milliseconds.  The default is `:never`. An `atom` value is interpreted to mean that there should be no periodic retrieval.

* `:api_module` identifies the module that does the retrieval of exchange rates. This is any module that implements the `Money.ExchangeRates` behaviour.  The  default is `Money.ExchangeRates.OpenExchangeRates`.

* `:exchange_rates_cache_module` defines the module that provides an exchange rates cache.  Any module that implements the `Money.ExchangeRates.Cache` behaviour.  Two alternative strategies are provided:

  * `Money.ExchangeRates.Cache.Ets` which is also the default.
  * `Money.ExchangeRates.Cache.Dets`

* `:preload_historic_rates` defines a date or a date range that will be requested when the exchange rate service starts up. The date or date range should be specified as either a `Date.t` or a `Date.Range.t` or a tuple of `{Date.t, Date.t}` representing the `from` and `to` dates for the rates to be retrieved. The default is `nil` meaning no historic rates are preloaded.  Some examples:

* `callback_module` defines a module that follows the `Money.ExchangeRates.Callback` behaviour whereby the function `rates_retrieved/2` is invoked after every successful retrieval of exchange rates.  The default is `Money.ExchangeRates.Callback`.

* `log_failure` defines the log level at which api retrieval errors are logged.  The default is `:warn`.

* `log_success` defines the log level at which successful api retrieval notifications are logged.  The default is `nil` which means no logging.

* `log_info` defines the log level at which service startup messages are logged.  The default is `info`.

* `:retriever_options` is available for exchange rate retriever module developers as a place to add retriever-specific configuration information.  This information should be added in the `init/1` callback in the retriever module.  See `Money.ExchangeRates.OpenExchangeRates.init/1` for an example.

* `:json_library` determines which json library to be used for decoding.  Two common options are `Poison` and `Jason`. The default is `Cldr.Config.json_library/0` which is currently configured by default as Poison.

### Configuring locales to support localised formatting

`Money` uses [ex_cldr](https://hex.pm/packages/ex_cldr) and [ex_cldr_numbers](https://hex.pm/packages/ex_cldr_numbers) to support configuring locales and providing localed formatting.

By default `ex_cldr` configures `en-001` (global english) as its only and default locale.  A minimal configuration to add any of the more then 500 known locales is below.  Full configuration information is contained in the [readme for ex_cldr](https://github.com/kipcole9/cldr#configuration).

```
config :ex_cldr,
  default_locale: "en-001",
  locales: ["fr", "zh-Hant", "en-GB", "bs", "pl", "ru", "th", "he", "af"]
```

* You can determine what locales are available to be configured by calling `Cldr.available_locale_names/0`.

* `Cldr.set_current_locale/1` will set the default locale for the process

* The `:locale` option can be used with `Money.to_string/2`.  If not provided as an option then `Money.to_string/2` will call `Cldr.get_current_locale/0` if one is set, otherwise it will use `Cldr.default_locale/0` which is set in the configuration.

### Preloading historic exchange rates

The current implementation will call the api_module to retrieve the historic rates once for each date in the `:preload_exchange_rates` range.  Some exchange rate services, like Open Exchange Rates, provides a bulk retrieval api that can retrieve multiple dates in a single call.  However this endpoint is only available for premium subscribers and it is still charged on a "per date retrieved" basis. So while there is a network/performance/efficiency benefit there is no economic benefit.  Please file an issue on [github](https://github.com/kipcole9/money) if implementing a bulk api is important to you.

Some examples of configuring the `:preload_exchange_rates` key follow:

  * `preload_exchange_rates: ~D[2017-01-01]`
  * `preload_exchange_rates: Date.range(~D[2017-01-01], ~D[2017-10-01])`
  * `preload_exchange_rates: {~D[2017-01-01], ~D[2017-10-01]}`

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

During exchange rate service startup, the function `init/1` is called on the configured exchange rate retrieval module.  This module is expected to return an updated configuration allowing a developer to customise how the configuration is to be managed.  See the implementation at `Money.ExchangeRates.OpenExchangeRates.init/1` for an example.

To support runtime (re-)configuration the following functions are provided:

  * `Money.ExchangeRates.Retriever.config/0` returns the current configuration of the exchange rates retrieval service.

  * `Money.ExchangeRates.Retriever.stop/0` and `Money.ExchangeRates.Retriever.start/0` stop and start the exchange rates retrieval service respectively.

  * `Money.ExchangeRates.Retriever.reconfigure/1` reconfigures the exchange rates retrieval service.  It does not restart the service, the service remains active during the recongiguration.

### Using Environment Variables in the configuration

Keys can also be configured to retrieve values from environment variables.  This lookup is done at runtime to facilitate deployment strategies.  If the value of a configuration key is `{:system, "some_string"}` then `"some_string"` is interpreted as an environment variable name which is passed to `System.get_env/2`.  An example configuration might be:

    config :ex_money,
      auto_start_exchange_rate_service: {:system, "RATE_SERVICE"},
      exchange_rates_retrieve_every: {:system, "RETRIEVE_EVERY"},
      open_exchange_rates_app_id: {:system, "OPEN_EXCHANGE_RATES_APP_ID"}

Note that the `{:system, "ENV KEY"}` approach is **not** currently supported for the `:preload_historic_rates` configuration key.

## The Exchange rates service process supervision and startup

If the exchange rate service is configured to automatically start up (because the config key `auto_start_exchange_rate_service` is set to `true`) then a supervisor process named `Money.ExchangeRates.Supervisor` is started which in turns starts a child `GenServer` called `Money.ExchangeRates.Retriever`.  It is `Money.ExchangeRates.Retriever` which will call the configured `api_module` to retrieve the rates.  It is also responsible for calling the configured `callback_module` after a successfull retrieval.

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

On application start (or manual start if `:auto_start_exchange_rate_service` is set to `false`), `Money.ExchangeRates.Retriever` will schedule the first retrieval to be executed after immediately and then each `:exchange_rates_retrieve_every` milliseconds thereafter.

## Using Ecto or other applications from within the callback module

If you provide your own callback module and that module depends on some other applications, like `Ecto`, already being started then automatically starting `Money.ExchangeRates.Supervisor` may not work since your `Ecto.Repo` is unlikely to have already been started.

In this situation the appropriate way to configure the exchange rates retrieval service is the following:

1. Set the configuration key `auto_start_exchange_rate_service` to `false` to prevent automatic startup of the service.

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
      # Money.ExchangeRates.Retriever.

      # Note the use of double `[]` around
      # the parameters which are required to ensure that the supervisor
      # is stopped before including in your supervisor tree.
      # The `start_retriever: true` is optional.  The default value is `false`.
      supervisor(Money.ExchangeRates.Supervisor, [[restart: true, start_retriever: true]])
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

    iex> Money.new("CHF", "130.02")
    #Money<:CHF, 130.02>

    iex> Money.new("thb", 11)
    #Money<:THB, 11>

The canonical representation of a currency code is an `atom` that is a valid
[ISO4217](http://www.currency-iso.org/en/home/tables/table-a1.html) currency code. The amount of a `%Money{}` is represented by a `Decimal`.

Note that the arguments to `Money.new/2` can be supplied in either order.

### Float amounts cannot be provided to `Money.new/2`

Float have well-known issues in computing due to issues of rounding and potential precision loss.  Internally `Money` uses `Decimal` to store the amount which allows arbitrary precision arithmetic.  `Money` also uses the `numeric` type in Postgres to preserve precision and even goes to far as to store the amount as a `string` in `MySQL` for the same reason.

Therefore an error is returned if an attempt is made to use `Money.new/2` with a float amount:

    {:error,
     {Money.InvalidAmountError,
      "Float amounts are not supported in new/2 due to potenial rounding " <>
        "and precision issues.  If absolutely required, use Money.from_float/2"}}

If the use of `float`s is require then the function `Money.from_float/2` is provided with the same arguments as those for `Money.new/2`.  `Money.from_float/2` provides an addition check and will return an error if the precision (number of digits) of the provided float is more than 15 (the number of digits guaranteed to round-trip between a 64-bit float and a string).

### Optional ~M sigil

An optional sigil module is available to aid in creating %Money{} structs.  It needs to be imported before use:

    import Money.Sigil

    ~M[100]USD
    #> #Money<:USD, 100>

### Localised Money formatting

`Money` provides locale-specific formatted output that is controlled be either the locale that has been set for this process or by the `:locale` parameter supplied to `Money.to_string/2`.  Configuring your localised environment requires configuring `ex_cldr` which is a dependency to `Money`.  See the [Configuration](https://github.com/kipcole9/cldr#configuration) section of the `ex_cldr` readme for more information.

The main API for formatting `Money` is `Money.to_string/2`. Additionally formatting options are passed to `Cldr.Number.to_string/2`.  Those options are described in the [readme for ex_cldr_numbers](https://github.com/kipcole9/cldr_numbers#primary-public-api) which is also a dependency to `Money`.

    iex> Money.to_string Money.new("thb", 11)
    {:ok, "THB11.00"}

    # The default locale is "en-001" which is
    # "global english"
    iex> Money.to_string Money.new("USD", "234.467")
    {:ok, "$US234.47"}

    # The locale "en" is "American English".  For
    # UK English use the locale "en-GB".  Australian
    # English is "en-AU" and so on.
    iex> Money.to_string Money.new("USD", "234.467"), locale: "en"
    {:ok, "$234.47"}

    iex> Money.to_string Money.new("USD", "234.467"), format: :long
    {:ok, "234.47 US dollars"}

    iex> Money.to_string Money.new("USD", "234.467"), locale: "fr"
    {:ok, "234,47 $US"}

    iex> Money.to_string Money.new("USD", "234.467"), locale: "de"
    {:ok, "234,47 $"}

    iex> Money.to_string Money.new("EUR", "234.467"), locale: "de"
    {:ok, "234,47 €"}

    iex> Money.to_string Money.new("EUR", "234.467"), locale: "fr"
    {:ok, "234,47 €"}

**Note that the output is influenced by the locale in effect.**  By default the locale used is that returned by `Cldr.get_current_local/0`.  Its default value is "en-001".  Additional locales can be configured, see `Cldr`.  The formatting options are defined in `Cldr.Number.to_string/2`.

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
    iex> Money.round Money.new(:USD, "100.678")
    #Money<:USD, 100.68>

    iex> Money.round Money.new(:JPY, "100.678")
    #Money<:JPY, 101>

### Currency Conversion

A `%Money{}` struct can be converted to another currency using `Money.to_currency/3` or `Money.to_currency!/3`.  For example:

    iex> Money.to_currency Money.new(:USD, 100), :AUD
    {:ok, #Money<:AUD, 136.43>}

    iex> Money.to_currency Money.new(:USD, 100), :AUD, ExchangeRates.historic_rates(~D[2017-01-01])
    {:ok, #Money<:AUD, 128.76>}

    iex> Money.to_currency Money.new(:USD, 100) , :AUDD, %{USD: Decimal.new(1), AUD: Decimal.new(0.7345)}
    {:error, {Cldr.UnknownCurrencyError, "Currency :AUDD is not known"}}

    iex> Money.to_currency! Money.new(:USD, 100), :XXX
    ** (Money.ExchangeRateError) No exchange rate is available for currency :XXX

A user-defined map of exchange rates can also be supplied:

    iex> Money.to_currency Money.new(:USD, 100), :AUD, %{USD: Decimal.new(1.0), AUD: Decimal.new(1.3)}
    #Money<:AUD, 130>

### Historic Conversion Rates

As noted in the [configuration](#configuration) section, `ex_money` can preload historic exchange rates when the exchange rates service starts up.  It can be anticipated that additional historic rates may be required subsequently.

* `Money.ExchangeRates.retrieve_historic/1` and `Money.ExchangeRates.retrieve_historic/2` can be called to request retrieval of historic rates at any time.  This call will send a message to the retrieval service to request retrieval.  It does not return the rates.

* `Money.ExchangeRates.historic_rates/1` is the partner function to `Money.ExchangeRates.latest_rates/0`.  It returns the exchange rates for a given date, and will return an error if no rates are available.

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

## Subscriptions

Subscriptions, especially in the context of a SaaS, can involve changing plans - either from a smaller plan to a larger or a larger plan to smaller.  In either situation a credit amount needs to be calculated based upon the current plan which is then applied to the new plan.  `Money.Subscription` is a module that provides functions to support this subscription pricing, credit calculations and payment dates.

The primary functions supporting subscriptions are:

* Create a new subscription: `Money.Subscription.new/3`
* Create a subscription plan: `Money.Subscription.Plan.new/3`
* Change a from one plan to another: `Money.Subscription.change_plan/3`
* Calculate the start date for the next interval of a plan: `Money.Subscription.next_interval_starts/3`
* Calculate the number of days in a plan interval: `Money.Subscription.plan_days/3`
* Calculate the number of days left in a plan interval: `Money.Subscription.days_remaining/4`

### Examples

    # Create the current plan
    iex> current_plan = Money.Subscription.Plan.new!(Money.new(:USD, 10), :month, 1)
    %Money.Subscription.Plan{
      interval: :month,
      interval_count: 1,
      price: #Money<:USD, 10>
    }

    # How many days in a billing period?
    iex> Money.Subscription.plan_days current_plan, ~D[2018-03-01]
    31

    iex> Money.Subscription.plan_days current_plan, ~D[2018-02-01]
    28

    # How many days remaining in the current billing period
    iex> Money.Subscription.days_remaining current_plan, ~D[2018-03-01], ~D[2018-03-10]
    22

    # When is the next billing date
    iex> Money.Subscription.next_interval_starts current_plan, ~D[2018-03-01]
    ~D[2018-04-01]

    # Create a new plan
    iex> new_plan = Money.Subscription.Plan.new!(Money.new(:USD, 10), :month, 3)
    %Money.Subscription.Plan{
      interval: :month,
      interval_count: 3,
      price: #Money<:USD, 10>
    }

    # Change plans at the end of the current billing period
    iex> Money.Subscription.change_plan current_plan, new_plan, current_interval_started: ~D[2018-03-01]
    %Money.Subscription.Change{
      carry_forward: #Money<:USD, 0>,
      credit_amount: #Money<:USD, 0>,
      credit_amount_applied: #Money<:USD, 0>,
      credit_days_applied: 0,
      credit_period_ends: nil,
      first_billing_amount: #Money<:USD, 10>,
      first_interval_starts: ~D[2018-04-01],
      next_interval_starts: ~D[2018-07-01]
    }

    # Change plans in the middle of the current plan period
    # and credit the balance of the current plan to the new plan
    iex> Money.Subscription.change_plan current_plan, new_plan, current_interval_started: ~D[2018-03-01], effective: ~D[2018-03-15]
    %Money.Subscription.Change{
      carry_forward: #Money<:USD, 0>,
      credit_amount: #Money<:USD, 5.49>,
      credit_amount_applied: #Money<:USD, 5.49>,
      credit_days_applied: 0,
      credit_period_ends: nil,
      first_billing_amount: #Money<:USD, 4.51>,
      first_interval_starts: ~D[2018-03-15],
      next_interval_starts: ~D[2018-06-15]
    }

    # Change plans in the middle of the current plan period
    # but instead of a monetary credit, apply the credit as
    # extra days on the new plan in the first billing period
    iex> Money.Subscription.change_plan current_plan, new_plan, current_interval_started: ~D[2018-03-01], effective: ~D[2018-03-15], prorate: :period
    %Money.Subscription.Change{
      carry_forward: #Money<:USD, 0>,
      credit_amount: #Money<:USD, 5.49>,
      credit_amount_applied: #Money<:USD, 0>,
      credit_days_applied: 51,
      credit_period_ends: ~D[2018-05-04],
      first_billing_amount: #Money<:USD, 10>,
      first_interval_starts: ~D[2018-03-15],
      next_interval_starts: ~D[2018-08-05]
    }

    # Create a subscription
    iex> plan = Money.Subscription.Plan.new!(Money.new(:USD, 200), :month, 3)
    iex> subscription = Money.Subscription.new! plan, ~D[2018-01-01]
    %Money.Subscription{
      created_at: #DateTime<2018-03-23 07:45:44.418916Z>,
      id: nil,
      plans: [
        {%Money.Subscription.Change{
           carry_forward: #Money<:USD, 0>,
           credit_amount: #Money<:USD, 0>,
           credit_amount_applied: #Money<:USD, 0>,
           credit_days_applied: 0,
           credit_period_ends: nil,
           first_billing_amount: #Money<:USD, 200>,
           first_interval_starts: ~D[2018-01-01],
           next_interval_starts: ~D[2018-04-01]
         },
         %Money.Subscription.Plan{
           interval: :month,
           interval_count: 3,
           price: #Money<:USD, 200>
         }}
      ]
    }

    # Change a subscription's plan
    iex> new_plan = Money.Subscription.Plan.new!(Money.new(:USD, 150), :day, 30)
    iex> Money.Subscription.change_plan! subscription, new_plan
    %Money.Subscription{
      created_at: #DateTime<2018-03-23 07:47:48.593973Z>,
      id: nil,
      plans: [
        {%Money.Subscription.Change{
           carry_forward: #Money<:USD, 0>,
           credit_amount: #Money<:USD, 0>,
           credit_amount_applied: #Money<:USD, 0>,
           credit_days_applied: 0,
           credit_period_ends: nil,
           first_billing_amount: #Money<:USD, 150>,
           first_interval_starts: ~D[2018-04-01],
           next_interval_starts: ~D[2018-05-01]
         },
         %Money.Subscription.Plan{
           interval: :day,
           interval_count: 30,
           price: #Money<:USD, 150>
         }},
        {%Money.Subscription.Change{
           carry_forward: #Money<:USD, 0>,
           credit_amount: #Money<:USD, 0>,
           credit_amount_applied: #Money<:USD, 0>,
           credit_days_applied: 0,
           credit_period_ends: nil,
           first_billing_amount: #Money<:USD, 200>,
           first_interval_starts: ~D[2018-01-01],
           next_interval_starts: ~D[2018-04-01]
         },
         %Money.Subscription.Plan{
           interval: :month,
           interval_count: 3,
           price: #Money<:USD, 200>
         }}
      ]
    }

## Serializing to a Postgres database with Ecto

`Money` provides custom Ecto day types and a custom Postgres data type to provide serialization of `Money.t` types without losing precision whilst also maintaining the integrity of the `{currency_code, amount}` relationship.  To serialise and retrieve money types from a database the following steps should be followed:

1. First generate the migration to create the custom type:

```elixir
mix money.gen.postgres.migration
* creating priv/repo/migrations
* creating priv/repo/migrations/20161007234652_add_money_with_currency_type_to_postgres.exs
```

2. Then migrate the database:

```elixir
mix ecto.migrate
07:09:28.637 [info]  == Running MoneyTest.Repo.Migrations.AddMoneyWithCurrencyTypeToPostgres.up/0 forward
07:09:28.640 [info]  execute "CREATE TYPE public.money_with_currency AS (currency_code char(3), amount numeric)"
07:09:28.647 [info]  == Migrated in 0.0s
```

3. Create your database migration with the new type (don't forget to `mix ecto.migrate` as well):

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

4. Create your schema using the `Money.Ecto.Composite.Type` ecto type:

```elixir
defmodule Ledger do
  use Ecto.Schema

  schema "ledgers" do
    field :amount, Money.Ecto.Composite.Type

    timestamps()
  end
end
```

5. Insert into the database:

```elixir
iex> Repo.insert %Ledger{amount: Money.new(:USD, "100.00")}
[debug] QUERY OK db=4.5ms
INSERT INTO "ledgers" ("amount","inserted_at","updated_at") VALUES ($1,$2,$3)
[{"USD", #Decimal<100.00>}, {{2016, 10, 7}, {23, 12, 13, 0}}, {{2016, 10, 7}, {23, 12, 13, 0}}]
```

6. Retrieve from the database:

```elixir
iex> Repo.all Ledger
[debug] QUERY OK source="ledgers" db=5.3ms decode=0.1ms queue=0.1ms
SELECT l0."amount", l0."inserted_at", l0."updated_at" FROM "ledgers" AS l0 []
[%Ledger{__meta__: #Ecto.Schema.Metadata<:loaded, "ledgers">, amount: #<:USD, 100.00>,
  inserted_at: ~N[2017-02-21 00:15:40.979576],
  updated_at: ~N[2017-02-21 00:15:40.991391]}]
```

## Serializing to a MySQL (or other non-Postgres) database with Ecto

Since MySQL does not support composite types, the `:map` type is used which in MySQL is implemented as a `JSON` column.  The currency code and amount are serialised into this column.

    defmodule MoneyTest.Repo.Migrations.CreateLedger do
      use Ecto.Migration

      def change do
        create table(:ledgers) do
          add :amount, :map
          timestamps()
        end
      end
    end

Create your schema using the `Money.Ecto.Map.Type` ecto type:

    defmodule Ledger do
      use Ecto.Schema

      schema "ledgers" do
        field :amount, Money.Ecto.Map.Type

        timestamps()
      end
    end

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

1.  In order to preserve precision of the decimal amount, the amount part of the `%Money{}` struct is serialised as a string. This is done because JSON serializes numeric values as either `integer` or `float`, neither of which would preserve precision of a decimal value.

2.  The precision of the serialized string value of amount is affected by the setting of `Decimal.get_context`.  The default is 28 digits which should cater for your requirements.

3.  Serializing the amount as a string means that SQL query arithmetic and equality operators will not work as expected.  You may find that `CAST`ing the string value will restore some of that functionality.  For example:

```sql
CAST(JSON_EXTRACT(amount_map, '$.amount') AS DECIMAL(20, 8)) AS amount;
```

## Postgres Database functions

Since the datatype used to store `Money` in Postgres is a composite type (called `:money_with_currency`), the standard aggregation functions like `sum` and `average` are not supported and the `order_by` clause doesn't perform as expected.  `Money` provides mechanisms to provide these functions.

### Aggregate functions: sum()

`Money` provides a migration generator which, when migrated to the database with `mix ecto.migrate`, supports performing `sum()` aggregation on `Money` types. The steps are:

1. Generate the migration by executing `mix money.gen.postgres.aggregate_functions`

2. Migrate the database by executive `mix ecto.migrate`

3. Formulate an Ecto query to use the aggregate function `sum()`

```elixir
  # Formulate the query.  Note the required use of the type()
  # expression which is needed to inform Ecto of the return
  # type of the function
  iex> q = Ecto.Query.select Item, [l], type(sum(l.price), l.price)
  #Ecto.Query<from l in Item, select: type(sum(l.price), l.price)>
  iex> Repo.all q
  [debug] QUERY OK source="items" db=6.1ms
  SELECT sum(l0."price")::money_with_currency FROM "items" AS l0 []
  [#Money<:USD, 600.00000000>]
```
**Note** that to preserve the integrity of `Money` it is not permissable to aggregate money that has different currencies.  If you attempt to aggregate money with different currencies the query will abort and an exception will be raised:
```elixir
  iex> Repo.all q
  [debug] QUERY ERROR source="items" db=4.5ms
  SELECT sum(l0."price")::money_with_currency FROM "items" AS l0 []
  ** (Postgrex.Error) ERROR 22033 (): Incompatible currency codes. Expected all currency codes to be USD
````

### Order_by with Money

Since `:money_with_currency` is a composite type, the default `order_by` results may surprise since the ordering is based upon the type structure, not the money amount.  Postgres defines a means to access the components of a composite type and therefore sorting can be done in a more predictable fashion.  For example:
```elixir
  # In this example we are decomposing the the composite column called
  # `price` and using the sub-field `amount` to perform the ordering.
  iex> q = from l in Item, select: l.price, order_by: fragment("amount(price)")
  #Ecto.Query<from l in Item, order_by: [asc: fragment("amount(price)")],
   select: l.amount>
  iex> Repo.all q
  [debug] QUERY OK source="items" db=2.0ms
  SELECT l0."price" FROM "items" AS l0 ORDER BY amount(price) []
  [#Money<:USD, 100.00000000>, #Money<:USD, 200.00000000>,
   #Money<:USD, 300.00000000>, #Money<:AUD, 300.00000000>]
```
**Note** that the results may still be unexpected.  The example above shows the correct ascending ordering by `amount(price)` however the ordering is not currency code aware and therefore mixed currencies will return a largely meaningless order.

## Installation

`Money` can be installed by adding `ex_money` to your list of dependencies in `mix.exs` and then executing `mix deps.get`

```elixir
def deps do
  [{:ex_money, "~> 1.0"}]
end
```

## Why yet another Money package?

* Fully localized formatting and rounding using [ex_cldr](https://hex.pm/packages/ex_cldr)

* Provides serialization to Postgres using a composite type and MySQL using a JSON type that keeps both the currency code and the amount together removing a source of potential error

* Uses the `Decimal` type in Elixir and the Postgres `numeric` type to preserve precision.  For MySQL the amount is serialised as a string to preserve precision that might otherwise be lost if stored as a JSON numeric type (which is either an integer or a float)

* Includes a set of financial calculations (arithmetic and cash flow calculations) that follow solid rounding rules

## Falsehoods programmers believe about prices

The [github gist](https://gist.github.com/rgs/6509585) gives a good summary of the challenges of managing money in an application. The following described how `Money` handles each of these assertions.

**1. You can store a price in a floating point variable.**

`Money` operates and serialises in a arbitrary precision Decimal value.

**2. All currencies are subdivided in 1/100th units (like US dollar/cents, euro/eurocents etc.).**

`Money` leverages CLDR which defines the appropriate number of decimal places of a currency. As of CLDR version 32 there are:

  * 52 currencies with zero decimal digits
  * 241 currencies with two decimal digits
  * 6 currencies with three decimal digits
  * and 1 currency with four decimal digits

**3. All currencies are subdivided in decimal units (like dinar/fils)**

**4. All currencies currently in circulation are subdivided in decimal units. (to exclude shillings, pennies) (counter-example: MGA)**

**5. All currencies are subdivided. (counter-examples: KRW, COP, JPY... Or subdivisions can be deprecated.)**

`Money` correctly manages the appropriate number of decimal places for a currency.  It also round correctly when formatting a currency for output (different currencies have different rounding levels for cash or transactions).

**6. Prices can't have more precision than the smaller sub-unit of the currency. (e.g. gas prices)**

All `Money` calculations are done with decimal arithmetic to the maxium precision of 28 decimal digits.

**7. For any currency you can have a price of 1. (ZWL)**

`Money` makes no assumption about the value assigned as long as its a real number.

**8. Every country has its own currency. (EUR is the best example, but also Franc CFA, etc.)**

`Money` makes no assumptions about the linkage of currencies to territories.

**9. No country uses another's country official currency as its official currency. (many countries use USD: Ecuador, Micronesia...)**

**10. Countries have only one currency.**

`Money` doesn't link territories (countries) to a currency - it focuses only on the `Money` domain.  The addon package [cldr_territories](https://github.com/Schultzer/cldr_territories) does have knowledge of what curriencies are in effect throughout history for a given territory.  See `Cldr.Territory.info/1`.

**11. Countries have only one currency currently in circulation. (Panama officially uses both PAB and USD)**

`Money` makes no assumptions about currencies in circulation.

**12. I'll only deal with currencies currently in circulation anyway.**

`Money` makes no assumptions about currencies in circulation.

**13. All currencies have an ISO 4217 3-letter code. (The Transnistrian ruble has none, for example)**

`Money` does validate currency codes against the ISO 4217 list.  Custom currencies can be created in accordance with ISO 4217 using `Cldr.Currency.new/2`.

**14. All currencies have a different name. (French franc, "nouveau franc")**

`Money` has localised names for all ISO 4217 currencies in each of the over 500 locales defined by CLDR.

**15. You always put the currency symbol after the price.**

`Money` formats currency strings according to a format mask that is either defined by CLDR or user supplied.

**16. You always put the currency symbol before the price.**

`Money` formats currency strings according to a format mask that is either defined by CLDR or user supplied.

**17. You always put the currency symbol either after, or before the price, never in the middle.**

`Money` formats currency strings according to a format mask that is either defined by CLDR or user supplied.

**18. There's only one currency symbol for any currency. (元, 角, 分 are increasing units of the Chinese renminbi.)**

`Money` uses format masks defined by CLDR which, for the Chinese renminbi uses the "￥" symbol.

**19. For a given currency, you always, but always, put the symbol in the same place.**

`Money` makes no assumpions about symbol placement.  The symbol can be places anywhere in a formatted string but is typically, for CLDR format masks, placed either before or after the formatted number.

**20. OK. But if you only use the ISO 4217 currency codes, you always put it before the price. (Hint: it depends on the language.)**

Same as for the answer to 19 above.

**21. Before the price means on the left. (ILS)**

`Money` formats according to a locale and correctly places symbols for languages written right-to-left.

**22. You can always use a dot (or a comma, etc.) as a decimal separator.**

The decimal separator is defined per locale according to the CLDR definitions.

**23. You can always use a space (or a dot, or a comma, etc.) as a thousands separator.**

The thousands (acutally grouping since not all locales format in thousands) separator is defined per locale according to the CLDR definitions.

**24. You separate big prices by grouping numbers in triplets (thousands). (One writes ¥1 0000)**

Grouping is done according the CLDR definitions.  For many languages the grouping is in thousands.  Some format other ways.  For example in India numbers are formatted with the first group as a triplet and subsequent groups as doublets.

**25. Prices at a single company will never range from five digits before the decimal to five digits after.**

`Money`'s default precision is 28 decimal digits.  All arithmetic is done using arbitrary precision decimal arithemetic.  No round is performed unless either explicitly requested or a money value is formatted for output.  When formatting rounding is applied according the locale-specific rules.

**26. Prices contains only digits and punctuation. (Germans can write 12,- €)**

`Money` format masks can contain very flexible formatting masks.  A set of formats is defined for each locale and a user-defined masks can also be defined.

**27. A price can be at most 10^N for some value of N.**

See the answer to 25.

**28. Given two currencies, there is only one exchange rate between them at any given point in time.**

`Money` supports an exchange rate mechansim, currency conversions and retrieval from external exchange rate services.  It does not impose any constraint on underlying conversion tables.

**29. Given two currencies, there is at least one exchange rate between them at any given point in time. (restriction on export of MAD, ARS, CNY, for example)**

See the answer to 28.

**30. And the final one: a standalone $ character is always pronounced dollar. (It's also the peso sign.)**

This is outside the domain of `Money`.
