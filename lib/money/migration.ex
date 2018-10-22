defmodule Money.Migration do
  @moduledoc false

  [%{status: {:ok, ecto_version}}] =
    if Version.compare(System.version(), "1.6.0") in [:gt, :eq] do
      Mix.Dep.filter_by_name([:ecto], Mix.Dep.cached)
    else
      Mix.Dep.loaded_by_name([:ecto], Mix.Dep.cached)
    end

  {ecto_major_version, _} = Integer.parse(ecto_version)
  @ecto_version ecto_version
  @ecto_major_version ecto_major_version

  def ecto_version do
    @ecto_version
  end

  def ecto_major_version do
    @ecto_major_version
  end

  if @ecto_major_version >= 3  do
    def migrations_path(repo) do
      Ecto.Migrator.migrations_path(repo)
    end
  else
    def migrations_path(repo) do
      Mix.Ecto.migrations_path(repo)
    end
  end
end