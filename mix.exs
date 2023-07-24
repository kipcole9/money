defmodule Money.Mixfile do
  use Mix.Project

  @version "5.15.0"

  def project do
    [
      app: :ex_money,
      version: @version,
      elixir: "~> 1.11",
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
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore_warnings",
        plt_add_apps: ~w(inets jason mix phoenix_html gringotts)a
      ],
      compilers: Mix.compilers()
    ]
  end

  defp description do
    """
    Money functions for operations on and localization of a money data type with support
    for ISO 4217 currencies and ISO 24165 digial tokens (crypto currencies).
    """
  end

  defp package do
    [
      maintainers: ["Kip Cole"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/kipcole9/money",
        "Readme" => "https://github.com/kipcole9/money/blob/v#{@version}/README.md",
        "Changelog" => "https://github.com/kipcole9/money/blob/v#{@version}/CHANGELOG.md"
      },
      files: [
        "lib",
        "config",
        "mix.exs",
        "README.md",
        "CHANGELOG.md",
        "LICENSE.md"
      ]
    ]
  end

  def application do
    [
      mod: {Money.Application, [strategy: :one_for_one, name: Money.Supervisor]},
      extra_applications: [:inets, :logger, :decimal]
    ]
  end

  def docs do
    [
      source_ref: "v#{@version}",
      extras: ["README.md", "CHANGELOG.md", "LICENSE.md"],
      main: "readme",
      groups_for_modules: groups_for_modules(),
      logo: "logo.png",
      skip_undefined_reference_warnings_on: ["changelog", "CHANGELOG.md", "README.md"]
    ]
  end

  defp groups_for_modules do
    [
      "Exchange Rates": ~r/^Money.ExchangeRates.?/,
      Subscriptions: ~r/^Money.Subscription.?/
    ]
  end

  def aliases do
    []
  end

  defp deps do
    [
      {:ex_cldr_numbers, "~> 2.31"},

      {:nimble_parsec, "~> 0.5 or ~> 1.0"},
      {:decimal, "~> 1.6 or ~> 2.0"},
      {:poison, "~> 3.0 or ~> 4.0 or ~> 5.0", optional: true},
      {:phoenix_html, "~> 2.0 or ~> 3.0", optional: true},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:jason, "~> 1.0", optional: true},
      {:stream_data, "~> 0.4", only: [:dev, :test]},
      {:benchee, "~> 1.0", optional: true, only: :dev},
      {:exprof, "~> 0.2", only: :dev, runtime: false},
      {:ex_doc, "~> 0.22", only: [:dev, :release]},

      {:gringotts, "~> 1.1", optional: true}
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp elixirc_paths(:test), do: ["lib", "test", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "mix"]
  defp elixirc_paths(_), do: ["lib"]
end
