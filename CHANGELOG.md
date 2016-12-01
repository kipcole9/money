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

