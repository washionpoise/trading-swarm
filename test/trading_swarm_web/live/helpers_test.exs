defmodule TradingSwarmWeb.Live.HelpersTest do
  use ExUnit.Case
  alias TradingSwarmWeb.Live.Helpers
  doctest Helpers

  describe "format_currency/1" do
    test "formats Decimal currency values correctly" do
      assert Helpers.format_currency(Decimal.new("1234.56")) == "$1,234.56"
      assert Helpers.format_currency(Decimal.new("-1234.56")) == "$-1,234.56"
      assert Helpers.format_currency(Decimal.new("0")) == "$0.00"
    end

    test "formats numeric currency values correctly" do
      assert Helpers.format_currency(1234.56) == "$1,234.56"
      assert Helpers.format_currency(-1234.56) == "$-1,234.56"
      assert Helpers.format_currency(0) == "$0.00"
    end

    test "handles nil values" do
      assert Helpers.format_currency(nil) == "$0.00"
    end
  end

  describe "format_number/1 and format_number/2" do
    test "formats numbers with default precision" do
      assert Helpers.format_number(1234.5678) == "1,234.57"
      assert Helpers.format_number(Decimal.new("1234.5678")) == "1,234.57"
    end

    test "formats numbers with custom precision" do
      assert Helpers.format_number(1234.5678, 4) == "1,234.5678"
      assert Helpers.format_number(1234.5678, 0) == "1,235"
    end

    test "handles nil values" do
      assert Helpers.format_number(nil) == "0"
      assert Helpers.format_number(nil, 4) == "0"
    end
  end

  describe "format_percentage/1" do
    test "formats decimal percentages" do
      assert Helpers.format_percentage(0.1567) == "15.67%"
      assert Helpers.format_percentage(Decimal.new("0.1567")) == "15.67%"
    end

    test "handles nil values" do
      assert Helpers.format_percentage(nil) == "0.00%"
    end
  end

  describe "format_pnl/1" do
    test "returns positive P&L with green color" do
      assert Helpers.format_pnl(Decimal.new("150.25")) == {"$150.25", "text-green-600"}
      assert Helpers.format_pnl(150.25) == {"$150.25", "text-green-600"}
    end

    test "returns negative P&L with red color" do
      assert Helpers.format_pnl(Decimal.new("-75.50")) == {"$-75.50", "text-red-600"}
      assert Helpers.format_pnl(-75.50) == {"$-75.50", "text-red-600"}
    end

    test "returns zero P&L with gray color" do
      assert Helpers.format_pnl(Decimal.new("0")) == {"$0.00", "text-gray-500"}
      assert Helpers.format_pnl(0) == {"$0.00", "text-gray-500"}
    end

    test "handles nil values" do
      assert Helpers.format_pnl(nil) == {"$0.00", "text-gray-500"}
    end
  end

  describe "format_time/1" do
    test "formats time correctly" do
      time = ~T[14:30:45]
      assert Helpers.format_time(time) == "2:30 PM"

      time = ~T[09:05:30]
      assert Helpers.format_time(time) == "9:05 AM"

      time = ~T[00:00:00]
      assert Helpers.format_time(time) == "12:00 AM"

      time = ~T[12:00:00]
      assert Helpers.format_time(time) == "12:00 PM"
    end

    test "handles nil values" do
      assert Helpers.format_time(nil) == "N/A"
    end
  end

  describe "status_color/1" do
    test "returns correct colors for statuses" do
      assert Helpers.status_color(:active) == "text-green-600"
      assert Helpers.status_color(:idle) == "text-yellow-600"
      assert Helpers.status_color(:error) == "text-red-600"
      assert Helpers.status_color(:offline) == "text-gray-500"
      assert Helpers.status_color(:unknown) == "text-gray-500"
    end
  end

  describe "pnl_color/1" do
    test "returns correct colors for P&L values" do
      assert Helpers.pnl_color(Decimal.new("100")) == "text-green-600"
      assert Helpers.pnl_color(Decimal.new("-100")) == "text-red-600"
      assert Helpers.pnl_color(Decimal.new("0")) == "text-gray-500"
      assert Helpers.pnl_color(100) == "text-green-600"
      assert Helpers.pnl_color(-100) == "text-red-600"
      assert Helpers.pnl_color(0) == "text-gray-500"
    end

    test "handles nil values" do
      assert Helpers.pnl_color(nil) == "text-gray-500"
    end
  end

  describe "risk_color/1" do
    test "returns correct colors for risk levels" do
      assert Helpers.risk_color(:low) == "text-green-600"
      assert Helpers.risk_color(:moderate) == "text-yellow-600"
      assert Helpers.risk_color(:high) == "text-red-600"
      assert Helpers.risk_color(:critical) == "text-red-800"
    end

    test "returns correct colors for numeric risk values" do
      assert Helpers.risk_color(0.2) == "text-green-600"
      assert Helpers.risk_color(0.5) == "text-yellow-600"
      assert Helpers.risk_color(0.7) == "text-orange-600"
      assert Helpers.risk_color(0.9) == "text-red-600"
    end
  end
end
