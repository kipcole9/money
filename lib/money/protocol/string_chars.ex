defimpl String.Chars, for: Money do
  def to_string(v) do
    Money.to_string!(v)
  end
end