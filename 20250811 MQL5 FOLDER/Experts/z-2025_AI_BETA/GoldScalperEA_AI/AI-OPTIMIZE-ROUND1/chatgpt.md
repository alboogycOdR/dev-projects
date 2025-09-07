You're already passing a solid set of data. To take this to the next level—especially for AI-driven decisions—here are some suggestions that focus on raw market structure and price behavior, not indicators.

---

### For Both Intraday Swing & Scalping (non-indicator-based):

#### 1. **Order Book Imbalance (if accessible)**
- Not natively in MT5, but if your broker supports it:
  - bid_volume, ask_volume
  - bid_ask_ratio: Derived signal

#### 2. **Price Action Behavior**
- **Bar Speed**: Time it takes to form the last bar (esp. useful on scalping).
- **Bar Size / Range**: High - Low of last bar(s).
- **Gap Detection**: Difference between the open of the current bar and close of the previous one.
- **Wick Size & Direction Bias**:
  - Top/Bottom wick ratio
  - Body-to-range ratio
  - Bullish/bearish body with long wick = potential reversal signal

#### 3. **Session Context**
- **time_of_day**: UTC time or converted session info (e.g., London Open)
- **is_session_open**: Flags like `is_london_open`, `is_ny_open`

#### 4. **Volume Profile Elements**
- If available or approximated:
  - **Price with highest volume (POC)** in recent bars
  - **Volume delta** (buy vs sell pressure)

---

### For (a) **Swing Trades**

Focus more on market structure and context:
- **Swing Highs/Lows**: Beyond just fractals. Track actual price swings based on zigzag or wave logic.
- **Consolidation Zones**: Detect areas with tight range over N bars (e.g., low stddev or low ATR clusters).
- **Breakout Watch**: Is current price breaking out of a previous range? Add fields like:
  - `range_breakout`: true/false
  - `break_direction`: up/down
- **Trend Maturity**: Count number of bars since last major EMA crossover or trend change.

---

### For (b) **Scalping**

Speed, volatility, and recent reactions matter:
- **Tick Density**: How many ticks occurred in the last bar? (If you store tick data)
- **Micro Price Reaction**:
  - How price behaved around the last support/resistance zones (e.g., was it rejected sharply?)
- **Spread Tracking**:
  - `current_spread`, `average_spread`, and `spread_spike_flag`
- **Microstructure Flags**:
  - e.g., did price tap into previous high and get rejected within 1 bar?

---

### Extra Context Ideas

- **News Proximity (optional)**: is_high_impact_news_within_30min (via economic calendar API).
- **Price Anchors**:
  - `open_day`, `open_session` (useful for VWAP-like strategies even without using VWAP itself).
- **Market Sentiment Tag** (optional if using external APIs): bullish/bearish/neutral

---

Would you like a suggested updated JSON schema with these included?