defmodule Money.UnknownCurrencyError do
  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end

defmodule Money.ExchangeRateError do
  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end

defmodule Money.InvalidAmountError do
  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end

defmodule Money.InvalidDigitsError do
  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end

defmodule Money.Invalid do
  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end

defmodule Money.ParseError do
  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end

defmodule Money.Subscription.NoCurrentPlan do
  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end

defmodule Money.Subscription.PlanError do
  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end

defmodule Money.Subscription.DateError do
  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end

defmodule Money.Subscription.PlanPending do
  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end
