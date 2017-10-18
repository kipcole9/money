# Changelog

## Money v0.6.1 October 18th, 2017

### Enhancements

* Upgrade to `ex_doc` in support of module grouping. (thanks to @lostkobrakai)

* Add support for string keys in conversion maps. (thanks to @schultzer)

* Update dependencies to those that don't warn on Elixir 1.5

## Money v0.6.0 September 20th, 2017

### Breaking Changes

* The tuple form of `Money.new/1` has been renamed to `Money.from_tuple/1` to better align with the standard lib and to make clearer that the primary public api for creating a Money struct is `Money.new/2` Closes #30 (thanks to @lostkobrakai)

### Enhancements

* Move supervisor to new module `Money.Application`.  Closed #29 (thanks to @lostkobrakai)

### Bug Fixes

* Fix typespec for `%Money{}` to use `Decimal.t`.  Closes #26 (thanks to @lostkobrakai)

* Add `@enforce_keys [:currency, :amount]`. Closes #27  (thanks to @lostkobrakai)

* Wrap `Money.Ecto.Composite.Type` and `Money.Ecto.Map.Type` in `Code.ensure_loaded?1` rather than just wrapping the functions. Closes #28 * (thanks to @lostkobrakai)

## Money v0.5.3 September 18th, 2017

### Enhancements

