defmodule TradingSwarm.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TradingSwarmWeb.Telemetry,
      TradingSwarm.Repo,
      {DNSCluster, query: Application.get_env(:trading_swarm, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TradingSwarm.PubSub},
      
      # Trading Swarm Core Components
      {Registry, keys: :unique, name: TradingSwarm.AgentRegistry},
      TradingSwarm.Core.RiskManager,
      TradingSwarm.AI.ModelCoordinator,
      TradingSwarm.Core.SwarmSupervisor,
      
      # Start to serve requests, typically the last entry
      TradingSwarmWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TradingSwarm.Supervisor]
    
    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        # Initialize the trading swarm after supervisor starts
        Task.start(fn ->
          Process.sleep(1000)  # Wait for components to initialize
          TradingSwarm.Core.SwarmSupervisor.start_initial_population()
        end)
        
        {:ok, pid}
      
      error ->
        error
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TradingSwarmWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
