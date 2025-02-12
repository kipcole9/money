defmodule Money.Combinators do
  @moduledoc false

  import NimbleParsec

  # Whitespace as defined by Unicode set :Zs plus tab
  @whitespace [?\s, ?\t, 0xA0, 0x1680, 0x2000, 0x202F, 0x205F, 0x3000]
  def whitespace do
    repeat(empty(), utf8_char(@whitespace))
    |> label("whitespace")
  end

  @separators [?., ?,, ?،, ?٫, ?、, ?︐, ?︑, ?﹐, ?﹑, ?，, ?､, ? ]
  def separators do
    utf8_char(@separators)
    |> label("separators")
  end

  @decimal_places [?., ?․, ?。, ?︒, ?﹒, ?．, ?｡]
  def decimal_place do
    utf8_char(@decimal_places)
    |> label("decimal place character")
  end

  @left_parens [?(]
  def left_paren do
    utf8_char(@left_parens)
    |> label("left parenthesis")
  end

  @right_parens [?)]
  def right_paren do
    utf8_char(@right_parens)
    |> label("right parenthesis")
  end

  @digits [?0..?9]
  def digits do
    repeat(empty(), ascii_char([?0..?9]))
    |> label("digits")
  end

  @minus [?-]
  def minus do
    ascii_char(@minus)
  end

  def positive_number do
    digits()
    |> repeat(separators() |> concat(digits()))
    |> optional(decimal_place() |> concat(digits()))
    |> label("positive number")
  end

  def negative_number do
    choice(empty(), [
      ignore(minus())
      |> concat(positive_number()),
      positive_number()
      |> ignore(minus())
    ])
    |> reduce({List, :to_string, []})
    |> map(:add_minus_sign)
    |> label("negative number")
  end

  def number do
    choice(empty(), [negative_number(), positive_number()])
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:amount)
    |> label("number")
  end

  @rtl [0x200F]
  def rtl do
    ignore(utf8_char(@rtl))
  end

  @invalid_chars @digits ++ @left_parens ++ @minus ++ @rtl
  @currency Enum.map(@invalid_chars, fn s -> {:not, s} end)

  def currency do
    utf8_char(@currency)
    |> times(min: 1)
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:currency)
    |> label("currency code, symbol or name")
  end

  def money_with_currency do
    choice(empty(), [
      optional(rtl())
      |> concat(number())
      |> ignore(optional(whitespace()))
      |> optional(currency())
      |> optional(rtl())
      |> eos(),
      optional(rtl())
      |> optional(currency())
      |> ignore(optional(whitespace()))
      |> concat(number())
      |> optional(rtl())
      |> eos()
    ])
    |> label("money with currency")
  end

  def accounting_format do
    choice(empty(), [
      ignore(left_paren())
      |> ignore(optional(whitespace()))
      |> concat(number())
      |> ignore(optional(whitespace()))
      |> optional(currency())
      |> ignore(optional(whitespace()))
      |> ignore(right_paren()),
      ignore(left_paren())
      |> ignore(optional(whitespace()))
      |> optional(currency())
      |> ignore(optional(whitespace()))
      |> concat(number())
      |> ignore(optional(whitespace()))
      |> ignore(right_paren())
    ])
    |> map(:change_sign)
    |> label("money with currency in accounting format")
  end
end
