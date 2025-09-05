# Test Kraken API connectivity
# Run with: mix run test_kraken.exs

IO.puts("🔄 Testing Kraken API connectivity...")

# Start Kraken client
{:ok, _pid} = TradingSwarm.Brokers.KrakenClient.start_link()

# Test public API - get server time
case TradingSwarm.Brokers.KrakenClient.get_server_time() do
  {:ok, server_time} ->
    IO.puts("✅ Kraken connection successful!")
    IO.puts("🕒 Server time: #{server_time}")

    # Test getting ticker for BTC/USD
    case TradingSwarm.Brokers.KrakenClient.get_ticker(["XBTUSD"]) do
      {:ok, ticker_data} ->
        IO.puts("📈 BTC/USD ticker data received")
        IO.inspect(ticker_data, label: "Ticker")

      {:error, reason} ->
        IO.puts("❌ Failed to get ticker: #{inspect(reason)}")
    end

  {:error, reason} ->
    IO.puts("❌ Kraken connection failed: #{inspect(reason)}")
end

# Test withdrawal minimums
IO.puts("\n💰 Withdrawal minimums:")

TradingSwarm.Brokers.KrakenClient.get_withdrawal_minimums()
|> Enum.each(fn {currency, minimum} ->
  IO.puts("  #{currency}: #{minimum}")
end)

IO.puts("\n🏁 Test completed!")
