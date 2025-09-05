defmodule TradingSwarm.Repo do
  use Ecto.Repo,
    otp_app: :trading_swarm,
    adapter: Ecto.Adapters.Postgres
end
