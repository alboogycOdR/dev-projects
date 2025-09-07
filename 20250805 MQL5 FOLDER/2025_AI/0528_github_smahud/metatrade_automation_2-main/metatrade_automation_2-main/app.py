import os
import json
import time
import numpy as np
import pandas as pd
import MetaTrader5 as mt5
from datetime import datetime, timedelta
import dash
from dash import dcc, html, Input, Output, State, callback_context
import dash_bootstrap_components as dbc
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import threading
import queue
import re
from langchain.chains import LLMChain
from langchain.memory import ConversationBufferMemory
from langchain_openai import ChatOpenAI
from indicators import calculate_atr, calculate_directional_entropy, calculate_ema
from prompts import market_analysis_prompt, initial_context_prompt, trade_feedback_prompt
from utils import parse_llm_response, format_trade_for_feedback, calculate_position_performance, detect_price_patterns

# Global variables
running = False
trade_queue = queue.Queue()
memory = None
llm_chain = None
current_position = 0  # Current number of contracts
max_contracts = 5  # Default max contracts
confidence_level = 0  # Market confidence (-100 to 100)
llm_reasoning = ""
total_pnl = 0.0
market_direction = "Neutral"  # Market direction (Bullish, Bearish, Neutral)
trade_history = []
support_resistance_levels = []

# Define the timeframe mapping
timeframe_dict = {
    "M1": mt5.TIMEFRAME_M1,
    "M5": mt5.TIMEFRAME_M5,
    "M15": mt5.TIMEFRAME_M15,
    "M30": mt5.TIMEFRAME_M30,
    "H1": mt5.TIMEFRAME_H1,
    "H4": mt5.TIMEFRAME_H4,
    "D1": mt5.TIMEFRAME_D1,
}

# Initialize the application
app = dash.Dash(__name__, external_stylesheets=[dbc.themes.DARKLY])
app.title = "MetaTrader5 LLM Trading Bot"

# Set API Key from environment variable
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")

def initialize_mt5(server="AMPGlobalUSA-Demo", login=1522209, password="P*5gSgXn"):
    """Initialize connection to MetaTrader5"""
    if not mt5.initialize():
        print("initialize() failed")
        mt5.shutdown()
        return False
    
    # Connect to the specified account
    authorized = mt5.login(login, password, server)
    if not authorized:
        print(f"Failed to connect to account {login}, error code: {mt5.last_error()}")
        mt5.shutdown()
        return False
    
    print(f"Connected to account {login}")
    return True

def initialize_llm_chain():
    """Initialize LLM chain with Langchain"""
    global memory, llm_chain
    
    # Initialize memory
    memory = ConversationBufferMemory(memory_key="chat_history", return_messages=True)
    
    # Initialize LLM
    llm = ChatOpenAI(
        temperature=0.2,
        api_key=OPENAI_API_KEY,
        model_name="gpt-4-turbo"  # or "gpt-3.5-turbo" based on your needs
    )
    
    # Create chain with the imported prompt
    llm_chain = LLMChain(
        llm=llm,
        prompt=market_analysis_prompt,
        memory=memory
    )
    
    return llm_chain

