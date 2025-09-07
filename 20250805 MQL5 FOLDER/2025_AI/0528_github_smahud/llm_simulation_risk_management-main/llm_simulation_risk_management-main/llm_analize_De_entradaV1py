#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Natural Gas Trading Dashboard with LLM Integration

A simulation of a natural gas futures trading system that uses LLM (Large Language Model)
analytics to make trading decisions based on price action, support/resistance levels, 
and volume patterns. The dashboard visualizes price movements, trading decisions, and
LLM reasoning in real-time.

OPTIMIZED VERSION: Significantly reduced token usage in LLM API calls
"""
from pyngrok import ngrok
# Standard library imports
import os
import json
import time
import threading
from datetime import datetime

# Third-party imports
import numpy as np
import pandas as pd
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import dash
from dash import dcc, html, Input, Output, State, callback_context
import dash_bootstrap_components as dbc

# API client setup
from dotenv import load_dotenv
load_dotenv()  # load environment variables from .env file
from openai import OpenAI

# Configuration constants
LLM_EVERY = 1  # Run LLM analysis on every 5th candle
# OpenAI API client initialization
client = OpenAI(
    timeout=5.0,    # 5 second timeout
    max_retries=2   # Limit retries to avoid hanging
)

# -----------------------------------------------------------------------------
# CONFIGURAÇÕES BÁSICAS
# -----------------------------------------------------------------------------
SUPPORT_RESISTANCE_LEVELS = [4.0, 3.9, 3.85, 3.8]
CONTRACT_MULTIPLIER      = 10_000     # Cada ponto inteiro (1,00 USD/MMBtu) = US$10 000 por contrato
CSV_PATH = r"C:\Users\Alvino\Documents\DataH\agent_projetc_simulation\operacao_test_llm.csv"

# -----------------------------------------------------------------------------
# VARIÁVEIS DE CACHE - NOVA IMPLEMENTAÇÃO
# -----------------------------------------------------------------------------
last_analysis_index = -1  # Último índice analisado pelo LLM
cached_llm_state = {
    "last_analysis": None,  # Último resultado completo da análise
    "recent_decisions": []  # Lista das últimas decisões (para contexto)
}

# -----------------------------------------------------------------------------
# CRIA SIMULAÇÃO CASO NÃO EXISTA CSV
# -----------------------------------------------------------------------------
if not os.path.exists(CSV_PATH):
    dates = pd.date_range(start='2025-01-01', periods=100, freq='H')
    np.random.seed(42)
    base_price = 3.9
    volatility = 0.15
    opens = [base_price]
    for i in range(1, 100):
        drift = np.random.normal(0, volatility * 0.1)
        bias  = -0.005
        opens.append(max(3.7, min(4.1, opens[-1] + drift + bias)))

    highs  = [o + np.random.uniform(0.01, volatility * 0.5) for o in opens]
    lows   = [o - np.random.uniform(0.01, volatility * 0.5) for o in opens]
    closes = []
    for i in range(100):
        if np.random.random() < 0.6:
            closes.append(opens[i] - np.random.uniform(0, (opens[i] - lows[i]) * 0.8))
        else:
            closes.append(opens[i] + np.random.uniform(0, (highs[i] - opens[i]) * 0.8))

    volumes   = np.random.randint(1000, 10000, 100)
    daily_avg = pd.Series(closes).rolling(window=5).mean().fillna(method='bfill').tolist()
    df = pd.DataFrame({
        'Date': dates,
        'Open': opens,
        'High': highs,
        'Low': lows,
        'Close': closes,
        'Volume': volumes,
        'Daily Avg(5)': daily_avg
    })

    for level in SUPPORT_RESISTANCE_LEVELS:
        for i in range(5, 95, 20):
            df.loc[i:i+5, 'Low']   = level - np.random.uniform(0, 0.03, 6)
            df.loc[i:i+5, 'Close'] = level + np.random.uniform(-0.02, 0.02, 6)

    import tempfile
    temp_dir = tempfile.gettempdir()
    CSV_PATH = os.path.join(temp_dir, "natural_gas_data_sample.csv")
    df.to_csv(CSV_PATH, index=False)
    print(f"Simulated data file created at: {CSV_PATH}")
else:
    df = pd.read_csv(CSV_PATH)
    try:
        df['Date'] = pd.to_datetime(df['Date'], format='%m/%d/%y %H:%M')
    except:
        try:
            df['Date'] = pd.to_datetime(df['Date'], format='%m/%d/%Y %H:%M')
        except:
            try:
                df['Date'] = pd.to_datetime(df['Date'], format='%Y-%m-%d %H:%M:%S')
            except:
                df['Date'] = pd.to_datetime(df['Date'])

# -----------------------------------------------------------------------------
# ESTADO INICIAL DA POSIÇÃO
# -----------------------------------------------------------------------------
initial_contracts = 5
current_contracts = initial_contracts
last_action       = "Initial entry: 5 contracts (SHORT)"
entry_price       = df['Close'].iloc[0]

action_history = [{
    "time":      df['Date'].iloc[0],
    "action":    last_action,
    "contracts": current_contracts,
    "price":     df['Close'].iloc[0]
}]
analysis_history = []
llm_thoughts     = "Starting market analysis for natural gas…"
llm_confidence_explanation = "Awaiting first analysis..."

# -----------------------------------------------------------------------------
# FUNÇÕES UTILITÁRIAS - ALTAMENTE OTIMIZADAS
# -----------------------------------------------------------------------------
def ask_llm_with_cache(current_data, price_history, support_resistance_levels, current_contracts, entry_price, last_action, current_index):
    """
    Highly optimized version of the ask_llm function that drastically reduces token usage
    by sending only essential data and using an improved caching strategy.
    """
    global last_analysis_index, cached_llm_state
    
    try:
        # Extract only needed fields from current candle
        current_candle = {
            "close": current_data["Close"],
            "volume": current_data["Volume"]
        }
        
        # 1. OPTIMIZATION: Check if analysis is truly needed
        should_analyze = False
        
        # First analysis or too long since last one
        if last_analysis_index == -1 or (current_index - last_analysis_index) >= 10:
            should_analyze = True
        else:
            # Check for significant price movement (>0.5%)
            last_candle_index = max(0, len(price_history) - (current_index - last_analysis_index) - 1)
            if last_candle_index < len(price_history):
                last_close = price_history[last_candle_index]["close"]
                current_close = current_data["Close"]
                price_change_pct = abs(current_close - last_close) / last_close
                
                if price_change_pct > 0.005:
                    should_analyze = True
                    
                # Check if crossed any support/resistance level
                for level in support_resistance_levels:
                    if (last_close > level and current_close < level) or \
                       (last_close < level and current_close > level):
                        should_analyze = True
                        break
                        
                # Check if volume is abnormally high (2x average)
                if len(price_history) >= 5:
                    recent_volumes = [p["volume"] for p in price_history[-5:]]
                    avg_volume = sum(recent_volumes) / len(recent_volumes)
                    if current_data["Volume"] > avg_volume * 2:
                        should_analyze = True
        
        # 2. If analysis not needed, return cached result
        if not should_analyze and cached_llm_state["last_analysis"] is not None:
            cached_decision = cached_llm_state["last_analysis"].copy()
            cached_decision["reasoning"] = "Market conditions stable, maintaining previous analysis"
            cached_decision["confidence"] = cached_decision["confidence"] * 0.95
            
            return cached_decision, f"[CACHED] {cached_decision['reasoning']} (Conf: {cached_decision['confidence']:.2f})"
        
        # 3. PREPARE MINIMAL DATA
        # Only send the necessary data points, not full candles
        incremental_data = []
        
        if last_analysis_index == -1:
            # First analysis: send only last 5 candles instead of 7
            history_subset = price_history[-5:]
            incremental_data = [{
                "c": ph["close"],  # Shortened keys to reduce tokens
                "v": ph["volume"]
            } for ph in history_subset]
        else:
            # Subsequent analyses: send only new candles, with minimal data
            new_candles_start = max(0, len(price_history) - (current_index - last_analysis_index))
            incremental_data = [{
                "c": ph["close"],
                "v": ph["volume"]
            } for ph in price_history[new_candles_start:]]
        
        # Prepare only the closest support/resistance level instead of multiple
        closest_level = min([(lvl, abs(current_data["Close"] - lvl)) for lvl in support_resistance_levels], key=lambda x: x[1])
        
        # 4. Prepare minimal context for LLM
        data_for_llm = {
            "current": {
                "c": current_data["Close"],
                "v": current_data["Volume"]
            },
            "new_data": incremental_data,
            "position": {
                "contracts": current_contracts,
                "dir": "SHORT",
                "entry": entry_price,
                "pnl": entry_price - current_data["Close"]
            },
            "context": {
                "level": closest_level[0],
                "dist": closest_level[1]
            }
        }
        
        # Include minimal history of recent decisions
        if cached_llm_state["recent_decisions"]:
            data_for_llm["prev"] = {
                "actions": [d["action"] for d in cached_llm_state["recent_decisions"][-2:]],  # Just last 2 actions
                "conf": cached_llm_state["last_analysis"]["confidence"] if cached_llm_state["last_analysis"] else 0.0
            }
        
        # 5. Build a much more token-efficient prompt
        prompt = f"""
