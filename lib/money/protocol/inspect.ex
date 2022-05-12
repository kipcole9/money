defimpl Inspect, for: Money do
  import Money, only: [is_digital_token: 1]

  def inspect(%Money{currency: token_id} = money, opts) when is_digital_token(token_id) do
    token = DigitalToken.get_token!(token_id)

    case Map.get(token.informative, :short_names) do
      [first | _rest] ->
        money
        |> Map.put(:currency, first)
        |> do_inspect(opts)

     _other ->
       do_inspect(money, opts)
    end
  end

  def inspect(money, opts) do
    do_inspect(money, opts)
  end

  def do_inspect(%Money{format_options: []} = money, _opts) do
    "Money.new(#{inspect(money.currency)}, #{inspect Decimal.to_string(money.amount)})"
  end

  def do_inspect(money, _opts) do
    format_options =
      money.format_options
      |> inspect()
      |> String.trim_leading("[")
      |> String.trim_trailing("]")

    "Money.new(#{inspect money.currency}, #{inspect Decimal.to_string(money.amount)}, #{format_options})"
  end
end