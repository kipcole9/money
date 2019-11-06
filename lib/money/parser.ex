defmodule Money.Parser do
  import NimbleParsec

  @whitespace [?\s, ?\t]
  def whitespace do
    repeat(ascii_char(@whitespace))
    |> label("whitespace")
  end

  @separators [?,, ?،, ?٫, ?、, ?︐, ?︑, ?﹐, ?﹑, ?，, ?､]
  def separators do
    utf8_char(@separators)
    |> label("separators")
  end

  @decimal_places [?., ?․, ?。, ?︒, ?﹒, ?．, ?｡]
  def decimal_place do
    utf8_char(@decimal_places)
    |> label("decimal place character")
  end

  @digits [?0..?9]
  def digits do
    repeat(ascii_char([?0..?9]))
    |> label("digits")
  end

  @minus [?-]
  def minus do
    ascii_char(@minus)
  end

  def number do
    optional(minus())
    |> concat(digits())
    |> repeat(separators() |> concat(digits()))
    |> optional(decimal_place() |> concat(digits()))
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:amount)
    |> label("a number")
  end

  @currency Enum.map(@separators ++ @decimal_places ++ @digits ++ @minus, fn s -> {:not, s} end)
  def currency do
    utf8_char(@currency)
    |> times(min: 1)
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:currency)
    |> label("a currency code, symbol or name")
  end

  def money_with_currency do
    choice([
        optional(currency()) |> ignore(optional(whitespace())) |> concat(number() |> eos() |> label("currency followed by a number")),
        number() |> ignore(optional(whitespace())) |> optional((currency()) |> eos() |> label("number followed by a currency"))
      ])
  end

end