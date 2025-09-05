defmodule TradingSwarm.Repo.Migrations.CreateTradingCoreTables do
  use Ecto.Migration

  def change do
    # Trading Agents table
    create table(:trading_agents) do
      add :name, :string, null: false
      add :status, :string, null: false, default: "idle"
      add :balance, :decimal, precision: 15, scale: 2, default: 0.0
      add :risk_tolerance, :decimal, precision: 5, scale: 4, default: 0.02
      add :strategy_params, :map, default: %{}
      add :last_trade_at, :utc_datetime
      add :total_trades, :integer, default: 0
      add :winning_trades, :integer, default: 0
      add :losing_trades, :integer, default: 0
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:trading_agents, [:name])
    create index(:trading_agents, [:status])

    # Trades table
    create table(:trades) do
      add :agent_id, references(:trading_agents, on_delete: :delete_all)
      add :symbol, :string, null: false
      add :side, :string, null: false # "buy" or "sell"
      add :type, :string, null: false # "market", "limit", etc
      add :quantity, :decimal, precision: 20, scale: 8, null: false
      add :price, :decimal, precision: 15, scale: 8, null: false
      add :executed_at, :utc_datetime, null: false
      add :status, :string, null: false, default: "pending"
      add :pnl, :decimal, precision: 15, scale: 2
      add :fees, :decimal, precision: 15, scale: 8, default: 0.0
      add :metadata, :map, default: %{}
      
      timestamps(type: :utc_datetime)
    end

    create index(:trades, [:agent_id])
    create index(:trades, [:symbol])
    create index(:trades, [:executed_at])
    create index(:trades, [:status])

    # Risk Events table
    create table(:risk_events) do
      add :agent_id, references(:trading_agents, on_delete: :delete_all)
      add :event_type, :string, null: false # "drawdown_warning", "limit_exceeded", etc
      add :severity, :string, null: false # "low", "medium", "high", "critical"
      add :message, :text, null: false
      add :metadata, :map, default: %{}
      add :resolved, :boolean, default: false
      add :resolved_at, :utc_datetime
      
      timestamps(type: :utc_datetime)
    end

    create index(:risk_events, [:agent_id])
    create index(:risk_events, [:event_type])
    create index(:risk_events, [:severity])
    create index(:risk_events, [:resolved])

    # Performance Metrics table
    create table(:performance_metrics) do
      add :agent_id, references(:trading_agents, on_delete: :delete_all)
      add :date, :date, null: false
      add :total_pnl, :decimal, precision: 15, scale: 2, default: 0.0
      add :daily_pnl, :decimal, precision: 15, scale: 2, default: 0.0
      add :drawdown, :decimal, precision: 5, scale: 4, default: 0.0
      add :win_rate, :decimal, precision: 5, scale: 4, default: 0.0
      add :total_trades, :integer, default: 0
      add :winning_trades, :integer, default: 0
      add :losing_trades, :integer, default: 0
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:performance_metrics, [:agent_id, :date])
    create index(:performance_metrics, [:date])

    # Market Data table for historical data
    create table(:market_data) do
      add :symbol, :string, null: false
      add :timestamp, :utc_datetime, null: false
      add :open, :decimal, precision: 15, scale: 8
      add :high, :decimal, precision: 15, scale: 8
      add :low, :decimal, precision: 15, scale: 8
      add :close, :decimal, precision: 15, scale: 8, null: false
      add :volume, :decimal, precision: 20, scale: 8
      add :timeframe, :string, null: false # "1m", "5m", "1h", "1d"
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:market_data, [:symbol, :timestamp, :timeframe])
    create index(:market_data, [:symbol, :timeframe])

    # System Configuration table
    create table(:system_configurations) do
      add :key, :string, null: false
      add :value, :text, null: false
      add :description, :string
      add :category, :string, default: "general"
      add :encrypted, :boolean, default: false
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:system_configurations, [:key])
    create index(:system_configurations, [:category])
  end
end
