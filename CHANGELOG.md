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
