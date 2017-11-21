defmodule MoneyTest do
  use ExUnit.Case
  import ExUnit.CaptureIO
  import Money.ExchangeRatesTestHelper

  alias Money.ExchangeRates
  alias Money.Financial

  doctest Money
  doctest Money.ExchangeRates

  test "create a new money struct with a binary currency code" do
    money = Money.new(1234, "USD")
    assert money.currency == :USD
    assert money.amount == Decimal.new(1234)
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

  test "that two binary arguments returns and error" do
    assert Money.new("USD", "1234") ==
      {:error, {Money.Invalid, "Unable to create money from \"USD\" and \"1234\""}}
  end

  test "that creating a money with a string amount that is invalid returns and error" do
    assert Money.new(:USD, "2134ff") ==
      {:error, {Money.InvalidAmountError,
                "Amount cannot be converted to a number: \"2134ff\""}}
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
      Money.new!(Decimal.new(100),  "ABCDE")
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
    assert Money.new(:XYZ, 100) == {:error, {Money.UnknownCurrencyError, "The currency :XYZ is invalid"}}
  end

  test "creating a money struct with an invalid binary currency code returns error tuple" do
    assert Money.new("ABCD", 100) == {:error, {Money.UnknownCurrencyError, "The currency \"ABCD\" is invalid"}}
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
    assert Money.cmp(m2, Money.new(:USD, 33.33)) == :eq
    assert Money.cmp(m3, Money.new(:USD, 0.01)) == :eq
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
    assert Money.round(Money.new(:USD, 123.456)) == Money.new(:USD, 123.46)
  end

  test "Money is rounded according to currency definition for JPY" do
    assert Money.round(Money.new(:JPY, 123.456)) == Money.new(:JPY, 123)
  end

  test "Money is rounded according to currency definition for CHF" do
    assert Money.round(Money.new(:CHF, 123.456)) == Money.new(:CHF, 123.46)
  end

  test "Money is rounded according to currency cash definition for CHF" do
    assert Money.round(Money.new(:CHF, 123.456), cash: true) == Money.new(:CHF, 125)
  end

  test "Extract decimal from money" do
    assert Money.to_decimal(Money.new(:USD, 1234)) == Decimal.new(1234)
  end

  test "Calculate irr with one outflow" do
    flows = [{1, Money.new(:USD, -123400)},{2, Money.new(:USD, 36200)},{3,Money.new(:USD,54800)},{4,Money.new(:USD,48100)}]
    assert Float.round(Financial.internal_rate_of_return(flows), 4) == 0.0596
  end

  test "Calculate irr with two outflows" do
    flows = [{0, Money.new(:USD, -1000)},{1, Money.new(:USD, -4000)},{2,Money.new(:USD,5000)},{3,Money.new(:USD,2000)}]
    assert Float.round(Financial.internal_rate_of_return(flows), 4) == 0.2548
  end

  @sleep_timer 50

  test "Get exchange rates" do
    capture_io fn ->
      {:ok, _pid} = start_service()
      :timer.sleep(@sleep_timer)
    end

    test_result = {:ok, %{USD: Decimal.new(1), AUD: Decimal.new(0.7), EUR: Decimal.new(1.2)}}
    assert Money.ExchangeRates.latest_rates() == test_result
  end

  test "Convert from USD to AUD" do
    capture_io fn ->
      {:ok, _pid} = start_service()
      :timer.sleep(@sleep_timer)
    end

    assert Money.cmp(Money.to_currency!(Money.new(:USD, 100), :AUD), Money.new(:AUD, 70)) == :eq
  end

  test "Convert from USD to USD" do
    capture_io fn ->
      {:ok, _pid} = start_service()
      :timer.sleep(@sleep_timer)
    end

    assert Money.cmp(Money.to_currency!(Money.new(:USD, 100), :USD), Money.new(:USD, 100)) == :eq
  end

  test "Convert from USD to ZZZ should return an error" do
    capture_io fn ->
      {:ok, _pid} = start_service()
      :timer.sleep(@sleep_timer)
    end

    assert Money.to_currency(Money.new(:USD, 100), :ZZZ) ==
      {:error, {Cldr.UnknownCurrencyError, "The currency :ZZZ is invalid"}}
  end

  test "Convert from USD to ZZZ should raise an exception" do
    capture_io fn ->
      {:ok, _pid} = start_service()
      :timer.sleep(@sleep_timer)
    end

    assert_raise Cldr.UnknownCurrencyError, ~r/The currency :ZZZ is invalid/, fn ->
      assert Money.to_currency!(Money.new(:USD, 100), :ZZZ)
    end
  end

  test "Convert from USD to AUD using historic rates" do
    capture_io fn ->
      {:ok, _pid} = start_service()
      :timer.sleep(@sleep_timer)
    end

    assert Money.to_currency!(Money.new(:USD, 100), :AUD,
      ExchangeRates.historic_rates(~D[2017-01-01])) |> Money.round ==
      Money.new(:AUD, Decimal.new(71.43))
  end

  test "Convert from USD to AUD using historic rates that aren't available" do
    capture_io fn ->
      {:ok, _pid} = start_service()
      :timer.sleep(@sleep_timer)
    end

    assert Money.to_currency(Money.new(:USD, 100), :AUD,
      ExchangeRates.historic_rates(~D[2017-02-01])) ==
       {:error, {Money.ExchangeRateError, "No exchange rates for 2017-02-01 were found"}}
  end

  test "Invoke callback module on successful exchange rate retrieval" do
    assert capture_io(fn ->
      {:ok, _pid} = start_service()
      :timer.sleep(@sleep_timer)
     end) == "Historic Rates Retrieved\nHistoric Rates Retrieved\nLatest Rates Retrieved\n"
  end

  test "That rates_available? returns correctly" do
    assert capture_io(fn ->
      {:ok, _pid} = Money.ExchangeRates.Retriever.start_link(Money.ExchangeRates.Retriever, ExchangeRates.default_config)
      assert ExchangeRates.latest_rates_available? == false
      :timer.sleep(@sleep_timer)
      assert ExchangeRates.latest_rates_available? == true
     end)
  end

  test "That an error is returned if there is no open exchange rates app_id configured" do
    Application.put_env(:ex_money, :open_exchange_rates_app_id, nil)
    config = Money.ExchangeRates.OpenExchangeRates.init(Money.ExchangeRates.default_config)
    config = Map.put(config, :log_levels, %{failure: :nil, info: nil, success: nil})
    assert Money.ExchangeRates.OpenExchangeRates.get_latest_rates(config) ==
      {:error, "Open Exchange Rates app_id is not configured.  Rates are not retrieved."}
  end

  if System.get_env("OPEN_EXCHANGE_RATES_APP_ID") do
    test "That the Open Exchange Rates retriever returns a map" do
      Application.put_env(:ex_money, :open_exchange_rates_app_id, System.get_env("OPEN_EXCHANGE_RATES_APP_ID"))
      config = Money.ExchangeRates.OpenExchangeRates.init(Money.ExchangeRates.default_config)
      config = Map.put(config, :log_levels, %{failure: :nil, info: nil, success: nil})
      {:ok, rates} = Money.ExchangeRates.OpenExchangeRates.get_latest_rates(config)
      assert is_map(rates)
    end
  end

  test "money conversion" do
    rates = %{USD: Decimal.new(1), AUD: Decimal.new(2)}
    assert Money.to_currency(Money.new(:USD, 100), :AUD, rates) == {:ok, Money.new(:AUD, 200)}
  end

  test "money to_string" do
    assert Money.to_string(Money.new(:USD, 100)) == {:ok, "$100.00"}
  end

  test "create money with a sigil" do
    import Money.Sigil
    m = ~M[100]USD
    assert m == Money.new!(:USD, 100)
  end
end