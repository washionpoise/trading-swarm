defmodule TradingSwarm.AI.NvidiaClient do
  @moduledoc """
  Cliente para integração com NVIDIA NIM API.
  
  Fornece acesso aos modelos de linguagem da NVIDIA para análise de trading,
  geração de estratégias e análise de sentimento de mercado.
  """
  
  require Logger
  
  @base_url "https://integrate.api.nvidia.com"
  @chat_completions_endpoint "/v1/chat/completions"
  
  @models %{
    qwen: "nvidia/llama3-chatqa-1.5-70b",
    nemotron: "nvidia/nemotron-4-340b-instruct",
    small_model: "nvidia/llama3-chatqa-1.5-8b"
  }
  
  def analyze_market_sentiment(text, symbol, model \\ :qwen) do
    prompt = build_sentiment_prompt(text, symbol)
    
    request_params = %{
      model: @models[model],
      messages: [
        %{
          role: "system",
          content: "Você é um analista financeiro profissional especializado em análise de sentimento de mercado."
        },
        %{
          role: "user", 
          content: prompt
        }
      ],
      temperature: 0.3,
      max_tokens: 1000,
      stream: false
    }
    
    make_api_request(request_params)
  end
  
  def generate_trading_strategy(market_data, strategy_type, model \\ :qwen) do
    prompt = build_strategy_prompt(market_data, strategy_type)
    
    request_params = %{
      model: @models[model],
      messages: [
        %{
          role: "system",
          content: "Você é um especialista em trading quantitativo especializado em estratégias algorítmicas."
        },
        %{
          role: "user",
          content: prompt
        }
      ],
      temperature: 0.4,
      max_tokens: 1500,
      stream: false
    }
    
    make_api_request(request_params)
  end
  
  defp make_api_request(params) do
    api_key = get_api_key()
    
    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"},
      {"User-Agent", "TradingSwarm/1.0"}
    ]
    
    body = Jason.encode!(params)
    
    case HTTPoison.post(@base_url <> @chat_completions_endpoint, body, headers, timeout: 30_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, response_data} ->
            parse_completion_response(response_data)
          
          {:error, decode_error} ->
            Logger.error("Falha ao decodificar resposta da API NVIDIA: #{inspect(decode_error)}")
            {:error, "Invalid JSON response"}
        end
      
      {:ok, %HTTPoison.Response{status_code: 401}} ->
        Logger.error("Falha de autenticação da API NVIDIA")
        {:error, "Authentication failed - check API key"}
      
      {:ok, %HTTPoison.Response{status_code: 402}} ->
        Logger.error("Pagamento requerido para API NVIDIA")
        {:error, "Payment required - check billing"}
      
      {:ok, %HTTPoison.Response{status_code: 429}} ->
        Logger.warn("Limite de taxa da API NVIDIA excedido")
        {:error, "Rate limit exceeded"}
      
      {:ok, %HTTPoison.Response{status_code: status_code, body: error_body}} ->
        Logger.error("Erro da API NVIDIA #{status_code}: #{error_body}")
        {:error, "API error: #{status_code}"}
      
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Falha na requisição HTTP: #{inspect(reason)}")
        {:error, "Network error: #{reason}"}
    end
  end
  
  defp parse_completion_response(%{"choices" => [%{"message" => %{"content" => content}} | _]}) do
    {:ok, %{content: content, timestamp: DateTime.utc_now()}}
  end
  
  defp parse_completion_response(response) do
    Logger.warn("Formato de resposta inesperado da API NVIDIA: #{inspect(response)}")
    {:error, "Unexpected response format"}
  end
  
  defp build_sentiment_prompt(text, symbol) do
    """
    Analise as seguintes informações de mercado para #{symbol} e forneça análise de sentimento:
    
    #{text}
    
    Forneça sua análise em formato JSON:
    {
      "sentiment": "bullish|bearish|neutral",
      "confidence": 0.0-1.0,
      "key_factors": ["fator1", "fator2", "fator3"],
      "recommendation": "buy|sell|hold",
      "target_price": numero ou null,
      "time_horizon": "short|medium|long",
      "risk_level": "low|medium|high"
    }
    
    Foque em insights acionáveis e métricas quantificáveis.
    """
  end
  
  defp build_strategy_prompt(market_data, strategy_type) do
    """
    Gere uma estratégia de trading #{strategy_type} baseada nos seguintes dados de mercado:
    
    #{inspect(market_data)}
    
    Forneça uma estratégia detalhada em formato JSON:
    {
      "strategy_name": "nome descritivo",
      "entry_conditions": ["condição1", "condição2"],
      "exit_conditions": ["condição1", "condição2"],
      "risk_parameters": {
        "stop_loss_pct": numero,
        "take_profit_pct": numero,
        "position_size_pct": numero
      },
      "technical_indicators": ["indicador1", "indicador2"],
      "time_frame": "1m|5m|15m|1h|4h|1d",
      "market_conditions": "trending|ranging|volatile",
      "expected_win_rate": numero,
      "risk_reward_ratio": numero
    }
    
    Garanta que a estratégia seja específica, testável e inclua gerenciamento de risco adequado.
    """
  end
  
  defp get_api_key do
    case System.get_env("NVIDIA_API_KEY") do
      nil ->
        Logger.error("Variável de ambiente NVIDIA_API_KEY não configurada")
        raise "NVIDIA API key not configured"
      
      key when is_binary(key) and byte_size(key) > 0 ->
        key
      
      _ ->
        Logger.error("Formato inválido da chave NVIDIA API")
        raise "Invalid NVIDIA API key"
    end
  end
  
  def health_check do
    simple_request = %{
      model: @models.small_model,
      messages: [%{role: "user", content: "Hello"}],
      max_tokens: 10
    }
    
    case make_api_request(simple_request) do
      {:ok, _response} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
  
  def available_models, do: @models
end