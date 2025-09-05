# Test consolidated balance functionality
# Run with: mix run test_balance_consolidation.exs

IO.puts("💰 Testing Consolidated Balance System...")

# Start Broker Manager
{:ok, _pid} = TradingSwarm.Brokers.BrokerManager.start_link()

# Wait a moment for clients to initialize
Process.sleep(1000)

IO.puts("\n🔄 Fetching consolidated balance...")

# Get consolidated balance
consolidated = TradingSwarm.Brokers.BrokerManager.get_consolidated_balance()

IO.puts("✅ Balance consolidation completed!")

IO.puts("\n📊 Balance Summary:")
IO.puts("Total USD Equivalent: $#{consolidated.total_balance}")
IO.puts("Last Updated: #{consolidated.last_updated}")

IO.puts("\n💳 By Broker:")

Enum.each(consolidated.by_broker, fn {broker_id, broker_data} ->
  IO.puts("  #{broker_id}: #{broker_data.status}")

  case broker_data.balances do
    balances when map_size(balances) > 0 ->
      Enum.each(balances, fn {currency, amount} ->
        IO.puts("    #{currency}: #{amount}")
      end)

    _ ->
      IO.puts("    No balances available")
  end
end)

IO.puts("\n🌍 By Currency:")

Enum.each(consolidated.by_currency, fn {currency, amount} ->
  IO.puts("  #{currency}: #{amount}")
end)

if map_size(consolidated.by_currency) == 0 do
  IO.puts("  No balances found (expected if no API credentials are configured)")
end

IO.puts("\n🎯 Testing Kraken Balance (if available)...")

# Test Kraken balance directly if client is running
case Process.whereis(TradingSwarm.Brokers.KrakenClient) do
  nil ->
    IO.puts("❌ Kraken client not running")

  _pid ->
    case TradingSwarm.Brokers.KrakenClient.get_balance() do
      {:ok, balances} ->
        IO.puts("✅ Kraken balance fetched successfully")
        IO.inspect(balances, label: "Kraken Balances")

      {:error, :missing_credentials} ->
        IO.puts("⚠️  Kraken credentials not configured for private API")

      {:error, reason} ->
        IO.puts("❌ Kraken balance error: #{inspect(reason)}")
    end
end

IO.puts("\n🏁 Balance consolidation test completed!")
