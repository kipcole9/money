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
    default_cldr_backend: Test.Cldr
  end
```
