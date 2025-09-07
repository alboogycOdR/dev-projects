# SR_Indicator - Indicador de Suporte e Resistência para MetaTrader 5

Este indicador identifica e desenha níveis de suporte e resistência em timeframes H4 e H1, além de marcar linhas de abertura, fechamento, máximas e mínimas do mercado para análise técnica avançada. O indicador foi projetado para ser facilmente acessível via API Python, permitindo integração com algoritmos de trading e modelos de linguagem (LLMs).

## Funcionalidades

- **Detecção automática** de níveis de suporte e resistência em múltiplos timeframes (H4 e H1)
- **Algoritmo avançado** para identificação de swing highs/lows com múltiplas confirmações
- **Classificação de níveis** por número de toques para identificar os mais significativos
- **Linhas de mercado** mostrando aberturas, fechamentos, máximas e mínimas dos dias recentes
- **Exportação de dados** em formato JSON para análise externa
- **Acesso via API Python** do MetaTrader 5 para integração com sistemas externos

## Instalação

1. Copie o arquivo `SR_Indicator.mq5` para a pasta `MQL5/Indicators` do seu terminal MetaTrader 5.
2. Abra o MetaEditor no MT5 (F4) e compile o indicador.
3. Reinicie o MetaTrader 5 ou atualize a lista de indicadores (Ctrl+N).
4. O indicador estará disponível em "Indicadores Personalizados" → "SR_Indicator".

## Parâmetros do Indicador

| Parâmetro | Descrição | Valor padrão |
|-----------|-----------|--------------|
| StartDate | Data inicial para análise | D'2025.03.01 00:00' |
| EndDate | Data final para análise | D'2025.05.10 00:00' |
| HistoricalDays | Dias para análise histórica | 70 |
| H4_Lookback | Barras para análise H4 | 400 |
| H1_Lookback | Barras para análise H1 | 600 |
| RecentDaysMarket | Dias recentes para abertura/fechamento | 5 |
| MaxH4Lines | Número máximo de linhas H4 | 8 |
| MaxH1Lines | Número máximo de linhas H1 | 10 |
| ZoneThreshold | Limiar para zonas de consolidação | 0.0008 |
| TouchesForStrong | Número de toques para considerar forte | 2 |
| H4_StrongColor | Cor para SR forte em H4 | clrCrimson |
| H1_StrongColor | Cor para SR forte em H1 | clrGold |
| MarketHoursColor | Cor para linhas de mercado | clrDodgerBlue |
| LineWidth_H4 | Largura das linhas H4 | 2 |
| LineWidth_H1 | Largura das linhas H1 | 1 |
| LineWidth_Market | Largura das linhas de mercado | 1 |
| StyleH4 | Estilo das linhas H4 | STYLE_SOLID |
| StyleH1 | Estilo das linhas H1 | STYLE_SOLID |
| StyleMarket | Estilo das linhas de mercado | STYLE_DASH |

2. Extraia apenas os níveis de preço dos seguintes buffers:
   - H4_Support_Resistance[] (Buffer 0) - todos os níveis importantes no timeframe H4
   - H1_Support_Resistance[] (Buffer 1) - todos os níveis importantes no timeframe H1
   - MarketOpenBuffer[] (Buffer 2) - preços de abertura dos últimos dias
   - MarketCloseBuffer[] (Buffer 3) - preços de fechamento dos últimos dias
   - MarketHighBuffer[] (Buffer 4) - preços máximos dos últimos dias
   - MarketLowBuffer[] (Buffer 5) - preços mínimos dos últimos dias
## Buffers do Indicador

O indicador disponibiliza os seguintes buffers para acesso externo:

| Índice | Nome | Descrição |
|--------|------|-----------|
| 0 | H4_Support_Resistance | Níveis de suporte e resistência em H4 |
| 1 | H1_Support_Resistance | Níveis de suporte e resistência em H1 |
| 2 | MarketOpenBuffer | Níveis de abertura do mercado |
| 3 | MarketCloseBuffer | Níveis de fechamento do mercado |
| 4 | MarketHighBuffer | Níveis de máximas do mercado |
| 5 | MarketLowBuffer | Níveis de mínimas do mercado |

**Observação**: Para diferenciar os níveis de suporte e resistência nos buffers unificados, o indicador exporta um arquivo JSON que contém essa informação.

## Exportação para JSON

O indicador automaticamente gera um arquivo JSON na pasta Files do MetaTrader 5 com o seguinte formato:

```json
{
  "H4_Support_Resistance": [
    {"price": 1.12345, "type": "Support"},
    {"price": 1.12567, "type": "Resistance"}
  ],
  "H1_Support_Resistance": [
    {"price": 1.12400, "type": "Support"},
    {"price": 1.12500, "type": "Resistance"}
  ],
  "Market_Data": [
    {
      "open": 1.12340,
      "close": 1.12360,
      "high": 1.12380,
      "low": 1.12320
    }
  ]
}
```

## Acesso via Python

Para acessar os dados do indicador em Python, você pode utilizar a API MetaTrader 5. Abaixo está um exemplo de código para integração:

