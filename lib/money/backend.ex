defmodule Money.Backend do
  @moduledoc false

  def define_money_module(config) do
    module = inspect(__MODULE__)
    backend = config.backend
    config = Macro.escape(config)

    quote location: :keep, bind_quoted: [module: module, backend: backend, config: config] do
      defmodule Money do
        @moduledoc false
        if Cldr.Config.include_module_docs?(config.generate_docs) do
          @moduledoc """
          A backend module for Money.

          This module provides the same api as the Money
          module however:

          * It matches the standard behaviour of other
          `ex_cldr` based libraries in maintaining the
          main public API on the backend module

          * It does not require the `:backend` option to
          be provided since that is implied through the
          use of the backend module.

          All the functions in this module delegate to
          the functions in `Money`.

          """
        end

        defdelegate validate_currency(currency_code), to: Cldr
        defdelegate known_currencies, to: Cldr
        defdelegate known_current_currencies, to: Elixir.Money
        defdelegate known_historic_currencies, to: Elixir.Money
        defdelegate known_tender_currencies, to: Elixir.Money

        require Cldr.Macros

        alias Elixir.Money.ExchangeRates

        @doc """
        Returns a %:'Elixir.Money'{} struct from a currency code and a currency amount or
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

            iex> #{inspect(__MODULE__)}.new(:USD, 100)
            Money.new(:USD, "100")

            iex> #{inspect(__MODULE__)}.new(100, :USD)
            Money.new(:USD, "100")

            iex> #{inspect(__MODULE__)}.new("USD", 100)
            Money.new(:USD, "100")

            iex> #{inspect(__MODULE__)}.new("thb", 500)
            Money.new(:THB, "500")

            iex> #{inspect(__MODULE__)}.new("EUR", Decimal.new(100))
            Money.new(:EUR, "100")

            iex> #{inspect(__MODULE__)}.new(:EUR, "100.30")
            Money.new(:EUR, "100.30")

            iex> #{inspect(__MODULE__)}.new(:XYZZ, 100)
            {:error, {Money.UnknownCurrencyError, "The currency :XYZZ is invalid"}}

            iex> #{inspect(__MODULE__)}.new("1.000,99", :EUR, locale: "de")
            Money.new(:EUR, "1000.99")

            iex> #{inspect(__MODULE__)}.new 123.445, :USD
            {:error,
             {Money.InvalidAmountError,
              "Float amounts are not supported in new/2 due to potenial " <>
              "rounding and precision issues.  If absolutely required, " <>
              "use Money.from_float/2"}}

        """
        @spec new(
                Elixir.Money.amount() | Elixir.Money.currency_code(),
                Elixir.Money.amount()
                | Elixir.Money.currency_code(),
                Keyword.t()
              ) ::
                Elixir.Money.t() | {:error, {module(), String.t()}}

        def new(currency_code, amount, options \\ []) do
          Elixir.Money.new(currency_code, amount, options)
        end

        @doc """
        Returns a %:'Elixir.Money'{} struct from a currency code and a currency amount. Raises an
        exception if the current code is invalid.

        ## Arguments

        * `currency_code` is an ISO4217 three-character upcased binary or atom

        * `amount` is an integer, float or Decimal

        ## Examples

            Money.new!(:XYZZ, 100)
            ** (Money.UnknownCurrencyError) Currency :XYZZ is not known
              (ex_money) lib/money.ex:177: Money.new!/2

        """
        @spec new!(
                Elixir.Money.amount() | Elixir.Money.currency_code(),
                Elixir.Money.amount()
                | Elixir.Money.currency_code(),
                Keyword.t()
              ) ::
                Elixir.Money.t() | no_return()

        def new!(currency_code, amount, options \\ []) do
          Elixir.Money.new!(currency_code, amount, options)
        end

        @doc """
        Returns a %:'Elixir.Money'{} struct from a currency code and a float amount, or
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

            iex> #{inspect(__MODULE__)}.from_float 1.23456, :USD
            Money.new(:USD, "1.23456")

            iex> #{inspect(__MODULE__)}.from_float 1.234567890987656, :USD
            {:error,
              {Money.InvalidAmountError,
                "The precision of the float 1.234567890987656 is " <>
                "greater than 15 which could lead to unexpected results. " <>
                "Reduce the precision or call Money.new/2 with a Decimal or String amount"}}

        """
        Cldr.Macros.doc_since("2.0.0")

        @spec from_float(
                float | Elixir.Money.currency_code(),
                float | Elixir.Money.currency_code(),
                Keyword.t()
              ) ::
                Elixir.Money.t() | {:error, {module(), String.t()}}

        def from_float(currency_code, amount, options \\ []) do
          Elixir.Money.from_float(currency_code, amount, options)
        end

        @doc """
        Returns a %:'Elixir.Money'{} struct from a currency code and a float amount, or
        raises an exception if the currency code is invalid.

        See `Money.from_float/2` for further information.

        **Note** that `Money` cannot detect lack of precision or rounding errors
        introduced upstream. This function therefore should be used with
        great care and its use should be considered potentially harmful.

        ## Arguments

        * `currency_code` is an ISO4217 three-character upcased binary or atom

        * `amount` is a float

        * `options` is a keyword list of options passed
          to `Money.new/3`. The default is `[]`.

        ## Examples

            iex> #{inspect(__MODULE__)}.from_float!(:USD, 1.234)
            Money.new(:USD, "1.234")

            Money.from_float!(:USD, 1.234567890987654)
            #=> ** (Money.InvalidAmountError) The precision of the float 1.234567890987654 is greater than 15 which could lead to unexpected results. Reduce the precision or call Money.new/2 with a Decimal or String amount
                (ex_money) lib/money.ex:293: Money.from_float!/2

        """
        # @doc since: "2.0.0"
        @spec from_float!(Elixir.Money.currency_code(), float, Keyword.t()) ::
                Elixir.Money.t() | no_return()

        def from_float!(currency_code, amount, options \\ []) do
          Elixir.Money.from_float!(currency_code, amount)
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
          is a `Cldr` backend module(). The default is `Money.default_backend()`

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

        * `:default_currency` is any valid currency code or `false`
          that will used if no currency code, symbol or description is
          indentified in the parsed string. The default is `nil`
          which means that the default currency associated with
          the `:locale` option will be used. If `false` then the
          currency assocated with the `:locale` option will not be
          used and an error will be returned if there is no currency
          in the string being parsed.

        ## Returns

        * a `Money.t` if parsing is successful or

        * `{:error, {exception, reason}}` if an error is
          detected.

        ## Examples

            iex> #{inspect(__MODULE__)}.parse("USD 100")
            Money.new(:USD, "100")

            iex> #{inspect(__MODULE__)}.parse "USD 100,00", locale: "de"
            Money.new(:USD, "100.00")

            iex> #{inspect(__MODULE__)}.parse("100 USD")
            Money.new(:USD, "100")

            iex> #{inspect(__MODULE__)}.parse("100 eurosports", fuzzy: 0.8)
            Money.new(:EUR, "100")

            iex> #{inspect(__MODULE__)}.parse("100 eurosports", fuzzy: 0.9)
            {:error,
              {Money.UnknownCurrencyError, "The currency \\"eurosports\\" is unknown or not supported"}}

            iex> #{inspect(__MODULE__)}.parse("100 afghan afghanis")
            Money.new(:AFN, "100")

            iex> #{inspect(__MODULE__)}.parse("100", default_currency: false)
            {:error,
              {Money.Invalid, "A currency code, symbol or description must be specified but was not found in \\"100\\""}}

            iex> #{inspect(__MODULE__)}.parse("USD 100 with trailing text")
            {:error,
              {Money.ParseError, "Could not parse \\"USD 100 with trailing text\\"."}}

        """
        Cldr.Macros.doc_since("3.2.0")

        @spec parse(String.t(), Keyword.t()) ::
                Elixir.Money.t() | {:error, {module(), String.t()}}
        def parse(string, options \\ []) do
          Elixir.Money.parse(string, options)
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

            iex> #{inspect(__MODULE__)}.to_string Money.new(:USD, 1234)
            {:ok, "$1,234.00"}

            iex> #{inspect(__MODULE__)}.to_string Money.new(:JPY, 1234)
            {:ok, "¥1,234"}

            iex> #{inspect(__MODULE__)}.to_string Money.new(:THB, 1234)
            {:ok, "THB 1,234.00"}

            iex> #{inspect(__MODULE__)}.to_string Money.new(:USD, 1234), format: :long
            {:ok, "1,234 US dollars"}

        """
        @spec to_string(Elixir.Money.t(), Keyword.t() | Cldr.Number.Format.Options.t()) ::
                {:ok, String.t()} | {:error, {atom, String.t()}}

        def to_string(money, options \\ []) do
          options = Keyword.put(options, :backend, unquote(backend))
          Elixir.Money.to_string(money, options)
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

            iex> #{inspect(__MODULE__)}.to_string! Money.new(:USD, 1234)
            "$1,234.00"

            iex> #{inspect(__MODULE__)}.to_string! Money.new(:JPY, 1234)
            "¥1,234"

            iex> #{inspect(__MODULE__)}.to_string! Money.new(:THB, 1234)
            "THB 1,234.00"

            iex> #{inspect(__MODULE__)}.to_string! Money.new(:USD, 1234), format: :long
            "1,234 US dollars"

        """
        @spec to_string!(Elixir.Money.t(), Keyword.t()) :: String.t() | no_return()

        def to_string!(%Elixir.Money{} = money, options \\ []) do
          options = Keyword.put(options, :backend, unquote(backend))
          Elixir.Money.to_string!(money, options)
        end

        @doc """
        Returns the amount part of a `Money` type as a `Decimal`

        ## Arguments

        * `money` is any valid `Money.t` type returned
          by `Money.new/2`

        ## Returns

        * a `Decimal.t`

        ## Example

            iex> m = #{inspect(__MODULE__)}.new("USD", 100)
            iex> #{inspect(__MODULE__)}.to_decimal(m)
            #Decimal<100>

        """
        @spec to_decimal(money :: Elixir.Money.t()) :: Decimal.t()
        def to_decimal(%Elixir.Money{} = money) do
          Elixir.Money.to_decimal(money)
        end

        @doc """
        The absolute value of a `Money` amount.
        Returns a `Money` type with a positive sign for the amount.

        ## Arguments

        * `money` is any valid `Money.t` type returned
          by `Money.new/2`

        ## Returns

        * a `Money.t`

        ## Example

            iex> m = #{inspect(__MODULE__)}.new("USD", -100)
            iex> #{inspect(__MODULE__)}.abs(m)
            Money.new(:USD, "100")

        """
        @spec abs(money :: Elixir.Money.t()) :: Elixir.Money.t()
        def abs(%Elixir.Money{} = money) do
          Elixir.Money.abs(money)
        end

        @doc """
        Add two `Money` values.

        ## Arguments

        * `money_1` and `money_2` are any valid `Money.t` types returned
          by `Money.new/2`

        ## Returns

        * `{:ok, money}` or

        * `{:error, reason}`

        ## Example

            iex> #{inspect(__MODULE__)}.add Money.new(:USD, 200), Money.new(:USD, 100)
            {:ok, Money.new(:USD, 300)}

            iex> #{inspect(__MODULE__)}.add Money.new(:USD, 200), Money.new(:AUD, 100)
            {:error, {ArgumentError, "Cannot add monies with different currencies. " <>
              "Received :USD and :AUD."}}

        """
        @spec add(money_1 :: Elixir.Money.t(), money_2 :: Elixir.Money.t()) ::
                {:ok, Elixir.Money.t()} | {:error, {module(), String.t()}}
        def add(%Elixir.Money{} = money_1, %Elixir.Money{} = money_2) do
          Elixir.Money.add(money_1, money_2)
        end

        @doc """
        Add two `Money` values and raise on error.

        ## Arguments

        * `money_1` and `money_2` are any valid `Money.t` types returned
          by `Money.new/2`

        ## Returns

        * `{:ok, money}` or

        * raises an exception

        ## Examples

            iex> #{inspect(__MODULE__)}.add! Money.new(:USD, 200), Money.new(:USD, 100)
            Money.new(:USD, "300")

            #{inspect(__MODULE__)}.add! Money.new(:USD, 200), Money.new(:CAD, 500)
            ** (ArgumentError) Cannot add two %:'Elixir.Money'{} with different currencies. Received :USD and :CAD.

        """
        def add!(%Elixir.Money{} = money_1, %Elixir.Money{} = money_2) do
          Elixir.Money.add!(money_1, money_2)
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

            iex> #{inspect(__MODULE__)}.sub Money.new(:USD, 200), Money.new(:USD, 100)
            {:ok, Money.new(:USD, 100)}

        """
        @spec sub(money_1 :: Elixir.Money.t(), money_2 :: Elixir.Money.t()) ::
                {:ok, Elixir.Money.t()} | {:error, {module(), String.t()}}

        def sub(%Elixir.Money{} = money_1, %Elixir.Money{} = money_2) do
          Elixir.Money.sub(money_1, money_2)
        end

        @doc """
        Subtract one `Money` value struct from another and raise on error.

        Returns either `{:ok, money}` or `{:error, reason}`.

        ## Arguments

        * `money_1` and `money_2` are any valid `Money.t` types returned
          by `Money.new/2`

        ## Returns

        * a `Money.t` struct or

        * raises an exception

        ## Examples

            iex> #{inspect(__MODULE__)}.sub! Money.new(:USD, 200), Money.new(:USD, 100)
            Money.new(:USD, "100")

            #{inspect(__MODULE__)}.sub! Money.new(:USD, 200), Money.new(:CAD, 500)
            ** (ArgumentError) Cannot subtract monies with different currencies. Received :USD and :CAD.

        """
        @spec sub!(money_1 :: Elixir.Money.t(), money_2 :: Elixir.Money.t()) ::
                Elixir.Money.t() | none()

        def sub!(%Elixir.Money{} = money_1, %Elixir.Money{} = money_2) do
          Elixir.Money.sub!(money_1, money_2)
        end

        @doc """
        Multiply a `Money` value by a number.

        ## Arguments

        * `money` is any valid `Money.t` type returned
          by `Money.new/2`

        * `number` is an integer, float or `Decimal.t`

        > Note that multipling one %:'Elixir.Money'{} by another is not supported.

        ## Returns

        * `{:ok, money}` or

        * `{:error, reason}`

        ## Example

            iex> #{inspect(__MODULE__)}.mult(Money.new(:USD, 200), 2)
            {:ok, Money.new(:USD, 400)}

            iex> #{inspect(__MODULE__)}.mult(Money.new(:USD, 200), "xx")
            {:error, {ArgumentError, "Cannot multiply money by \\"xx\\""}}

        """
        @spec mult(Elixir.Money.t(), Cldr.Math.number_or_decimal()) ::
                {:ok, Elixir.Money.t()} | {:error, {module(), String.t()}}

        def mult(%Elixir.Money{} = money, number) do
          Elixir.Money.mult(money, number)
        end

        @doc """
        Multiply a `Money` value by a number and raise on error.

        ## Arguments

        * `money` is any valid `Money.t` types returned
          by `Money.new/2`

        * `number` is an integer, float or `Decimal.t`

        ## Returns

        * a `Money.t` or

        * raises an exception

        ## Examples

            iex> #{inspect(__MODULE__)}.mult!(Money.new(:USD, 200), 2)
            Money.new(:USD, "400")

            #{inspect(__MODULE__)}.mult!(Money.new(:USD, 200), :invalid)
            ** (ArgumentError) Cannot multiply money by :invalid

        """
        @spec mult!(Elixir.Money.t(), Cldr.Math.number_or_decimal()) ::
                Elixir.Money.t() | none()
        def mult!(%Elixir.Money{} = money, number) do
          Elixir.Money.mult!(money, number)
        end

        @doc """
        Divide a `Money` value by a number.

        ## Arguments

        * `money` is any valid `Money.t` types returned
          by `Money.new/2`

        * `number` is an integer, float or `Decimal.t`

        > Note that dividing one %:'Elixir.Money'{} by another is not supported.

        ## Returns

        * `{:ok, money}` or

        * `{:error, reason}`

        ## Example

            iex> #{inspect(__MODULE__)}.div Money.new(:USD, 200), 2
            {:ok, Money.new(:USD, 100)}

            iex> #{inspect(__MODULE__)}.div(Money.new(:USD, 200), "xx")
            {:error, {ArgumentError, "Cannot divide money by \\"xx\\""}}

        """
        @spec div(Elixir.Money.t(), Cldr.Math.number_or_decimal()) ::
                {:ok, Elixir.Money.t()} | {:error, {module(), String.t()}}

        def div(%Elixir.Money{} = money_1, number) do
          Elixir.Money.div(money_1, number)
        end

        @doc """
        Divide a `Money` value by a number and raise on error.

        ## Arguments

        * `money` is any valid `Money.t` types returned
          by `Money.new/2`

        * `number` is an integer, float or `Decimal.t`

        ## Returns

        * a `Money.t` struct or

        * raises an exception

        ## Examples

            iex> #{inspect(__MODULE__)}.div Money.new(:USD, 200), 2
            {:ok, Money.new(:USD, 100)}

            #{inspect(__MODULE__)}.div(Money.new(:USD, 200), "xx")
            ** (ArgumentError) "Cannot divide money by \\"xx\\""]}}

        """
        def div!(%Elixir.Money{} = money, number) do
          Elixir.Money.div!(money, number)
        end

        @doc """
        Returns a boolean indicating if two `Money` values are equal

        ## Arguments

        * `money_1` and `money_2` are any valid `Money.t` types returned
          by `Money.new/2`

        ## Returns

        * `true` or `false`

        ## Example

            iex> #{inspect(__MODULE__)}.equal? Money.new(:USD, 200), Money.new(:USD, 200)
            true

            iex> #{inspect(__MODULE__)}.equal? Money.new(:USD, 200), Money.new(:USD, 100)
            false

        """
        @spec equal?(money_1 :: Elixir.Money.t(), money_2 :: Elixir.Money.t()) :: boolean
        def equal?(%Elixir.Money{} = money_1, %Elixir.Money{} = money_2) do
          Elixir.Money.equal?(money_1, money_2)
        end

        @doc """
        Compares two `Money` values numerically. If the first number is greater
        than the second :gt is returned, if less than :lt is returned, if both
        numbers are equal :eq is returned.

        ## Arguments

        * `money_1` and `money_2` are any valid `Money.t` types returned
          by `Money.new/2`

        ## Returns

        *  `:gt` | `:eq` | `:lt` or

        * `{:error, {module(), String.t}}`

        ## Examples

            iex> #{inspect(__MODULE__)}.compare Money.new(:USD, 200), Money.new(:USD, 100)
            :gt

            iex> #{inspect(__MODULE__)}.compare Money.new(:USD, 200), Money.new(:USD, 200)
            :eq

            iex> #{inspect(__MODULE__)}.compare Money.new(:USD, 200), Money.new(:USD, 500)
            :lt

            iex> #{inspect(__MODULE__)}.compare Money.new(:USD, 200), Money.new(:CAD, 500)
            {:error,
             {ArgumentError,
              "Cannot compare monies with different currencies. Received :USD and :CAD."}}

        """
        @spec compare(money_1 :: Elixir.Money.t(), money_2 :: Elixir.Money.t()) ::
                :gt | :eq | :lt | {:error, {module(), String.t()}}
        def compare(%Elixir.Money{} = money_1, %Elixir.Money{} = money_2) do
          Elixir.Money.compare(money_1, money_2)
        end

        @doc """
        Compares two `Money` values numerically and raises on error.

        ## Arguments

        * `money_1` and `money_2` are any valid `Money.t` types returned
          by `Money.new/2`

        ## Returns

        *  `:gt` | `:eq` | `:lt` or

        * raises an exception

        ## Examples

            #{inspect(__MODULE__)}.compare! Money.new(:USD, 200), Money.new(:CAD, 500)
            ** (ArgumentError) Cannot compare monies with different currencies. Received :USD and :CAD.

        """
        def compare!(%Elixir.Money{} = money_1, %Elixir.Money{} = money_2) do
          Elixir.Money.cmp!(money_1, money_2)
        end

        @doc """
        Compares two `Money` values numerically. If the first number is greater
        than the second #Integer<1> is returned, if less than Integer<-1> is
        returned. Otherwise, if both numbers are equal Integer<0> is returned.

        ## Arguments

        * `money_1` and `money_2` are any valid `Money.t` types returned
          by `Money.new/2`

        ## Returns

        *  `-1` | `0` | `1` or

        * `{:error, {module(), String.t}}`

        ## Examples

            iex> #{inspect(__MODULE__)}.cmp Money.new(:USD, 200), Money.new(:USD, 100)
            1

            iex> #{inspect(__MODULE__)}.cmp Money.new(:USD, 200), Money.new(:USD, 200)
            0

            iex> #{inspect(__MODULE__)}.cmp Money.new(:USD, 200), Money.new(:USD, 500)
            -1

            iex> #{inspect(__MODULE__)}.cmp Money.new(:USD, 200), Money.new(:CAD, 500)
            {:error,
             {ArgumentError,
              "Cannot compare monies with different currencies. Received :USD and :CAD."}}

        """
        @spec cmp(money_1 :: Elixir.Money.t(), money_2 :: Elixir.Money.t()) ::
                -1 | 0 | 1 | {:error, {module(), String.t()}}
        def cmp(%Elixir.Money{} = money_1, %Elixir.Money{} = money_2) do
          Elixir.Money.cmp(money_1, money_2)
        end

        @doc """
        Compares two `Money` values numerically and raises on error.

        ## Arguments

        * `money_1` and `money_2` are any valid `Money.t` types returned
          by `Money.new/2`

        ## Returns

        *  `-1` | `0` | `1` or

        * raises an exception

        ## Examples

            #{inspect(__MODULE__)}.cmp! Money.new(:USD, 200), Money.new(:CAD, 500)
            ** (ArgumentError) Cannot compare monies with different currencies. Received :USD and :CAD.

        """
        def cmp!(%Elixir.Money{} = money_1, %Elixir.Money{} = money_2) do
          Elixir.Money.cmp!(money_1, money_2)
        end

        @doc """
        Split a `Money` value into a number of parts maintaining the currency's
        precision and rounding and ensuring that the parts sum to the original
        amount.

        ## Arguments

        * `money` is a `%:'Elixir.Money'{}` struct

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

            #{inspect(__MODULE__)}.split Money.new(123.5, :JPY), 3
            {¥41, ¥1}

            #{inspect(__MODULE__)}.split Money.new(123.4, :JPY), 3
            {¥41, ¥0}

            #{inspect(__MODULE__)}.split Money.new(123.7, :USD), 9
            {$13.74, $0.04}

        """
        @spec split(Elixir.Money.t(), non_neg_integer) ::
                {Elixir.Money.t(), Elixir.Money.t()}

        def split(%Elixir.Money{} = money, parts) when is_integer(parts) do
          Elixir.Money.split(money, parts)
        end

        @doc """
        Round a `Money` value into the acceptable range for the requested currency.

        ## Arguments

        * `money` is a `%:'Elixir.Money'{}` struct

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

            iex> #{inspect(__MODULE__)}.round Money.new("123.73", :CHF), currency_digits: :cash
            Money.new(:CHF, "123.75")

            iex> #{inspect(__MODULE__)}.round Money.new("123.73", :CHF), currency_digits: 0
            Money.new(:CHF, "124")

            iex> #{inspect(__MODULE__)}.round Money.new("123.7456", :CHF)
            Money.new(:CHF, "123.75")

            iex> #{inspect(__MODULE__)}.round Money.new("123.7456", :JPY)
            Money.new(:JPY, "124")

        """
        @spec round(Elixir.Money.t(), Keyword.t()) :: Elixir.Money.t()
        def round(%Elixir.Money{} = money, options \\ []) do
          Elixir.Money.round(money, options)
        end

        @doc """
        Set the fractional part of a `Money`.

        ## Arguments

        * `money` is a `%:'Elixir.Money'{}` struct

        * `fraction` is an integer amount that will be set
          as the fraction of the `money`

        ## Notes

        The fraction can only be set if it matches the number of
        decimal digits for the currency associated with the `money`.
        Therefore, for a currency with 2 decimal digits, the
        maximum for `fraction` is `99`.

        ## Examples

            iex> #{inspect(__MODULE__)}.put_fraction Money.new(:USD, "2.49"), 99
            Money.new(:USD, "2.99")

            iex> #{inspect(__MODULE__)}.put_fraction Money.new(:USD, "2.49"), 0
            Money.new(:USD, "2.0")

            iex> #{inspect(__MODULE__)}.put_fraction Money.new(:USD, "2.49"), 999
            {:error,
             {Money.InvalidAmountError, "Rounding up to 999 is invalid for currency :USD"}}

        """

        def put_fraction(%Elixir.Money{} = money, upto) when is_integer(upto) do
          Elixir.Money.put_fraction(money, upto)
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

            #{inspect(__MODULE__)}.to_currency(Money.new(:USD, 100), :AUD, %{USD: Decimal.new(1), AUD: Decimal.from_float(0.7345)})
            {:ok, Money.new(:AUD, "73.4500")}

            #{inspect(__MODULE__)}.to_currency(Money.new("USD", 100), "AUD", %{"USD" => Decimal.new(1), "AUD" => Decimal.from_float(0.7345)})
            {:ok, Money.new(:AUD, "73.4500")}

            iex> #{inspect(__MODULE__)}.to_currency Money.new(:USD, 100), :AUDD, %{USD: Decimal.new(1), AUD: Decimal.from_float(0.7345)}
            {:error, {Cldr.UnknownCurrencyError, "The currency :AUDD is invalid"}}

            iex> #{inspect(__MODULE__)}.to_currency Money.new(:USD, 100), :CHF, %{USD: Decimal.new(1), AUD: Decimal.from_float(0.7345)}
            {:error, {Money.ExchangeRateError, "No exchange rate is available for currency :CHF"}}

        """
        @spec to_currency(
                Elixir.Money.t(),
                Elixir.Money.currency_code(),
                ExchangeRates.t()
                | {:ok, ExchangeRates.t()}
                | {:error, {module(), String.t()}}
              ) :: {:ok, Elixir.Money.t()} | {:error, {module(), String.t()}}

        def to_currency(money, to_currency, rates \\ ExchangeRates.latest_rates()) do
          Elixir.Money.to_currency(money, to_currency, rates)
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

            iex> #{inspect(__MODULE__)}.to_currency! Money.new(:USD, 100), :AUD, %{USD: Decimal.new(1), AUD: Decimal.from_float(0.7345)}
            Money.new(:AUD, "73.4500")

            iex> #{inspect(__MODULE__)}.to_currency! Money.new("USD", 100), "AUD", %{"USD" => Decimal.new(1), "AUD" => Decimal.from_float(0.7345)}
            Money.new(:AUD, "73.4500")

            #{inspect(__MODULE__)}.to_currency! Money.new(:USD, 100), :ZZZ, %{USD: Decimal.new(1), AUD: Decimal.from_float(0.7345)}
            ** (Cldr.UnknownCurrencyError) Currency :ZZZ is not known

        """
        @spec to_currency!(
                Elixir.Money.t(),
                Elixir.Money.currency_code(),
                ExchangeRates.t()
                | {:ok, ExchangeRates.t()}
                | {:error, {module(), String.t()}}
              ) :: Elixir.Money.t() | no_return

        def to_currency!(
              %Elixir.Money{} = money,
              currency,
              rates \\ ExchangeRates.latest_rates()
            ) do
          Elixir.Money.to_currency!(money, currency, rates)
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

            #{inspect(__MODULE__)}.cross_rate(Money.new(:USD, 100), :AUD, %{USD: Decimal.new(1), AUD: Decimal.new("0.7345")})
            {:ok, #Decimal<0.7345>}

            #{inspect(__MODULE__)}.cross_rate Money.new(:USD, 100), :ZZZ, %{USD: Decimal.new(1), AUD: Decimal.new(0.7345)}
            ** (Cldr.UnknownCurrencyError) Currency :ZZZ is not known

        """
        @spec cross_rate(
                Elixir.Money.t() | Elixir.Money.currency_code(),
                Elixir.Money.currency_code(),
                ExchangeRates.t() | {:ok, ExchangeRates.t()}
              ) :: {:ok, Decimal.t()} | {:error, {module(), String.t()}}

        def cross_rate(from, to, rates \\ ExchangeRates.latest_rates()) do
          Elixir.Money.cross_rate(from, to, rates)
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

            iex> #{inspect(__MODULE__)}.cross_rate!(Money.new(:USD, 100), :AUD, %{USD: Decimal.new(1), AUD: Decimal.new("0.7345")})
            #Decimal<0.7345>

            iex> #{inspect(__MODULE__)}.cross_rate!(:USD, :AUD, %{USD: Decimal.new(1), AUD: Decimal.new("0.7345")})
            #Decimal<0.7345>

            #{inspect(__MODULE__)}.cross_rate Money.new(:USD, 100), :ZZZ, %{USD: Decimal.new(1), AUD: Decimal.new("0.7345")}
            ** (Cldr.UnknownCurrencyError) Currency :ZZZ is not known

        """
        @spec cross_rate!(
                Elixir.Money.t() | Elixir.Money.currency_code(),
                Elixir.Money.currency_code(),
                ExchangeRates.t() | {:ok, ExchangeRates.t()}
              ) :: Decimal.t() | no_return

        def cross_rate!(from, to_currency, rates \\ ExchangeRates.latest_rates()) do
          Elixir.Money.cross_rate!(from, to_currency, rates)
        end

        @doc """
        Normalizes the underlying `Decimal` amount on the
        given `t:Elixir.Money`.

        This will normalize the coefficient and exponent of the
        decimal amount in a standard way that may aid in
        native comparison of `t:Elixir.Money` items.

        ## Example

            iex> x = %Money{currency: :USD, amount: %Decimal{sign: 1, coef: 42, exp: 0}}
            Money.new(:USD, "42")
            iex> y = %Money{currency: :USD, amount: %Decimal{sign: 1, coef: 4200000000, exp: -8}}
            Money.new(:USD, "42.00000000")
            iex> x == y
            false
            iex> y = Money.normalize(x)
            Money.new(:USD, "42")
            iex> x == y
            true

        """
        @spec normalize(Elixir.Money.t()) :: Elixir.Money.t()
        Cldr.Macros.doc_since("5.0.0")

        def normalize(%Elixir.Money{} = money) do
          Elixir.Money.normalize(money)
        end

        @deprecated "Use #{inspect(__MODULE__)}.normalize/1 instead."
        def reduce(money) do
          normalize(money)
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

        ## Arguments

        * `money` is any `Money.t` struct returned by `Cldr.Currency.new/2`

        ## Notes

        * Since the returned integer is expected to have the implied fractional
        digits the `Money` needs to be rounded which is what this function does.

        ## Example

            iex> m = #{inspect(__MODULE__)}.new(:USD, "200.012356")
            Money.new(:USD, "200.012356")
            iex> #{inspect(__MODULE__)}.to_integer_exp(m)
            {:USD, 20001, -2, Money.new(:USD, "0.002356")}

            iex> m = #{inspect(__MODULE__)}.new(:USD, "200.00")
            Money.new(:USD, "200.00")
            iex> #{inspect(__MODULE__)}.to_integer_exp(m)
            {:USD, 20000, -2, Money.new(:USD, "0.00")}

        """
        def to_integer_exp(%Elixir.Money{} = money) do
          Elixir.Money.to_integer_exp(money)
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

            iex> #{inspect(__MODULE__)}.from_integer(20000, :USD)
            Money.new(:USD, "200.00")

            iex> #{inspect(__MODULE__)}.from_integer(200, :JPY)
            Money.new(:JPY, "200")

            iex> #{inspect(__MODULE__)}.from_integer(20012, :USD)
            Money.new(:USD, "200.12")

            iex> #{inspect(__MODULE__)}.from_integer(20012, :COP)
            Money.new(:COP, "200.12")

        """
        @spec from_integer(integer, Elixir.Money.currency_code(), Keyword.t()) ::
                Elixir.Money.t() | {:error, module(), String.t()}

        def from_integer(amount, currency, options \\ []) when is_integer(amount) do
          Elixir.Money.from_integer(amount, currency, options)
        end

        @doc """
        Return a zero amount `t:Money` in the given currency.

        ## Arguments

        * `money_or_currency` is either a `t:Money` or
          a currency code

        * `options` is a keyword list of options passed
          to `Money.new/3`. The default is `[]`.

        ## Example

            iex> #{inspect(__MODULE__)}.zero(:USD)
            Money.new(:USD, "0")

            iex> money = Money.new(:USD, 200)
            iex> #{inspect(__MODULE__)}.zero(money)
            Money.new(:USD, "0")

            iex> #{inspect(__MODULE__)}.zero :ZZZ
            {:error, {Cldr.UnknownCurrencyError, "The currency :ZZZ is invalid"}}

        """
        @spec zero(Elixir.Money.currency_code() | Elixir.Money.t(), Keyword.t()) ::
                Elixir.Money.t()

        def zero(money, options \\ [])

        def zero(%Elixir.Money{} = money, options) do
          Elixir.Money.zero(money, options)
        end

        def zero(currency, options) when is_atom(currency) do
          Elixir.Money.zero(currency, options)
        end

        @doc false
        def from_integer({_currency, _integer, _exponent, _remainder} = value) do
          Elixir.Money.from_integer(value)
        end

        defp default_backend do
          Elixir.Money.default_backend()
        end
      end
    end
  end
end
