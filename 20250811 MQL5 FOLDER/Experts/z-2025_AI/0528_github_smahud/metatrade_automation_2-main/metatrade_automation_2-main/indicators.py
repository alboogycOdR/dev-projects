"""
Technical Indicators Module for MetaTrader5 LLM Trading Bot
-----------------------------------------------------------
This module contains functions for calculating technical indicators
used in market analysis.
"""

import numpy as np
import pandas as pd
from scipy.stats import entropy

def calculate_ema(series, period=9):
    """
    Calculate Exponential Moving Average (EMA)
    
    Args:
        series (pd.Series): Price series
        period (int): EMA period
        
    Returns:
        pd.Series: EMA values
    """
    return series.ewm(span=period, adjust=False).mean()

def calculate_atr(df, period=14):
    """
    Calculate Average True Range (ATR)
    
    Args:
        df (pd.DataFrame): OHLC dataframe with 'high', 'low', 'close' columns
        period (int): ATR period
        
    Returns:
        pd.Series: ATR values
    """
    high = df['high']
    low = df['low']
    close = df['close'].shift(1)
    
    # Handle first row where previous close is NaN
    close.iloc[0] = df['open'].iloc[0]
    
    # Calculate true range
    tr1 = high - low
    tr2 = abs(high - close)
    tr3 = abs(low - close)
    
    tr = pd.concat([tr1, tr2, tr3], axis=1).max(axis=1)
    
    # Calculate ATR
    atr = tr.rolling(window=period).mean()
    
    return atr

def calculate_directional_entropy(df, period=14, bins=10):
    """
    Calculate Directional Entropy
    
    Directional entropy measures the randomness or predictability of price movements.
    Higher entropy values indicate more random price movements, while lower values
    suggest more predictable movements.
    
    Args:
        df (pd.DataFrame): OHLC dataframe
        period (int): Period for entropy calculation
        bins (int): Number of bins for histogram
        
    Returns:
        pd.Series: Directional entropy values
    """
    # Calculate price changes
    price_changes = df['close'].diff().fillna(0)
    
    # Initialize entropy series
    entropy_series = pd.Series(index=df.index, dtype=float)
    
    # Calculate rolling entropy
    for i in range(period, len(df)):
        window = price_changes.iloc[i-period:i]
        
        # Create histogram of price changes
        hist, _ = np.histogram(window, bins=bins)
        hist = hist / np.sum(hist)  # Normalize
        
        # Calculate entropy (remove zeros to avoid log(0))
        hist_nonzero = hist[hist > 0]
        ent = entropy(hist_nonzero)
        
        entropy_series.iloc[i] = ent
    
    return entropy_series

def calculate_volume_profile(df, price_levels=10):
    """
    Calculate Volume Profile
    
    Volume profile shows the distribution of volume across price levels.
    
    Args:
        df (pd.DataFrame): OHLC dataframe with 'close' and 'tick_volume' columns
        price_levels (int): Number of price levels
        
    Returns:
        dict: Volume profile as a dictionary of price levels and volumes
    """
    min_price = df['low'].min()
    max_price = df['high'].max()
    
    # Create price bins
    price_bins = np.linspace(min_price, max_price, price_levels+1)
    
    # Initialize volume profile
    volume_profile = {f"{price_bins[i]:.5f}-{price_bins[i+1]:.5f}": 0 for i in range(price_levels)}
    
    # Distribute volume across price bins
    for i in range(len(df)):
        # Approximate volume distribution across the price range of the candle
        candle_low = df['low'].iloc[i]
        candle_high = df['high'].iloc[i]
        candle_volume = df['tick_volume'].iloc[i]
        
        # Find which bins this candle spans
        for j in range(price_levels):
            bin_low = price_bins[j]
            bin_high = price_bins[j+1]
            
            # Check for overlap between candle and bin
            overlap_low = max(candle_low, bin_low)
            overlap_high = min(candle_high, bin_high)
            
            if overlap_high > overlap_low:
                # Calculate proportion of candle in this bin
                candle_range = candle_high - candle_low
                if candle_range > 0:
                    overlap_ratio = (overlap_high - overlap_low) / candle_range
                    volume_profile[f"{bin_low:.5f}-{bin_high:.5f}"] += candle_volume * overlap_ratio
    
    return volume_profile

def detect_support_resistance(df, window=20, threshold=0.01):
    """
    Detect Support and Resistance levels
    
    Args:
        df (pd.DataFrame): OHLC dataframe
        window (int): Lookback window
        threshold (float): Price threshold as a percentage
        
    Returns:
        tuple: Lists of support and resistance levels
    """
    supports = []
    resistances = []
    
    # Identify local minima and maxima
    for i in range(window, len(df) - window):
        # Current price
        current_low = df['low'].iloc[i]
        current_high = df['high'].iloc[i]
        
        # Check if this is a local minimum (support)
        is_support = True
        for j in range(i - window, i + window + 1):
            if j != i and df['low'].iloc[j] < current_low:
                is_support = False
                break
                
        # Check if this is a local maximum (resistance)
        is_resistance = True
        for j in range(i - window, i + window + 1):
            if j != i and df['high'].iloc[j] > current_high:
                is_resistance = False
                break
        
        # Add to support/resistance lists if criteria are met
        if is_support:
            # Check if this level is already in our list
            if not any(abs(current_low - s) / s < threshold for s in supports):
                supports.append(current_low)
                
        if is_resistance:
            # Check if this level is already in our list
            if not any(abs(current_high - r) / r < threshold for r in resistances):
                resistances.append(current_high)
    
    return sorted(supports), sorted(resistances)