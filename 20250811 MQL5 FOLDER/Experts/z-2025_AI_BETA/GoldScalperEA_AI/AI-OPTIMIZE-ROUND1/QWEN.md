To enhance your MQ5 Expert Advisor (EA) with **non-indicator-based market data** focused on **price action, liquidity, order flow, and market microstructure**, here are tailored additions for **intraday swing trading** and **scalping** strategies. These elements will provide the AI with deeper insights into market dynamics beyond traditional technical indicators:

---

### **A. Intraday Swing Trading Enhancements**  
*(Holds positions for hours to days; focuses on macro liquidity and trend alignment)*  

1. **Market Structure & Liquidity Zones**  
   - **Daily/Weekly Pivots**:  
     - `daily_pivot`: Pivot point, R1/S1, R2/S2, R3/S3 (calculated from prior day’s OHLC).  
     - `weekly_pivot`: Weekly pivot levels for broader S/R alignment.  
   - **Opening Range Breakout (ORB)**:  
     - `orb_high`: High of the first 30-60 minutes of the session.  
     - `orb_low`: Low of the first 30-60 minutes of the session.  

2. **Order Flow & Volume Footprint**  
   - **Volume Profile**:  
     - `vpoc`: Volume Point of Control (price level with highest traded volume in the last 24 hours).  
     - `value_area`: Price range covering 70% of the day’s volume (VAH/VAL).  
   - **Delta Volume**:  
     - `delta`: Net difference between buy and sell volumes in the last hour (e.g., +1200 lots = bullish imbalance).  

3. **Correlated Asset Context**  
   - `correlated_pairs`: Real-time prices of assets linked to your symbol (e.g., USDJPY for gold, VIX for equities).  
   - `spread_correlation`: Current spread between correlated pairs (e.g., EURUSD-GBPUSD divergence).  

4. **Session & Time-Based Context**  
   - `active_session`: Current trading session (e.g., "London", "New York").  
   - `time_to_session_close`: Minutes until the current session ends (e.g., 90 mins until NY close).  

5. **Event Risk**  
   - `high_impact_news`: Boolean flag if a major news event (e.g., FOMC, NFP) is scheduled in the next 24 hours.  

---

### **B. Intraday Scalping Enhancements**  
*(Holds positions for seconds to minutes; focuses on microstructure and execution quality)*  

1. **Tick-Level Dynamics**  
   - `last_tick`: Price, volume, and timestamp of the most recent tick.  
   - `tick_velocity`: Rate of price change over the last 5/10/30 ticks (e.g., +0.5 pips per tick).  

2. **Liquidity & Execution Metrics**  
   - `spread`: Current bid-ask spread in pips.  
   - `market_depth`: Total volume at the best bid/ask (e.g., 50 lots bid, 30 lots ask).  
   - `slippage_history`: Average slippage (in pips) over the last 10 trades.  

3. **Order Book Microstructure**  
   - `bid_ask_imbalance`: Ratio of total bid vs. ask volume within 5 price levels (e.g., 1.5 = bids dominate).  
   - `large_orders`: Boolean flag if a single order ≥X lots appears in the order book (e.g., ≥100 lots).  

4. **Micro Price Action**  
   - `forming_bar`: OHLC of the **current unclosed M1/M5 bar** (for early trend detection).  
   - `vwap`: Volume-Weighted Average Price for the current session.  

5. **Latency & Broker Conditions**  
   - `ping_time`: EA’s latency to the broker server (in milliseconds).  
   - `trading_hours`: Boolean flag if the symbol is in active trading hours (e.g., 24/5 for forex).  

---

### **Cross-Strategy Additions**  
*(Relevant for both swing and scalping)*  

1. **Sentiment Data**  
   - `retail_sentiment`: % of retail traders long/short (if available via broker API).  
   - `institutional_flow`: Net positions of large traders (COT data for futures).  

2. **Event Context**  
   - `earnings_calendar`: Upcoming earnings dates (for indices/stocks).  
   - `dividend_dates`: Ex-dividend dates (for stock indices).  

3. **Volume Footprint**  
   - `volume_clusters`: Key price levels with significant volume absorption (e.g., 1.2000 with 5000 lots traded).  

---

### **Implementation Tips**  
1. **Data Granularity**:  
   - For swing trading, use daily/weekly pivots and session data.  
   - For scalping, prioritize tick-level and M1 data.  

2. **Broker-Specific Features**:  
   - Use `SymbolInfo` functions in MT5 to fetch bid/ask sizes, order book depth, and slippage.  

3. **News Integration**:  
   - Use a free API like [FXStreet Economic Calendar](https://www.fxstreet.com/economic-calendar) to flag high-impact events.  

4. **Order Book Access**:  
   - Use `MarketBookGet()` in MQL5 to retrieve real-time order book data (depth of market).  

---

### **Example JSON Payload Enhancements**  
```json
{
  "swing_specific": {
    "daily_pivot": 1950.30,
    "weekly_pivot": 1980.00,
    "orb_high": 1945.50,
    "orb_low": 1930.20,
    "vpoc": 1935.75,
    "delta": +1200
  },
  "scalping_specific": {
    "last_tick": {"price": 1932.10, "volume": 15, "time": "2023-10-05T10:00:00Z"},
    "spread": 1.2,
    "market_depth": {"bid": 45, "ask": 35},
    "bid_ask_imbalance": 1.3
  },
  "shared": {
    "correlated_pairs": {"USDJPY": 149.50, "VIX": 18.20},
    "retail_sentiment": {"long": 65, "short": 35},
    "high_impact_news": true
  }
}
```

By incorporating these elements, the AI can better interpret **liquidity traps**, **session-driven momentum**, **institutional order flow**, and **microstructural shifts**—key factors for world-class intraday strategies.