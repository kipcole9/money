require Money.Backend
require Money

defmodule Test.Cldr do
  use Cldr,
    default_locale: "en",
    locales: ["en", "root", "de"],
    providers: [Cldr.Number, Money]
end
