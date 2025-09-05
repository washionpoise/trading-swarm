defmodule TradingSwarm.Market.MarketData do
  @moduledoc """
  Schema for market data (OHLCV candles) storage.
  
  Stores historical market data for different timeframes and symbols
  used by trading agents for analysis and decision making.
  """
  
  use Ecto.Schema
  import Ecto.Changeset

  schema "market_data" do
    field :symbol, :string
    field :timestamp, :utc_datetime
    field :open, :decimal
    field :high, :decimal
    field :low, :decimal
    field :close, :decimal
    field :volume, :decimal
    field :timeframe, :string

    timestamps(type: :utc_datetime)
  end

  @timeframe_values ~w(1m 5m 15m 30m 1h 4h 1d 1w)
  @required_fields ~w(symbol timestamp close timeframe)a
  @optional_fields ~w(open high low volume)a

  @doc false
  def changeset(market_data, attrs) do
    market_data
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:timeframe, @timeframe_values)
    |> validate_number(:open, greater_than: 0)
    |> validate_number(:high, greater_than: 0)
    |> validate_number(:low, greater_than: 0)
    |> validate_number(:close, greater_than: 0)
    |> validate_number(:volume, greater_than_or_equal_to: 0)
    |> validate_ohlc_consistency()
    |> unique_constraint([:symbol, :timestamp, :timeframe])
  end

  defp validate_ohlc_consistency(changeset) do
    with %{valid?: true} <- changeset,
         open when not is_nil(open) <- get_field(changeset, :open),
         high when not is_nil(high) <- get_field(changeset, :high),
         low when not is_nil(low) <- get_field(changeset, :low),
         close when not is_nil(close) <- get_field(changeset, :close) do
      cond do
        Decimal.lt?(high, open) or Decimal.lt?(high, close) ->
          add_error(changeset, :high, "must be greater than or equal to open and close")

        Decimal.gt?(low, open) or Decimal.gt?(low, close) ->
          add_error(changeset, :low, "must be less than or equal to open and close")

        Decimal.lt?(high, low) ->
          add_error(changeset, :high, "must be greater than or equal to low")

        true ->
          changeset
      end
    else
      _ -> changeset
    end
  end

  @doc """
  Returns the price change from open to close.
  """
  def price_change(%__MODULE__{open: open, close: close}) when not is_nil(open) do
    Decimal.sub(close, open)
  end
  def price_change(_), do: nil

  @doc """
  Returns the percentage change from open to close.
  """
  def percentage_change(%__MODULE__{open: open, close: close}) when not is_nil(open) do
    change = Decimal.sub(close, open)
    Decimal.div(change, open) |> Decimal.mult(100)
  end
  def percentage_change(_), do: nil

  @doc """
  Returns the trading range (high - low).
  """
  def trading_range(%__MODULE__{high: high, low: low}) when not is_nil(high) and not is_nil(low) do
    Decimal.sub(high, low)
  end
  def trading_range(_), do: nil

  @doc """
  Returns true if the candle is bullish (close > open).
  """
  def bullish?(%__MODULE__{open: open, close: close}) when not is_nil(open) do
    Decimal.gt?(close, open)
  end
  def bullish?(_), do: false

  @doc """
  Returns true if the candle is bearish (close < open).
  """
  def bearish?(%__MODULE__{open: open, close: close}) when not is_nil(open) do
    Decimal.lt?(close, open)
  end
  def bearish?(_), do: false
end