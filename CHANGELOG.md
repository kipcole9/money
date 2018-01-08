# Changelog for Money v1.1.3

This is the changelog for Money v1.1.3 released on January 8th, 2018.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/money/tags)

### Enhancements

* Improves the documentation that describes how to configure locales and how that relates to `Money.to_string/2`

* Add `Money.from_integer/2` as the effective inverse of `Money.to_integer_exp/1`.  This function converts an integer form of money (inluding any decimal digits) into a `Money` struct. This is useful for services that return money in an integer format.

```
  iex> Money.from_integer(20000, :USD)
  #Money<:USD, 200.00>

  iex> Money.from_integer(200, :JPY)
  #Money<:JPY, 200>

```

# Changelog for Money v1.1.2

## Bug fixes

* Fixes a bug in `Money.to_integer_exp/1` which was not correctly adjusting the exponent for money amounts that had no decimal places, or the number of decimal places was less than that required for the currency,  Additional tests have been added.

# Changelog for Money v1.1.1

## Enhancements

* Add `Money.to_integer_exp/1` to convert a `Money` into a tuple of the `{currency_code, integer (coefficient), exponent and remainder}`.  This is useful for services that require money to be presented in an integer format.

```
  iex> m = Money.new(:USD, 200.012356)
  #Money<:USD, 200.012356>
  iex> Money.to_integer_exp(m)
  {:USD, 20001, -2, Money.new(:USD, 0.002356)}
```

* Format the code using the Elixir code formatter

# Changelog for Money v1.1.0

## Changes & Deprecations

* The configuration option `:exchange_rate_service` is deprecated in favour of `:auto_start_exchange_rate_service` to better reflect the intent of the option.  The keyword `:exchange_rate_service` will continue to be supported until `Money` version 2.0.

* The configuration option `:delay_before_first_retrieval` is deprecated and is removed from the configuration struct.  Since the option has had no effect since version 0.9 its removal should have no impact on existing code.

* Added [Falsehoods programmers believe about prices](https://gist.github.com/rgs/6509585) topics  which give a good summary of the challenges of managing money in an application and how `Money` manages each of them.
