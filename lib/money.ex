defmodule Money do
  @moduledoc """
  Money implements a set of functions to store, retrieve, convert and perform
  arithmetic on a `Money.t` type that is composed of a currency code and
  a decimal currency amount.

  Money is very opinionated in the interests of serving as a dependable library
  that can underpin accounting and financial applications.

  This opinion expressed by ensuring that:

  1. Money must always have both a amount and a currency code.

  2. The currency code must always be valid.

  3. Money arithmetic can only be performed when both operands are of the
     same currency.

  4. Money amounts are represented as a `Decimal`.

  5. Money is serialised to the database as a custom Postgres composite type
     that includes both the amount and the currency. Therefore for Ecto
     serialization Postgres is assumed as the data store. Serialization is
     entirely optional and Ecto is not a package dependency.

  6. All arithmetic functions work in fixed point decimal.  No rounding
     occurs automatically (unless expressly called out for a function).

  7. Explicit rounding obeys the rounding rules for a given currency.  The
     rounding rules are defined by the Unicode consortium in its CLDR
     repository as implemented by the hex package `ex_cldr`.  These rules
     define the number of fractional digits for a currency and the rounding
     increment where appropriate.

  """

  @typedoc """
  Money is composed of an atom representation of an ISO4217 currency code and
  a `Decimal` representation of an amount.
  """
  @type t :: %Money{currency: atom, amount: Decimal.t}
  @type currency_code :: atom

  @enforce_keys [:currency, :amount]
  defstruct currency: nil, amount: nil

  import Kernel, except: [round: 1, div: 1]

  # Default mode for rounding is :half_even, also known
  # as bankers rounding
  @default_rounding_mode :half_even

  alias Cldr.Currency

  defdelegate validate_currency(currency_code), to: Cldr

  @doc """
  Returns a %Money{} struct from a currency code and a currency amount or
  an error tuple of the form `{:error, {exception, message}}`.

  ## Options

  * `currency_code` is an ISO4217 three-character upcased binary or atom

  * `amount` is an integer, float or Decimal

  Note that the `currency_code` and `amount` arguments can be supplied in
  either order,

  ## Examples

      iex> Money.new(:USD, 100)
      #Money<:USD, 100>

      iex> Money.new(100, :USD)
      #Money<:USD, 100>

      iex> Money.new("USD", 100)
      #Money<:USD, 100>

      iex> Money.new("thb", 500)
      #Money<:THB, 500>

      iex> Money.new(500, "thb")
      #Money<:THB, 500>

      iex> Money.new("EUR", Decimal.new(100))
      #Money<:EUR, 100>

      iex> Money.new(:XYZZ, 100)
      {:error, {Money.UnknownCurrencyError, "The currency :XYZZ is invalid"}}

  """
  @spec new(number, binary) :: Money.t
  def new(currency_code, amount) when is_binary(currency_code) do
    case validate_currency(currency_code) do
      {:error, {_exception, message}} -> {:error, {Money.UnknownCurrencyError, message}}
      {:ok, code} -> new(code, amount)
    end
  end

  def new(amount, currency_code) when is_binary(currency_code) do
    new(currency_code, amount)
  end

  def new(currency_code, amount) when is_atom(currency_code) and is_number(amount) do
    case validate_currency(currency_code) do
      {:error, {_exception, message}} -> {:error, {Money.UnknownCurrencyError, message}}
      {:ok, code} -> %Money{amount: Decimal.new(amount), currency: code}
    end
  end

  def new(amount, currency_code) when is_number(amount) and is_atom(currency_code) do
    new(currency_code, amount)
  end

  def new(currency_code, %Decimal{} = amount) when is_atom(currency_code) do
    case validate_currency(currency_code) do
      {:error, {_exception, message}} -> {:error, {Money.UnknownCurrencyError, message}}
      {:ok, code} -> %Money{amount: amount, currency: code}
    end
  end

  def new(%Decimal{} = amount, currency_code) when is_atom(currency_code) do
    new(currency_code, amount)
  end

  @doc """
  Returns a %Money{} struct from a currency code and a currency amount. Raises an
  exception if the current code is invalid.

  ## Options

  * `currency_code` is an ISO4217 three-character upcased binary or atom

  * `amount` is an integer, float or Decimal

  ## Examples

      Money.new!(:XYZZ, 100)
      ** (Money.UnknownCurrencyError) Currency :XYZZ is not known
        (ex_money) lib/money.ex:177: Money.new!/2

  """
  def new!(currency_code, amount)
  when (is_binary(currency_code) or is_atom(currency_code)) do
    case money = new(currency_code, amount) do
      {:error, {exception, message}} -> raise exception, message
      _ -> money
    end
  end

  def new!(amount, currency_code)
  when (is_binary(currency_code) or is_atom(currency_code)) and is_number(amount) do
    new!(currency_code, amount)
  end

  def new!(%Decimal{} = amount, currency_code)
  when is_binary(currency_code) or is_atom(currency_code) do
    new!(currency_code, amount)
  end

  def new!(currency_code, %Decimal{} = amount)
  when is_binary(currency_code) or is_atom(currency_code) do
    new!(currency_code, amount)
  end

  @doc """
  Returns a %Money{} struct from a tuple consistenting of a currency code and
  a currency amount.  The format of the argument is a 2-tuple where:

  ## Options

  * `currency_code` is an ISO4217 three-character upcased binary

  * `amount` is an integer, float or Decimal

  This function is typically called from Ecto when it's loading a %Money{}
  struct from the database.

  ## Example

      iex> Money.from_tuple({"USD", 100})
      #Money<:USD, 100>

      iex> Money.from_tuple({100, "USD"})
      #Money<:USD, 100>

  """
  @spec from_tuple({binary, number}) :: Money.t
  def from_tuple({currency_code, amount}) when is_binary(currency_code) and is_number(amount) do
    case validate_currency(currency_code) do
      {:error, {_exception, message}} ->
        {:error, {Money.UnknownCurrencyError, message}}
      {:ok, code} ->
        %Money{amount: Decimal.new(amount), currency: code}
    end
  end

  def from_tuple({amount, currency_code}) when is_binary(currency_code) and is_number(amount) do
    from_tuple({currency_code, amount})
  end

  @doc """
  Returns a %Money{} struct from a tuple consistenting of a currency code and
  a currency amount.  Raises an exception if the currency code is invalid.

  ## Options

  * `currency_code` is an ISO4217 three-character upcased binary

  * `amount` is an integer, float or Decimal

  This function is typically called from Ecto when it's loading a %Money{}
  struct from the database.

  ## Example

      iex> Money.from_tuple!({"USD", 100})
      #Money<:USD, 100>

      Money.from_tuple!({"NO!", 100})
      ** (Money.UnknownCurrencyError) Currency "NO!" is not known
          (ex_money) lib/money.ex:130: Money.new!/1

  """
  def from_tuple!({currency_code, amount}) when is_binary(currency_code) and is_number(amount) do
    case money = new(currency_code, amount) do
      {:error, {exception, message}} -> raise exception, message
      _ -> money
    end
  end

  def from_tuple!({amount, currency_code}) when is_binary(currency_code) and is_number(amount) do
    from_tuple!({currency_code, amount})
  end

  @doc """
  Returns a formatted string representation of a `Money{}`.

  Formatting is performed according to the rules defined by CLDR. See
  `Cldr.Number.to_string/2` for formatting options.  The default is to format
  as a currency which applies the appropriate rounding and fractional digits
  for the currency.

  ## Options

  * `money_1` is any valid `Money.t` type returned
    by `Money.new/2`

  ## Returns

  * `{:ok, string}` or

  * `{:error, reason}`

  ## Examples

      iex> Money.to_string Money.new(:USD, 1234)
      {:ok, "$1,234.00"}

      iex> Money.to_string Money.new(:JPY, 1234)
      {:ok, "¥1,234"}

      iex> Money.to_string Money.new(:THB, 1234)
      {:ok, "THB1,234.00"}

      iex> Money.to_string Money.new(:USD, 1234), format: :long
      {:ok, "1,234 US dollars"}

  """
  def to_string(%Money{} = money, options \\ []) do
    options = merge_options(options, [currency: money.currency])
    Cldr.Number.to_string(money.amount, options)
  end

  @doc """
  Returns a formatted string representation of a `Money{}` or raises if
  there is an error.

  Formatting is performed according to the rules defined by CLDR. See
  `Cldr.Number.to_string!/2` for formatting options.  The default is to format
  as a currency which applies the appropriate rounding and fractional digits
  for the currency.

  ## Examples

      iex> Money.to_string! Money.new(:USD, 1234)
      "$1,234.00"

      iex> Money.to_string! Money.new(:JPY, 1234)
      "¥1,234"

      iex> Money.to_string! Money.new(:THB, 1234)
      "THB1,234.00"

      iex> Money.to_string! Money.new(:USD, 1234), format: :long
      "1,234 US dollars"

  """
  def to_string!(%Money{} = money, options \\ []) do
    options = merge_options(options, [currency: money.currency])
    Cldr.Number.to_string!(money.amount, options)
  end

  @doc """
  Returns the amount part of a `Money` type as a `Decimal`

  ## Options

  * `money` is any valid `Money.t` type returned
    by `Money.new/2`

  ## Returns

  * a `Decimal.t`

  ## Example

      iex> m = Money.new("USD", 100)
      iex> Money.to_decimal(m)
      #Decimal<100>

  """
  @spec to_decimal(money :: Money.t) :: Decimal.t
  def to_decimal(%Money{amount: amount}) do
    amount
  end

  @doc """
  Add two `Money` values.

  ## Options

  * `money_1` and `money_2` are any valid `Money.t` types returned
    by `Money.new/2`

  ## Returns

  * `{:ok, money}` or

  * `{:error, reason}`

  ## Example

      iex> Money.add Money.new(:USD, 200), Money.new(:USD, 100)
      {:ok, Money.new(:USD, 300)}

      iex> Money.add Money.new(:USD, 200), Money.new(:AUD, 100)
      {:error, {ArgumentError, "Cannot add monies with different currencies. " <>
        "Received :USD and :AUD."}}

  """
  @spec add(money_1 :: Money.t, money_2 :: Money.t) :: Money.t
  def add(%Money{currency: same_currency, amount: amount_a}, %Money{currency: same_currency, amount: amount_b}) do
    {:ok, %Money{currency: same_currency, amount: Decimal.add(amount_a, amount_b)}}
  end

  def add(%Money{currency: code_a}, %Money{currency: code_b}) do
    {:error, {ArgumentError, "Cannot add monies with different currencies. " <>
      "Received #{inspect code_a} and #{inspect code_b}."}}
  end

  @doc """
  Add two `Money` values and raise on error.

  ## Options

  * `money_1` and `money_2` are any valid `Money.t` types returned
    by `Money.new/2`

  ## Returns

  * `{:ok, money}` or

  * raises an exception

  ## Examples

      iex> Money.add! Money.new(:USD, 200), Money.new(:USD, 100)
      #Money<:USD, 300>

      Money.add! Money.new(:USD, 200), Money.new(:CAD, 500)
      ** (ArgumentError) Cannot add two %Money{} with different currencies. Received :USD and :CAD.

  """
  def add!(%Money{} = money_1, %Money{} = money_2) do
    case add(money_1, money_2) do
      {:ok, result} -> result
      {:error, {exception, message}} -> raise exception, message
    end
  end

  @doc """
  Subtract one `Money` value struct from another.

  ## Options

  * `money_1` and `money_2` are any valid `Money.t` types returned
    by `Money.new/2`

  ## Returns

  * `{:ok, money}` or

  * `{:error, reason}`

  ## Example

      iex> Money.sub Money.new(:USD, 200), Money.new(:USD, 100)
      {:ok, Money.new(:USD, 100)}

  """
  @spec sub(money_1 :: Money.t, money_2 :: Money.t)
      :: {:ok, Money.t} | {:error, {Exception.t, String.t}}

  def sub(%Money{currency: same_currency, amount: amount_a}, %Money{currency: same_currency, amount: amount_b}) do
    {:ok, %Money{currency: same_currency, amount: Decimal.sub(amount_a, amount_b)}}
  end

  def sub(%Money{currency: code_a}, %Money{currency: code_b}) do
    {:error, {ArgumentError, "Cannot subtract two monies with different currencies. " <>
      "Received #{inspect code_a} and #{inspect code_b}."}}
  end

  @doc """
  Subtract one `Money` value struct from another and raise on error.

  Returns either `{:ok, money}` or `{:error, reason}`.

  ## Options

  * `money_1` and `money_2` are any valid `Money.t` types returned
    by `Money.new/2`

  ## Returns

  * a `Money.t` struct or

  * raises an exception

  ## Examples

      iex> Money.sub! Money.new(:USD, 200), Money.new(:USD, 100)
      #Money<:USD, 100>

      Money.sub! Money.new(:USD, 200), Money.new(:CAD, 500)
      ** (ArgumentError) Cannot subtract monies with different currencies. Received :USD and :CAD.

  """
  @spec sub!(money_1 :: Money.t, money_2 :: Money.t) :: Money.t | none()

  def sub!(%Money{} = a, %Money{} = b) do
    case sub(a, b) do
      {:ok, result} -> result
      {:error, {exception, message}} -> raise exception, message
    end
  end

  @doc """
  Multiply a `Money` value by a number.

  ## Options

  * `money` is any valid `Money.t` type returned
    by `Money.new/2`

  * `number` is an integer, float or `Decimal.t`

  > Note that multipling one %Money{} by another is not supported.

  ## Returns

  * `{:ok, money}` or

  * `{:error, reason}`

  ## Example

      iex> Money.mult(Money.new(:USD, 200), 2)
      {:ok, Money.new(:USD, 400)}

      iex> Money.mult(Money.new(:USD, 200), "xx")
      {:error, {ArgumentError, "Cannot multiply money by \\"xx\\""}}

  """
  @spec mult(Money.t, Cldr.Math.number_or_decimal) :: Money.t
  def mult(%Money{currency: code, amount: amount}, number) when is_number(number) do
    {:ok, %Money{currency: code, amount: Decimal.mult(amount, Decimal.new(number))}}
  end

  def mult(%Money{currency: code, amount: amount}, %Decimal{} = number) do
    {:ok, %Money{currency: code, amount: Decimal.mult(amount, number)}}
  end

  def mult(%Money{}, other) do
    {:error, {ArgumentError, "Cannot multiply money by #{inspect other}"}}
  end

  @doc """
  Multiply a `Money` value by a number and raise on error.

  ## Options

  * `money` is any valid `Money.t` types returned
    by `Money.new/2`

  * `number` is an integer, float or `Decimal.t`

  ## Returns

  * a `Money.t` or

  * raises an exception

  ## Examples

      iex> Money.mult!(Money.new(:USD, 200), 2)
      #Money<:USD, 400>

      Money.mult!(Money.new(:USD, 200), :invalid)
      ** (ArgumentError) Cannot multiply money by :invalid

  """
  @spec mult!(Money.t, Cldr.Math.number_or_decimal) :: Money.t | none()
  def mult!(%Money{} = money, number) do
    case mult(money, number) do
      {:ok, result} -> result
      {:error, {exception, message}} -> raise exception, message
    end
  end

  @doc """
  Divide a `Money` value by a number.

  ## Options

  * `money` is any valid `Money.t` types returned
    by `Money.new/2`

  * `number` is an integer, float or `Decimal.t`

  > Note that dividing one %Money{} by another is not supported.

  ## Returns

  * `{:ok, money}` or

  * `{:error, reason}`

  ## Example

      iex> Money.div Money.new(:USD, 200), 2
      {:ok, Money.new(:USD, 100)}

      iex> Money.div(Money.new(:USD, 200), "xx")
      {:error, {ArgumentError, "Cannot divide money by \\"xx\\""}}

  """
  @spec div(Money.t, Cldr.Math.number_or_decimal) :: Money.t
  def div(%Money{currency: code, amount: amount}, number) when is_number(number) do
    {:ok, %Money{currency: code, amount: Decimal.div(amount, Decimal.new(number))}}
  end

  def div(%Money{currency: code, amount: amount}, %Decimal{} = number) do
    {:ok, %Money{currency: code, amount: Decimal.div(amount, number)}}
  end

  def div(%Money{}, other) do
    {:error, {ArgumentError, "Cannot divide money by #{inspect other}"}}
  end

  @doc """
  Divide a `Money` value by a number and raise on error.

  ## Options

  * `money` is any valid `Money.t` types returned
    by `Money.new/2`

  * `number` is an integer, float or `Decimal.t`

  ## Returns

  * a `Money.t` struct or

  * raises an exception

  ## Examples

      iex> Money.div Money.new(:USD, 200), 2
      {:ok, Money.new(:USD, 100)}

      Money.div(Money.new(:USD, 200), "xx")
      ** (ArgumentError) "Cannot divide money by \\"xx\\""]}}

  """
  def div!(%Money{} = money, number) do
    case Money.div(money, number) do
      {:ok, result} -> result
      {:error, {exception, message}} -> raise exception, message
    end
  end

  @doc """
  Returns a boolean indicating if two `Money` values are equal

  ## Options

  * `money_1` and `money_2` are any valid `Money.t` types returned
    by `Money.new/2`

  ## Returns

  * `true` or `false`

  ## Example

      iex> Money.equal? Money.new(:USD, 200), Money.new(:USD, 200)
      true

      iex> Money.equal? Money.new(:USD, 200), Money.new(:USD, 100)
      false

  """
  @spec equal?(money_1 :: Money.t, money_2 :: Money.t) :: boolean
  def equal?(%Money{currency: same_currency, amount: amount_a}, %Money{currency: same_currency, amount: amount_b}) do
    Decimal.equal?(amount_a, amount_b)
  end

  def equal?(_, _) do
    false
  end

  @doc """
  Compares two `Money` values numerically. If the first number is greater
  than the second :gt is returned, if less than :lt is returned, if both
  numbers are equal :eq is returned.

  ## Options

  * `money_1` and `money_2` are any valid `Money.t` types returned
    by `Money.new/2`

  ## Returns

  *  `:gt` | `:eq` | `:lt` or

  * `{:error, {Exception.t, String.t}}`

  ## Examples

      iex> Money.cmp Money.new(:USD, 200), Money.new(:USD, 100)
      :gt

      iex> Money.cmp Money.new(:USD, 200), Money.new(:USD, 200)
      :eq

      iex> Money.cmp Money.new(:USD, 200), Money.new(:USD, 500)
      :lt

      iex> Money.cmp Money.new(:USD, 200), Money.new(:CAD, 500)
      {:error,
       {ArgumentError,
        "Cannot compare monies with different currencies. Received :USD and :CAD."}}

  """
  @spec cmp(money_1 :: Money.t, money_2 :: Money.t) :: :gt | :eq | :lt | {:error, {Exception.t, String.t}}
  def cmp(%Money{currency: same_currency, amount: amount_a}, %Money{currency: same_currency, amount: amount_b}) do
    Decimal.cmp(amount_a, amount_b)
  end

  def cmp(%Money{currency: code_a}, %Money{currency: code_b}) do
    {:error, {ArgumentError, "Cannot compare monies with different currencies. " <>
      "Received #{inspect code_a} and #{inspect code_b}."}}
  end

  @doc """
  Compares two `Money` values numerically and raises on error.

  ## Options

  * `money_1` and `money_2` are any valid `Money.t` types returned
    by `Money.new/2`

  ## Returns

  *  `:gt` | `:eq` | `:lt` or

  * raises an exception

  ## Examples

      Money.cmp! Money.new(:USD, 200), Money.new(:CAD, 500)
      ** (ArgumentError) Cannot compare monies with different currencies. Received :USD and :CAD.

  """
  def cmp!(%Money{} = money_1, %Money{} = money_2) do
    case cmp(money_1, money_2) do
      {:error, {exception, reason}} -> raise exception, reason
      result -> result
    end
  end

  @doc """
  Compares two `Money` values numerically. If the first number is greater
  than the second #Integer<1> is returned, if less than Integer<-1> is
  returned. Otherwise, if both numbers are equal Integer<0> is returned.

  ## Options

  * `money_1` and `money_2` are any valid `Money.t` types returned
    by `Money.new/2`

  ## Returns

  *  `-1` | `0` | `1` or

  * `{:error, {Exception.t, String.t}}`

  ## Examples

      iex> Money.compare Money.new(:USD, 200), Money.new(:USD, 100)
      1

      iex> Money.compare Money.new(:USD, 200), Money.new(:USD, 200)
      0

      iex> Money.compare Money.new(:USD, 200), Money.new(:USD, 500)
      -1

      iex> Money.compare Money.new(:USD, 200), Money.new(:CAD, 500)
      {:error,
       {ArgumentError,
        "Cannot compare monies with different currencies. Received :USD and :CAD."}}

  """
  @spec compare(money_1 :: Money.t, money_2 :: Money.t) :: -1 | 0 | 1 | {:error, {Exception.t, String.t}}
  def compare(%Money{currency: same_currency, amount: amount_a}, %Money{currency: same_currency, amount: amount_b}) do
    amount_a
    |> Decimal.compare(amount_b)
    |> Decimal.to_integer
  end

  def compare(%Money{currency: code_a}, %Money{currency: code_b}) do
    {:error, {ArgumentError, "Cannot compare monies with different currencies. " <>
      "Received #{inspect code_a} and #{inspect code_b}."}}
  end

  @doc """
  Compares two `Money` values numerically and raises on error.

  ## Options

  * `money_1` and `money_2` are any valid `Money.t` types returned
    by `Money.new/2`

  ## Returns

  *  `-1` | `0` | `1` or

  * raises an exception

  ## Examples

      Money.compare! Money.new(:USD, 200), Money.new(:CAD, 500)
      ** (ArgumentError) Cannot compare monies with different currencies. Received :USD and :CAD.

  """
  def compare!(%Money{} = money_1, %Money{} = money_2) do
    case compare(money_1, money_2) do
      {:error, {exception, reason}} -> raise exception, reason
      result -> result
    end
  end

  @doc """
  Split a `Money` value into a number of parts maintaining the currency's
  precision and rounding and ensuring that the parts sum to the original
  amount.

  ## Options

  * `money` is a `%Money{}` struct

  * `parts` is an integer number of parts into which the `money` is split

  Returns a tuple `{dividend, remainder}` as the function result
  derived as follows:

  1. Round the money amount to the required currency precision using
  `Money.round/1`

  2. Divide the result of step 1 by the integer divisor

  3. Round the result of the division to the precision of the currency
  using `Money.round/1`

  4. Return two numbers: the result of the division and any remainder
  that could not be applied given the precision of the currency.

  ## Examples

      Money.split Money.new(123.5, :JPY), 3
      {¥41, ¥1}

      Money.split Money.new(123.4, :JPY), 3
      {¥41, ¥0}

      Money.split Money.new(123.7, :USD), 9
      {$13.74, $0.04}

  """
  @spec split(Money.t, non_neg_integer) :: {Money.t, Money.t}
  def split(%Money{} = money, parts) when is_integer(parts) do
    rounded_money = Money.round(money)

    div =
      rounded_money
      |> Money.div!(parts)
      |> round

    remainder = sub!(rounded_money, mult!(div, parts))
    {div, remainder}
  end

  @doc """
  Round a `Money` value into the acceptable range for the defined currency.

  ## Options

  * `money` is a `%Money{}` struct

  * `opts` is a keyword list with the following keys:

    * `:rounding_mode` that defines how the number will be rounded.  See
    `Decimal.Context`.  The default is `:half_even` which is also known
    as "banker's rounding"

    * `:cash` which determines whether the rounding is being applied to
    an accounting amount or a cash amount.  Some currencies, such as the
    :AUD and :CHF have a cash unit increment minimum which requires
    a different rounding increment to an arbitrary accounting amount. The
    default is `false`.

  There are two kinds of rounding applied:

  1.  Round to the appropriate number of fractional digits

  2. Apply an appropriate rounding increment.  Most currencies
  round to the same precision as the number of decimal digits, but some
  such as :AUD and :CHF round to a minimum such as 0.05 when its a cash
  amount.

  ## Examples

      iex> Money.round Money.new(123.7456, :CHF), cash: true
      #Money<:CHF, 125>

      iex> Money.round Money.new(123.7456, :CHF)
      #Money<:CHF, 123.75>

      Money.round Money.new(123.7456, :JPY)
      #Money<:JPY, 124>

  """
  @spec round(Money.t, Keyword.t):: Money.t
  def round(%Money{} = money, opts \\ []) do
    money
    |> round_to_decimal_digits(opts)
    |> round_to_nearest(opts)
  end

  defp round_to_decimal_digits(%Money{currency: code, amount: amount}, opts) do
    with {:ok, currency} <- Currency.currency_for_code(code) do
      rounding_mode = Keyword.get(opts, :rounding_mode, @default_rounding_mode)
      rounding = if opts[:cash], do: currency.cash_digits, else: currency.digits
      rounded_amount = Decimal.round(amount, rounding, rounding_mode)
      %Money{currency: code, amount: rounded_amount}
    end
  end

  defp round_to_nearest(%Money{currency: code} = money, opts) do
    with {:ok, currency} <- Currency.currency_for_code(code) do
      increment = if opts[:cash], do: currency.cash_rounding, else: currency.rounding
      do_round_to_nearest(money, increment, opts)
    end
  end

  defp do_round_to_nearest(money, 0, _opts) do
    money
  end

  defp do_round_to_nearest(money, increment, opts) do
    rounding_mode = Keyword.get(opts, :rounding_mode, @default_rounding_mode)
    rounding = Decimal.new(increment)

    rounded_amount =
      money.amount
      |> Decimal.div(rounding)
      |> Decimal.round(0, rounding_mode)
      |> Decimal.mult(rounding)

    %Money{currency: money.currency, amount: rounded_amount}
  end

  @doc """
  Convert `money` from one currency to another.

  ## Options

  * `money` is any `Money.t` struct returned by `Cldr.Currency.new/2`

  * `to_currency` is a valid currency code into which the `money` is converted

  * `rates` is a `Map` of currency rates where the map key is an upcased
    atom or string and the value is a Decimal conversion factor.  The default is the
    latest available exchange rates returned from `Money.ExchangeRates.latest_rates()`

  ## Examples

      Money.to_currency(Money.new(:USD, 100), :AUD, %{USD: Decimal.new(1), AUD: Decimal.new(0.7345)})
      {:ok, #Money<:AUD, 73.4500>}

      Money.to_currency(Money.new("USD", 100), "AUD", %{"USD" => Decimal.new(1), "AUD" => Decimal.new(0.7345)})
      {:ok, #Money<:AUD, 73.4500>}

      iex> Money.to_currency Money.new(:USD, 100) , :AUDD, %{USD: Decimal.new(1), AUD: Decimal.new(0.7345)}
      {:error, {Cldr.UnknownCurrencyError, "The currency :AUDD is invalid"}}

      iex> Money.to_currency Money.new(:USD, 100) , :CHF, %{USD: Decimal.new(1), AUD: Decimal.new(0.7345)}
      {:error, {Money.ExchangeRateError, "No exchange rate is available for currency :CHF"}}

  """
  @spec to_currency(Money.t, Money.currency_code, Map.t) :: {:ok, Map.t} | {:error, {Exception.t, String.t}}
  def to_currency(money, to_currency, rates \\ Money.ExchangeRates.latest_rates())

  def to_currency(%Money{currency: currency} = money, to_currency, _rates)
  when currency == to_currency do
    {:ok, money}
  end

  def to_currency(%Money{currency: currency} = money, to_currency, %{} = rates)
  when is_atom(to_currency) or is_binary(to_currency) do
    with \
      {:ok, to_code} <- validate_currency(to_currency)
    do
      if currency == to_code, do: money, else: to_currency(money, to_currency, {:ok, rates})
    else
      {:error, _} = error -> error
    end
  end

  def to_currency(%Money{currency: from_currency, amount: amount}, to_currency, {:ok, rates})
  when is_atom(to_currency) or is_binary(to_currency) do
    with \
      {:ok, currency_code} <- validate_currency(to_currency),
      {:ok, base_rate} <- get_rate(from_currency, rates),
      {:ok, conversion_rate} <- get_rate(currency_code, rates)
    do
      converted_amount =
        amount
        |> Decimal.div(base_rate)
        |> Decimal.mult(conversion_rate)

      {:ok, Money.new(to_currency, converted_amount)}
    else
      {:error, _} = error -> error
    end
  end

  def to_currency(_money, _to_currency, {:error, reason}) do
    {:error, reason}
  end

  @doc """
  Convert `money` from one currency to another and raises on error

  ## Options

  * `money` is any `Money.t` struct returned by `Cldr.Currency.new/2`

  * `to_currency` is a valid currency code into which the `money` is converted

  * `rates` is a `Map` of currency rates where the map key is an upcased
    atom or string and the value is a Decimal conversion factor.  The default is the
    latest available exchange rates returned from `Money.ExchangeRates.latest_rates()`

  ## Examples

      iex> Money.to_currency! Money.new(:USD, 100) , :AUD, %{USD: Decimal.new(1), AUD: Decimal.new(0.7345)}
      #Money<:AUD, 73.4500>

      iex> Money.to_currency! Money.new("USD", 100) , "AUD", %{"USD" => Decimal.new(1), "AUD" => Decimal.new(0.7345)}
      #Money<:AUD, 73.4500>

      Money.to_currency! Money.new(:USD, 100) , :ZZZ, %{USD: Decimal.new(1), AUD: Decimal.new(0.7345)}
      ** (Cldr.UnknownCurrencyError) Currency :ZZZ is not known

  """
  def to_currency!(%Money{} = money, currency) do
    money
    |> to_currency(currency)
    |> do_to_currency!
  end

  def to_currency!(%Money{} = money, currency, rates) do
    money
    |> to_currency(currency, rates)
    |> do_to_currency!
  end

  defp do_to_currency!(result) do
    case result do
      {:ok, converted} -> converted
      {:error, {exception, reason}} -> raise exception, reason
    end
  end

  @doc """
  Calls `Decimal.reduce/1` on the given `%Money{}`

  This will reduce the coefficient and exponent of the
  decimal amount in a standard way that may aid in
  native comparison of `%Money{}` items.

  ## Example

      iex> x = %Money{currency: :USD, amount: %Decimal{sign: 1, coef: 42, exp: 0}}
      #Money<:USD, 42>
      iex> y = %Money{currency: :USD, amount: %Decimal{sign: 1, coef: 4200000000, exp: -8}}
      #Money<:USD, 42.00000000>
      iex> x == y
      false
      iex> y = Money.reduce(x)
      #Money<:USD, 42>
      iex> x == y
      true

  """
  @spec reduce(Money.t) :: Money.t
  def reduce(%Money{currency: currency, amount: amount}) do
    %Money{currency: currency, amount: Decimal.reduce(amount)}
  end

  ## Helpers

  @doc false
  def get_env(key, default \\ nil) do
    case env = Application.get_env(:ex_money, key, default) do
      {:system, env_key} ->
        System.get_env(env_key) || default
      _ ->
        env
    end
  end

  def get_env(key, default, :integer) do
    key
    |> get_env(default)
    |> to_integer
  end

  def get_env(key, default, :module) do
    key
    |> get_env(default)
    |> to_module
  end

  defp to_integer(nil), do: nil
  defp to_integer(n) when is_integer(n), do: n
  defp to_integer(n) when is_binary(n), do: String.to_integer(n)

  defp to_module(nil), do: nil
  defp to_module(module_name) when is_atom(module_name) , do: module_name
  defp to_module(module_name) when is_binary(module_name) do
    Module.concat([module_name])
  end

  defp get_rate(currency, rates) do
    rates
    |> Map.take([currency, Atom.to_string(currency)])
    |> Map.values
    |> case do
         [rate] -> {:ok, rate}
         _      -> {:error, {Money.ExchangeRateError, "No exchange rate is available for currency #{inspect currency}"}}
       end
  end

  defp merge_options(options, required) do
    Keyword.merge(options, required, fn _k, _v1, v2 -> v2 end)
  end

  defimpl String.Chars do
    def to_string(v) do
      Money.to_string(v)
    end
  end

  defimpl Inspect, for: Money do
    def inspect(money, _opts) do
      "#Money<#{inspect money.currency}, #{Decimal.to_string(money.amount)}>"
    end
  end

  if Code.ensure_compiled?(Phoenix.HTML.Safe) do
    defimpl Phoenix.HTML.Safe, for: Money do
      def to_iodata(money) do
        Phoenix.HTML.Safe.to_iodata(to_string(money))
      end
    end
  end
end
