defmodule TradingSwarmWeb.API.AgentController do
  @moduledoc """
  JSON API controller for trading agents.
  
  Provides REST endpoints for:
  - Agent listing with filtering and pagination
  - Agent creation, updates, and deletion
  - Agent status management
  - Agent performance metrics
  """
  
  use TradingSwarmWeb, :controller
  require Logger
  
  alias TradingSwarm.{Trading, Repo}
  alias TradingSwarm.Trading.TradingAgent
  
  def index(conn, params) do
    Logger.info("API: Loading agents with params: #{inspect(params)}")
    
    try do
      # Parse query parameters
      page = String.to_integer(params["page"] || "1")
      per_page = min(String.to_integer(params["per_page"] || "20"), 100)
      status_filter = params["status"]
      
      # Build query
      agents_query = build_agents_query(status_filter)
      
      # Get paginated results
      agents = 
        agents_query
        |> Repo.paginate(page: page, page_size: per_page)
      
      # Format response
      agents_data = format_agents_response(agents.entries)
      
      conn
      |> put_resp_content_type("application/json")
      |> json(%{
        success: true,
        data: agents_data,
        pagination: %{
          current_page: page,
          per_page: per_page,
          total_entries: agents.total_entries,
          total_pages: agents.total_pages
        },
        timestamp: DateTime.utc_now()
      })
      
    rescue
      error ->
        Logger.error("API: Error loading agents: #{inspect(error)}")
        
        conn
        |> put_resp_content_type("application/json")
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to load agents",
          message: "Internal server error occurred"
        })
    end
  end
  
  def show(conn, %{"id" => id}) do
    Logger.info("API: Loading agent #{id}")
    
    try do
      agent = 
        TradingAgent
        |> Repo.get!(id)
        |> Repo.preload([:trades, :risk_events, :performance_metrics])
      
      # Calculate performance metrics
      performance = calculate_performance_metrics(agent)
      
      agent_data = format_agent_response(agent, performance)
      
      conn
      |> put_resp_content_type("application/json")
      |> json(%{
        success: true,
        data: agent_data,
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
          message: "No agent exists with ID #{id}"
        })
        
      error ->
        Logger.error("API: Error loading agent #{id}: #{inspect(error)}")
        
        conn
        |> put_resp_content_type("application/json")
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to load agent",
          message: "Internal server error occurred"
        })
    end
  end
  
  def create(conn, %{"agent" => agent_params}) do
    Logger.info("API: Creating agent with params: #{inspect(agent_params, pretty: true)}")
    
    # Add default values
    agent_params = 
      agent_params
      |> Map.put_new("status", "idle")
      |> Map.put_new("balance", "1000.00")
      |> Map.put_new("risk_tolerance", "0.1")
      |> Map.put_new("strategy_params", %{})
    
    case Trading.create_agent(agent_params) do
      {:ok, agent} ->
        Logger.info("API: Successfully created agent #{agent.id}")
        
        # Publish creation event
        Phoenix.PubSub.broadcast(
          TradingSwarm.PubSub, 
          "agent_updates", 
          {:agent_created, agent}
        )
        
        agent_data = format_agent_response(agent)
        
        conn
        |> put_resp_content_type("application/json")
        |> put_status(:created)
        |> json(%{
          success: true,
          data: agent_data,
          message: "Agent created successfully",
          timestamp: DateTime.utc_now()
        })
        
      {:error, changeset} ->
        Logger.warning("API: Failed to create agent: #{inspect(changeset.errors)}")
        
        conn
        |> put_resp_content_type("application/json")
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          error: "Validation failed",
          errors: format_changeset_errors(changeset),
          message: "Agent creation failed due to validation errors"
        })
    end
  end
  
  def update(conn, %{"id" => id, "agent" => agent_params}) do
    Logger.info("API: Updating agent #{id} with params: #{inspect(agent_params, pretty: true)}")
    
    try do
      agent = Repo.get!(TradingAgent, id)
      
      case Trading.update_agent(agent, agent_params) do
        {:ok, updated_agent} ->
          Logger.info("API: Successfully updated agent #{id}")
          
          # Publish update event
          Phoenix.PubSub.broadcast(
            TradingSwarm.PubSub, 
            "agent_updates", 
            {:agent_updated, updated_agent}
          )
          
          agent_data = format_agent_response(updated_agent)
          
          conn
          |> put_resp_content_type("application/json")
          |> json(%{
            success: true,
            data: agent_data,
            message: "Agent updated successfully",
            timestamp: DateTime.utc_now()
          })
          
        {:error, changeset} ->
          Logger.warning("API: Failed to update agent #{id}: #{inspect(changeset.errors)}")
          
          conn
          |> put_resp_content_type("application/json")
          |> put_status(:unprocessable_entity)
          |> json(%{
            success: false,
            error: "Validation failed",
            errors: format_changeset_errors(changeset),
            message: "Agent update failed due to validation errors"
          })
      end
      
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_resp_content_type("application/json")
        |> put_status(:not_found)
        |> json(%{
          success: false,
          error: "Agent not found",
          message: "No agent exists with ID #{id}"
        })
        
      error ->
        Logger.error("API: Error updating agent #{id}: #{inspect(error)}")
        
        conn
        |> put_resp_content_type("application/json")
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to update agent",
          message: "Internal server error occurred"
        })
    end
  end
  
  def delete(conn, %{"id" => id}) do
    Logger.info("API: Deleting agent #{id}")
    
    try do
      agent = Repo.get!(TradingAgent, id)
      
      case Trading.delete_agent(agent) do
        {:ok, _deleted_agent} ->
          Logger.info("API: Successfully deleted agent #{id}")
          
          # Publish deletion event
          Phoenix.PubSub.broadcast(
            TradingSwarm.PubSub, 
            "agent_updates", 
            {:agent_deleted, %{id: id, name: agent.name}}
          )
          
          conn
          |> put_resp_content_type("application/json")
          |> json(%{
            success: true,
            message: "Agent deleted successfully",
            timestamp: DateTime.utc_now()
          })
          
        {:error, changeset} ->
          Logger.warning("API: Failed to delete agent #{id}: #{inspect(changeset.errors)}")
          
          conn
          |> put_resp_content_type("application/json")
          |> put_status(:unprocessable_entity)
          |> json(%{
            success: false,
            error: "Deletion failed",
            errors: format_changeset_errors(changeset),
            message: "Agent deletion failed"
          })
      end
      
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_resp_content_type("application/json")
        |> put_status(:not_found)
        |> json(%{
          success: false,
          error: "Agent not found",
          message: "No agent exists with ID #{id}"
        })
        
      error ->
        Logger.error("API: Error deleting agent #{id}: #{inspect(error)}")
        
        conn
        |> put_resp_content_type("application/json")
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to delete agent",
          message: "Internal server error occurred"
        })
    end
  end
  
  def toggle_status(conn, %{"id" => id}) do
    Logger.info("API: Toggling status for agent #{id}")
    
    try do
      agent = Repo.get!(TradingAgent, id)
      
      new_status = case agent.status do
        "active" -> "idle"
        "idle" -> "active"
        "stopped" -> "idle"
        "error" -> "idle"
        _ -> "idle"
      end
      
      case Trading.update_agent(agent, %{"status" => new_status}) do
        {:ok, updated_agent} ->
          Logger.info("API: Successfully toggled agent #{id} status to #{new_status}")
          
          # Publish status change event
          Phoenix.PubSub.broadcast(
            TradingSwarm.PubSub, 
            "agent_updates", 
            {:agent_status_changed, updated_agent}
          )
          
          agent_data = format_agent_response(updated_agent)
          
          conn
          |> put_resp_content_type("application/json")
          |> json(%{
            success: true,
            data: agent_data,
            message: "Agent status updated to #{new_status}",
            timestamp: DateTime.utc_now()
          })
          
        {:error, changeset} ->
          Logger.warning("API: Failed to toggle agent #{id} status: #{inspect(changeset.errors)}")
          
          conn
          |> put_resp_content_type("application/json")
          |> put_status(:unprocessable_entity)
          |> json(%{
            success: false,
            error: "Status update failed",
            errors: format_changeset_errors(changeset),
            message: "Failed to update agent status"
          })
      end
      
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_resp_content_type("application/json")
        |> put_status(:not_found)
        |> json(%{
          success: false,
          error: "Agent not found",
          message: "No agent exists with ID #{id}"
        })
        
      error ->
        Logger.error("API: Error toggling agent #{id} status: #{inspect(error)}")
        
        conn
        |> put_resp_content_type("application/json")
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to update status",
          message: "Internal server error occurred"
        })
    end
  end
  
  def performance(conn, %{"id" => id}) do
    Logger.info("API: Getting performance metrics for agent #{id}")
    
    try do
      agent = 
        TradingAgent
        |> Repo.get!(id)
        |> Repo.preload([:trades, :performance_metrics])
      
      performance_metrics = calculate_detailed_performance_metrics(agent)
      
      conn
      |> put_resp_content_type("application/json")
      |> json(%{
        success: true,
        data: %{
          agent_id: agent.id,
          agent_name: agent.name,
          performance: performance_metrics
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
          message: "No agent exists with ID #{id}"
        })
        
      error ->
        Logger.error("API: Error getting performance for agent #{id}: #{inspect(error)}")
        
        conn
        |> put_resp_content_type("application/json")
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to get performance metrics",
          message: "Internal server error occurred"
        })
    end
  end
  
  # Private functions
  
  defp build_agents_query(status_filter) do
    query = from(a in TradingAgent)
    
    if status_filter && status_filter != "" do
      from(a in query, where: a.status == ^status_filter)
    else
      query
    end
    |> from(order_by: [asc: :name])
  end
  
  defp format_agents_response(agents) do
    Enum.map(agents, &format_agent_response/1)
  end
  
  defp format_agent_response(agent, performance \\ nil) do
    %{
      id: agent.id,
      name: agent.name,
      status: agent.status,
      balance: agent.balance,
      risk_tolerance: agent.risk_tolerance,
      strategy_params: agent.strategy_params,
      total_trades: agent.total_trades,
      winning_trades: agent.winning_trades,
      losing_trades: agent.losing_trades,
      win_rate: TradingAgent.win_rate(agent),
      last_trade_at: agent.last_trade_at,
      inserted_at: agent.inserted_at,
      updated_at: agent.updated_at,
      performance: performance
    }
  end
  
  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
  
  defp calculate_performance_metrics(agent) do
    %{
      total_trades: agent.total_trades || 0,
      winning_trades: agent.winning_trades || 0,
      losing_trades: agent.losing_trades || 0,
      win_rate: TradingAgent.win_rate(agent),
      profit_loss: calculate_profit_loss(agent),
      current_balance: agent.balance,
      risk_score: calculate_risk_score(agent)
    }
  end
  
  defp calculate_detailed_performance_metrics(agent) do
    basic_metrics = calculate_performance_metrics(agent)
    
    Map.merge(basic_metrics, %{
      sharpe_ratio: 0.0,
      sortino_ratio: 0.0,
      max_drawdown: Decimal.new("0.00"),
      average_profit_per_trade: Decimal.new("0.00"),
      best_trade: Decimal.new("0.00"),
      worst_trade: Decimal.new("0.00"),
      volatility: 0.0,
      beta: 1.0
    })
  end
  
  defp calculate_profit_loss(agent) do
    if agent.balance do
      Decimal.sub(agent.balance, Decimal.new("1000.00"))
    else
      Decimal.new("0.00")
    end
  end
  
  defp calculate_risk_score(agent) do
    base_risk = agent.risk_tolerance || Decimal.new("0.1")
    risk_float = Decimal.to_float(base_risk)
    
    activity_multiplier = if agent.last_trade_at do
      hours_since = DateTime.diff(DateTime.utc_now(), agent.last_trade_at, :hour)
      if hours_since < 24, do: 1.2, else: 0.8
    else
      0.5
    end
    
    risk_float * activity_multiplier
  end
end