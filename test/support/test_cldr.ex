require Money.Backend
require Money

defmodule Test.Cldr do
  use Cldr,
    default_locale: "en",
    locales: ["en", "de", "da", "nl", "de-CH", "fr", "zh-Hant-HK", "zh-Hans", "ja", "es-CO"],
    providers: [Cldr.Number, Money],
    suppress_warnings: true
end
