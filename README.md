# Money

Money implements a set of functions to store, retrieve and perform arithmetic
on a `%Money{}` type that is composed of a currency code and a currency amount.

Money is opinionated in the interests of serving as a dependable library
that can underpin accounting and financial applications.  In its initial
release it can be expected that this contract may not be fully met.

How is this opinion expressed?

1. Money must always have both a amount and a currency code.

2. The currency code must always be a valid ISO4217 code.

3. Money arithmetic can only be performed when both operands are of the
same currency.

4. Money amounts are represented as a `Decimal`.

5. Money can be serialised to the database as a composite Postgres type that
includes both the amount and the currency. Therefore for Ecto serialization
Postgres is assumed as the data store. Serialization is entirely optional.

6. All arithmetic functions work on a `Decimal`. No rounding occurs
automatically (unless expressly called out for a function, as is the case for
`Money.split/2`).

7. Explicit rounding obeys the rounding rules for a given currency. The
rounding rules are defined by the Unicode consortium in its CLDR repository as
implemented by the hex package `ex_cldr`. These rules define the number of
fractional digits for a currency and the rounding increment where appropriate.

8. Money output string formatting output using the hex package
[ex_cldr](https://hex.pm/packages/ex_cldr) that correctly rounds to the
appropriate number of fractional digits and to the correct rounding increment
for currencies that have minimum cash increments (like the Swiss Franc and
Australian Dollar)


## Why yet another Money package?

* Fully localized formatting and rounding using [ex_cldr](https://hex.pm/packages/ex_cldr)

* Provides serialization to Postgres using a composite type that keeps both the currency code and the amount together removing a source of potential error

* Uses the `Decimal` type in Elixir and the Postgres `numeric` type to preserve precision

## Examples

###Creating a %Money{} struct

     iex> Money.new(:USD, 100)
     #Money<:USD, 100>

     iex> Money.new("CHF", 130.02)
     #Money<:CHF, 130.02>

     iex> Money.new("thb", 11)
     #Money<:THB, 11>

The canonical representation of a currency code is an `atom` that is a valid
[ISO4217](http://www.currency-iso.org/en/home/tables/table-a1.html) currency code. The amount of a `%Money{}` is represented by a `Decimal`.

###Optional ~M sigil

An optional sigil module is available to aid in creating %Money{} structs.  It needs to be imported before use:

    import Money.Sigil

    ~M[100]USD
    #> #Money<:USD, 100>

###Localised String formatting
See also `Money.to_string/2` and `Cldr.Number.to_string/2`):

    iex> Money.to_string Money.new("thb", 11)
    "THB11.00"

    iex> Money.to_string Money.new("USD", 234.467)
    "$234.47"

    iex> Money.to_string Money.new("USD", 234.467), format: :long
    "234.47 US dollars"

Note that the output is influenced by the locale in effect.  By default the localed used is that returned by `Cldr.get_local/0`.  Its default value is "en".  Additional locales can be configured, see `Cldr`.  The formatting options are defined in `Cldr.Number.to_string/2`.

###Arithmetic Functions
See also the module `Money.Arithmetic`):

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

    # Split a %Money{} returning the a dividend and a remainder. All
    # operations respect the number of fractional digits defined for a currency
    iex> m1 = Money.new(:USD, 100)
    #Money<:USD, 100>

    iex> Money.split(m1, 3)
    {#Money<:USD, 33.33>, #Money<:USD, 0.01>}

    # Rounding applies the currency definitions of CLDR as implemented in
    # the hex package [ex_cldr](https://hex.pm/packages/ex_cldr)
    iex> Money.round Money.new(:USD, 100.678)
    #Money<:USD, 100.68>

    iex> Money.round Money.new(:JPY, 100.678)
    #Money<:JPY, 101>

###Financial Functions

A limited set of financial functions are available in the module `Money.Financial`.  These are `use`d in the `Money` module. See `Money` for the available functions.

## Serializing to a Postgres database with Ecto

First generate the migration to create the custom type:

    mix money.gen.migration
    * creating priv/repo/migrations
    * creating priv/repo/migrations/20161007234652_add_money_with_currency_type_to_postgres.exs

Then migrate the database:

    mix ecto.migrate
    07:09:28.637 [info]  == Running MoneyTest.Repo.Migrations.AddMoneyWithCurrencyTypeToPostgres.up/0 forward
    07:09:28.640 [info]  execute "CREATE TYPE public.money_with_currency AS (currency_code char(3), amount numeric(20,8))"
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
    [%Ledger{__meta__: #Ecto.Schema.Metadata<:loaded, "ledgers">, amount: #<:USD, 100.00000000>,
      inserted_at: #Ecto.DateTime<2016-10-07 23:12:13>,
      updated_at: #Ecto.DateTime<2016-10-07 23:12:13>}]

## Roadmap

The next phase of development will focus on adding exchange rate support to ex_money.

## Installation

ex_money can be installed by:

  1. Adding `ex_money` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:ex_money, "~> 0.0.5"}]
    end
    ```

  2. Ensuring `ex_money` is started before your application:

    ```elixir
    def application do
      [applications: [:ex_money]]
    end
    ```