def get_initial_context(symbol, timeframe, num_candles=10):
    """Get initial market context for LLM"""
    if timeframe not in timeframe_dict:
        return "Invalid timeframe"
    
    # Get historical data
    rates = mt5.copy_rates_from_pos(symbol, timeframe_dict[timeframe], 0, num_candles)
    
    if rates is None or len(rates) == 0:
        return "No data available"
    
    # Convert to dataframe
    df = pd.DataFrame(rates)
    df['time'] = pd.to_datetime(df['time'], unit='s')
    
    # Calculate indicators
    df['atr'] = calculate_atr(df, period=14)
    df['entropy'] = calculate_directional_entropy(df, period=14)
    df['ema9'] = calculate_ema(df['close'], period=9)
    
    # Detect price patterns
    patterns = detect_price_patterns(df)
    
    # Prepare context summary
    market_summary = {
        "period_analyzed": f"{num_candles} {timeframe} candles",
        "start_date": df['time'].iloc[0].strftime("%Y-%m-%d %H:%M"),
        "end_date": df['time'].iloc[-1].strftime("%Y-%m-%d %H:%M"),
        "price_range": {
            "high": float(df['high'].max()),
            "low": float(df['low'].min()),
            "current": float(df['close'].iloc[-1])
        },
        "trend_summary": {
            "direction": "Bullish" if df['close'].iloc[-1] > df['open'].iloc[0] else "Bearish",
            "strength": abs(float(df['close'].iloc[-1] - df['open'].iloc[0])) / float(df['atr'].iloc[-1]) if not np.isnan(df['atr'].iloc[-1]) and df['atr'].iloc[-1] != 0 else 0,
        },
        "volatility": {
            "average_atr": float(df['atr'].mean()) if not np.isnan(df['atr'].mean()) else 0,
            "entropy": float(df['entropy'].mean()) if not np.isnan(df['entropy'].mean()) else 0
        },
        "key_levels": {
            "recent_high": float(df['high'].max()),
            "recent_low": float(df['low'].min()),
            "ema9": float(df['ema9'].iloc[-1]) if not np.isnan(df['ema9'].iloc[-1]) else 0
        },
        "price_patterns": patterns
    }
    
    return json.dumps(market_summary, indent=2)

def get_current_candle_data(symbol, timeframe):
    """Get current candle data"""
    if timeframe not in timeframe_dict:
        return "Invalid timeframe"
    
    # Get current candle
    rates = mt5.copy_rates_from_pos(symbol, timeframe_dict[timeframe], 0, 2)
    
    if rates is None or len(rates) < 2:
        return "No data available"
    
    # Convert to dataframe
    df = pd.DataFrame(rates)
    df['time'] = pd.to_datetime(df['time'], unit='s')
    
    # Calculate indicators
    atr = calculate_atr(df, period=14)
    entropy = calculate_directional_entropy(df, period=14)
    ema9 = calculate_ema(df['close'], period=9)
    
    # Detect price patterns
    patterns = detect_price_patterns(df)
    
    # Prepare data summary
    candle_data = {
        "timestamp": df['time'].iloc[-1].strftime("%Y-%m-%d %H:%M"),
        "ohlc": {
            "open": float(df['open'].iloc[-1]),
            "high": float(df['high'].iloc[-1]),
            "low": float(df['low'].iloc[-1]),
            "close": float(df['close'].iloc[-1])
        },
        "volume": float(df['tick_volume'].iloc[-1]),
        "indicators": {
            "atr": float(atr.iloc[-1]) if not np.isnan(atr.iloc[-1]) else 0,
            "directional_entropy": float(entropy.iloc[-1]) if not np.isnan(entropy.iloc[-1]) else 0,
            "ema9": float(ema9.iloc[-1]) if not np.isnan(ema9.iloc[-1]) else 0
        },
        "price_action": {
            "candle_type": "Bullish" if df['close'].iloc[-1] > df['open'].iloc[-1] else "Bearish",
            "candle_size": abs(float(df['close'].iloc[-1] - df['open'].iloc[-1])),
            "upper_wick": float(df['high'].iloc[-1]) - max(float(df['open'].iloc[-1]), float(df['close'].iloc[-1])),
            "lower_wick": min(float(df['open'].iloc[-1]), float(df['close'].iloc[-1])) - float(df['low'].iloc[-1])
        },
        "price_patterns": patterns
    }
    
    return json.dumps(candle_data, indent=2)

