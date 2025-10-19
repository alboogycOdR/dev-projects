The Displacement Opening Range Breakout (D'ORB) is a revised trading model for 2025 that builds upon the traditional Opening Range Breakout (ORB) strategy. This updated approach introduces the concept of "displacement" to improve the win rate and risk-to-reward ratio.

### Defining the Core Concepts

*   **Opening Range (OR):** This is established by the high and low of the first 15-minute candle after the market opens. For futures, this typically corresponds to the New York open (9:30 AM EST). The range is therefore set at 9:45 AM EST. An Opening Range Break is confirmed when a 5-minute candle closes outside of this initial 15-minute range.
*   **Displacement (Fair Value Gaps - FVG):** The key addition to the traditional ORB is the requirement of a Fair Value Gap (FVG), which signals displacement or an imbalance in the order book. An FVG is a three-candlestick pattern where there is a gap between the high of the first candle and the low of the third candle (for a bullish FVG) or between the low of the first candle and the high of the third candle (for a bearish FVG). This indicates a strong, fast-moving market, leaving unfilled orders behind.

### The Trading Models

There are two primary models for entering a trade with the D'ORB strategy:

**Model 1: m5 Re-test (Higher Success Rate, Very Frequent)**

1.  Identify the Opening Range high and low.
2.  Wait for a 5-minute (m5) candle to close outside the range, confirming the breakout.
3.  Look for an m5 Fair Value Gap that forms on the breakout candle or immediately after.
4.  Set a limit order to enter a trade when the price re-tests this FVG.
5.  Place the stop loss at the low (for a long trade) or high (for a short trade) of the 5-minute candle that created the gap.
6.  The target is a fixed 1:2 risk-to-reward ratio.

**Model 2: m1 Re-test (Less Frequent, Higher Success Rate)**

This model is used when the 5-minute breakout does not leave a clear FVG.

1.  After the m5 breakout candle closes, drop down to the 1-minute (m1) timeframe.
2.  Identify a clear m1 FVG that formed during the breakout.
3.  Set a limit order to enter on a re-test of the m1 FVG.
4.  The stop loss must still be placed on the low or high of the *5-minute* breakout candle.
5.  A minimum stop loss of 15 points is required. If the stop is smaller, it should be moved to the next candle's high/low or to the 50% level of the opening range.

### Trading Plan and Risk Management

*   **Max Trades Per Day:** 2
*   **Daily Stop Rules:** Stop trading for the day after 2 wins, 2 losses, or 1 win and 1 loss.
*   **Trading Schedule:** Monday to Friday during a major session (e.g., New York).
*   **Partials/Breakeven (Optional):**
    *   **Take Profit 1 (TP1):** Sell 80% of the position at a 1:2 risk-to-reward ratio.
    *   **Take Profit 2 (TP2):** Sell the remaining 20% at a 1:5 risk-to-reward ratio.
    *   **Break Even:** Move stop loss to break even if a time-based liquidity level is hit before 1:2 RR or if high-impact news is imminent.

### EMA Bias (Exponential Moving Average)

To further increase the probability of a trade, an EMA bias can be used to confirm the trend direction.

*   **Setup:** Use a 200-period EMA on the 15-minute (m15) chart.
*   **Bullish Bias:** If the price is trending above the m15 200 EMA, focus on taking long (buy) trades.
*   **Bearish Bias:** If the price is trending below the m15 200 EMA, focus on taking short (sell) trades.
*   **Ranging Market:** If the price is chopping back and forth across the EMA, it's considered a ranging market, and the EMA bias should not be used. Trading with the bias has been shown to improve the win rate.