if !Money.exclude_protocol_implementation(String.Chars) do
  defimpl String.Chars, for: Money do
    def to_string(v) do
      Money.to_string!(v)
    end
  end

  if Code.ensure_loaded?(Cldr.Unit) do
    defimpl String.Chars, for: Money.Subscription.Plan do
      def to_string(v) do
        Money.Subscription.Plan.to_string!(v)
      end
    end
  end
end
