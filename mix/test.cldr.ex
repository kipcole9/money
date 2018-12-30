defmodule Money.Cldr do
  use Cldr,
    locales: ["en", "de", "it", "es"],
    providers: [Cldr, Cldr.Numbers]

end