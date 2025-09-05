defmodule TradingSwarmWeb.API.RehoboamController do
  @moduledoc """
  JSON API controller for Rehoboam AI surveillance system.

  Provides REST endpoints for:
  - Market predictions and destiny calculations
  - Agent behavioral analysis
  - Surveillance data access
  - Real-time omniscience metrics
  """

  use TradingSwarmWeb, :controller
  require Logger

  alias TradingSwarm.Rehoboam

  def status(conn, _params) do
    Logger.info("API: Getting Rehoboam omniscience status")

    try do
      omniscience_status = Rehoboam.get_omniscience_status()

      conn
      |> put_resp_content_type("application/json")
      |> json(%{
        success: true,
        data: omniscience_status,
        timestamp: DateTime.utc_now()
      })
    rescue
      error ->
        Logger.error("API: Error getting Rehoboam status: #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json")
        |> put_status(:service_unavailable)
        |> json(%{
          success: false,
          error: "Rehoboam offline",
          message: "The surveillance system is currently unavailable",
          data: %{system_status: :offline, omniscience_level: 0.0}
        })
    end
  end

  def predictions(conn, _params) do
    Logger.info("API: Getting destiny predictions")

    try do
      destiny_predictions = Rehoboam.get_destiny_predictions()

      conn
      |> put_resp_content_type("application/json")
      |> json(%{
        success: true,
        data: %{
          predictions: destiny_predictions,
          generated_at: DateTime.utc_now(),
          confidence_level: Map.get(destiny_predictions, :prediction_confidence, 0.0)
        },
        timestamp: DateTime.utc_now()
      })
    rescue
      error ->
        Logger.error("API: Error getting predictions: #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json")
        |> put_status(:service_unavailable)
        |> json(%{
          success: false,
          error: "Prediction system unavailable",
          message: "Unable to generate destiny predictions at this time"
        })
    end
  end

  def analyze_market(conn, _params) do
    Logger.info("API: Analyzing market conditions")

    try do
      market_analysis = Rehoboam.analyze_market_conditions()

      conn
      |> put_resp_content_type("application/json")
      |> json(%{
        success: true,
        data: market_analysis,
        timestamp: DateTime.utc_now()
      })
    rescue
      error ->
        Logger.error("API: Error analyzing market: #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json")
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Market analysis failed",
          message: "Unable to analyze current market conditions"
        })
    end
  end

  def agent_loop(conn, %{"agent_id" => agent_id}) do
    Logger.info("API: Getting behavioral loop for agent #{agent_id}")

    try do
      agent_loop = Rehoboam.get_agent_loop(agent_id)

      conn
      |> put_resp_content_type("application/json")
      |> json(%{
        success: true,
        data: %{
          agent_id: agent_id,
          behavioral_loop: agent_loop
        },
        timestamp: DateTime.utc_now()
      })
    rescue
      error ->
        Logger.error("API: Error getting agent loop for #{agent_id}: #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json")
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to get agent loop",
          message: "Unable to analyze agent behavioral patterns"
        })
    end
  end

  def predict_behavior(conn, %{"agent_id" => agent_id} = params) do
    Logger.info("API: Predicting behavior for agent #{agent_id}")

    try do
      # Get market conditions from params or use defaults
      market_conditions = Map.get(params, "market_conditions", get_default_market_conditions())

      behavior_prediction = Rehoboam.predict_agent_behavior(agent_id, market_conditions)

      conn
      |> put_resp_content_type("application/json")
      |> json(%{
        success: true,
        data: %{
          agent_id: agent_id,
          prediction: behavior_prediction,
          market_conditions: market_conditions,
          predicted_at: DateTime.utc_now()
        },
        timestamp: DateTime.utc_now()
      })
    rescue
      error ->
        Logger.error("API: Error predicting behavior for agent #{agent_id}: #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json")
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Behavior prediction failed",
          message: "Unable to predict agent behavior patterns"
        })
    end
  end

  def detect_divergence(conn, %{"agent_id" => agent_id} = params) do
    Logger.info("API: Detecting divergence for agent #{agent_id}")

    try do
      # Get recent behavior from params or fetch it
      recent_behavior =
        Map.get(params, "recent_behavior", get_recent_behavior_for_agent(agent_id))

      divergence_analysis = Rehoboam.detect_divergence(agent_id, recent_behavior)

      conn
      |> put_resp_content_type("application/json")
      |> json(%{
        success: true,
        data: %{
          agent_id: agent_id,
          divergence_analysis: divergence_analysis,
          analyzed_at: DateTime.utc_now()
        },
        timestamp: DateTime.utc_now()
      })
    rescue
      error ->
        Logger.error("API: Error detecting divergence for agent #{agent_id}: #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json")
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Divergence detection failed",
          message: "Unable to analyze behavioral divergence"
        })
    end
  end

  def intervention_strategy(conn, %{"agent_id" => agent_id, "divergence_type" => divergence_type}) do
    Logger.info(
      "API: Calculating intervention for agent #{agent_id}, divergence: #{divergence_type}"
    )

    try do
      intervention = Rehoboam.calculate_intervention_strategy(agent_id, divergence_type)

      conn
      |> put_resp_content_type("application/json")
      |> json(%{
        success: true,
        data: %{
          agent_id: agent_id,
          divergence_type: divergence_type,
          intervention_strategy: intervention,
          calculated_at: DateTime.utc_now()
        },
        timestamp: DateTime.utc_now()
      })
    rescue
      error ->
        Logger.error(
          "API: Error calculating intervention for agent #{agent_id}: #{inspect(error)}"
        )

        conn
        |> put_resp_content_type("application/json")
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Intervention calculation failed",
          message: "Unable to calculate intervention strategy"
        })
    end
  end

  def market_destiny(conn, params) do
    Logger.info("API: Forecasting market destiny")

    timeframe = params["timeframe"] || "24h"

    try do
      # Get market data from params or fetch current data
      market_data = Map.get(params, "market_data", get_current_market_data())

      destiny_forecast = Rehoboam.forecast_market_destiny(timeframe, market_data)

      conn
      |> put_resp_content_type("application/json")
      |> json(%{
        success: true,
        data: %{
          timeframe: timeframe,
          market_destiny: destiny_forecast,
          market_data: market_data,
          forecasted_at: DateTime.utc_now()
        },
        timestamp: DateTime.utc_now()
      })
    rescue
      error ->
        Logger.error("API: Error forecasting market destiny: #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json")
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Market destiny forecast failed",
          message: "The future remains uncertain"
        })
    end
  end

  def surveillance_data(conn, _params) do
    Logger.info("API: Getting surveillance data")

    try do
      omniscience_status = Rehoboam.get_omniscience_status()

      surveillance_data = %{
        system_status: omniscience_status.system_status,
        omniscience_level: omniscience_status.omniscience_level,
        surveillance_streams: omniscience_status.surveillance_streams,
        monitored_agents: omniscience_status.monitored_agents,
        divergence_alerts: omniscience_status.divergence_alerts,
        interventions_executed: omniscience_status.interventions_executed,
        control_metrics: omniscience_status.control_metrics,
        last_prophecy: omniscience_status.last_prophecy,
        uptime: omniscience_status.uptime
      }

      conn
      |> put_resp_content_type("application/json")
      |> json(%{
        success: true,
        data: surveillance_data,
        timestamp: DateTime.utc_now()
      })
    rescue
      error ->
        Logger.error("API: Error getting surveillance data: #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json")
        |> put_status(:service_unavailable)
        |> json(%{
          success: false,
          error: "Surveillance system unavailable",
          message: "Unable to access surveillance data at this time"
        })
    end
  end

  def submit_behavior(conn, %{"behavior_data" => behavior_data}) do
    Logger.info("API: Submitting agent behavior data")

    try do
      # Submit behavior data to Rehoboam for analysis
      Rehoboam.submit_agent_behavior(behavior_data)

      conn
      |> put_resp_content_type("application/json")
      |> json(%{
        success: true,
        message: "Behavior data submitted successfully",
        data: %{
          agent_id: behavior_data["agent_id"],
          submitted_at: DateTime.utc_now()
        },
        timestamp: DateTime.utc_now()
      })
    rescue
      error ->
        Logger.error("API: Error submitting behavior data: #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json")
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          error: "Behavior submission failed",
          message: "Unable to process behavior data"
        })
    end
  end

  def register_surveillance_stream(conn, %{"stream_id" => stream_id, "config" => stream_config}) do
    Logger.info("API: Registering surveillance stream #{stream_id}")

    try do
      Rehoboam.register_surveillance_stream(stream_id, stream_config)

      conn
      |> put_resp_content_type("application/json")
      |> json(%{
        success: true,
        message: "Surveillance stream registered successfully",
        data: %{
          stream_id: stream_id,
          config: stream_config,
          registered_at: DateTime.utc_now()
        },
        timestamp: DateTime.utc_now()
      })
    rescue
      error ->
        Logger.error("API: Error registering surveillance stream: #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json")
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          error: "Stream registration failed",
          message: "Unable to register surveillance stream"
        })
    end
  end

  def behavioral_analysis(conn, _params) do
    Logger.info("API: Getting behavioral analysis")

    try do
      # This would get comprehensive behavioral analysis
      # For now, returning mock analysis structure
      analysis = %{
        total_agents_analyzed: 0,
        behavioral_patterns_detected: [],
        loop_integrity_summary: %{
          stable: 0,
          degrading: 0,
          unstable: 0,
          breaking: 0
        },
        predictability_distribution: %{
          high: 0,
          medium: 0,
          low: 0
        },
        divergence_trends: [],
        intervention_recommendations: []
      }

      conn
      |> put_resp_content_type("application/json")
      |> json(%{
        success: true,
        data: analysis,
        timestamp: DateTime.utc_now()
      })
    rescue
      error ->
        Logger.error("API: Error getting behavioral analysis: #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json")
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Behavioral analysis failed",
          message: "Unable to analyze behavioral patterns"
        })
    end
  end

  # Private functions

  defp get_default_market_conditions() do
    %{
      volatility: :moderate,
      trend: :sideways,
      sentiment: :neutral,
      volume: :normal,
      timestamp: DateTime.utc_now()
    }
  end

  defp get_recent_behavior_for_agent(agent_id) do
    # This would fetch recent behavior data for the agent
    # For now, returning mock data
    %{
      agent_id: agent_id,
      recent_decisions: [],
      behavioral_patterns: [],
      loop_adherence: 0.0,
      last_activity: DateTime.utc_now()
    }
  end

  defp get_current_market_data() do
    # This would fetch current market data
    # For now, returning mock data
    %{
      symbols: ["BTC-USD", "ETH-USD", "ADA-USD"],
      prices: %{
        "BTC-USD" => Decimal.new("50000.00"),
        "ETH-USD" => Decimal.new("3000.00"),
        "ADA-USD" => Decimal.new("1.50")
      },
      volumes: %{},
      timestamp: DateTime.utc_now()
    }
  end
end
