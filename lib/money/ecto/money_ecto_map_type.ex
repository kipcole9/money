if Code.ensure_loaded?(Ecto.Type) do
  defmodule Money.Ecto.Map.Type do
    @moduledoc """
    Implements Ecto.Type behaviour for Money, where the underlying schema type
    is a map.

    This is the required option for databases such as MySQL that do not support
    composite types.

    In order to preserve precision, the amount is serialized as a string since the
    JSON representation of a numeric value is either an integer or a float.

    `Decimal.to_string/1` is not guaranteed to produce a string that will round-trip
    convert back to the identical number.  However given enough precision in the
    `Decimal.get_context/0` then round trip conversion should be expected.  The default
    precision in the context is 28 digits.
    """

    @behaviour Ecto.Type

    defdelegate cast(money), to: Money.Ecto.Composite.Type

    def type() do
      :map
    end

    def load(%{"currency" => currency, "amount" => amount}) when is_binary(amount) do
      with \
        {:ok, amount} <- Decimal.parse(amount),
        {:ok, currency} <- Money.validate_currency(currency)
      do
        {:ok, Money.new(currency, amount)}
      end
    end

    def load(%{"currency" => currency, "amount" => amount}) when is_number(amount) do
      with {:ok, currency} <- Money.validate_currency(currency) do
        {:ok, Money.new(currency, amount)}
      end
    end

    def dump(%Money{currency: currency, amount: %Decimal{} = amount}) do
      {:ok, %{"currency" =>  to_string(currency), "amount" => Decimal.to_string(amount)}}
    end

    def dump({currency, amount})
    when (is_binary(currency) or is_atom(currency)) and is_number(amount) do
      with {:ok, currency_code} <- Money.validate_currency(currency) do
        {:ok, %{"currency" =>  to_string(currency_code), "amount" => amount}}
      end
    end

    def dump({currency, %Decimal{} = amount})
    when (is_binary(currency) or is_atom(currency)) do
      with {:ok, currency_code} <- Money.validate_currency(currency) do
        {:ok, %{"currency" =>  to_string(currency_code), "amount" => Decimal.to_string(amount)}}
      end
    end

    def dump(_) do
      :error
    end
  end
end