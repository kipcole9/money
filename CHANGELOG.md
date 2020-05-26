# Changelog for Money v5.1.0

This is the changelog for Money v5.1.0 released on May 26th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Enhancements

* Extract default currency from locale when calling `Money.parse/2` on a money string. The updated docs now say:

  * `:default_currency` is any valid currency code or `false`
    that will used if no currency code, symbol or description is
    indentified in the parsed string. The default is `nil`
    which means that the default currency associated with
    the `:locale` option will be used. If `false` then the
    currency assocated with the `:locale` option will not be
    used and an error will be returned if there is no currency
    in the string being parsed.

* Add certificate verification for exchange rate retrieval

# Changelog for Money v5.0.2

This is the changelog for Money v5.0.2 released on April 29th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Bug Fixes

* Update the application supervisor spec

# Changelog for Money v5.0.1

This is the changelog for Money v5.0.1 released on January 28th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Bug Fixes

* Make `nimble_parsec` a required dependency since it is required for parsing money amounts. Thanks to @jonnystoten for the report.

# Changelog for Money v5.0.0

This is the changelog for Money v5.0.0 released on January 21st, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Breaking changes

* Elixir 1.10 introduces semantic sorting for stucts that depends on the availability of a `compare/2` function that returns `:lt`, `:eq` or `:gt`.  Therefore in this release of `ex_money` the functions `compare/2` and `compare!/2` are swapped with `cmp/2` and `cmp!/2` in order to conform with this expectation. Now `compare/2` will return `:eq`, `:lt` or `:gt`. And `cmp/2` return `-1`, `0` or `1`.

* Deprecate `Money.reduce/1` in favour of `Money.normalize/1` to be consistent with `Decimal` versions `1.9` and later.

It is believed and tested that `Money` version `5.0.0` is compatible with all versions of `Decimal` from `1.6` up to the as-yet-unreleased `2.0`.

### Support of Elixir 1.10 Enum sorting

From Elixir verison `1.10.0`, several functions in the `Enum` module can use the `Money.compare/2` function to simplify sorting. For example:

```
iex> list = [Money.new(:USD, 100), Money.new(:USD, 200)]
[#Money<:USD, 100>, #Money<:USD, 200>]
iex> Enum.sort list, Money
[#Money<:USD, 100>, #Money<:USD, 200>]
iex> Enum.sort list, {:asc, Money}
[#Money<:USD, 100>, #Money<:USD, 200>]
iex> Enum.sort list, {:desc, Money}
[#Money<:USD, 200>, #Money<:USD, 100>]
```
**Note that `Enum.sort/2` will sort money amounts even when the currencies are incompatible. In this case the order of the result is not predictable. It is the developers responsibility to filter the list to compatible currencies prior to sorting. This is a limitation of the `Enum.sort/2` implementation.**

### Notes on Decimal version support

* `ex_money` version `5.0.0` is compatible with `Decimal` versions from `1.6` onwards. In `Decimal` version `2.0` the same changes to `compare/2` and `cmp/2` will occur and in `Decimal` version `1.9`, `Decimal.cmp/2` is deprecated.  `ex_money` version `5.0.0` detects these different versions of `Decimal` and therefore remains compatability with `Decimal` back to version `1.6`.

# Changelog for Money v4.4.2

This is the changelog for Money v4.4.2 released on January 2nd, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Bug Fixes

* Remove calls to `Code.ensure_compiled?/1` since it is deprecated in Elixir 1.10. Use instead `Cldr.Config.ensure_compiled?/1` which is added as a private API in `Cldr` version 2.12.0. This version of `Cldr` now becomes the minimum version required.

* Remove spurious entries in `.dialyzer_ignore_warnings` - no entries are required and dialyzer is happy.

# Changelog for Money v4.4.1

This is the changelog for Money v4.4.1 released on November 10th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Bug Fixes

* Fixes money parsing error. Thanks to @Doerge. Closes #112.

# Changelog for Money v4.4.0

This is the changelog for Money v4.4.0 released on November 6th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Breaking Change

