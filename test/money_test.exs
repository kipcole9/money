defmodule MoneyTest do
  use ExUnit.Case
  use ExUnitProperties

  import ExUnit.CaptureLog
  alias Money.Financial

  doctest Money
  doctest Money.ExchangeRates
  doctest Money.Currency
  doctest Money.ExchangeRates.Cache
  doctest Money.ExchangeRates.Cache.Ets
  doctest Money.ExchangeRates.Cache.Dets
  doctest Money.ExchangeRates.Retriever
  doctest Money.Financial
  doctest Money.Sigil

  test "create a new money struct with a binary currency code" do
    money = Money.new(1234, "USD")
    assert money.currency == :USD
    assert money.amount == Decimal.new(1234)
  end

  test "create a new money struct wth a binary currency code and binary amount" do
    money = Money.new("1234", "USD")
    assert money.currency == :USD
    assert money.amount == Decimal.new(1234)

    money = Money.new("USD", "1234")
    assert money.currency == :USD
    assert money.amount == Decimal.new(1234)
  end

  test "create a new money struct wth a invalid binary currency code and binary amount" do
    money = Money.new("1234", "ZZZ")
    assert money == {:error, {Money.Invalid, "Unable to create money from \"1234\" and \"ZZZ\""}}

    money = Money.new("ZZZ", "1234")
    assert money == {:error, {Money.Invalid, "Unable to create money from \"ZZZ\" and \"1234\""}}
  end

  test "create a new! money struct with a binary currency code" do
    money = Money.new!(1234, "USD")
    assert money.currency == :USD
    assert money.amount == Decimal.new(1234)
  end

  test "create a new money struct with an atom currency code" do
    money = Money.new(1234, :USD)
    assert money.currency == :USD
    assert money.amount == Decimal.new(1234)
  end

  test "create a new! money struct with an atom currency code" do
    money = Money.new!(1234, :USD)
    assert money.currency == :USD
    assert money.amount == Decimal.new(1234)
  end

  test "create a new money struct with a binary currency code with reversed params" do
    money = Money.new("USD", 1234)
    assert money.currency == :USD
    assert money.amount == Decimal.new(1234)
  end

  test "create a new money struct with a atom currency code with reversed params" do
    money = Money.new(:USD, 1234)
    assert money.currency == :USD
    assert money.amount == Decimal.new(1234)
  end

  test "create a new money struct with a lower case binary currency code with reversed params" do
    money = Money.new("usd", 1234)
    assert money.currency == :USD
    assert money.amount == Decimal.new(1234)
  end

  test "create a new currency with a locale to normalise an amount string" do
    money = Money.new(:USD, "1.234.567,99", locale: "de")
    assert money.currency == :USD
    assert money.amount == Decimal.new("1234567.99")

    money = Money.new(:USD, "1,234,567.99", locale: "en")
    assert money.currency == :USD
    assert money.amount == Decimal.new("1234567.99")
  end

  test "create a new money struct from a tuple" do
    money = Money.from_tuple({"USD", 1234})
    assert money.currency == :USD
    assert money.amount == Decimal.new(1234)
  end

  test "create a new! money struct from a tuple with bang method" do
    money = Money.from_tuple!({"USD", 1234})
    assert money.currency == :USD
    assert money.amount == Decimal.new(1234)
  end

  test "create a new money struct from a number and atom currency with bang method" do
    money = Money.new!(:USD, 1234)
    assert money.currency == :USD
    assert money.amount == Decimal.new(1234)
  end

  test "create a new money struct from a number and binary currency with bang method" do
    money = Money.new!("USD", 1234)
    assert money.currency == :USD
    assert money.amount == Decimal.new(1234)
  end

  test "create a new money struct from a decimal and binary currency with bang method" do
    money = Money.new!("USD", Decimal.new(1234))
    assert money.currency == :USD
    assert money.amount == Decimal.new(1234)

    money = Money.new!(Decimal.new(1234), "USD")
    assert money.currency == :USD
    assert money.amount == Decimal.new(1234)
  end

  test "create a new money struct from a decimal and atom currency with bang method" do
    money = Money.new!(:USD, Decimal.new(1234))
    assert money.currency == :USD
    assert money.amount == Decimal.new(1234)

    money = Money.new!(Decimal.new(1234), :USD)
    assert money.currency == :USD
    assert money.amount == Decimal.new(1234)
  end

  test "create a new money struct from an atom currency and a string amount" do
    money = Money.new!(:USD, "1234")
    assert money.currency == :USD
    assert money.amount == Decimal.new(1234)

    money = Money.new!("1234", :USD)
    assert money.currency == :USD
    assert money.amount == Decimal.new(1234)
  end

  test "that creating a money with a string amount that is invalid returns and error" do
    assert Money.new(:USD, "2134ff") ==
             {:error,
              {Money.InvalidAmountError, "Amount cannot be converted to a number: \"2134ff\""}}
  end

  test "raise when creating a new money struct from a tuple with an invalid currency code" do
    assert_raise Money.UnknownCurrencyError, "The currency \"ABCD\" is invalid", fn ->
      Money.from_tuple!({"ABCD", 1234})
    end
  end

  test "raise when creating a new money struct from invalid input" do
    assert_raise Money.UnknownCurrencyError, "The currency \"ABCDE\" is invalid", fn ->
      Money.from_tuple!({1234, "ABCDE"})
    end

    assert_raise Money.UnknownCurrencyError, "The currency \"ABCDE\" is invalid", fn ->
      Money.new!("ABCDE", 100)
    end

    assert_raise Money.UnknownCurrencyError, "The currency \"ABCDE\" is invalid", fn ->
      Money.new!(Decimal.new(100), "ABCDE")
    end

    assert_raise Money.UnknownCurrencyError, "The currency \"ABCDE\" is invalid", fn ->
      Money.new!("ABCDE", Decimal.new(100))
    end
  end

  test "create a new money struct with a decimal" do
    money = Money.new(:USD, Decimal.new(1234))
    assert money.currency == :USD
    assert money.amount == Decimal.new(1234)

    money = Money.new("usd", Decimal.new(1234))
    assert money.currency == :USD
    assert money.amount == Decimal.new(1234)

    money = Money.new(Decimal.new(1234), :USD)
    assert money.currency == :USD
    assert money.amount == Decimal.new(1234)

    money = Money.new(Decimal.new(1234), "usd")
    assert money.currency == :USD
    assert money.amount == Decimal.new(1234)
  end

  test "creating a money struct with an invalid atom currency code returns error tuple" do
    assert Money.new(:ZYZ, 100) ==
             {:error, {Money.UnknownCurrencyError, "The currency :ZYZ is invalid"}}
  end

  test "creating a money struct with an invalid binary currency code returns error tuple" do
    assert Money.new("ABCD", 100) ==
             {:error, {Money.UnknownCurrencyError, "The currency \"ABCD\" is invalid"}}
  end

  test "string output of money is correctly formatted" do
    money = Money.new(1234, :USD)
    assert Money.to_string(money) == {:ok, "$1,234.00"}
  end

  test "adding two money structs with same currency" do
    assert Money.add!(Money.new(:USD, 100), Money.new(:USD, 100)) == Money.new(:USD, 200)
  end

  test "subtracting two money structs with same currency" do
    assert Money.sub!(Money.new(:USD, 100), Money.new(:USD, 40)) == Money.new(:USD, 60)
  end

  test "adding two money structs with different currency raises" do
    assert_raise ArgumentError, ~r/Cannot add monies/, fn ->
      Money.add!(Money.new(:USD, 100), Money.new(:AUD, 100))
    end
  end

  test "subtracting two money structs with different currency raises" do
    assert_raise ArgumentError, ~r/Cannot subtract two monies/, fn ->
      Money.sub!(Money.new(:USD, 100), Money.new(:AUD, 100))
    end
  end

  test "cash flows with different currencies raises" do
    flows = [{1, Money.new(:USD, 100)}, {2, Money.new(:AUD, 100)}]

    assert_raise ArgumentError, ~r/More than one currency found in cash flows/, fn ->
      Money.Financial.present_value(flows, 0.12)
    end

    assert_raise ArgumentError, ~r/More than one currency found in cash flows/, fn ->
      Money.Financial.future_value(flows, 0.12)
    end

    assert_raise ArgumentError, ~r/More than one currency found in cash flows/, fn ->
      Money.Financial.net_present_value(flows, 0.12, Money.new(:EUR, 100))
    end
  end

  test "multiply a money by an integer" do
    assert Money.mult!(Money.new(:USD, 100), 2) == Money.new(:USD, 200)
  end

  test "multiply a money by an decimal" do
    assert Money.mult!(Money.new(:USD, 100), Decimal.new(2)) == Money.new(:USD, 200)
  end

  test "multiply a money by a float" do
    m1 = Money.mult!(Money.new(:USD, 100), 2.5)
    m2 = Money.new(:USD, 250)
    assert Money.equal?(m1, m2) == true
  end

  test "multiple a money by something that raises an exception" do
    assert_raise ArgumentError, ~r/Cannot multiply money by/, fn ->
      Money.mult!(Money.new(:USD, 100), :invalid)
    end
  end

  test "divide a money by an integer" do
    assert Money.div!(Money.new(:USD, 100), 2) == Money.new(:USD, 50)
  end

  test "divide a money by an decimal" do
    assert Money.div!(Money.new(:USD, 100), Decimal.new(2)) == Money.new(:USD, 50)
  end

  test "divide a money by a float" do
    m1 = Money.div!(Money.new(:USD, 100), 2.5)
    m2 = Money.new(:USD, 40)
    assert Money.equal?(m1, m2) == true
  end

  test "divide a money by something that raises an exception" do
    assert_raise ArgumentError, ~r/Cannot divide money by/, fn ->
      Money.div!(Money.new(:USD, 100), :invalid)
    end
  end

  test "Two %Money{} with different currencies are not equal" do
    m1 = Money.new(:USD, 250)
    m2 = Money.new(:JPY, 250)
    assert Money.equal?(m1, m2) == false
  end

  test "Split %Money{} into 4 equal parts" do
    m1 = Money.new(:USD, 100)
    {m2, m3} = Money.split(m1, 4)
    assert Money.cmp(m2, Money.new(:USD, 25)) == :eq
    assert Money.cmp(m3, Money.new(:USD, 0)) == :eq
  end

  test "Split %Money{} into 3 equal parts" do
    m1 = Money.new(:USD, 100)
    {m2, m3} = Money.split(m1, 3)
    assert Money.cmp(m2, Money.new(:USD, Decimal.new(33.33))) == :eq
    assert Money.cmp(m3, Money.new(:USD, Decimal.new(0.01))) == :eq
  end

  property "check that money split sums to the original value" do
    check all {money, splits} <- GenerateSplits.generate_money(), max_runs: 1_000 do
      {split_amount, remainder} = Money.split(money, splits)
      reassemble = Money.mult!(split_amount, splits) |> Money.add!(remainder)
      assert Money.cmp(reassemble, money) == :eq
    end
  end

  test "Test successful money cmp" do
    m1 = Money.new(:USD, 100)
    m2 = Money.new(:USD, 200)
    m3 = Money.new(:USD, 100)
    assert Money.cmp(m1, m2) == :lt
    assert Money.cmp(m2, m1) == :gt
    assert Money.cmp(m1, m3) == :eq
  end

  test "Test money cmp!" do
    m1 = Money.new(:USD, 100)
    m2 = Money.new(:USD, 200)
    m3 = Money.new(:USD, 100)
    assert Money.cmp!(m1, m2) == :lt
    assert Money.cmp!(m2, m1) == :gt
    assert Money.cmp!(m1, m3) == :eq
  end

  test "cmp! raises an exception" do
    assert_raise ArgumentError, ~r/Cannot compare monies with different currencies/, fn ->
      Money.cmp!(Money.new(:USD, 100), Money.new(:AUD, 25))
    end
  end

  test "Test successul money compare" do
    m1 = Money.new(:USD, 100)
    m2 = Money.new(:USD, 200)
    m3 = Money.new(:USD, 100)
    assert Money.compare(m1, m2) == -1
    assert Money.compare(m2, m1) == 1
    assert Money.compare(m1, m3) == 0
  end

  test "Test money compare!" do
    m1 = Money.new(:USD, 100)
    m2 = Money.new(:USD, 200)
    m3 = Money.new(:USD, 100)
    assert Money.compare!(m1, m2) == -1
    assert Money.compare!(m2, m1) == 1
    assert Money.compare!(m1, m3) == 0
  end

  test "compare! raises an exception" do
    assert_raise ArgumentError, ~r/Cannot compare monies with different currencies/, fn ->
      Money.compare!(Money.new(:USD, 100), Money.new(:AUD, 25))
    end
  end

  test "Money is rounded according to currency definition for USD" do
    assert Money.round(Money.new(:USD, "123.456")) == Money.new(:USD, "123.46")
  end

  test "Money is rounded according to currency definition for JPY" do
    assert Money.round(Money.new(:JPY, "123.456")) == Money.new(:JPY, 123)
  end

  test "Money is rounded according to currency definition for CHF" do
    assert Money.round(Money.new(:CHF, "123.456")) == Money.new(:CHF, "123.46")
  end

  test "Money is rounded according to currency cash definition for CHF" do
    assert Money.round(Money.new(:CHF, "123.456"), currency_digits: :cash) ==
             Money.new(:CHF, "123.45")

    assert Money.round(Money.new(:CHF, "123.41"), currency_digits: :cash) ==
             Money.new(:CHF, "123.40")

    assert Money.round(Money.new(:CHF, "123.436"), currency_digits: :cash) ==
             Money.new(:CHF, "123.45")
  end

  test "Extract decimal from money" do
    assert Money.to_decimal(Money.new(:USD, 1234)) == Decimal.new(1234)
  end

  test "Calculate irr with one outflow" do
    flows = [
      {1, Money.new(:USD, -123_400)},
      {2, Money.new(:USD, 36200)},
      {3, Money.new(:USD, 54800)},
      {4, Money.new(:USD, 48100)}
    ]

    assert Float.round(Financial.internal_rate_of_return(flows), 4) == 0.0596
  end

  test "Calculate irr with two outflows" do
    flows = [
      {0, Money.new(:USD, -1000)},
      {1, Money.new(:USD, -4000)},
      {2, Money.new(:USD, 5000)},
      {3, Money.new(:USD, 2000)}
    ]

    assert Float.round(Financial.internal_rate_of_return(flows), 4) == 0.2548
  end

  test "money conversion" do
    rates = %{USD: Decimal.new(1), AUD: Decimal.new(2)}
    assert Money.to_currency(Money.new(:USD, 100), :AUD, rates) == {:ok, Money.new(:AUD, 200)}
  end

  test "money conversion with binary to_currency that is the same as from currency" do
    rates = %{USD: Decimal.new(0.3), AUD: Decimal.new(2)}
    assert Money.to_currency(Money.new(:USD, 100), "USD", rates) == {:ok, Money.new(:USD, 100)}
  end

  test "money to_string" do
    assert Money.to_string(Money.new(:USD, 100)) == {:ok, "$100.00"}
  end

  test "create money with a sigil" do
    import Money.Sigil
    m = ~M[100]USD
    assert m == Money.new!(:USD, 100)
  end

  test "raise when a sigil function has an invalid currency" do
    assert_raise Money.UnknownCurrencyError, ~r/The currency .* is invalid/, fn ->
      Money.Sigil.sigil_M("42", [?A, ?B, ?C])
    end
  end

  test "raise when a sigil has an invalid currency" do
    import Money.Sigil

    assert_raise Money.UnknownCurrencyError, ~r/The currency .* is invalid/, fn ->
      ~M[42]ABD
    end
  end

  test "that we get a deprecation message if we use :exchange_rate_service keywork option" do
    Application.put_env(:ex_money, :exchange_rate_service, true)

    assert capture_log(fn ->
             Money.Application.maybe_log_deprecation()
           end) =~ "Configuration option :exchange_rate_service is deprecated"
  end

  test "that we get a deprecation message if we use :delay_before_first_retrieval keywork option" do
    Application.put_env(:ex_money, :delay_before_first_retrieval, 300)

    assert capture_log(fn ->
             Money.Application.maybe_log_deprecation()
           end) =~ "Configuration option :delay_before_first_retrieval is deprecated"
  end

  test "the integer and exponent for a number with more than the required decimal places" do
    m = Money.new(:USD, "200.012356")
    assert Money.to_integer_exp(m) == {:USD, 20001, -2, Money.new(:USD, "0.002356")}
  end

  test "the integer and exponent for a number with no decimal places" do
    m = Money.new(:USD, "200.00")
    assert Money.to_integer_exp(m) == {:USD, 20000, -2, Money.new(:USD, "0.00")}
  end

  test "the integer and exponent for a number with one less than the required decimal places" do
    m = Money.new(:USD, "200.1")
    assert Money.to_integer_exp(m) == {:USD, 20010, -2, Money.new(:USD, "0.0")}
  end

  test "the integer and exponent for a currency with no decimal places" do
    m = Money.new(:JPY, "200.1")
    assert Money.to_integer_exp(m) == {:JPY, 200, 0, Money.new(:JPY, "0.1")}
  end

  test "the integer and exponent for a currency with three decimal places" do
    m = Money.new(:JOD, "200.1")
    assert Money.to_integer_exp(m) == {:JOD, 200_100, -3, Money.new(:JOD, "0.0")}

    m = Money.new(:JOD, "200.1234")
    assert Money.to_integer_exp(m) == {:JOD, 200_123, -3, Money.new(:JOD, "0.0004")}

    m = Money.new(:JOD, 200)
    assert Money.to_integer_exp(m) == {:JOD, 200_000, -3, Money.new(:JOD, 0)}
  end

  test "that the Phoenix.HTML.Safe protocol returns the correct result" do
    assert Phoenix.HTML.Safe.to_iodata(Money.new(:USD, 100)) == "$100.00"
  end

  test "that we use iso digits as default for to_integer_exp" do
    assert Money.to_integer_exp(Money.new(:COP, 1234)) == {:COP, 123_400, -2, Money.new(:COP, 0)}
  end

  test "that we can use accounting digits for to_integer_exp" do
    assert Money.to_integer_exp(Money.new(:COP, 1234), currency_digits: :accounting) ==
             {:COP, 123400, -2, Money.new(:COP, 0)}
  end

  test "json encoding for Jason" do
    assert Jason.encode(
             Money.new("0.0020", :USD) == {:ok, "{\"currency\":\"USD\",\"amount\":\"0.0020\"}"}
           )
  end

  test "json encoding for Poison" do
    assert Poison.encode(
             Money.new("0.0020", :USD) == {:ok, "{\"currency\":\"USD\",\"amount\":\"0.0020\"}"}
           )
  end
end