* Update to [ex_cldr](https://hex.pm/packages/ex_cldr) version 0.7.0 and add [ex_cldr_numbers](https://hex.pm/packages/ex_numbers) version 0.1.0

## Money v0.5.2  September 13th,  2017

### Enhancements

* Make `Decimal` dependency explicit

## Money v0.5.1  September 4th,  2017

### Enhancements

* Update to [ex_cldr](https://hex.pm/packages/ex_cldr) version 0.6.2

## Money v0.5.0  August 24,  2017

### Breaking Changes

* `Money` now requires Elixir 1.5 as a minimum

* `Money.to_string./2` now returns either `{:ok, string}` or `{:error, reason}`.  Use `Money.to_string!/2` to return the string or raise an exception.

### Enhancements

* Update to [ex_cldr](https://hex.pm/packages/ex_cldr) version 0.5.2.  See the [changelog](https://github.com/kipcole9/cldr/blob/v0.5.2/CHANGELOG.md) for more information.

* Add `Money.to_string!/2`

## Money v0.4.3  August 14,  2017

### Bug Fixes

* Fix `dev.exs` and `test.exs` configuration keys for `exchange_rates_retrieve_every`

## Money v0.4.2  July 9,  2017

### Bug Fixes

* Add missing guard clause in `Money.new!/2`. Thanks to Ryan Winchester.  Fixes #20.

### Enhancements

* Adds support for both atom and binary map keys for casting.  Thanks to Ryan Winchester.

## Money v0.4.1  July 9,  2017

### Enhancements

* Updates `ex_cldr` dependency to 0.4.2 which fixes an issue whereby a default locale that had not previously been installed would not compile.

* Updates documentation for `Money.new/2` to make it clear that the `currency_code` and `amount` arguments can be in any order.

## Money v0.4.0  July 3,  2017

### Breaking Change

It's a breaking change but not a huge one.  `Money.ExchangeRates.Retriever` had a nasty code smell - it was retrieving rates during the initialisation of the process which had nasty side-effects if the retrieval stalled or crashed.  The new and improved strategy uses `Process.send_after/3` in the `init/1` function with a configurable delay before that first retrieval.

The configuration key is `:delay_before_first_retrieval` with a default of 100 milliseconds.  If set to anything other than a positive integer then the initial retrieval is not done - retrieval commences with the next cycle of the configured `:retrieve_every` interval.

For library users the key consideration here is that exchange rates cannot be assumed to be available when your application starts.

### Enhancements

* A new function `Money.ExchangeRates.retrieve/0` is available to schedule rate retrieval immediately.

* A new function `Money.ExchangeRates.rates_available?/0` that returns `true` if rates are available and `false` otherwise.

## Money v0.3.0  June 26,  2017

I know, its not great to have two releases with breaking changes in quick succession.  But the fact that the functions in `Money.{Arithmetic, Conversion, Financial}` were being included via a `__using__` macro just wasn't clean and the modules weren't so large as to be a serious issue.

The refactoring moves `Money.{Arithmetic, Conversion}` functions into `Money` so there's no breaking change to the API there.  `Money.Financial` functions are kept separately and need to be invoked on that module, not on `Money` - this part is a breaking change.

### Breaking changes

* `Money.Financial` functions are no longer included in the `Money` module.  This means they must be invoked on `Money.Financial` rather than on `Money`.

### Enhancements

* Solid improvement in test coverage but still more work to do.

```
  COV  FILE                                        LINES RELEVANT   MISSED
  0.0% lib/mix/tasks/money_postgres_migration.e       64       17       17
 96.6% lib/money.ex                                  809       89        3
 70.0% lib/money/ecto/money_ecto_composite_type       84       10        3
  0.0% lib/money/ecto/money_ecto_map_type.ex          61        4        4
 50.0% lib/money/exception.ex                         15        2        1
  0.0% lib/money/exchange_rates/callback_module       23        0        0
  0.0% lib/money/exchange_rates/exchange_rate_s       18        3        3
 57.1% lib/money/exchange_rates/exchange_rates.      109        7        3
 80.0% lib/money/exchange_rates/exchange_rates_       81       20        4
 37.5% lib/money/exchange_rates/open_exchange_r       57        8        5
 73.0% lib/money/financial.ex                        331       37       10
100.0% lib/money/sigil.ex                             32        3        0
100.0% test/support/exchange_rate_callback_modu        8        1        0
 50.0% test/support/exchange_rate_mock.ex             26        2        1
[TOTAL]  73.4%
```

### Bug Fixes

* `Money.new!(decimal, currency)` and `Money.new!(currency, decimal)` were recursing infinitely.  This is now fixed and new tests added.
>>>>>>> 95074cfc608ebc60467755fa73a5a7b6a2b54609

## Money v0.2.0  June 25,  2017

### Breaking changes

Arithmetic and comparion functions now return a `{:ok, result}` tuple on success and an `{:error, reason}` tuple on error.  "Bang" methods are provided that either return a simple result or raise on error.  This change is to better align with idiomatic Elixir/Erlang behaviour.

For most applications, change calls to the "bang" methods should keep the behaviour of versions in the 0.1.x releases.

### Enhancements

* `add/2`, `sub/2`, `mult/2`, `div/2`, `cmp/2`, `compare/2`, `convert_to/3` now return an `{:ok, result}` or `{:error, reason}` tuple that than a simple rest on success and raise an exception on error.

* new methods `add!/2`, `sub!/2`, `mult!/2`, `div!/2`, `cmp!/2`, `compare!/2`, `convert_to!/3` are added the provide the original behaviour, returning a simple value or raising an exception on error.

* Improved the formatting and parameter names for several functions and made several pipelines more idiomatic. Thanks to Xavier Defrang.

* Documented the way to manually configure the exchange rates supervision tree.  This is useful if the configured `callback_module` depends upon other applications being started.  This would be tue, for example, if the `callback_module` uses an Ecto repo.

## Bug Fixes

* Changed the `config` key `open_exchange_rates_retrieve_every` to be `300_000` to align with the documented 5 minutes interval.  Thanks to Andrew Phillipo.

## Money v0.1.7 June 21,  2017

### Bug Fixes

* Starts :inets application first so that the default exchange rate retriever can start in a release by preventing a circular start dependency between :inets and :exchange_rates_retriever.  Thanks to Peter Krenn.

## Money v0.1.6 June 20,  2017

Update dependencies to align with the requirements for Elixir 1.4.4 (all tests are passing on this release).

### Bug Fixes

* Fix README reference to the postgres migration generator name which is  `money.gen.postgres.migration`.  Thanks to Andrew Phillipo.

### Enhancements

* Make the configuration dynamic by removing a dependence on module attributes.  Thanks to Xavier Defrang

## Money v0.1.5 June 7,  2017

### Bug Fixes

* Fix missing comma in readme example configuration [Closed #10].  Thanks to Xavier Defrang.

## Money v0.1.4 May 29, 2017

### Enhancements

* Updated to `ex_cldr` version 0.4.0

## Money v0.1.3 April 27, 2017

### Enhancements

* Updated to `ex_cldr` version 0.2.0

* Supported only on Elixir 1.4.x

## Money v0.1.2 April 17, 2017

### Enhancements

* Updated to `ex_cldr` version 0.1.3 to reflect updated CLDR repository version 30.0.1 and revised api for `Cldr.Currency.validate_currency_code/1`

## Money v0.1.1 April 11, 2017

### Enhancements

* Improves error handing for exchange rates and conversions in the case where either the exchange rate service is not running or there is no available rate for a given currency

* Improve the error handling related to Ecto loading, dumping and casting.  This is a more robust approach to maintaining data integrity by ensuring only valid currency codes are loaded, dumped or casted.

### Bug Fixes

* Bump `ex_cldr` dependency to version 0.1.2.  This fixes the issue where the atoms representing value currency codes would not be loaded early enough to be available for `known_locale?/1`

## Money v0.1.0 April 8, 2017

Minor version is bumped to reflect the change in behaviour of `Money.new/2` which now returns an error tuple if the currency code is invalid rather than raising an exception.

### Enhancements

* `Money.new/2` now returns an error tuple of the form `{:error, {exception, message}}` if the currency code is invalid rather than the old behaviour of raising an exception.

* `Money.new!/2` is added that provides the previous default behaviour of raising an exception if the currency code is invalid.

* Depends on `ex_cldr` at version 0.1.1 which provides enhanced currency code validation checking that allows duplicate code in `ex_money` to be removed.

## Money v0.0.16 April 7, 2017

### Bug Fixes

* Fixes the case where an example of `Money.new("USD", 100)` could fail because the list of `atom` currency codes had not been loaded.  The list is now force-loaded at compile time.

## Money v0.0.15 March 23, 2017

### Enhancements

* Bump `ex_cldr` dependency version to 0.1.0 which includes CLDR repository version 31.0.0

## Money v0.0.14 February 27, 2017

### Bugfixes

* Bump dependency requirement for `ex_cldr` to at least 0.0.20 since 0.0.19 omits `version.json`

## Money v0.0.13 February 21, 2017

### Enhancements

* Adds a alternative type `Money.Ecto.Map.Type` to support serializing `%Money{}` types to databases that do not support composite types but do support Ecto map types.

* Renamed `Money.Ecto.Type` to `Money.Ecto.Composite.Type` to more clearly reflect the underlying implementation and to differentiate from the new map type implementation.

* Renamed the migration task that creates the composite type in Postgres to `Money.Gen.Postgres.Migration` since it is only applicable to Postgres.

* Supports `cast`ing maps that have both "currency" and "amount" keys into Ecto changesets which is helpful for pattern matching and changesets.

## Money v0.0.12 February 20, 2017

### Enhancements

* Updates `Ecto` dependency to `~> 2.1`

### Bugfixes

* Updates `ex_cldr` dependency to v0.0.18 which fixes pluralization of `%Decimal{}` types

## Money v0.0.11 December 12, 2016

### Enhancements

* `:exchange_rate_service` is false by default.  This is a change from previous releases that configured the service on by default

* Removed dependency on HTTPoison, uses the built-in `:httpc` module instead since the requirements are simple

### Bugfixes

* Updates ex_cldr to v0.0.15 which fixes error in Financial.periods()

* `:open_exchange_rates_app_id` is not long reqired to be specified  in order for compilation to complete

* declares Ecto as an optional dependency which should fix the compilation order and therefore result in the ecto migration Mix task and the Ecto type to be available after installation without a forced recompile/

## Money v0.0.10 December 11, 2016

### Bugfixes

* Update dependency for :ex_cldr to v0.0.13 since v0.0.12 was preventing compilation when Plug was loaded

## Money v0.0.7 November 23, 2016

### Enhancements

* Add optional callback module that defines a `rates_retrieved/2` function that is invoked on each successful retrieval of exchange rates

## Money v0.0.6 November 21, 2016

### Enhancements

* Add present_value and future_value for a list of cash flows

* Add net_present_value for an investment and a list of cash flows

* Add net_present_value for an investment, payment, interest rate and periods

* Add internal_rate_of_return for a list of cash flows

* Add exchange rate retrieval and currency conversion support

## Money v0.0.5 October 8, 2016

### Enhancements

* Adds a set of financial functions defined in `Money.Financial`

* Adds a sigil `~M` defined in `Money.Sigil`

* Adds the `Phoenix.HTML.Safe` protocol implementation

## Money v0.0.4 October 8, 2016

### Bug Fixes

* Removed ambiguous and unhelpful function Money.rounding/0

### Enhancements

* Added usage examples and doctests

* Improved documentation in several places to make the intent clearer

* Made the SQL in the migration clearer for the output when the migration is run