def execute_trade(symbol, action, contracts_to_adjust):
    """Execute trade on MetaTrader5"""
    global current_position, total_pnl
    
    # Check if we need to adjust position
    if action == "WAIT" or contracts_to_adjust == 0:
        return "No trade executed"
    
    # Get current symbol info
    symbol_info = mt5.symbol_info(symbol)
    if symbol_info is None:
        return f"Symbol {symbol} not found"
    
    # Prepare trade request
    trade_type = mt5.ORDER_TYPE_BUY if action == "ADD_CONTRACTS" else mt5.ORDER_TYPE_SELL
    price = symbol_info.ask if trade_type == mt5.ORDER_TYPE_BUY else symbol_info.bid
    
    # Determine volume based on contracts to adjust
    volume = abs(contracts_to_adjust)
    
    # Create trade request
    request = {
        "action": mt5.TRADE_ACTION_DEAL,
        "symbol": symbol,
        "volume": volume,
        "type": trade_type,
        "price": price,
        "deviation": 20,  # Price deviation in points
        "magic": 123456,  # Magic number for identifying trades
        "comment": f"LLM Bot {'Buy' if trade_type == mt5.ORDER_TYPE_BUY else 'Sell'}",
        "type_time": mt5.ORDER_TIME_GTC,
        "type_filling": mt5.ORDER_FILLING_IOC,
    }
    
    # Send trade order
    result = mt5.order_send(request)
    
    if result.retcode != mt5.TRADE_RETCODE_DONE:
        return f"Order failed, retcode={result.retcode}"
    
    # Update position tracking
    if action == "ADD_CONTRACTS":
        current_position += contracts_to_adjust
    else:  # REMOVE_CONTRACTS
        current_position -= contracts_to_adjust
    
    # For demonstration, update PnL with a simulated value
    # In a real scenario, you would calculate this from actual positions
    pnl_change = np.random.normal(0, 10) * contracts_to_adjust  # Simulated PnL change
    total_pnl += pnl_change
    
    # Add to trade history
    trade_history.append({
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "action": action,
        "contracts": contracts_to_adjust,
        "price": price,
        "pnl_change": pnl_change
    })
    
    return f"Order executed successfully: {action}, {contracts_to_adjust} contracts at {price}"

def analyze_market(symbol, timeframe, use_initial_context=False):
    """Analyze market using LLM"""
    global llm_reasoning, confidence_level, market_direction
    
    # Get support resistance levels as string
    sr_str = "\n".join([f"Level {i+1}: {level}" for i, level in enumerate(support_resistance_levels)])
    
    # Get initial context if needed
    context = "{}"
    if use_initial_context:
        context = get_initial_context(symbol, timeframe)
    
    # Get current market data
    market_data = get_current_candle_data(symbol, timeframe)
    
    # Run LLM analysis
    response = llm_chain.invoke({
        "context": context,
        "market_data": market_data,
        "support_resistance": sr_str,
        "current_position": current_position,
        "max_contracts": max_contracts
    })
    
    # Parse response using utility function
    try:
        analysis = parse_llm_response(response['text'])
        
        # Update global variables
        llm_reasoning = analysis['reasoning']
        confidence_level = analysis['confidence_level']
        market_direction = analysis['direction']
        
        # Return analysis
        return analysis
    except Exception as e:
        print(f"Error in analyze_market: {e}")
        return {
            "market_summary": "Error analyzing market",
            "confidence_level": 0,
            "direction": "Neutral",
            "action": "WAIT",
            "reasoning": f"Error in LLM analysis: {str(e)}",
            "contracts_to_adjust": 0
        }

