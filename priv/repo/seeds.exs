# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     TradingSwarm.Repo.insert!(%TradingSwarm.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias TradingSwarm.Repo
alias TradingSwarm.Trading.TradingAgent
alias TradingSwarm.System.SystemConfiguration

# Insert default system configurations
system_configs = [
  %{
    key: "max_concurrent_trades",
    value: "100",
    description: "Maximum number of concurrent trades across all agents",
    category: "trading"
  },
  %{
    key: "global_risk_limit",
    value: "0.02",
    description: "Global risk limit as percentage of total portfolio",
    category: "risk_management"
  },
  %{
    key: "market_data_refresh_interval",
    value: "5000",
    description: "Market data refresh interval in milliseconds",
    category: "market_data"
  },
  %{
    key: "nvidia_api_enabled",
    value: "true",
    description: "Enable NVIDIA API for AI analysis",
    category: "api"
  },
  %{
    key: "correlation_threshold",
    value: "0.7",
    description: "Correlation threshold for risk analysis",
    category: "risk_management"
  },
  %{
    key: "notification_webhook_url",
    value: "http://localhost:4000/webhooks/notifications",
    description: "Webhook URL for trading notifications",
    category: "notifications"
  }
]

Enum.each(system_configs, fn config ->
  %SystemConfiguration{}
  |> SystemConfiguration.changeset(config)
  |> Repo.insert!(on_conflict: :nothing)
end)

# Insert sample trading agents
trading_agents = [
  %{
    name: "Momentum Trader Alpha",
    status: "idle",
    balance: Decimal.new("10000.00"),
    risk_tolerance: Decimal.new("0.05"),
    strategy_params: %{
      "strategy_type" => "momentum",
      "lookback_period" => 20,
      "momentum_threshold" => 0.02,
      "stop_loss_pct" => 0.03,
      "take_profit_pct" => 0.06
    }
  },
  %{
    name: "Mean Reversion Beta",
    status: "idle",
    balance: Decimal.new("15000.00"),
    risk_tolerance: Decimal.new("0.03"),
    strategy_params: %{
      "strategy_type" => "mean_reversion",
      "rsi_oversold" => 30,
      "rsi_overbought" => 70,
      "bollinger_std" => 2.0,
      "stop_loss_pct" => 0.025,
      "take_profit_pct" => 0.04
    }
  },
  %{
    name: "Scalper Gamma",
    status: "idle",
    balance: Decimal.new("5000.00"),
    risk_tolerance: Decimal.new("0.10"),
    strategy_params: %{
      "strategy_type" => "scalping",
      "timeframe" => "1m",
      "profit_target" => 0.001,
      "max_hold_time" => 300,
      "volume_threshold" => 1000000
    }
  },
  %{
    name: "Swing Trader Delta",
    status: "idle",
    balance: Decimal.new("20000.00"),
    risk_tolerance: Decimal.new("0.04"),
    strategy_params: %{
      "strategy_type" => "swing",
      "timeframe" => "4h",
      "trend_strength_min" => 0.6,
      "fibonacci_levels" => [0.236, 0.382, 0.618],
      "stop_loss_pct" => 0.04,
      "take_profit_pct" => 0.08
    }
  }
]

Enum.each(trading_agents, fn agent ->
  %TradingAgent{}
  |> TradingAgent.changeset(agent)
  |> Repo.insert!(on_conflict: :nothing)
end)

IO.puts("✅ Seed data inserted successfully!")
IO.puts("📊 Created #{length(system_configs)} system configurations")
IO.puts("🤖 Created #{length(trading_agents)} trading agents")
