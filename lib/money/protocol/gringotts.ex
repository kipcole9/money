if Cldr.Config.ensure_compiled?(Gringotts.Money) &&
     !Money.exclude_protocol_implementation(Gringotts.Money) do
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
        |> Money.round()
        |> Map.get(:amount)
        |> Module.concat(Money.default_backend(), Number).to_string!

      {currency(money), rounded_string}
    end
  end
end
