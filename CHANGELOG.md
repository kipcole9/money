# Changelog for Money v2.3.0

This is the changelog for Money v2.3.0 released on _, 2018.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

This release is primarily a refactoring of the exchange rates service.  It separates the concerns of retrieval and caching.  It also normalises the api amongst the three modules `Money.ExchangeRates`, `Money.ExchangeRates.Retriever` and `Money.ExchangeRates.Cache`.  Each of these modules implements:

  * `latest_rates/0`
  * `historic_rates/1`

This makes it clear that rates can be retrieved through the cache or the service API.  The implementation in `Money.ExchangeRates` will return the cached value if available or will call the service API if not.

### Migration from earlier versions

* If your current configuration relies upon the default exchange rates retrieval occurring then from this release forward you will need to explicity specify the retrieval period.  The default value has been changed to `:never`. For example:

```
config :ex_money,
  exchange_rates_retrieve_every: 300_000
```

### Deprecation

* The configuration option `:auto_start_exchange_rate_service` is deprecated.  The service is always started since rates can be retrieved synchronously on demand via `Money.ExchangeRates.Retriever.latest_rates/0` or periodically as defined by the configuration option `:exchange_rates_retrieve_every`

### Enhancements

* Print an informative message and raises at compile time if the configured json library appears to not be configured.

* Move exchange rate caching to its own module `Money.ExchangeRates.Cache`

* Move all exchange rates retrieval functions to `Money.ExchangeRates.Retriever`

* Add `Money.ExchangeRates.Retriever.reconfigure/1` to allow reconfiguration of the exchange rates retriever.

* Add `Money.ExchangeRates.Retriever.config/0` to return the current retriever configuration.

* If the config key `:exchange_rates_retrieve_every` is set to an `atom` rather than an `integer` then no periodic retrieval will be performed.  This allows the configuration of the following, which is also the default:

```
config :ex_money,
  exchange_rates_retrieve_every: :never
```

* Use `etag`s in the `Money.ExchangeRates.OpenExchangeRates` api module when retrieving exchange rates from the service.

# Changelog for Money v2.2.0

### Enhancements

* Add `Money.known_currencies/0` which delegates to `Cldr.known_currencies/0` and returns the list of known currency codes

* Add `Money.known_current_currencies/0` to return the list of currencies currently active according to ISO 4217

* Add `Money.known_historic_currencies/0` to return a list of currencies known to Cldr but which are not considered in current use

* Add `Money.known_tender_currencies/0` to return a list of currencies defined as legal tender in Cldr

* Add the configuration key `:json_library` that specifies which json library to use for decoding json.  The default is `Cldr.Config.json_library/0` which is currently `Poison` although this is likely to change to `Jason` when `Phoenix makes this change.

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
