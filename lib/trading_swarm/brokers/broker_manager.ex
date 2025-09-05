defmodule TradingSwarm.Brokers.BrokerManager do
  @moduledoc """
  Central manager for multiple trading platforms integration.

  Supports:
  - Crypto: Kraken
  - Forex: Markets4you, TIOmarkets, RoboForex, Capital.com, Exness  
  - Binary Options: Pocket Option, Olymp Trade, IQ Option, Quotex
  """

  use GenServer
  require Logger

  alias TradingSwarm.Brokers.{KrakenClient, Markets4youClient}
  alias TradingSwarm.Brokers.BinaryOptions.{PocketOptionClient, OlympTradeClient}
  alias TradingSwarm.Brokers.Forex.{TIOmarketsClient, RoboForexClient}

  @broker_configs %{
    # Crypto
    kraken: %{
      name: "Kraken",
      type: :crypto,
      min_deposit: 0,
      min_withdrawal: "varies_by_crypto",
      features: [:high_security, :regulated],
      client: KrakenClient
    },

    # Forex
    markets4you: %{
      name: "Markets4you (Forex4you)",
      type: :forex,
      min_deposit: 0,
      min_withdrawal: 0,
      features: [:cent_account, :low_spreads],
      client: Markets4youClient
    },
    tiomarkets: %{
      name: "TIOmarkets",
      type: :forex,
      min_deposit: 20,
      min_withdrawal: 50,
      features: [:multi_regulated, :unlimited_leverage],
      client: TIOmarketsClient
    },
    roboforex: %{
      name: "RoboForex",
      type: :forex,
      min_deposit: 10,
      min_withdrawal: 10,
      features: [:copy_trading, :low_deposit],
      client: RoboForexClient
    },

    # Binary Options
    pocket_option: %{
      name: "Pocket Option",
      type: :binary_options,
      min_deposit: 5,
      min_withdrawal: 10,
      features: [:brazil_best, :variety_assets],
      client: PocketOptionClient
    },
    olymp_trade: %{
      name: "Olymp Trade",
      type: :binary_options,
      min_deposit: 10,
      min_withdrawal: 10,
      features: [:no_withdrawal_fees, :flexible_accounts],
      client: OlympTradeClient
    }
  }

  @default_routing_rules %{
    crypto: [:kraken],
    forex: [:markets4you, :tiomarkets, :roboforex],
    binary_options: [:pocket_option, :olymp_trade],
    scalping: [:markets4you, :kraken],
    swing_trading: [:tiomarkets, :roboforex]
  }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Logger.info("Starting Broker Manager with #{map_size(@broker_configs)} brokers")

    state = %{
      brokers: @broker_configs,
      routing_rules: @default_routing_rules,
      active_brokers: MapSet.new(),
      balance_cache: %{},
      last_update: DateTime.utc_now()
    }

    # Start broker clients
    start_broker_clients()

    {:ok, state}
  end

  # Public API

  @doc """
  Get available brokers by type or strategy.
  """
  def get_brokers(filter \\ :all) do
    GenServer.call(__MODULE__, {:get_brokers, filter})
  end

  @doc """
  Route trading order to optimal broker based on strategy and amount.
  """
  def route_order(order_params) do
    GenServer.call(__MODULE__, {:route_order, order_params})
  end

  @doc """
  Get broker configuration.
  """
  def get_broker_config(broker_id) do
    GenServer.call(__MODULE__, {:get_broker_config, broker_id})
  end

  @doc """
  Check withdrawal limits for all brokers.
  """
  def check_withdrawal_limits(amount) do
    GenServer.call(__MODULE__, {:check_withdrawal_limits, amount})
  end

  @doc """
  Get consolidated balance across all brokers.
  """
  def get_consolidated_balance() do
    GenServer.call(__MODULE__, :get_consolidated_balance)
  end

  # GenServer Callbacks

  def handle_call({:get_brokers, :all}, _from, state) do
    {:reply, state.brokers, state}
  end

  def handle_call({:get_brokers, filter}, _from, state) when is_atom(filter) do
    brokers =
      state.brokers
      |> Enum.filter(fn {_id, config} -> config.type == filter end)
      |> Enum.into(%{})

    {:reply, brokers, state}
  end

  def handle_call({:get_brokers, strategy}, _from, state) when is_binary(strategy) do
    strategy_atom = String.to_existing_atom(strategy)
    broker_ids = Map.get(state.routing_rules, strategy_atom, [])

    brokers =
      broker_ids
      |> Enum.map(fn id -> {id, state.brokers[id]} end)
      |> Enum.into(%{})

    {:reply, brokers, state}
  end

  def handle_call({:route_order, order_params}, _from, state) do
    %{
      strategy_type: strategy_type,
      amount: amount,
      symbol: symbol,
      side: side
    } = order_params

    optimal_broker = find_optimal_broker(order_params, state)

    case optimal_broker do
      nil ->
        {:reply, {:error, :no_suitable_broker}, state}

      broker_id ->
        broker_config = state.brokers[broker_id]

        result = %{
          broker_id: broker_id,
          broker_name: broker_config.name,
          broker_type: broker_config.type,
          min_deposit: broker_config.min_deposit,
          min_withdrawal: broker_config.min_withdrawal,
          features: broker_config.features,
          routed_at: DateTime.utc_now()
        }

        Logger.info("Order routed to #{broker_config.name} for #{strategy_type} strategy")
        {:reply, {:ok, result}, state}
    end
  end

  def handle_call({:get_broker_config, broker_id}, _from, state) do
    config = Map.get(state.brokers, broker_id)
    {:reply, config, state}
  end

  def handle_call({:check_withdrawal_limits, amount}, _from, state) do
    limits_check =
      state.brokers
      |> Enum.map(fn {broker_id, config} ->
        can_withdraw =
          case config.min_withdrawal do
            0 -> true
            # Need specific crypto check
            "varies_by_crypto" -> true
            min_amount when is_number(min_amount) -> amount >= min_amount
            _ -> false
          end

        {broker_id,
         %{
           broker_name: config.name,
           min_withdrawal: config.min_withdrawal,
           can_withdraw: can_withdraw,
           deficit: if(can_withdraw, do: 0, else: config.min_withdrawal - amount)
         }}
      end)
      |> Enum.into(%{})

    {:reply, limits_check, state}
  end

  def handle_call(:get_consolidated_balance, _from, state) do
    # Fetch balances from all active brokers
    consolidated = fetch_all_balances(state)

    {:reply, consolidated, state}
  end

  # Private Functions

  defp start_broker_clients() do
    # Start broker clients based on available credentials
    start_available_clients()
    Logger.info("Broker clients initialization completed")
  end

  defp find_optimal_broker(order_params, state) do
    %{strategy_type: strategy_type, amount: amount} = order_params

    # Get brokers for strategy
    strategy_atom = String.to_existing_atom(strategy_type)
    candidate_brokers = Map.get(state.routing_rules, strategy_atom, [])

    # Filter by minimum deposit
    suitable_brokers =
      candidate_brokers
      |> Enum.filter(fn broker_id ->
        config = state.brokers[broker_id]
        amount >= config.min_deposit
      end)

    # Select based on priority (first in list for now)
    List.first(suitable_brokers)
  end

  @doc """
  Update routing rules dynamically.
  """
  def update_routing_rules(new_rules) do
    GenServer.cast(__MODULE__, {:update_routing_rules, new_rules})
  end

  def handle_cast({:update_routing_rules, new_rules}, state) do
    updated_state = %{state | routing_rules: Map.merge(state.routing_rules, new_rules)}
    Logger.info("Routing rules updated")
    {:noreply, updated_state}
  end

  defp fetch_all_balances(state) do
    # Fetch balances from active brokers with credentials
    by_broker =
      state.active_brokers
      |> MapSet.to_list()
      |> Enum.map(&fetch_broker_balance/1)
      |> Enum.into(%{})

    # Calculate totals by currency
    by_currency = calculate_currency_totals(by_broker)

    # Calculate total balance in USD equivalent
    total_balance = calculate_total_usd_balance(by_currency)

    %{
      total_balance: total_balance,
      by_broker: by_broker,
      by_currency: by_currency,
      last_updated: DateTime.utc_now()
    }
  end

  defp fetch_broker_balance(broker_id) do
    case broker_id do
      :kraken ->
        # Only fetch if Kraken client is available and has credentials
        case Process.whereis(TradingSwarm.Brokers.KrakenClient) do
          nil ->
            {broker_id, %{status: :unavailable, balances: %{}}}

          _pid ->
            case TradingSwarm.Brokers.KrakenClient.get_balance() do
              {:ok, balances} -> {broker_id, %{status: :connected, balances: balances}}
              {:error, _reason} -> {broker_id, %{status: :error, balances: %{}}}
            end
        end

      _ ->
        # Other brokers not implemented yet
        {broker_id, %{status: :not_implemented, balances: %{}}}
    end
  end

  defp calculate_currency_totals(by_broker) do
    by_broker
    |> Enum.flat_map(fn {_broker, %{balances: balances}} ->
      case balances do
        map when is_map(map) -> Map.to_list(balances)
        _ -> []
      end
    end)
    |> Enum.reduce(%{}, fn {currency, amount}, acc ->
      current = Map.get(acc, currency, Decimal.new("0.00"))

      amount_decimal =
        case amount do
          %Decimal{} -> amount
          amount when is_binary(amount) -> Decimal.new(amount)
          amount when is_number(amount) -> Decimal.from_float(amount)
          _ -> Decimal.new("0.00")
        end

      Map.put(acc, currency, Decimal.add(current, amount_decimal))
    end)
  end

  defp calculate_total_usd_balance(by_currency) do
    # Simplified USD conversion - in production would use real exchange rates
    by_currency
    |> Enum.reduce(Decimal.new("0.00"), fn {currency, amount}, acc ->
      usd_equivalent =
        case currency do
          "USD" -> amount
          # Kraken USD format
          "ZUSD" -> amount
          # Rough BTC price
          "BTC" -> Decimal.mult(amount, Decimal.new("50000"))
          # Kraken BTC format
          "ZBTC" -> Decimal.mult(amount, Decimal.new("50000"))
          # Rough ETH price
          "ETH" -> Decimal.mult(amount, Decimal.new("3000"))
          # Kraken ETH format
          "ZETH" -> Decimal.mult(amount, Decimal.new("3000"))
          # Unknown currency
          _ -> Decimal.new("0.00")
        end

      Decimal.add(acc, usd_equivalent)
    end)
  end

  defp start_available_clients() do
    # Start Kraken client if credentials are available
    kraken_config = Application.get_env(:trading_swarm, :kraken_api, %{})

    if kraken_config[:api_key] && kraken_config[:api_secret] do
      case TradingSwarm.Brokers.KrakenClient.start_link() do
        {:ok, _pid} -> Logger.info("Kraken client started successfully")
        {:error, reason} -> Logger.warning("Failed to start Kraken client: #{inspect(reason)}")
      end
    end

    # Add other broker clients as they are implemented
    :ok
  end
end
