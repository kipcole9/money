defmodule Money.Combinators do
  @moduledoc false

  import NimbleParsec

  @whitespace [?\s, ?\t]
  def whitespace do
    repeat(utf8_char(@whitespace))
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
    repeat(ascii_char([?0..?9]))
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
    choice([
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
    choice([negative_number(), positive_number()])
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:amount)
    |> label("number")
  end

  @invalid_chars @separators ++
                   @decimal_places ++
                   @digits ++
                   @minus ++
                   @left_parens ++
                   @right_parens

  @currency Enum.map(@invalid_chars, fn s -> {:not, s} end)
  def currency do
    utf8_char(@currency)
    |> times(min: 1)
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:currency)
    |> label("currency code, symbol or name")
  end

  def money_with_currency do
    choice([
      number()
      |> ignore(optional(whitespace()))
      |> optional(currency())
      |> eos(),
      optional(currency())
      |> ignore(optional(whitespace()))
      |> concat(number())
      |> eos()
    ])
  end

  def accounting_format do
    choice([
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
  end

end
