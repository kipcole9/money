defmodule Money.UnknownCurrencyError do
  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end

defmodule Money.CurrencyAlreadyDefinedError do
  defexception [:currency]

  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{currency: currency}) do
    "The currency #{inspect(currency)} is already defined."
  end
end

defmodule Money.CurrencyNotSavedError do
  defexception [:currency]

  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{currency: currency}) do
    "The currency #{inspect(currency)} could not be saved. Ensure Money.Currency.Store is started."
  end
end

defmodule Money.InvalidCurrencyError do
  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end

defmodule Money.FormatError do
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
