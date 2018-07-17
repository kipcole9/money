defmodule Money.DDL do
  @default_db :postgres

  @doc """
  Returns the SQL string which when executed will
  define the `money_with_currency` data type.

  ## Arguments

  * `db_type`: the type of the database for which the SQL
    string should be returned.  Defaults to `:postgres` which
    is currently the only supported database type.

  """
  def create_money_with_currency(db_type \\ @default_db) do
    read_sql_file(db_type, "create_money_with_currency.sql")
  end

  @doc """
  Returns the SQL string which when executed will
  drop the `money_with_currency` data type.

  ## Arguments

  * `db_type`: the type of the database for which the SQL
    string should be returned.  Defaults to `:postgres` which
    is currently the only supported database type.

  """
  def drop_money_with_currency(db_type \\ @default_db) do
    read_sql_file(db_type, "drop_money_with_currency.sql")
  end

  @doc """
  Returns the SQL string which when executed will
  define aggregate functions for the `money_with_currency`
  data type.

  ## Arguments

  * `db_type`: the type of the database for which the SQL
    string should be returned.  Defaults to `:postgres` which
    is currently the only supported database type.

  """
  def define_aggregate_functions(db_type \\ @default_db) do
    read_sql_file(db_type, "define_aggregate_functions.sql")
  end

  def drop_aggregate_functions(db_type \\ @default_db) do
    read_sql_file(db_type, "drop_aggregate_functions.sql")
  end

  defp read_sql_file(db_type, file_name) do
    base_dir(db_type)
    |> Path.join(file_name)
    |> File.read!
  end

  defp base_dir(db_type) do
    :code.priv_dir(:ex_money)
    |> Path.join(["SQL", "/#{db_type}"])
  end
end