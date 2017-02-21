defmodule Money.Ecto.Map.Type do
  @moduledoc """
    Implements Ecto.Type behaviour for Money, where the underlying schema type
    is a map.

    This is the required option for databases such as MySql that do not support
    composite fields.

    In order to preserve precision, the amount is serialized as a string since the
    json representation of a numeric value is either an integer or a float.

    `Decimal.to_string/1` is not guaranteed to produce a string that will round-trip
    convert back to the identical number.  However given enough precision in the
    `Decimal.get_context/0` then round trip conversion should be expected.  The default
    precision in the context is 28 digits.
  """

  if Code.ensure_loaded?(Ecto.Type) do
    @behaviour Ecto.Type

    def type() do
      :map
    end

    def cast(%{"currency" => currency, "amount" => amount}) when is_binary(currency) and is_number(amount) do
      with {:ok, amount} <- Decimal.new(amount) do
        {:ok, Money.new(currency, amount)}
      end
    end

    def cast(%{"currency" => currency, "amount" => %Decimal{} = amount}) when is_binary(currency) do
      {:ok, Money.new(currency, amount)}
    end

    def cast(%Money{} = money) do
      {:ok, money}
    end

    def cast(_) do
      :error
    end

    def load(%{"currency" => currency, "amount" => amount}) do
      with {:ok, amount} <- Decimal.parse(amount) do
        {:ok, Money.new(currency, amount)}
      end
    end

    def dump(%Money{currency: currency, amount: %Decimal{} = amount}) do
      {:ok, %{currency: to_string(currency), amount: Decimal.to_string(amount)}}
    end

    def dump(_) do
      :error
    end
  end
end