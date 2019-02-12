defmodule Money.Cldr do
  @moduledoc false

  use Cldr,
    locales: ["en", "de", "it", "es", "fr"],
    default_locale: "en",
    providers: [Cldr.Number]
end
