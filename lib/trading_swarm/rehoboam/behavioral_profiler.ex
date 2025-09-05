defmodule TradingSwarm.Rehoboam.BehavioralProfiler do
  @moduledoc """
  Behavioral Profiling module for Rehoboam system.

  Analyzes and profiles:
  - Trading agent behavior patterns
  - Market participant psychology
  - Decision-making patterns
  - Risk tolerance and adaptation
  - Performance consistency and predictability
  - Anomaly detection in trading behaviors
  """

  use GenServer
  require Logger

  # 5 minutes
  @profile_update_interval 300_000
  @behavior_history_limit 1000
  @anomaly_threshold 0.7
  @profile_confidence_threshold 0.6

  defstruct [
    :profiles,
    :behavior_patterns,
    :anomaly_detector,
    :profiling_stats,
    :last_analysis
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Logger.info("Starting Rehoboam Behavioral Profiler...")

    state = %__MODULE__{
      profiles: %{},
      behavior_patterns: initialize_behavior_patterns(),
      anomaly_detector: initialize_anomaly_detector(),
      profiling_stats: %{
        total_profiles: 0,
        anomalies_detected: 0,
        last_profile_update: nil
      },
      last_analysis: nil
    }

    # Schedule periodic profiling analysis
    schedule_profiling_analysis()

    {:ok, state}
  end

  @doc """
  Create or update behavioral profile for an agent.
  """
  def profile_agent(agent_id, behavioral_data) do
    GenServer.call(__MODULE__, {:profile_agent, agent_id, behavioral_data})
  end

  @doc """
  Get behavioral profile for specific agent.
  """
  def get_profile(agent_id) do
    GenServer.call(__MODULE__, {:get_profile, agent_id})
  end

  @doc """
  Analyze behavior pattern and detect anomalies.
  """
  def analyze_behavior_pattern(behavior_data) do
    GenServer.call(__MODULE__, {:analyze_behavior_pattern, behavior_data})
  end

  @doc """
  Get all profiles with optional filtering.
  """
  def get_all_profiles(filter \\ :all) do
    GenServer.call(__MODULE__, {:get_all_profiles, filter})
  end

  @doc """
  Detect behavioral anomalies across all agents.
  """
  def detect_anomalies() do
    GenServer.call(__MODULE__, :detect_anomalies)
  end

  @doc """
  Get profiling statistics and system health.
  """
  def get_profiling_stats() do
    GenServer.call(__MODULE__, :get_profiling_stats)
  end

  @doc """
  Submit behavioral event for analysis.
  """
  def submit_behavioral_event(event_data) do
    GenServer.cast(__MODULE__, {:submit_behavioral_event, event_data})
  end

  # GenServer Callbacks

  def handle_call({:profile_agent, agent_id, behavioral_data}, _from, state) do
    Logger.debug("Profiling agent: #{agent_id}")

    # Get existing profile or create new one
    current_profile = Map.get(state.profiles, agent_id, create_empty_profile(agent_id))

    # Update profile with new behavioral data
    updated_profile = update_agent_profile(current_profile, behavioral_data)

    # Update profiles map
    updated_profiles = Map.put(state.profiles, agent_id, updated_profile)

    # Update stats
    updated_stats = update_profiling_stats(state.profiling_stats, :profile_updated)

    updated_state = %{state | profiles: updated_profiles, profiling_stats: updated_stats}

    {:reply, {:ok, updated_profile}, updated_state}
  end

  def handle_call({:get_profile, agent_id}, _from, state) do
    profile = Map.get(state.profiles, agent_id, {:error, :profile_not_found})
    {:reply, profile, state}
  end

  def handle_call({:analyze_behavior_pattern, behavior_data}, _from, state) do
    analysis_result = analyze_single_behavior_pattern(behavior_data, state.behavior_patterns)
    {:reply, analysis_result, state}
  end

  def handle_call({:get_all_profiles, filter}, _from, state) do
    filtered_profiles = filter_profiles(state.profiles, filter)
    {:reply, filtered_profiles, state}
  end

  def handle_call(:detect_anomalies, _from, state) do
    anomaly_results = detect_behavioral_anomalies(state.profiles, state.anomaly_detector)

    updated_stats =
      if length(anomaly_results) > 0 do
        update_profiling_stats(
          state.profiling_stats,
          :anomalies_detected,
          length(anomaly_results)
        )
      else
        state.profiling_stats
      end

    updated_state = %{state | profiling_stats: updated_stats}

    {:reply, anomaly_results, updated_state}
  end

  def handle_call(:get_profiling_stats, _from, state) do
    enhanced_stats =
      Map.merge(state.profiling_stats, %{
        total_profiles: map_size(state.profiles),
        active_profiles: count_active_profiles(state.profiles),
        last_analysis: state.last_analysis
      })

    {:reply, enhanced_stats, state}
  end

  def handle_cast({:submit_behavioral_event, event_data}, state) do
    # Process behavioral event and update relevant profiles
    updated_profiles = process_behavioral_event(state.profiles, event_data)

    updated_state = %{state | profiles: updated_profiles}

    {:noreply, updated_state}
  end

  def handle_info(:perform_profiling_analysis, state) do
    Logger.debug("Performing periodic behavioral profiling analysis...")

    # Analyze all profiles for patterns and anomalies
    analysis_result = perform_comprehensive_analysis(state.profiles, state.behavior_patterns)

    # Update anomaly detector based on new patterns
    updated_anomaly_detector = update_anomaly_detector(state.anomaly_detector, analysis_result)

    updated_state = %{
      state
      | last_analysis: analysis_result,
        anomaly_detector: updated_anomaly_detector
    }

    # Notify Rehoboam of analysis results
    notify_rehoboam_analysis(analysis_result)

    schedule_profiling_analysis()
    {:noreply, updated_state}
  end

  # Private Functions

  defp initialize_behavior_patterns() do
    %{
      risk_patterns: %{
        conservative: %{
          min_risk: 0.0,
          max_risk: 0.3,
          characteristics: [:low_volatility, :stable_returns]
        },
        moderate: %{
          min_risk: 0.3,
          max_risk: 0.6,
          characteristics: [:balanced_approach, :moderate_volatility]
        },
        aggressive: %{
          min_risk: 0.6,
          max_risk: 1.0,
          characteristics: [:high_volatility, :high_reward_seeking]
        }
      },
      trading_patterns: %{
        scalper: %{
          frequency: :very_high,
          hold_time: :minutes,
          characteristics: [:quick_profits, :high_frequency]
        },
        day_trader: %{
          frequency: :high,
          hold_time: :hours,
          characteristics: [:intraday_focus, :technical_analysis]
        },
        swing_trader: %{
          frequency: :medium,
          hold_time: :days,
          characteristics: [:trend_following, :patience]
        },
        position_trader: %{
          frequency: :low,
          hold_time: :weeks_months,
          characteristics: [:long_term_vision, :fundamental_analysis]
        }
      },
      decision_patterns: %{
        analytical: %{
          decision_time: :slow,
          data_dependency: :high,
          characteristics: [:research_heavy, :methodical]
        },
        intuitive: %{
          decision_time: :fast,
          data_dependency: :low,
          characteristics: [:gut_feeling, :experience_based]
        },
        algorithmic: %{
          decision_time: :instant,
          data_dependency: :very_high,
          characteristics: [:systematic, :emotionless]
        }
      }
    }
  end

  defp initialize_anomaly_detector() do
    %{
      thresholds: %{
        risk_deviation: @anomaly_threshold,
        performance_deviation: @anomaly_threshold,
        behavior_consistency: 1.0 - @anomaly_threshold
      },
      detection_methods: [:statistical_outlier, :pattern_deviation, :performance_anomaly],
      learning_rate: 0.1,
      adaptation_factor: 0.05
    }
  end

  defp create_empty_profile(agent_id) do
    %{
      agent_id: agent_id,
      created_at: DateTime.utc_now(),
      last_updated: DateTime.utc_now(),
      behavioral_history: [],
      risk_profile: %{
        risk_tolerance: 0.5,
        risk_consistency: 0.0,
        risk_adaptation_rate: 0.0
      },
      trading_style: %{
        frequency: :unknown,
        hold_time: :unknown,
        preferred_instruments: [],
        success_rate: 0.0
      },
      decision_making: %{
        decision_speed: :unknown,
        data_reliance: :unknown,
        consistency: 0.0,
        adaptability: 0.0
      },
      performance_metrics: %{
        total_trades: 0,
        successful_trades: 0,
        average_return: 0.0,
        max_drawdown: 0.0,
        volatility: 0.0
      },
      behavioral_score: %{
        predictability: 0.0,
        stability: 0.0,
        anomaly_count: 0,
        confidence: 0.0
      },
      pattern_classifications: []
    }
  end

  defp update_agent_profile(profile, behavioral_data) do
    # Add new behavioral data to history
    updated_history = [
      behavioral_data | Enum.take(profile.behavioral_history, @behavior_history_limit - 1)
    ]

    # Recalculate profile metrics based on updated history
    updated_risk_profile = calculate_risk_profile(updated_history)
    updated_trading_style = calculate_trading_style(updated_history)
    updated_decision_making = calculate_decision_making(updated_history)
    updated_performance_metrics = calculate_performance_metrics(updated_history)
    updated_behavioral_score = calculate_behavioral_score(updated_history)

    # Classify behavior patterns
    pattern_classifications = classify_behavior_patterns(updated_history)

    %{
      profile
      | last_updated: DateTime.utc_now(),
        behavioral_history: updated_history,
        risk_profile: updated_risk_profile,
        trading_style: updated_trading_style,
        decision_making: updated_decision_making,
        performance_metrics: updated_performance_metrics,
        behavioral_score: updated_behavioral_score,
        pattern_classifications: pattern_classifications
    }
  end

  defp calculate_risk_profile(behavioral_history) do
    if length(behavioral_history) < 5 do
      %{risk_tolerance: 0.5, risk_consistency: 0.0, risk_adaptation_rate: 0.0}
    else
      risk_levels =
        Enum.map(behavioral_history, fn data ->
          Map.get(data, :risk_level, 0.5)
        end)

      avg_risk = Enum.sum(risk_levels) / length(risk_levels)
      risk_variance = calculate_variance(risk_levels)
      risk_trend = calculate_trend(risk_levels)

      %{
        risk_tolerance: avg_risk,
        risk_consistency: 1.0 - min(1.0, risk_variance),
        risk_adaptation_rate: abs(risk_trend)
      }
    end
  end

  defp calculate_trading_style(behavioral_history) do
    if length(behavioral_history) < 10 do
      %{frequency: :unknown, hold_time: :unknown, preferred_instruments: [], success_rate: 0.0}
    else
      # Analyze trading frequency
      trades_per_day = calculate_trading_frequency(behavioral_history)

      # Analyze holding times
      avg_hold_time = calculate_average_hold_time(behavioral_history)

      # Analyze preferred instruments
      preferred_instruments = calculate_preferred_instruments(behavioral_history)

      # Calculate success rate
      success_rate = calculate_success_rate(behavioral_history)

      %{
        frequency: classify_trading_frequency(trades_per_day),
        hold_time: classify_hold_time(avg_hold_time),
        preferred_instruments: preferred_instruments,
        success_rate: success_rate
      }
    end
  end

  defp calculate_decision_making(behavioral_history) do
    if length(behavioral_history) < 10 do
      %{decision_speed: :unknown, data_reliance: :unknown, consistency: 0.0, adaptability: 0.0}
    else
      # Analyze decision speed from timestamp patterns
      decision_times = extract_decision_times(behavioral_history)
      avg_decision_time = Enum.sum(decision_times) / length(decision_times)

      # Analyze data reliance
      data_usage_scores = extract_data_usage_scores(behavioral_history)
      avg_data_reliance = Enum.sum(data_usage_scores) / length(data_usage_scores)

      # Calculate consistency
      consistency_score = calculate_decision_consistency(behavioral_history)

      # Calculate adaptability
      adaptability_score = calculate_adaptability(behavioral_history)

      %{
        decision_speed: classify_decision_speed(avg_decision_time),
        data_reliance: classify_data_reliance(avg_data_reliance),
        consistency: consistency_score,
        adaptability: adaptability_score
      }
    end
  end

  defp calculate_performance_metrics(behavioral_history) do
    trades =
      Enum.filter(behavioral_history, fn data ->
        Map.get(data, :event_type) == :trade_completed
      end)

    if length(trades) < 5 do
      %{
        total_trades: 0,
        successful_trades: 0,
        average_return: 0.0,
        max_drawdown: 0.0,
        volatility: 0.0
      }
    else
      total_trades = length(trades)

      successful_trades =
        Enum.count(trades, fn trade ->
          Map.get(trade, :outcome) == :success
        end)

      returns =
        Enum.map(trades, fn trade ->
          Map.get(trade, :return_percentage, 0.0)
        end)

      avg_return = Enum.sum(returns) / length(returns)
      max_drawdown = calculate_max_drawdown(returns)
      volatility = calculate_volatility(returns)

      %{
        total_trades: total_trades,
        successful_trades: successful_trades,
        average_return: avg_return,
        max_drawdown: max_drawdown,
        volatility: volatility
      }
    end
  end

  defp calculate_behavioral_score(behavioral_history) do
    if length(behavioral_history) < 10 do
      %{predictability: 0.0, stability: 0.0, anomaly_count: 0, confidence: 0.0}
    else
      predictability = calculate_predictability_score(behavioral_history)
      stability = calculate_stability_score(behavioral_history)
      anomaly_count = count_behavioral_anomalies(behavioral_history)
      confidence = calculate_confidence_score(behavioral_history)

      %{
        predictability: predictability,
        stability: stability,
        anomaly_count: anomaly_count,
        confidence: confidence
      }
    end
  end

  defp classify_behavior_patterns(behavioral_history) do
    patterns = []

    # Risk pattern classification
    risk_pattern = classify_risk_pattern(behavioral_history)
    patterns = if risk_pattern, do: [risk_pattern | patterns], else: patterns

    # Trading pattern classification
    trading_pattern = classify_trading_pattern(behavioral_history)
    patterns = if trading_pattern, do: [trading_pattern | patterns], else: patterns

    # Decision pattern classification
    decision_pattern = classify_decision_pattern(behavioral_history)
    patterns = if decision_pattern, do: [decision_pattern | patterns], else: patterns

    patterns
  end

  defp analyze_single_behavior_pattern(behavior_data, behavior_patterns) do
    %{
      timestamp: DateTime.utc_now(),
      pattern_matches: find_pattern_matches(behavior_data, behavior_patterns),
      anomaly_indicators: detect_pattern_anomalies(behavior_data),
      confidence_score: calculate_pattern_confidence(behavior_data),
      recommendations: generate_pattern_recommendations(behavior_data)
    }
  end

  defp filter_profiles(profiles, filter) do
    case filter do
      :all ->
        profiles

      :active ->
        Enum.filter(profiles, fn {_id, profile} ->
          profile_active?(profile)
        end)
        |> Enum.into(%{})

      :anomalous ->
        Enum.filter(profiles, fn {_id, profile} ->
          profile.behavioral_score.anomaly_count > 0
        end)
        |> Enum.into(%{})

      :high_confidence ->
        Enum.filter(profiles, fn {_id, profile} ->
          profile.behavioral_score.confidence > @profile_confidence_threshold
        end)
        |> Enum.into(%{})

      _ ->
        profiles
    end
  end

  defp detect_behavioral_anomalies(profiles, anomaly_detector) do
    profiles
    |> Enum.flat_map(fn {agent_id, profile} ->
      anomalies = detect_profile_anomalies(profile, anomaly_detector)
      Enum.map(anomalies, fn anomaly -> Map.put(anomaly, :agent_id, agent_id) end)
    end)
    |> Enum.sort_by(fn anomaly -> anomaly.severity end, :desc)
  end

  defp detect_profile_anomalies(profile, anomaly_detector) do
    anomalies = []

    # Check risk deviation anomalies
    risk_anomalies = detect_risk_anomalies(profile, anomaly_detector)
    anomalies = anomalies ++ risk_anomalies

    # Check performance anomalies
    performance_anomalies = detect_performance_anomalies(profile, anomaly_detector)
    anomalies = anomalies ++ performance_anomalies

    # Check behavior consistency anomalies
    consistency_anomalies = detect_consistency_anomalies(profile, anomaly_detector)
    anomalies = anomalies ++ consistency_anomalies

    anomalies
  end

  defp process_behavioral_event(profiles, event_data) do
    agent_id = Map.get(event_data, :agent_id, :unknown)

    case Map.get(profiles, agent_id) do
      nil ->
        # Create new profile for unknown agent
        new_profile = create_empty_profile(agent_id)
        updated_profile = update_agent_profile(new_profile, event_data)
        Map.put(profiles, agent_id, updated_profile)

      existing_profile ->
        # Update existing profile
        updated_profile = update_agent_profile(existing_profile, event_data)
        Map.put(profiles, agent_id, updated_profile)
    end
  end

  defp perform_comprehensive_analysis(profiles, behavior_patterns) do
    %{
      timestamp: DateTime.utc_now(),
      total_profiles_analyzed: map_size(profiles),
      behavioral_patterns_identified: identify_global_patterns(profiles, behavior_patterns),
      risk_distribution: calculate_risk_distribution(profiles),
      performance_statistics: calculate_global_performance_stats(profiles),
      anomaly_summary: summarize_anomalies(profiles),
      recommendations: generate_global_recommendations(profiles)
    }
  end

  defp notify_rehoboam_analysis(analysis_result) do
    case Process.whereis(TradingSwarm.Rehoboam) do
      nil ->
        Logger.debug("Rehoboam not running - analysis stored for later processing")

      _pid ->
        behavioral_event = %{
          timestamp: analysis_result.timestamp,
          event_type: :behavioral_analysis,
          data: analysis_result,
          source: :behavioral_profiler,
          stream_id: :behavioral_analysis
        }

        TradingSwarm.Rehoboam.submit_agent_behavior(behavioral_event)
    end
  end

  defp schedule_profiling_analysis() do
    Process.send_after(self(), :perform_profiling_analysis, @profile_update_interval)
  end

  # Helper calculation functions (simplified implementations)

  defp calculate_variance(values) do
    if length(values) <= 1 do
      0.0
    else
      mean = Enum.sum(values) / length(values)

      variance =
        values
        |> Enum.map(fn x -> (x - mean) * (x - mean) end)
        |> Enum.sum()
        |> Kernel./(length(values) - 1)

      :math.sqrt(variance)
    end
  end

  defp calculate_trend(values) do
    if length(values) < 2 do
      0.0
    else
      # Simple linear trend calculation
      n = length(values)
      x_values = Enum.to_list(1..n)

      x_mean = Enum.sum(x_values) / n
      y_mean = Enum.sum(values) / n

      numerator =
        Enum.zip(x_values, values)
        |> Enum.map(fn {x, y} -> (x - x_mean) * (y - y_mean) end)
        |> Enum.sum()

      denominator =
        x_values
        |> Enum.map(fn x -> (x - x_mean) * (x - x_mean) end)
        |> Enum.sum()

      if denominator == 0, do: 0.0, else: numerator / denominator
    end
  end

  # Placeholder implementations for complex calculations
  defp calculate_trading_frequency(_behavioral_history), do: 5.0
  # minutes
  defp calculate_average_hold_time(_behavioral_history), do: 1440
  defp calculate_preferred_instruments(_behavioral_history), do: ["BTC/USD", "ETH/USD"]

  defp calculate_success_rate(behavioral_history) do
    successful =
      Enum.count(behavioral_history, fn data ->
        Map.get(data, :outcome) == :success
      end)

    if length(behavioral_history) > 0, do: successful / length(behavioral_history), else: 0.0
  end

  defp classify_trading_frequency(freq) when freq > 50, do: :very_high
  defp classify_trading_frequency(freq) when freq > 10, do: :high
  defp classify_trading_frequency(freq) when freq > 2, do: :medium
  defp classify_trading_frequency(_), do: :low

  defp classify_hold_time(time) when time < 60, do: :minutes
  defp classify_hold_time(time) when time < 1440, do: :hours
  defp classify_hold_time(time) when time < 10_080, do: :days
  defp classify_hold_time(_), do: :weeks_months

  # seconds
  defp extract_decision_times(_behavioral_history), do: [30, 45, 60, 120]
  defp extract_data_usage_scores(_behavioral_history), do: [0.7, 0.8, 0.6, 0.9]
  defp calculate_decision_consistency(_behavioral_history), do: 0.75
  defp calculate_adaptability(_behavioral_history), do: 0.6

  defp classify_decision_speed(time) when time < 30, do: :fast
  defp classify_decision_speed(time) when time < 120, do: :medium
  defp classify_decision_speed(_), do: :slow

  defp classify_data_reliance(score) when score > 0.8, do: :very_high
  defp classify_data_reliance(score) when score > 0.6, do: :high
  defp classify_data_reliance(score) when score > 0.4, do: :medium
  defp classify_data_reliance(_), do: :low

  defp calculate_max_drawdown(returns) do
    returns
    |> Enum.scan(0, &(&1 + &2))
    |> Enum.scan(&min/2)
    |> Enum.min()
    |> abs()
  end

  defp calculate_volatility(returns) do
    calculate_variance(returns)
  end

  defp calculate_predictability_score(_behavioral_history), do: 0.7
  defp calculate_stability_score(_behavioral_history), do: 0.8
  defp count_behavioral_anomalies(_behavioral_history), do: 2

  defp calculate_confidence_score(behavioral_history) do
    min(1.0, length(behavioral_history) / 100.0)
  end

  defp classify_risk_pattern(_behavioral_history), do: :moderate_risk_taker
  defp classify_trading_pattern(_behavioral_history), do: :swing_trader
  defp classify_decision_pattern(_behavioral_history), do: :analytical_trader

  defp find_pattern_matches(_behavior_data, _behavior_patterns),
    do: [:momentum_following, :risk_aware]

  defp detect_pattern_anomalies(_behavior_data), do: []
  defp calculate_pattern_confidence(_behavior_data), do: 0.8

  defp generate_pattern_recommendations(_behavior_data),
    do: ["Consider risk management", "Monitor volatility"]

  defp profile_active?(profile) do
    case profile.last_updated do
      nil ->
        false

      last_update ->
        time_diff = DateTime.diff(DateTime.utc_now(), last_update, :second)
        # Active if updated within 24 hours
        time_diff < 86_400
    end
  end

  defp count_active_profiles(profiles) do
    profiles
    |> Enum.count(fn {_id, profile} -> profile_active?(profile) end)
  end

  defp detect_risk_anomalies(_profile, _anomaly_detector), do: []
  defp detect_performance_anomalies(_profile, _anomaly_detector), do: []
  defp detect_consistency_anomalies(_profile, _anomaly_detector), do: []

  defp update_anomaly_detector(detector, _analysis_result), do: detector

  defp update_profiling_stats(stats, :profile_updated) do
    %{stats | last_profile_update: DateTime.utc_now()}
  end

  defp update_profiling_stats(stats, :anomalies_detected, count) do
    %{
      stats
      | anomalies_detected: stats.anomalies_detected + count,
        last_profile_update: DateTime.utc_now()
    }
  end

  defp identify_global_patterns(_profiles, _behavior_patterns),
    do: [:global_risk_increase, :market_uncertainty]

  defp calculate_risk_distribution(_profiles), do: %{low: 0.3, medium: 0.5, high: 0.2}
  defp calculate_global_performance_stats(_profiles), do: %{avg_return: 0.05, volatility: 0.15}

  defp summarize_anomalies(_profiles),
    do: %{total: 5, high_severity: 1, medium_severity: 2, low_severity: 2}

  defp generate_global_recommendations(_profiles),
    do: ["Monitor high-risk agents", "Adjust position sizes"]
end
