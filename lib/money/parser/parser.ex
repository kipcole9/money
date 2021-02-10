defmodule Money.Parser do
  @moduledoc false

  # parsec:Money.Parser
  import NimbleParsec
  import Money.Combinators

  defparsec(:money_parser, choice([money_with_currency(), accounting_format()]))
  # parsec:Money.Parser

  def change_sign({:amount, amount}) do
    revised_number =
      case amount do
        <<"-", number::binary>> -> number
        number -> "-" <> number
      end

    {:amount, revised_number}
  end

  def change_sign(other), do: other

  def add_minus_sign(arg) do
    "-" <> arg
  end
end
