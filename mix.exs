defmodule Money.Mixfile do
  use Mix.Project

  @version "2.6.1"

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
      dialyzer: [ignore_warnings: ".dialyzer_ignore_warnings"]
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
      logo: "logo.png"
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
      {:ex_cldr, "~> 1.6"},
      {:ex_cldr_numbers, "~> 1.4"},
      {:decimal, "~> 1.4"},
      {:ecto, "~> 2.1", optional: true},
      {:phoenix_html, "~> 2.0", optional: true},
      {:ex_doc, "~> 0.18", only: :dev},
      {:dialyxir, "~> 0.5", only: :dev, runtime: false},
      {:jason, "~> 1.0", optional: true},
      {:poison, "~> 2.2 or ~> 3.1", optional: true},
      {:stream_data, "~> 0.4.1", only: [:dev, :test]},
      {:gringotts, "~>1.1", optional: true}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
