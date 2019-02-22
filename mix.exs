defmodule Money.Mixfile do
  use Mix.Project

  @version "3.2.5-dev"

  def project do
    [
      app: :ex_money,
      version: @version,
      elixir: "~> 1.5",
      name: "Money",
      source_url: "https://github.com/kipcole9/money",
      docs: docs(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      test_coverage: [tool: ExCoveralls],
      aliases: aliases(),
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [ignore_warnings: ".dialyzer_ignore_warnings"],
      compilers: Mix.compilers()
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
        "Readme" => "https://github.com/kipcole9/money/blob/v#{@version}/README.md",
        "Changelog" => "https://github.com/kipcole9/money/blob/v#{@version}/CHANGELOG.md",
        "Roadmap" => "https://github.com/kipcole9/money/blob/v#{@version}/ROADMAP.md"
      },
      files: [
        "lib",
        "priv/SQL",
        "config",
        "mix.exs",
        "README.md",
        "CHANGELOG.md",
        "LICENSE.md",
        "ROADMAP.md"
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
      groups_for_modules: groups_for_modules(),
      logo: "logo.png",
      skip_undefined_reference_warnings_on: ["changelog"]
    ]
  end

  defp groups_for_modules do
    [
      "Exchange Rates": ~r/^Money.ExchangeRates.?/,
      Subscriptions: ~r/^Money.Subscription.?/,
      Ecto: ~r/^Money.Ecto.?/
    ]
  end

  def aliases do
    []
  end

  defp deps do
    [
      {:ex_cldr, "~> 2.0"},
      {:ex_cldr_numbers, "~> 2.0"},
      {:decimal, "~> 1.5"},
      {:phoenix_html, "~> 2.0", optional: true},
      {:dialyxir, "~> 0.5", only: :dev, runtime: false},
      {:jason, "~> 1.0", optional: true},
      {:stream_data, "~> 0.4.1", only: [:dev, :test]},
      {:gringotts, "~>1.1", only: :test, optional: true},
      {:ecto_sql, "~> 3.0", optional: true},
      ex_doc_version(System.version())
    ]
  end

  defp ex_doc_version(version) do
    cond do
      Version.compare(version, "1.7.0") in [:gt, :eq] ->
        {:ex_doc, "~> 0.19", only: [:dev, :release]}

      Version.compare(version, "1.6.0") == :lt ->
        {:ex_doc, ">= 0.17.0 and < 0.18.0", only: [:dev, :release]}

      Version.compare(version, "1.7.0") == :lt ->
        {:ex_doc, ">= 0.18.0 and < 0.19.0", only: [:dev, :release]}
    end
  end

  defp elixirc_paths(:test), do: ["lib", "test", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "mix"]
  defp elixirc_paths(_), do: ["lib"]
end
