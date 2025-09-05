defmodule TradingSwarmWeb.API.RiskController do
  @moduledoc """
  JSON API controller for risk management data.

  Provides REST endpoints for:
  - Risk metrics and exposure data
  - Risk events and alerts
  - Correlation analysis
  - Risk limits management
  - Real-time risk monitoring
  """

  use TradingSwarmWeb, :controller
  require Logger

  alias TradingSwarm.{Risk, Repo}
  alias TradingSwarm.Risk.RiskEvent

  def metrics(conn, _params) do
    Logger.info("API: Getting risk metrics")

    try do
      risk_metrics = get_current_risk_metrics()

      conn
      |> put_resp_content_type("application/json")
      |> json(%{
        success: true,
        data: risk_metrics,
        timestamp: DateTime.utc_now()
      })
    rescue
      error ->
        Logger.error("API: Error getting risk metrics: #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json")
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to get risk metrics",
          message: "Internal server error occurred"
        })
    end
  end

  def exposure(conn, params) do
    Logger.info("API: Getting exposure analysis")

    group_by = params["group_by"] || "symbol"

    try do
      exposure_data = get_exposure_analysis(group_by)

      conn
      |> put_resp_content_type("application/json")
      |> json(%{
        success: true,
        data: %{
          group_by: group_by,
          exposure_breakdown: exposure_data.breakdown,
          concentration_risk: exposure_data.concentration_risk,
          limits: exposure_data.limits,
          utilization: exposure_data.utilization
        },
        timestamp: DateTime.utc_now()
      })
    rescue
      error ->
        Logger.error("API: Error getting exposure analysis: #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json")
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to get exposure analysis",
          message: "Internal server error occurred"
        })
    end
  end

  def correlation(conn, params) do
    Logger.info("API: Getting correlation analysis")

    timeframe = params["timeframe"] || "30d"

    try do
      correlation_analysis = get_correlation_analysis(timeframe)

      conn
      |> put_resp_content_type("application/json")
      |> json(%{
        success: true,
        data: %{
          timeframe: timeframe,
          correlation_matrix: correlation_analysis.matrix,
          high_correlations: correlation_analysis.high_correlations,
          correlation_risk: correlation_analysis.risk_score,
          diversification_metrics: correlation_analysis.diversification
        },
        timestamp: DateTime.utc_now()
      })
    rescue
      error ->
        Logger.error("API: Error getting correlation analysis: #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json")
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to get correlation analysis",
          message: "Internal server error occurred"
        })
    end
  end

  def events(conn, params) do
    Logger.info("API: Getting risk events")

    try do
      # Parse query parameters
      page = String.to_integer(params["page"] || "1")
      per_page = min(String.to_integer(params["per_page"] || "25"), 100)
      severity_filter = params["severity"]
      resolved_filter = params["resolved"]

      # Build query
      events_query = build_risk_events_query(severity_filter, resolved_filter)

      # Get paginated results
      risk_events =
        events_query
        |> Repo.paginate(page: page, page_size: per_page)

      # Format events
      events_data = format_risk_events_response(risk_events.entries)

      # Get summary
      events_summary = get_risk_events_summary()

      conn
      |> put_resp_content_type("application/json")
      |> json(%{
        success: true,
        data: events_data,
        summary: events_summary,
        pagination: %{
          current_page: page,
          per_page: per_page,
          total_entries: risk_events.total_entries,
          total_pages: risk_events.total_pages
        },
        timestamp: DateTime.utc_now()
      })
    rescue
      error ->
        Logger.error("API: Error getting risk events: #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json")
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to get risk events",
          message: "Internal server error occurred"
        })
    end
  end

  def active_events(conn, _params) do
    Logger.info("API: Getting active risk events")

    try do
      active_events = get_active_risk_events()
      critical_events = Enum.filter(active_events, &(&1.severity == "critical"))

      conn
      |> put_resp_content_type("application/json")
      |> json(%{
        success: true,
        data: %{
          active_events: format_risk_events_response(active_events),
          critical_events: format_risk_events_response(critical_events),
          total_active: length(active_events),
          total_critical: length(critical_events)
        },
        timestamp: DateTime.utc_now()
      })
    rescue
      error ->
        Logger.error("API: Error getting active risk events: #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json")
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to get active risk events",
          message: "Internal server error occurred"
        })
    end
  end

  def limits(conn, _params) do
    Logger.info("API: Getting risk limits")

    try do
      risk_limits = get_current_risk_limits()
      limit_utilization = calculate_limit_utilization()
      violations = get_current_violations()

      conn
      |> put_resp_content_type("application/json")
      |> json(%{
        success: true,
        data: %{
          limits: risk_limits,
          utilization: limit_utilization,
          violations: violations,
          health_status: calculate_limits_health(limit_utilization, violations)
        },
        timestamp: DateTime.utc_now()
      })
    rescue
      error ->
        Logger.error("API: Error getting risk limits: #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json")
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to get risk limits",
          message: "Internal server error occurred"
        })
    end
  end

  def update_limits(conn, %{"limits" => limits_params}) do
    Logger.info("API: Updating risk limits")

    try do
      case Risk.update_limits(limits_params) do
        {:ok, updated_limits} ->
          Logger.info("API: Successfully updated risk limits")

          # Publish limits update
          Phoenix.PubSub.broadcast(
            TradingSwarm.PubSub,
            "risk_updates",
            {:risk_limits_updated, updated_limits}
          )

          conn
          |> put_resp_content_type("application/json")
          |> json(%{
            success: true,
            data: updated_limits,
            message: "Risk limits updated successfully",
            timestamp: DateTime.utc_now()
          })

          # Note: Currently Risk.update_limits only returns {:ok, _}
          # This clause is kept for future error handling if needed
          # {:error, reason} ->
          #   Logger.warning("API: Failed to update risk limits: #{inspect(reason)}")
          #   conn
          #   |> put_resp_content_type("application/json") 
          #   |> put_status(:unprocessable_entity)
          #   |> json(%{success: false, error: "Limits update failed", message: inspect(reason)})
      end
    rescue
      error ->
        Logger.error("API: Error updating risk limits: #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json")
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to update risk limits",
          message: "Internal server error occurred"
        })
    end
  end

  def resolve_event(conn, %{"id" => event_id}) do
    Logger.info("API: Resolving risk event #{event_id}")

    try do
      risk_event = Repo.get!(RiskEvent, event_id)

      case Risk.resolve_event(risk_event) do
        {:ok, resolved_event} ->
          Logger.info("API: Successfully resolved risk event #{event_id}")

          # Publish resolution event
          Phoenix.PubSub.broadcast(
            TradingSwarm.PubSub,
            "risk_updates",
            {:risk_event_resolved, resolved_event}
          )

          event_data = format_risk_event_response(resolved_event)

          conn
          |> put_resp_content_type("application/json")
          |> json(%{
            success: true,
            data: event_data,
            message: "Risk event resolved successfully",
            timestamp: DateTime.utc_now()
          })

        {:error, changeset} ->
          Logger.warning(
            "API: Failed to resolve risk event #{event_id}: #{inspect(changeset.errors)}"
          )

          conn
          |> put_resp_content_type("application/json")
          |> put_status(:unprocessable_entity)
          |> json(%{
            success: false,
            error: "Event resolution failed",
            errors: format_changeset_errors(changeset)
          })
      end
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_resp_content_type("application/json")
        |> put_status(:not_found)
        |> json(%{
          success: false,
          error: "Risk event not found",
          message: "No risk event exists with ID #{event_id}"
        })

      error ->
        Logger.error("API: Error resolving risk event #{event_id}: #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json")
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to resolve risk event",
          message: "Internal server error occurred"
        })
    end
  end

  def var_analysis(conn, params) do
    Logger.info("API: Getting VaR analysis")

    confidence_level = String.to_float(params["confidence_level"] || "0.95")
    timeframe = params["timeframe"] || "1d"

    try do
      var_analysis = calculate_var_analysis(confidence_level, timeframe)

      conn
      |> put_resp_content_type("application/json")
      |> json(%{
        success: true,
        data: %{
          confidence_level: confidence_level,
          timeframe: timeframe,
          var_estimate: var_analysis.var_estimate,
          expected_shortfall: var_analysis.expected_shortfall,
          historical_var: var_analysis.historical_var,
          monte_carlo_var: var_analysis.monte_carlo_var,
          var_breakdown: var_analysis.breakdown
        },
        timestamp: DateTime.utc_now()
      })
    rescue
      error ->
        Logger.error("API: Error calculating VaR analysis: #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json")
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "VaR analysis failed",
          message: "Internal server error occurred"
        })
    end
  end

  def stress_test(conn, params) do
    Logger.info("API: Running stress test")

    scenario = params["scenario"] || "market_crash"

    try do
      stress_results = run_stress_test_scenario(scenario)

      conn
      |> put_resp_content_type("application/json")
      |> json(%{
        success: true,
        data: %{
          scenario: scenario,
          results: stress_results,
          tested_at: DateTime.utc_now()
        },
        timestamp: DateTime.utc_now()
      })
    rescue
      error ->
        Logger.error("API: Error running stress test: #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json")
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Stress test failed",
          message: "Internal server error occurred"
        })
    end
  end

  # Private functions

  defp get_current_risk_metrics() do
    %{
      total_exposure: Decimal.new("0.00"),
      var_1d: Decimal.new("0.00"),
      var_5d: Decimal.new("0.00"),
      expected_shortfall: Decimal.new("0.00"),
      max_drawdown: Decimal.new("0.00"),
      sharpe_ratio: 0.0,
      sortino_ratio: 0.0,
      beta: 1.0,
      alpha: 0.0,
      volatility: 0.0,
      correlation_with_market: 0.0,
      risk_adjusted_return: 0.0
    }
  end

  defp get_exposure_analysis(_group_by) do
    %{
      breakdown: [],
      concentration_risk: %{
        concentration_score: 0.0,
        top_positions: [],
        diversification_ratio: 1.0,
        herfindahl_index: 0.0
      },
      limits: %{
        max_single_position: Decimal.new("1000.00"),
        max_symbol_exposure: Decimal.new("2000.00"),
        max_sector_exposure: Decimal.new("3000.00")
      },
      utilization: %{
        single_position: 0.0,
        symbol_exposure: 0.0,
        sector_exposure: 0.0
      }
    }
  end

  defp get_correlation_analysis(_timeframe) do
    %{
      matrix: %{},
      high_correlations: [],
      risk_score: %{
        average_correlation: 0.0,
        max_correlation: 0.0,
        correlation_risk_score: 0.0
      },
      diversification: %{
        effective_positions: 0,
        diversification_ratio: 1.0,
        concentration_score: 0.0
      }
    }
  end

  defp build_risk_events_query(severity_filter, resolved_filter) do
    import Ecto.Query
    query = from(e in RiskEvent, preload: [:agent])

    # Apply severity filter
    query =
      if severity_filter && severity_filter != "" do
        from(e in query, where: e.severity == ^severity_filter)
      else
        query
      end

    # Apply resolved filter
    query =
      case resolved_filter do
        "true" -> from(e in query, where: e.resolved == true)
        "false" -> from(e in query, where: e.resolved == false)
        _ -> query
      end

    from(e in query, order_by: [desc: e.inserted_at])
  end

  defp format_risk_events_response(events) do
    Enum.map(events, &format_risk_event_response/1)
  end

  defp format_risk_event_response(event) do
    %{
      id: event.id,
      event_type: event.event_type,
      severity: event.severity,
      message: event.message,
      metadata: event.metadata,
      resolved: event.resolved,
      resolved_at: event.resolved_at,
      agent:
        if(event.agent,
          do: %{
            id: event.agent.id,
            name: event.agent.name
          },
          else: nil
        ),
      age_hours: RiskEvent.age_in_hours(event),
      critical: RiskEvent.critical?(event),
      inserted_at: event.inserted_at,
      updated_at: event.updated_at
    }
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defp get_active_risk_events() do
    # This would query active (unresolved) risk events
    # For now, returning empty list
    []
  end

  defp get_risk_events_summary() do
    %{
      total_events: 0,
      critical_events: 0,
      high_events: 0,
      medium_events: 0,
      low_events: 0,
      resolved_events: 0,
      unresolved_events: 0
    }
  end

  defp get_current_risk_limits() do
    %{
      max_total_exposure: Decimal.new("10000.00"),
      max_position_size: Decimal.new("1000.00"),
      max_daily_loss: Decimal.new("500.00"),
      max_var_1d: Decimal.new("200.00"),
      max_correlation: 0.8,
      max_agents: 10,
      max_leverage: 2.0,
      stop_loss_threshold: 0.05
    }
  end

  defp calculate_limit_utilization() do
    %{
      max_total_exposure: 0.0,
      max_position_size: 0.0,
      max_daily_loss: 0.0,
      max_var_1d: 0.0,
      max_correlation: 0.0,
      max_agents: 0.0,
      max_leverage: 0.0
    }
  end

  defp get_current_violations() do
    # This would get current limit violations
    []
  end

  defp calculate_limits_health(utilization, violations) do
    if length(violations) > 0 do
      :violation
    else
      max_utilization = utilization |> Map.values() |> Enum.max()

      cond do
        max_utilization > 0.9 -> :warning
        max_utilization > 0.7 -> :caution
        true -> :healthy
      end
    end
  end

  defp calculate_var_analysis(_confidence_level, _timeframe) do
    # This would calculate VaR using various methods
    # For now, returning mock analysis
    %{
      var_estimate: Decimal.new("100.00"),
      expected_shortfall: Decimal.new("150.00"),
      historical_var: Decimal.new("95.00"),
      monte_carlo_var: Decimal.new("105.00"),
      breakdown: %{
        by_asset: [],
        by_strategy: [],
        by_agent: []
      }
    }
  end

  defp run_stress_test_scenario(scenario) do
    # This would run actual stress test scenarios
    # For now, returning mock results
    %{
      scenario_name: scenario,
      portfolio_impact: Decimal.new("-500.00"),
      var_change: Decimal.new("50.00"),
      expected_shortfall_change: Decimal.new("75.00"),
      worst_case_loss: Decimal.new("-1000.00"),
      recovery_time_estimate: "2-3 days",
      recommendations: [
        "Reduce exposure to high-risk assets",
        "Increase hedge positions",
        "Review stop-loss levels"
      ]
    }
  end
end
