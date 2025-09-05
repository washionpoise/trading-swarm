defmodule TradingSwarm.Trading do
  @moduledoc """
  The Trading context.

  Handles all trading-related operations including:
  - Agent management
  - Trade execution and tracking
  - Trading statistics and analytics
  """

  import Ecto.Query, warn: false
  alias TradingSwarm.Repo

  alias TradingSwarm.Trading.{TradingAgent, Trade}

  ## Agent functions

  @doc """
  Returns the list of trading agents.
  """
  def list_agents do
    Repo.all(TradingAgent)
  end

  @doc """
  Gets a single trading agent.

  Raises `Ecto.NoResultsError` if the agent does not exist.
  """
  def get_agent!(id), do: Repo.get!(TradingAgent, id)

  @doc """
  Creates a trading agent.
  """
  def create_agent(attrs \\ %{}) do
    %TradingAgent{}
    |> TradingAgent.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a trading agent.
  """
  def update_agent(%TradingAgent{} = agent, attrs) do
    agent
    |> TradingAgent.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a trading agent.
  """
  def delete_agent(%TradingAgent{} = agent) do
    Repo.delete(agent)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking agent changes.
  """
  def change_agent(%TradingAgent{} = agent, attrs \\ %{}) do
    TradingAgent.changeset(agent, attrs)
  end

  @doc """
  Toggles an agent's status between active and idle.
  """
  def toggle_agent_status(agent_id) do
    agent = get_agent!(agent_id)

    new_status =
      case agent.status do
        "active" -> "idle"
        "idle" -> "active"
        "stopped" -> "idle"
        "error" -> "idle"
        _ -> "idle"
      end

    update_agent(agent, %{status: new_status})
  end

  ## Trade functions

  @doc """
  Returns the list of trades.
  """
  def list_trades do
    Repo.all(Trade)
  end

  @doc """
  Gets a single trade.

  Raises `Ecto.NoResultsError` if the trade does not exist.
  """
  def get_trade!(id), do: Repo.get!(Trade, id)

  @doc """
  Creates a trade.
  """
  def create_trade(attrs \\ %{}) do
    %Trade{}
    |> Trade.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a trade.
  """
  def update_trade(%Trade{} = trade, attrs) do
    trade
    |> Trade.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a trade.
  """
  def delete_trade(%Trade{} = trade) do
    Repo.delete(trade)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking trade changes.
  """
  def change_trade(%Trade{} = trade, attrs \\ %{}) do
    Trade.changeset(trade, attrs)
  end

  @doc """
  Gets trades for a specific agent.
  """
  def list_trades_for_agent(agent_id) do
    from(t in Trade, where: t.agent_id == ^agent_id, order_by: [desc: t.executed_at])
    |> Repo.all()
  end

  @doc """
  Gets recent trades with limit.
  """
  def list_recent_trades(limit \\ 10) do
    from(t in Trade,
      order_by: [desc: t.executed_at],
      limit: ^limit,
      preload: [:agent]
    )
    |> Repo.all()
  end

  ## Statistics functions

  @doc """
  Gets trading statistics for all agents.
  """
  def get_trading_statistics do
    total_trades = Repo.aggregate(Trade, :count, :id)

    executed_trades =
      from(t in Trade, where: t.status == "executed")
      |> Repo.aggregate(:count, :id)

    total_pnl =
      from(t in Trade, where: t.status == "executed" and not is_nil(t.pnl))
      |> Repo.aggregate(:sum, :pnl) || Decimal.new("0.00")

    winning_trades =
      from(t in Trade, where: t.status == "executed" and t.pnl > 0)
      |> Repo.aggregate(:count, :id)

    win_rate = if executed_trades > 0, do: winning_trades / executed_trades * 100, else: 0.0

    %{
      total_trades: total_trades,
      executed_trades: executed_trades,
      pending_trades: total_trades - executed_trades,
      total_pnl: total_pnl,
      winning_trades: winning_trades,
      losing_trades: executed_trades - winning_trades,
      win_rate: win_rate
    }
  end

  @doc """
  Gets agent statistics.
  """
  def get_agent_statistics do
    total_agents = Repo.aggregate(TradingAgent, :count, :id)

    active_agents =
      from(a in TradingAgent, where: a.status == "active")
      |> Repo.aggregate(:count, :id)

    idle_agents =
      from(a in TradingAgent, where: a.status == "idle")
      |> Repo.aggregate(:count, :id)

    error_agents =
      from(a in TradingAgent, where: a.status == "error")
      |> Repo.aggregate(:count, :id)

    %{
      total_count: total_agents,
      active_count: active_agents,
      idle_count: idle_agents,
      error_count: error_agents,
      stopped_count: total_agents - active_agents - idle_agents - error_agents
    }
  end

  @doc """
  Gets performance metrics for a specific agent.
  """
  def get_agent_performance(agent_id) do
    agent = get_agent!(agent_id)
    trades = list_trades_for_agent(agent_id)

    total_trades = length(trades)
    executed_trades = Enum.filter(trades, &(&1.status == "executed"))

    total_pnl =
      executed_trades
      |> Enum.map(&(&1.pnl || Decimal.new("0.00")))
      |> Enum.reduce(Decimal.new("0.00"), &Decimal.add/2)

    winning_trades = Enum.count(executed_trades, &Trade.profitable?/1)
    losing_trades = length(executed_trades) - winning_trades

    win_rate =
      if length(executed_trades) > 0,
        do: winning_trades / length(executed_trades) * 100,
        else: 0.0

    %{
      agent: agent,
      total_trades: total_trades,
      executed_trades: length(executed_trades),
      pending_trades: total_trades - length(executed_trades),
      winning_trades: winning_trades,
      losing_trades: losing_trades,
      win_rate: win_rate,
      total_pnl: total_pnl,
      current_balance: agent.balance || Decimal.new("0.00"),
      last_activity: agent.last_trade_at
    }
  end
end
