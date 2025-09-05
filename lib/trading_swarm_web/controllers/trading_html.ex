defmodule TradingSwarmWeb.TradingHTML do
  @moduledoc """
  HTML templates and rendering functions for TradingController.

  Provides templates for:
  - Trading activity index and filtering
  - Agent-specific trading views
  - Trading statistics and analytics
  - Trade details and impact analysis
  """

  use TradingSwarmWeb, :html

  embed_templates "trading_html/*"
end
