# Changelog for Money v2.6.1

This is the changelog for Money v2.6.0 released on May 301st, 2018.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Enhancements

* Moves the `Jason.Encoder` protocol implementation to the protocol implementation file.  This prevents some circular compilation issues when using the `:cldr` compiler.

# Changelog for Money v2.6.0

This is the changelog for Money v2.6.0 released on May 30th, 2018.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Enhancements

* Change the definition of the `money_with_currency` composite Postgres type from `numeric(20,8)` to `numeric`.  This provides for a much wider precision and scale.  It also means that retrieving `Money.t` data from the database will be returned with the same scale as when it was stored.  Closes #67.  Thanks to @doughsay.

* Relaxes the requirements for [ex_cldr](https://hex.pm/packages/ex_cldr) and [ex_cldr_numbers](https://hex.pm/packages/ex_cldr_numbers)

* Adds json encoding for `Money.t` for [jason](https://hex.pm/packages/jason) and [poison](https://hex.pm/packages/poison)

* Fix some typespecs.  Thanks to @danschultzer.

# Changelog for Money v2.5.0

This is the changelog for Money v2.5.0 released on April 9th, 2018.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Enhancements

* Adds support for ISO4217 "X" currency codes.  Currency codes that start with "X" followed by two alphabetic characters are considered valid currency codes.  Some codes are defined, like "XAU" for "Gold".  The undefined codes are available for application-specific usage.  Note that from a `Cldr` perspective these codes are considered valid, but unknown.  This means they can be used anywhere as a currency for `Money`.  But `Cldr.known_currency?/1` will return `false` for these codes since there is no definition for them in `CLDR`.

* Adds basic support for Postgres aggregation functions using the `Money.Ecto.Composite.Type` type definition. This allows expression in Ecto such as:

```elixir
  iex> q = Ecto.Query.select Ledger, [l], type(sum(l.amount), l.amount)
  #Ecto.Query<from l in Ledger, select: type(sum(l.amount), l.amount)>
  iex> Repo.all q
  [debug] QUERY OK source="ledgers" db=6.1ms
  SELECT sum(l0."amount")::money_with_currency FROM "ledgers" AS l0 []
  [#Money<:USD, 600.00000000>]
```
This release supports only the `sum` aggregate function and only for Postgres.  A migration generator is provided that when executed with `mix ecto.migrate` will add the relevant functions to the Postgres database to support this functionality.  See the README for more information.

### Bug fixes

* Fixes some typos in the "Falsehoods programmers believe about money" section of the changelog.  Thanks to @mindseyeblind

* Fixes the calculation of the `current_interval_start_date/2` and `plan_pending?/2` when the option `:today` with a date that is not `Date.utc_today/0` is passed

# Changelog for Money v2.4.0

### Enhancements

* Update ex_cldr dependency to version 1.5.0 which uses CLDR data version 33.

* Update ex_cldr_numbers dependency to 1.4.0

* Clarify the examples of `Money.to_string/2` to note that the default locale is "en-001".  Thanks to @snewcomer. Closes #61.

# Changelog for Money v2.3.0

### Bug Fixes

* Fix the protocol implementation for `String.Chars`

### Enhancements

This version introduces a new module `Money.Subscription` that supports applications that manage subscriptions. These appications often need to support upgrading and downgrading plans.  This action involves the calculation of a credit amount from the current plan that is then applied to the new plan.  See `Money.Subscription` and `Money.Subscription.change_plan/3`.

* Add `Money.Subscription.new/3` and `Money.Subscription.new!/3` to create a new subscription with its inital plan
* Add `Money.Subscription.Plan.new/3` and `Money.Subscription.Plan.new!/3` to create a new plan
* Add `Money.Subscription.change_plan/3` and `Money.Subscription.change_plan!/3`to change subscription plans and apply any credit for unused parts of the current period
* Add `Money.Subscription.plan_days/3` to return the number of days in a plan interval
* Add `Money.Subscription.days_remaining/4` to return the number of days remaining in the current interval for a plan
* Add `Money.Subscription.next_interval_starts/3` to return the next interval start date for a subscription to a plan
* Add `Money.zero/1` that returns a `Money.t` with a zero amount in the given currency

# Changelog for Money v2.2.2

This is the changelog for Money v2.2.2 released on February 27th, 2018.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Bug Fixes

* Fix `Money.split` to ensure that `split_amount * parts + remainder == original_money` and added property testing

* Allow `Money.new/2` to have both a binary currency code and a binary amount.  Thanks to @mbenatti.  Closes #57.

# Changelog for Money v2.2.1

### Bug Fixes

* Correctly round to cash increment Money.round/2 now correctly uses the rounding increment for a currency. This is relevant for currencies like :AUD and :CHF which have minimum cash rounding of 0.05 even though the accounting increment is 0.01.  Thanks to @maennchen.  Closes #56.

* Update documentation for `Money.round/2` to correctly refer to the option `:currency_digits` with the valid options of `:cash`, `:accounting` and `:iso`.  The default is `:iso`.  The option `cash: true` is invalid.

# Changelog for Money v2.2.0

This release is primarily a refactoring of the exchange rates service.  It separates the concerns of retrieval and caching.  It also normalises the API amongst the three modules `Money.ExchangeRates`, `Money.ExchangeRates.Retriever` and `Money.ExchangeRates.Cache`.  Each of these modules implements:

  * `latest_rates/0`
  * `historic_rates/1`

This makes it clear that rates can be retrieved through the cache or the service API.  The implementation in `Money.ExchangeRates` will return the cached value if available or will call the service API if not.

### Migration from earlier releases

The only known issue for migrating from earlier releases is if your application requires a different supervision strategy for the exchange rate service that the default one.  This is documented in the README in the section "Using Ecto or other applications from within the callback module".  The change is the way in which the supervisor is defined.  It is included here for completeness:

**In prior releases:**
```
supervisor(Money.ExchangeRates.Supervisor, [])
```

**From this release onwards:**
```
supervisor(Money.ExchangeRates.Supervisor, [[restart: true, start_retriever: true]])
```
Note that the option `start_retriever: true` is optional.  The default is `false`.  The option `restart: true` is required in this case because the exchange rates supervisor is always started when `ex_money` is started even if the retriever is not started.  Therefore it needs to be stopped first before restarting in the new supervision tree.  The option `restart: true` forces this step to be executed.

### Enhancements

* Define an exchange rates cache behaviour `Money.ExchangeRates.Cache`

* Adds the config key `:exchange_rates_cache_module` which can be set to a module that implements the `Money.ExchangeRates.Cache` behaviour.  Two modules are provided:

  * `Money.ExchangeRates.Cache.Ets` (the default) and
  * `Money.ExchangeRates.Cache.Dets`

* Move all exchange rates retrieval functions to `Money.ExchangeRates.Retriever`

* Add several functions to `Money.ExchangeRates.Retriever`:

  * `:config/0` to return the current retriever configuration.
  * `reconfigure/1` to allow reconfiguration of the exchange rates retriever.
  * `start/1` to start the service. Delegates to `Money.ExchangeRates.Supervisor.start_retriever/1`.
  * `stop/0` to stop the service. Delegates to `Money.ExchangeRates.Supervisor.stop_retriever/0`.
  * `restart/0` to restart the service. Delegates to `Money.ExchangeRates.Supervisor.restart_retriever/0`.
  * `delete/0` to delete the service.  It can be started again with `start/1`. Delegates to `Money.ExchangeRates.Supervisor.delete_retriever/0`.

* If the config key `:exchange_rates_retrieve_every` is set to an `atom` rather than an `integer` then no periodic retrieval will be performed.  This allows the configuration of the following, which is also the default:

```
config :ex_money,
  exchange_rates_retrieve_every: :never
```

* Use `etag`'s in the `Money.ExchangeRates.OpenExchangeRates` API module when retrieving exchange rates from the service.

* Add `Money.known_currencies/0` which delegates to `Cldr.known_currencies/0` and returns the list of known currency codes

* Add `Money.known_current_currencies/0` to return the list of currencies currently active according to ISO 4217

* Add `Money.known_historic_currencies/0` to return a list of currencies known to Cldr but which are not considered in current use

* Add `Money.known_tender_currencies/0` to return a list of currencies defined as legal tender in Cldr

* Add the configuration key `:json_library` that specifies which json library to use for decoding json.  The default is `Cldr.Config.json_library/0` which is currently `Poison` although this is likely to change to `Jason` when `Phoenix` makes this change.

* Moves the protocol implementations for `String.Chars`, `Inspect` and `Phoenix.HTML.Safe` to a separate file so that recompilation on locale configuration change works correctly.

# Changelog for Money v2.1.0

### Enhancements

* `Money.to_integer_exp/2` now uses the definition of digits (subunits) as defined by ISO 4217.  Previously the definition was that supplied by CLDR.  CLDR's definition is not always in alignment with ISO 4217.  ISO 4217 is a firm requirement for financial transactions through payment gateways.

* Bump dependencies for `ex_cldr` to 1.4.0 and `ex_cldr_numbers` to 1.3.0 to support `:iso_digits`

# Changelog for Money v2.0.4

### Bug Fixes

* Fixed `from_float!/2` which would fail since `new/2` does not return `{:ok, Money.t}`.  Note that from `ex_money` 3.0, `Money.new/2` will return `{:ok, Money.t}` to be consistent with canonical approaches in Elixir.  Closes #48.  Thanks for @lostkobrakai.

# Changelog for Money v2.0.3

### Bug Fixes

* Fixes the typespec for `Money.new/2` and revises several other typespecs.  Added a dialyzer configuration.  Since `Money.new/2` allows flexible (probably too flexible) order or arguments, the typespec does not fully match the function implementation and Dialyzer understandably complains.  However the value of a typespec as documentation argues against making the typespec formally correct.  This will be revisited for Money 3.0.

# Changelog for Money v2.0.2

### Bug Fixes

* `Money.Sigil` was calling `String.to_existing_atom/1` directly rather than `Cldr.validate_currency/1`.  Since currency codes are only loaded and therefore the atoms materialized when `Cldr` is loaded this created a situation whereby a valid currency code may raise an `agument error`.  `Money.Sigil` now correctly calls `Cldr.validate_currency/1` which ensures the currency atoms are loaded before validation.  Closes #46.

# Changelog for Money v2.0.1

### Bug Fixes

* `Phoenix.HTML.Safe` protocol implementation correctly returns a formatted string, not an `{:ok, string}` tuple.  Closes #45.

# Changelog for Money v2.0.0

### Breaking Changes

* The function `Money.new/2` no longer supports a `float` amount.  The new function `Money.from_float/2` is introduced.  The factory function `Money.new/2` previously supported a `float` amount as a parameter.  There are many well-documented issues with float.  Although a float with a precision of no more than 15 digits will convert (and round-trip) without loss of precision there is a real possibility that the upstream calculations that produced the float will have introduced rounding or precision errors. Calling `Money.new/2` with a float amount will return an error tuple:

  ```
  {:error, {
    Money.InvalidAmountError,
      "Float amounts are not supported in new/2 due to potenial rounding " <>
      "and precision issues.  If absolutely required, use Money.from_float/2"}}
  ```

* Remove support for `Money` tuples in `Money.Ecto.Composite.Type` and `Money.Ecto.Map.Type`.  Previously there has been support for dumping `Money` in a tuple format.  This support has now been removed and all `Money` operations should be based on the `Money.t` struct.

### Enhancements

* Add `Money.from_float/2` to create a `Money` struct from a float and a currency code.  This function is named to make it clear that we risk losing precision due to upstream rounding errors.  According to the standard and experimentation, floats of up to 15 digits of precision will round trip without error.  Therefore `from_float/2` will check the precision of the number and return an error if the precision is greater than 15 since the correctness of the number cannot be verified beyond that.

* Add `Money.from_float!/2` which is like `from_float/2` but raises on error

* Formatted the text the with the Elixir 1.6 code formatter
