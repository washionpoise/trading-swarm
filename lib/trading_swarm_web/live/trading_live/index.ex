defmodule TradingSwarmWeb.TradingLive.Index do
  @moduledoc """
  LiveView for trading activity dashboard.

  Features:
  - Real-time trade feed with prepend updates
  - Trading statistics and metrics
  - Market overview and analysis
  - Filtering and sorting capabilities
  """

  use TradingSwarmWeb, :live_view
  require Logger

  alias TradingSwarm.Trading

  import TradingSwarmWeb.TradingComponents
  import TradingSwarmWeb.DashboardComponents
  import TradingSwarmWeb.ChartComponents

  @impl true
  def mount(_params, _session, socket) do
    Logger.info("TradingLive.Index mounted")

    # Subscribe to real-time trading updates
    if connected?(socket) do
      Phoenix.PubSub.subscribe(TradingSwarm.PubSub, "trading_updates")
      Phoenix.PubSub.subscribe(TradingSwarm.PubSub, "market_updates")
    end

    socket =
      socket
      |> assign_trading_data()
      |> assign(:loading, false)
      |> assign(:last_updated, DateTime.utc_now())
      |> assign(:status_filter, "all")
      |> assign(:symbol_filter, "all")
      |> assign(:sort_by, "time")
      |> assign(:timeframe, "24h")

    {:ok, socket}
  end

  @impl true
  def handle_event("filter_trades", %{"status" => status, "symbol" => symbol}, socket) do
    socket =
      socket
      |> assign(:status_filter, status)
      |> assign(:symbol_filter, symbol)
      |> assign(:trades, load_trades(status, symbol, socket.assigns.sort_by))

    {:noreply, socket}
  end

  @impl true
  def handle_event("sort_trades", %{"sort_by" => sort_by}, socket) do
    socket =
      socket
      |> assign(:sort_by, sort_by)
      |> assign(
        :trades,
        load_trades(socket.assigns.status_filter, socket.assigns.symbol_filter, sort_by)
      )

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_timeframe", %{"timeframe" => timeframe}, socket) do
    socket =
      socket
      |> assign(:timeframe, timeframe)
      |> assign_trading_statistics(timeframe)

    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh_trading", _params, socket) do
    Logger.info("Manual trading refresh requested")

    socket =
      socket
      |> assign(:loading, true)
      |> assign_trading_data()
      |> assign(:last_updated, DateTime.utc_now())
      |> assign(:loading, false)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:trading_update, trade_data}, socket) do
    Logger.debug("Received trading update: #{inspect(trade_data)}")

    # Prepend new trade to the list
    updated_trades = [trade_data | Enum.take(socket.assigns.trades, 49)]

    socket =
      socket
      |> assign(:trades, updated_trades)
      |> assign(:last_updated, DateTime.utc_now())
      |> update_trading_statistics(trade_data)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:market_update, market_data}, socket) do
    Logger.debug("Received market update: #{inspect(market_data)}")

    socket =
      socket
      |> assign(:market_overview, market_data)
      |> assign(:last_updated, DateTime.utc_now())

    {:noreply, socket}
  end

  # Private functions

  defp assign_trading_data(socket) do
    try do
      timeframe = socket.assigns[:timeframe] || "24h"

      socket
      |> assign(:trades, load_trades("all", "all", "time"))
      |> assign_trading_statistics(timeframe)
      |> assign(:market_overview, get_market_overview())
      |> assign(:filter_options, get_filter_options())
    rescue
      error ->
        Logger.error("Error loading trading data: #{inspect(error)}")
        assign_fallback_trading_data(socket)
    end
  end

  defp assign_trading_statistics(socket, timeframe) do
    stats = get_trading_statistics(timeframe)
    performance_data = get_performance_data(timeframe)

    socket
    |> assign(:trading_stats, stats)
    |> assign(:performance_data, performance_data)
    |> assign(:pnl_chart_data, get_pnl_chart_data(timeframe))
    |> assign(:volume_chart_data, get_volume_chart_data(timeframe))
  end

  defp load_trades(status_filter, symbol_filter, sort_by) do
    # This would query the database with filters
    # For now, returning mock data
    base_trades = [
      %{
        id: "trade_001",
        symbol: "BTC-USD",
        side: "buy",
        type: "market",
        quantity: 0.5,
        price: 50000.00,
        executed_at: DateTime.utc_now() |> DateTime.add(-300, :second),
        status: "executed",
        pnl: 125.50,
        fees: 25.00,
        agent_id: "agent_001",
        agent_name: "Alpha Trader"
      },
      %{
        id: "trade_002",
        symbol: "ETH-USD",
        side: "sell",
        type: "limit",
        quantity: 2.0,
        price: 3000.00,
        executed_at: DateTime.utc_now() |> DateTime.add(-600, :second),
        status: "executed",
        pnl: -75.25,
        fees: 15.00,
        agent_id: "agent_002",
        agent_name: "Beta Scalper"
      },
      %{
        id: "trade_003",
        symbol: "ADA-USD",
        side: "buy",
        type: "market",
        quantity: 1000.0,
        price: 1.50,
        executed_at: DateTime.utc_now() |> DateTime.add(-900, :second),
        status: "pending",
        pnl: 0,
        fees: 0,
        agent_id: "agent_003",
        agent_name: "Gamma Swing"
      }
    ]

    # Apply filters
    filtered_trades =
      base_trades
      |> filter_by_status(status_filter)
      |> filter_by_symbol(symbol_filter)
      |> sort_trades(sort_by)

    filtered_trades
  end

  defp filter_by_status(trades, "all"), do: trades
  defp filter_by_status(trades, status), do: Enum.filter(trades, &(&1.status == status))

  defp filter_by_symbol(trades, "all"), do: trades
  defp filter_by_symbol(trades, symbol), do: Enum.filter(trades, &(&1.symbol == symbol))

  defp sort_trades(trades, "time"), do: Enum.sort_by(trades, & &1.executed_at, {:desc, DateTime})
  defp sort_trades(trades, "symbol"), do: Enum.sort_by(trades, & &1.symbol)
  defp sort_trades(trades, "pnl"), do: Enum.sort_by(trades, & &1.pnl, :desc)
  defp sort_trades(trades, "volume"), do: Enum.sort_by(trades, &(&1.quantity * &1.price), :desc)
  defp sort_trades(trades, _), do: trades

  defp get_trading_statistics(timeframe) do
    # This would query actual statistics from database
    # For now, returning mock data
    %{
      timeframe: timeframe,
      total_trades: 156,
      executed_trades: 142,
      pending_trades: 8,
      failed_trades: 6,
      total_volume: Decimal.new("2847593.50"),
      total_pnl: Decimal.new("12847.75"),
      avg_trade_size: Decimal.new("18252.52"),
      win_rate: 0.67,
      best_trade: Decimal.new("2450.00"),
      worst_trade: Decimal.new("-890.25"),
      total_fees: Decimal.new("1247.85")
    }
  end

  defp get_performance_data(timeframe) do
    # This would calculate performance data for charts
    # For now, returning mock data points
    case timeframe do
      "1h" ->
        Enum.map(0..11, fn i ->
          {DateTime.utc_now() |> DateTime.add(-i * 300, :second), :rand.uniform(1000) - 500}
        end)
        |> Enum.reverse()

      "24h" ->
        Enum.map(0..23, fn i ->
          {DateTime.utc_now() |> DateTime.add(-i * 3600, :second), :rand.uniform(2000) - 1000}
        end)
        |> Enum.reverse()

      "7d" ->
        Enum.map(0..6, fn i ->
          {DateTime.utc_now() |> DateTime.add(-i * 86400, :second), :rand.uniform(5000) - 2500}
        end)
        |> Enum.reverse()

      _ ->
        []
    end
  end

  defp get_pnl_chart_data(_timeframe) do
    # Mock P&L chart data
    [
      {"Morning", 250},
      {"Afternoon", -125},
      {"Evening", 450},
      {"Night", 180}
    ]
  end

  defp get_volume_chart_data(_timeframe) do
    # Mock volume chart data
    [
      {"BTC-USD", 125_000},
      {"ETH-USD", 89000},
      {"ADA-USD", 45000},
      {"SOL-USD", 32000}
    ]
  end

  defp get_market_overview() do
    %{
      market_status: :open,
      total_market_cap: Decimal.new("2500000000000"),
      btc_dominance: 42.5,
      fear_greed_index: 65,
      active_symbols: 12,
      trending_up: ["BTC-USD", "ETH-USD"],
      trending_down: ["ADA-USD"]
    }
  end

  defp get_filter_options() do
    %{
      statuses: ["all", "executed", "pending", "failed", "cancelled"],
      symbols: ["all", "BTC-USD", "ETH-USD", "ADA-USD", "SOL-USD", "DOT-USD"]
    }
  end

  defp update_trading_statistics(socket, trade_data) do
    # Update statistics when new trade comes in
    current_stats = socket.assigns.trading_stats

    updated_stats = %{
      current_stats
      | total_trades: current_stats.total_trades + 1,
        total_volume:
          Decimal.add(
            current_stats.total_volume,
            Decimal.new(trade_data[:volume] || "0")
          ),
        total_pnl:
          Decimal.add(
            current_stats.total_pnl,
            Decimal.new(trade_data[:pnl] || "0")
          )
    }

    assign(socket, :trading_stats, updated_stats)
  end

  defp assign_fallback_trading_data(socket) do
    socket
    |> assign(:trades, [])
    |> assign(:trading_stats, %{
      total_trades: 0,
      executed_trades: 0,
      pending_trades: 0,
      failed_trades: 0,
      total_volume: Decimal.new("0.00"),
      total_pnl: Decimal.new("0.00"),
      win_rate: 0.0
    })
    |> assign(:market_overview, %{market_status: :unknown})
    |> assign(:filter_options, %{statuses: [], symbols: []})
    |> assign(:performance_data, [])
    |> assign(:pnl_chart_data, [])
    |> assign(:volume_chart_data, [])
  end
end
