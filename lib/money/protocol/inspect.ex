defimpl Inspect, for: Money do
  import Money, only: [is_digital_token: 1]

  # `:digital_token` is an optional dependency. See `Money` for context.
  @compile {:no_warn_undefined, DigitalToken}

  def inspect(%Money{currency: token_id} = money, opts) when is_digital_token(token_id) do
    short_name =
      if Code.ensure_loaded?(DigitalToken) do
        case apply(DigitalToken, :short_name, [token_id]) do
          {:ok, name} -> name
          _ -> token_id
        end
      else
        token_id
      end

    money
    |> Map.put(:currency, short_name)
    |> do_inspect(opts)
  end

  def inspect(money, opts) do
    do_inspect(money, opts)
  end

  def do_inspect(%Money{format_options: []} = money, _opts) do
    "Money.new(#{inspect(money.currency)}, #{inspect(Decimal.to_string(money.amount))})"
  end

  def do_inspect(money, _opts) do
    format_options =
      money.format_options
      |> inspect()
      |> String.trim_leading("[")
      |> String.trim_trailing("]")

    "Money.new(#{inspect(money.currency)}, #{inspect(Decimal.to_string(money.amount))}, #{format_options})"
  end
end
