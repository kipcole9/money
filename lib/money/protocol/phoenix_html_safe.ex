if Cldr.Config.ensure_compiled?(Phoenix.HTML.Safe) &&
     !Money.exclude_protocol_implementation(Phoenix.HTML.Safe) do
  defimpl Phoenix.HTML.Safe, for: Money do
    def to_iodata(money) do
      Phoenix.HTML.Safe.to_iodata(Money.to_string!(money))
    end
  end
end
