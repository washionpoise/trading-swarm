defmodule TradingSwarmWeb.AgentController do
  @moduledoc """
  Controller for managing trading agents in the swarm system.

  Handles CRUD operations for agents, status management, and performance metrics.
  """

  use TradingSwarmWeb, :controller
  require Logger

  alias TradingSwarm.{Trading, Repo}
  alias TradingSwarm.Trading.TradingAgent

  def index(conn, params) do
    Logger.info("Loading agents index")

    try do
      # Parse query parameters
      page = String.to_integer(params["page"] || "1")
      per_page = min(String.to_integer(params["per_page"] || "20"), 100)
      status_filter = params["status"]
      sort_by = params["sort"] || "name"

      # Build query with filters
      agents_query = build_agents_query(status_filter, sort_by)

      # Get paginated results
      agents =
        agents_query
        |> Repo.paginate(page: page, page_size: per_page)

      # Get summary statistics
      stats = get_agents_summary()

      conn
      |> assign(:agents, agents)
      |> assign(:stats, stats)
      |> assign(:current_page, page)
      |> assign(:status_filter, status_filter)
      |> assign(:sort_by, sort_by)
      |> render(:index)
    rescue
      error ->
        Logger.error("Error loading agents: #{inspect(error)}")

        conn
        |> put_flash(:error, "Failed to load agents")
        |> assign(:agents, %{entries: [], total_entries: 0})
        |> assign(:stats, %{total: 0, active: 0, idle: 0, error: 0})
        |> render(:index)
    end
  end

  def show(conn, %{"id" => id}) do
    Logger.info("Loading agent #{id}")

    try do
      agent =
        TradingAgent
        |> Repo.get!(id)
        |> Repo.preload([:trades, :risk_events, :performance_metrics])

      # Get agent performance metrics
      performance = calculate_agent_performance(agent)

      # Get recent trades
      recent_trades = get_recent_trades_for_agent(agent.id)

      # Get risk events
      risk_events = get_risk_events_for_agent(agent.id)

      conn
      |> assign(:agent, agent)
      |> assign(:performance, performance)
      |> assign(:recent_trades, recent_trades)
      |> assign(:risk_events, risk_events)
      |> render(:show)
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_flash(:error, "Agent not found")
        |> redirect(to: ~p"/agents")

      error ->
        Logger.error("Error loading agent #{id}: #{inspect(error)}")

        conn
        |> put_flash(:error, "Failed to load agent")
        |> redirect(to: ~p"/agents")
    end
  end

  def new(conn, _params) do
    Logger.info("Showing new agent form")

    changeset = TradingAgent.changeset(%TradingAgent{}, %{})

    conn
    |> assign(:changeset, changeset)
    |> assign(:action, ~p"/agents")
    |> render(:new)
  end

  def create(conn, %{"trading_agent" => agent_params}) do
    Logger.info("Creating new agent with params: #{inspect(agent_params, pretty: true)}")

    # Add default values
    agent_params =
      agent_params
      |> Map.put_new("status", "idle")
      |> Map.put_new("balance", "1000.00")
      |> Map.put_new("risk_tolerance", "0.1")
      |> Map.put_new("strategy_params", %{})

    case Trading.create_agent(agent_params) do
      {:ok, agent} ->
        Logger.info("Successfully created agent #{agent.id}")

        # Publish agent creation event
        Phoenix.PubSub.broadcast(
          TradingSwarm.PubSub,
          "agent_updates",
          {:agent_created, agent}
        )

        conn
        |> put_flash(:info, "Agent created successfully")
        |> redirect(to: ~p"/agents/#{agent.id}")

      {:error, changeset} ->
        Logger.warning("Failed to create agent: #{inspect(changeset.errors)}")

        conn
        |> put_flash(:error, "Failed to create agent")
        |> assign(:changeset, changeset)
        |> assign(:action, ~p"/agents")
        |> render(:new)
    end
  end

  def edit(conn, %{"id" => id}) do
    Logger.info("Showing edit form for agent #{id}")

    try do
      agent = Repo.get!(TradingAgent, id)
      changeset = TradingAgent.changeset(agent, %{})

      conn
      |> assign(:agent, agent)
      |> assign(:changeset, changeset)
      |> assign(:action, ~p"/agents/#{agent.id}")
      |> render(:edit)
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_flash(:error, "Agent not found")
        |> redirect(to: ~p"/agents")

      error ->
        Logger.error("Error loading agent #{id} for edit: #{inspect(error)}")

        conn
        |> put_flash(:error, "Failed to load agent")
        |> redirect(to: ~p"/agents")
    end
  end

  def update(conn, %{"id" => id, "trading_agent" => agent_params}) do
    Logger.info("Updating agent #{id} with params: #{inspect(agent_params, pretty: true)}")

    try do
      agent = Repo.get!(TradingAgent, id)

      case Trading.update_agent(agent, agent_params) do
        {:ok, updated_agent} ->
          Logger.info("Successfully updated agent #{id}")

          # Publish agent update event
          Phoenix.PubSub.broadcast(
            TradingSwarm.PubSub,
            "agent_updates",
            {:agent_updated, updated_agent}
          )

          conn
          |> put_flash(:info, "Agent updated successfully")
          |> redirect(to: ~p"/agents/#{updated_agent.id}")

        {:error, changeset} ->
          Logger.warning("Failed to update agent #{id}: #{inspect(changeset.errors)}")

          conn
          |> put_flash(:error, "Failed to update agent")
          |> assign(:agent, agent)
          |> assign(:changeset, changeset)
          |> assign(:action, ~p"/agents/#{agent.id}")
          |> render(:edit)
      end
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_flash(:error, "Agent not found")
        |> redirect(to: ~p"/agents")

      error ->
        Logger.error("Error updating agent #{id}: #{inspect(error)}")

        conn
        |> put_flash(:error, "Failed to update agent")
        |> redirect(to: ~p"/agents")
    end
  end

  def delete(conn, %{"id" => id}) do
    Logger.info("Deleting agent #{id}")

    try do
      agent = Repo.get!(TradingAgent, id)

      case Trading.delete_agent(agent) do
        {:ok, _deleted_agent} ->
          Logger.info("Successfully deleted agent #{id}")

          # Publish agent deletion event
          Phoenix.PubSub.broadcast(
            TradingSwarm.PubSub,
            "agent_updates",
            {:agent_deleted, %{id: id, name: agent.name}}
          )

          conn
          |> put_flash(:info, "Agent deleted successfully")
          |> redirect(to: ~p"/agents")

        {:error, changeset} ->
          Logger.warning("Failed to delete agent #{id}: #{inspect(changeset.errors)}")

          conn
          |> put_flash(:error, "Failed to delete agent")
          |> redirect(to: ~p"/agents/#{id}")
      end
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_flash(:error, "Agent not found")
        |> redirect(to: ~p"/agents")

      error ->
        Logger.error("Error deleting agent #{id}: #{inspect(error)}")

        conn
        |> put_flash(:error, "Failed to delete agent")
        |> redirect(to: ~p"/agents")
    end
  end

  def toggle_status(conn, %{"id" => id}) do
    Logger.info("Toggling status for agent #{id}")

    try do
      agent = Repo.get!(TradingAgent, id)

      new_status =
        case agent.status do
          "active" -> "idle"
          "idle" -> "active"
          "stopped" -> "idle"
          "error" -> "idle"
          _ -> "idle"
        end

      case Trading.update_agent(agent, %{"status" => new_status}) do
        {:ok, updated_agent} ->
          Logger.info("Successfully toggled agent #{id} status to #{new_status}")

          # Publish status change event
          Phoenix.PubSub.broadcast(
            TradingSwarm.PubSub,
            "agent_updates",
            {:agent_status_changed, updated_agent}
          )

          conn
          |> put_flash(:info, "Agent status updated to #{new_status}")
          |> redirect(to: ~p"/agents/#{id}")

        {:error, changeset} ->
          Logger.warning("Failed to toggle agent #{id} status: #{inspect(changeset.errors)}")

          conn
          |> put_flash(:error, "Failed to update agent status")
          |> redirect(to: ~p"/agents/#{id}")
      end
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_flash(:error, "Agent not found")
        |> redirect(to: ~p"/agents")

      error ->
        Logger.error("Error toggling agent #{id} status: #{inspect(error)}")

        conn
        |> put_flash(:error, "Failed to update agent status")
        |> redirect(to: ~p"/agents")
    end
  end

  # Private functions

  defp build_agents_query(_status_filter, _sort_by) do
    # Mock data for now since we don't have TradingAgent schema
    []
  end

  defp get_agents_summary() do
    # This would normally query the database
    # For now, returning mock data
    %{
      total: 0,
      active: 0,
      idle: 0,
      stopped: 0,
      error: 0
    }
  end

  defp calculate_agent_performance(agent) do
    %{
      total_trades: agent.total_trades || 0,
      winning_trades: agent.winning_trades || 0,
      losing_trades: agent.losing_trades || 0,
      win_rate: TradingAgent.win_rate(agent),
      current_balance: agent.balance || Decimal.new("0.00"),
      profit_loss: calculate_profit_loss(agent),
      risk_score: calculate_risk_score(agent),
      last_activity: agent.last_trade_at
    }
  end

  defp calculate_profit_loss(agent) do
    # This would calculate P&L from trades
    # For now, returning mock calculation
    if agent.balance do
      Decimal.sub(agent.balance, Decimal.new("1000.00"))
    else
      Decimal.new("0.00")
    end
  end

  defp calculate_risk_score(agent) do
    # Simple risk score based on risk tolerance and recent activity
    base_risk = agent.risk_tolerance || Decimal.new("0.1")

    # Convert to float for calculation
    risk_float = Decimal.to_float(base_risk)

    # Adjust based on recent activity
    activity_multiplier =
      if agent.last_trade_at do
        hours_since = DateTime.diff(DateTime.utc_now(), agent.last_trade_at, :hour)
        if hours_since < 24, do: 1.2, else: 0.8
      else
        0.5
      end

    risk_float * activity_multiplier
  end

  defp get_recent_trades_for_agent(_agent_id) do
    # This would query recent trades for the agent
    # For now, returning empty list
    []
  end

  defp get_risk_events_for_agent(_agent_id) do
    # This would query risk events for the agent
    # For now, returning empty list
    []
  end
end
