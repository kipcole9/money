defmodule Money.Mixfile do
  use Mix.Project

  def project do
    [app: :ex_money,
     version: "0.0.1",
     elixir: "> 1.2.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [applications: [:logger, :ex_cldr, :postgrex]]
  end

  defp deps do
    [
      {:ex_cldr, ">= 0.0.3"},
      {:postgrex, ">= 0.0.0", only: [:dev, :test]},
      {:ecto, "~> 2.0", only: [:dev, :test]}
    ]
  end
end
