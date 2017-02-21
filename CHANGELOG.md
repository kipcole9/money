## Changelog for Ex_Money v0.0.13 February 21, 2017

### Enhancements

* Adds a alternative type `Money.Ecto.Map.Type` to support serializing `%Money{}` types to databases that do not support composite types but do support Ecto map types.

* Renamed `Money.Ecto.Type` to `Money.Ecto.Composite.Type` to more clearly reflect the underlying implementation and to differentiate from the new map type implementation.

* Renamed the migration task that creates the composite type in Postgres to `Money.Gen.Postgres.Migration` since it is only applicable to Postgres.

* Supports `cast`ing maps that have both "currency" and "amount" keys into Ecto changesets which is helpful for pattern matching and changesets.

## Changelog for Ex_Money v0.0.12 February 20, 2017

### Enhancements

* Updates `Ecto` dependency to `~> 2.1`

### Bugfixes

* Updates `ex_cldr` dependency to v0.0.18 which fixes pluralization of `%Decimal{}` types

## Changelog for Ex_Money v0.0.11 December 12, 2016

### Enhancements

* `:exchange_rate_service` is false by default.  This is a change from previous releases that configured the service on by default

* Removed dependency on HTTPoison, uses the built-in `:httpc` module instead since the requirements are simple

### Bugfixes

* Updates ex_cldr to v0.0.15 which fixes error in Financial.periods()

* `:open_exchange_rates_app_id` is not long reqired to be specified  in order for compilation to complete

* declares Ecto as an optional dependency which should fix the compilation order and therefore result in the ecto migration Mix task and the Ecto type to be available after installation without a forced recompile/

## Changelog for Ex_Money v0.0.10 December 11, 2016

### Bugfixes

* Update dependency for :ex_cldr to v0.0.13 since v0.0.12 was preventing compilation when Plug was loaded

## Changelog for Ex_Money v0.0.7 November 23, 2016

### Enhancements

* Add optional callback module that defines a `rates_retrieved/2` function that is invoked on each successful retrieval of exchange rates

## Changelog for Ex_Money v0.0.6 November 21, 2016

### Enhancements

* Add present_value and future_value for a list of cash flows

* Add net_present_value for an investment and a list of cash flows

* Add net_present_value for an investment, payment, interest rate and periods

* Add internal_rate_of_return for a list of cash flows

* Add exchange rate retrieval and currency conversion support

## Changelog for Ex_Money v0.0.5 October 8, 2016

### Enhancements

* Adds a set of financial functions defined in `Money.Financial`

* Adds a sigil `~M` defined in `Money.Sigil`

* Adds the `Phoenix.HTML.Safe` protocol implementation

## Changelog for Ex_Money v0.0.4 October 8, 2016

### Bug Fixes

* Removed ambiguous and unhelpful function Money.rounding/0

### Enhancements

* Added usage examples and doctests

* Improved documentation in several places to make the intent clearer

* Made the SQL in the migration clearer for the output when the migration is run

