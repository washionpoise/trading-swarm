defmodule TradingSwarmWeb.RehoboamLive.Surveillance do
  @moduledoc """
  Rehoboam AI Surveillance Dashboard LiveView.

  Features:
  - Omnipresent monitoring status display
  - Market destiny prediction timeline
  - Behavioral analysis of trading agents
  - Intervention logs and recommendations
  - Real-time AI insights and alerts
  """

  use TradingSwarmWeb, :live_view
  require Logger

  alias TradingSwarm.Rehoboam

  import TradingSwarmWeb.DashboardComponents
  import TradingSwarmWeb.TradingComponents
  # import TradingSwarmWeb.ChartComponents  # Currently unused

  @impl true
  def mount(_params, _session, socket) do
    Logger.info("RehoboamLive.Surveillance mounted")

    # Subscribe to Rehoboam updates
    if connected?(socket) do
      Phoenix.PubSub.subscribe(TradingSwarm.PubSub, "rehoboam_updates")
      Phoenix.PubSub.subscribe(TradingSwarm.PubSub, "agent_surveillance")
      Phoenix.PubSub.subscribe(TradingSwarm.PubSub, "market_analysis")
    end

    socket =
      socket
      |> assign_surveillance_data()
      |> assign(:loading, false)
      |> assign(:last_updated, DateTime.utc_now())
      |> assign(:selected_agent, nil)
      |> assign(:prediction_timeframe, "1h")
      |> assign(:auto_refresh, true)

    # Schedule periodic updates if auto-refresh is enabled
    if socket.assigns.auto_refresh do
      Process.send_after(self(), :refresh_surveillance, 5000)
    end

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_auto_refresh", _params, socket) do
    new_auto_refresh = !socket.assigns.auto_refresh

    socket = assign(socket, :auto_refresh, new_auto_refresh)

    if new_auto_refresh do
      Process.send_after(self(), :refresh_surveillance, 5000)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh_surveillance", _params, socket) do
    Logger.info("Manual surveillance refresh requested")

    socket =
      socket
      |> assign(:loading, true)
      |> assign_surveillance_data()
      |> assign(:last_updated, DateTime.utc_now())
      |> assign(:loading, false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_agent", %{"agent_id" => agent_id}, socket) do
    socket =
      socket
      |> assign(:selected_agent, agent_id)
      |> load_agent_analysis(agent_id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_prediction_timeframe", %{"timeframe" => timeframe}, socket) do
    socket =
      socket
      |> assign(:prediction_timeframe, timeframe)
      |> load_market_predictions(timeframe)

    {:noreply, socket}
  end

  @impl true
  def handle_event("request_intervention", %{"agent_id" => agent_id}, socket) do
    Logger.info("Intervention requested for agent #{agent_id}")

    case Rehoboam.request_intervention(agent_id) do
      {:ok, intervention} ->
        socket =
          socket
          |> put_flash(:info, "Intervention strategy generated for agent #{agent_id}")
          |> assign_surveillance_data()

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Failed to request intervention: #{inspect(reason)}")
        socket = put_flash(socket, :error, "Failed to generate intervention strategy")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:refresh_surveillance, socket) do
    if socket.assigns.auto_refresh do
      socket =
        socket
        |> assign_surveillance_data()
        |> assign(:last_updated, DateTime.utc_now())

      # Schedule next refresh
      Process.send_after(self(), :refresh_surveillance, 5000)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:rehoboam_update, data}, socket) do
    Logger.debug("Received Rehoboam update: #{inspect(data)}")

    socket =
      socket
      |> assign_surveillance_data()
      |> assign(:last_updated, DateTime.utc_now())

    {:noreply, socket}
  end

  @impl true
  def handle_info({:agent_surveillance, data}, socket) do
    Logger.debug("Received agent surveillance update: #{inspect(data)}")

    socket =
      socket
      |> update_agent_surveillance(data)
      |> assign(:last_updated, DateTime.utc_now())

    {:noreply, socket}
  end

  @impl true
  def handle_info({:market_analysis, data}, socket) do
    Logger.debug("Received market analysis update: #{inspect(data)}")

    socket =
      socket
      |> update_market_analysis(data)
      |> assign(:last_updated, DateTime.utc_now())

    {:noreply, socket}
  end

  # Private functions

  defp assign_surveillance_data(socket) do
    try do
      # Get Rehoboam status and surveillance data
      omniscience_status = get_omniscience_status()
      behavioral_profiles = get_behavioral_profiles()
      market_predictions = get_market_predictions(socket.assigns[:prediction_timeframe] || "1h")
      intervention_logs = get_intervention_logs()
      surveillance_metrics = get_surveillance_metrics()
      agent_divergences = get_agent_divergences()

      socket
      |> assign(:omniscience_status, omniscience_status)
      |> assign(:behavioral_profiles, behavioral_profiles)
      |> assign(:market_predictions, market_predictions)
      |> assign(:intervention_logs, intervention_logs)
      |> assign(:surveillance_metrics, surveillance_metrics)
      |> assign(:agent_divergences, agent_divergences)
      |> assign(:predictive_accuracy, calculate_predictive_accuracy(market_predictions))
    rescue
      error ->
        Logger.error("Error loading surveillance data: #{inspect(error)}")
        assign_fallback_surveillance_data(socket)
    end
  end

  defp get_omniscience_status() do
    case Rehoboam.get_omniscience_status() do
      status when is_map(status) ->
        status

      _ ->
        %{
          system_status: :active,
          omniscience_level: 0.87,
          monitored_agents: 4,
          active_predictions: 12,
          divergence_alerts: 2,
          last_analysis: DateTime.utc_now() |> DateTime.add(-300, :second),
          processing_capacity: 0.75,
          prediction_accuracy: 0.82
        }
    end
  end

  defp get_behavioral_profiles() do
    [
      %{
        agent_id: "agent_001",
        agent_name: "Alpha Trader",
        risk_profile: :moderate,
        behavioral_score: 0.85,
        deviation_alerts: 1,
        last_anomaly: DateTime.utc_now() |> DateTime.add(-1800, :second),
        confidence: 0.92,
        predicted_actions: ["BUY_EUR_USD", "SELL_GBP_JPY"]
      },
      %{
        agent_id: "agent_002",
        agent_name: "Beta Scalper",
        risk_profile: :aggressive,
        behavioral_score: 0.73,
        deviation_alerts: 3,
        last_anomaly: DateTime.utc_now() |> DateTime.add(-600, :second),
        confidence: 0.78,
        predicted_actions: ["SCALP_BTC_USD"]
      },
      %{
        agent_id: "agent_003",
        agent_name: "Gamma Swing",
        risk_profile: :conservative,
        behavioral_score: 0.91,
        deviation_alerts: 0,
        last_anomaly: nil,
        confidence: 0.95,
        predicted_actions: ["HOLD_POSITIONS"]
      }
    ]
  end

  defp get_market_predictions(timeframe) do
    now = DateTime.utc_now()

    case timeframe do
      "1h" ->
        [
          %{
            timestamp: now,
            market_sentiment: 0.65,
            volatility_forecast: 0.42,
            key_events: ["EUR_ECB_ANNOUNCEMENT"],
            confidence: 0.88
          },
          %{
            timestamp: DateTime.add(now, 1800, :second),
            market_sentiment: 0.72,
            volatility_forecast: 0.38,
            key_events: [],
            confidence: 0.84
          },
          %{
            timestamp: DateTime.add(now, 3600, :second),
            market_sentiment: 0.58,
            volatility_forecast: 0.55,
            key_events: ["USD_EMPLOYMENT_DATA"],
            confidence: 0.79
          }
        ]

      "4h" ->
        [
          %{
            timestamp: now,
            market_sentiment: 0.61,
            volatility_forecast: 0.48,
            key_events: ["MARKET_OPEN_LONDON"],
            confidence: 0.86
          },
          %{
            timestamp: DateTime.add(now, 14_400, :second),
            market_sentiment: 0.69,
            volatility_forecast: 0.35,
            key_events: ["US_MARKET_OPEN"],
            confidence: 0.82
          }
        ]

      _ ->
        []
    end
  end

  defp get_intervention_logs() do
    [
      %{
        id: "int_001",
        timestamp: DateTime.utc_now() |> DateTime.add(-3600, :second),
        agent_id: "agent_002",
        agent_name: "Beta Scalper",
        intervention_type: :risk_reduction,
        reason: "Excessive position size detected",
        action_taken: "Reduced maximum position size by 50%",
        effectiveness: 0.85,
        status: :completed
      },
      %{
        id: "int_002",
        timestamp: DateTime.utc_now() |> DateTime.add(-7200, :second),
        agent_id: "agent_001",
        agent_name: "Alpha Trader",
        intervention_type: :strategy_adjustment,
        reason: "Behavioral deviation from expected pattern",
        action_taken: "Adjusted momentum threshold parameters",
        effectiveness: 0.92,
        status: :completed
      },
      %{
        id: "int_003",
        timestamp: DateTime.utc_now() |> DateTime.add(-300, :second),
        agent_id: "agent_004",
        agent_name: "Delta Arbitrage",
        intervention_type: :emergency_stop,
        reason: "Critical system error in price feed",
        action_taken: "Halted all trading operations",
        effectiveness: nil,
        status: :in_progress
      }
    ]
  end

  defp get_surveillance_metrics() do
    %{
      # hours
      total_monitoring_time: 24.5,
      predictions_made: 847,
      interventions_executed: 23,
      accuracy_rate: 0.847,
      # seconds
      avg_response_time: 0.23,
      system_load: 0.68,
      memory_usage: 0.45,
      prediction_queue_size: 3
    }
  end

  defp get_agent_divergences() do
    [
      %{
        agent_id: "agent_002",
        agent_name: "Beta Scalper",
        divergence_type: :behavioral,
        severity: :high,
        description: "Agent showing unusual risk-taking behavior",
        detected_at: DateTime.utc_now() |> DateTime.add(-1200, :second),
        confidence: 0.89
      },
      %{
        agent_id: "agent_004",
        agent_name: "Delta Arbitrage",
        divergence_type: :performance,
        severity: :critical,
        description: "Significant performance degradation detected",
        detected_at: DateTime.utc_now() |> DateTime.add(-600, :second),
        confidence: 0.95
      }
    ]
  end

  defp calculate_predictive_accuracy(predictions) do
    if length(predictions) > 0 do
      total_confidence =
        predictions
        |> Enum.map(& &1.confidence)
        |> Enum.sum()

      total_confidence / length(predictions)
    else
      0.0
    end
  end

  defp load_agent_analysis(socket, agent_id) do
    # Load detailed analysis for specific agent
    agent_analysis = %{
      behavioral_timeline: [],
      risk_factors: [],
      performance_metrics: %{},
      recommendations: []
    }

    assign(socket, :selected_agent_analysis, agent_analysis)
  end

  defp load_market_predictions(socket, timeframe) do
    predictions = get_market_predictions(timeframe)
    assign(socket, :market_predictions, predictions)
  end

  defp assign_fallback_surveillance_data(socket) do
    socket
    |> assign(:omniscience_status, %{system_status: :offline, omniscience_level: 0.0})
    |> assign(:behavioral_profiles, [])
    |> assign(:market_predictions, [])
    |> assign(:intervention_logs, [])
    |> assign(:surveillance_metrics, %{})
    |> assign(:agent_divergences, [])
    |> assign(:predictive_accuracy, 0.0)
  end

  defp update_agent_surveillance(socket, _data) do
    # Update agent surveillance data from real-time updates
    socket
  end

  defp update_market_analysis(socket, _data) do
    # Update market analysis from real-time updates
    socket
  end
end
