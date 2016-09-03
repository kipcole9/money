defmodule Money.Ecto.Type do
  @moduledoc """
  Implements the Ecto.Type behaviour for a user-defined Postgres type
  called `:money_with_currency`.
  """

  if Code.ensure_loaded?(Ecto.Type) do
    @behaviour Ecto.Type
    def type, do: :money_with_currency
    def blank?(_), do: false

    def load(money),
      do: {:ok, Money.new(money)}

    def dump(%Money{} = money),
      do: {:ok, {money.code, money.value}}
    def dump(money) when is_tuple(money),
      do: {:ok, money}
    def dump(_),
      do: :error

    def cast(%Money{} = money),
      do: {:ok, money}
    def cast(money) when is_tuple(money),
      do: {:ok,  Money.new(money)}
    def cast(_money),
      do: :error
  end
end