Expert nat gas trader. Current:
- Pos: {current_contracts} SHORT @ ${entry_price:.4f}
- Price: ${current_data["Close"]:.4f}
- Level: {closest_level[0]:.4f} (dist: {closest_level[1]:.4f})
- New candles: {len(incremental_data)}
Analyze the data to identify actionable trading opportunities, especially looking for:

1. BREAKOUTS: When price breaks through support/resistance levels
   - Price crossing below a support level is a strong SHORT signal
   - High volume during breakouts significantly increases confidence (>0.8)
   - The closer a breakout occurs to a key level, the stronger the signal

2. CANDLESTICK PATTERNS that indicate continuation or reversal:
   - Bearish engulfing patterns suggest adding to SHORT positions
   - Long bearish candles with small wicks show strong downward momentum
   - Multiple candles touching a level before breaking it increases confidence

3. VOLUME CONFIRMATION:
   - High volume on breakout candles confirms the move (increase confidence by 0.2)
   - Low volume pullbacks to broken levels are opportunities to add positions
   - Volume increasing as price moves away from broken level is very bullish/bearish

BE DECISIVE - when you see clear signals, confidence should be 0.7 or higher.

When multiple signals align (breakout + high volume + bearish pattern), be very confident (0.9+) and take larger positions.

Respond with a JSON object containing:
1. "action": ("ADD_SHORT", "ADD_LONG", "REDUCE_SHORT", "REDUCE_LONG", or "HOLD")
2. "quantity": number of contracts to adjust (1-3 based on confidence)
3. "reasoning": explanation of your decision 
4. "confidence": your confidence level (0.0-1.0)
5. "confidence_explanation": detailed explanation of why you chose this confidence level 

