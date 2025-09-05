defmodule TradingSwarm.Analytics.PerformanceMetric do
  @moduledoc """
  Schema for daily performance metrics of trading agents.
  
  Stores aggregated daily performance data for analysis and reporting.
  """
  
  use Ecto.Schema
  import Ecto.Changeset

  alias TradingSwarm.Trading.TradingAgent

  schema "performance_metrics" do
    field :date, :date
    field :total_pnl, :decimal
    field :daily_pnl, :decimal
    field :drawdown, :decimal
    field :win_rate, :decimal
    field :total_trades, :integer, default: 0
    field :winning_trades, :integer, default: 0
    field :losing_trades, :integer, default: 0

    belongs_to :agent, TradingAgent, foreign_key: :agent_id

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(date agent_id)a
  @optional_fields ~w(total_pnl daily_pnl drawdown win_rate total_trades winning_trades losing_trades)a

  @doc false
  def changeset(performance_metric, attrs) do
    performance_metric
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:drawdown, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> validate_number(:win_rate, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> validate_number(:total_trades, greater_than_or_equal_to: 0)
    |> validate_number(:winning_trades, greater_than_or_equal_to: 0)
    |> validate_number(:losing_trades, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:agent_id)
    |> unique_constraint([:agent_id, :date])
  end

  @doc """
  Calculates win rate percentage from trades.
  """
  def calculate_win_rate(%__MODULE__{total_trades: 0}), do: 0.0
  def calculate_win_rate(%__MODULE__{total_trades: total, winning_trades: winning}) do
    (winning / total) * 100
  end

  @doc """
  Returns true if the agent had a profitable day.
  """
  def profitable_day?(%__MODULE__{daily_pnl: nil}), do: false
  def profitable_day?(%__MODULE__{daily_pnl: daily_pnl}), do: Decimal.gt?(daily_pnl, 0)

  @doc """
  Returns the loss rate as a decimal.
  """
  def loss_rate(%__MODULE__{total_trades: 0}), do: 0.0
  def loss_rate(%__MODULE__{total_trades: total, losing_trades: losing}) do
    losing / total
  end
end