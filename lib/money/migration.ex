defmodule Money.Migration do
  @moduledoc false

  if Code.ensure_loaded?(Ecto.Migrator) && function_exported?(Ecto.Migrator, :migrations_path, 1) do
    def migrations_path(repo) do
      Ecto.Migrator.migrations_path(repo)
    end
  end

  if Code.ensure_loaded?(Mix.Ecto) && function_exported?(Mix.Ecto, :migrations_path, 1) do
    def migrations_path(repo) do
      Mix.Ecto.migrations_path(repo)
    end
  end

  if Code.ensure_loaded?(Code) && function_exported?(Code, :format_string!, 1) do
    @spec format_string!(String.t()) :: iodata()
    @dialyzer {:no_return, format_string!: 1}
    def format_string!(string) do
      Code.format_string!(string)
    end
  else
    @spec format_string!(String.t()) :: iodata()
    def format_string!(string) do
      string
    end
  end
end
