require Money.Backend
require Money

defmodule Test.Cldr do
  use Cldr,
    default_locale: "en",
    locales: ["en", "root", "de", "da", "nl", "de-CH", "fr", "zh-Hant-HK", "zh-Hans", "ja"],
    providers: [Cldr.Number, Money],
    supress_warnings: true
end
