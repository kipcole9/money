# Changelog for Money v1.0.0-rc.1

This is the changelog for Money v1.0.0-rc.1 released on November __th, 2017.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

This version signals API stability and the first release candidate.

## Enhancements

* Updated [ex_cldr](https://hex.pm/packages/ex_cldr) to version 1.0.0-rc.0

* Ensure that `cast/1` is consistent in type checking for both type adapters (Postgres and MySQL)

## Bug Fixes

* Allow string values for an amount for `Money.new/2` as long as the `currency_code` is an atom.

* Improve the error message if `Money.new/2` can't disambiguate the arguments.  Thanks to @ssomnoremac.  Closes #37.

