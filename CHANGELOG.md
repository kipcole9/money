# Changelog for Money v1.1.1

This is the changelog for Money v1.1.1 released on December 31st 2017.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

## Enhancements

* Format the code using the Elixir code formatter

# Changelog for Money v1.1.0

## Changes & Deprecations

* The configuration option `:exchange_rate_service` is deprecated in favour of `:auto_start_exchange_rate_service` to better reflect the intent of the option.  The keyword `:exchange_rate_service` will continue to be supported until `Money` version 2.0.

* The configuration option `:delay_before_first_retrieval` is deprecated and is removed from the configuration struct.  Since the option has had no effect since version 0.9 its removal should have no impact on existing code.

* Added [Falsehoods programmers believe about prices](https://gist.github.com/rgs/6509585) topics  which give a good summary of the challenges of managing money in an application and how `Money` manages each of them.
