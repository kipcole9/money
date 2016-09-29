defmodule Money.Arithmetic do
  @moduledoc """
  Arithmetic functions for %Money{}
  """

  def add(%Money{currency: code_a, value: value_a}, %Money{currency: code_b, value: value_b})
  when code_a == code_b do
    %Money{currency: code_a, value: Decimal.add(value_a, value_b)}
  end

  def mult(%Money{currency: code_a, value: value_a}, %Money{currency: code_b, value: value_b})
  when code_a == code_b do
    %Money{currency: code_a, value: Decimal.mult(value_a, value_b)}
  end

  def sub(%Money{currency: code_a, value: value_a}, %Money{currency: code_b, value: value_b})
  when code_a == code_b do
    %Money{currency: code_a, value: Decimal.sub(value_a, value_b)}
  end

  def div(%Money{currency: code_a, value: value_a}, %Money{currency: code_b, value: value_b})
  when code_a == code_b do
    %Money{currency: code_a, value: Decimal.div(value_a, value_b)}
  end
end