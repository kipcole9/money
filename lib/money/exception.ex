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

defmodule Money.Invalid do
  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end

defmodule Subscription.NoCurrentPlan do
  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end

defmodule Subscription.PlanError do
  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end

defmodule Subscription.DateError do
  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end

defmodule Subscription.PlanPending do
  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end
