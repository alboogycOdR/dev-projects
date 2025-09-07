"""
Utility functions for MetaTrader5 LLM Trading Bot
-------------------------------------------------
This module contains utility functions for data processing,
error handling, and other common operations.
"""

import json
import re
import pandas as pd
import numpy as np
from datetime import datetime, timedelta

def parse_llm_response(response_text):
    """
    Parse the LLM response text to extract JSON content

    Args:
        response_text (str): Raw response text from LLM

    Returns:
        dict: Parsed JSON content or default structure if parsing fails
    """
    # Default structure in case parsing fails
    default_response = {
        "market_summary": "Unable to analyze market",
        "confidence_level": 0,
        "direction": "Neutral",
        "action": "WAIT",
        "reasoning": "Failed to parse LLM response",
        "contracts_to_adjust": 0
    }
    
    try:
        # Use regex to find JSON content between ```json and ``` markers
        json_pattern = r'```json\s*([\s\S]*?)\s*```'
        match = re.search(json_pattern, response_text)
        
        if match:
            json_str = match.group(1)
            return json.loads(json_str)
        
        # If no match with the pattern, try to find JSON content directly
        # Look for opening curly brace
        start_idx = response_text.find('{')
        if start_idx >= 0:
            # Count braces to find the matching closing brace
            brace_count = 0
            for i in range(start_idx, len(response_text)):
                if response_text[i] == '{':
                    brace_count += 1
                elif response_text[i] == '}':
                    brace_count -= 1
                    if brace_count == 0:
                        # Found complete JSON object
                        json_str = response_text[start_idx:i+1]
                        return json.loads(json_str)
        
        # If still no valid JSON found, return default
        return default_response
    
    except (json.JSONDecodeError, ValueError, AttributeError) as e:
        print(f"Error parsing LLM response: {e}")
        return default_response

def format_trade_for_feedback(trade, current_price, market_data):
    """
    Format trade information for feedback analysis
    
    Args:
        trade (dict): Trade information
        current_price (float): Current price of the asset
        market_data (str): JSON string of current market data
        
    Returns:
        dict: Formatted trade information for feedback prompt
    """
    return {
        "symbol": trade.get("symbol", "unknown"),
        "action": trade.get("action", "WAIT"),
        "contracts": trade.get("contracts", 0),
        "entry_price": trade.get("price", 0.0),
        "current_price": current_price,
        "pnl": (current_price - trade.get("price", 0.0)) * trade.get("contracts", 0) if trade.get("action") == "ADD_CONTRACTS" else (trade.get("price", 0.0) - current_price) * trade.get("contracts", 0),
        "market_conditions": market_data
    }

def calculate_position_performance(trades, current_price):
    """
    Calculate performance metrics for the current position
    
    Args:
        trades (list): List of trade dictionaries
        current_price (float): Current price of the asset
        
    Returns:
        dict: Performance metrics
    """
    if not trades:
        return {
            "unrealized_pnl": 0.0,
            "realized_pnl": 0.0,
            "total_pnl": 0.0,
            "average_entry": 0.0,
            "position_size": 0,
            "return_pct": 0.0
        }
    
    # Calculate metrics
    position_size = sum(trade["contracts"] if trade["action"] == "ADD_CONTRACTS" else -trade["contracts"] for trade in trades)
    
    if position_size == 0:
        average_entry = 0.0
    else:
        # Calculate weighted average entry price
        weighted_sum = sum(trade["price"] * trade["contracts"] for trade in trades if trade["action"] == "ADD_CONTRACTS")
        total_bought = sum(trade["contracts"] for trade in trades if trade["action"] == "ADD_CONTRACTS")
        
        average_entry = weighted_sum / total_bought if total_bought > 0 else 0.0
    
    # Calculate P&L
    realized_pnl = sum(trade.get("pnl_change", 0.0) for trade in trades)
    
    if position_size > 0:
        unrealized_pnl = (current_price - average_entry) * position_size
    else:
        unrealized_pnl = 0.0
    
    total_pnl = realized_pnl + unrealized_pnl
    
    # Calculate return percentage
    invested_amount = average_entry * abs(position_size) if position_size != 0 else 1.0  # Avoid division by zero
    return_pct = (total_pnl / invested_amount) * 100 if invested_amount > 0 else 0.0
    
    return {
        "unrealized_pnl": unrealized_pnl,
        "realized_pnl": realized_pnl,
        "total_pnl": total_pnl,
        "average_entry": average_entry,
        "position_size": position_size,
        "return_pct": return_pct
    }

