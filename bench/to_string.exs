money = Money.new(:USD, 100)

Benchee.run(
  %{
    "to_string" => fn -> Money.to_string(money) end
  },
  time: 10,
  memory_time: 2
)