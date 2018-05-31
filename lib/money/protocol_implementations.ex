defimpl String.Chars, for: Money do
  def to_string(v) do
    Money.to_string!(v)
  end
end

defimpl Inspect, for: Money do
  def inspect(money, _opts) do
    "#Money<#{inspect(money.currency)}, #{Decimal.to_string(money.amount)}>"
  end
end

if Code.ensure_compiled?(Jason) do
  defimpl Jason.Encoder, for: Money do
    def encode(struct, opts) do
      struct
      |> Map.take([:currency, :amount])
      |> Jason.Encode.map(opts)
    end
  end
end

if Code.ensure_compiled?(Phoenix.HTML.Safe) do
  defimpl Phoenix.HTML.Safe, for: Money do
    def to_iodata(money) do
      Phoenix.HTML.Safe.to_iodata(Money.to_string!(money))
    end
  end
end

if Code.ensure_compiled?(Gringotts.Money) do
  defimpl Gringotts.Money, for: Money do
    def currency(%Money{currency: currency}) do
      Atom.to_string(currency)
    end

    def value(%Money{amount: amount}) do
      amount
    end

    def to_integer(%Money{} = money) do
      {_currency, integer, exponent, _remainder} = Money.to_integer_exp(money)
      {currency(money), integer, exponent}
    end

    def to_string(%Money{} = money) do
      rounded_string =
        money
        |> Money.round
        |> Map.get(:amount)
        |> Cldr.Number.to_string!

      {currency(money), rounded_string}
    end
  end
end