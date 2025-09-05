defmodule TradingSwarmWeb.TradingController do
  @moduledoc """
  Controller for trading operations and trade management.
  
  Handles:
  - Trade listings with filtering and pagination
  - Trading statistics and analytics
  - Agent-specific trade views
  - Trade execution monitoring
  """
  
  use TradingSwarmWeb, :controller
  require Logger
  
  alias TradingSwarm.{Trading, Repo}
  alias TradingSwarm.Trading.{Trade, TradingAgent}
  
  def index(conn, params) do
    Logger.info("Loading trades index with params: #{inspect(params)}")
    
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
      
      # Get summary statistics
      stats = get_trades_summary(status_filter, agent_filter, symbol_filter)
      
      # Get available agents and symbols for filters
      filter_options = get_filter_options()
      
      conn
      |> assign(:trades, trades)
      |> assign(:stats, stats)
      |> assign(:filter_options, filter_options)
      |> assign(:current_page, page)
      |> assign(:status_filter, status_filter)
      |> assign(:agent_filter, agent_filter)
      |> assign(:symbol_filter, symbol_filter)
      |> assign(:sort_by, sort_by)
      |> assign(:page_title, "Trading Activity")
      |> render(:index)
      
    rescue
      error ->
        Logger.error("Error loading trades: #{inspect(error)}")
        
        conn
        |> put_flash(:error, "Failed to load trading data")
        |> assign(:trades, %{entries: [], total_entries: 0})
        |> assign(:stats, get_empty_stats())
        |> assign(:filter_options, %{agents: [], symbols: []})
        |> assign(:page_title, "Trading Activity")
        |> render(:index)
    end
  end
  
  def statistics(conn, params) do
    Logger.info("Loading trading statistics")
    
    timeframe = params["timeframe"] || "24h"
    
    try do
      # Get comprehensive trading statistics
      trading_stats = get_comprehensive_statistics(timeframe)
      
      # Get performance metrics
      performance_metrics = get_performance_metrics(timeframe)
      
      # Get agent statistics
      agent_stats = get_agent_trading_statistics(timeframe)
      
      # Get symbol statistics
      symbol_stats = get_symbol_trading_statistics(timeframe)
      
      # Get P&L trends
      pnl_trends = get_pnl_trends(timeframe)
      
      conn
      |> assign(:trading_stats, trading_stats)
      |> assign(:performance_metrics, performance_metrics)
      |> assign(:agent_stats, agent_stats)
      |> assign(:symbol_stats, symbol_stats)
      |> assign(:pnl_trends, pnl_trends)
      |> assign(:timeframe, timeframe)
      |> assign(:page_title, "Trading Statistics")
      |> render(:statistics)
      
    rescue
      error ->
        Logger.error("Error loading trading statistics: #{inspect(error)}")
        
        conn
        |> put_flash(:error, "Failed to load trading statistics")
        |> assign(:trading_stats, get_empty_comprehensive_stats())
        |> assign(:performance_metrics, %{})
        |> assign(:agent_stats, [])
        |> assign(:symbol_stats, [])
        |> assign(:pnl_trends, [])
        |> assign(:timeframe, timeframe)
        |> assign(:page_title, "Trading Statistics")
        |> render(:statistics)
    end
  end
  
  def by_agent(conn, %{"agent_id" => agent_id} = params) do
    Logger.info("Loading trades for agent #{agent_id}")
    
    try do
      # Get the agent
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
      
      # Get agent-specific statistics
      agent_stats = get_agent_specific_statistics(agent_id)
      
      # Get agent performance over time
      performance_history = get_agent_performance_history(agent_id)
      
      conn
      |> assign(:agent, agent)
      |> assign(:trades, trades)
      |> assign(:agent_stats, agent_stats)
      |> assign(:performance_history, performance_history)
      |> assign(:current_page, page)
      |> assign(:status_filter, status_filter)
      |> assign(:page_title, "#{agent.name} Trading Activity")
      |> render(:by_agent)
      
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_flash(:error, "Agent not found")
        |> redirect(to: ~p"/trading")
        
      error ->
        Logger.error("Error loading trades for agent #{agent_id}: #{inspect(error)}")
        
        conn
        |> put_flash(:error, "Failed to load agent trading data")
        |> redirect(to: ~p"/trading")
    end
  end
  
  def show(conn, %{"id" => trade_id}) do
    Logger.info("Loading trade details for #{trade_id}")
    
    try do
      trade = 
        Trade
        |> Repo.get!(trade_id)
        |> Repo.preload([:agent])
      
      # Get related trades (same symbol, similar timeframe)
      related_trades = get_related_trades(trade)
      
      # Calculate trade impact metrics
      trade_impact = calculate_trade_impact(trade)
      
      conn
      |> assign(:trade, trade)
      |> assign(:related_trades, related_trades)
      |> assign(:trade_impact, trade_impact)
      |> assign(:page_title, "Trade Details")
      |> render(:show)
      
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_flash(:error, "Trade not found")
        |> redirect(to: ~p"/trading")
        
      error ->
        Logger.error("Error loading trade #{trade_id}: #{inspect(error)}")
        
        conn
        |> put_flash(:error, "Failed to load trade details")
        |> redirect(to: ~p"/trading")
    end
  end
  
  def export(conn, params) do
    Logger.info("Exporting trading data with params: #{inspect(params)}")
    
    try do
      format = params["format"] || "csv"
      timeframe = params["timeframe"] || "24h"
      
      # Build export query
      export_data = build_export_data(params)
      
      case format do
        "csv" ->
          csv_data = generate_csv_export(export_data)
          filename = "trades_export_#{Date.utc_today()}.csv"
          
          conn
          |> put_resp_content_type("text/csv")
          |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
          |> send_resp(200, csv_data)
          
        "json" ->
          conn
          |> put_resp_content_type("application/json")
          |> json(%{
            success: true,
            data: export_data,
            exported_at: DateTime.utc_now(),
            total_records: length(export_data)
          })
          
        _ ->
          conn
          |> put_resp_content_type("application/json")
          |> put_status(:bad_request)
          |> json(%{success: false, error: "Unsupported export format"})
      end
      
    rescue
      error ->
        Logger.error("Error exporting trading data: #{inspect(error)}")
        
        conn
        |> put_resp_content_type("application/json")
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: "Export failed"})
    end
  end
  
  # Private functions
  
  defp build_trades_query(status_filter, agent_filter, symbol_filter, sort_by) do
    query = from(t in Trade, preload: [:agent])
    
    # Apply status filter
    query = if status_filter && status_filter != "" do
      from(t in query, where: t.status == ^status_filter)
    else
      query
    end
    
    # Apply agent filter
    query = if agent_filter && agent_filter != "" do
      agent_id = String.to_integer(agent_filter)
      from(t in query, where: t.agent_id == ^agent_id)
    else
      query
    end
    
    # Apply symbol filter
    query = if symbol_filter && symbol_filter != "" do
      from(t in query, where: t.symbol == ^symbol_filter)
    else
      query
    end
    
    # Apply sorting
    case sort_by do
      "executed_at" -> from(t in query, order_by: [desc: t.executed_at])
      "symbol" -> from(t in query, order_by: [asc: t.symbol, desc: t.executed_at])
      "side" -> from(t in query, order_by: [asc: t.side, desc: t.executed_at])
      "quantity" -> from(t in query, order_by: [desc: t.quantity, desc: t.executed_at])
      "price" -> from(t in query, order_by: [desc: t.price, desc: t.executed_at])
      "pnl" -> from(t in query, order_by: [desc: t.pnl, desc: t.executed_at])
      "agent" -> from(t in query, join: a in assoc(t, :agent), order_by: [asc: a.name, desc: t.executed_at])
      _ -> from(t in query, order_by: [desc: t.executed_at])
    end
  end
  
  defp build_agent_trades_query(agent_id, status_filter) do
    query = from(t in Trade, where: t.agent_id == ^agent_id, preload: [:agent])
    
    if status_filter && status_filter != "" do
      from(t in query, where: t.status == ^status_filter)
    else
      query
    end
    |> from(order_by: [desc: :executed_at])
  end
  
  defp get_trades_summary(status_filter, agent_filter, symbol_filter) do
    # This would calculate summary statistics from the database
    # For now, returning mock data
    %{
      total_trades: 0,
      executed_trades: 0,
      pending_trades: 0,
      cancelled_trades: 0,
      failed_trades: 0,
      total_volume: Decimal.new("0.00"),
      total_pnl: Decimal.new("0.00"),
      average_trade_size: Decimal.new("0.00"),
      win_rate: 0.0
    }
  end
  
  defp get_empty_stats() do
    %{
      total_trades: 0,
      executed_trades: 0,
      pending_trades: 0,
      cancelled_trades: 0,
      failed_trades: 0,
      total_volume: Decimal.new("0.00"),
      total_pnl: Decimal.new("0.00"),
      average_trade_size: Decimal.new("0.00"),
      win_rate: 0.0
    }
  end
  
  defp get_filter_options() do
    # This would query available agents and symbols
    # For now, returning mock data
    %{
      agents: [],
      symbols: ["BTC-USD", "ETH-USD", "ADA-USD"]
    }
  end
  
  defp get_comprehensive_statistics(timeframe) do
    # This would calculate comprehensive statistics based on timeframe
    # For now, returning mock data
    %{
      timeframe: timeframe,
      total_trades: 0,
      successful_trades: 0,
      failed_trades: 0,
      total_volume: Decimal.new("0.00"),
      total_pnl: Decimal.new("0.00"),
      average_profit_per_trade: Decimal.new("0.00"),
      win_rate: 0.0,
      sharpe_ratio: 0.0,
      max_drawdown: Decimal.new("0.00"),
      volatility: 0.0
    }
  end
  
  defp get_empty_comprehensive_stats() do
    %{
      total_trades: 0,
      successful_trades: 0,
      failed_trades: 0,
      total_volume: Decimal.new("0.00"),
      total_pnl: Decimal.new("0.00"),
      average_profit_per_trade: Decimal.new("0.00"),
      win_rate: 0.0,
      sharpe_ratio: 0.0,
      max_drawdown: Decimal.new("0.00"),
      volatility: 0.0
    }
  end
  
  defp get_performance_metrics(timeframe) do
    # This would calculate performance metrics
    # For now, returning mock data
    %{
      roi: 0.0,
      annualized_return: 0.0,
      total_fees_paid: Decimal.new("0.00"),
      average_holding_period: 0,
      best_trade: Decimal.new("0.00"),
      worst_trade: Decimal.new("0.00")
    }
  end
  
  defp get_agent_trading_statistics(timeframe) do
    # This would get per-agent statistics
    # For now, returning empty list
    []
  end
  
  defp get_symbol_trading_statistics(timeframe) do
    # This would get per-symbol statistics
    # For now, returning empty list
    []
  end
  
  defp get_pnl_trends(timeframe) do
    # This would calculate P&L trends over time
    # For now, returning empty list
    []
  end
  
  defp get_agent_specific_statistics(agent_id) do
    # This would calculate statistics specific to an agent
    # For now, returning mock data
    %{
      total_trades: 0,
      winning_trades: 0,
      losing_trades: 0,
      win_rate: 0.0,
      total_pnl: Decimal.new("0.00"),
      average_profit_per_trade: Decimal.new("0.00"),
      best_trade: Decimal.new("0.00"),
      worst_trade: Decimal.new("0.00"),
      current_streak: 0,
      max_winning_streak: 0,
      max_losing_streak: 0
    }
  end
  
  defp get_agent_performance_history(agent_id) do
    # This would get performance history for charts
    # For now, returning empty list
    []
  end
  
  defp get_related_trades(trade) do
    # This would find related trades based on symbol and time
    # For now, returning empty list
    []
  end
  
  defp calculate_trade_impact(trade) do
    # This would calculate the impact of the trade
    # For now, returning mock data
    %{
      portfolio_impact: 0.0,
      market_impact: 0.0,
      fees_impact: Decimal.to_float(trade.fees || Decimal.new("0.00")),
      slippage: 0.0
    }
  end
  
  defp build_export_data(params) do
    # This would build data for export based on filters
    # For now, returning empty list
    []
  end
  
  defp generate_csv_export(data) do
    # This would generate CSV from export data
    # For now, returning basic CSV header
    "timestamp,symbol,side,quantity,price,pnl,status,agent\n"
  end
end