* `Money.parse/2` until this release supported the `:currency_filter` option. It allowed for currencies to be filtered based upon their attributes (`:all`, `:current`, `:historic`, `:tender`, `:annotated`). When multiple attributes were passed in a list, a currency had to meet all of these attributes. From this release onwards, multiple attributes items are `or`ed, not `and`ed. It is expected this option is used extremely rarely and therefore of limited impact.

### Enhancements

* `Money.parse/2` now includes the option `:default_currency` which allows for parsing a number only (without a currency code) and it will be tagged with the `:default_currency`.
```elixir
  iex> Money.parse("100")
  {:error,
   {Money.Invalid,
    "A currency code, symbol or description must be specified but was not found in \"100\""}}
  iex> Money.parse("100", default_currency: :USD)
  #Money<:USD, 100>
```

* Add `:only` and `:except` options to `Money.parse/2` to specify which currency codes or currency attributes are permitted.  `:only` and `:except` replace the option `:currency_filter` which is now deprecated. If provided, `:currency_filter` is interpreted as `:only`. An example:
```elixir
  iex> Money.parse("100 usd", only: :current, except: :USD)
  {:error,
   {Money.UnknownCurrencyError,
    "The currency \"usd\" is unknown or not supported"}}
```

* `Money.parse/2` now supports negative money amounts.
```elixir
  iex> Money.parse("chf -100")
  #Money<:CHF, -100>

  iex> Money.parse("(chf 100)")
  #Money<:CHF, -100>
```
* The money parser has been rewritten using [nimble_parsec](https://hex,pm.packages/nimble_parsec)

# Changelog for Money v4.3.0

This is the changelog for Money v4.3.0 released on September 8th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Enhancements

* Adds a `Money` backend in the same spirit as other libraries that leverge [ex_cldr](https://hex,pm/packages/ex_cldr). Thanks to @Lostkobrakai. Closes #108. All of the functions in the `Money` module may also be called on a backend module `<backend>.Money.fun` without having to specify a backend module since this is implicit.

### Bug Fixes

* `Money.new!/3` replaces `Money.new!/2` to accept options. Thanks to @Lostkobrakai. Closes #109.

# Changelog for Money v4.2.2

This is the changelog for Money v4.2.2 released on September 7th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Bug Fixes

* Use `Keyword.get_lazy` when the default is `Cldr.default_backend/0` to avoid exceptions when no default backend is configured. Thanks to @Lostkobrakai. Closes #108.

# Changelog for Money v4.2.1

This is the changelog for Money v4.2.1 released on September 2nd, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Bug Fixes

* Fixes parsing of money amount that have a single digit amount. Closes #107.  Thanks to @njwest

# Changelog for Money v4.2.0

This is the changelog for Money v4.2.0 released on 21 August, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Bug Fixes

* Move the `Money.Migration` module to [ex_money_ecto](https://hex.pm/packages/ex_money_sql) where it belongs

### Enhancements

* `Money.default_backend/0` will now either use the backend configured under the `:default_cldr_backend` key of `ex_money` or `Cldr.default_backend/0`. In either case an exeption will be raised if no default backend is configured.

# Changelog for Money v4.1.0

This is the changelog for Money v4.1.0 released on July 13th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Enhancements

* Adds `Money.abs/1`. Thanks to @jeremyjh.

* Improve `@doc` consistency using `## Arguments` not `## Options`.

# Changelog for Money v4.0.0

This is the changelog for Money v4.0.0 released on July 8th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Breaking Changes

* Functions related to the serialization of money types have been extracted to the library [ex_money_sql](https://hex.pm/packages/ex_money_sql).  For applications using the dependency `ex_money` that *do not* require serialization no changes are required.  For applications using serialization, the dependency should be changed to `ex_money_sql` (which in turn depends on `ex_money`).

* Supports Elixir 1.6 and later only

# Changelog for Money v3.4.4

This is the changelog for Money v3.4.4 released on June 2nd, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Enhancements

* Supports passing an `Cldr.Number.Formation.Options.t` as alternative to a `Keyword.t` for options to `Money.to_string/2`.  Performance is doubled when using pre-validated options which is useful if formatting is being executed in a tight loop.

An example of this usage is:

```elixir
  iex> money = Money.new(:USD, 100)

  # Apply any options required as a keyword list
  # Money will take care of managing the `:currency` option
  iex> options = []

  iex> {:ok, options} = Cldr.Number.Format.Options.validate_options(0, backend, options)
  iex> Money.to_string(money, options)
```

The `0` in `validate_options` is used to determine the sign of the amount because that can influence formatting - for example the accounting format often uses `(1234)` as its format.  If you know your amounts are always positive, just use `0`.

If the use case may have both positive and negative amounts, generate two option sets (one with the positive number and one with the negative).  Then use the appropriate option set.  For example:

```elixir
  iex> money = Money.new(:USD, 1234)

  # Add options as required
  # Money will take care of managing the `:currency` option
  iex> options = []

  iex> {:ok, positive_options} = Cldr.Number.Format.Options.validate_options(0, backend, options)
  iex> {:ok, negative_options} = Cldr.Number.Format.Options.validate_options(-1, backend, options)

  iex> if Money.cmp(money, Money.zero(:USD)) == :gt do
  ...>   Money.to_string(money, positive_options)
  ...> else
  ...>   Money.to_string(money, negative_options)
  ...> end
```

# Changelog for Money v3.4.3

This is the changelog for Money v3.4.3 released on June 2nd, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Bug Fixes

* Ensure `Money.to_string!/2` properly raises

* Add specs for `Money.to_string/2` and `Money.to_string!/2`

Thanks to @rodrigues for the report and PR.

# Changelog for Money v3.4.2

This is the changelog for Money v3.4.2 released on April 16th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Bug Fixes

* `Money.put_fraction/2` now correctly allows setting the fraction to 0.

### Enhancements

* `Money.round/2` allows setting `:currency_digits` to an integer number of digits in addition to the options `:iso`, `:cash` and `:accounting`.  The default remains `:iso`.

* Improves the documentation for `Money.to_string/2`.

# Changelog for Money v3.4.1

This is the changelog for Money v3.4.1 released on April 5th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Bug Fixes

* Fix `README.md` markdown formatting error.  Thanks to @fireproofsocks for the report and @lostkobrakai for the fix.  Closes #99.

# Changelog for Money v3.4.0

This is the changelog for Money v3.4.0 released on March 28th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Enhancements

* Updates to [CLDR version 35.0.0](http://cldr.unicode.org/index/downloads/cldr-35) released on March 27th 2019 through `ex_cldr` version 2.6.0.

# Changelog for Money v3.3.1

This is the changelog for Money v3.3.1 released on March 8th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Bug Fixes

* Fix or silence dialyzer warnings

# Changelog for Money v3.3.0

This is the changelog for Money v3.3.0 released on February 24th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Enhancements

* Adds `Money.put_fraction/2`. This will set the fractional part of a money to the specified integer amount.  Examples:
```
  iex> Money.put_fraction Money.new(:USD, "2.49"), 99
  #Money<:USD, 2.99>

  iex> Money.put_fraction Money.new(:USD, "2.49"), 999
  {:error,
   {Money.InvalidAmountError, "Rounding up to 999 is invalid for currency :USD"}}
```

### Bug Fixes

* Parsing money strings now uses a more complete set of character definitions for decimal and grouping separators based upon the `characters.json` file of the "en" locale.

# Changelog for Money v3.2.4

This is the changelog for Money v3.2.4 released on February 13th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Bug Fixes

* Updates to [ex_cldr_currencies version 2.1.2](https://hex.pm/packages/ex_cldr_currencies/2.1.2) which correctly removes duplicate currency strings when the same string referred to different currency codes. See the [changelog](https://github.com/kipcole9/cldr_currencies/blob/v2.1.2/CHANGELOG.md) for further detail.

### Enhancements

* Adds a `:fuzzy` option to `Money.parse/2` that uses `String.jaro_distance/2` to help determine if the provided currency text can be resolved as a currency code.  For example:
```
  iex> Money.parse("100 eurosports", fuzzy: 0.8)
  #Money<:EUR, 100>

  iex> Money.parse("100 eurosports", fuzzy: 0.9)
  {:error,
   {Money.Invalid, "Unable to create money from \\"eurosports\\" and \\"100\\""}}
```

# Changelog for Money v3.2.3

This is the changelog for Money v3.2.3 released on February 12th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Bug Fixes

* Correctly parse money strings with unicode currency symbols like "€". Closes #95.  Thanks to @crbelaus.

# Changelog for Money v3.2.2

This is the changelog for Money v3.2.2 released on February 10th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Enhancements

* Improves parsing of money strings. Parsing now uses various strings that [CLDR](https://cldr.unicode.org) knows about.  Some examples:

```
  iex> Money.parse "$au 12 346", locale: "fr"
  #Money<:AUD, 12346>
  iex> Money.parse "12 346 dollar australien", locale: "fr"
  #Money<:AUD, 12346>
  iex> Money.parse "A$ 12346", locale: "en"
  #Money<:AUD, 12346>
  iex> Money.parse "australian dollar 12346.45", locale: "en"
  #Money<:AUD, 12346.45>
  iex> Money.parse "AU$ 12346,45", locale: "de"
  #Money<:AUD, 12346.45>

  # Can also return the strings available for a given currency
  # and locale
  iex> Cldr.Currency.strings_for_currency :AUD, "de"
  ["aud", "au$", "australischer dollar", "australische dollar"]

  # Round trip formatting also seems to be ok
  iex> {:ok, string} = Cldr.Number.to_string 1234, Money.Cldr, currency: :AUD
  {:ok, "A$1,234.00"}
  iex> Money.parse string
  #Money<:AUD, 1234.00>
```
# Changelog for Money v3.2.1

This is the changelog for Money v3.2.1 released on February 2nd, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Bug Fixes

* Added `Money.Ecto.Composite.Type.cast/1` and `Money.Ecto.Map.Type.cast/1` for a `String.t` parameter. When a `String.t` is provided, `cast/1` will call `Money.parse/2` to create the `Money.t`.

* `Money.new/3` now uses the current locale on the default backend if no locale or backend is specified. This means that `Money.Ecto.Composite.Type.cast/1` and `Money.Ecto.Map.Type.cast/1` will be parsed using the locale that has been set for the current process in the default backend. As a result, a simple `type=text` form field can be used to input a money type (currency code and amount in a single string) that can then be cast to a `Money.t`.

# Changelog for Money v3.2.0

This is the changelog for Money v3.2.0 released on February 1st, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Bug Fixes

* Correctly generate `migrations_path/1` function based upon whether `Ecto` is configured and which version

### Enhancements

* Adds `Money.parse/2` which will parse a string comprising a currency code and an amount. It will return a `Money.t` or an error.  This function may be helpful in supporting money input in HTML forms.

# Changelog for Money v3.1.0

This is the changelog for Money v3.1.0 released on December 30th, 2018.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Bug Fixes

* Fix typo in `exchange_rates_retriever.ex`.  Thanks to @lostkobrakai.  Closes #91.

* Remove obsolete `cldr` compiler

* Changes the `sum` aggregate function for `money_with_currency` to be `STRICT` which means it handles `NULL` columns in the same way as the standard `SUM` function.  Thanks to @lostkobrakai.  Closes #88.

* Fixes documentation link errors

* Fix unhandled terminate typo error in exchange rates server. Thanks to @xavier. Closes #90.

# Changelog for Money v3.0.0

This is the changelog for Money v3.0.0 released on November 23rd, 2018.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

The primary purpose of this release is to support ex_cldr version 2.0

### Breaking changes

* `Money.from_tuple/1` has been removed
* Uses [ex_cldr](https://hex.pm/packages/ex_cldr/2.0.0) version 2.  Please see [the changelog](https://github.com/kipcole9/cldr/blob/v2.0.1/CHANGELOG.md#migrating-from-cldr-1x-to-cldr-version-2x) for configuration changes that are required.
* Requires a default_cldr_backend to be configured in `config.exs`.  For example:
```
  config :ex_money,
    ...
    default_cldr_backend: MyApp.Cldr
  end
```
