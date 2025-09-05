defmodule TradingSwarm.Rehoboam.DataCollector do
  @moduledoc """
  Westworld Rehoboam Omnipresent Surveillance Data Collection.

  "We see everything."

  Surveillance Responsibilities:
  - Omnipresent monitoring of all trading activities
  - Behavioral pattern collection from all agents
  - Market sentiment analysis for control purposes
  - NVIDIA AI-powered data analysis and interpretation
  - Real-time agent behavior tracking and loop verification
  - Surveillance data aggregation for destiny prediction

  Philosophy:
  - Every data point reveals behavioral patterns
  - Agents cannot hide from omnipresent surveillance
  - Data collection enables prediction and control
  - Information is power, prediction is control
  """

  use GenServer
  require Logger

  alias TradingSwarm.AI.NvidiaClient

  # Surveillance configuration - more frequent for better control
  # 30 seconds - more frequent surveillance
  @surveillance_interval 30_000
  # Larger surveillance data storage
  @max_surveillance_points 20_000
  # 2 minutes between NVIDIA AI analysis
  @nvidia_ai_cooldown 120_000

  # Legacy compatibility
  @max_data_points @max_surveillance_points
  @exa_search_cooldown @nvidia_ai_cooldown

  defstruct [
    # Agents performing surveillance
    :surveillance_agents,
    # Active surveillance data streams  
    :surveillance_streams,
    # Last NVIDIA AI analysis timestamp
    :last_ai_analysis,
    # Statistics on surveillance effectiveness
    :surveillance_stats,
    # Cache of analyzed behavioral patterns
    :behavioral_cache,
    # Current level of system omniscience
    :omniscience_level
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Logger.info("Initializing Rehoboam Omnipresent Surveillance - 'We see everything'")

    state = %__MODULE__{
      surveillance_agents: initialize_surveillance_agents(),
      surveillance_streams: %{},
      last_ai_analysis: nil,
      surveillance_stats: %{
        total_surveillance_events: 0,
        successful_analysis: 0,
        behavioral_patterns_detected: 0,
        omniscience_improvements: 0,
        last_surveillance: nil
      },
      behavioral_cache: %{},
      omniscience_level: 0.0
    }

    # Start periodic surveillance
    schedule_surveillance()

    Logger.info("Rehoboam surveillance active - Omnipresent monitoring initiated")
    {:ok, state}
  end

  @doc """
  Collect comprehensive surveillance data from all monitored sources.
  "Every data point tells a story."
  """
  def collect_surveillance_data() do
    GenServer.call(__MODULE__, :collect_surveillance_data, 30_000)
  end

  @doc """
  Perform NVIDIA AI-powered behavioral analysis on collected data.
  "Understanding behavior is the key to prediction."
  """
  def analyze_behavioral_patterns(agent_data) do
    GenServer.call(__MODULE__, {:analyze_behavioral_patterns, agent_data}, 60_000)
  end

  @doc """
  Get current surveillance streams status.
  """
  def get_surveillance_streams() do
    GenServer.call(__MODULE__, :get_surveillance_streams)
  end

  @doc """
  Register new surveillance agent for data collection.
  "Expanding our omniscience."
  """
  def register_surveillance_agent(agent_id, config) do
    GenServer.cast(__MODULE__, {:register_surveillance_agent, agent_id, config})
  end

  @doc """
  Get omniscience statistics and surveillance metrics.
  """
  def get_omniscience_stats() do
    GenServer.call(__MODULE__, :get_omniscience_stats)
  end

  # GenServer Callbacks

  def handle_call(:collect_market_data, _from, state) do
    Logger.debug("Collecting market data from all sources...")

    collection_result = perform_data_collection(state.collectors)

    updated_stats = update_collection_stats(state.collection_stats, collection_result)
    updated_streams = update_data_streams(state.data_streams, collection_result)

    updated_state = %{state | collection_stats: updated_stats, data_streams: updated_streams}

    {:reply, collection_result, updated_state}
  end

  def handle_call({:research_market_conditions, query}, _from, state) do
    case can_perform_exa_search?(state.last_exa_search) do
      true ->
        Logger.info("Performing EXA research: #{query}")

        research_result = perform_exa_research(query)

        updated_state = %{state | last_exa_search: DateTime.utc_now()}

        {:reply, research_result, updated_state}

      false ->
        Logger.warning("EXA search rate limited - too soon since last search")
        {:reply, {:error, :rate_limited}, state}
    end
  end

  def handle_call(:get_data_streams, _from, state) do
    {:reply, state.data_streams, state}
  end

  def handle_call(:get_collection_stats, _from, state) do
    {:reply, state.collection_stats, state}
  end

  def handle_cast({:register_data_source, source_id, config}, state) do
    Logger.info("Registering new data source: #{source_id}")

    updated_collectors =
      Map.put(state.collectors, source_id, %{
        config: config,
        status: :active,
        last_collection: nil,
        total_collections: 0
      })

    {:noreply, %{state | collectors: updated_collectors}}
  end

  def handle_info(:perform_collection, state) do
    # Perform scheduled data collection
    case perform_data_collection(state.collectors) do
      {:ok, collection_data} ->
        updated_stats = update_collection_stats(state.collection_stats, {:ok, collection_data})
        updated_streams = update_data_streams(state.data_streams, {:ok, collection_data})

        # Notify Rehoboam of new data
        notify_rehoboam_new_data(collection_data)

        updated_state = %{state | collection_stats: updated_stats, data_streams: updated_streams}

        schedule_surveillance()
        {:noreply, updated_state}

      {:error, reason} ->
        Logger.error("Data collection failed: #{inspect(reason)}")
        updated_stats = update_collection_stats(state.collection_stats, {:error, reason})

        schedule_surveillance()
        {:noreply, %{state | collection_stats: updated_stats}}
    end
  end

  # Private Functions

  defp initialize_surveillance_agents() do
    %{
      kraken_surveillance: %{
        config: %{type: :crypto_monitoring, priority: :critical},
        status: :monitoring,
        last_surveillance: nil,
        behavioral_insights_collected: 0,
        surveillance_quality: :high
      },
      behavioral_analysis: %{
        config: %{type: :agent_behavior, priority: :critical},
        status: :active,
        last_surveillance: nil,
        behavioral_insights_collected: 0,
        surveillance_quality: :comprehensive
      },
      market_sentiment: %{
        config: %{type: :sentiment_surveillance, priority: :high},
        status: :monitoring,
        last_surveillance: nil,
        behavioral_insights_collected: 0,
        surveillance_quality: :moderate
      },
      nvidia_ai_analysis: %{
        config: %{type: :ai_behavioral_analysis, priority: :maximum},
        status: :active,
        last_surveillance: nil,
        behavioral_insights_collected: 0,
        surveillance_quality: :omniscient
      }
    }
  end

  defp schedule_surveillance() do
    Process.send_after(self(), :perform_surveillance, @surveillance_interval)
  end

  defp perform_data_collection(collectors) do
    try do
      collection_results =
        collectors
        |> Enum.filter(fn {_id, collector} -> collector.status == :active end)
        |> Enum.map(&collect_from_source/1)
        |> Enum.into(%{})

      {:ok,
       %{
         timestamp: DateTime.utc_now(),
         sources: collection_results,
         total_data_points: count_data_points(collection_results)
       }}
    rescue
      error ->
        Logger.error("Data collection error: #{inspect(error)}")
        {:error, error}
    end
  end

  defp collect_from_source({source_id, _collector}) do
    case source_id do
      :kraken -> collect_kraken_data()
      :market_news -> collect_market_news()
      :social_sentiment -> collect_social_sentiment()
      :exa_research -> {:skip, "EXA research performed on-demand only"}
      _ -> {:error, :unknown_source}
    end
  end

  defp collect_kraken_data() do
    case Process.whereis(TradingSwarm.Brokers.KrakenClient) do
      nil ->
        {:error, :client_unavailable}

      _pid ->
        try do
          # Collect ticker data for major pairs
          major_pairs = ["XBTUSD", "ETHUSD", "ADAUSD", "DOTUSD"]

          case TradingSwarm.Brokers.KrakenClient.get_ticker(major_pairs) do
            {:ok, ticker_data} ->
              processed_data = process_ticker_data(ticker_data)

              {:ok,
               %{
                 source: :kraken,
                 type: :market_data,
                 data: processed_data,
                 data_points: map_size(ticker_data)
               }}

            {:error, reason} ->
              {:error, reason}
          end
        rescue
          error -> {:error, error}
        end
    end
  end

  defp collect_market_news() do
    # Placeholder for market news collection
    # In production, would integrate with news APIs
    {:ok,
     %{
       source: :market_news,
       type: :news_data,
       data: %{
         headlines: [],
         sentiment_score: 0.0
       },
       data_points: 0
     }}
  end

  defp collect_social_sentiment() do
    # Placeholder for social sentiment analysis
    # Would integrate with Twitter API, Reddit, etc.
    {:ok,
     %{
       source: :social_sentiment,
       type: :sentiment_data,
       data: %{
         overall_sentiment: :neutral,
         confidence: 0.0,
         mentions: 0
       },
       data_points: 0
     }}
  end

  defp process_ticker_data(ticker_data) do
    ticker_data
    |> Enum.map(fn {pair, data} ->
      {pair,
       %{
         price: extract_price(data),
         volume: extract_volume(data),
         change_24h: extract_price_change(data),
         timestamp: DateTime.utc_now()
       }}
    end)
    |> Enum.into(%{})
  end

  defp extract_price(ticker_data) when is_map(ticker_data) do
    # Kraken ticker format: {"c": ["price", "lot_volume"]}
    case Map.get(ticker_data, "c") do
      [price | _] when is_binary(price) ->
        case Float.parse(price) do
          {parsed_price, _} -> parsed_price
          :error -> 0.0
        end

      _ ->
        0.0
    end
  end

  defp extract_price(_), do: 0.0

  defp extract_volume(ticker_data) when is_map(ticker_data) do
    case Map.get(ticker_data, "v") do
      [_, volume_24h] when is_binary(volume_24h) ->
        case Float.parse(volume_24h) do
          {parsed_volume, _} -> parsed_volume
          :error -> 0.0
        end

      _ ->
        0.0
    end
  end

  defp extract_volume(_), do: 0.0

  defp extract_price_change(ticker_data) when is_map(ticker_data) do
    # Calculate from opening price and current price
    case {Map.get(ticker_data, "o"), Map.get(ticker_data, "c")} do
      {[open_price], [current_price | _]}
      when is_binary(open_price) and is_binary(current_price) ->
        with {open_float, _} <- Float.parse(open_price),
             {current_float, _} <- Float.parse(current_price) do
          (current_float - open_float) / open_float * 100
        else
          _ -> 0.0
        end

      _ ->
        0.0
    end
  end

  defp extract_price_change(_), do: 0.0

  defp count_data_points(collection_results) do
    collection_results
    |> Enum.map(fn {_source, result} ->
      case result do
        {:ok, %{data_points: count}} -> count
        _ -> 0
      end
    end)
    |> Enum.sum()
  end

  defp update_collection_stats(current_stats, collection_result) do
    case collection_result do
      {:ok, collection_data} ->
        %{
          current_stats
          | total_collected: current_stats.total_collected + collection_data.total_data_points,
            successful_collections: current_stats.successful_collections + 1,
            last_collection: DateTime.utc_now()
        }

      {:error, _reason} ->
        %{
          current_stats
          | failed_collections: current_stats.failed_collections + 1,
            last_collection: DateTime.utc_now()
        }
    end
  end

  defp update_data_streams(current_streams, collection_result) do
    case collection_result do
      {:ok, collection_data} ->
        new_streams =
          collection_data.sources
          |> Enum.filter(fn {_source, result} -> match?({:ok, _}, result) end)
          |> Enum.map(fn {source, {:ok, data}} ->
            stream_id = "#{source}_stream"

            current_stream =
              Map.get(current_streams, stream_id, %{
                data_points: [],
                last_update: nil,
                total_points: 0
              })

            new_data_point = %{
              timestamp: DateTime.utc_now(),
              data: data,
              source: source
            }

            updated_points = [
              new_data_point | Enum.take(current_stream.data_points, @max_data_points - 1)
            ]

            {stream_id,
             %{
               current_stream
               | data_points: updated_points,
                 last_update: DateTime.utc_now(),
                 total_points: current_stream.total_points + 1
             }}
          end)
          |> Enum.into(%{})

        Map.merge(current_streams, new_streams)

      {:error, _reason} ->
        current_streams
    end
  end

  defp notify_rehoboam_new_data(collection_data) do
    # Notify main Rehoboam system of new data
    case Process.whereis(TradingSwarm.Rehoboam) do
      nil ->
        Logger.debug("Rehoboam not running - data stored for later processing")

      _pid ->
        market_event = %{
          timestamp: collection_data.timestamp,
          event_type: :data_collection,
          data: collection_data,
          source: :data_collector,
          stream_id: :market_data
        }

        TradingSwarm.Rehoboam.submit_market_event(market_event)
    end
  end

  defp can_perform_exa_search?(last_search) do
    case last_search do
      nil ->
        true

      last_time ->
        time_diff = DateTime.diff(DateTime.utc_now(), last_time, :millisecond)
        time_diff >= @exa_search_cooldown
    end
  end

  defp perform_exa_research(query) do
    try do
      # Use EXA MCP for market research
      case apply(:mcp__exa__web_search_exa, :search, [%{query: query, numResults: 5}]) do
        {:ok, search_results} ->
          processed_results = process_exa_results(search_results, query)

          {:ok,
           %{
             query: query,
             timestamp: DateTime.utc_now(),
             results: processed_results,
             source: :exa_research
           }}

        {:error, reason} ->
          Logger.error("EXA search failed: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      error ->
        Logger.error("EXA research error: #{inspect(error)}")
        {:error, error}
    end
  end

  defp process_exa_results(search_results, query) when is_list(search_results) do
    search_results
    |> Enum.map(fn result ->
      %{
        title: Map.get(result, "title", ""),
        url: Map.get(result, "url", ""),
        snippet: Map.get(result, "snippet", ""),
        relevance_score: calculate_relevance_score(result, query),
        processed_at: DateTime.utc_now()
      }
    end)
  end

  defp process_exa_results(search_results, _query) do
    Logger.warning("Unexpected EXA results format: #{inspect(search_results)}")
    []
  end

  defp calculate_relevance_score(result, query) do
    # Simple relevance scoring based on keyword matches
    title = String.downcase(Map.get(result, "title", ""))
    snippet = String.downcase(Map.get(result, "snippet", ""))
    query_words = String.downcase(query) |> String.split()

    title_matches = Enum.count(query_words, fn word -> String.contains?(title, word) end)
    snippet_matches = Enum.count(query_words, fn word -> String.contains?(snippet, word) end)

    # Weight title matches higher
    total_matches = title_matches * 2 + snippet_matches
    max_possible_score = length(query_words) * 3

    if max_possible_score > 0 do
      total_matches / max_possible_score
    else
      0.0
    end
  end
end
