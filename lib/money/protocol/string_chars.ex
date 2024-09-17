if !Money.exclude_protocol_implementation(String.Chars) do
  defimpl String.Chars, for: Money do
    def to_string(v) do
      Money.to_string!(v)
    end
  end
end
