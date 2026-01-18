ExUnit.start()
{:ok, _pid} = Cldr.Currency.start_link()
{:ok, _currency} = Cldr.Currency.new(:ABCD, name: "ABCD", digits: 0)