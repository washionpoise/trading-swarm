defmodule TradingSwarmWeb.PageController do
  use TradingSwarmWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
