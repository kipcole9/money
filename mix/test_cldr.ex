# require Money.Backend
require Money

defmodule Money.Cldr do
  @moduledoc false

  use Cldr,
    locales: [
      "en",
      "en-ZA",
      "bn",
      "de",
      "it",
      "es",
      "fr",
      "da",
      "zh-Hant-HK",
      "zh-Hans",
      "ja",
      "en-001",
      "th",
      "es-CO",
      "pt-CV",
      "ar-EG",
      "ar-MA"
    ],
    default_locale: "en",
    providers: [Cldr.Number, Cldr.Unit, Money]
end
