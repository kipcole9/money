require Money.Backend
require Money

defmodule Test.Cldr do
  use Cldr,
    default_locale: "en",
    locales: ["en", "root", "de", "da", "nl", "de-CH", "fr"],
    providers: [Cldr.Number, Money],
    supress_warnings: true
end
