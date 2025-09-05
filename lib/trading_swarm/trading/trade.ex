defmodule TradingSwarm.Trading.Trade do
  @moduledoc """
  Schema for individual trades executed by trading agents.

  Each trade record contains execution details, P&L information,
  and metadata for analysis and reporting.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias TradingSwarm.Trading.TradingAgent

  schema "trades" do
    field :symbol, :string
    field :side, :string
    field :type, :string
    field :quantity, :decimal
    field :price, :decimal
    field :executed_at, :utc_datetime
    field :status, :string, default: "pending"
    field :pnl, :decimal
    field :fees, :decimal
    field :metadata, :map

    belongs_to :agent, TradingAgent, foreign_key: :agent_id

    timestamps(type: :utc_datetime)
  end

  @side_values ~w(buy sell)
  @type_values ~w(market limit stop stop_limit)
  @status_values ~w(pending executed cancelled failed)
  @required_fields ~w(symbol side type quantity price executed_at status agent_id)a
  @optional_fields ~w(pnl fees metadata)a

  @doc false
  def changeset(trade, attrs) do
    trade
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:side, @side_values)
    |> validate_inclusion(:type, @type_values)
    |> validate_inclusion(:status, @status_values)
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:price, greater_than: 0)
    |> validate_number(:fees, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:agent_id)
  end

  @doc """
  Returns true if the trade was profitable.
  """
  def profitable?(%__MODULE__{pnl: pnl}) when is_nil(pnl), do: false
  def profitable?(%__MODULE__{pnl: pnl}), do: Decimal.gt?(pnl, 0)

  @doc """
  Returns true if the trade is completed (executed).
  """
  def completed?(%__MODULE__{status: "executed"}), do: true
  def completed?(_), do: false

  @doc """
  Returns the trade value (quantity * price).
  """
  def trade_value(%__MODULE__{quantity: quantity, price: price}) do
    Decimal.mult(quantity, price)
  end

  @doc """
  Calculates the net P&L after fees.
  """
  def net_pnl(%__MODULE__{pnl: nil}), do: nil
  def net_pnl(%__MODULE__{pnl: pnl, fees: nil}), do: pnl

  def net_pnl(%__MODULE__{pnl: pnl, fees: fees}) do
    Decimal.sub(pnl, fees)
  end
end
