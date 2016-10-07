# Money

Implements a **Money** type for Elixir that includes:

- A Postgres custom type `money_with_currency` that stores a decimal monetary value with an associated currency code.  Also includes a `Mix` task to generate a migration that creates the custom type.

- Money formatting output using the hex package [ex_cldr](https://hex.pm/packages/ex_cldr) that correctly rounds to the appropriate number of fractional digits and to the correct rounding increment for currencies that have minimum cash increments (like the Swiss Franc and Australian Dollar)

- Money arithmetic

## Examples

Creating a new %Money{} struct:

     iex> Money.new(:USD, 100)
     #Money<:USD, 100>

     iex> Money.new("CHF", 130.02)
     #Money<:CHF, 130.02>

     iex> Money.new("thb", 11)
     #Money<:THB, 11>

Formatting a %Money{} to a string (see `Money.to_string/2` and `Cldr.Number.to_string/2`):

    iex> Money.to_string Money.new("thb", 11)
    "THB11.00"

    iex> Money.to_string Money.new("USD", 234.467)
    "$234.47"

    iex> Money.to_string Money.new("USD", 234.467), format: :long
    "234.47 US dollars"

Money Arithmetic (see the module `Money.Arithmetic`):

    iex> m1 = Money.new(:USD, 100)
    #Money<:USD, 100>

    iex> m2 = Money.new(:USD, 200)
    #Money<:USD, 200>

    iex> Money.add(m1, m2)
    #Money<:USD, 300>

    iex> m3 = Money.new(:AUD, 300)
    #Money<:AUD, 300>

    iex(11)> Money.add(m1, m3)
    ** (ArgumentError) Cannot add two %Money{} with different currencies. Received :USD and :AUD.
        (ex_money) lib/money.ex:46: Money.add/2

## Serializing %Money{} to a Postgres database

First generate the migration to create the custom type:

    mix money.gen.migration
    * creating priv/repo/migrations
    * creating priv/repo/migrations/20161007234652_add_money_with_currency_type_to_postgres.exs

Then migrate the database:

    mix ecto.migrate
    07:09:28.637 [info]  == Running MoneyTest.Repo.Migrations.AddMoneyWithCurrencyTypeToPostgres.up/0 forward
    07:09:28.640 [info]  execute "  CREATE TYPE public.money_with_currency AS (\n    currency_code  char(3),\n    amount          numeric(20,8)\n  )\n"
    07:09:28.647 [info]  == Migrated in 0.0s

Create your schema using the `Money.Ecto.Type` ecto type:

    defmodule Ledger do
      use Ecto.Schema

      @primary_key false
      schema "ledgers" do
        field :amount, Money.Ecto.Type

        timestamps()
      end
    end

Insert into the database:

    Repo.insert %Ledger{amount: Money.new(:USD, 100)}
    [debug] QUERY OK db=4.5ms
    INSERT INTO "ledgers" ("amount","inserted_at","updated_at") VALUES ($1,$2,$3) [{"USD", #Decimal<100>}, {{2016, 10, 7}, {23, 12, 13, 0}}, {{2016, 10, 7}, {23, 12, 13, 0}}]

Retrieve from the database:

    Repo.all Ledger
    [debug] QUERY OK source="ledgers" db=5.3ms decode=0.1ms queue=0.1ms
    SELECT l0."amount", l0."inserted_at", l0."updated_at" FROM "ledgers" AS l0 []
    [%Ledger{__meta__: #Ecto.Schema.Metadata<:loaded, "ledgers">, amount: $100.00,
      inserted_at: #Ecto.DateTime<2016-10-07 23:12:13>,
      updated_at: #Ecto.DateTime<2016-10-07 23:12:13>}]

## Roadmap

The next phase of development will focus on adding exchange rate support to ex_money.

## Installation

ex_money can be installed by:

  1. Adding `ex_money` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:ex_money, "~> 0.0.1"}]
    end
    ```

  2. Ensuring `ex_money` is started before your application:

    ```elixir
    def application do
      [applications: [:ex_money]]
    end
    ```

