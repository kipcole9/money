defimpl Inspect, for: Money do
  # import Inspect.Algebra

  def inspect(money, _opts) do
    Money.to_string(money)
  end
end