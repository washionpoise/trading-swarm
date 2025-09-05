defmodule TradingSwarmWeb.ChartComponents do
  @moduledoc """
  Reusable chart components using Contex for server-side rendering.
  """

  use Phoenix.Component
  import Phoenix.HTML, only: [raw: 1]
  alias Contex.{Dataset, BarChart, LinePlot, Plot}

  @doc """
  Renders a line chart for performance metrics
  """
  attr :data, :list, required: true, doc: "List of {x, y} tuples for the chart"
  attr :title, :string, default: "Performance Chart"
  attr :width, :integer, default: 600
  attr :height, :integer, default: 300
  attr :x_label, :string, default: "Time"
  attr :y_label, :string, default: "Value"

  def performance_line_chart(assigns) do
    chart =
      assigns.data
      |> Dataset.new(["time", "value"])
      |> LinePlot.new(mapping: %{x_col: "time", y_cols: ["value"]})
      |> Plot.new(500, 400, assigns.title)
      |> Plot.titles(assigns.title)
      |> Plot.to_svg()

    assigns = assign(assigns, :chart_svg, chart)

    ~H"""
    <div class="bg-white dark:bg-gray-800 rounded-lg shadow-md p-4">
      <div class="w-full overflow-x-auto">
        {raw(@chart_svg)}
      </div>
    </div>
    """
  end

  @doc """
  Renders a bar chart for agent performance comparison
  """
  attr :data, :list, required: true, doc: "List of {label, value} tuples"
  attr :title, :string, default: "Agent Performance"
  attr :width, :integer, default: 600
  attr :height, :integer, default: 300

  def agent_performance_bar_chart(assigns) do
    chart =
      assigns.data
      |> Dataset.new(["agent", "performance"])
      |> BarChart.new(mapping: %{cat_col: "agent", val_cols: ["performance"]})
      |> Plot.new(500, 400, assigns.title)
      |> Plot.titles(assigns.title)
      |> Plot.to_svg()

    assigns = assign(assigns, :chart_svg, chart)

    ~H"""
    <div class="bg-white dark:bg-gray-800 rounded-lg shadow-md p-4">
      <div class="w-full overflow-x-auto">
        {raw(@chart_svg)}
      </div>
    </div>
    """
  end

  @doc """
  Renders a simple risk gauge using SVG
  """
  attr :risk_level, :float, required: true, doc: "Risk level from 0.0 to 1.0"
  attr :title, :string, default: "Risk Level"
  attr :size, :integer, default: 120

  def risk_gauge(assigns) do
    # Calculate gauge position (180 degrees arc)
    # -90 to 90 degrees
    angle = assigns.risk_level * 180 - 90
    radius = assigns.size / 2 - 20
    center_x = assigns.size / 2
    center_y = assigns.size / 2

    # Calculate needle position
    needle_x = center_x + radius * :math.cos(angle * :math.pi() / 180)
    needle_y = center_y + radius * :math.sin(angle * :math.pi() / 180)

    # Determine color based on risk level
    color =
      cond do
        # green
        assigns.risk_level < 0.3 -> "#10B981"
        # yellow
        assigns.risk_level < 0.7 -> "#F59E0B"
        # red
        true -> "#EF4444"
      end

    assigns = assign(assigns, :needle_x, needle_x)
    assigns = assign(assigns, :needle_y, needle_y)
    assigns = assign(assigns, :center_x, center_x)
    assigns = assign(assigns, :center_y, center_y)
    assigns = assign(assigns, :radius, radius)
    assigns = assign(assigns, :color, color)

    ~H"""
    <div class="bg-white dark:bg-gray-800 rounded-lg shadow-md p-4 text-center">
      <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">{@title}</h3>
      <svg width={@size} height={@size} viewBox={"0 0 #{@size} #{@size}"} class="mx-auto">
        <!-- Gauge arc background -->
        <path
          d={"M #{@center_x - @radius} #{@center_y} A #{@radius} #{@radius} 0 0 1 #{@center_x + @radius} #{@center_y}"}
          fill="none"
          stroke="#E5E7EB"
          stroke-width="8"
        />
        
    <!-- Gauge arc colored portion -->
        <path
          d={"M #{@center_x - @radius} #{@center_y} A #{@radius} #{@radius} 0 0 1 #{@needle_x} #{@needle_y}"}
          fill="none"
          stroke={@color}
          stroke-width="8"
        />
        
    <!-- Needle -->
        <line
          x1={@center_x}
          y1={@center_y}
          x2={@needle_x}
          y2={@needle_y}
          stroke={@color}
          stroke-width="3"
        />
        
    <!-- Center dot -->
        <circle cx={@center_x} cy={@center_y} r="4" fill={@color} />
      </svg>
      <div class="text-sm text-gray-600 dark:text-gray-400 mt-2">
        {:erlang.float_to_binary(@risk_level * 100, decimals: 1)}%
      </div>
    </div>
    """
  end
end
