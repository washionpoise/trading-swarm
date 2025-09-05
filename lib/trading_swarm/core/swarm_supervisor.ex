defmodule TradingSwarm.Core.SwarmSupervisor do
  @moduledoc """
  Supervisor para gerenciar o enxame de agentes de trading.

  Este supervisor gerencia centenas de agentes de trading concorrentes,
  implementando uma estratégia de supervisão um-para-um onde falhas
  individuais de agentes não derrubam o sistema inteiro.
  """

  use DynamicSupervisor

  alias TradingSwarm.Core.TradingAgent

  require Logger

  @max_agents 500
  @initial_population 20

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting Trading Swarm Supervisor")

    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_children: @max_agents,
      max_seconds: 5,
      max_restarts: 3
    )
  end

  def start_initial_population do
    Logger.info("Starting initial population of #{@initial_population} trading agents")

    1..@initial_population
    |> Enum.map(&create_random_agent/1)
    |> Enum.each(&start_agent/1)
  end

  def start_agent(agent_params) do
    child_spec = {TradingAgent, agent_params}

    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} ->
        Logger.info("Agent #{agent_params.id} started successfully")

        Phoenix.PubSub.broadcast(
          TradingSwarm.PubSub,
          "swarm_events",
          {:agent_born, agent_params.id, pid}
        )

        {:ok, pid}

      {:error, reason} ->
        Logger.error("Failed to start agent #{agent_params.id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def get_active_agents do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.map(fn {_, pid, _, _} ->
      try do
        GenServer.call(pid, :get_performance, 1000)
      catch
        :exit, _ -> nil
      end
    end)
    |> Enum.filter(&(&1 != nil))
  end

  def get_swarm_statistics do
    agents = get_active_agents()

    %{
      total_agents: length(agents),
      agents_by_strategy: group_by_strategy(agents),
      total_trades: sum_trades(agents),
      total_pnl: sum_pnl(agents),
      average_fitness: average_fitness(agents)
    }
  end

  defp create_random_agent(index) do
    %{
      id: "agent_#{index}_#{System.unique_integer()}",
      dna: generate_random_dna(),
      generation: 1
    }
  end

  defp generate_random_dna do
    strategies = [:scalping, :trend_following, :mean_reversion, :arbitrage, :momentum]

    %{
      strategy_type: Enum.random(strategies),
      risk_tolerance: 0.005 + :rand.uniform() * 0.015,
      trade_frequency: :rand.uniform() * 0.2,
      win_rate: 0.45 + :rand.uniform() * 0.3,
      stop_loss: 0.005 + :rand.uniform() * 0.02,
      take_profit: 0.01 + :rand.uniform() * 0.04,
      volatility_threshold: :rand.uniform() * 0.05,
      momentum_period: 5 + :rand.uniform(20)
    }
  end

  defp group_by_strategy(agents) do
    agents
    |> Enum.group_by(fn agent -> agent[:strategy_type] end)
    |> Enum.map(fn {strategy, agents_list} -> {strategy, length(agents_list)} end)
    |> Enum.into(%{})
  end

  defp sum_trades(agents) do
    agents
    |> Enum.map(fn agent -> agent[:trades_count] || 0 end)
    |> Enum.sum()
  end

  defp sum_pnl(agents) do
    agents
    |> Enum.map(fn agent ->
      case agent[:total_pnl] do
        %Decimal{} = pnl -> Decimal.to_float(pnl)
        pnl when is_number(pnl) -> pnl
        _ -> 0.0
      end
    end)
    |> Enum.sum()
  end

  defp average_fitness(agents) do
    if length(agents) > 0 do
      total_fitness =
        agents
        |> Enum.map(fn agent -> agent[:fitness_score] || 0.0 end)
        |> Enum.sum()

      total_fitness / length(agents)
    else
      0.0
    end
  end

  def replace_weakest_agents(new_agent_params_list) when is_list(new_agent_params_list) do
    current_agents = get_active_agents()

    weak_agents =
      current_agents
      |> Enum.sort_by(fn agent -> agent[:fitness_score] || 0.0 end)
      |> Enum.take(length(new_agent_params_list))

    Enum.each(weak_agents, fn agent ->
      if agent[:id] do
        terminate_agent(agent[:id])
      end
    end)

    Enum.each(new_agent_params_list, &start_agent/1)

    Logger.info("Substituídos #{length(new_agent_params_list)} agentes fracos por evoluídos")
  end

  def terminate_agent(agent_id) do
    case Registry.lookup(TradingSwarm.AgentRegistry, agent_id) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)

      [] ->
        {:error, :agent_not_found}
    end
  end
end
