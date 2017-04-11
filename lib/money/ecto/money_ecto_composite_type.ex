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

    # When loading from the database
    def load({currency, amount}) do
      with {:ok, currency_code} <- Money.validate_currency_code(currency) do
        {:ok, Money.new(currency_code, amount)}
      else
        {:error, _} = error -> error
      end
    end

    # Dumping to the database.  We make the assumption that
    # since we are dumping from %Money{} structs that the
    # data is ok
    def dump(%Money{} = money) do
      {:ok, {to_string(money.currency), money.amount}}
    end

    def dump({currency, amount})
    when (is_binary(currency) or is_atom(currency)) and is_number(amount) do
      with {:ok, currency_code} <- Money.validate_currency_code(currency) do
        {:ok, {to_string(currency_code), amount}}
      else
        {:error, _} = error -> error
      end
    end

    def dump(_) do
      :error
    end

    # Casting in changesets
    def cast(%Money{} = money) do
      {:ok, money}
    end

    def cast({currency, amount} = money)
    when (is_binary(currency) or is_atom(currency)) and is_number(amount) do
      {:ok, Money.new(money)}
    end

    def cast(%{"currency" => currency, "amount" => amount})
    when (is_binary(currency) or is_atom(currency)) and is_number(amount) do
      with decimal_amount <- Decimal.new(amount),
           {:ok, currency_code} <- Money.validate_currency_code(currency) do
        {:ok, Money.new(currency_code, decimal_amount)}
      else
        {:error, _} = error -> error
      end
    end

    def cast(%{"currency" => currency, "amount" => amount})
    when (is_binary(currency) or is_atom(currency)) and is_binary(amount) do
      with {:ok, amount} <- Decimal.parse(amount),
           {:ok, currency_code} <- Money.validate_currency_code(currency) do
        {:ok, Money.new(currency_code, amount)}
      else
        {:error, _} = error -> error
      end
    end

    def cast(_money) do
      :error
    end
  end
end