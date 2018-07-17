defmodule Money.DDL do
  @moduledoc """
  Functions to return SQL DDL commands that support the
  creation and deletion of the `money_with_currency` database
  type and associated aggregate functions.
  """
  @default_db :postgres

  @supported_db_types :code.priv_dir(:ex_money)
    |> Path.join("SQL")
    |> File.ls!
    |> Enum.map(&String.to_atom/1)

  @doc """
  Returns the SQL string which when executed will
  define the `money_with_currency` data type.

  ## Arguments

  * `db_type`: the type of the database for which the SQL
    string should be returned.  Defaults to `:postgres` which
    is currently the only supported database type.

  """
  def create_money_with_currency(db_type \\ @default_db)

  def create_money_with_currency(db_type) do
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

  @doc """
  Returns the SQL string which when executed will
  drop the aggregate functions for the `money_with_currency`
  data type.

  ## Arguments

  * `db_type`: the type of the database for which the SQL
    string should be returned.  Defaults to `:postgres` which
    is currently the only supported database type.

  """
  def drop_aggregate_functions(db_type \\ @default_db) do
    read_sql_file(db_type, "drop_aggregate_functions.sql")
  end

  defp read_sql_file(db_type, file_name) when db_type in @supported_db_types do
    base_dir(db_type)
    |> Path.join(file_name)
    |> File.read!
  end

  defp read_sql_file(db_type, file_name) do
    raise ArgumentError, "Database type #{db_type} does not have a SQL definition " <>
                         "file #{inspect file_name}"
  end

  defp base_dir(db_type) do
    :code.priv_dir(:ex_money)
    |> Path.join(["SQL", "/#{db_type}"])
  end
end