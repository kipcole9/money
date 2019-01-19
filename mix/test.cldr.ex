defmodule Money.Cldr do
  @moduledoc false

  use Cldr,
    locales: ["en", "de", "it", "es"],
    providers: [Cldr, Cldr.Numbers]

end