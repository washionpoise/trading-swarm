# 🧬 Trading Swarm Intelligence System

Um sistema revolucionário de trading autônomo que combina **inteligência de enxame**, **algoritmos genéticos** e *
*múltiplos modelos de IA** para criar um ecossistema de trading que transcende os sistemas algorítmicos tradicionais.

## 🌟 Visão Geral

O Sistema de Trading com Inteligência de Enxame é uma abordagem inovadora que emprega centenas de agentes de trading
concorrentes que evoluem suas estratégias através de algoritmos genéticos, enquanto utilizam modelos avançados de IA (
NVIDIA Qwen, GPT-4, Claude) para análise de mercado em tempo real.

### ✨ Principais Inovações

- **Ecossistema Vivo**: Centenas de agentes de trading autônomos operando como um enxame digital
- **Evolução Contínua**: Algoritmos genéticos rodando a cada 5 minutos para evoluir estratégias
- **Orquestra de IA**: Integração de NVIDIA Qwen, GPT-4, Claude e modelos financeiros especializados
- **Arquitetura Tolerante a Falhas**: Construído no modelo de atores do Elixir com árvores de supervisão OTP
- **Inteligência em Tempo Real**: Arquitetura orientada a eventos usando Phoenix PubSub para decisões com latência de
  microssegundos

## 🏗️ Arquitetura do Sistema

### Componentes Principais

#### 🧠 TradingCore: O Cérebro do Enxame

- **SwarmSupervisor**: Gerencia centenas de processos de agentes concorrentes
- **TradingAgent**: Traders autônomos individuais com DNA de estratégia
- **GeneticCoordinator**: Executa ciclos de evolução a cada 5 minutos
- **RiskManager**: Alocação distribuída de capital (2% máximo por agente)

#### 🤖 TradingAI: A Rede de Inteligência

- **ModelCoordinator**: Roteia requisições para modelos de IA ótimos
- **NVIDIAClient**: Integração primária com modelos Qwen da NVIDIA
- **AIOrchestra**: Coordenação multi-modelo para análise superior

## 🧬 Motor de Evolução Genética

### Como as Estratégias Evoluem

A cada 5 minutos, o sistema executa um algoritmo genético sofisticado:

1. **Avaliação de Aptidão**: Performance de cada agente é medida
2. **Seleção de Elite**: Os 10% melhores agentes são preservados
3. **Crossover Genético**: Agentes elite criam descendentes híbridos
4. **Mutação Estratégica**: Novas estratégias são introduzidas
5. **Substituição**: Os mais fracos são substituídos por evoluídos

### Cinco Espécies de Estratégias

1. **Scalping**: Trades de alta frequência e pequenos lucros
2. **Trend Following**: Surfando ondas de momentum
3. **Mean Reversion**: Explorando overshoots de preço
4. **Arbitrage**: Diferenças de preço entre mercados
5. **Momentum**: Padrões de breakout e continuação

## 🛠️ Instalação e Configuração

### Pré-requisitos

- Elixir 1.15+
- Erlang/OTP 26+
- PostgreSQL 14+
- Chave API NVIDIA (configurar `NVIDIA_API_KEY`)

### Instalação

```bash
# Clone o repositório
git clone git@github.com:gabrielmaialva33/trading-swarm.git
cd trading-swarm

# Instalar dependências
mix deps.get

# Configurar banco de dados
mix ecto.setup

# Iniciar o servidor Phoenix
mix phx.server
```

### Variáveis de Ambiente

```bash
export NVIDIA_API_KEY="sua-chave-nvidia-aqui"
export DATABASE_URL="postgresql://user:password@localhost/trading_swarm_dev"
```

## 🏃‍♂️ Executando o Sistema

### Desenvolvimento Local

```bash
# Iniciar em modo interativo
iex -S mix phx.server

# Verificar status do enxame
iex> TradingSwarm.Core.SwarmSupervisor.get_swarm_statistics()

# Verificar status de risco
iex> TradingSwarm.Core.RiskManager.get_risk_status()
```

Acesse [`localhost:4000`](http://localhost:4000) no seu browser.

## 📈 Métricas de Performance

- **Agentes Concorrentes**: 500+ processos de trading simultâneos
- **Latência de Decisão**: Sub-100ms de evento para decisão de trade
- **Velocidade de Evolução**: Evolução completa em ciclos de 5 minutos
- **Gerenciamento de Risco**: Máximo 2% de risco por agente, 15% sistema-wide

## 🚀 Status do Desenvolvimento

**✅ Concluído:**

- Sistema de agentes de trading com GenServer
- Algoritmo genético para evolução de estratégias
- Integração com NVIDIA API
- Gerenciamento de risco distribuído
- Sistema de eventos Phoenix PubSub

**🚧 Em Desenvolvimento:**

- Dashboard Phoenix LiveView
- Otimização avançada de portfólio
- Múltiplos provedores de dados de mercado

## ⚠️ Aviso de Risco

Este é um sistema experimental para fins educacionais e de pesquisa. Trading envolve risco substancial e pode resultar
em perda de capital. Use apenas com dinheiro que você pode se dar ao luxo de perder.

---

**Este não é apenas trading algorítmico—esta é inteligência de trading que vive, aprende e evolui.** 🧬✨
