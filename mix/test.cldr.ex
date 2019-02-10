defmodule Money.Cldr do
  @moduledoc false

  use Cldr,
    locales: ["en", "de", "it", "es", "fr"],
    providers: [Cldr.Number]
end