def trading_loop(symbol, timeframe):
    """Main trading loop"""
    global running, trade_history, current_position, total_pnl
    
    print(f"Starting trading loop for {symbol} on {timeframe} timeframe")
    
    # Keep track of the last processed candle time
    last_candle_time = None
    
    while running:
        try:
            # Check if a new candle has formed
            current_rates = mt5.copy_rates_from_pos(symbol, timeframe_dict.get(timeframe, mt5.TIMEFRAME_H4), 0, 1)
            if current_rates is not None and len(current_rates) > 0:
                current_candle_time = pd.to_datetime(current_rates[0]['time'], unit='s')
                
                # If this is a new candle, analyze the market
                if last_candle_time is None or current_candle_time > last_candle_time:
                    print(f"New candle detected at {current_candle_time}")
                    last_candle_time = current_candle_time
                    
                    # Perform market analysis (but don't execute trades yet)
                    analysis = analyze_market(symbol, timeframe)
                    print(f"Market analysis: {analysis['market_summary']}")
                    print(f"Confidence: {analysis['confidence_level']}, Direction: {analysis['direction']}")
            
            # Check if there are user inputs in the queue
            try:
                user_input = trade_queue.get_nowait()
                print(f"Processing user input: {user_input}")
                
                # Analyze market
                analysis = analyze_market(symbol, timeframe)
                
                # Execute trade based on analysis
                if analysis['action'] != "WAIT":
                    # Limit contract adjustments to respect max_contracts
                    contracts_to_adjust = min(
                        analysis['contracts_to_adjust'],
                        max_contracts - current_position if analysis['action'] == "ADD_CONTRACTS" else current_position
                    )
                    
                    if contracts_to_adjust > 0:
                        result = execute_trade(symbol, analysis['action'], contracts_to_adjust)
                        print(result)
                        
                        # Calculate position performance
                        symbol_info = mt5.symbol_info(symbol)
                        if symbol_info:
                            current_price = symbol_info.ask
                            performance = calculate_position_performance(trade_history, current_price)
                            total_pnl = performance['total_pnl']
                            
                            print(f"Position size: {performance['position_size']}")
                            print(f"Average entry: {performance['average_entry']:.5f}")
                            print(f"Unrealized P&L: ${performance['unrealized_pnl']:.2f}")
                            print(f"Total P&L: ${performance['total_pnl']:.2f}")
                    else:
                        print(f"Skipping trade - contracts to adjust ({contracts_to_adjust}) <= 0")
                else:
                    print("Analysis recommends waiting - no trade executed")
            
            except queue.Empty:
                # No user input, continue with regular updates
                pass
            
            # Sleep to avoid excessive polling
            time.sleep(1)
            
        except Exception as e:
            print(f"Error in trading loop: {e}")
            time.sleep(5)  # Sleep on error to avoid rapid error loops

