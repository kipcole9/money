money = Money.new(:USD, 100)

options = [currency: money.currency]
number = money.amount
backend = Money.default_backend

{:ok, options} = Cldr.Number.Format.Options.validate_options(0, backend, options)

Benchee.run(
  %{
    "to_string" => fn -> Money.to_string(money, options) end
  },
  time: 10,
  memory_time: 2
)