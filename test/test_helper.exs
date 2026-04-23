if Code.ensure_loaded?(DigitalToken) do
  ExUnit.start()
else
  ExUnit.start(exclude: [:digital_token])
end

{:ok, _currency} = Money.Currency.new(:ABCD, name: "ABCD", digits: 0)
