defmodule Money.Ecto.Type do
  @moduledoc """
  Implements Ecto.Type behaviour for Money, where the underlying schema type
  is a map.
  """

  if Code.ensure_loaded?(Ecto.Type) do
    @behaviour Ecto.Type

    def type(), do: :map

    def cast(%{"currency" => currency, "amount" => term})
    when is_binary(currency) and is_binary(term) do
      with {:ok, amount} <- Decimal.parse(term) do
        {:ok, Money.new(currency, amount)}
      end
    end

    def cast(%{"currency" => currency, "amount" => term})
    when is_binary(currency) and is_number(term) do
      with {:ok, amount} <- Decimal.new(term) do
        {:ok, Money.new(currency, amount)}
      end
    end

    def cast(%Money{} = money), do: {:ok, money}
    def cast(_), do: :error

    def load(%{"currency" => currency, "amount" => term}) do
      with {:ok, amount} <- Decimal.parse(term) do
        {:ok, Money.new(currency, amount)}
      end
    end

    def dump(%Money{currency: currency,
                    amount: %Decimal{} = amount}) do
      {:ok, %{currency: currency,
              amount: Decimal.to_string(amount)}}
    end
    def dump(_), do: :error
  end
end
