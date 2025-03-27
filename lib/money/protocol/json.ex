if Cldr.Config.ensure_compiled?(JSON) &&
     !Money.exclude_protocol_implementation(JSON.Encoder) do
  defimpl JSON.Encoder, for: Money do
    def encode(struct, encoder) do
      struct
      |> Map.take([:currency, :amount])
      |> encoder.(encoder)
    end
  end
end
