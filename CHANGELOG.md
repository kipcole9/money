# Changelog for Cldr v3.4.0

This is the changelog for Cldr v3.4.0 released on March 28th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/cldr/tags)

### Enhancements

* Updates to [CLDR version 35.0.0](http://cldr.unicode.org/index/downloads/cldr-35) released on March 27th 2019 through `ex_cldr` version 2.6.0.

# Changelog for Cldr v3.3.1

This is the changelog for Cldr v3.3.1 released on March 8th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/cldr/tags)

### Bug Fixes

* Fix or silence dialyzer warnings

# Changelog for Cldr v3.3.0

This is the changelog for Cldr v3.3.0 released on February 24th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/cldr/tags)

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
