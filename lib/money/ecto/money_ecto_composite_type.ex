defmodule Money.Ecto.Composite.Type do
  @moduledoc """
  Implements the Ecto.Type behaviour for a user-defined Postgres composite type
  called `:money_with_currency`.

  This is the preferred option for Postgres database since the serialized money
  amount is stored as a number,
  """

  if Code.ensure_loaded?(Ecto.Type) do
    @behaviour Ecto.Type

    def type do
      :money_with_currency
    end

    def blank?(_) do
      false
    end

    def load(money) do
      {:ok, Money.new(money)}
    end

    def dump(%Money{} = money) do
      {:ok, {to_string(money.currency), money.amount}}
    end

    def dump(money) when is_tuple(money) do
      {:ok, money}
    end

    def dump(_) do
      :error
    end

    def cast(%Money{} = money) do
      {:ok, money}
    end

    def cast(money) when is_tuple(money) do
      {:ok,  Money.new(money)}
    end

    def cast(%{"currency" => currency, "amount" => amount}) when is_binary(currency) and is_number(amount) do
      with {:ok, amount} <- Decimal.new(amount) do
        {:ok, Money.new(currency, amount)}
      end
    end

    def cast(_money) do
      :error
    end
  end
end