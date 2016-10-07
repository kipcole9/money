# Money

Implements a **Money** type for Elixir that includes:

- Postgres extension for a custom type `money_with_currency` that stores a decimal monetary value with an associated currency code.  Also includes a `Mix` task to generate a migration that creates the custom type.

- Money formatting output using the hex package ex_cldr that correctly rounds to the appropriate number of fractional digits and to the correct rounding increment for currencies that have minimum cash increments (like the Swiss Franc and Australian Dollar)

- Money arithmetic using Decimal arithmetic for math

## Examples

## Roadmap

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `money` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:ex_money, "~> 0.0.1"}]
    end
    ```

  2. Ensure `money` is started before your application:

    ```elixir
    def application do
      [applications: [:ex_money]]
    end
    ```