# Create the app layout
app.layout = dbc.Container([
    dbc.Row([
        dbc.Col([
            html.H1("MetaTrader5 LLM Trading Bot", className="text-center my-4"),
        ])
    ]),
    
    dbc.Row([
        dbc.Col([
            dbc.Card([
                dbc.CardHeader("Trading Setup"),
                dbc.CardBody([
                    dbc.Row([
                        dbc.Col([
                            html.Label("Asset Symbol:"),
                            dbc.Input(id="symbol-input", type="text", value="EURUSD", placeholder="Enter symbol (e.g., EURUSD)"),
                        ], width=6),
                        dbc.Col([
                            html.Label("Timeframe:"),
                            dcc.Dropdown(
                                id="timeframe-dropdown",
                                options=[
                                    {"label": "1 Minute (M1)", "value": "M1"},
                                    {"label": "5 Minutes (M5)", "value": "M5"},
                                    {"label": "15 Minutes (M15)", "value": "M15"},
                                    {"label": "30 Minutes (M30)", "value": "M30"},
                                    {"label": "1 Hour (H1)", "value": "H1"},
                                    {"label": "4 Hours (H4)", "value": "H4"},
                                    {"label": "1 Day (D1)", "value": "D1"},
                                ],
                                value="H4"
                            ),
                        ], width=6),
                    ]),
                    
                    html.Br(),
                    
                    dbc.Row([
                        dbc.Col([
                            html.Label("Support & Resistance Levels:"),
                            dbc.Input(id="sr-input", type="text", placeholder="Enter levels separated by commas (e.g., 1.1000, 1.1050)"),
                            html.Div(id="sr-output", className="mt-2")
                        ], width=6),
                        dbc.Col([
                            html.Label("Max Contracts:"),
                            dbc.Input(id="max-contracts-input", type="number", value=5, min=1, max=100),
                        ], width=6),
                    ]),
                    
                    html.Br(),
                    
                    dbc.Row([
                        dbc.Col([
                            dbc.Checkbox(id="use-context-checkbox", label="Use Initial Market Context", value=False),
                            dbc.Tooltip(
                                "Enabling this will analyze previous candles to provide context for the LLM, but will use more tokens.",
                                target="use-context-checkbox",
                            ),
                        ], width=6),
                        dbc.Col([
                            dbc.Button("Start", id="start-button", color="success", className="me-2"),
                            dbc.Button("Stop", id="stop-button", color="danger", className="me-2"),
                            dbc.Button("Trigger Analysis", id="analyze-button", color="primary", className="me-2"),
                        ], width=6, className="d-flex justify-content-end align-items-end"),
                    ]),
                ]),
            ], className="mb-4"),
        ], width=12),
    ]),
    
    dbc.Row([
        dbc.Col([
            dbc.Card([
                dbc.CardHeader("Market Dashboard"),
                dbc.CardBody([
                    dbc.Row([
                        dbc.Col([
                            html.H5("Current Position:"),
                            html.H3(id="position-display", children="0 Contracts"),
                        ], width=4),
                        dbc.Col([
                            html.H5("Total P&L:"),
                            html.H3(id="pnl-display", children="$0.00"),
                        ], width=4),
                        dbc.Col([
                            html.H5("Market Direction:"),
                            html.H3(id="direction-display", children="Neutral"),
                        ], width=4),
                    ]),
                    
                    html.Hr(),
                    
                    # Add price chart
                    html.Div([
                        html.H5("Price Chart:"),
                        dcc.Graph(id="price-chart", style={"height": "400px"}),
                    ], className="mb-4"),
                    
                    html.H5("Confidence Level:"),
                    dbc.Progress(id="confidence-bar", value=50, color="info", className="mb-3", style={"height": "30px"}),
                    
                    html.Div([
                        html.H5("LLM Reasoning:"),
                        html.Div(id="reasoning-display", className="p-3 bg-light text-dark rounded")
                    ]),
                ]),
            ], className="mb-4"),
        ], width=12),
    ]),
    
    dbc.Row([
        dbc.Col([
            dbc.Card([
                dbc.CardHeader("Trade History"),
                dbc.CardBody([
                    html.Div(id="trade-history-display", style={"maxHeight": "300px", "overflow": "auto"})
                ]),
            ]),
        ], width=12),
    ]),
    
    # Add interval component for regular updates
    dcc.Interval(
        id='interval-component',
        interval=5*1000,  # in milliseconds (5 seconds)
        n_intervals=0
    )
])

@app.callback(
    [Output("sr-output", "children")],
    [Input("sr-input", "value")]
)
def update_sr_levels(sr_input):
    """Update support and resistance levels"""
    global support_resistance_levels
    
    if not sr_input:
        support_resistance_levels = []
        return [html.P("No levels defined", className="text-muted")]
    
    try:
        # Parse comma-separated values
        levels = [float(level.strip()) for level in sr_input.split(",") if level.strip()]
        support_resistance_levels = sorted(levels)
        
        # Create output display
        level_displays = []
        for i, level in enumerate(support_resistance_levels):
            level_displays.append(html.Span(f"{level:.4f}", className="badge bg-primary me-2"))
        
        return [html.Div(level_displays)]
    
    except ValueError:
        return [html.P("Invalid input. Use comma-separated numbers.", className="text-danger")]

