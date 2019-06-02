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

  import Kernel, except: [round: 1]

  @typedoc """
  Money is composed of an atom representation of an ISO4217 currency code and
  a `Decimal` representation of an amount.
  """
  @type t :: %Money{currency: atom(), amount: Decimal.t()}
  @type currency_code :: atom() | String.t()
  @type amount :: float() | integer() | Decimal.t() | String.t()

  @enforce_keys [:currency, :amount]
  defstruct currency: nil, amount: nil

  @json_library Application.get_env(:ex_money, :json_library, Cldr.Config.json_library())
  unless Code.ensure_loaded?(@json_library) do
    IO.puts("""

    The json_library '#{inspect(@json_library)}' does not appear
    to be available.  A json library is required
    for Money to operate. Is it configured as a
    dependency in mix.exs?

    In config.exs your expicit or implicit configuration is:

      config ex_money,
        json_library: #{inspect(@json_library)}

    In mix.exs you will need something like:

      def deps() do
        [
          ...
          {:#{String.downcase(inspect(@json_library))}, version_string}
        ]
      end
    """)

    raise ArgumentError,
          "Json library #{String.downcase(inspect(@json_library))} does " <>
            "not appear to be a dependency"
  end

  # Default mode for rounding is :half_even, also known
  # as bankers rounding
  @default_rounding_mode :half_even

  alias Money.Currency
  alias Money.ExchangeRates

  defdelegate validate_currency(currency_code), to: Cldr
  defdelegate known_currencies, to: Cldr
  defdelegate known_current_currencies, to: Money.Currency
  defdelegate known_historic_currencies, to: Money.Currency
  defdelegate known_tender_currencies, to: Money.Currency

  @doc """
  Returns a %Money{} struct from a currency code and a currency amount or
  an error tuple of the form `{:error, {exception, message}}`.

  ## Arguments

  * `currency_code` is an ISO4217 three-character upcased binary or atom

  * `amount` is an integer, string or Decimal

  ## Options

  `:locale` is any known locale.  The locale is used to normalize any
  binary (String) amounts to a form that can be consumed by `Decimal.new/1`.
  This consists of removing any localised grouping characters and replacing
  the localised decimal separator with a ".".

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

      iex> Money.new("EUR", Decimal.new(100))
      #Money<:EUR, 100>

      iex> Money.new(:EUR, "100.30")
      #Money<:EUR, 100.30>

      iex> Money.new(:XYZZ, 100)
      {:error, {Money.UnknownCurrencyError, "The currency :XYZZ is invalid"}}

      iex> Money.new("1.000,99", :EUR, locale: "de")
      #Money<:EUR, 1000.99>

      iex> Money.new 123.445, :USD
      {:error,
       {Money.InvalidAmountError,
        "Float amounts are not supported in new/2 due to potenial " <>
        "rounding and precision issues.  If absolutely required, " <>
        "use Money.from_float/2"}}

  """
  @spec new(amount | currency_code, amount | currency_code, Keyword.t()) ::
          Money.t() | {:error, {module(), String.t()}}

  def new(currency_code, amount, options \\ [])

  def new(currency_code, amount, options) when is_binary(currency_code) and is_integer(amount) do
    case validate_currency(currency_code) do
      {:error, {_exception, message}} -> {:error, {Money.UnknownCurrencyError, message}}
      {:ok, code} -> new(code, amount, options)
    end
  end

  def new(amount, currency_code, options) when is_binary(currency_code) and is_integer(amount) do
    new(currency_code, amount, options)
  end

  def new(currency_code, amount, _options) when is_atom(currency_code) and is_integer(amount) do
    with {:ok, code} <- validate_currency(currency_code) do
      %Money{amount: Decimal.new(amount), currency: code}
    else
      {:error, {Cldr.UnknownCurrencyError, message}} ->
        {:error, {Money.UnknownCurrencyError, message}}
    end
  end

  def new(amount, currency_code, options) when is_integer(amount) and is_atom(currency_code) do
    new(currency_code, amount, options)
  end

  def new(currency_code, %Decimal{} = amount, _options)
      when is_atom(currency_code) or is_binary(currency_code) do
    case validate_currency(currency_code) do
      {:error, {_exception, message}} -> {:error, {Money.UnknownCurrencyError, message}}
      {:ok, code} -> %Money{amount: amount, currency: code}
    end
  end

  def new(%Decimal{} = amount, currency_code, options)
      when is_atom(currency_code) or is_binary(currency_code) do
    new(currency_code, amount, options)
  end

  def new(currency_code, amount, options) when is_atom(currency_code) and is_binary(amount) do
    with {:ok, decimal} <- parse_decimal(amount, options[:locale], options[:backend]) do
      new(currency_code, decimal, options)
    end
  rescue
    Decimal.Error ->
      {
        :error,
        {Money.InvalidAmountError, "Amount cannot be converted to a number: #{inspect(amount)}"}
      }
  end

  def new(amount, currency_code, options) when is_atom(currency_code) and is_binary(amount) do
    new(currency_code, amount, options)
  end

  def new(_currency_code, amount, _options) when is_float(amount) do
    {:error,
     {Money.InvalidAmountError,
      "Float amounts are not supported in new/2 due to potenial rounding " <>
        "and precision issues.  If absolutely required, use Money.from_float/2"}}
  end

  def new(amount, _currency_code, _options) when is_float(amount) do
    {:error,
     {Money.InvalidAmountError,
      "Float amounts are not supported in new/2 due to potenial rounding " <>
        "and precision issues.  If absolutely required, use Money.from_float/2"}}
  end

  def new(param_a, param_b, options) when is_binary(param_a) and is_binary(param_b) do
    with {:ok, currency_code} <- validate_currency(param_a) do
      new(currency_code, param_b, options)
    else
      {:error, _} ->
        with {:ok, currency_code} <- validate_currency(param_b) do
          new(currency_code, param_a, options)
        else
          {:error, _} ->
            {:error,
             {Money.Invalid,
              "Unable to create money from #{inspect(param_a)} " <> "and #{inspect(param_b)}"}}
        end
    end
  end

  @doc """
  Returns a %Money{} struct from a currency code and a currency amount. Raises an
  exception if the current code is invalid.

  ## Arguments

  * `currency_code` is an ISO4217 three-character upcased binary or atom

  * `amount` is an integer, float or Decimal

  ## Examples

      Money.new!(:XYZZ, 100)
      ** (Money.UnknownCurrencyError) Currency :XYZZ is not known
        (ex_money) lib/money.ex:177: Money.new!/2

  """
  @spec new!(amount | currency_code, amount | currency_code) :: Money.t() | no_return()

  def new!(currency_code, amount)
      when is_binary(currency_code) or is_atom(currency_code) do
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
  Returns a %Money{} struct from a currency code and a float amount, or
  an error tuple of the form `{:error, {exception, message}}`.

  Floats are fraught with danger in computer arithmetic due to the
  unexpected loss of precision during rounding. The IEEE754 standard
  indicates that a number with a precision of 16 digits should
  round-trip convert without loss of fidelity. This function supports
  numbers with a precision up to 15 digits and will error if the
  provided amount is outside that range.

  **Note** that `Money` cannot detect lack of precision or rounding errors
  introduced upstream. This function therefore should be used with
  great care and its use should be considered potentially harmful.

  ## Arguments

  * `currency_code` is an ISO4217 three-character upcased binary or atom

  * `amount` is a float

  ## Examples

      iex> Money.from_float 1.23456, :USD
      #Money<:USD, 1.23456>

      iex> Money.from_float 1.234567890987656, :USD
      {:error,
        {Money.InvalidAmountError,
          "The precision of the float 1.234567890987656 is " <>
          "greater than 15 which could lead to unexpected results. " <>
          "Reduce the precision or call Money.new/2 with a Decimal or String amount"}}

  """
  # @doc since: "2.0.0"
  @max_precision_allowed 15
  @spec from_float(float | currency_code, float | currency_code) ::
          Money.t() | {:error, {module(), String.t()}}

  def from_float(currency_code, amount)
      when (is_binary(currency_code) or is_atom(currency_code)) and is_float(amount) do
    if Cldr.Number.precision(amount) <= @max_precision_allowed do
      new(currency_code, Decimal.from_float(amount))
    else
      {:error,
       {Money.InvalidAmountError,
        "The precision of the float #{inspect(amount)} " <>
          "is greater than #{inspect(@max_precision_allowed)} " <>
          "which could lead to unexpected results. Reduce the " <>
          "precision or call Money.new/2 with a Decimal or String amount"}}
    end
  end

  def from_float(amount, currency_code)
      when (is_binary(currency_code) or is_atom(currency_code)) and is_float(amount) do
    from_float(currency_code, amount)
  end

  @doc """
  Returns a %Money{} struct from a currency code and a float amount, or
  raises an exception if the currency code is invalid.

  See `Money.from_float/2` for further information.

  **Note** that `Money` cannot detect lack of precision or rounding errors
  introduced upstream. This function therefore should be used with
  great care and its use should be considered potentially harmful.

  ## Arguments

  * `currency_code` is an ISO4217 three-character upcased binary or atom

  * `amount` is a float

  ## Examples

      iex> Money.from_float!(:USD, 1.234)
      #Money<:USD, 1.234>

      Money.from_float!(:USD, 1.234567890987654)
      #=> ** (Money.InvalidAmountError) The precision of the float 1.234567890987654 is greater than 15 which could lead to unexpected results. Reduce the precision or call Money.new/2 with a Decimal or String amount
          (ex_money) lib/money.ex:293: Money.from_float!/2

  """
  # @doc since: "2.0.0"
  @spec from_float!(currency_code, float) :: Money.t() | no_return()

  def from_float!(currency_code, amount) do
    case from_float(currency_code, amount) do
      {:error, {exception, reason}} -> raise exception, reason
      money -> money
    end
  end

  # The set of grouping chars and decimal chars comes
  # from CLDR's "misc" category for the "en" locale.
  # Ideally we would be generating these characters
  # from the locale files directly.
  @grouping_chars ",،٫、︐︑﹐﹑，､"
  @decimal_chars ".․。︒﹒．｡"
  @currency "[^0-9#{@grouping_chars}#{@decimal_chars}]+"
  @amount "[0-9][0-9#{@grouping_chars}#{@decimal_chars}]+"
  @regex Regex.compile!("^(?<cb>#{@currency})?(?<amount>#{@amount})?(?<ca>#{@currency})?$", "u")

  @doc false
  def parser_regex do
    @regex
  end

  @doc """
  Parse a string and return a `Money.t` or an error.

  The string to be parsed is required to have a currency
  code and an amount.  The currency code may be placed
  before the amount or after, but not both.

  Parsing is strict.  Additional text surrounding the
  currency code and amount will cause the parse to
  fail.

  ## Arguments

  * `string` is a string to be parsed

  * `options` is a keyword list of options that is
    passed to `Money.new/3` with the exception of
    the options listed below

  ## Options

  * `backend` is any module() that includes `use Cldr` and therefore
    is a `Cldr` backend module(). THe default is `Money.default_backend()`

  * `locale_name` is any valid locale name returned by `Cldr.known_locale_names/1`
    or a `Cldr.LanguageTag` struct returned by `Cldr.Locale.new!/2`
    The default is `<backend>.get_locale()`

  * `currency_filter` is an `atom` or list of `atoms` representing the
    currency types to be considered for a match. If a list of
    atoms is given, the currency must meet all criteria for
    it to be considered.

    * `:all`, the default, considers all currencies

    * `:current` considers those currencies that have a `:to`
      date of nil and which also is a known ISO4217 currency

    * `:historic` is the opposite of `:current`

    * `:tender` considers currencies that are legal tender

    * `:unannotated` considers currencies that don't have
      "(some string)" in their names.  These are usually
      financial instruments.

  * `fuzzy` is a float greater than `0.0` and less than or
    equal to `1.0` which is used as input to the
    `String.jaro_distance/2` to determine is the provided
    currency string is *close enough* to a known currency
    string for it to identify definitively a currency code.
    It is recommended to use numbers greater than `0.8` in
    order to reduce false positives.

  ## Returns

  * a `Money.t` if parsing is successful or

  * `{:error, {exception, reason}}` if an error is
    detected.

  ## Examples

      iex> Money.parse("USD 100")
      #Money<:USD, 100>

      iex> Money.parse "USD 100,00", locale: "de"
      #Money<:USD, 100.00>

      iex> Money.parse("100 USD")
      #Money<:USD, 100>

      iex> Money.parse("100 eurosports", fuzzy: 0.8)
      #Money<:EUR, 100>

      iex> Money.parse("100 eurosports", fuzzy: 0.9)
      {:error,
       {Money.Invalid, "Unable to create money from \\"eurosports\\" and \\"100\\""}}

      iex> Money.parse("100 afghan afghanis")
      #Money<:AFN, 100>

      iex> Money.parse("100")
      {:error,
       {Money.Invalid,
        "A currency code must be specified but was not found in \\"100\\""}}

      iex> Money.parse("USD 100 with trailing text")
      {:error,
        {Money.Invalid, "A currency code can only be specified once. " <>
          "Found both \\"usd\\" and \\"with trailing text\\"."}}

  """
  # @doc since: "3.2.0"
  @spec parse(String.t(), Keyword.t()) :: Money.t() | {:error, {module(), String.t()}}
  def parse(string, options \\ [])

  def parse(string, options) do
    @regex
    |> Regex.named_captures(String.trim(string))
    |> trim_and_lower("ca")
    |> trim_and_lower("cb")
    |> do_parse(string, options)
  end

  defp trim_and_lower(nil, _key) do
    nil
  end

  defp trim_and_lower(map, key) do
    value =
      map
      |> Map.get(key)
      |> String.trim
      |> String.downcase
    Map.put(map, key, value)
  end

  defp do_parse(%{"cb" => "", "ca" => ""}, string, _options) do
    {:error,
     {Money.Invalid, "A currency code must be specified but was not found in #{inspect(string)}"}}
  end

  defp do_parse(%{"amount" => ""}, string, _options) do
    {:error, {Money.Invalid, "An amount must be specified but was not found in #{inspect(string)}"}}
  end

  defp do_parse(%{"cb" => "", "ca" => currency, "amount" => amount}, _, options) do
    maybe_create_money(currency, amount, options)
  end

  defp do_parse(%{"cb" => currency, "ca" => "", "amount" => amount}, _, options) do
    maybe_create_money(currency, amount, options)
  end

  defp do_parse(%{"cb" => cb, "ca" => ca}, _, _options) do
    {:error,
     {Money.Invalid,
      "A currency code can only be specified once. Found both #{inspect(cb)} and #{inspect(ca)}."}}
  end

  defp do_parse(_captures, string, _options) do
    {:error, {Money.Invalid, "Could not parse #{inspect(string)}."}}
  end

  defp maybe_create_money(currency, amount, options) do
    backend = Keyword.get(options, :backend, Money.default_backend)
    locale = Keyword.get(options, :locale, backend.get_locale)
    {currency_filter, options} = Keyword.pop(options, :currency_filter, :all)
    {fuzzy, options} = Keyword.pop(options, :fuzzy, nil)
    amount = String.trim(amount)

    with {:ok, currency_strings} <- Cldr.Currency.currency_strings(locale, backend, currency_filter),
         {:ok, currency} <- find_currency(currency_strings, currency, fuzzy) do
      Money.new(currency, amount, options)
    end
  end

  defp find_currency(currency_strings, currency, nil) do
    {:ok, Map.get(currency_strings, currency, currency)}
  end

  defp find_currency(currency_strings, currency, fuzzy)
        when is_float(fuzzy) and fuzzy > 0.0 and fuzzy <= 1.0 do

    {distance, currency_code} =
      currency_strings
      |> Enum.map(fn {k, v} -> {String.jaro_distance(k, currency), v} end)
      |> Enum.sort(fn {k1, _v1}, {k2, _v2} -> k1 > k2 end)
      |> hd

    if distance >= fuzzy do
      {:ok, currency_code}
    else
      {:ok, currency}
    end
  end

  defp find_currency(_currency_strings, _currency, fuzzy) do
    {:error, {
      ArgumentError,
      "option :fuzzy must be a number > 0.0 and <= 1.0. Found #{inspect fuzzy}"
    }}
  end

  @doc """
  Returns a formatted string representation of a `Money{}`.

  Formatting is performed according to the rules defined by CLDR. See
  `Cldr.Number.to_string/2` for formatting options.  The default is to format
  as a currency which applies the appropriate rounding and fractional digits
  for the currency.

  ## Arguments

  * `money` is any valid `Money.t` type returned
    by `Money.new/2`

  * `options` is a keyword list of options

  ## Returns

  * `{:ok, string}` or

  * `{:error, reason}`

  ## Options

  * `:backend` is any CLDR backend module.  The default is
    `Money.default_backend()`.

  * Any other options are passed to `Cldr.Number.to_string/3`

  ## Examples

      iex> Money.to_string Money.new(:USD, 1234)
      {:ok, "$1,234.00"}

      iex> Money.to_string Money.new(:JPY, 1234)
      {:ok, "¥1,234"}

      iex> Money.to_string Money.new(:THB, 1234)
      {:ok, "THB 1,234.00"}

      iex> Money.to_string Money.new(:USD, 1234), format: :long
      {:ok, "1,234 US dollars"}

  """
  @spec to_string(Money.t(), Keyword.t()) :: {:ok, String.t()} | {:error, term}
  def to_string(%Money{} = money, options \\ []) do
    default_options = [backend: Money.default_backend(), currency: money.currency]
    options = Keyword.merge(default_options, options)
    backend = options[:backend]
    Cldr.Number.to_string(money.amount, backend, options)
  end

  @doc """
  Returns a formatted string representation of a `Money.t` or raises if
  there is an error.

  Formatting is performed according to the rules defined by CLDR. See
  `Cldr.Number.to_string!/2` for formatting options.  The default is to format
  as a currency which applies the appropriate rounding and fractional digits
  for the currency.

  ## Arguments

  * `money` is any valid `Money.t` type returned
    by `Money.new/2`

  * `options` is a keyword list of options

  ## Options

  * `:backend` is any CLDR backend module.  The default is
    `Money.default_backend()`.

  * Any other options are passed to `Cldr.Number.to_string/3`

  ## Examples

      iex> Money.to_string! Money.new(:USD, 1234)
      "$1,234.00"

      iex> Money.to_string! Money.new(:JPY, 1234)
      "¥1,234"

      iex> Money.to_string! Money.new(:THB, 1234)
      "THB 1,234.00"

      iex> Money.to_string! Money.new(:USD, 1234), format: :long
      "1,234 US dollars"

  """
  @spec to_string!(Money.t(), Keyword.t()) :: String.t()
  def to_string!(%Money{} = money, options \\ []) do
    with {:ok, string} <- Money.to_string(money, options) do
      string
    else
      {:error, {type, message}} when is_atom(type) and is_binary(message) ->
        raise type, message

      other ->
        raise "Error converting money to string: " <> inspect(other)
    end
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
  @spec to_decimal(money :: Money.t()) :: Decimal.t()
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
  @spec add(money_1 :: Money.t(), money_2 :: Money.t()) ::
          {:ok, Money.t()} | {:error, {module(), String.t()}}
  def add(%Money{currency: same_currency, amount: amount_a}, %Money{
        currency: same_currency,
        amount: amount_b
      }) do
    {:ok, %Money{currency: same_currency, amount: Decimal.add(amount_a, amount_b)}}
  end

  def add(%Money{currency: code_a}, %Money{currency: code_b}) do
    {
      :error,
      {
        ArgumentError,
        "Cannot add monies with different currencies. " <>
          "Received #{inspect(code_a)} and #{inspect(code_b)}."
      }
    }
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
  @spec sub(money_1 :: Money.t(), money_2 :: Money.t()) ::
          {:ok, Money.t()} | {:error, {module(), String.t()}}

  def sub(%Money{currency: same_currency, amount: amount_a}, %Money{
        currency: same_currency,
        amount: amount_b
      }) do
    {:ok, %Money{currency: same_currency, amount: Decimal.sub(amount_a, amount_b)}}
  end

  def sub(%Money{currency: code_a}, %Money{currency: code_b}) do
    {:error,
     {ArgumentError,
      "Cannot subtract two monies with different currencies. " <>
        "Received #{inspect(code_a)} and #{inspect(code_b)}."}}
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
  @spec sub!(money_1 :: Money.t(), money_2 :: Money.t()) :: Money.t() | none()

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
  @spec mult(Money.t(), Cldr.Math.number_or_decimal()) ::
          {:ok, Money.t()} | {:error, {module(), String.t()}}
  def mult(%Money{currency: code, amount: amount}, number) when is_integer(number) do
    {:ok, %Money{currency: code, amount: Decimal.mult(amount, Decimal.new(number))}}
  end

  def mult(%Money{currency: code, amount: amount}, number) when is_float(number) do
    {:ok, %Money{currency: code, amount: Decimal.mult(amount, Decimal.from_float(number))}}
  end

  def mult(%Money{currency: code, amount: amount}, %Decimal{} = number) do
    {:ok, %Money{currency: code, amount: Decimal.mult(amount, number)}}
  end

  def mult(%Money{}, other) do
    {:error, {ArgumentError, "Cannot multiply money by #{inspect(other)}"}}
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
  @spec mult!(Money.t(), Cldr.Math.number_or_decimal()) :: Money.t() | none()
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
  @spec div(Money.t(), Cldr.Math.number_or_decimal()) ::
          {:ok, Money.t()} | {:error, {module(), String.t()}}
  def div(%Money{currency: code, amount: amount}, number) when is_integer(number) do
    {:ok, %Money{currency: code, amount: Decimal.div(amount, Decimal.new(number))}}
  end

  def div(%Money{currency: code, amount: amount}, number) when is_float(number) do
    {:ok, %Money{currency: code, amount: Decimal.div(amount, Decimal.from_float(number))}}
  end

  def div(%Money{currency: code, amount: amount}, %Decimal{} = number) do
    {:ok, %Money{currency: code, amount: Decimal.div(amount, number)}}
  end

  def div(%Money{}, other) do
    {:error, {ArgumentError, "Cannot divide money by #{inspect(other)}"}}
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
  @spec equal?(money_1 :: Money.t(), money_2 :: Money.t()) :: boolean
  def equal?(%Money{currency: same_currency, amount: amount_a}, %Money{
        currency: same_currency,
        amount: amount_b
      }) do
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

  * `{:error, {module(), String.t}}`

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
  @spec cmp(money_1 :: Money.t(), money_2 :: Money.t()) ::
          :gt | :eq | :lt | {:error, {module(), String.t()}}
  def cmp(%Money{currency: same_currency, amount: amount_a}, %Money{
        currency: same_currency,
        amount: amount_b
      }) do
    Decimal.cmp(amount_a, amount_b)
  end

  def cmp(%Money{currency: code_a}, %Money{currency: code_b}) do
    {:error,
     {ArgumentError,
      "Cannot compare monies with different currencies. " <>
        "Received #{inspect(code_a)} and #{inspect(code_b)}."}}
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

  * `{:error, {module(), String.t}}`

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
  @spec compare(money_1 :: Money.t(), money_2 :: Money.t()) ::
          -1 | 0 | 1 | {:error, {module(), String.t()}}
  def compare(%Money{currency: same_currency, amount: amount_a}, %Money{
        currency: same_currency,
        amount: amount_b
      }) do
    amount_a
    |> Decimal.compare(amount_b)
    |> Decimal.to_integer()
  end

  def compare(%Money{currency: code_a}, %Money{currency: code_b}) do
    {:error,
     {ArgumentError,
      "Cannot compare monies with different currencies. " <>
        "Received #{inspect(code_a)} and #{inspect(code_b)}."}}
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
  @spec split(Money.t(), non_neg_integer) :: {Money.t(), Money.t()}
  def split(%Money{} = money, parts) when is_integer(parts) do
    rounded_money = Money.round(money)

    div =
      rounded_money
      |> Money.div!(parts)
      |> round

    remainder = sub!(money, mult!(div, parts))
    {div, remainder}
  end

  @doc """
  Round a `Money` value into the acceptable range for the requested currency.

  ## Arguments

  * `money` is a `%Money{}` struct

  * `opts` is a keyword list of options

  ## Options

    * `:rounding_mode` that defines how the number will be rounded.  See
      `Decimal.Context`.  The default is `:half_even` which is also known
      as "banker's rounding"

    * `:currency_digits` which determines the rounding increment.
      The valid options are `:cash`, `:accounting` and `:iso` or
      an integer value representing the rounding factor.  The
      default is `:iso`.

  ## Notes

  There are two kinds of rounding applied:

  1. Round to the appropriate number of fractional digits

  3. Apply an appropriate rounding increment.  Most currencies
     round to the same precision as the number of decimal digits, but some
     such as `:CHF` round to a minimum such as `0.05` when its a cash
     amount. The rounding increment is applied when the option
     `:currency_digits` is set to `:cash`

  ## Examples

      iex> Money.round Money.new("123.73", :CHF), currency_digits: :cash
      #Money<:CHF, 123.75>

      iex> Money.round Money.new("123.73", :CHF), currency_digits: 0
      #Money<:CHF, 124>

      iex> Money.round Money.new("123.7456", :CHF)
      #Money<:CHF, 123.75>

      iex> Money.round Money.new("123.7456", :JPY)
      #Money<:JPY, 124>

  """
  @spec round(Money.t(), Keyword.t()) :: Money.t()
  def round(%Money{} = money, opts \\ []) do
    money
    |> round_to_decimal_digits(opts)
    |> round_to_nearest(opts)
  end

  defp round_to_decimal_digits(%Money{currency: code, amount: amount}, opts) do
    with {:ok, currency} <- Currency.currency_for_code(code) do
      rounding_mode = Keyword.get(opts, :rounding_mode, @default_rounding_mode)
      rounding = digits_from_opts(currency, opts[:currency_digits])
      rounded_amount = Decimal.round(amount, rounding, rounding_mode)
      %Money{currency: code, amount: rounded_amount}
    end
  end

  defp digits_from_opts(currency, nil) do
    currency.iso_digits
  end

  defp digits_from_opts(currency, :iso) do
    currency.iso_digits
  end

  defp digits_from_opts(currency, :accounting) do
    currency.digits
  end

  defp digits_from_opts(currency, :cash) do
    currency.cash_digits
  end

  defp digits_from_opts(_currency, digits) when is_integer(digits) do
    digits
  end

  defp round_to_nearest(%Money{currency: code} = money, opts) do
    with {:ok, currency} <- Currency.currency_for_code(code) do
      digits = digits_from_opts(currency, opts[:currency_digits])
      increment = increment_from_opts(currency, opts[:currency_digits])
      do_round_to_nearest(money, digits, increment, opts)
    end
  end

  defp round_to_nearest({:error, _} = error, _opts) do
    error
  end

  defp do_round_to_nearest(money, _digits, 0, _opts) do
    money
  end

  defp do_round_to_nearest(money, digits, increment, opts) do
    rounding_mode = Keyword.get(opts, :rounding_mode, @default_rounding_mode)

    rounding =
      -digits
      |> Cldr.Math.power_of_10()
      |> Kernel.*(increment)
      |> Decimal.from_float()

    rounded_amount =
      money.amount
      |> Decimal.div(rounding)
      |> Decimal.round(0, rounding_mode)
      |> Decimal.mult(rounding)

    %Money{currency: money.currency, amount: rounded_amount}
  end

  defp increment_from_opts(currency, :cash) do
    currency.cash_rounding
  end

  defp increment_from_opts(currency, _) do
    currency.rounding
  end


  @doc """
  Set the fractional part of a `Money`.

  ## Arguments

  * `money` is a `%Money{}` struct

  * `fraction` is an integer amount that will be set
    as the fraction of the `money`

  ## Notes

  The fraction can only be set if it matches the number of
  decimal digits for the currency associated with the `money`.
  Therefore, for a currency with 2 decimal digits, the
  maximum for `fraction` is `99`.

  ## Examples

      iex> Money.put_fraction Money.new(:USD, "2.49"), 99
      #Money<:USD, 2.99>

      iex> Money.put_fraction Money.new(:USD, "2.49"), 0
      #Money<:USD, 2.0>

      iex> Money.put_fraction Money.new(:USD, "2.49"), 999
      {:error,
       {Money.InvalidAmountError, "Rounding up to 999 is invalid for currency :USD"}}

  """
  def put_fraction(money, fraction \\ 0)

  @one Decimal.new(1)
  @zero Decimal.new(0)

  def put_fraction(%Money{currency: code, amount: amount}, upto) when is_integer(upto) do
    with {:ok, currency} <- Currency.currency_for_code(code) do
      digits = currency.digits
      diff = Decimal.from_float((100 - upto) * :math.pow(10, -digits))
      if Decimal.cmp(diff, @one) in [:lt, :eq] && Decimal.cmp(@zero, diff) in [:lt, :eq] do
        new_amount =
          Decimal.round(amount, 0)
          |> Decimal.add(@one)
          |> Decimal.sub(diff)

        Money.new(code, new_amount)
      else
        {:error, {Money.InvalidAmountError,
          "Rounding up to #{inspect upto} is invalid for currency #{inspect code}"}}
      end
    end
  end

  @doc """
  Convert `money` from one currency to another.

  ## Arguments

  * `money` is any `Money.t` struct returned by `Cldr.Currency.new/2`

  * `to_currency` is a valid currency code into which the `money` is converted

  * `rates` is a `Map` of currency rates where the map key is an upcased
    atom or string and the value is a Decimal conversion factor.  The default is the
    latest available exchange rates returned from `Money.ExchangeRates.latest_rates()`

  ## Examples

      Money.to_currency(Money.new(:USD, 100), :AUD, %{USD: Decimal.new(1), AUD: Decimal.from_float(0.7345)})
      {:ok, #Money<:AUD, 73.4500>}

      Money.to_currency(Money.new("USD", 100), "AUD", %{"USD" => Decimal.new(1), "AUD" => Decimal.from_float(0.7345)})
      {:ok, #Money<:AUD, 73.4500>}

      iex> Money.to_currency Money.new(:USD, 100), :AUDD, %{USD: Decimal.new(1), AUD: Decimal.from_float(0.7345)}
      {:error, {Cldr.UnknownCurrencyError, "The currency :AUDD is invalid"}}

      iex> Money.to_currency Money.new(:USD, 100), :CHF, %{USD: Decimal.new(1), AUD: Decimal.from_float(0.7345)}
      {:error, {Money.ExchangeRateError, "No exchange rate is available for currency :CHF"}}

  """
  @spec to_currency(
          Money.t(),
          currency_code(),
          ExchangeRates.t() | {:ok, ExchangeRates.t()} | {:error, {module(), String.t()}}
        ) :: {:ok, Money.t()} | {:error, {module(), String.t()}}

  def to_currency(money, to_currency, rates \\ Money.ExchangeRates.latest_rates())

  def to_currency(%Money{} = money, currency, {:ok, %{} = rates}) do
    to_currency(money, currency, rates)
  end

  def to_currency(_money, _to_currency, {:error, reason}) do
    {:error, reason}
  end

  def to_currency(%Money{currency: currency} = money, currency, _rates) do
    {:ok, money}
  end

  def to_currency(%Money{} = money, to_currency, %{} = rates)
      when is_binary(to_currency) do
    with {:ok, currency_code} <- validate_currency(to_currency) do
      to_currency(money, currency_code, rates)
    end
  end

  def to_currency(%Money{currency: from_currency, amount: amount}, to_currency, %{} = rates)
      when is_atom(to_currency) do
    with {:ok, to_currency_code} <- validate_currency(to_currency),
         {:ok, cross_rate} <- cross_rate(from_currency, to_currency_code, rates) do
      converted_amount = Decimal.mult(amount, cross_rate)
      {:ok, Money.new(to_currency, converted_amount)}
    end
  end

  @doc """
  Convert `money` from one currency to another and raises on error

  ## Arguments

  * `money` is any `Money.t` struct returned by `Cldr.Currency.new/2`

  * `to_currency` is a valid currency code into which the `money` is converted

  * `rates` is a `Map` of currency rates where the map key is an upcased
    atom or string and the value is a Decimal conversion factor.  The default is the
    latest available exchange rates returned from `Money.ExchangeRates.latest_rates()`

  ## Examples

      iex> Money.to_currency! Money.new(:USD, 100), :AUD, %{USD: Decimal.new(1), AUD: Decimal.from_float(0.7345)}
      #Money<:AUD, 73.4500>

      iex> Money.to_currency! Money.new("USD", 100), "AUD", %{"USD" => Decimal.new(1), "AUD" => Decimal.from_float(0.7345)}
      #Money<:AUD, 73.4500>

      Money.to_currency! Money.new(:USD, 100), :ZZZ, %{USD: Decimal.new(1), AUD: Decimal.from_float(0.7345)}
      ** (Cldr.UnknownCurrencyError) Currency :ZZZ is not known

  """
  @spec to_currency!(
          Money.t(),
          currency_code(),
          ExchangeRates.t() | {:ok, ExchangeRates.t()} | {:error, {module(), String.t()}}
        ) :: Money.t() | no_return

  def to_currency!(money, to_currency, rates \\ Money.ExchangeRates.latest_rates())

  def to_currency!(%Money{} = money, currency, rates) do
    money
    |> to_currency(currency, rates)
    |> do_to_currency!
  end

  defp do_to_currency!({:ok, converted}) do
    converted
  end

  defp do_to_currency!({:error, {exception, reason}}) do
    raise exception, reason
  end

  @doc """
  Returns the effective cross-rate to convert from one currency
  to another.

  ## Arguments

  * `from` is any `Money.t` struct returned by `Cldr.Currency.new/2` or a valid
     currency code

  * `to_currency` is a valid currency code into which the `money` is converted

  * `rates` is a `Map` of currency rates where the map key is an upcased
    atom or string and the value is a Decimal conversion factor.  The default is the
    latest available exchange rates returned from `Money.ExchangeRates.latest_rates()`

  ## Examples

      Money.cross_rate(Money.new(:USD, 100), :AUD, %{USD: Decimal.new(1), AUD: Decimal.new("0.7345")})
      {:ok, #Decimal<0.7345>}

      Money.cross_rate Money.new(:USD, 100), :ZZZ, %{USD: Decimal.new(1), AUD: Decimal.new(0.7345)}
      ** (Cldr.UnknownCurrencyError) Currency :ZZZ is not known

  """
  @spec cross_rate(
          Money.t() | currency_code,
          currency_code,
          ExchangeRates.t() | {:ok, ExchangeRates.t()}
        ) :: {:ok, Decimal.t()} | {:error, {module(), String.t()}}

  def cross_rate(from, to, rates \\ Money.ExchangeRates.latest_rates())

  def cross_rate(from, to, {:ok, rates}) do
    cross_rate(from, to, rates)
  end

  def cross_rate(%Money{currency: from_currency}, to_currency, %{} = rates) do
    cross_rate(from_currency, to_currency, rates)
  end

  def cross_rate(from_currency, to_currency, %{} = rates) do
    with {:ok, from_code} <- validate_currency(from_currency),
         {:ok, to_code} <- validate_currency(to_currency),
         {:ok, from_rate} <- get_rate(from_code, rates),
         {:ok, to_rate} <- get_rate(to_code, rates) do
      {:ok, Decimal.div(to_rate, from_rate)}
    end
  end

  @doc """
  Returns the effective cross-rate to convert from one currency
  to another.

  ## Arguments

  * `from` is any `Money.t` struct returned by `Cldr.Currency.new/2` or a valid
     currency code

  * `to_currency` is a valid currency code into which the `money` is converted

  * `rates` is a `Map` of currency rates where the map key is an upcased
    atom or string and the value is a Decimal conversion factor.  The default is the
    latest available exchange rates returned from `Money.ExchangeRates.latest_rates()`

  ## Examples

      iex> Money.cross_rate!(Money.new(:USD, 100), :AUD, %{USD: Decimal.new(1), AUD: Decimal.new("0.7345")})
      #Decimal<0.7345>

      iex> Money.cross_rate!(:USD, :AUD, %{USD: Decimal.new(1), AUD: Decimal.new("0.7345")})
      #Decimal<0.7345>

      Money.cross_rate Money.new(:USD, 100), :ZZZ, %{USD: Decimal.new(1), AUD: Decimal.new("0.7345")}
      ** (Cldr.UnknownCurrencyError) Currency :ZZZ is not known

  """
  @spec cross_rate!(
          Money.t() | currency_code,
          currency_code,
          ExchangeRates.t() | {:ok, ExchangeRates.t()}
        ) :: Decimal.t() | no_return

  def cross_rate!(from, to_currency, rates \\ Money.ExchangeRates.latest_rates())

  def cross_rate!(from, to_currency, rates) do
    cross_rate(from, to_currency, rates)
    |> do_cross_rate!
  end

  defp do_cross_rate!({:ok, rate}) do
    rate
  end

  defp do_cross_rate!({:error, {exception, reason}}) do
    raise exception, reason
  end

  @doc """
  Calls `Decimal.reduce/1` on the given `Money.t()`

  This will reduce the coefficient and exponent of the
  decimal amount in a standard way that may aid in
  native comparison of `%Money.t()` items.

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
  @spec reduce(Money.t()) :: Money.t()
  def reduce(%Money{currency: currency, amount: amount}) do
    %Money{currency: currency, amount: Decimal.reduce(amount)}
  end

  @doc """
  Returns a tuple comprising the currency code, integer amount,
  exponent and remainder

  Some services require submission of money items as an integer
  with an implied exponent that is appropriate to the currency.

  Rather than return only the integer, `Money.to_integer_exp`
  returns the currency code, integer, exponent and remainder.
  The remainder is included because to return an integer
  money with an implied exponent the `Money` has to be rounded
  potentially leaving a remainder.

  ## Options

  * `money` is any `Money.t` struct returned by `Cldr.Currency.new/2`

  ## Notes

  * Since the returned integer is expected to have the implied fractional
  digits the `Money` needs to be rounded which is what this function does.

  ## Example

      iex> m = Money.new(:USD, "200.012356")
      #Money<:USD, 200.012356>
      iex> Money.to_integer_exp(m)
      {:USD, 20001, -2, Money.new(:USD, "0.002356")}

      iex> m = Money.new(:USD, "200.00")
      #Money<:USD, 200.00>
      iex> Money.to_integer_exp(m)
      {:USD, 20000, -2, Money.new(:USD, "0.00")}

  """
  def to_integer_exp(%Money{} = money, opts \\ []) do
    new_money =
      money
      |> Money.round(opts)
      |> Money.reduce()

    {:ok, remainder} = Money.sub(money, new_money)
    {:ok, currency} = Currency.currency_for_code(money.currency)
    digits = digits_from_opts(currency, opts[:currency_digits])
    exponent = -digits
    exponent_adjustment = abs(exponent - new_money.amount.exp)
    integer = Cldr.Math.power_of_10(exponent_adjustment) * new_money.amount.coef

    {money.currency, integer, exponent, remainder}
  end

  @doc """
  Convert an integer representation of money into a `Money` struct.

  This is the inverse operation of `Money.to_integer_exp/1`. Note
  that the ISO definition of currency digits (subunit) is *always*
  used.  This is, in some cases like the Colombian Peso (COP)
  different to the CLDR definition.

  ## Options

  * `integer` is an integer representation of a mooney item including
    any decimal digits.  ie. 20000 would interpreted to mean $200.00

  * `currency` is the currency code for the `integer`.  The assumed
    decimal places is derived from the currency code.

  ## Returns

  * A `Money` struct or

  * `{:error, {Cldr.UnknownCurrencyError, message}}`

  ## Examples

      iex> Money.from_integer(20000, :USD)
      #Money<:USD, 200.00>

      iex> Money.from_integer(200, :JPY)
      #Money<:JPY, 200>

      iex> Money.from_integer(20012, :USD)
      #Money<:USD, 200.12>

      iex> Money.from_integer(20012, :COP)
      #Money<:COP, 200.12>

  """
  @spec from_integer(integer, currency_code) :: Money.t() | {:error, module(), String.t()}
  def from_integer(amount, currency) when is_integer(amount) do
    with {:ok, currency} <- validate_currency(currency),
         {:ok, %{iso_digits: digits}} <- Currency.currency_for_code(currency) do
      sign = if amount < 0, do: -1, else: 1
      digits = if digits == 0, do: 0, else: -digits

      sign
      |> Decimal.new(abs(amount), digits)
      |> Money.new(currency)
    end
  end

  @doc """
  Return a zero amount `Money.t` in the given currency

  ## Example

      iex> Money.zero(:USD)
      #Money<:USD, 0>

      iex> money = Money.new(:USD, 200)
      iex> Money.zero(money)
      #Money<:USD, 0>

      iex> Money.zero :ZZZ
      {:error, {Cldr.UnknownCurrencyError, "The currency :ZZZ is invalid"}}

  """
  @spec zero(currency_code | Money.t()) :: Money.t()
  def zero(%{currency: currency, amount: _amount}) do
    zero(currency)
  end

  def zero(currency) do
    with {:ok, currency} <- validate_currency(currency) do
      Money.new(currency, 0)
    end
  end

  @doc false
  def from_integer({currency, integer, _exponent, _remainder}) do
    from_integer(integer, currency)
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

  def get_env(key, default, :maybe_integer) do
    key
    |> get_env(default)
    |> to_maybe_integer
  end

  def get_env(key, default, :module) do
    key
    |> get_env(default)
    |> to_module()
  end

  def get_env(key, default, :boolean) do
    case get_env(key, default) do
      true ->
        true

      false ->
        false

      other ->
        raise RuntimeError,
              "[ex_money] The configuration key " <>
                "#{inspect(key)} must be either true or false. #{inspect(other)} was provided."
    end
  end

  defp to_integer(nil), do: nil
  defp to_integer(n) when is_integer(n), do: n
  defp to_integer(n) when is_binary(n), do: String.to_integer(n)

  defp to_maybe_integer(nil), do: nil
  defp to_maybe_integer(n) when is_integer(n), do: n
  defp to_maybe_integer(n) when is_atom(n), do: n
  defp to_maybe_integer(n) when is_binary(n), do: String.to_integer(n)

  defp to_module(nil), do: nil
  defp to_module(module_name) when is_atom(module_name), do: module_name

  defp to_module(module_name) when is_binary(module_name) do
    Module.concat([module_name])
  end

  defp get_rate(currency, rates) do
    rates
    |> Map.take([currency, Atom.to_string(currency)])
    |> Map.values()
    |> case do
      [rate] ->
        {:ok, rate}

      _ ->
        {:error,
         {Money.ExchangeRateError,
          "No exchange rate is available for currency #{inspect(currency)}"}}
    end
  end

  @doc false
  def json_library do
    @json_library
  end

  defp parse_decimal(string, nil, nil) do
    parse_decimal(string, default_backend().get_locale, default_backend())
  end

  defp parse_decimal(string, nil, backend) do
    parse_decimal(string, backend.get_locale, backend)
  end

  defp parse_decimal(string, locale, nil) do
    parse_decimal(string, locale, default_backend())
  end

  defp parse_decimal(string, locale, backend) do
    with {:ok, locale} <- Cldr.validate_locale(locale, backend),
         {:ok, symbols} <- Cldr.Number.Symbol.number_symbols_for(locale, backend) do
      decimal =
        string
        |> String.replace(symbols.latn.group, "")
        |> String.replace(symbols.latn.decimal, ".")
        |> Decimal.new()

      {:ok, decimal}
    end
  end

  @app_name Money.Mixfile.project() |> Keyword.get(:app)
  @doc false
  def app_name do
    @app_name
  end

  @doc false
  def default_backend() do
    Application.get_env(@app_name, :default_cldr_backend) ||
      raise "A default backend must be configured"
  end
end
