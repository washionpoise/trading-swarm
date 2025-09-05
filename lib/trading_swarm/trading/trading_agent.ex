defmodule TradingSwarm.Trading.TradingAgent do
  @moduledoc """
  Schema for trading agents in the swarm system.

  Each agent represents an autonomous trading entity with its own balance,
  risk tolerance, and strategy parameters.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias TradingSwarm.Trading.Trade
  alias TradingSwarm.Risk.RiskEvent
  alias TradingSwarm.Analytics.PerformanceMetric

  schema "trading_agents" do
    field :name, :string
    field :status, :string, default: "idle"
    field :balance, :decimal
    field :risk_tolerance, :decimal
    field :strategy_params, :map
    field :last_trade_at, :utc_datetime
    field :total_trades, :integer, default: 0
    field :winning_trades, :integer, default: 0
    field :losing_trades, :integer, default: 0

    has_many :trades, Trade, foreign_key: :agent_id
    has_many :risk_events, RiskEvent, foreign_key: :agent_id
    has_many :performance_metrics, PerformanceMetric, foreign_key: :agent_id

    timestamps(type: :utc_datetime)
  end

  @status_values ~w(idle active stopped error)
  @required_fields ~w(name status)a
  @optional_fields ~w(balance risk_tolerance strategy_params last_trade_at total_trades winning_trades losing_trades)a

  @doc false
  def changeset(agent, attrs) do
    agent
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, @status_values)
    |> validate_number(:balance, greater_than_or_equal_to: 0)
    |> validate_number(:risk_tolerance, greater_than: 0, less_than_or_equal_to: 1)
    |> validate_number(:total_trades, greater_than_or_equal_to: 0)
    |> validate_number(:winning_trades, greater_than_or_equal_to: 0)
    |> validate_number(:losing_trades, greater_than_or_equal_to: 0)
    |> unique_constraint(:name)
  end

  @doc """
  Returns the win rate for the agent as a percentage.
  """
  def win_rate(%__MODULE__{total_trades: 0}), do: 0.0

  def win_rate(%__MODULE__{total_trades: total, winning_trades: winning}) do
    winning / total * 100
  end

  @doc """
  Returns true if the agent is currently active.
  """
  def active?(%__MODULE__{status: "active"}), do: true
  def active?(_), do: false

  @doc """
  Returns true if the agent is stopped or in error state.
  """
  def stopped?(%__MODULE__{status: status}) when status in ["stopped", "error"], do: true
  def stopped?(_), do: false
end
