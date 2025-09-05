defmodule TradingSwarmWeb.DashboardLive do
  @moduledoc """
  Main dashboard LiveView showing real-time trading system statistics.

  Features:
  - Real-time updates via PubSub
  - Active agents count and status
  - Total P&L and risk exposure
  - Recent trades feed
  - System health metrics
  """

  use TradingSwarmWeb, :live_view
  require Logger

  alias TradingSwarm.{Trading, Risk}
  alias TradingSwarm.Rehoboam

  import TradingSwarmWeb.ChartComponents
  import TradingSwarmWeb.TradingComponents
  import TradingSwarmWeb.DashboardComponents

  @impl true
  def mount(_params, _session, socket) do
    Logger.info("DashboardLive mounted")

    # Subscribe to real-time updates
    if connected?(socket) do
      Phoenix.PubSub.subscribe(TradingSwarm.PubSub, "trading_updates")
      Phoenix.PubSub.subscribe(TradingSwarm.PubSub, "agent_updates")
      Phoenix.PubSub.subscribe(TradingSwarm.PubSub, "risk_updates")
    end

    # Load initial data
    socket =
      socket
      |> assign_dashboard_metrics()
      |> assign(:loading, false)
      |> assign(:last_updated, DateTime.utc_now())
      |> assign(:performance_data, [])

    {:ok, socket}
  end

  @impl true
  def handle_info({:trading_update, data}, socket) do
    Logger.debug("Received trading update: #{inspect(data)}")

    socket =
      socket
      |> update_trading_metrics(data)
      |> assign(:last_updated, DateTime.utc_now())

    {:noreply, socket}
  end

  @impl true
  def handle_info({:agent_update, data}, socket) do
    Logger.debug("Received agent update: #{inspect(data)}")

    socket =
      socket
      |> update_agent_metrics(data)
      |> assign(:last_updated, DateTime.utc_now())

    {:noreply, socket}
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
  def handle_event("refresh_dashboard", _params, socket) do
    Logger.info("Manual dashboard refresh requested")

    socket =
      socket
      |> assign_dashboard_metrics()
      |> assign(:last_updated, DateTime.utc_now())

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_agent", %{"agent_id" => agent_id}, socket) do
    case Trading.toggle_agent_status(agent_id) do
      {:ok, _agent} ->
        socket =
          socket
          |> put_flash(:info, "Agent status toggled successfully")
          |> assign_dashboard_metrics()

        {:noreply, socket}

      {:error, reason} ->
        socket = put_flash(socket, :error, "Failed to toggle agent: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  # Private functions

  defp assign_dashboard_metrics(socket) do
    try do
      # Get agent statistics
      agent_stats = get_agent_statistics()

      # Get trading statistics
      trading_stats = get_trading_statistics()

      # Get risk metrics
      risk_stats = get_risk_statistics()

      # Get recent trades
      recent_trades = get_recent_trades()

      # Get Rehoboam status
      rehoboam_status = get_rehoboam_status()

      socket
      |> assign(:agent_count, agent_stats.total_count)
      |> assign(:active_agents, agent_stats.active_count)
      |> assign(:idle_agents, agent_stats.idle_count)
      |> assign(:error_agents, agent_stats.error_count)
      |> assign(:total_pnl, trading_stats.total_pnl)
      |> assign(:daily_pnl, trading_stats.daily_pnl)
      |> assign(:total_trades, trading_stats.total_trades)
      |> assign(:winning_trades, trading_stats.winning_trades)
      |> assign(:win_rate, trading_stats.win_rate)
      |> assign(:risk_exposure, risk_stats.total_exposure)
      |> assign(:risk_alerts, risk_stats.active_alerts)
      |> assign(:recent_trades, recent_trades)
      |> assign(:rehoboam_status, rehoboam_status)
      |> assign(:system_health, calculate_system_health(agent_stats, risk_stats))
    rescue
      error ->
        Logger.error("Error loading dashboard metrics: #{inspect(error)}")
        assign_fallback_metrics(socket)
    end
  end

  defp get_agent_statistics() do
    # This would query the database - using mock data for now
    %{
      total_count: 0,
      active_count: 0,
      idle_count: 0,
      error_count: 0
    }
  end

  defp get_trading_statistics() do
    # This would query trades from database - using mock data for now
    %{
      total_pnl: Decimal.new("0.00"),
      daily_pnl: Decimal.new("0.00"),
      total_trades: 0,
      winning_trades: 0,
      win_rate: 0.0
    }
  end

  defp get_risk_statistics() do
    # This would query risk events - using mock data for now
    %{
      total_exposure: Decimal.new("0.00"),
      active_alerts: 0,
      critical_alerts: 0
    }
  end

  defp get_recent_trades() do
    # This would query recent trades - using empty list for now
    []
  end

  defp get_rehoboam_status() do
    case Rehoboam.get_omniscience_status() do
      status when is_map(status) ->
        status

      _ ->
        %{
          system_status: :unknown,
          omniscience_level: 0.0,
          monitored_agents: 0,
          divergence_alerts: 0
        }
    end
  rescue
    _ ->
      %{
        system_status: :offline,
        omniscience_level: 0.0,
        monitored_agents: 0,
        divergence_alerts: 0
      }
  end

  defp calculate_system_health(agent_stats, risk_stats) do
    active_ratio =
      if agent_stats.total_count > 0,
        do: agent_stats.active_count / agent_stats.total_count,
        else: 0.0

    error_ratio =
      if agent_stats.total_count > 0,
        do: agent_stats.error_count / agent_stats.total_count,
        else: 0.0

    risk_factor = if risk_stats.active_alerts > 5, do: 0.5, else: 1.0

    health_score = (active_ratio * 0.6 + (1 - error_ratio) * 0.3 + risk_factor * 0.1) * 100

    cond do
      health_score > 85 -> :excellent
      health_score > 70 -> :good
      health_score > 50 -> :fair
      health_score > 25 -> :poor
      true -> :critical
    end
  end

  defp assign_fallback_metrics(socket) do
    socket
    |> assign(:agent_count, 0)
    |> assign(:active_agents, 0)
    |> assign(:idle_agents, 0)
    |> assign(:error_agents, 0)
    |> assign(:total_pnl, Decimal.new("0.00"))
    |> assign(:daily_pnl, Decimal.new("0.00"))
    |> assign(:total_trades, 0)
    |> assign(:winning_trades, 0)
    |> assign(:win_rate, 0.0)
    |> assign(:risk_exposure, Decimal.new("0.00"))
    |> assign(:risk_alerts, 0)
    |> assign(:recent_trades, [])
    |> assign(:rehoboam_status, %{system_status: :error, omniscience_level: 0.0})
    |> assign(:system_health, :unknown)
  end

  defp update_trading_metrics(socket, data) do
    # Update trading-related assigns based on real-time data
    socket
    |> assign(:total_pnl, Map.get(data, :total_pnl, socket.assigns.total_pnl))
    |> assign(:recent_trades, [data | Enum.take(socket.assigns.recent_trades, 9)])
  end

  defp update_agent_metrics(socket, data) do
    # Update agent-related assigns based on real-time data
    socket
    |> assign(:agent_count, Map.get(data, :total_count, socket.assigns.agent_count))
    |> assign(:active_agents, Map.get(data, :active_count, socket.assigns.active_agents))
  end

  defp update_risk_metrics(socket, data) do
    # Update risk-related assigns based on real-time data
    socket
    |> assign(:risk_exposure, Map.get(data, :total_exposure, socket.assigns.risk_exposure))
    |> assign(:risk_alerts, Map.get(data, :active_alerts, socket.assigns.risk_alerts))
  end
end
