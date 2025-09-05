defmodule TradingSwarmWeb.Live.Helpers do
  @moduledoc """
  Shared helper functions for LiveView modules.

  Provides consistent formatting for currency, numbers, timestamps, P&L,
  percentages, and color-coding across all LiveViews.
  """

  @doc """
  Formats a Decimal or numeric value as currency with $ symbol and 2 decimal places.

  ## Examples

      iex> format_currency(Decimal.new("1234.56"))
      "$1,234.56"
      
      iex> format_currency(1234.56)
      "$1,234.56"
      
      iex> format_currency(-1234.56)
      "-$1,234.56"
  """
  def format_currency(value) when is_nil(value), do: "$0.00"

  def format_currency(%Decimal{} = value) do
    value
    |> Decimal.to_float()
    |> format_currency()
  end

  def format_currency(value) when is_number(value) do
    formatted = Number.Currency.number_to_currency(value, format: "%n", precision: 2)
    "$#{formatted}"
  end

  def format_currency(_), do: "$0.00"

  @doc """
  Formats a number with default precision of 2 decimal places.

  ## Examples

      iex> format_number(1234.5678)
      "1,234.57"
      
      iex> format_number(Decimal.new("1234.5678"))
      "1,234.57"
  """
  def format_number(value), do: format_number(value, 2)

  @doc """
  Formats a number with specified precision.

  ## Examples

      iex> format_number(1234.5678, 4)
      "1,234.5678"
      
      iex> format_number(1234.5678, 0)
      "1,235"
  """
  def format_number(value, _precision) when is_nil(value), do: "0"

  def format_number(%Decimal{} = value, precision) do
    value
    |> Decimal.to_float()
    |> format_number(precision)
  end

  def format_number(value, precision) when is_number(value) do
    Number.Delimit.number_to_delimited(value, precision: precision)
  end

  def format_number(_, _), do: "0"

  @doc """
  Formats a DateTime or NaiveDateTime as a readable timestamp.

  ## Examples

      iex> format_timestamp(~U[2023-12-01 14:30:00Z])
      "Dec 1, 2:30 PM"
  """
  def format_timestamp(nil), do: "N/A"

  def format_timestamp(%DateTime{} = datetime) do
    date_str = datetime |> DateTime.to_date() |> format_date_short()
    time_str = datetime |> DateTime.to_time() |> format_time()
    date_str <> ", " <> time_str
  end

  def format_timestamp(%NaiveDateTime{} = naive_datetime) do
    date_str = naive_datetime |> NaiveDateTime.to_date() |> format_date_short()
    time_str = naive_datetime |> NaiveDateTime.to_time() |> format_time()
    date_str <> ", " <> time_str
  end

  def format_timestamp(_), do: "N/A"

  @doc """
  Formats P&L with color indication (positive = green, negative = red).
  Returns a tuple of {value, color_class}.

  ## Examples

      iex> format_pnl(Decimal.new("150.25"))
      {"$150.25", "text-green-600"}
      
      iex> format_pnl(Decimal.new("-75.50"))
      {"-$75.50", "text-red-600"}
  """
  def format_pnl(value) when is_nil(value), do: {"$0.00", "text-gray-500"}

  def format_pnl(%Decimal{} = value) do
    color_class = pnl_color(value)
    formatted_value = format_currency(value)
    {formatted_value, color_class}
  end

  def format_pnl(value) when is_number(value) do
    decimal_value = Decimal.from_float(value)
    format_pnl(decimal_value)
  end

  def format_pnl(_), do: {"$0.00", "text-gray-500"}

  @doc """
  Formats a decimal as a percentage.

  ## Examples

      iex> format_percentage(0.1567)
      "15.67%"
      
      iex> format_percentage(Decimal.new("0.1567"))
      "15.67%"
  """
  def format_percentage(value) when is_nil(value), do: "0.00%"

  def format_percentage(%Decimal{} = value) do
    value
    |> Decimal.to_float()
    |> format_percentage()
  end

  def format_percentage(value) when is_number(value) do
    Number.Percentage.number_to_percentage(value * 100, precision: 2)
  end

  def format_percentage(_), do: "0.00%"

  @doc """
  Formats a Time as a readable time string.

  ## Examples

      iex> format_time(~T[14:30:45])
      "2:30 PM"
  """
  def format_time(nil), do: "N/A"

  def format_time(%Time{} = time) do
    hour = time.hour
    minute = time.minute

    {display_hour, period} =
      case hour do
        0 -> {12, "AM"}
        h when h < 12 -> {h, "AM"}
        12 -> {12, "PM"}
        h -> {h - 12, "PM"}
      end

    minute_str = if minute < 10, do: "0#{minute}", else: "#{minute}"
    "#{display_hour}:#{minute_str} #{period}"
  end

  def format_time(_), do: "N/A"

  @doc """
  Returns the appropriate color class for a status.

  ## Examples

      iex> status_color(:active)
      "text-green-600"
      
      iex> status_color(:error)
      "text-red-600"
  """
  def status_color(:active), do: "text-green-600"
  def status_color(:idle), do: "text-yellow-600"
  def status_color(:error), do: "text-red-600"
  def status_color(:offline), do: "text-gray-500"
  def status_color(:paused), do: "text-blue-600"
  def status_color(:excellent), do: "text-green-600"
  def status_color(:good), do: "text-green-500"
  def status_color(:fair), do: "text-yellow-500"
  def status_color(:poor), do: "text-orange-500"
  def status_color(:critical), do: "text-red-600"
  def status_color(_), do: "text-gray-500"

  @doc """
  Returns the appropriate color class for P&L values.

  ## Examples

      iex> pnl_color(Decimal.new("150.25"))
      "text-green-600"
      
      iex> pnl_color(Decimal.new("-75.50"))
      "text-red-600"
  """
  def pnl_color(value) when is_nil(value), do: "text-gray-500"

  def pnl_color(%Decimal{} = value) do
    case Decimal.compare(value, Decimal.new("0")) do
      :gt -> "text-green-600"
      :lt -> "text-red-600"
      :eq -> "text-gray-500"
    end
  end

  def pnl_color(value) when is_number(value) do
    cond do
      value > 0 -> "text-green-600"
      value < 0 -> "text-red-600"
      true -> "text-gray-500"
    end
  end

  def pnl_color(_), do: "text-gray-500"

  @doc """
  Returns the appropriate color class for risk levels.

  ## Examples

      iex> risk_color(:low)
      "text-green-600"
      
      iex> risk_color(:high)
      "text-red-600"
  """
  def risk_color(:low), do: "text-green-600"
  def risk_color(:moderate), do: "text-yellow-600"
  def risk_color(:medium), do: "text-yellow-600"
  def risk_color(:high), do: "text-red-600"
  def risk_color(:critical), do: "text-red-800"

  def risk_color(value) when is_number(value) do
    cond do
      value < 0.3 -> "text-green-600"
      value < 0.6 -> "text-yellow-600"
      value < 0.8 -> "text-orange-600"
      true -> "text-red-600"
    end
  end

  def risk_color(_), do: "text-gray-500"

  # Private helper functions

  defp format_date_short(%Date{} = date) do
    months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ]

    month_name = Enum.at(months, date.month - 1)
    "#{month_name} #{date.day}"
  end

  defp format_date_short(_), do: "N/A"
end
