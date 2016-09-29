defmodule Money.Repo.Migrations.AddMoneyWithCurrencyTypeToPostgres do
  use Ecto.Migration

  def up do
    execute """
      CREATE TYPE public.money_with_currency AS (
        currency_code  char(3),
        value          numeric(20,8)
      )
    """
  end

  def down do
    execute "DROP TYPE public.money_with_currency"
  end
end
