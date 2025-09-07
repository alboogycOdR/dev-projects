To enhance the market data sent to the AI endpoint for your MQ5 Expert Advisor (EA), we’ll focus on adding non-indicator-based data that reflects price action, liquidity, order flow, and market microstructure. Your EA operates in two modes—intraday swing trades and intraday scalping trades—each with distinct needs due to their differing time horizons and trading objectives. The current market data snapshot is already robust, but we can elevate it to a world-class level by incorporating additional raw or minimally processed data points that provide deeper insights into market dynamics. Below, I’ll outline recommended additions tailored to each mode, ensuring they align with the non-indicator-based requirement and are feasible within MQ5’s capabilities.
Understanding Non-Indicator-Based Data
Non-indicator-based data refers to raw or minimally derived market information that avoids mathematical transformations or statistical analyses typical of indicators like MACD, RSI, or moving averages. Instead, we’ll focus on data directly reflecting price behavior, trading activity, and market structure, such as order book details, volume metrics, and price level relationships.
Additional Market Data Recommendations
The following data points are designed to complement your existing snapshot, enhancing the AI’s ability to make informed trading decisions. I’ve split them into categories relevant to both modes, with mode-specific emphasis where applicable.
1. Price Action and Key Levels
Distance to Nearest Support and Resistance
Description: The pip distance from the current price (rates[0].close) to the nearest support and resistance levels already identified in your support_resistance object.
Why: Provides context on how close the price is to significant levels where reversals or breakouts might occur.
For Swing Trades: Helps identify potential trend exhaustion or continuation zones.
For Scalping: Signals immediate price reaction points for quick entries/exits.
Implementation: Subtract the current price from the nearest support and resistance values.
Pivot Points
Description: Daily pivot points (e.g., Pivot, R1, S1) calculated from the previous day’s high, low, and close prices.
Why: Widely watched levels that act as dynamic support/resistance, reflecting market psychology.
For Swing Trades: Useful for targeting larger moves or identifying reversal zones.
For Scalping: Hourly pivots could be considered, but daily pivots still provide short-term context.
Implementation: Use iHigh, iLow, and iClose from the previous D1 bar to compute:  
Pivot = (High + Low + Close) / 3  
R1 = (2 × Pivot) - Low  
S1 = (2 × Pivot) - High
2. Liquidity and Volume Metrics
Bid-Ask Spread
Description: The current difference between the ask and bid prices (SymbolInfoDouble(Symbol(), SYMBOL_ASK) - SymbolInfoDouble(Symbol(), SYMBOL_BID)).
Why: Indicates liquidity and potential execution costs; wider spreads suggest lower liquidity.
For Swing Trades: Helps assess trade feasibility during volatile periods.
For Scalping: Critical for ensuring tight spreads, as slippage can erode small profits.
Implementation: Retrieve real-time via SymbolInfoDouble.
Tick Volume
Description: The number of price changes (ticks) in the most recent M5 bar, accessible via CopyTicks.
Why: Reflects trading activity intensity; higher tick volume may signal momentum or reversals.
For Swing Trades: Complements the volume profile for trend confirmation.
For Scalping: Indicates immediate market engagement for rapid trades.
Implementation: Use CopyTicks to count ticks in the last M5 period (limit to 100-200 ticks for efficiency).
Volatility Measure (Bar Range Deviation)
Description: The standard deviation of the high-low ranges of the last 10 M5 bars.
Why: Captures raw volatility clustering without relying on ATR, showing if the market is in a high- or low-volatility regime.
For Swing Trades: Signals potential trend starts or ends.
For Scalping: Highlights periods of opportunity or risk.
Implementation: Calculate the range (High - Low) for each of the last 10 bars, then compute the standard deviation.
3. Order Flow and Microstructure (Where Feasible)
Order Book Imbalance (If Available)
Description: The difference between buy and sell order volumes at the best bid and ask levels.
Why: Shows immediate buying/selling pressure; a strong imbalance may predict short-term price moves.
For Swing Trades: Less critical but useful for confirmation.
For Scalping: Highly valuable for anticipating micro-movements.
Implementation: Requires broker-provided Depth of Market (DOM) data via MarketBookAdd. If unavailable, omit this metric.
Short-Term Price Momentum
Description: The price change over the last 5 ticks, calculated as current_tick_price - tick_price_5_ago.
Why: Reflects micro-level momentum for rapid decision-making.
For Swing Trades: Less relevant due to longer horizons.
For Scalping: Critical for timing entries/exits in fast markets.
Implementation: Use CopyTicks to retrieve the last 5 ticks and compute the difference.
Consecutive Up/Down Ticks
Description: The number of consecutive tick price increases or decreases in the last M5 bar.
Why: Indicates short-term directional pressure or exhaustion.
For Swing Trades: Limited use but could confirm momentum.
For Scalping: Signals potential breakouts or reversals.
Implementation: Analyze tick data from CopyTicks to count consecutive up or down moves.
4. Market Context and Sentiment
Trading Session
Description: The current trading session (e.g., Asian, London, New York) based on the M5 bar’s timestamp.
Why: Session overlaps or quiet periods affect liquidity and volatility.
For Swing Trades: Helps adjust strategies around high-impact sessions or economic events.
For Scalping: Identifies periods of high/low liquidity for execution.
Implementation: Map the current UTC time (adjusted for broker offset) to session hours (e.g., London: 08:00-16:00 UTC).
Sentiment (Bar Direction)
Description: The percentage of the last 20 M5 bars that closed higher than their open ((Close - Open) > 0).
Why: Provides a simple measure of recent bullish or bearish bias.
For Swing Trades: Indicates prevailing sentiment for trend trades.
For Scalping: Less critical but adds context.
Implementation: Analyze recent_prices array, counting positive closes and dividing by 20.
Currency Strength
Description: A raw strength score for each currency in the pair, based on the average percentage change against a basket (e.g., EUR, USD, JPY) over the last 20 M5 bars.
Why: Shows which currency is driving the pair’s movement.
For Swing Trades: Valuable for trend confirmation and pair selection.
For Scalping: Less relevant due to short horizons.
Implementation: Compute percentage changes for related pairs (e.g., EURUSD, USDJPY) and average them.
Tailored Recommendations by Mode
Here’s how the data aligns with each EA mode:
For Intraday Swing Trades
Pivot Points: Daily levels for targeting swings.
Currency Strength: Identifies strong/weak currencies for trend trades.
Trading Session: Adjusts for session-driven volatility.
Sentiment (Bar Direction): Confirms trend bias.
Distance to Support/Resistance: Gauges proximity to reversal zones.
Volatility Measure: Detects regime shifts for trend entries.
For Intraday Scalping Trades
Bid-Ask Spread: Ensures low-cost execution.
Tick Volume: Measures immediate activity.
Short-Term Momentum: Times rapid entries/exits.
Consecutive Up/Down Ticks: Spots micro-trends or reversals.
Distance to Support/Resistance: Signals quick reaction points.
Order Book Imbalance (if available): Predicts micro-moves.
Universal Data (Both Modes)
Volatility Measure: Adapts to changing market conditions.
Practical Considerations in MQ5
Data Availability: Order book data depends on broker support (MarketBookAdd). If unavailable, focus on tick and price data.
Performance: Limit tick retrieval (e.g., 100 ticks) and pre-compute values like pivot points to avoid delays on new M5 bars.
Broker Volume: Forex volume is often tick volume, not true traded volume, but it still reflects activity.
Updated JSON Payload Example
Here’s how the additional data might integrate into your JSON snapshot:
json
{
  "symbol": "XAUUSD",
  "timeframe": "PERIOD_M5",
  "current_price": 2475.32,
  "technical_indicators": { /* existing data */ },
  "candle_patterns": [ /* existing data */ ],
  "support_resistance": { /* existing data */ },
  "positions": { /* existing data */ },
  "recent_prices": [ /* existing data */ ],
  "additional_data": {
    "distance_to_support": 10.5,
    "distance_to_resistance": 15.2,
    "bid_ask_spread": 0.3,
    "volatility": 5.7,
    "pivot_points": {
      "pivot": 2470.0,
      "R1": 2500.0,
      "S1": 2450.0
    },
    "currency_strength": {
      "XAU": 0.75,
      "USD": 0.65
    },
    "trading_session": "London",
    "sentiment": 0.6,
    "tick_volume": 120,
    "short_term_momentum": 0.2,
    "consecutive_up_ticks": 3
  }
}
Conclusion
By adding these non-indicator-based data points—distance to key levels, pivot points, bid-ask spread, tick volume, volatility, currency strength, trading session, sentiment, momentum, and consecutive ticks (plus order book imbalance if available)—your EA will provide the AI with a richer, more nuanced market snapshot. This enhances its ability to detect price action, liquidity shifts, and microstructure patterns, making it world-class for both intraday swing and scalping strategies. Tailor the data to the active mode if payload size is a concern, but including all relevant metrics ensures flexibility for the AI to optimize decisions.