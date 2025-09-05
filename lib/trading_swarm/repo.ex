defmodule TradingSwarm.Repo do
  use Ecto.Repo,
    otp_app: :trading_swarm,
    adapter: Ecto.Adapters.Postgres
    
  @doc """
  Paginates a query using our custom pagination module.
  """
  def paginate(query, opts \\ []) do
    TradingSwarm.Pagination.paginate(query, opts)
  end
end
