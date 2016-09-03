defmodule Money.Mixfile do
  use Mix.Project

  def project do
    [app: :money,
     version: "0.1.0",
     elixir: "> 1.2.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger]]
  end

  defp deps do
    [{:cldr, github: "kipcole9/cldr"}]
  end
end
