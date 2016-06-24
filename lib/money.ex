defmodule Money do
  @moduledoc """
  Defines the Money struct. Implements the Ecto.Type behaviour
  """
  
  @type t :: %Money{ currency: String.t , value: Decimal }
  defstruct currency: nil, value: nil
  
  if Code.ensure_loaded?(Ecto.Type) do
    @behaviour Ecto.Type
    def type, do: :money_with_currency
    def blank?(_), do: false

    def load(money), 
      do: {:ok, %Money{currency: elem(money, 0), value: elem(money, 1)}}

    def dump(%Money{} = money), 
      do: {:ok, {money.code, money.value}}
    def dump(money) when is_tuple(money),
      do: {:ok, money}
    def dump(_), 
      do: :error

    def cast(%Money{} = money), 
      do: {:ok, money}
    def cast(money) when is_tuple(money), 
      do: {:ok,  %Money{currency: elem(money, 0), value: elem(money, 1)}}
    def cast(_money), 
      do: :error
  end
end

defimpl Inspect, for: Money do
  import Inspect.Algebra

  def inspect(money, _opts) do
    concat ["#Money<", "#{money.currency} #{money.value}", ">"]
  end
end