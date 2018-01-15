# Changelog for Money v2.0.1

This is the changelog for Money v2.0.1 released on January 16th, 2017.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

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
