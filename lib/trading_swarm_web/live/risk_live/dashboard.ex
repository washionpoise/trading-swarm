defmodule TradingSwarmWeb.RiskLive.Dashboard do
  @moduledoc """
  LiveView for risk management dashboard.

  Features:
  - Risk meters and gauges
  - Exposure visualization
  - Correlation matrix display
  - VaR calculations and stress tests
  - Real-time risk alerts
  """

  use TradingSwarmWeb, :live_view
  require Logger

  alias TradingSwarm.Risk

  import TradingSwarmWeb.ChartComponents
  import TradingSwarmWeb.DashboardComponents
  import TradingSwarmWeb.TradingComponents

  @impl true
  def mount(_params, _session, socket) do
    Logger.info("RiskLive.Dashboard mounted")

    # Subscribe to risk updates
    if connected?(socket) do
      Phoenix.PubSub.subscribe(TradingSwarm.PubSub, "risk_updates")
      Phoenix.PubSub.subscribe(TradingSwarm.PubSub, "trading_updates")
    end

    socket =
      socket
      |> assign_risk_data()
      |> assign(:loading, false)
      |> assign(:last_updated, DateTime.utc_now())
      |> assign(:selected_timeframe, "24h")
      |> assign(:exposure_grouping, "symbol")

    {:ok, socket}
  end

  @impl true
  def handle_event("change_timeframe", %{"timeframe" => timeframe}, socket) do
    socket =
      socket
      |> assign(:selected_timeframe, timeframe)
      |> load_risk_data_for_timeframe(timeframe)

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_exposure_grouping", %{"grouping" => grouping}, socket) do
    socket =
      socket
      |> assign(:exposure_grouping, grouping)
      |> load_exposure_data(grouping)

    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh_risk", _params, socket) do
    Logger.info("Manual risk refresh requested")

    socket =
      socket
      |> assign(:loading, true)
      |> assign_risk_data()
      |> assign(:last_updated, DateTime.utc_now())
      |> assign(:loading, false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("resolve_alert", %{"alert_id" => alert_id}, socket) do
    Logger.info("Resolving risk alert #{alert_id}")

    case Risk.resolve_event(alert_id) do
      {:ok, _resolved_event} ->
        socket =
          socket
          |> put_flash(:info, "Risk alert resolved successfully")
          |> assign_risk_data()

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Failed to resolve alert: #{inspect(reason)}")
        socket = put_flash(socket, :error, "Failed to resolve alert")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:risk_update, data}, socket) do
    Logger.debug("Received risk update: #{inspect(data)}")

    socket =
      socket
      |> update_risk_metrics(data)
      |> assign(:last_updated, DateTime.utc_now())

    {:noreply, socket}
  end

  @impl true
  def handle_info({:trading_update, data}, socket) do
    Logger.debug("Received trading update affecting risk: #{inspect(data)}")

    # Recalculate risk metrics when trades occur
    socket =
      socket
      |> assign_risk_data()
      |> assign(:last_updated, DateTime.utc_now())

    {:noreply, socket}
  end

  # Private functions

  defp assign_risk_data(socket) do
    try do
      timeframe = socket.assigns[:selected_timeframe] || "24h"
      exposure_grouping = socket.assigns[:exposure_grouping] || "symbol"

      socket
      |> assign(:risk_metrics, get_risk_metrics())
      |> assign(:risk_limits, get_risk_limits())
      |> assign(:var_data, get_var_data(timeframe))
      |> assign(:exposure_data, get_exposure_data(exposure_grouping))
      |> assign(:correlation_matrix, get_correlation_matrix())
      |> assign(:risk_events, get_active_risk_events())
      |> assign(:risk_health, calculate_risk_health())
    rescue
      error ->
        Logger.error("Error loading risk data: #{inspect(error)}")
        assign_fallback_risk_data(socket)
    end
  end

  defp load_risk_data_for_timeframe(socket, timeframe) do
    var_data = get_var_data(timeframe)
    correlation_matrix = get_correlation_matrix(timeframe)

    socket
    |> assign(:var_data, var_data)
    |> assign(:correlation_matrix, correlation_matrix)
  end

  defp load_exposure_data(socket, grouping) do
    exposure_data = get_exposure_data(grouping)
    assign(socket, :exposure_data, exposure_data)
  end

  defp get_risk_metrics() do
    %{
      total_exposure: Decimal.new("245780.50"),
      var_1d: Decimal.new("12450.25"),
      var_5d: Decimal.new("28950.75"),
      expected_shortfall: Decimal.new("18650.30"),
      max_drawdown: Decimal.new("8750.00"),
      sharpe_ratio: 1.25,
      sortino_ratio: 1.67,
      beta: 0.95,
      volatility: 0.145,
      correlation_with_market: 0.72,
      stress_test_loss: Decimal.new("45000.00")
    }
  end

  defp get_risk_limits() do
    %{
      max_exposure: %{
        limit: Decimal.new("500000.00"),
        current: Decimal.new("245780.50"),
        utilization: 0.49
      },
      var_1d_limit: %{
        limit: Decimal.new("25000.00"),
        current: Decimal.new("12450.25"),
        utilization: 0.50
      },
      max_drawdown_limit: %{
        limit: Decimal.new("20000.00"),
        current: Decimal.new("8750.00"),
        utilization: 0.44
      },
      concentration_limit: %{
        limit: 0.25,
        current: 0.18,
        utilization: 0.72
      }
    }
  end

  defp get_var_data(timeframe) do
    # Mock VaR data based on timeframe
    base_multiplier =
      case timeframe do
        "1d" -> 1.0
        "5d" -> 2.5
        "30d" -> 6.0
        _ -> 1.0
      end

    %{
      timeframe: timeframe,
      var_95: Decimal.new("#{12450 * base_multiplier}"),
      var_99: Decimal.new("#{18750 * base_multiplier}"),
      expected_shortfall: Decimal.new("#{22350 * base_multiplier}"),
      confidence_interval: [
        Decimal.new("#{10200 * base_multiplier}"),
        Decimal.new("#{15800 * base_multiplier}")
      ],
      backtest_exceptions: :rand.uniform(5),
      model_accuracy: 0.89 + :rand.uniform() * 0.1
    }
  end

  defp get_exposure_data(grouping) do
    case grouping do
      "symbol" ->
        [
          %{name: "BTC-USD", exposure: Decimal.new("125000.00"), percentage: 50.8},
          %{name: "ETH-USD", exposure: Decimal.new("75000.00"), percentage: 30.5},
          %{name: "ADA-USD", exposure: Decimal.new("30000.00"), percentage: 12.2},
          %{name: "SOL-USD", exposure: Decimal.new("15780.50"), percentage: 6.4}
        ]

      "agent" ->
        [
          %{name: "Alpha Trader", exposure: Decimal.new("98000.00"), percentage: 39.9},
          %{name: "Beta Scalper", exposure: Decimal.new("67000.00"), percentage: 27.3},
          %{name: "Gamma Swing", exposure: Decimal.new("55780.50"), percentage: 22.7},
          %{name: "Delta Arbitrage", exposure: Decimal.new("25000.00"), percentage: 10.2}
        ]

      "strategy" ->
        [
          %{name: "Momentum", exposure: Decimal.new("110000.00"), percentage: 44.8},
          %{name: "Mean Reversion", exposure: Decimal.new("85000.00"), percentage: 34.6},
          %{name: "Arbitrage", exposure: Decimal.new("35780.50"), percentage: 14.6},
          %{name: "Scalping", exposure: Decimal.new("15000.00"), percentage: 6.1}
        ]

      _ ->
        []
    end
  end

  defp get_correlation_matrix(timeframe \\ "30d") do
    # Mock correlation matrix
    symbols = ["BTC-USD", "ETH-USD", "ADA-USD", "SOL-USD"]

    matrix =
      for i <- 0..(length(symbols) - 1) do
        for j <- 0..(length(symbols) - 1) do
          cond do
            i == j -> 1.0
            # Random correlation 0.1-0.9
            i > j -> :rand.uniform() * 0.8 + 0.1
            # Will be filled by symmetry
            true -> nil
          end
        end
      end

    # Make matrix symmetric
    symmetric_matrix =
      for {row, i} <- Enum.with_index(matrix) do
        for {val, j} <- Enum.with_index(row) do
          if val == nil do
            Enum.at(Enum.at(matrix, j), i)
          else
            val
          end
        end
      end

    %{
      symbols: symbols,
      matrix: symmetric_matrix,
      timeframe: timeframe,
      high_correlations: [
        %{pair: "BTC-USD / ETH-USD", correlation: 0.87},
        %{pair: "ADA-USD / SOL-USD", correlation: 0.75}
      ]
    }
  end

  defp get_active_risk_events() do
    [
      %{
        id: "risk_001",
        type: "position_limit_exceeded",
        severity: :high,
        message: "BTC-USD position exceeds 50% concentration limit",
        detected_at: DateTime.utc_now() |> DateTime.add(-1800, :second),
        agent_name: "Alpha Trader",
        current_value: "52.3%",
        threshold: "50.0%"
      },
      %{
        id: "risk_002",
        type: "var_threshold_breach",
        severity: :medium,
        message: "Daily VaR exceeds warning threshold",
        detected_at: DateTime.utc_now() |> DateTime.add(-3600, :second),
        agent_name: "Beta Scalper",
        current_value: "$15,250",
        threshold: "$15,000"
      },
      %{
        id: "risk_003",
        type: "correlation_spike",
        severity: :low,
        message: "High correlation detected between BTC and ETH",
        detected_at: DateTime.utc_now() |> DateTime.add(-7200, :second),
        agent_name: "System",
        current_value: "0.89",
        threshold: "0.85"
      }
    ]
  end

  defp calculate_risk_health() do
    # Simplified risk health calculation
    # Would be calculated from actual metrics
    risk_score = 0.75

    cond do
      risk_score > 0.8 -> :good
      risk_score > 0.6 -> :fair
      risk_score > 0.4 -> :poor
      true -> :critical
    end
  end

  defp update_risk_metrics(socket, _data) do
    # Update risk metrics from real-time data
    # For now, just refresh all data
    assign_risk_data(socket)
  end

  defp assign_fallback_risk_data(socket) do
    socket
    |> assign(:risk_metrics, %{})
    |> assign(:risk_limits, %{})
    |> assign(:var_data, %{})
    |> assign(:exposure_data, [])
    |> assign(:correlation_matrix, %{symbols: [], matrix: []})
    |> assign(:risk_events, [])
    |> assign(:risk_health, :unknown)
  end
end
