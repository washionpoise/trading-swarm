defmodule TradingSwarm.AI.ModelCoordinator do
  @moduledoc """
  Coordena múltiplos modelos de IA para decisões ótimas de trading.
  
  Este módulo orquestra o "Conselho de IA" - roteando diferentes tarefas
  para os modelos de IA mais apropriados baseado em suas forças e
  métricas de performance atuais.
  """
  
  use GenServer
  
  alias TradingSwarm.AI.NvidiaClient
  
  require Logger
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(_opts) do
    Logger.info("Iniciando Coordenador de Modelos de IA")
    
    Phoenix.PubSub.subscribe(TradingSwarm.PubSub, "model_usage")
    
    initial_state = %{
      model_performance: initialize_model_metrics(),
      routing_rules: initialize_routing_rules(),
      fallback_chain: [:nvidia],
      total_requests: 0,
      failed_requests: 0
    }
    
    schedule_performance_evaluation()
    
    {:ok, initial_state}
  end
  
  def analyze_market(strategy_type, options \\ []) do
    GenServer.call(__MODULE__, {:analyze_market, strategy_type, options})
  end
  
  @impl true
  def handle_call({:analyze_market, strategy_type, options}, _from, state) do
    optimal_provider = select_optimal_provider(:strategy, state, options)
    
    result = case optimal_provider do
      :nvidia ->
        NvidiaClient.generate_trading_strategy(%{strategy_type: strategy_type}, strategy_type)
      
      _ ->
        {:error, "Provider not implemented yet"}
    end
    
    new_state = update_model_usage(state, optimal_provider, result)
    {:reply, result, new_state}
  end
  
  @impl true
  def handle_call(:get_model_performance, _from, state) do
    performance_summary = %{
      model_metrics: state.model_performance,
      total_requests: state.total_requests,
      success_rate: calculate_overall_success_rate(state)
    }
    
    {:reply, performance_summary, state}
  end
  
  @impl true
  def handle_info({:evaluate_performance}, state) do
    Logger.info("Avaliando performance dos modelos de IA")
    
    Enum.each(state.model_performance, fn {provider, metrics} ->
      Logger.info("#{provider}: latency=#{metrics.avg_latency}ms, success=#{metrics.success_rate}")
    end)
    
    schedule_performance_evaluation()
    {:noreply, state}
  end
  
  defp select_optimal_provider(task_type, state, _options) do
    preferred_providers = Map.get(state.routing_rules, task_type, [:nvidia])
    hd(preferred_providers)
  end
  
  defp update_model_usage(state, provider, result) do
    success = case result do
      {:ok, _} -> true
      {:error, _} -> false
    end
    
    %{state |
      total_requests: state.total_requests + 1,
      failed_requests: if(success, do: state.failed_requests, else: state.failed_requests + 1)
    }
  end
  
  defp initialize_model_metrics do
    %{
      nvidia: %{
        avg_latency: 2000.0,
        success_rate: 0.95,
        cost_per_request: 0.02,
        last_used: DateTime.utc_now(),
        request_count: 0
      }
    }
  end
  
  defp initialize_routing_rules do
    %{
      sentiment: [:nvidia],
      strategy: [:nvidia],
      risk: [:nvidia],
      trade_evaluation: [:nvidia]
    }
  end
  
  defp calculate_overall_success_rate(state) do
    if state.total_requests > 0 do
      (state.total_requests - state.failed_requests) / state.total_requests
    else
      0.0
    end
  end
  
  defp schedule_performance_evaluation do
    Process.send_after(self(), {:evaluate_performance}, 5 * 60 * 1000)
  end
  
  def health_check_all do
    results = %{
      nvidia: NvidiaClient.health_check()
    }
    
    Logger.info("Resultados do health check dos modelos: #{inspect(results)}")
    results
  end
  
  def get_model_performance do
    GenServer.call(__MODULE__, :get_model_performance)
  end
end