```python
import MetaTrader5 as mt5
import pandas as pd
import numpy as np
from datetime import datetime
import json

# Conectar ao MetaTrader 5
if not mt5.initialize():
    print("Falha na inicialização do MetaTrader 5")
    mt5.shutdown()
    exit()

# Configurações
symbol = "EURUSD"  # Substitua pelo símbolo que você está usando
timeframe = mt5.TIMEFRAME_M15  # Ajuste conforme necessário

# Obter handle do indicador
indicator_handle = mt5.indicator_create(
    symbol, 
    timeframe,
    "SR_Indicator",  # Nome do arquivo do indicador sem extensão
    # Parâmetros do indicador (opcional)
    StartDate=datetime(2025, 3, 1),
    EndDate=datetime(2025, 5, 10)
)

if indicator_handle == 0:
    print("Falha ao criar handle do indicador:", mt5.last_error())
    mt5.shutdown()
    exit()

# Número de barras a considerar
rates_count = 100

# Acessar os diferentes buffers unificados
h4_sr = mt5.copy_buffer(indicator_handle, 0, 0, rates_count)  # H4_Support_Resistance
h1_sr = mt5.copy_buffer(indicator_handle, 1, 0, rates_count)  # H1_Support_Resistance
market_open = mt5.copy_buffer(indicator_handle, 2, 0, rates_count)
market_close = mt5.copy_buffer(indicator_handle, 3, 0, rates_count)
market_high = mt5.copy_buffer(indicator_handle, 4, 0, rates_count)
market_low = mt5.copy_buffer(indicator_handle, 5, 0, rates_count)

# Filtrar valores válidos (diferentes de EMPTY_VALUE e maiores que 0)
h4_sr = [p for p in h4_sr if not np.isnan(p) and p > 0]
h1_sr = [p for p in h1_sr if not np.isnan(p) and p > 0]

# Processar informações de mercado
market_data = []
for i in range(len(market_open)):
    if not np.isnan(market_open[i]) and market_open[i] > 0:
        market_data.append({
            'open': market_open[i],
            'close': market_close[i],
            'high': market_high[i],
            'low': market_low[i]
        })

# Para obter informações sobre tipo (suporte/resistência), leia o arquivo JSON exportado
json_file_path = mt5.terminal_info().data_path + "\\MQL5\\Files\\SR_Levels_" + symbol + ".json"

try:
    with open(json_file_path, 'r') as file:
        sr_data = json.load(file)
        print("Dados carregados do arquivo JSON")
except FileNotFoundError:
    # Se o arquivo não for encontrado, use apenas os valores dos buffers
    sr_data = {
        'H4_Support_Resistance': [{"price": float(price)} for price in h4_sr],
        'H1_Support_Resistance': [{"price": float(price)} for price in h1_sr],
        'Market_Data': market_data
    }
    print("Arquivo JSON não encontrado, usando apenas dados dos buffers")

# Imprimir os dados
print(json.dumps(sr_data, indent=2))

# Integração com LLM (exemplo)
def analyze_with_llm(data):
    import requests
    
    # URL da sua API LLM
    url = "https://your-llm-api.com/analyze"
    
    payload = {
        "symbol": symbol,
        "sr_levels": data,
        "prompt": "Analise os níveis de suporte e resistência e sugira possíveis pontos de entrada e saída"
    }
    
    headers = {
        "Content-Type": "application/json"
    }
    
    try:
        response = requests.post(url, json=payload, headers=headers)
        
        if response.status_code == 200:
            return response.json()
        else:
            return {"error": f"Falha com código de status {response.status_code}"}
    except Exception as e:
        return {"error": str(e)}

# Liberar o handle do indicador e desconectar
mt5.indicator_release(indicator_handle)
mt5.shutdown()

# Descomente para analisar com LLM
# llm_response = analyze_with_llm(sr_data)
# print(llm_response)
```

## Integração com Modelos de Linguagem (LLM)

Para integrar com um LLM, envie os dados JSON para sua API preferida. Exemplo de prompt para o LLM:

```
Analise os seguintes níveis de suporte e resistência para EURUSD:

Níveis H4:
- Suporte: 1.1234, 1.1220
- Resistência: 1.1250, 1.1275

Níveis H1:
- Suporte: 1.1230, 1.1225
- Resistência: 1.1245, 1.1260

Dados de Mercado:
- Dia 1: Abertura 1.1235, Fechamento 1.1240, Alta 1.1250, Baixa 1.1230
- Dia 2: Abertura 1.1240, Fechamento 1.1245, Alta 1.1255, Baixa 1.1235

Forneça uma análise técnica e possíveis cenários para o próximo movimento de preço.
```

## Notas de Implementação

1. O indicador identifica níveis de suporte e resistência principalmente através da detecção de swing highs e lows.
2. Os níveis são classificados pela quantidade de "toques" ou interações que o preço teve com o nível.
3. Níveis com mais toques têm maior relevância e são considerados mais fortes.
4. Para melhor desempenho, ajuste o parâmetro ZoneThreshold de acordo com a volatilidade do par de moedas.

## Requisitos

- MetaTrader 5 (versão 5.0.0 ou superior)
- Python 3.6+ com o módulo MetaTrader5 instalado (`pip install MetaTrader5`)
- Para integração com LLMs, você precisará de acesso à API do modelo desejado

## Solução de Problemas

**P: Não consigo ver o indicador no gráfico**
R: Verifique se o arquivo foi compilado corretamente e se não há erros no log do MetaEditor.

**P: Os níveis de suporte e resistência não parecem precisos**
R: Ajuste o parâmetro ZoneThreshold para corresponder à volatilidade do instrumento. Valores menores para instrumentos menos voláteis, valores maiores para instrumentos mais voláteis.

**P: Não consigo acessar o indicador via Python**
R: Verifique se o MetaTrader 5 está em execução e se o módulo Python está instalado corretamente. Certifique-se de que o indicador esteja compilado e disponível no terminal.

**P: O arquivo JSON não está sendo gerado**
R: Verifique as permissões da pasta Files do MetaTrader 5. O terminal deve ter permissão para gravar arquivos.

## Licença

Este código é fornecido sem garantias. Use por sua conta e risco.

---

**Desenvolvido por:** [Seu Nome/Empresa]
**Versão:** 1.0
**Data:** Maio 2025