def detect_price_patterns(ohlc_df, lookback=5):
    """
    Detect common price patterns in OHLC data
    
    Args:
        ohlc_df (pd.DataFrame): DataFrame with OHLC data
        lookback (int): Number of candles to look back
        
    Returns:
        list: Detected patterns
    """
    patterns = []
    
    # Make sure we have enough data
    if len(ohlc_df) < lookback:
        return patterns
    
    # Get recent candles
    recent = ohlc_df.iloc[-lookback:].copy()
    
    # Calculate candle body sizes and shadows
    recent['body_size'] = abs(recent['close'] - recent['open'])
    recent['upper_shadow'] = recent['high'] - recent[['open', 'close']].max(axis=1)
    recent['lower_shadow'] = recent[['open', 'close']].min(axis=1) - recent['low']
    recent['candle_size'] = recent['high'] - recent['low']
    recent['is_bullish'] = recent['close'] > recent['open']
    
    # Check for doji (small body, shadows on both sides)
    last_candle = recent.iloc[-1]
    if last_candle['body_size'] < 0.2 * last_candle['candle_size']:
        patterns.append("Doji")
    
    # Check for hammer (small body, long lower shadow, small upper shadow)
    if (last_candle['lower_shadow'] > 2 * last_candle['body_size'] and 
        last_candle['upper_shadow'] < 0.5 * last_candle['body_size']):
        if last_candle['is_bullish']:
            patterns.append("Hammer (Bullish)")
        else:
            patterns.append("Inverted Hammer (Bearish)")
    
    # Check for shooting star (small body, long upper shadow, small lower shadow)
    if (last_candle['upper_shadow'] > 2 * last_candle['body_size'] and 
        last_candle['lower_shadow'] < 0.5 * last_candle['body_size']):
        if last_candle['is_bullish']:
            patterns.append("Shooting Star (Bearish)")
        else:
            patterns.append("Inverted Hammer (Bullish)")
    
    # Check for engulfing patterns
    if len(recent) >= 2:
        prev_candle = recent.iloc[-2]
        if (last_candle['is_bullish'] and not prev_candle['is_bullish'] and
            last_candle['open'] <= prev_candle['close'] and
            last_candle['close'] >= prev_candle['open']):
            patterns.append("Bullish Engulfing")
        
        if (not last_candle['is_bullish'] and prev_candle['is_bullish'] and
            last_candle['open'] >= prev_candle['close'] and
            last_candle['close'] <= prev_candle['open']):
            patterns.append("Bearish Engulfing")
    
    # Check for three white soldiers (three consecutive bullish candles)
    if len(recent) >= 3:
        if (all(recent['is_bullish'].iloc[-3:]) and
            recent['close'].iloc[-1] > recent['close'].iloc[-2] > recent['close'].iloc[-3]):
            patterns.append("Three White Soldiers (Bullish)")
    
    # Check for three black crows (three consecutive bearish candles)
    if len(recent) >= 3:
        if (all(~recent['is_bullish'].iloc[-3:]) and
            recent['close'].iloc[-1] < recent['close'].iloc[-2] < recent['close'].iloc[-3]):
            patterns.append("Three Black Crows (Bearish)")
    
    return patterns

def format_timeframe_for_display(timeframe_code):
    """
    Convert MetaTrader5 timeframe code to readable string
    
    Args:
        timeframe_code: MetaTrader5 timeframe code
        
    Returns:
        str: Formatted timeframe string
    """
    timeframe_map = {
        "M1": "1 Minute",
        "M5": "5 Minutes",
        "M15": "15 Minutes",
        "M30": "30 Minutes",
        "H1": "1 Hour",
        "H4": "4 Hours",
        "D1": "Daily"
    }
    
    return timeframe_map.get(timeframe_code, timeframe_code)