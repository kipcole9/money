if Mix.env != :prod do
  defmodule Money.Repo do
    use Ecto.Repo, otp_app: :ex_money

  end
end