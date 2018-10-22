defmodule Money.Mixfile do
  use Mix.Project

  @version "2.12.1"

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
      compilers: Mix.compilers() ++ [:cldr]
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
      {:ex_cldr, "~> 1.8"},
      {:ex_cldr_numbers, "~> 1.6"},
      {:decimal, "~> 1.4"},
      {:phoenix_html, "~> 2.0", optional: true},
      {:dialyxir, "~> 0.5", only: :dev, runtime: false},
      {:jason, "~> 1.0", optional: true},
      {:poison, "~> 2.2 or ~> 3.1", optional: true},
      {:stream_data, "~> 0.4.1", only: [:dev, :test]},
      {:gringotts, "~>1.1", optional: true},
      ecto_version(System.get_env("ECTO_VERSION")),
      ex_doc_version(System.version())
    ]
  end

  defp ex_doc_version(version) do
    cond do
      Version.compare(version, "1.7.0") in [:gt, :eq] ->
        {:ex_doc, "~> 0.19", only: :dev}
      Version.compare(version, "1.6.0") == :lt ->
        {:ex_doc, ">= 0.17.0 and < 0.18.0", only: :dev}
      Version.compare(version, "1.7.0") == :lt ->
        {:ex_doc, ">= 0.18.0 and < 0.19.0", only: :dev}
    end
  end

  defp ecto_version(nil), do: {:ecto, "~> 2.1 or ~> 3.0", optional: true}
  defp ecto_version("2"), do: {:ecto, "~> 2.1", optional: true}
  defp ecto_version("3"), do: {:ecto_sql, "~> 3.0.0-rc", optional: true}
  defp ecto_version(other) do
    raise "$ECTO_VERSION should be either nil, 2 or 3.  Found #{inspect other}"
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
