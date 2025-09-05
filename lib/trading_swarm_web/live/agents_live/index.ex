defmodule TradingSwarmWeb.AgentsLive.Index do
  @moduledoc """
  LiveView for managing trading agents.

  Features:
  - Grid view of all agents with status cards
  - Start/stop controls for each agent
  - Real-time updates via PubSub
  - Performance metrics per agent
  """

  use TradingSwarmWeb, :live_view
  require Logger

  alias TradingSwarm.Trading

  import TradingSwarmWeb.TradingComponents
  import TradingSwarmWeb.DashboardComponents

  @impl true
  def mount(_params, _session, socket) do
    Logger.info("AgentsLive.Index mounted")

    # Subscribe to real-time agent updates
    if connected?(socket) do
      Phoenix.PubSub.subscribe(TradingSwarm.PubSub, "agent_updates")
      Phoenix.PubSub.subscribe(TradingSwarm.PubSub, "trading_updates")
    end

    socket =
      socket
      |> assign(:agents, load_agents())
      |> assign(:loading, false)
      |> assign(:last_updated, DateTime.utc_now())
      |> assign(:filter_status, :all)
      |> assign(:sort_by, :name)

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_agent", %{"agent_id" => agent_id}, socket) do
    Logger.info("Toggling agent #{agent_id}")

    case Trading.toggle_agent_status(agent_id) do
      {:ok, _agent} ->
        socket =
          socket
          |> put_flash(:info, "Agent status updated successfully")
          |> assign(:agents, load_agents())
          |> assign(:last_updated, DateTime.utc_now())

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Failed to toggle agent #{agent_id}: #{inspect(reason)}")
        socket = put_flash(socket, :error, "Failed to update agent status")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("filter_agents", %{"status" => status}, socket) do
    filter_status = String.to_atom(status)

    socket =
      socket
      |> assign(:filter_status, filter_status)
      |> assign(:agents, load_agents(filter_status))

    {:noreply, socket}
  end

  @impl true
  def handle_event("sort_agents", %{"sort_by" => sort_by}, socket) do
    sort_field = String.to_atom(sort_by)

    socket =
      socket
      |> assign(:sort_by, sort_field)
      |> assign(:agents, sort_agents(socket.assigns.agents, sort_field))

    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh_agents", _params, socket) do
    Logger.info("Manual agents refresh requested")

    socket =
      socket
      |> assign(:loading, true)
      |> assign(:agents, load_agents(socket.assigns.filter_status))
      |> assign(:last_updated, DateTime.utc_now())
      |> assign(:loading, false)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:agent_update, data}, socket) do
    Logger.debug("Received agent update: #{inspect(data)}")

    socket =
      socket
      |> assign(:agents, load_agents(socket.assigns.filter_status))
      |> assign(:last_updated, DateTime.utc_now())

    {:noreply, socket}
  end

  @impl true
  def handle_info({:trading_update, data}, socket) do
    Logger.debug("Received trading update affecting agents: #{inspect(data)}")

    # Update agent performance if trade affects specific agent
    if Map.has_key?(data, :agent_id) do
      socket =
        socket
        |> assign(:agents, load_agents(socket.assigns.filter_status))
        |> assign(:last_updated, DateTime.utc_now())

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # Private functions

  defp load_agents(filter_status \\ :all) do
    try do
      # This would normally query from database
      # For now, return mock data
      agents = [
        %{
          id: "agent_001",
          name: "Alpha Trader",
          status: :active,
          total_pnl: Decimal.new("1250.50"),
          trade_count: 24,
          win_rate: 0.75,
          strategy: "momentum",
          created_at: DateTime.utc_now() |> DateTime.add(-86400, :second)
        },
        %{
          id: "agent_002",
          name: "Beta Scalper",
          status: :idle,
          total_pnl: Decimal.new("-125.25"),
          trade_count: 18,
          win_rate: 0.61,
          strategy: "scalping",
          created_at: DateTime.utc_now() |> DateTime.add(-172_800, :second)
        },
        %{
          id: "agent_003",
          name: "Gamma Swing",
          status: :active,
          total_pnl: Decimal.new("875.00"),
          trade_count: 12,
          win_rate: 0.83,
          strategy: "swing",
          created_at: DateTime.utc_now() |> DateTime.add(-259_200, :second)
        },
        %{
          id: "agent_004",
          name: "Delta Arbitrage",
          status: :error,
          total_pnl: Decimal.new("325.75"),
          trade_count: 8,
          win_rate: 0.88,
          strategy: "arbitrage",
          created_at: DateTime.utc_now() |> DateTime.add(-345_600, :second)
        }
      ]

      case filter_status do
        :all -> agents
        status -> Enum.filter(agents, fn agent -> agent.status == status end)
      end
    rescue
      error ->
        Logger.error("Error loading agents: #{inspect(error)}")
        []
    end
  end

  defp sort_agents(agents, sort_field) do
    case sort_field do
      :name -> Enum.sort_by(agents, & &1.name)
      :status -> Enum.sort_by(agents, & &1.status)
      :pnl -> Enum.sort_by(agents, &Decimal.to_float(&1.total_pnl), :desc)
      :trades -> Enum.sort_by(agents, & &1.trade_count, :desc)
      :win_rate -> Enum.sort_by(agents, & &1.win_rate, :desc)
      _ -> agents
    end
  end

  defp get_agents_summary(agents) do
    total_agents = length(agents)
    active_count = Enum.count(agents, &(&1.status == :active))
    idle_count = Enum.count(agents, &(&1.status == :idle))
    error_count = Enum.count(agents, &(&1.status == :error))

    total_pnl =
      agents
      |> Enum.map(& &1.total_pnl)
      |> Enum.reduce(Decimal.new("0"), &Decimal.add/2)

    total_trades =
      agents
      |> Enum.map(& &1.trade_count)
      |> Enum.sum()

    avg_win_rate =
      if total_agents > 0 do
        agents
        |> Enum.map(& &1.win_rate)
        |> Enum.sum()
        |> Kernel./(total_agents)
      else
        0.0
      end

    %{
      total: total_agents,
      active: active_count,
      idle: idle_count,
      error: error_count,
      total_pnl: total_pnl,
      total_trades: total_trades,
      avg_win_rate: avg_win_rate
    }
  end
end
