defmodule Money.Sigil do
  @doc ~S"""
  Implements the sigil `~M` for Money

  The lower case `~m` variant does not exist as interpolation and excape
  characters are not useful for Money sigils.

  ## Example

      import Money.Sigil

      iex> ~M[1000]usd
      #Money<:USD, 1000>
  """

  def sigil_M(amount, [_, _, _] = currency) do
    Money.new(to_decimal(amount), atomize(currency))
  end

  defp to_decimal(string) do
    string
    |> String.replace("_", "")
    |> Decimal.new
  end

  defp atomize(currency) do
    currency
    |> List.to_string
    |> String.upcase
    |> String.to_existing_atom
  end
end