JSON response only:
{{"action":"ADD_SHORT/REDUCE_SHORT/HOLD","quantity":1-3,"reasoning":"<100 chars","confidence":0.0-1.0,"confidence_explanation":"<200 chars"}}
"""

        # 6. Call LLM with minimal tokens
        resp = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "You are a trading algorithm. Respond with valid JSON, but you may include a verbose confidence_explanation field."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.5,
            max_tokens=500  # Reduced from 300
        )
        
        # Process response
        content = resp.choices[0].message.content.strip()
        try:
            # Parse response as JSON
            decision = json.loads(content)
            
            # Update cache
            last_analysis_index = current_index
            cached_llm_state["last_analysis"] = decision
            cached_llm_state["recent_decisions"].append({
                "index": current_index,
                "action": decision["action"],
                "reasoning": decision["reasoning"],
                "confidence": decision["confidence"]
            })
            
            # Keep only the 3 most recent decisions instead of 5
            if len(cached_llm_state["recent_decisions"]) > 3:
                cached_llm_state["recent_decisions"] = cached_llm_state["recent_decisions"][-3:]
            
            return decision, content
            
        except json.JSONDecodeError:
            # Return default HOLD on parsing failure
            return {"action": "HOLD", "quantity": 0, "reasoning": "Parse error", "confidence": 0.0, "confidence_explanation": "Error in LLM response"}, content
    
    except Exception as e:
        # Return default HOLD on error
        return {"action": "HOLD", "quantity": 0, "reasoning": f"Error: {str(e)[:20]}", "confidence": 0.0, "confidence_explanation": f"LLM error"}, "LLM unavailable."

def get_confidence_color(confidence):
    """Return a color based on confidence level"""
    if confidence >= 0.8:
        return "success"  # Green
    elif confidence >= 0.6:
        return "primary"  # Blue
    elif confidence >= 0.4:
        return "warning"  # Yellow
    else:
        return "danger"   # Red

# -----------------------------------------------------------------------------
# DASH APP
# -----------------------------------------------------------------------------
app    = dash.Dash(__name__, external_stylesheets=[dbc.themes.DARKLY])
server = app.server

app.layout = html.Div([
    dbc.Row([
        dbc.Col(html.H1("Natural Gas Trading Dashboard with LLM", className="text-center mb-4"), width=12)
    ]),
    dbc.Row([
        dbc.Col(dbc.Card([
            dbc.CardHeader("Simulation Controls"),
            dbc.CardBody([
                dbc.Button("Start Simulation", id="start-button", color="success", className="me-2"),
                dbc.Button("Pause", id="pause-button", color="warning", className="me-2"),
                dbc.Button("Restart", id="reset-button", color="danger"),
                html.Hr(),
                html.Label("Speed (seconds per candle):"),
                dcc.Slider(id="speed-slider", min=0.2, max=3, step=0.2, value=1,
                           marks={i: f"{i}s" for i in [0.2,1,2,3]})
            ])
        ]), width=12, className="mb-4")
    ]),
    dbc.Row([
        dbc.Col(dbc.Card([
            dbc.CardHeader("Price Chart"),
            dbc.CardBody(dcc.Graph(id="price-chart", style={"height":"600px"}, config={"displayModeBar":False}))
        ]), width=8),
        dbc.Col([
            dbc.Card([
                dbc.CardHeader("Status"),
                dbc.CardBody([
                    html.H5("Current Position:"), html.H3(id="current-position"),
                    html.Hr(),
                    html.H5("Current Price:"), html.H3(id="current-price"),
                    html.Hr(),
                    html.H5("P&L:"), html.H3(id="pnl")
                ])
            ], className="mb-4"),
            dbc.Card([
                dbc.CardHeader("LLM Analysis"),
                dbc.CardBody([
                    dbc.Tabs([
                        dbc.Tab([
                            html.H5("Thoughts:"), 
                            html.Pre(id="llm-thoughts", style={
                                "whiteSpace":"pre-wrap","fontSize":"0.85rem",
                                "backgroundColor":"#343a40","padding":"10px","borderRadius":"5px"}),
                            html.Hr(),
                            html.H5("Last action:"), 
                            html.Div(id="llm-action", style={"fontWeight":"bold"})
                        ], label="Analysis"),
                        dbc.Tab([
                            html.H5("Confidence Level:"),
                            html.Div([
                                dbc.Progress(id="confidence-bar", value=0, color="success", 
                                             className="mb-3", style={"height": "20px"}),
                                html.Div(id="confidence-value", className="text-center")
                            ]),
                            html.Hr(),
                            html.H5("Explanation:"),
                            html.Div(id="confidence-explanation", style={
                                "backgroundColor":"#343a40","padding":"10px","borderRadius":"5px",
                                "fontSize":"0.9rem"})
                        ], label="Confiance")
                    ])
                ])
            ])
        ], width=4)
    ]),
    dbc.Row(dbc.Col(dbc.Card([
        dbc.CardHeader("Action & Analysis History"),
        dbc.CardBody(html.Div(id="action-history", style={"maxHeight":"500px","overflowY":"auto"}))
    ]), width=12), className="mt-4"),
    dcc.Store(id="simulation-data", data={
        "is_running": False,
        "current_index": 0,
        "speed": 1.0,
        "data": df.to_dict('records'),
        "current_contracts": current_contracts,
        "entry_price": entry_price,
        "action_history": action_history,
        "analysis_history": analysis_history,
        "llm_thoughts": llm_thoughts,
        "last_action": last_action,
        "confidence": 0.0,
        "confidence_explanation": llm_confidence_explanation
    }),
    dcc.Interval(id="simulation-interval", interval=2000, n_intervals=0, disabled=True)
])

# -----------------------------------------------------------------------------
# CALLBACK – CONTROLE DA SIMULAÇÃO
# -----------------------------------------------------------------------------
@app.callback(
    [Output("simulation-interval","disabled"),
     Output("simulation-interval","interval"),
     Output("simulation-data","data", allow_duplicate=True)],
    [Input("start-button","n_clicks"), Input("pause-button","n_clicks"),
     Input("reset-button","n_clicks"), Input("speed-slider","value")],
    [State("simulation-data","data")],
    prevent_initial_call=True
)
def control_simulation(start, pause, reset, speed, data):
    ctx = callback_context
    if not ctx.triggered: return dash.no_update, dash.no_update, dash.no_update
    trg = ctx.triggered[0]["prop_id"].split(".")[0]
    if trg=="start-button":
        data["is_running"]=True; return False, int(speed*1000), data
    if trg=="pause-button":
        data["is_running"]=False; return True, dash.no_update, data
    if trg=="reset-button":
        # Reiniciar o cache quando reiniciar a simulação
        global last_analysis_index, cached_llm_state
        last_analysis_index = -1
        cached_llm_state = {
            "last_analysis": None,
            "recent_decisions": []
        }
        
        data.update({
            "is_running": False,
            "current_index": 0,
            "current_contracts": initial_contracts,
            "entry_price": df['Close'].iloc[0],
            "action_history": [{
                "time": df['Date'].iloc[0],
                "action": "Initial entry: 5 contracts (SHORT)",
                "contracts": initial_contracts,
                "price": df['Close'].iloc[0]
            }],
            "analysis_history": [],
            "llm_thoughts": "Restarting natural gas market analysis…",
            "last_action": "Initial entry: 5 contracts (SHORT)",
            "confidence": 0.0,
            "confidence_explanation": "Awaiting first analysis..."
        })
        return True, dash.no_update, data
    return dash.no_update, int(speed*1000), dash.no_update

# -----------------------------------------------------------------------------
# CALLBACK – AVANÇA A SIMULAÇÃO - OTIMIZADO COM CACHE
# -----------------------------------------------------------------------------
@app.callback(
    [Output("price-chart","figure"), Output("current-position","children"),
     Output("current-price","children"), Output("pnl","children"),
     Output("llm-thoughts","children"), Output("llm-action","children"),
     Output("confidence-bar", "value"), Output("confidence-bar", "color"),
     Output("confidence-value", "children"), Output("confidence-explanation", "children"),
     Output("action-history","children"), Output("simulation-data","data")],
    [Input("simulation-interval","n_intervals")], [State("simulation-data","data")]
)
def update_simulation(n, data):
    if not data["is_running"]:
        return [dash.no_update]*12
    idx = data["current_index"]
    if idx >= len(data["data"]) - 1:
        data["is_running"]=False; return [dash.no_update]*11 + [data]
    idx += 1; data["current_index"]=idx

    recs         = data["data"][:idx+1]
    current_price= recs[-1]["Close"]
    open_price   = recs[-1]["Open"]

    # LLM para análise de mercado e decisões de trading (com cache)
    if idx % LLM_EVERY == 0:
        # Preparar histórico de preços recente com dados OHLCV completos
        # OPTIMIZATION: Only collect recent history (10 candles max)
        ph = [{
            "time": recs[i]["Date"],
            "open": recs[i]["Open"], 
            "high": recs[i]["High"],
            "low": recs[i]["Low"],
            "close": recs[i]["Close"],
            "volume": recs[i]["Volume"]
        } for i in range(max(0, idx-10), idx+1)]
        
        # Obter decisão do LLM como JSON estruturado (usando cache)
        decision, raw_response = ask_llm_with_cache(
            recs[-1],
            ph,
            SUPPORT_RESISTANCE_LEVELS,
            data["current_contracts"],
            data["entry_price"],
            data["last_action"],
            idx  # Passar o índice atual para o sistema de cache
        )
        
        # Armazenar a resposta bruta para exibição
        data["llm_thoughts"] = raw_response
        
        # Verificar se a resposta veio do cache ou do LLM
        is_cached = raw_response.startswith("[CACHED]")
        
        # Só adicionar ao histórico de análise se não for do cache
        if not is_cached:
            data["analysis_history"].append({
                "time": recs[-1]["Date"], 
                "price": current_price, 
                "thoughts": raw_response
            })
        
        # Processar a decisão estruturada do LLM
        action = decision.get("action", "HOLD")
        quantity = decision.get("quantity", 0)
        reasoning = decision.get("reasoning", "No reasoning provided")
        confidence = decision.get("confidence", 0.0)
        confidence_explanation = decision.get("confidence_explanation", "No explanation provided")
        
        # Armazenar dados de confiança
        data["confidence"] = confidence
        data["confidence_explanation"] = confidence_explanation
        
        # Executar a ação de trading se não for HOLD e quantity > 0
        # Também registrar HOLDs com alta confiança para ver o que está acontecendo
        if (action != "HOLD" and quantity > 0) or confidence > 0.5:
            old = data["current_contracts"]
            
            if action == "ADD_SHORT":
                # Para sinais de alta confiança, considerar usar a quantidade sugerida
                # Para confiança menor, ainda pegar pelo menos 1 contrato se acima do limiar
                adjusted_qty = quantity if confidence >= 0.50 else max(1, quantity-1)
                data["current_contracts"] += adjusted_qty
                new = data["current_contracts"]
                # média ponderada do preço de entrada
                data["entry_price"] = (data["entry_price"]*old + current_price*adjusted_qty)/new
                
                act = (f"{'[CACHED] ' if is_cached else ''}LLM: {action} {adjusted_qty} → {new} @ {current_price:.4f}; "
                       f"Entry={data['entry_price']:.4f}; "
                       f"Reason: {reasoning}")
                       
            elif action == "REDUCE_SHORT" and old >= quantity:
                # Ajustar quantidade se necessário com base na confiança
                adjusted_qty = min(quantity, old)  # Não pode reduzir abaixo de 0
                data["current_contracts"] -= adjusted_qty
                new = data["current_contracts"]
                # Preço de entrada permanece o mesmo ao reduzir posição
                
                act = (f"{'[CACHED] ' if is_cached else ''}LLM: {action} {adjusted_qty} → {new} @ {current_price:.4f}; "
                       f"Entry={data['entry_price']:.4f}; "
                       f"Reason: {reasoning}")
                
            elif action == "HOLD" and confidence > 0.6:
                # Apenas registrar a decisão de HOLD com alta confiança para transparência
                act = (f"{'[CACHED] ' if is_cached else ''}LLM: {action} @ {current_price:.4f}; "
                       f"Reason: {reasoning}")
                
            else:
                # Ação não suportada ou quantidade inválida
                act = None
                
            if act:  # Apenas atualizar se uma ação válida foi tomada
                data["action_history"].append({
                    "time": recs[-1]["Date"],
                    "action": act,
                    "contracts": data["current_contracts"],
                    "price": current_price
                })
                data["last_action"] = act

    # P&L total
    delta = data["entry_price"] - current_price
    pnl = delta * CONTRACT_MULTIPLIER * data["current_contracts"]

    # Chart - OPTIMIZATION: Less overhead in chart generation
    fig = make_subplots(rows=2, cols=1, shared_xaxes=True,
                        vertical_spacing=0.1, row_heights=[0.8,0.2],
                        specs=[[{"type":"candlestick"}],[{"type":"bar"}]])
    
    # Only show the last 50 candles maximum to improve performance
    display_records = recs[-50:] if len(recs) > 50 else recs
    
    fig.add_trace(go.Candlestick(
        x=[r["Date"] for r in display_records], 
        open=[r["Open"] for r in display_records],
        high=[r["High"] for r in display_records], 
        low=[r["Low"] for r in display_records],
        close=[r["Close"] for r in display_records], 
        name="Price"
    ), row=1, col=1)
    
    # Add support/resistance levels
    for lvl in SUPPORT_RESISTANCE_LEVELS:
        fig.add_shape(type="line", x0=display_records[0]["Date"], x1=display_records[-1]["Date"],
                      y0=lvl, y1=lvl, line=dict(dash="dash"), row=1, col=1)
    
    # Add volume bars
    fig.add_trace(go.Bar(
        x=[r["Date"] for r in display_records], 
        y=[r["Volume"] for r in display_records],
        name="Volume"
    ), row=2, col=1)
    
    # Add action markers (trades)
    # Only include actions that are in the display range
    action_dates = [r["Date"] for r in display_records]
    actions = [a for a in data["action_history"] if a["time"] in action_dates]
    
    if actions:
        fig.add_trace(go.Scatter(
            x=[a["time"] for a in actions], 
            y=[a["price"] for a in actions],
            mode="markers", 
            marker=dict(symbol="star", size=10), 
            name="Actions"
        ), row=1, col=1)
    
    # Simplified layout with less customization
    fig.update_layout(template="plotly_dark", legend=dict(orientation="h", y=1.02))
    fig.update_xaxes(type="category")

    # Optimize history display - limit to recent entries only
    combo = []
    for a in data["action_history"][-10:]:  # Last 10 actions only
        combo.append({"time": a["time"], "content": a["action"], "type": "ACTION"})
    for an in data["analysis_history"][-5:]:  # Last 5 analyses only
        combo.append({"time": an["time"], "content": an["thoughts"], "type": "ANALYSIS"})
    combo.sort(key=lambda x: x["time"], reverse=True)
    
    # Build history display
    hist = []
    for itm in combo[:15]:  # Limit to 15 total items
        color = "yellow" if itm["type"]=="ACTION" else "lightblue"
        hist.append(html.Div([
            html.Span(f"{itm['time']}: ", style={"fontWeight":"bold"}),
            html.Span(itm["content"], style={"color": color})
        ], style={"marginBottom":"6px"}))
    
    # Confidence info
    confidence_value = data["confidence"] * 100  # Convert to percentage
    confidence_color = get_confidence_color(data["confidence"])
    confidence_text = f"Confidence: {confidence_value:.1f}%"

    return (
        fig,
        f"{data['current_contracts']} Contracts (SHORT)",
        f"{current_price:.4f}",
        f"{pnl:,.2f} USD" + (" (Profit)" if pnl>0 else " (Loss)"),
        data["llm_thoughts"],
        data["last_action"],
        confidence_value,
        confidence_color,
        confidence_text,
        data["confidence_explanation"],
        hist,
        data
    )

# -----------------------------------------------------------------------------
# RUN SERVER
# -----------------------------------------------------------------------------



if __name__ == "__main__":
    # debug=True se quiser recarregar no código; em produção ponha False
    app.run(debug=True, host="0.0.0.0", port=8050)
