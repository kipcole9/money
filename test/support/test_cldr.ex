require Money.Backend
require Money

defmodule Test.Cldr do
  use Cldr,
    default_locale: "en",
    locales: [
      "en",
      "en-ZA",
      "de",
      "da",
      "nl",
      "de-CH",
      "fr",
      "zh-Hant-HK",
      "zh-Hans",
      "ja",
      "es-CO",
      "bn",
      "ar-MA"
    ],
    providers: [Cldr.Number, Money],
    suppress_warnings: true
end