@app.callback(
    Output("price-chart", "figure"),
    [Input("interval-component", "n_intervals")],
    [State("symbol-input", "value"),
     State("timeframe-dropdown", "value")]
)
def update_price_chart(n_intervals, symbol, timeframe):
    """Update price chart with current market data"""
    if not symbol or not timeframe:
        # Return empty chart if no symbol or timeframe
        return go.Figure()
    
    # Define the timeframe mapping
    timeframe_dict = {
        "M1": mt5.TIMEFRAME_M1,
        "M5": mt5.TIMEFRAME_M5,
        "M15": mt5.TIMEFRAME_M15,
        "M30": mt5.TIMEFRAME_M30,
        "H1": mt5.TIMEFRAME_H1,
        "H4": mt5.TIMEFRAME_H4,
        "D1": mt5.TIMEFRAME_D1,
    }
    
    try:
        # Check if mt5 is initialized
        if not mt5.terminal_info():
            # Return placeholder chart if MT5 not initialized
            fig = go.Figure()
            fig.add_annotation(
                text="MetaTrader5 not initialized. Start trading to view chart.",
                xref="paper", yref="paper",
                x=0.5, y=0.5,
                showarrow=False,
                font=dict(size=14)
            )
            return fig
        
        # Get 50 most recent candles for the chart
        rates = mt5.copy_rates_from_pos(symbol, timeframe_dict.get(timeframe, mt5.TIMEFRAME_H4), 0, 50)
        
        if rates is None or len(rates) == 0:
            # Return empty chart if no data
            fig = go.Figure()
            fig.add_annotation(
                text=f"No data available for {symbol} on {timeframe} timeframe",
                xref="paper", yref="paper",
                x=0.5, y=0.5,
                showarrow=False,
                font=dict(size=14)
            )
            return fig
        
        # Convert to dataframe
        df = pd.DataFrame(rates)
        df['time'] = pd.to_datetime(df['time'], unit='s')
        
        # Calculate indicators
        df['atr'] = calculate_atr(df, period=14)
        df['entropy'] = calculate_directional_entropy(df, period=14)
        df['ema9'] = calculate_ema(df['close'], period=9)
        
        # Create subplots
        fig = make_subplots(
            rows=2, cols=1,
            shared_xaxes=True,
            vertical_spacing=0.03,
            row_heights=[0.7, 0.3],
            subplot_titles=("Price", "Indicators")
        )
        
        # Add candlestick chart
        fig.add_trace(
            go.Candlestick(
                x=df['time'],
                open=df['open'],
                high=df['high'],
                low=df['low'],
                close=df['close'],
                name="Price"
            ),
            row=1, col=1
        )
        
        # Add EMA
        fig.add_trace(
            go.Scatter(
                x=df['time'],
                y=df['ema9'],
                name="EMA9",
                line=dict(color='purple', width=1)
            ),
            row=1, col=1
        )
        
        # Add support and resistance lines
        for level in support_resistance_levels:
            fig.add_shape(
                type="line",
                x0=df['time'].iloc[0],
                x1=df['time'].iloc[-1],
                y0=level,
                y1=level,
                line=dict(color="rgba(255, 0, 0, 0.5)", width=2, dash="dash"),
                row=1, col=1
            )
        
        # Add ATR
        fig.add_trace(
            go.Scatter(
                x=df['time'],
                y=df['atr'],
                name="ATR (14)",
                line=dict(color='orange', width=1)
            ),
            row=2, col=1
        )
        
        # Add Directional Entropy
        fig.add_trace(
            go.Scatter(
                x=df['time'],
                y=df['entropy'],
                name="Directional Entropy",
                line=dict(color='blue', width=1)
            ),
            row=2, col=1
        )
        
        # Add volume as bar chart
        fig.add_trace(
            go.Bar(
                x=df['time'],
                y=df['tick_volume'],
                name="Volume",
                marker=dict(
                    color=np.where(df['close'] > df['open'], 'green', 'red'),
                    opacity=0.5
                )
            ),
            row=2, col=1
        )
        
        # Add trade entry points if available
        for trade in trade_history:
            timestamp = datetime.strptime(trade['timestamp'], "%Y-%m-%d %H:%M:%S")
            
            # Find the closest candle to this timestamp
            closest_idx = np.abs(df['time'] - timestamp).argmin()
            
            if closest_idx >= 0 and closest_idx < len(df):
                # Add marker for trade entry
                marker_color = 'green' if trade['action'] == 'ADD_CONTRACTS' else 'red'
                
                fig.add_trace(
                    go.Scatter(
                        x=[df['time'].iloc[closest_idx]],
                        y=[df['high'].iloc[closest_idx] * 1.002 if trade['action'] == 'ADD_CONTRACTS' else df['low'].iloc[closest_idx] * 0.998],
                        mode='markers',
                        marker=dict(
                            symbol='triangle-down' if trade['action'] == 'REMOVE_CONTRACTS' else 'triangle-up',
                            size=12,
                            color=marker_color,
                            line=dict(width=2, color='black')
                        ),
                        name=f"{trade['action']} ({trade['contracts']})"
                    ),
                    row=1, col=1
                )
        
        # Update layout
        fig.update_layout(
            title=f"{symbol} - {timeframe}",
            xaxis_title="Time",
            height=600,
            margin=dict(l=50, r=50, t=80, b=50),
            template="plotly_dark",
            xaxis_rangeslider_visible=False,
            legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="center", x=0.5)
        )
        
        # Set y-axis titles
        fig.update_yaxes(title_text="Price", row=1, col=1)
        fig.update_yaxes(title_text="Indicators/Volume", row=2, col=1)
        
        return fig
    
    except Exception as e:
        print(f"Error updating chart: {e}")
        
        # Return error message in chart
        fig = go.Figure()
        fig.add_annotation(
            text=f"Error updating chart: {str(e)}",
            xref="paper", yref="paper",
            x=0.5, y=0.5,
            showarrow=False,
            font=dict(size=14, color="red")
        )
        return fig

