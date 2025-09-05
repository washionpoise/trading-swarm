defmodule TradingSwarm.Core.TradingAgent do
  @moduledoc """
  Individual trading agent with evolutionary DNA.
  
  Each agent is a GenServer process that maintains its own trading strategy,
  position tracking, and performance metrics. Agents evolve their strategies
  through genetic algorithms.
  """
  
  use GenServer
  
  alias TradingSwarm.Core.{GeneticCoordinator, RiskManager}
  alias TradingSwarm.Data.MarketData
  alias TradingSwarm.AI.ModelCoordinator
  
  require Logger
  
  @type strategy_type :: :scalping | :trend_following | :mean_reversion | :arbitrage | :momentum
  
  @type agent_dna :: %{
    strategy_type: strategy_type(),
    risk_tolerance: float(),
    trade_frequency: float(),
    win_rate: float(),
    stop_loss: float(),
    take_profit: float(),
    volatility_threshold: float(),
    momentum_period: integer()
  }
  
  @type agent_state :: %{
    id: String.t(),
    dna: agent_dna(),
    positions: map(),
    performance: map(),
    risk_limits: map(),
    generation: integer(),
    fitness_score: float(),
    trades_count: integer(),
    total_pnl: Decimal.t()
  }
  
  def start_link(agent_params) do
    GenServer.start_link(__MODULE__, agent_params, name: via_tuple(agent_params.id))
  end
  
  defp via_tuple(id), do: {:via, Registry, {TradingSwarm.AgentRegistry, id}}
  
  @impl true
  def init(agent_params) do
    Logger.info("Starting trading agent #{agent_params.id}")
    
    state = %{
      id: agent_params.id,
      dna: agent_params.dna,
      positions: %{},
      performance: initialize_performance_metrics(),
      risk_limits: %{max_risk: agent_params.dna.risk_tolerance * 10000},
      generation: agent_params.generation || 1,
      fitness_score: 0.0,
      trades_count: 0,
      total_pnl: Decimal.new(0)
    }
    
    Phoenix.PubSub.subscribe(TradingSwarm.PubSub, "market_events")
    Phoenix.PubSub.subscribe(TradingSwarm.PubSub, "risk_events")
    
    schedule_strategy_execution()
    
    {:ok, state}
  end
  
  @impl true
  def handle_info({:market_update, symbol, price}, state) do
    new_state = analyze_market_opportunity(state, symbol, price)
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info({:execute_strategy}, state) do
    new_state = execute_trading_strategy(state)
    schedule_strategy_execution()
    {:noreply, new_state}
  end
  
  @impl true
  def handle_call(:get_performance, _from, state) do
    performance_data = %{
      id: state.id,
      fitness_score: state.fitness_score,
      total_pnl: state.total_pnl,
      trades_count: state.trades_count,
      win_rate: calculate_win_rate(state),
      strategy_type: state.dna.strategy_type,
      generation: state.generation
    }
    
    {:reply, performance_data, state}
  end
  
  defp analyze_market_opportunity(state, symbol, price) do
    case state.dna.strategy_type do
      :scalping -> analyze_scalping_opportunity(state, symbol, price)
      :trend_following -> analyze_trend_opportunity(state, symbol, price)
      :mean_reversion -> analyze_mean_reversion_opportunity(state, symbol, price)
      :arbitrage -> analyze_arbitrage_opportunity(state, symbol, price)
      :momentum -> analyze_momentum_opportunity(state, symbol, price)
    end
  end
  
  defp execute_trading_strategy(state) do
    if :rand.uniform() < state.dna.trade_frequency do
      symbol = "AAPL"  # Default symbol for now
      price = 150.0 + (:rand.uniform() - 0.5) * 10  # Simulated price
      
      trade_size = calculate_position_size(state, symbol, price)
      
      if trade_size > 0 do
        trade = %{
          symbol: symbol,
          type: if(:rand.uniform() > 0.5, do: :buy, else: :sell),
          quantity: trade_size,
          price: price,
          timestamp: DateTime.utc_now()
        }
        
        execute_trade(state, trade)
      else
        state
      end
    else
      state
    end
  end
  
  defp analyze_scalping_opportunity(state, _symbol, _price) do
    state
  end
  
  defp analyze_trend_opportunity(state, _symbol, _price) do
    state
  end
  
  defp analyze_mean_reversion_opportunity(state, _symbol, _price) do
    state
  end
  
  defp analyze_arbitrage_opportunity(state, _symbol, _price) do
    state
  end
  
  defp analyze_momentum_opportunity(state, _symbol, _price) do
    state
  end
  
  defp calculate_position_size(state, _symbol, price) do
    account_balance = Decimal.new(10000)
    risk_amount = Decimal.mult(account_balance, Decimal.from_float(state.dna.risk_tolerance))
    
    Decimal.div(risk_amount, Decimal.from_float(price))
    |> Decimal.to_float()
    |> max(0)
  end
  
  defp execute_trade(state, trade) do
    Logger.info("Agent #{state.id} executing #{trade.type} #{trade.quantity} #{trade.symbol} at $#{trade.price}")
    
    pnl_impact = simulate_trade_outcome(trade, state.dna.win_rate)
    new_total_pnl = Decimal.add(state.total_pnl, Decimal.from_float(pnl_impact))
    
    Phoenix.PubSub.broadcast(
      TradingSwarm.PubSub,
      "trading_events",
      {:trade_executed, state.id, trade, pnl_impact}
    )
    
    new_fitness = calculate_fitness_update(state, pnl_impact)
    
    %{state |
      trades_count: state.trades_count + 1,
      total_pnl: new_total_pnl,
      fitness_score: new_fitness
    }
  end
  
  defp simulate_trade_outcome(trade, win_rate) do
    if :rand.uniform() < win_rate do
      trade.quantity * trade.price * 0.01 * :rand.uniform()
    else
      -trade.quantity * trade.price * 0.005 * :rand.uniform()
    end
  end
  
  defp calculate_fitness_update(state, pnl_impact) do
    pnl_factor = Decimal.to_float(state.total_pnl) / 1000.0
    win_rate_factor = calculate_win_rate(state)
    trade_frequency_factor = min(state.trades_count / 100.0, 1.0)
    
    (pnl_factor * 0.5) + (win_rate_factor * 0.3) + (trade_frequency_factor * 0.2)
  end
  
  defp calculate_win_rate(state) do
    if state.trades_count > 0 do
      state.dna.win_rate
    else
      0.0
    end
  end
  
  defp initialize_performance_metrics do
    %{
      daily_returns: [],
      monthly_returns: [],
      trades_history: [],
      drawdowns: []
    }
  end
  
  defp schedule_strategy_execution do
    frequency_ms = :rand.uniform(30_000) + 5_000
    Process.send_after(self(), {:execute_strategy}, frequency_ms)
  end
  
  def get_performance(agent_id) do
    case Registry.lookup(TradingSwarm.AgentRegistry, agent_id) do
      [{pid, _}] -> GenServer.call(pid, :get_performance)
      [] -> {:error, :agent_not_found}
    end
  end
end