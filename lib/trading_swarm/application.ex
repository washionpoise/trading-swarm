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
      # Start a worker by calling: TradingSwarm.Worker.start_link(arg)
      # {TradingSwarm.Worker, arg},
      # Start to serve requests, typically the last entry
      TradingSwarmWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TradingSwarm.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TradingSwarmWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