@app.callback(
    [Output("max-contracts-input", "disabled")],
    [Input("start-button", "n_clicks")],
    [State("max-contracts-input", "value")]
)
def update_max_contracts(n_clicks, max_contracts_value):
    """Update max contracts setting"""
    global max_contracts
    
    if n_clicks is not None and n_clicks > 0:
        max_contracts = max(1, min(100, max_contracts_value))
        return [True]  # Disable input after starting
    
    return [False]

@app.callback(
    [Output("start-button", "disabled"),
     Output("stop-button", "disabled"),
     Output("analyze-button", "disabled")],
    [Input("start-button", "n_clicks"),
     Input("stop-button", "n_clicks")],
    [State("symbol-input", "value"),
     State("timeframe-dropdown", "value"),
     State("use-context-checkbox", "value")]
)
def control_trading(start_clicks, stop_clicks, symbol, timeframe, use_context):
    """Control trading process"""
    global running, llm_chain, trade_queue
    
    # Get the button that triggered the callback
    ctx = callback_context
    triggered_id = ctx.triggered[0]['prop_id'].split('.')[0] if ctx.triggered else None
    
    if triggered_id == "start-button" and start_clicks is not None and start_clicks > 0:
        # Initialize components
        if not initialize_mt5():
            return [False, True, False]
        
        # Initialize LLM chain
        if llm_chain is None:
            initialize_llm_chain()
        
        # Start trading loop
        running = True
        trading_thread = threading.Thread(target=trading_loop, args=(symbol, timeframe))
        trading_thread.daemon = True
        trading_thread.start()
        
        # If enabled, get initial context
        if use_context:
            try:
                context = get_initial_context(symbol, timeframe)
                print("Initial context obtained")
            except Exception as e:
                print(f"Error getting initial context: {e}")
        
        return [True, False, False]
    
    elif triggered_id == "stop-button" and stop_clicks is not None and stop_clicks > 0:
        # Stop trading loop
        running = False
        
        # Shutdown MT5
        mt5.shutdown()
        
        return [False, True, True]
    
    # Default state
    return [False, True, True]

@app.callback(
    Output("analyze-button", "n_clicks"),
    [Input("analyze-button", "n_clicks")],
    [State("symbol-input", "value"),
     State("timeframe-dropdown", "value")]
)
def trigger_analysis(n_clicks, symbol, timeframe):
    """Trigger manual market analysis"""
    if n_clicks is not None and n_clicks > 0:
        # Add to the queue
        trade_queue.put("ANALYZE")
    
    return 0  # Reset clicks

if __name__ == "__main__":
    app.run(debug=True, port=8050)