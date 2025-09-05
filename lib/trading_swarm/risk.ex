defmodule TradingSwarm.Risk do
  @moduledoc """
  The Risk context.

  Handles all risk management operations including:
  - Risk event tracking and resolution
  - Risk limits management
  - Exposure analysis
  - Risk metrics calculation
  """

  import Ecto.Query, warn: false
  alias TradingSwarm.Repo

  alias TradingSwarm.Risk.RiskEvent
  alias TradingSwarm.Trading.{TradingAgent, Trade}

  ## Risk Event functions

  @doc """
  Returns the list of risk events.
  """
  def list_risk_events do
    Repo.all(RiskEvent)
  end

  @doc """
  Gets a single risk event.

  Raises `Ecto.NoResultsError` if the risk event does not exist.
  """
  def get_risk_event!(id), do: Repo.get!(RiskEvent, id)

  @doc """
  Creates a risk event.
  """
  def create_risk_event(attrs \\ %{}) do
    %RiskEvent{}
    |> RiskEvent.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a risk event.
  """
  def update_risk_event(%RiskEvent{} = risk_event, attrs) do
    risk_event
    |> RiskEvent.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Resolves a risk event.
  """
  def resolve_event(%RiskEvent{} = risk_event, attrs \\ %{}) do
    risk_event
    |> RiskEvent.resolve_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a risk event.
  """
  def delete_risk_event(%RiskEvent{} = risk_event) do
    Repo.delete(risk_event)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking risk event changes.
  """
  def change_risk_event(%RiskEvent{} = risk_event, attrs \\ %{}) do
    RiskEvent.changeset(risk_event, attrs)
  end

  @doc """
  Gets active (unresolved) risk events.
  """
  def list_active_risk_events do
    from(e in RiskEvent, where: e.resolved == false, order_by: [desc: e.inserted_at])
    |> Repo.all()
  end

  @doc """
  Gets critical risk events.
  """
  def list_critical_risk_events do
    from(e in RiskEvent,
      where: e.severity == "critical" and e.resolved == false,
      order_by: [desc: e.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Gets risk events for a specific agent.
  """
  def list_risk_events_for_agent(agent_id) do
    from(e in RiskEvent,
      where: e.agent_id == ^agent_id,
      order_by: [desc: e.inserted_at]
    )
    |> Repo.all()
  end

  ## Risk Limits functions

  @doc """
  Updates risk limits configuration.
  """
  def update_limits(limits_params) do
    # This would update risk limits in a configuration store
    # For now, just returning success with the provided params
    {:ok, limits_params}
  end

  @doc """
  Gets current risk limits.
  """
  def get_current_limits do
    # This would retrieve current limits from configuration
    # For now, returning default limits
    %{
      max_total_exposure: Decimal.new("10000.00"),
      max_position_size: Decimal.new("1000.00"),
      max_daily_loss: Decimal.new("500.00"),
      max_var_1d: Decimal.new("200.00"),
      max_correlation: 0.8,
      max_agents: 10
    }
  end

  ## Risk Metrics functions

  @doc """
  Calculates current risk metrics.
  """
  def calculate_risk_metrics do
    # Get all executed trades
    executed_trades =
      from(t in Trade, where: t.status == "executed")
      |> Repo.all()

    # Calculate total exposure
    total_exposure =
      executed_trades
      |> Enum.map(&Trade.trade_value/1)
      |> Enum.reduce(Decimal.new("0.00"), &Decimal.add/2)

    # Calculate total P&L
    total_pnl =
      executed_trades
      |> Enum.map(&(&1.pnl || Decimal.new("0.00")))
      |> Enum.reduce(Decimal.new("0.00"), &Decimal.add/2)

    # Calculate basic metrics
    volatility = calculate_portfolio_volatility(executed_trades)
    max_drawdown = calculate_max_drawdown(executed_trades)

    %{
      total_exposure: total_exposure,
      total_pnl: total_pnl,
      volatility: volatility,
      max_drawdown: max_drawdown,
      var_1d: calculate_var_1d(executed_trades),
      var_5d: calculate_var_5d(executed_trades),
      sharpe_ratio: calculate_sharpe_ratio(executed_trades),
      active_risk_events: count_active_risk_events(),
      critical_risk_events: count_critical_risk_events()
    }
  end

  @doc """
  Gets risk statistics summary.
  """
  def get_risk_statistics do
    active_events = list_active_risk_events()

    events_by_severity =
      active_events
      |> Enum.group_by(& &1.severity)
      |> Map.new(fn {severity, events} -> {severity, length(events)} end)

    %{
      total_active_events: length(active_events),
      critical_events: Map.get(events_by_severity, "critical", 0),
      high_events: Map.get(events_by_severity, "high", 0),
      medium_events: Map.get(events_by_severity, "medium", 0),
      low_events: Map.get(events_by_severity, "low", 0),
      oldest_unresolved: get_oldest_unresolved_event(),
      avg_resolution_time: calculate_avg_resolution_time()
    }
  end

  @doc """
  Calculates exposure breakdown by various criteria.
  """
  def calculate_exposure_breakdown(group_by \\ :symbol) do
    executed_trades =
      from(t in Trade, where: t.status == "executed", preload: [:agent])
      |> Repo.all()

    case group_by do
      :symbol ->
        executed_trades
        |> Enum.group_by(& &1.symbol)
        |> Map.new(fn {symbol, trades} ->
          total_exposure =
            trades
            |> Enum.map(&Trade.trade_value/1)
            |> Enum.reduce(Decimal.new("0.00"), &Decimal.add/2)

          {symbol,
           %{
             trade_count: length(trades),
             total_exposure: total_exposure,
             # Would calculate against total portfolio
             percentage: 0.0
           }}
        end)

      :agent ->
        executed_trades
        |> Enum.group_by(& &1.agent_id)
        |> Map.new(fn {agent_id, trades} ->
          total_exposure =
            trades
            |> Enum.map(&Trade.trade_value/1)
            |> Enum.reduce(Decimal.new("0.00"), &Decimal.add/2)

          agent_name = if length(trades) > 0, do: hd(trades).agent.name, else: "Unknown"

          {agent_id,
           %{
             agent_name: agent_name,
             trade_count: length(trades),
             total_exposure: total_exposure,
             # Would calculate against total portfolio
             percentage: 0.0
           }}
        end)

      :side ->
        buy_trades = Enum.filter(executed_trades, &(&1.side == "buy"))
        sell_trades = Enum.filter(executed_trades, &(&1.side == "sell"))

        buy_exposure =
          buy_trades
          |> Enum.map(&Trade.trade_value/1)
          |> Enum.reduce(Decimal.new("0.00"), &Decimal.add/2)

        sell_exposure =
          sell_trades
          |> Enum.map(&Trade.trade_value/1)
          |> Enum.reduce(Decimal.new("0.00"), &Decimal.add/2)

        %{
          buy: %{trade_count: length(buy_trades), total_exposure: buy_exposure},
          sell: %{trade_count: length(sell_trades), total_exposure: sell_exposure}
        }

      _ ->
        %{}
    end
  end

  # Private functions

  defp calculate_portfolio_volatility(_trades) do
    # This would calculate actual portfolio volatility
    # For now, returning a mock value
    0.15
  end

  defp calculate_max_drawdown(_trades) do
    # This would calculate actual maximum drawdown
    # For now, returning a mock value
    Decimal.new("100.00")
  end

  defp calculate_var_1d(_trades) do
    # This would calculate 1-day Value at Risk
    # For now, returning a mock value
    Decimal.new("50.00")
  end

  defp calculate_var_5d(_trades) do
    # This would calculate 5-day Value at Risk
    # For now, returning a mock value
    Decimal.new("200.00")
  end

  defp calculate_sharpe_ratio(_trades) do
    # This would calculate actual Sharpe ratio
    # For now, returning a mock value
    1.2
  end

  defp count_active_risk_events do
    from(e in RiskEvent, where: e.resolved == false)
    |> Repo.aggregate(:count, :id)
  end

  defp count_critical_risk_events do
    from(e in RiskEvent, where: e.resolved == false and e.severity == "critical")
    |> Repo.aggregate(:count, :id)
  end

  defp get_oldest_unresolved_event do
    from(e in RiskEvent,
      where: e.resolved == false,
      order_by: [asc: e.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  defp calculate_avg_resolution_time do
    # This would calculate average resolution time for resolved events
    # For now, returning a mock value in hours
    24.5
  end
end
