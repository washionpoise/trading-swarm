defmodule TradingSwarmWeb.Router do
  use TradingSwarmWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TradingSwarmWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", TradingSwarmWeb do
    pipe_through :browser

    get "/", PageController, :home

    # Dashboard LiveView
    live "/dashboard", DashboardLive, :index

    # Agent management routes
    resources "/agents", AgentController do
      post "/toggle_status", AgentController, :toggle_status
    end

    # Rehoboam AI surveillance routes
    scope "/rehoboam" do
      get "/predictions", RehoboamController, :predictions
      get "/surveillance", RehoboamController, :surveillance
      get "/behavioral_profiles", RehoboamController, :behavioral_profiles
      get "/agent_loop/:agent_id", RehoboamController, :agent_loop
      post "/predict_behavior/:agent_id", RehoboamController, :predict_behavior
      post "/detect_divergence/:agent_id", RehoboamController, :detect_divergence
      post "/intervention_strategy/:agent_id", RehoboamController, :intervention_strategy
      get "/market_destiny", RehoboamController, :market_destiny
    end

    # Trading routes
    scope "/trading" do
      get "/", TradingController, :index
      get "/statistics", TradingController, :statistics
      get "/by_agent/:agent_id", TradingController, :by_agent
      get "/export", TradingController, :export
      get "/:id", TradingController, :show
    end

    # Risk management routes
    scope "/risk" do
      get "/dashboard", RiskController, :dashboard
      get "/exposure", RiskController, :exposure
      get "/correlation_matrix", RiskController, :correlation_matrix
      get "/events", RiskController, :events
      post "/events/:id/resolve", RiskController, :resolve_event
      get "/limits", RiskController, :limits
      post "/limits", RiskController, :update_limits
      get "/current_risk", RiskController, :api_current_risk
    end
  end

  # API routes
  scope "/api/v1", TradingSwarmWeb.API do
    pipe_through :api

    # Agent API routes
    resources "/agents", AgentController, except: [:new, :edit] do
      post "/toggle_status", AgentController, :toggle_status
      get "/performance", AgentController, :performance
    end

    # Rehoboam AI API routes
    scope "/rehoboam" do
      get "/status", RehoboamController, :status
      get "/predictions", RehoboamController, :predictions
      post "/analyze_market", RehoboamController, :analyze_market
      get "/agent_loop/:agent_id", RehoboamController, :agent_loop
      post "/predict_behavior/:agent_id", RehoboamController, :predict_behavior
      post "/detect_divergence/:agent_id", RehoboamController, :detect_divergence
      post "/intervention_strategy/:agent_id", RehoboamController, :intervention_strategy
      get "/market_destiny", RehoboamController, :market_destiny
      get "/surveillance_data", RehoboamController, :surveillance_data
      post "/submit_behavior", RehoboamController, :submit_behavior
      post "/register_surveillance_stream", RehoboamController, :register_surveillance_stream
      get "/behavioral_analysis", RehoboamController, :behavioral_analysis
    end

    # Trading API routes
    scope "/trading" do
      get "/", TradingController, :index
      get "/statistics", TradingController, :statistics
      get "/by_agent/:agent_id", TradingController, :by_agent
      get "/performance", TradingController, :performance
      get "/export", TradingController, :export
      get "/realtime_metrics", TradingController, :realtime_metrics
      get "/:id", TradingController, :show
    end

    # Risk API routes
    scope "/risk" do
      get "/metrics", RiskController, :metrics
      get "/exposure", RiskController, :exposure
      get "/correlation", RiskController, :correlation
      get "/events", RiskController, :events
      get "/active_events", RiskController, :active_events
      get "/limits", RiskController, :limits
      post "/limits", RiskController, :update_limits
      post "/events/:id/resolve", RiskController, :resolve_event
      get "/var_analysis", RiskController, :var_analysis
      post "/stress_test", RiskController, :stress_test
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:trading_swarm, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TradingSwarmWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
