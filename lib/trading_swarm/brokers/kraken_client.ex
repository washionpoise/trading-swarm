defmodule TradingSwarm.Brokers.KrakenClient do
  @moduledoc """
  Kraken cryptocurrency exchange API client.

  Features:
  - High security standards
  - Regulated by FinCEN, FCA, FINTRAC
  - Spot and futures trading
  - Zero minimum deposit
  """

  use GenServer
  require Logger

  @base_url "https://api.kraken.com/0"
  @public_endpoints %{
    server_time: "/public/Time",
    asset_pairs: "/public/AssetPairs",
    ticker: "/public/Ticker",
    ohlc: "/public/OHLC",
    order_book: "/public/Depth",
    trades: "/public/Trades"
  }

  @private_endpoints %{
    balance: "/private/Balance",
    trade_balance: "/private/TradeBalance",
    open_orders: "/private/OpenOrders",
    closed_orders: "/private/ClosedOrders",
    add_order: "/private/AddOrder",
    cancel_order: "/private/CancelOrder"
  }

  @withdrawal_minimums %{
    "BTC" => 0.0005,
    "ETH" => 0.005,
    "USD" => 5.00,
    "EUR" => 5.00,
    "ADA" => 1.0,
    "DOT" => 0.05,
    "USDT" => 5.0,
    "USDC" => 5.0
  }

  defstruct [:api_key, :api_secret, :name, :status]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    kraken_config = Application.get_env(:trading_swarm, :kraken_api, %{})

    api_key =
      Keyword.get(opts, :api_key) || kraken_config[:api_key] || System.get_env("KRAKEN_API_KEY")

    api_secret =
      Keyword.get(opts, :api_secret) || kraken_config[:api_secret] ||
        System.get_env("KRAKEN_API_SECRET")

    state = %__MODULE__{
      api_key: api_key,
      api_secret: api_secret,
      name: "Kraken",
      status: :connecting
    }

    # Test connection
    case test_connection() do
      {:ok, _time} ->
        Logger.info("Kraken client connected successfully")
        {:ok, %{state | status: :connected}}

      {:error, reason} ->
        Logger.warning("Kraken connection failed: #{inspect(reason)}")
        {:ok, %{state | status: :disconnected}}
    end
  end

  # Public API

  @doc """
  Get current server time from Kraken.
  """
  def get_server_time() do
    GenServer.call(__MODULE__, :get_server_time)
  end

  @doc """
  Get ticker information for trading pairs.
  """
  def get_ticker(pairs \\ []) do
    GenServer.call(__MODULE__, {:get_ticker, pairs})
  end

  @doc """
  Get OHLC data for a pair.
  """
  def get_ohlc(pair, interval \\ 1) do
    GenServer.call(__MODULE__, {:get_ohlc, pair, interval})
  end

  @doc """
  Get account balance (requires API keys).
  """
  def get_balance() do
    GenServer.call(__MODULE__, :get_balance)
  end

  @doc """
  Place a trading order.
  """
  def place_order(order_params) do
    GenServer.call(__MODULE__, {:place_order, order_params})
  end

  @doc """
  Get open orders.
  """
  def get_open_orders() do
    GenServer.call(__MODULE__, :get_open_orders)
  end

  @doc """
  Cancel an order.
  """
  def cancel_order(order_id) do
    GenServer.call(__MODULE__, {:cancel_order, order_id})
  end

  @doc """
  Check withdrawal minimums for different cryptocurrencies.
  """
  def get_withdrawal_minimums() do
    @withdrawal_minimums
  end

  @doc """
  Check if amount meets withdrawal minimum for currency.
  """
  def can_withdraw?(currency, amount) do
    minimum = Map.get(@withdrawal_minimums, currency, 0)
    amount >= minimum
  end

  # GenServer Callbacks

  def handle_call(:get_server_time, _from, state) do
    case make_public_request(@public_endpoints.server_time) do
      {:ok, %{"result" => %{"unixtime" => unix_time}}} ->
        server_time = DateTime.from_unix!(unix_time)
        {:reply, {:ok, server_time}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:get_ticker, pairs}, _from, state) do
    params = if Enum.empty?(pairs), do: %{}, else: %{pair: Enum.join(pairs, ",")}

    case make_public_request(@public_endpoints.ticker, params) do
      {:ok, %{"result" => ticker_data}} ->
        {:reply, {:ok, ticker_data}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:get_ohlc, pair, interval}, _from, state) do
    params = %{pair: pair, interval: interval}

    case make_public_request(@public_endpoints.ohlc, params) do
      {:ok, %{"result" => ohlc_data}} ->
        {:reply, {:ok, ohlc_data}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:get_balance, _from, state) do
    if state.api_key && state.api_secret do
      case make_private_request(@private_endpoints.balance, %{}, state) do
        {:ok, %{"result" => balance_data}} ->
          {:reply, {:ok, balance_data}, state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    else
      {:reply, {:error, :missing_credentials}, state}
    end
  end

  def handle_call({:place_order, order_params}, _from, state) do
    if state.api_key && state.api_secret do
      # Convert order params to Kraken format
      kraken_params = convert_order_params(order_params)

      case make_private_request(@private_endpoints.add_order, kraken_params, state) do
        {:ok, %{"result" => order_result}} ->
          {:reply, {:ok, order_result}, state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    else
      {:reply, {:error, :missing_credentials}, state}
    end
  end

  def handle_call(:get_open_orders, _from, state) do
    if state.api_key && state.api_secret do
      case make_private_request(@private_endpoints.open_orders, %{}, state) do
        {:ok, %{"result" => orders_data}} ->
          {:reply, {:ok, orders_data}, state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    else
      {:reply, {:error, :missing_credentials}, state}
    end
  end

  def handle_call({:cancel_order, order_id}, _from, state) do
    if state.api_key && state.api_secret do
      params = %{txid: order_id}

      case make_private_request(@private_endpoints.cancel_order, params, state) do
        {:ok, %{"result" => cancel_result}} ->
          {:reply, {:ok, cancel_result}, state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    else
      {:reply, {:error, :missing_credentials}, state}
    end
  end

  # Private Functions

  defp test_connection() do
    case make_public_request(@public_endpoints.server_time) do
      {:ok, %{"result" => %{"unixtime" => unix_time}}} ->
        server_time = DateTime.from_unix!(unix_time)
        {:ok, server_time}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp make_public_request(endpoint, params \\ %{}) do
    url = @base_url <> endpoint

    case Req.get(url, params: params, headers: [{"User-Agent", "TradingSwarm/1.0"}]) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status_code, body: body}} ->
        Logger.error("Kraken API error: #{status_code} - #{inspect(body)}")
        {:error, {:http_error, status_code, body}}

      {:error, reason} ->
        Logger.error("Kraken request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp make_private_request(endpoint, params, state) do
    nonce = :os.system_time(:millisecond)
    form_params = Map.put(params, :nonce, nonce)
    post_data = URI.encode_query(form_params)

    # Generate signature according to Kraken API docs
    signature = generate_signature(endpoint, post_data, nonce, state.api_secret)

    headers = [
      {"API-Key", state.api_key},
      {"API-Sign", signature},
      {"User-Agent", "TradingSwarm/1.0"}
    ]

    url = @base_url <> endpoint

    case Req.post(url, form: form_params, headers: headers) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status_code, body: body}} ->
        Logger.error("Kraken private API error: #{status_code} - #{inspect(body)}")
        {:error, {:http_error, status_code, body}}

      {:error, reason} ->
        Logger.error("Kraken private request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp generate_signature(endpoint, post_data, nonce, api_secret) do
    # Kraken signature algorithm
    nonce_post = "#{nonce}#{post_data}"
    sha256_hash = :crypto.hash(:sha256, nonce_post)
    secret_decoded = Base.decode64!(api_secret)

    hmac_data = endpoint <> sha256_hash
    hmac = :crypto.mac(:hmac, :sha512, secret_decoded, hmac_data)

    Base.encode64(hmac)
  end

  defp convert_order_params(order_params) do
    %{
      symbol: symbol,
      side: side,
      amount: amount
    } = order_params

    # Base order parameters according to Kraken API
    base_params = %{
      pair: symbol,
      # "buy" or "sell"
      type: side,
      volume: to_string(amount)
    }

    # Add ordertype and price based on order type
    case Map.get(order_params, :order_type, "market") do
      "market" ->
        Map.put(base_params, :ordertype, "market")

      "limit" ->
        price = Map.get(order_params, :price, 0)

        base_params
        |> Map.put(:ordertype, "limit")
        |> Map.put(:price, to_string(price))

      "stop_loss" ->
        price = Map.get(order_params, :price, 0)

        base_params
        |> Map.put(:ordertype, "stop-loss")
        |> Map.put(:price, to_string(price))

      "take_profit" ->
        price = Map.get(order_params, :price, 0)

        base_params
        |> Map.put(:ordertype, "take-profit")
        |> Map.put(:price, to_string(price))
    end
    |> maybe_add_leverage(order_params)
    |> maybe_add_timeframe(order_params)
  end

  defp maybe_add_leverage(params, order_params) do
    case Map.get(order_params, :leverage) do
      nil -> params
      leverage -> Map.put(params, :leverage, to_string(leverage))
    end
  end

  defp maybe_add_timeframe(params, order_params) do
    case Map.get(order_params, :timeframe) do
      nil -> params
      # Good Till Cancelled
      "GTC" -> Map.put(params, :timeinforce, "GTC")
      # Immediate or Cancel
      "IOC" -> Map.put(params, :timeinforce, "IOC")
      # Fill or Kill
      "FOK" -> Map.put(params, :timeinforce, "FOK")
      _ -> params
    end
  end

  @doc """
  Convert Kraken pair format to standard format.
  """
  def normalize_symbol(kraken_symbol) do
    # Convert XXBTZUSD to BTC/USD format
    normalized =
      kraken_symbol
      |> String.replace("XBT", "BTC")
      |> String.replace("XDG", "DOGE")

    base = String.slice(normalized, 0..2)
    quote = String.slice(normalized, 3..5)

    "#{base}/#{quote}"
  end
end
