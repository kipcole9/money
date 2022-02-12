if Cldr.Config.ensure_compiled?(Jason) &&
    !Money.exclude_protocol_implementation(Json.Encoder) do
  defimpl Jason.Encoder, for: Money do
    def encode(struct, opts) do
      struct
      |> Map.take([:currency, :amount])
      |> Jason.Encode.map(opts)
    end
  end
end