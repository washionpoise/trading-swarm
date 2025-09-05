defmodule TradingSwarmWeb.TradingComponents do
  @moduledoc """
  Reusable components for trading-specific UI elements.
  """
  
  use Phoenix.Component
  use Phoenix.HTML
  
  @doc """
  Renders a trading card with P&L display
  """
  attr :title, :string, required: true
  attr :value, :any, required: true
  attr :change, :any, default: nil
  attr :icon, :string, default: nil
  attr :class, :string, default: ""
  
  def trading_metric_card(assigns) do
    pnl_color = cond do
      is_number(assigns.change) and assigns.change > 0 -> "text-green-600 dark:text-green-400"
      is_number(assigns.change) and assigns.change < 0 -> "text-red-600 dark:text-red-400"
      true -> "text-gray-600 dark:text-gray-400"
    end
    
    assigns = assign(assigns, :pnl_color, pnl_color)
    
    ~H"""
    <div class={"bg-white dark:bg-gray-800 rounded-lg shadow-md p-6 #{@class}"}>
      <div class="flex items-center justify-between">
        <div>
          <p class="text-sm font-medium text-gray-600 dark:text-gray-400"><%= @title %></p>
          <p class="text-2xl font-bold text-gray-900 dark:text-white mt-2">
            <%= format_currency(@value) %>
          </p>
          <%= if @change do %>
            <p class={"text-sm mt-1 #{@pnl_color}"}>
              <%= format_change(@change) %>
            </p>
          <% end %>
        </div>
        <%= if @icon do %>
          <div class="text-3xl text-gray-400">
            <%= @icon %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
  
  @doc """
  Renders a status badge
  """
  attr :status, :atom, required: true
  attr :class, :string, default: ""
  
  def status_badge(assigns) do
    {bg_class, text_class} = case assigns.status do
      :active -> {"bg-green-100 dark:bg-green-900", "text-green-800 dark:text-green-200"}
      :idle -> {"bg-yellow-100 dark:bg-yellow-900", "text-yellow-800 dark:text-yellow-200"}
      :error -> {"bg-red-100 dark:bg-red-900", "text-red-800 dark:text-red-200"}
      :offline -> {"bg-gray-100 dark:bg-gray-700", "text-gray-800 dark:text-gray-200"}
      :excellent -> {"bg-emerald-100 dark:bg-emerald-900", "text-emerald-800 dark:text-emerald-200"}
      :good -> {"bg-green-100 dark:bg-green-900", "text-green-800 dark:text-green-200"}
      :fair -> {"bg-yellow-100 dark:bg-yellow-900", "text-yellow-800 dark:text-yellow-200"}
      :poor -> {"bg-orange-100 dark:bg-orange-900", "text-orange-800 dark:text-orange-200"}
      :critical -> {"bg-red-100 dark:bg-red-900", "text-red-800 dark:text-red-200"}
      _ -> {"bg-gray-100 dark:bg-gray-700", "text-gray-800 dark:text-gray-200"}
    end
    
    assigns = assign(assigns, :bg_class, bg_class)
    assigns = assign(assigns, :text_class, text_class)
    
    ~H"""
    <span class={"inline-flex px-2 py-1 text-xs font-semibold rounded-full #{@bg_class} #{@text_class} #{@class}"}>
      <%= String.capitalize(to_string(@status)) %>
    </span>
    """
  end
  
  @doc """
  Renders a trade row for the trades table
  """
  attr :trade, :map, required: true
  
  def trade_row(assigns) do
    ~H"""
    <tr class="hover:bg-gray-50 dark:hover:bg-gray-700">
      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-white">
        <%= @trade.symbol %>
      </td>
      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
        <%= @trade.type %>
      </td>
      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-white">
        <%= format_number(@trade.quantity) %>
      </td>
      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-white">
        $<%= format_number(@trade.price, 2) %>
      </td>
      <td class={"px-6 py-4 whitespace-nowrap text-sm #{if @trade.pnl >= 0, do: "text-green-600", else: "text-red-600"}"}>
        <%= format_pnl(@trade.pnl) %>
      </td>
      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
        <%= format_timestamp(@trade.timestamp) %>
      </td>
    </tr>
    """
  end
  
  @doc """
  Renders an agent card
  """
  attr :agent, :map, required: true
  attr :on_toggle, :any, default: nil
  
  def agent_card(assigns) do
    ~H"""
    <div class="bg-white dark:bg-gray-800 rounded-lg shadow-md p-6">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
          <%= @agent.name || "Agent #{@agent.id}" %>
        </h3>
        <.status_badge status={@agent.status} />
      </div>
      
      <div class="space-y-2 mb-4">
        <div class="flex justify-between text-sm">
          <span class="text-gray-600 dark:text-gray-400">Total P&L:</span>
          <span class={"font-medium #{if @agent.total_pnl >= 0, do: "text-green-600", else: "text-red-600"}"}>
            <%= format_currency(@agent.total_pnl) %>
          </span>
        </div>
        <div class="flex justify-between text-sm">
          <span class="text-gray-600 dark:text-gray-400">Trades:</span>
          <span class="text-gray-900 dark:text-white"><%= @agent.trade_count || 0 %></span>
        </div>
        <div class="flex justify-between text-sm">
          <span class="text-gray-600 dark:text-gray-400">Win Rate:</span>
          <span class="text-gray-900 dark:text-white">
            <%= :erlang.float_to_binary((@agent.win_rate || 0) * 100, decimals: 1) %>%
          </span>
        </div>
      </div>
      
      <%= if @on_toggle do %>
        <button 
          phx-click={@on_toggle}
          phx-value-agent_id={@agent.id}
          class={"w-full px-4 py-2 rounded-lg text-sm font-medium transition-colors #{
            if @agent.status == :active,
              do: "bg-red-600 hover:bg-red-700 text-white",
              else: "bg-green-600 hover:bg-green-700 text-white"
          }"}
        >
          <%= if @agent.status == :active, do: "Stop Agent", else: "Start Agent" %>
        </button>
      <% end %>
    </div>
    """
  end
  
  # Helper functions
  
  defp format_currency(value) when is_struct(value, Decimal) do
    "$#{Decimal.to_string(value, :normal)}"
  end
  
  defp format_currency(value) when is_number(value) do
    Number.Currency.number_to_currency(value)
  end
  
  defp format_currency(value), do: "$0.00"
  
  defp format_change(change) when is_number(change) do
    sign = if change >= 0, do: "+", else: ""
    "#{sign}#{Number.Currency.number_to_currency(change)}"
  end
  
  defp format_change(_), do: ""
  
  defp format_number(value, decimals \\ 0) when is_number(value) do
    Number.Delimit.number_to_delimited(value, precision: decimals)
  end
  
  defp format_number(value, _decimals) when is_struct(value, Decimal) do
    Decimal.to_string(value, :normal)
  end
  
  defp format_number(_, _), do: "0"
  
  defp format_pnl(pnl) when is_number(pnl) do
    sign = if pnl >= 0, do: "+", else: ""
    "#{sign}#{Number.Currency.number_to_currency(pnl)}"
  end
  
  defp format_pnl(_), do: "$0.00"
  
  defp format_timestamp(%DateTime{} = dt) do
    Timex.format!(dt, "{M}/{D} {h24}:{m}")
  end
  
  defp format_timestamp(_), do: ""
end