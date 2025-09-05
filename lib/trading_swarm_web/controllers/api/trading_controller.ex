defmodule TradingSwarmWeb.API.TradingController do
  @moduledoc """
  JSON API controller for trading operations and trade data.

  Provides REST endpoints for:
  - Trade listings with filtering and pagination
  - Trading statistics and analytics
  - Trade execution monitoring
  - Performance metrics
  """

  use TradingSwarmWeb, :controller
  require Logger

  alias TradingSwarm.Repo
  alias TradingSwarm.Trading.{Trade, TradingAgent}

  def index(conn, params) do
    Logger.info("API: Loading trades with params: #{inspect(params)}")

    try do
      # Parse query parameters
      page = String.to_integer(params["page"] || "1")
      per_page = min(String.to_integer(params["per_page"] || "50"), 200)
      status_filter = params["status"]
      agent_filter = params["agent_id"]
      symbol_filter = params["symbol"]
      sort_by = params["sort"] || "executed_at"

      # Build query with filters
      trades_query = build_trades_query(status_filter, agent_filter, symbol_filter, sort_by)

      # Get paginated results
      trades =
        trades_query
        |> Repo.paginate(page: page, page_size: per_page)

      # Format trades for API response
      trades_data = format_trades_response(trades.entries)

      # Get summary statistics
      stats = get_trades_summary(status_filter, agent_filter, symbol_filter)

      conn
      |> put_resp_content_type("application/json")
      |> json(%{
        success: true,
        data: trades_data,
        summary: stats,
        pagination: %{
          current_page: page,
          per_page: per_page,
          total_entries: trades.total_entries,
          total_pages: trades.total_pages
        },
        timestamp: DateTime.utc_now()
      })
    rescue
      error ->
        Logger.error("API: Error loading trades: #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json")
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to load trades",
          message: "Internal server error occurred"
        })
    end
  end

  def show(conn, %{"id" => trade_id}) do
    Logger.info("API: Loading trade #{trade_id}")

    try do
      trade =
        Trade
        |> Repo.get!(trade_id)
        |> Repo.preload([:agent])

      # Calculate additional metrics
      trade_metrics = calculate_trade_metrics(trade)

      trade_data = format_trade_response(trade, trade_metrics)

      conn
      |> put_resp_content_type("application/json")
      |> json(%{
        success: true,
        data: trade_data,
        timestamp: DateTime.utc_now()
      })
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_resp_content_type("application/json")
        |> put_status(:not_found)
        |> json(%{
          success: false,
          error: "Trade not found",
          message: "No trade exists with ID #{trade_id}"
        })

      error ->
        Logger.error("API: Error loading trade #{trade_id}: #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json")
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to load trade",
          message: "Internal server error occurred"
        })
    end
  end

  def statistics(conn, params) do
    Logger.info("API: Loading trading statistics")

    timeframe = params["timeframe"] || "24h"

    try do
      # Get comprehensive trading statistics
      trading_stats = get_comprehensive_statistics(timeframe)

      # Get performance metrics
      performance_metrics = get_performance_metrics(timeframe)

      # Get breakdown statistics
      breakdown_stats = %{
        by_agent: get_agent_breakdown_statistics(timeframe),
        by_symbol: get_symbol_breakdown_statistics(timeframe),
        by_strategy: get_strategy_breakdown_statistics(timeframe)
      }

      # Get trend data
      trend_data = get_trading_trends(timeframe)

      conn
      |> put_resp_content_type("application/json")
      |> json(%{
        success: true,
        data: %{
          timeframe: timeframe,
          overall_statistics: trading_stats,
          performance_metrics: performance_metrics,
          breakdown: breakdown_stats,
          trends: trend_data
        },
        timestamp: DateTime.utc_now()
      })
    rescue
      error ->
        Logger.error("API: Error loading trading statistics: #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json")
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to load statistics",
          message: "Internal server error occurred"
        })
    end
  end

  def by_agent(conn, %{"agent_id" => agent_id} = params) do
    Logger.info("API: Loading trades for agent #{agent_id}")

    try do
      # Verify agent exists
      agent = Repo.get!(TradingAgent, agent_id)

      # Parse pagination parameters
      page = String.to_integer(params["page"] || "1")
      per_page = min(String.to_integer(params["per_page"] || "50"), 200)
      status_filter = params["status"]

      # Build query for agent trades
      trades_query = build_agent_trades_query(agent_id, status_filter)

      # Get paginated results
      trades =
        trades_query
        |> Repo.paginate(page: page, page_size: per_page)

      # Format trades
      trades_data = format_trades_response(trades.entries)

      # Get agent-specific statistics
      agent_stats = get_agent_specific_statistics(agent_id)

      conn
      |> put_resp_content_type("application/json")
      |> json(%{
        success: true,
        data: %{
          agent: %{
            id: agent.id,
            name: agent.name,
            status: agent.status
          },
          trades: trades_data,
          statistics: agent_stats
        },
        pagination: %{
          current_page: page,
          per_page: per_page,
          total_entries: trades.total_entries,
          total_pages: trades.total_pages
        },
        timestamp: DateTime.utc_now()
      })
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_resp_content_type("application/json")
        |> put_status(:not_found)
        |> json(%{
          success: false,
          error: "Agent not found",
          message: "No agent exists with ID #{agent_id}"
        })

      error ->
        Logger.error("API: Error loading trades for agent #{agent_id}: #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json")
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to load agent trades",
          message: "Internal server error occurred"
        })
    end
  end

  def performance(conn, params) do
    Logger.info("API: Loading performance metrics")

    timeframe = params["timeframe"] || "24h"
    agent_id = params["agent_id"]

    try do
      performance_data =
        if agent_id do
          # Agent-specific performance
          agent = Repo.get!(TradingAgent, agent_id)
          get_agent_performance_metrics(agent, timeframe)
        else
          # Overall system performance
          get_system_performance_metrics(timeframe)
        end

      conn
      |> put_resp_content_type("application/json")
      |> json(%{
        success: true,
        data: performance_data,
        timestamp: DateTime.utc_now()
      })
    rescue
      Ecto.NoResultsError ->
        if agent_id do
          conn
          |> put_resp_content_type("application/json")
          |> put_status(:not_found)
          |> json(%{
            success: false,
            error: "Agent not found",
            message: "No agent exists with ID #{agent_id}"
          })
        else
          conn
          |> put_resp_content_type("application/json")
          |> put_status(:internal_server_error)
          |> json(%{
            success: false,
            error: "Failed to load performance metrics",
            message: "Internal server error occurred"
          })
        end

      error ->
        Logger.error("API: Error loading performance metrics: #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json")
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to load performance metrics",
          message: "Internal server error occurred"
        })
    end
  end

  def export(conn, params) do
    Logger.info("API: Exporting trading data")

    try do
      format = params["format"] || "json"

      # Build export data based on filters
      export_data = build_export_data(params)

      case format do
        "json" ->
          conn
          |> put_resp_content_type("application/json")
          |> json(%{
            success: true,
            data: export_data,
            exported_at: DateTime.utc_now(),
            total_records: length(export_data),
            filters: extract_filters(params)
          })

        "csv" ->
          csv_data = generate_csv_export(export_data)
          filename = "trades_export_#{Date.utc_today()}.csv"

          conn
          |> put_resp_content_type("text/csv")
          |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
          |> send_resp(200, csv_data)

        _ ->
          conn
          |> put_resp_content_type("application/json")
          |> put_status(:bad_request)
          |> json(%{
            success: false,
            error: "Invalid format",
            message: "Supported formats: json, csv"
          })
      end
    rescue
      error ->
        Logger.error("API: Error exporting trading data: #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json")
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Export failed",
          message: "Internal server error occurred"
        })
    end
  end

  def realtime_metrics(conn, _params) do
    Logger.info("API: Getting real-time trading metrics")

    try do
      # Get current real-time metrics
      realtime_data = %{
        active_trades: get_active_trades_count(),
        pending_orders: get_pending_orders_count(),
        daily_pnl: get_daily_pnl(),
        hourly_volume: get_hourly_volume(),
        system_health: get_trading_system_health(),
        agent_activity: get_agent_activity_summary()
      }

      conn
      |> put_resp_content_type("application/json")
      |> json(%{
        success: true,
        data: realtime_data,
        timestamp: DateTime.utc_now()
      })
    rescue
      error ->
        Logger.error("API: Error getting real-time metrics: #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json")
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to get real-time metrics",
          message: "Internal server error occurred"
        })
    end
  end

  # Private functions

  defp build_trades_query(status_filter, agent_filter, symbol_filter, sort_by) do
    import Ecto.Query

    from(t in Trade, preload: [:agent])
    |> apply_api_status_filter(status_filter)
    |> apply_api_agent_filter(agent_filter)
    |> apply_api_symbol_filter(symbol_filter)
    |> apply_api_trades_sort(sort_by)
  end

  defp apply_api_status_filter(query, status_filter) do
    import Ecto.Query

    if status_filter && status_filter != "" do
      from(t in query, where: t.status == ^status_filter)
    else
      query
    end
  end

  defp apply_api_agent_filter(query, agent_filter) do
    import Ecto.Query

    if agent_filter && agent_filter != "" do
      agent_id = String.to_integer(agent_filter)
      from(t in query, where: t.agent_id == ^agent_id)
    else
      query
    end
  end

  defp apply_api_symbol_filter(query, symbol_filter) do
    import Ecto.Query

    if symbol_filter && symbol_filter != "" do
      from(t in query, where: t.symbol == ^symbol_filter)
    else
      query
    end
  end

  defp apply_api_trades_sort(query, sort_by) do
    import Ecto.Query

    case sort_by do
      "executed_at" -> from(t in query, order_by: [desc: t.executed_at])
      "symbol" -> from(t in query, order_by: [asc: t.symbol, desc: t.executed_at])
      "quantity" -> from(t in query, order_by: [desc: t.quantity, desc: t.executed_at])
      "price" -> from(t in query, order_by: [desc: t.price, desc: t.executed_at])
      "pnl" -> from(t in query, order_by: [desc: t.pnl, desc: t.executed_at])
      _ -> from(t in query, order_by: [desc: t.executed_at])
    end
  end

  defp build_agent_trades_query(agent_id, status_filter) do
    import Ecto.Query
    query = from(t in Trade, where: t.agent_id == ^agent_id, preload: [:agent])

    if status_filter && status_filter != "" do
      from(t in query, where: t.status == ^status_filter)
    else
      query
    end
    |> from(order_by: [desc: :executed_at])
  end

  defp format_trades_response(trades) do
    Enum.map(trades, &format_trade_response/1)
  end

  defp format_trade_response(trade, metrics \\ nil) do
    %{
      id: trade.id,
      symbol: trade.symbol,
      side: trade.side,
      type: trade.type,
      quantity: trade.quantity,
      price: trade.price,
      executed_at: trade.executed_at,
      status: trade.status,
      pnl: trade.pnl,
      fees: trade.fees,
      metadata: trade.metadata,
      agent:
        if(trade.agent,
          do: %{
            id: trade.agent.id,
            name: trade.agent.name
          },
          else: nil
        ),
      trade_value: Trade.trade_value(trade),
      net_pnl: Trade.net_pnl(trade),
      metrics: metrics,
      inserted_at: trade.inserted_at,
      updated_at: trade.updated_at
    }
  end

  defp calculate_trade_metrics(trade) do
    %{
      trade_value: Trade.trade_value(trade),
      net_pnl: Trade.net_pnl(trade),
      profitable: Trade.profitable?(trade),
      completed: Trade.completed?(trade),
      roi_percentage: calculate_roi_percentage(trade),
      holding_period: calculate_holding_period(trade)
    }
  end

  defp calculate_roi_percentage(trade) do
    if trade.pnl && Decimal.gt?(trade.pnl, 0) do
      trade_value = Trade.trade_value(trade)

      if Decimal.gt?(trade_value, 0) do
        Decimal.div(trade.pnl, trade_value) |> Decimal.mult(100) |> Decimal.to_float()
      else
        0.0
      end
    else
      0.0
    end
  end

  defp calculate_holding_period(_trade) do
    # This would calculate actual holding period if we track entry/exit times
    # For now, returning 0 as placeholder
    0
  end

  defp get_trades_summary(_status_filter, _agent_filter, _symbol_filter) do
    # This would calculate real summary statistics
    # For now, returning mock data
    %{
      total_trades: 0,
      executed_trades: 0,
      pending_trades: 0,
      cancelled_trades: 0,
      total_volume: Decimal.new("0.00"),
      total_pnl: Decimal.new("0.00"),
      win_rate: 0.0
    }
  end

  defp get_comprehensive_statistics(_timeframe) do
    # Mock comprehensive statistics
    %{
      total_trades: 0,
      successful_trades: 0,
      failed_trades: 0,
      total_volume: Decimal.new("0.00"),
      total_pnl: Decimal.new("0.00"),
      win_rate: 0.0,
      average_trade_size: Decimal.new("0.00")
    }
  end

  defp get_performance_metrics(_timeframe) do
    # Mock performance metrics
    %{
      roi: 0.0,
      sharpe_ratio: 0.0,
      max_drawdown: Decimal.new("0.00"),
      volatility: 0.0
    }
  end

  defp get_agent_breakdown_statistics(_timeframe) do
    []
  end

  defp get_symbol_breakdown_statistics(_timeframe) do
    []
  end

  defp get_strategy_breakdown_statistics(_timeframe) do
    []
  end

  defp get_trading_trends(_timeframe) do
    []
  end

  defp get_agent_specific_statistics(_agent_id) do
    # Mock agent-specific statistics
    %{
      total_trades: 0,
      winning_trades: 0,
      losing_trades: 0,
      win_rate: 0.0,
      total_pnl: Decimal.new("0.00"),
      average_profit_per_trade: Decimal.new("0.00")
    }
  end

  defp get_agent_performance_metrics(agent, timeframe) do
    %{
      agent_id: agent.id,
      agent_name: agent.name,
      timeframe: timeframe,
      performance: get_agent_specific_statistics(agent.id)
    }
  end

  defp get_system_performance_metrics(timeframe) do
    %{
      timeframe: timeframe,
      performance: get_comprehensive_statistics(timeframe)
    }
  end

  defp build_export_data(_params) do
    # This would build export data based on filters
    # For now, returning empty list
    []
  end

  defp extract_filters(params) do
    %{
      status: params["status"],
      agent_id: params["agent_id"],
      symbol: params["symbol"],
      timeframe: params["timeframe"]
    }
  end

  defp generate_csv_export(data) do
    # Generate CSV header and data
    header = "id,symbol,side,type,quantity,price,executed_at,status,pnl,fees,agent_id\n"

    csv_rows =
      Enum.map(data, fn trade ->
        "#{trade.id},#{trade.symbol},#{trade.side},#{trade.type},#{trade.quantity},#{trade.price},#{trade.executed_at},#{trade.status},#{trade.pnl || 0},#{trade.fees || 0},#{trade.agent_id}"
      end)

    header <> Enum.join(csv_rows, "\n")
  end

  defp get_active_trades_count() do
    0
  end

  defp get_pending_orders_count() do
    0
  end

  defp get_daily_pnl() do
    Decimal.new("0.00")
  end

  defp get_hourly_volume() do
    Decimal.new("0.00")
  end

  defp get_trading_system_health() do
    :healthy
  end

  defp get_agent_activity_summary() do
    %{
      active_agents: 0,
      idle_agents: 0,
      total_agents: 0
    }
  end
end
