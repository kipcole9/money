# Changelog for Money v2.1.0

This is the changelog for Money v2.0.4 released on _, 2017.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Enhancements

* `Money.to_integer_exp/1` is now `Money.to_integer/2`

* `Money.to_integer/2` now uses the definition of digits (subunits) as defined by ISO 4217.  Previously the definition was that supplied by CLDR.  CLDR's definition is not always in alignment with ISO 4217.  ISO 4217 is a firm requirement for financial transactions through payment gateways.

* Note that the dependencies for `ex_cldr` and `ex_cldr_numbers` have been bumped accordingly.

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
