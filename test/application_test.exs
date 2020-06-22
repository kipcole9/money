defmodule Money.Application.Test do
  use ExUnit.Case

  test "That our default Application supervisor has the default options" do
    {_app, options} = Application.spec(:ex_money) |> Keyword.get(:mod)
    assert options == [strategy: :one_for_one, name: Money.Supervisor]
  end

  test "default supervisor name" do
    assert Money.ExchangeRates.Supervisor.default_supervisor == Money.Supervisor
  end
end