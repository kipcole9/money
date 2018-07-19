defmodule Money.DDL do
  @moduledoc """
  Functions to return SQL DDL commands that support the
  creation and deletion of the `money_with_currency` database
  type and associated aggregate functions.
  """

  # @doc since: "2.7.0"

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

  @doc """
  Returns a string that will Ecto `execute` each SQL
  command.

  ## Arguments

  * `sql` is a string of SQL commands that are
    separated by three newlines ("\\n"),
    that is to say two blank lines between commands
    in the file.

  ## Example

      iex> Money.DDL.execute "SELECT name FROM customers;\n\n\nSELECT id FROM orders;"
      "execute \"\"\"\nSELECT name FROM customers;\n\n\nSELECT id FROM orders;\n\"\"\""

  """
  def execute_each(sql) do
    sql
    |> String.split("\n\n\n")
    |> Enum.map(&execute/1)
    |> Enum.join("\n")
  end

  @doc """
  Returns a string that will Ecto `execute` a single SQL
  command.

  ## Arguments

  * `sql` is a single SQL command

  ## Example

      iex> Money.DDL.execute "SELECT name FROM customers;"
      "execute \"SELECT name FROM customers;\""

  """
  def execute(sql) do
    sql = String.trim_trailing(sql, "\n")
    if String.contains?(sql, "\n") do
      "execute \"\"\"\n" <> sql <> "\n\"\"\""
    else
      "execute " <> inspect(sql)
    end
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