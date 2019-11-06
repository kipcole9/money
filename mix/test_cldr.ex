defmodule Money.Cldr do
  @moduledoc false

  use Cldr,
    locales: ["en", "de", "it", "es", "fr"],
    default_locale: "en",
    data_dir: "../cldr/priv/cldr",
    providers: [Cldr.Number, Money]
end
