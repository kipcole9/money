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

if Code.ensure_compiled?(Phoenix.HTML.Safe) do
  defimpl Phoenix.HTML.Safe, for: Money do
    def to_iodata(money) do
      Phoenix.HTML.Safe.to_iodata(Money.to_string!(money))
    end
  end
end
