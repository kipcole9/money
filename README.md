# Money

**Work in progress - don't use, its not all there yet!**

Implements a **Money** type for Elixir that includes:

- Postgres extension for a custom type `money_with_currency` that stores a decimal monetary value with an associated currency code

- Money formatting output using cldr (also under development)

- Money arithmetic using Decimal arithmetic for math and exchange rates

- Exchange rate process to retrieve and manage current exchange rates

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `money` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:money, "~> 0.1.0"}]
    end
    ```

  2. Ensure `money` is started before your application:

    ```elixir
    def application do
      [applications: [:money]]
    end
    ```

