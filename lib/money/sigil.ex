defmodule Money.Sigil do
  @doc ~S"""
  Implements the sigil `~M` for Money

  The lower case `~m` variant does not exist as interpolation and excape
  characters are not useful for Money sigils.

  ## Example

      iex> import Money.Sigil
      iex> ~M[1000]usd
      #Money<:USD, 1000>
      iex> ~M[1000.34]usd
      #Money<:USD, 1000.34>

  """
  @spec sigil_M(binary, list) :: Money.t() | {:error, Exception.t String.t}
  def sigil_M(amount, [_, _, _] = currency) do
    Money.new(to_decimal(amount), atomize(currency))
  end

  defp to_decimal(string) do
    string
    |> String.replace("_", "")
    |> Decimal.new()
  end

  defp atomize(currency) do
    currency
    |> List.to_string()
    |> validate_currency!
  end

  def validate_currency!(currency) do
    case Money.validate_currency(currency) do
      {:ok, currency} -> currency
      {:error, {_exception, reason}} -> raise Money.UnknownCurrencyError, reason
    end
  end
end
