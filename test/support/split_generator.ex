defmodule GenerateSplits do
  require ExUnitProperties

  def generate_money do
    ExUnitProperties.gen all value <- StreamData.float(min: 0.0, max: 999999999999999.9),
    split <- StreamData.integer(1..101) do
      {Money.new(:USD, Float.to_string(value)), split}
    end
  end
end
