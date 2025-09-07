World-Class Market Data Enhancements for MT5 Expert Advisor
Let me suggest non-indicator based market data that would significantly enhance your trading system for both intraday swing and scalping strategies.

Pure Price Action & Market Structure

Price Swing Analysis

Swing high/low points (last 5-10)
Swing magnitude and duration measurements
Higher highs/higher lows vs. lower highs/lower lows sequence
Break of structure events (when price breaks previous swing high/low)


Range Analysis

Current bar's range vs. average range for this time of day
Contraction/expansion sequences of bar ranges
Range bound periods identification (consecutive bars with decreasing ranges)
Bar momentum (close position within the range)


Key Price Levels

Session open/high/low/close (current and previous)
Weekly/monthly pivots (pure price calculation)
Round numbers and psychological levels
Previous day's value area



Order Flow & Market Microstructure

Volume Analysis

Delta volume (buying vs. selling pressure)
Volume profile (distribution across price levels)
Volume POC (point of control - price with highest volume)
Relative volume (current vs. average for this time)
Cumulative volume delta


Market Depth Analysis (if available)

Order book imbalance ratios
Large limit orders (resting liquidity)
Size of bids vs. asks
Order flow absorption (large orders being filled without price movement)


Liquidity Analysis

Stop clusters (likely positions of stop orders)
Liquidity voids (areas with minimal trading activity)
Liquidity sweeps (when price quickly moves through a level)
Failed auctions (price rejects from a level with high volume)



Time-Based Context

Session Analysis

Current trading session (Asian, European, American)
Time to session open/close
Historical volatility patterns for current time of day
Day of week performance patterns


Multi-timeframe Context

Higher timeframe supply/demand zones (D1, H4)
Trading range percentage (where in the daily range price is currently)
Alignment of current price to higher timeframe structure



Market Internals & Correlations

Market Regime Analysis

Correlation with market indices (S&P 500, VIX)
Correlation with related pairs/instruments
Risk on/off sentiment indicators
Sector performance (for stocks)


Market Internals

Tick data analysis (if available)
Market breadth information (for indices)
Institutional money flow indicators
COT data for futures (weekly granularity)



Examples for Implementation
For Intraday Swing Trading
json{
  "price_structure": {
    "swing_points": [
      {"type": "high", "price": 1.12450, "time": "2025-04-09 10:30", "broken": false},
      {"type": "low", "price": 1.12150, "time": "2025-04-09 11:45", "broken": true}
    ],
    "structure_state": "uptrend",  // "uptrend", "downtrend", "range", "transition"
    "recent_breaks": [
      {"level": 1.12320, "type": "resistance_broken", "time": "2025-04-09 13:15"}
    ]
  },
  
  "session_context": {
    "current_session": "European",
    "minutes_until_session_close": 120,
    "minutes_until_next_session": 180,
    "day_range_completion": 0.65,  // 0-1 scale of where we are in the day's range
    "key_times": [
      {"event": "US NFP", "minutes_until": 75, "expected_impact": "high"}
    ]
  },
  
  "key_levels": {
    "daily_levels": {
      "open": 1.12200,
      "high": 1.12550,
      "low": 1.12050,
      "prev_close": 1.12180
    },
    "weekly_levels": {
      "open": 1.11980,
      "high": 1.12550,
      "low": 1.11870
    },
    "psychological_levels": [1.12000, 1.12500],
    "distance_to_nearest_level": {"price": 1.12500, "pips": 23}
  },
  
  "volume_analysis": {
    "current_relative_volume": 1.45,  // compared to avg for this time
    "volume_trend": "increasing",
    "buy_volume_ratio": 1.32,  // >1 means buying pressure dominates
    "volume_distribution": [
      {"price_level": 1.12400, "volume": 342, "delta": 87},
      {"price_level": 1.12350, "volume": 215, "delta": -34}
      // Additional levels
    ],
    "poc": 1.12400  // Point of control
  }
}
For Scalping
json{
  "market_microstructure": {
    "order_book": {
      "bid_ask_imbalance": 2.3,  // ratio of bid to ask volume
      "bid_size_changes": +150,  // recent change in bid size
      "ask_size_changes": -87,   // recent change in ask size
      "large_orders": [
        {"side": "bid", "price": 1.12370, "size": 250}
      ]
    },
    "tape_speed": 1.78,  // transactions per second vs average
    "iceberg_detection": [
      {"price": 1.12400, "detected_size": 850, "confidence": "high"}
    ]
  },
  
  "price_action_micro": {
    "momentum_shifts": [
      {"time": "2025-04-09 14:05:23", "direction": "bullish", "strength": "strong"}
    ],
    "imbalance_zones": [
      {"from": 1.12380, "to": 1.12420, "type": "unfilled_bullish"}
    ],
    "last_3_bars": [
      {"range": 12, "close_position": 0.85, "volume": 156},
      {"range": 15, "close_position": 0.78, "volume": 187},
      {"range": 8, "close_position": 0.92, "volume": 201}
    ]
  },
  
  "liquidity_analysis": {
    "stop_clusters": [
      {"price": 1.12350, "size": "large", "type": "sell_stops"}
    ],
    "liquidity_voids": [
      {"from": 1.12425, "to": 1.12445, "strength": "medium"}
    ],
    "recent_sweeps": [
      {"price": 1.12300, "time": "2025-04-09 13:55", "followed_by": "reversal"}
    ],
    "spread_dynamics": {
      "current": 0.7,
      "average": 0.5,
      "expanding": true
    }
  },
  
  "tick_data": {
    "tick_direction": +7,  // net up/down ticks in last X seconds
    "tick_speed": 1.3,     // ticks per second vs average
    "tick_size": 1.2       // average tick size vs normal
  }
}
Implementation Strategies

For MT5 Development:

Use OnBookEvent() handler to access market depth data if available
Use custom tick collectors to analyze order flow between bars
Create efficient caches for higher timeframe data
Implement efficient methods to detect price structure changes


Data Source Considerations:

Some brokers provide better order flow and market depth data than others
Consider using specialized DMA/ECN brokers for better microstructure data
For institutional-grade data, consider using separate data feeds


Performance Optimization:

Calculate heavy data elements only on bar close
Use efficient algorithms for pattern detection
Consider pre-calculating some elements at higher timeframes



Would you like me to expand on any specific aspect of these recommendations or discuss implementation approaches for particular data elements?