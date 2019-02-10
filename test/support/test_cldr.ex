defmodule Test.Cldr do
  use Cldr,
    default_locale: "en",
    locales: ["en", "root", "de"],
    providers: [Cldr.Number]
end
