# Changelog for Money v1.1.0

This is the changelog for Money v1.1.0 released on ______.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

## Changes & Deprecations

* The configuration option `:exchange_rate_service` is deprecated in favour of `:auto_start_exchange_rate_service` to better reflect the intent of the option.  The keyword `:exchange_rate_service` will continue to be supported until `Money` version 2.0.

* The configuration option `:delay_before_first_retrieval` is deprecated and is removed from the configuration struct.  SInce the option has had no effect since version 0.9 its removal should have no impact on existing code.
