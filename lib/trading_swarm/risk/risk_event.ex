defmodule TradingSwarm.Risk.RiskEvent do
  @moduledoc """
  Schema for risk management events in the trading system.
  
  Risk events track important system alerts, warnings, and violations
  that require attention or have been resolved.
  """
  
  use Ecto.Schema
  import Ecto.Changeset

  alias TradingSwarm.Trading.TradingAgent

  schema "risk_events" do
    field :event_type, :string
    field :severity, :string
    field :message, :string
    field :metadata, :map
    field :resolved, :boolean, default: false
    field :resolved_at, :utc_datetime

    belongs_to :agent, TradingAgent, foreign_key: :agent_id

    timestamps(type: :utc_datetime)
  end

  @event_types ~w(drawdown_warning position_limit_exceeded correlation_violation emergency_stop system_error)
  @severity_levels ~w(low medium high critical)
  @required_fields ~w(event_type severity message agent_id)a
  @optional_fields ~w(metadata resolved resolved_at)a

  @doc false
  def changeset(risk_event, attrs) do
    risk_event
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:event_type, @event_types)
    |> validate_inclusion(:severity, @severity_levels)
    |> validate_length(:message, min: 1, max: 1000)
    |> foreign_key_constraint(:agent_id)
  end

  @doc """
  Changeset for resolving a risk event.
  """
  def resolve_changeset(risk_event, attrs \\ %{}) do
    risk_event
    |> cast(attrs, [:resolved, :resolved_at])
    |> put_change(:resolved, true)
    |> put_change(:resolved_at, DateTime.utc_now())
  end

  @doc """
  Returns true if the event is critical severity.
  """
  def critical?(%__MODULE__{severity: "critical"}), do: true
  def critical?(_), do: false

  @doc """
  Returns true if the event is resolved.
  """
  def resolved?(%__MODULE__{resolved: true}), do: true
  def resolved?(_), do: false

  @doc """
  Returns the age of the event in hours.
  """
  def age_in_hours(%__MODULE__{inserted_at: inserted_at}) do
    now = DateTime.utc_now()
    DateTime.diff(now, inserted_at, :hour)
  end
end