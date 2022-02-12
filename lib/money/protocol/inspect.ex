defimpl Inspect, for: Money do
  def inspect(%Money{format_options: []} = money, _opts) do
    "Money.new(#{inspect(money.currency)}, #{inspect Decimal.to_string(money.amount)})"
  end

  def inspect(money, _opts) do
    format_options =
      money.format_options
      |> inspect()
      |> String.trim_leading("[")
      |> String.trim_trailing("]")

    "Money.new(#{inspect money.currency}, #{inspect Decimal.to_string(money.amount)}, #{format_options})"
  end
end