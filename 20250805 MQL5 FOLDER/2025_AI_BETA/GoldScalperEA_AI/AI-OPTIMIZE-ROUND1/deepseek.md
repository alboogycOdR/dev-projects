To elevate your EA’s market data to a world-class level for **intraday swing** and **scalping** strategies, here’s a curated list of **non-indicator-based data** focused on price action, liquidity, and market microstructure. These additions will help the AI infer institutional activity, liquidity traps, and short-term order flow dynamics:

---

### **1. Price Action & Market Structure Enhancements**
#### **A. Institutional Footprints**  
- **Volume-Weighted Price Levels**:  
  - `vwap`: Volume-weighted average price over the last 1-4 hours (identifies fair value).  
  - `volume_clusters`: Key price levels with unusually high volume (e.g., `{"1895.00": 1.2M, "1900.50": 850K}`).  
- **Order Blocks**:  
  - `institutional_blocks`: Array of price zones where large bullish/bearish candles closed (e.g., `{"zone": [1890-1895], "direction": "bullish", "time": "2023-10-01T14:00"}`).  

#### **B. Auction Process**  
- **Market Profile**:  
  - `value_area_high`/`value_area_low`: Price range containing 70% of today’s volume (from TPO or volume profiles).  
  - `poor_high`/`poor_low`: Weakest extremes of the session (price levels with minimal trading activity).  
- **Session Overlaps**:  
  - `london_new_york_overlap`: Binary flag (0/1) during 8 AM–12 PM EST (high-liquidity window).  

---

### **2. Liquidity & Order Flow Signals**  
#### **A. Liquidity Heatmap**  
- **Liquidity Pools**:  
  - `liquidity_heatmap`: Aggregated buy/sell limit orders within 1% of current price (e.g., `"bids": 1890.50 (2.1M), asks: 1895.00 (1.8M)`).  
- **Stop Hunts**:  
  - `liquidity_gaps`: Distance to nearest clusters of stops (e.g., `"stops_above": 1905.00, stops_below: 1880.00`).  

#### **B. Real-Time Order Flow**  
- **Delta Imbalance**:  
  - `delta_5min`: Net difference between buy/sell volume over 5 minutes (e.g., `+1.5M` = aggressive buying).  
- **Absorption Signals**:  
  - `absorption_at_level`: Flags when large orders soak up liquidity at S/R (e.g., `"1895.00": {"direction": "bullish", "size": 850K}`).  

---

### **3. Microstructure & Execution Context**  
#### **A. Tick-Level Dynamics**  
- **Tick Speed**:  
  - `ticks_per_second`: Rate of price changes (e.g., `45/sec` = high volatility).  
- **Market Responsiveness**:  
  - `retracement_depth`: Depth (%) of pullbacks after spikes (e.g., "price spiked 0.5%, retraced 30%").  

#### **B. Spread/Slippage Analysis**  
- **Spread Behavior**:  
  - `spread_std_dev`: Standard deviation of spreads over the last hour (identifies erratic liquidity).  
- **Slippage Risk**:  
  - `liquidity_dryup`: Flag (0/1) if bid/ask depth drops below a threshold (e.g., `< 500K contracts`).  

---

### **4. Time & Event-Driven Data**  
#### **A. Session Timing**  
- **Session-Specific Context**:  
  - `session_phase`: "Asian grind", "London open", "New York close" (volatility regimes).  
- **Economic Event Proximity**:  
  - `minutes_since_high_impact_news`: Time elapsed since last major news event (e.g., `120` = 2 hours).  

#### **B. Time-of-Day Patterns**  
- **Seasonality**:  
  - `hourly_seasonality`: Historical win rate for the current hour (e.g., `14:00 GMT: 62% bullish`).  

---

### **5. Multi-Timeframe Context**  
#### **A. Higher-Timeframe (HTF) Anchors**  
- **HTF Key Levels**:  
  - `weekly_high_low`: Weekly high/low price (acts as magnet for price).  
  - `prev_day_high_low`: Previous day’s high/low and close.  
- **HTF Liquidity**:  
  - `monthly_option_expiry_levels`: Key strikes for options expiring this month.  

#### **B. Fractal Scaling**  
- **Multi-Timeframe S/R**:  
  - `htf_resistance`: Nearest H4/D1 resistance level (e.g., `1900.00`).  
  - `htf_support`: Nearest H4/D1 support level (e.g., `1880.00`).  

---

### **Implementation Example (JSON Additions)**  
```json
{
  "volume_analysis": {
    "vwap": 1895.30,
    "volume_clusters": {"1890.50": 2100000, "1900.00": 1800000},
    "value_area_high": 1902.00,
    "value_area_low": 1888.50
  },
  "order_flow": {
    "delta_5min": 1500000,
    "liquidity_heatmap": {
      "bids": {"1890.50": 2100000, "1885.00": 1500000},
      "asks": {"1900.00": 1800000, "1905.00": 900000}
    }
  },
  "microstructure": {
    "ticks_per_second": 45,
    "spread_std_dev": 0.8,
    "liquidity_dryup": 0
  },
  "time_context": {
    "session_phase": "London/New York Overlap",
    "minutes_since_high_impact_news": 120
  },
  "htf_context": {
    "weekly_high": 1910.00,
    "weekly_low": 1875.00,
    "prev_day_close": 1892.50
  }
}
```

---

### **Strategy-Specific Prioritization**  
| **Data Type**               | **Intraday Swing** | **Scalping** |  
|------------------------------|-------------------|-------------|  
| Volume Clusters              | ✅ High          | ✅ Medium   |  
| Delta Imbalance              | ✅ Medium        | ✅ Critical |  
| Liquidity Heatmap            | ✅ Medium        | ✅ Critical |  
| HTF Key Levels               | ✅ Critical      | ✅ Low      |  
| Tick Speed/Spread Behavior   | ✅ Low           | ✅ Critical |  

---

### **Why This Works**  
1. **Swing Trades**: Focus on *institutional blocks*, *HTF key levels*, and *session timing* to align with institutional flow.  
2. **Scalping**: Prioritize *order book depth*, *delta imbalance*, and *tick speed* to exploit micro-inefficiencies.  
3. **Risk Mitigation**: `liquidity_dryup` and `spread_std_dev` help avoid toxic market conditions.  

By integrating these datasets, your AI can detect hidden liquidity, differentiate between false breakouts and genuine momentum, and adapt to regime shifts (e.g., news-driven volatility).