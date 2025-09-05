defmodule TradingSwarmWeb.DashboardComponents do
  @moduledoc """
  Reusable dashboard widget components.
  """

  use Phoenix.Component
  import Phoenix.HTML, only: [raw: 1]
  alias Phoenix.LiveView.JS

  @doc """
  Renders a dashboard metric widget
  """
  attr :title, :string, required: true
  attr :value, :any, required: true
  attr :subtitle, :string, default: nil
  attr :icon, :string, default: nil
  attr :trend, :atom, default: nil
  attr :trend_value, :string, default: nil
  attr :class, :string, default: ""

  def metric_widget(assigns) do
    trend_color =
      case assigns.trend do
        :up -> "text-green-600 dark:text-green-400"
        :down -> "text-red-600 dark:text-red-400"
        :neutral -> "text-gray-600 dark:text-gray-400"
        _ -> "text-gray-600 dark:text-gray-400"
      end

    trend_icon =
      case assigns.trend do
        :up -> "↗"
        :down -> "↘"
        :neutral -> "→"
        _ -> ""
      end

    assigns = assign(assigns, :trend_color, trend_color)
    assigns = assign(assigns, :trend_icon, trend_icon)

    ~H"""
    <div class={"bg-white dark:bg-gray-800 rounded-lg shadow-md p-6 #{@class}"}>
      <div class="flex items-center justify-between">
        <div class="flex-1">
          <p class="text-sm font-medium text-gray-600 dark:text-gray-400">
            {@title}
          </p>
          <p class="text-3xl font-bold text-gray-900 dark:text-white mt-2">
            {@value}
          </p>
          <%= if @subtitle do %>
            <p class="text-sm text-gray-500 dark:text-gray-400 mt-1">
              {@subtitle}
            </p>
          <% end %>
          <%= if @trend_value do %>
            <div class={"flex items-center mt-2 text-sm #{@trend_color}"}>
              <span class="mr-1">{@trend_icon}</span>
              {@trend_value}
            </div>
          <% end %>
        </div>
        <%= if @icon do %>
          <div class="text-4xl text-gray-400 dark:text-gray-500">
            {raw(@icon)}
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Renders a progress bar
  """
  attr :label, :string, required: true
  attr :value, :float, required: true
  attr :max_value, :float, default: 100.0
  attr :color, :string, default: "blue"
  attr :show_percentage, :boolean, default: true

  def progress_bar(assigns) do
    percentage = min(assigns.value / assigns.max_value * 100, 100)

    color_classes =
      case assigns.color do
        "green" -> "bg-green-500"
        "red" -> "bg-red-500"
        "yellow" -> "bg-yellow-500"
        "blue" -> "bg-blue-500"
        _ -> "bg-blue-500"
      end

    assigns = assign(assigns, :percentage, percentage)
    assigns = assign(assigns, :color_classes, color_classes)

    ~H"""
    <div class="mb-4">
      <div class="flex justify-between mb-1">
        <span class="text-sm font-medium text-gray-700 dark:text-gray-300">
          {@label}
        </span>
        <%= if @show_percentage do %>
          <span class="text-sm font-medium text-gray-700 dark:text-gray-300">
            {:erlang.float_to_binary(@percentage, decimals: 1)}%
          </span>
        <% end %>
      </div>
      <div class="w-full bg-gray-200 rounded-full h-2 dark:bg-gray-700">
        <div
          class={"#{@color_classes} h-2 rounded-full transition-all duration-300 ease-in-out"}
          style={"width: #{@percentage}%"}
        >
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a system health indicator
  """
  attr :health, :atom, required: true
  attr :class, :string, default: ""

  def health_indicator(assigns) do
    {bg_class, border_class, text_class, icon} =
      case assigns.health do
        :excellent ->
          {"bg-green-50 dark:bg-green-900", "border-green-200 dark:border-green-700",
           "text-green-800 dark:text-green-200", "💚"}

        :good ->
          {"bg-emerald-50 dark:bg-emerald-900", "border-emerald-200 dark:border-emerald-700",
           "text-emerald-800 dark:text-emerald-200", "💚"}

        :fair ->
          {"bg-yellow-50 dark:bg-yellow-900", "border-yellow-200 dark:border-yellow-700",
           "text-yellow-800 dark:text-yellow-200", "💛"}

        :poor ->
          {"bg-orange-50 dark:bg-orange-900", "border-orange-200 dark:border-orange-700",
           "text-orange-800 dark:text-orange-200", "🧡"}

        :critical ->
          {"bg-red-50 dark:bg-red-900", "border-red-200 dark:border-red-700",
           "text-red-800 dark:text-red-200", "❤️"}

        _ ->
          {"bg-gray-50 dark:bg-gray-700", "border-gray-200 dark:border-gray-600",
           "text-gray-800 dark:text-gray-200", "⚪"}
      end

    assigns = assign(assigns, :bg_class, bg_class)
    assigns = assign(assigns, :border_class, border_class)
    assigns = assign(assigns, :text_class, text_class)
    assigns = assign(assigns, :icon, icon)

    ~H"""
    <div class={"rounded-lg border-2 p-4 #{@bg_class} #{@border_class} #{@class}"}>
      <div class="flex items-center space-x-3">
        <span class="text-2xl">{@icon}</span>
        <div>
          <h3 class={"text-lg font-semibold #{@text_class}"}>
            System Health: {String.capitalize(to_string(@health))}
          </h3>
          <p class={"text-sm #{@text_class} opacity-75"}>
            {health_description(@health)}
          </p>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a loading skeleton
  """
  attr :class, :string, default: ""

  def loading_skeleton(assigns) do
    ~H"""
    <div class={"animate-pulse #{@class}"}>
      <div class="bg-gray-200 dark:bg-gray-700 rounded h-4 mb-2"></div>
      <div class="bg-gray-200 dark:bg-gray-700 rounded h-4 w-3/4 mb-2"></div>
      <div class="bg-gray-200 dark:bg-gray-700 rounded h-4 w-1/2"></div>
    </div>
    """
  end

  @doc """
  Renders a refresh button
  """
  attr :on_click, :any, required: true
  attr :loading, :boolean, default: false
  attr :class, :string, default: ""

  def refresh_button(assigns) do
    ~H"""
    <button
      phx-click={@on_click}
      disabled={@loading}
      class={"inline-flex items-center px-3 py-2 border border-gray-300 dark:border-gray-600 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 dark:text-gray-200 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 #{@class}"}
    >
      <%= if @loading do %>
        <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-gray-500" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4">
          </circle>
          <path
            class="opacity-75"
            fill="currentColor"
            d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
          >
          </path>
        </svg>
        Refreshing...
      <% else %>
        <svg
          class="-ml-1 mr-2 h-4 w-4 text-gray-500"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
          >
          </path>
        </svg>
        Refresh
      <% end %>
    </button>
    """
  end

  @doc """
  Renders the last updated timestamp
  """
  attr :timestamp, :any, required: true
  attr :class, :string, default: ""

  def last_updated(assigns) do
    ~H"""
    <p class={"text-xs text-gray-500 dark:text-gray-400 #{@class}"}>
      Last updated: {format_relative_time(@timestamp)}
    </p>
    """
  end

  @doc """
  Navigation bar for TradingSwarm application.
  """
  attr :current_path, :string, required: true
  attr :class, :string, default: ""

  def trading_nav(assigns) do
    ~H"""
    <nav class={[
      "bg-white dark:bg-gray-800 shadow-lg border-b border-gray-200 dark:border-gray-700",
      @class
    ]}>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16">
          <!-- Logo/Brand -->
          <div class="flex items-center">
            <div class="flex-shrink-0 flex items-center">
              <div class="text-2xl mr-3">🚀</div>
              <span class="text-xl font-bold text-gray-900 dark:text-white">
                TradingSwarm
              </span>
            </div>
          </div>
          
    <!-- Desktop Navigation Links -->
          <div class="hidden lg:flex items-center space-x-8">
            <.nav_link
              path="/app/dashboard"
              current_path={@current_path}
              icon="hero-home"
              label="Dashboard"
            />
            <.nav_link
              path="/app/agents"
              current_path={@current_path}
              icon="hero-users"
              label="Agents"
            />
            <.nav_link
              path="/app/surveillance"
              current_path={@current_path}
              icon="hero-eye"
              label="AI Surveillance"
            />
            <.nav_link
              path="/app/trading"
              current_path={@current_path}
              icon="hero-chart-bar"
              label="Trading"
            />
            <.nav_link
              path="/app/risk"
              current_path={@current_path}
              icon="hero-shield-exclamation"
              label="Risk"
            />
          </div>
          
    <!-- Mobile menu button and User Menu -->
          <div class="flex items-center space-x-4">
            <!-- Mobile menu button -->
            <button
              class="lg:hidden p-2 rounded-md text-gray-400 hover:text-gray-500 hover:bg-gray-100 dark:hover:bg-gray-700"
              phx-click={JS.remove_attribute("hidden", to: "#mobile-nav")}
            >
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M4 6h16M4 12h16M4 18h16"
                />
              </svg>
            </button>
            
    <!-- User Menu (placeholder for future auth) -->
            <div class="hidden lg:flex items-center text-sm text-gray-500 dark:text-gray-400">
              <svg class="w-6 h-6 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
                />
              </svg>
              <span>System Admin</span>
            </div>
          </div>
        </div>
      </div>
    </nav>
    """
  end

  @doc """
  Individual navigation link component.
  """
  attr :path, :string, required: true
  attr :current_path, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true

  defp nav_link(assigns) do
    is_active = String.starts_with?(assigns.current_path, assigns.path)

    assigns = assign(assigns, :is_active, is_active)

    ~H"""
    <.link
      navigate={@path}
      class={[
        "flex items-center px-3 py-2 rounded-md text-sm font-medium transition-colors duration-200",
        if(@is_active,
          do: "text-blue-600 dark:text-blue-400 bg-blue-50 dark:bg-blue-900/20",
          else:
            "text-gray-500 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white hover:bg-gray-50 dark:hover:bg-gray-700"
        )
      ]}
    >
      <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d={icon_path(@icon)} />
      </svg>
      {@label}
    </.link>
    """
  end

  @doc """
  Mobile-friendly navigation sidebar.
  """
  attr :current_path, :string, required: true
  attr :class, :string, default: ""

  def mobile_nav_sidebar(assigns) do
    ~H"""
    <div id="mobile-nav" class={["fixed inset-0 z-50 lg:hidden", @class]} hidden>
      <!-- Background overlay -->
      <div
        class="fixed inset-0 bg-gray-600 bg-opacity-75"
        phx-click={JS.set_attribute({"hidden", ""}, to: "#mobile-nav")}
      />
      
    <!-- Sidebar panel -->
      <div class="fixed inset-y-0 left-0 flex flex-col w-64 bg-white dark:bg-gray-800 shadow-xl">
        <!-- Header -->
        <div class="flex items-center justify-between h-16 px-4 bg-gray-50 dark:bg-gray-900">
          <div class="flex items-center">
            <div class="text-2xl mr-3">🚀</div>
            <span class="text-lg font-bold text-gray-900 dark:text-white">
              TradingSwarm
            </span>
          </div>
          <button
            class="p-2 rounded-md text-gray-400 hover:text-gray-500 hover:bg-gray-100 dark:hover:bg-gray-700"
            phx-click={JS.set_attribute({"hidden", ""}, to: "#mobile-nav")}
          >
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M6 18L18 6M6 6l12 12"
              />
            </svg>
          </button>
        </div>
        
    <!-- Navigation Links -->
        <nav class="flex-1 px-4 py-4 space-y-2">
          <.mobile_nav_link
            path="/app/dashboard"
            current_path={@current_path}
            icon="hero-home"
            label="Dashboard"
          />
          <.mobile_nav_link
            path="/app/agents"
            current_path={@current_path}
            icon="hero-users"
            label="Agents"
          />
          <.mobile_nav_link
            path="/app/surveillance"
            current_path={@current_path}
            icon="hero-eye"
            label="AI Surveillance"
          />
          <.mobile_nav_link
            path="/app/trading"
            current_path={@current_path}
            icon="hero-chart-bar"
            label="Trading"
          />
          <.mobile_nav_link
            path="/app/risk"
            current_path={@current_path}
            icon="hero-shield-exclamation"
            label="Risk"
          />
        </nav>
      </div>
    </div>
    """
  end

  @doc """
  Individual mobile navigation link component.
  """
  attr :path, :string, required: true
  attr :current_path, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true

  defp mobile_nav_link(assigns) do
    is_active = String.starts_with?(assigns.current_path, assigns.path)

    assigns = assign(assigns, :is_active, is_active)

    ~H"""
    <.link
      navigate={@path}
      class={[
        "flex items-center w-full px-4 py-3 rounded-lg text-sm font-medium transition-colors duration-200",
        if(@is_active,
          do: "text-blue-600 dark:text-blue-400 bg-blue-50 dark:bg-blue-900/20",
          else:
            "text-gray-700 dark:text-gray-300 hover:text-gray-900 dark:hover:text-white hover:bg-gray-50 dark:hover:bg-gray-700"
        )
      ]}
      phx-click={JS.set_attribute({"hidden", ""}, to: "#mobile-nav")}
    >
      <svg class="w-5 h-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d={icon_path(@icon)} />
      </svg>
      {@label}
    </.link>
    """
  end

  # Private helper functions

  defp health_description(:excellent), do: "All systems operating optimally"
  defp health_description(:good), do: "Systems running well with minor issues"
  defp health_description(:fair), do: "Some performance degradation detected"
  defp health_description(:poor), do: "Multiple issues affecting performance"
  defp health_description(:critical), do: "Critical issues requiring immediate attention"
  defp health_description(_), do: "System status unknown"

  defp format_relative_time(%DateTime{} = dt) do
    Timex.from_now(dt)
  end

  defp format_relative_time(_), do: "Unknown"

  # Icon path helper for Heroicons
  defp icon_path("hero-home"),
    do:
      "M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"

  defp icon_path("hero-users"),
    do:
      "M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z"

  defp icon_path("hero-eye"),
    do:
      "M15 12a3 3 0 11-6 0 3 3 0 016 0z M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"

  defp icon_path("hero-chart-bar"),
    do:
      "M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"

  defp icon_path("hero-shield-exclamation"),
    do:
      "M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"

  defp icon_path(_), do: "M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
end
