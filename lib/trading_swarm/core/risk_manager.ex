defmodule TradingSwarm.Core.RiskManager do
  @moduledoc """
  Gerenciador de risco distribuído para o sistema de trading swarm.

  Implementa controles de risco em tempo real, monitoramento de drawdown,
  limites de posição e validação de trades para garantir operação segura.
  """

  use GenServer

  require Logger

  # Maximum 15% system drawdown
  @max_account_risk 0.15
  # Maximum 2% per agent
  @max_agent_risk 0.02
  # Maximum correlation between positions (70%)
  @max_correlation 0.7

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting Risk Manager")

    Phoenix.PubSub.subscribe(TradingSwarm.PubSub, "trading_events")
    Phoenix.PubSub.subscribe(TradingSwarm.PubSub, "risk_events")

    initial_state = %{
      total_exposure: Decimal.new(0),
      position_limits: %{},
      drawdown_tracking: %{
        current_drawdown: 0.0,
        max_drawdown: 0.0,
        # Initial capital
        high_water_mark: Decimal.new(100_000)
      },
      risk_metrics: initialize_risk_metrics(),
      alert_levels: %{
        # 10% drawdown warning
        warning: 0.10,
        # 12% drawdown critical
        critical: 0.12,
        # 15% drawdown emergency stop
        emergency: 0.15
      },
      emergency_stop: false
    }

    schedule_risk_evaluation()

    {:ok, initial_state}
  end

  @impl true
  def handle_call({:validate_trade, trade, agent_limits}, _from, state) do
    validation_result = validate_trade_request(trade, agent_limits, state)
    {:reply, validation_result, state}
  end

  @impl true
  def handle_call({:calculate_limits, risk_tolerance}, _from, state) do
    limits = calculate_agent_limits(risk_tolerance)
    {:reply, limits, state}
  end

  @impl true
  def handle_call(:get_risk_status, _from, state) do
    status = %{
      total_exposure: state.total_exposure,
      current_drawdown: state.drawdown_tracking.current_drawdown,
      max_drawdown: state.drawdown_tracking.max_drawdown,
      emergency_stop: state.emergency_stop,
      risk_level: calculate_risk_level(state)
    }

    {:reply, status, state}
  end

  @impl true
  def handle_info({:trade_executed, agent_id, trade, pnl_impact}, state) do
    new_state = update_risk_metrics(state, agent_id, trade, pnl_impact)
    new_state = update_drawdown_tracking(new_state, pnl_impact)

    # Verificar se algum limite foi violado
    case check_risk_violations(new_state) do
      {:ok, :normal} ->
        {:noreply, new_state}

      {:warning, level, message} ->
        broadcast_risk_alert(level, message)
        {:noreply, new_state}

      {:emergency, message} ->
        Logger.error("PARADA DE EMERGÊNCIA: #{message}")
        broadcast_risk_alert(:emergency, message)
        {:noreply, %{new_state | emergency_stop: true}}
    end
  end

  @impl true
  def handle_info({:evaluate_risk}, state) do
    Logger.info("Avaliando métricas de risco do sistema")

    # Log métricas principais
    Logger.info(
      "Drawdown atual: #{Float.round(state.drawdown_tracking.current_drawdown * 100, 2)}%"
    )

    Logger.info("Exposição total: $#{Decimal.to_float(state.total_exposure)}")

    schedule_risk_evaluation()
    {:noreply, state}
  end

  defp validate_trade_request(trade, agent_limits, state) do
    cond do
      state.emergency_stop ->
        {:error, "Sistema em parada de emergência"}

      exceeds_agent_limits?(trade, agent_limits) ->
        {:error, "Trade excede limites do agente"}

      exceeds_system_limits?(trade, state) ->
        {:error, "Trade excede limites do sistema"}

      # TODO: Implementar análise de correlação em produção
      # violates_correlation_limits?(trade, state) ->
      #   {:error, "Trade viola limites de correlação"}

      true ->
        {:ok, trade}
    end
  end

  defp exceeds_agent_limits?(trade, limits) do
    trade_value = trade.quantity * trade.price
    # 2% of 50k portfolio
    max_risk = limits.max_risk || @max_agent_risk * 50_000.0
    trade_value > max_risk
  end

  defp exceeds_system_limits?(trade, state) do
    trade_value = Decimal.from_float(trade.quantity * trade.price)
    new_exposure = Decimal.add(state.total_exposure, trade_value)

    # Verifica se nova exposição excede limites
    max_exposure =
      Decimal.mult(state.drawdown_tracking.high_water_mark, Decimal.from_float(@max_account_risk))

    Decimal.compare(new_exposure, max_exposure) == :gt
  end

  defp calculate_agent_limits(risk_tolerance) do
    # Capital base
    base_capital = 100_000.0
    max_risk_amount = base_capital * risk_tolerance

    %{
      max_risk: max_risk_amount,
      # Alavancagem 5x
      max_position_size: max_risk_amount * 5,
      daily_loss_limit: max_risk_amount * 3,
      max_trades_per_day: 100
    }
  end

  defp update_risk_metrics(state, agent_id, trade, _pnl_impact) do
    trade_value = Decimal.from_float(trade.quantity * trade.price)

    new_exposure =
      if trade.type == :buy do
        Decimal.add(state.total_exposure, trade_value)
      else
        Decimal.sub(state.total_exposure, trade_value)
      end

    # Atualizar limites de posição para o agente
    agent_exposure = Map.get(state.position_limits, agent_id, Decimal.new(0))

    new_agent_exposure =
      if trade.type == :buy do
        Decimal.add(agent_exposure, trade_value)
      else
        Decimal.sub(agent_exposure, trade_value)
      end

    new_position_limits = Map.put(state.position_limits, agent_id, new_agent_exposure)

    %{state | total_exposure: new_exposure, position_limits: new_position_limits}
  end

  defp update_drawdown_tracking(state, pnl_impact) do
    current_equity =
      Decimal.add(state.drawdown_tracking.high_water_mark, Decimal.from_float(pnl_impact))

    new_high_water_mark =
      if Decimal.compare(current_equity, state.drawdown_tracking.high_water_mark) == :gt do
        current_equity
      else
        state.drawdown_tracking.high_water_mark
      end

    drawdown = Decimal.sub(new_high_water_mark, current_equity)
    drawdown_pct = Decimal.div(drawdown, new_high_water_mark) |> Decimal.to_float()

    max_drawdown = max(state.drawdown_tracking.max_drawdown, drawdown_pct)

    new_tracking = %{
      current_drawdown: drawdown_pct,
      max_drawdown: max_drawdown,
      high_water_mark: new_high_water_mark
    }

    %{state | drawdown_tracking: new_tracking}
  end

  defp check_risk_violations(state) do
    current_dd = state.drawdown_tracking.current_drawdown

    cond do
      current_dd >= state.alert_levels.emergency ->
        {:emergency, "Drawdown crítico: #{Float.round(current_dd * 100, 2)}%"}

      current_dd >= state.alert_levels.critical ->
        {:warning, :critical, "Drawdown crítico: #{Float.round(current_dd * 100, 2)}%"}

      current_dd >= state.alert_levels.warning ->
        {:warning, :warning, "Drawdown de aviso: #{Float.round(current_dd * 100, 2)}%"}

      true ->
        {:ok, :normal}
    end
  end

  defp calculate_risk_level(state) do
    current_dd = state.drawdown_tracking.current_drawdown

    cond do
      state.emergency_stop -> :emergency
      current_dd >= state.alert_levels.critical -> :critical
      current_dd >= state.alert_levels.warning -> :high
      current_dd >= 0.05 -> :medium
      true -> :low
    end
  end

  defp broadcast_risk_alert(level, message) do
    Phoenix.PubSub.broadcast(
      TradingSwarm.PubSub,
      "risk_events",
      {:risk_alert, level, message}
    )

    Logger.warning("ALERTA DE RISCO [#{level}]: #{message}")
  end

  defp initialize_risk_metrics do
    %{
      daily_pnl: Decimal.new(0),
      weekly_pnl: Decimal.new(0),
      monthly_pnl: Decimal.new(0),
      trades_today: 0,
      winning_trades: 0,
      losing_trades: 0
    }
  end

  defp schedule_risk_evaluation do
    # A cada minuto
    Process.send_after(self(), {:evaluate_risk}, 60_000)
  end

  # API Pública

  def validate_trades(trades, agent_limits) when is_list(trades) do
    validated =
      Enum.map(trades, fn trade ->
        case validate_trade(trade, agent_limits) do
          {:ok, validated_trade} -> validated_trade
          {:error, _reason} -> nil
        end
      end)

    valid_trades = Enum.filter(validated, &(&1 != nil))
    {:ok, valid_trades}
  end

  def validate_trade(trade, agent_limits) do
    GenServer.call(__MODULE__, {:validate_trade, trade, agent_limits})
  end

  def calculate_limits(risk_tolerance) do
    GenServer.call(__MODULE__, {:calculate_limits, risk_tolerance})
  end

  def get_risk_status do
    GenServer.call(__MODULE__, :get_risk_status)
  end

  def emergency_stop do
    GenServer.cast(__MODULE__, :emergency_stop)
  end
end
