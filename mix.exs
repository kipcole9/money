defmodule Money.Mixfile do
  use Mix.Project

  @version "0.0.6-dev"

  def project do
    [app: :ex_money,
     version: @version,
     elixir: "~> 1.3",
     name: "Money",
     source_url: "https://github.com/kipcole9/money",
     docs: docs(),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     description: description(),
     package: package(),
     test_coverage: [tool: ExCoveralls],
     aliases: aliases()
   ]
  end

  defp description do
    "Money functions for the serialization of and operations on a money data type."
  end

  defp package do
    [
      maintainers: ["Kip Cole"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/kipcole9/money"},
      files: [
        "lib", "config", "mix.exs", "README*", "CHANGELOG*"
      ]
    ]
  end

  def application do
    []
  end

  def docs do
    [
      source_ref: "v#{@version}"
    ]
  end

  def aliases do
    []
  end

  defp deps do
    [
      {:ex_cldr, "~> 0.0.5"},
      {:excoveralls, "~> 0.5.6", only: :test},
      {:gen_stage, "~> 0.4", only: [:dev, :test]},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end
end
