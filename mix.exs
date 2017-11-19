defmodule Money.Mixfile do
  use Mix.Project

  @version "1.0.0-rc.0"

  def project do
    [app: :ex_money,
     version: @version,
     elixir: "~> 1.5",
     name: "Money",
     source_url: "https://github.com/kipcole9/money",
     docs: docs(),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     description: description(),
     package: package(),
     test_coverage: [tool: ExCoveralls],
     aliases: aliases(),
     elixirc_paths: elixirc_paths(Mix.env)
   ]
  end

  defp description do
    "Money functions for the serialization of and operations on a money data type."
  end

  defp package do
    [
      maintainers: ["Kip Cole"],
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => "https://github.com/kipcole9/money",
        "Readme"    => "https://github.com/kipcole9/money/blob/v#{@version}/README.md",
        "Changelog" => "https://github.com/kipcole9/money/blob/v#{@version}/CHANGELOG.md"},
      files: [
        "lib", "config", "mix.exs", "README.md", "CHANGELOG.md", "LICENSE.md"
      ]
    ]
  end

  def application do
    [
      mod: {Money.Application, []},
      extra_applications: [:inets, :logger]
    ]
  end

  def docs do
    [
      source_ref: "v#{@version}",
      extras: ["README.md", "CHANGELOG.md", "LICENSE.md"],
      main: "readme",
      groups_for_modules: groups_for_modules()
    ]
  end

  defp groups_for_modules do
    [
      "Exchange Rates": ~r/^Money.ExchangeRates.?/,
      "Ecto": ~r/^Money.Ecto.?/
    ]
  end

  def aliases do
    []
  end

  defp deps do
    [
      {:ex_cldr, "~> 1.0.0-rc or ~> 1.0"},
      {:ex_cldr_numbers, "~> 1.0.0-rc or ~> 1.0"},
      {:decimal, "~> 1.4"},
      {:ecto, "~> 2.1", optional: true},
      {:ex_doc, "~> 0.18", only: :dev}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]
end
