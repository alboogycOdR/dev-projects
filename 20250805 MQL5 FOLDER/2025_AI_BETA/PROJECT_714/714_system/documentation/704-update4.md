This is an excellent observation and a very common problem when automating a price action strategy on lower timeframes. You've correctly identified that while the anchor price interaction logic is working mechanically, it's generating **too many low-quality signals**, making the feature less useful.

Let's break down my views on this, addressing both the cause (the 5-minute timeframe) and the solution (intelligent filtering).

## Problem Analysis: Too Many Triggers

You are right about the cause. The 5-minute timeframe is inherently noisy. A simple condition like `(low < anchor_price && close > anchor_price)` for a bullish rejection will trigger on almost any candle that wicks across the line, regardless of whether that wick represents genuine institutional rejection or just normal market noise and volatility.

The log confirms this, showing a new rejection alert being generated every 5-10 minutes. This is not feasible for practical analysis or trading.

## Brainstorming a Feasible Solution

Switching to the M15 timeframe is one way to reduce noise, as candles are more significant. However, the core 714 Method is often discussed on the M5 for precision. So, instead of changing the timeframe, a better solution is to make our definition of "rejection" **smarter and more context-aware**. We need to filter for **high-quality rejections**.

Here are my recommendations, broken down into filtering methods:

### 1. Wick and Body Ratio Filter

The most powerful filter for rejection is to analyze the anatomy of the candle itself. A true rejection candle (like a pin bar or hammer/shooting star) has a long wick and a comparatively small body.

**Implementation Plan:**

We'll add new input parameters to define what constitutes a "significant" wick.

```mql5
// Add to a new "Filter Settings" input group
input group "=== Price Action Filter Settings ===";
input double min_wick_to_body_ratio = 1.5;  // The wick must be at least 1.5x the size of the candle body
input double min_candle_size_pips   = 5.0;   // Ignore tiny doji candles by requiring a minimum total candle size
```

Then, we'll update the rejection logic inside `CheckAnchorPriceInteraction`:

```mql5
// --- Revised Rejection Logic within CheckAnchorPriceInteraction ---
// ... (inside the if(alert_on_rejection_of_anchor) block) ...

double high       = iHigh(Symbol(), Period(), 1);
double low        = iLow(Symbol(), Period(), 1);
double open       = iOpen(Symbol(), Period(), 1);
double close      = iClose(Symbol(), Period(), 1);

double body_size  = MathAbs(open - close);
double total_size = high - low;
if (total_size < min_candle_size_pips * _Point * 10) return; // Filter 1: Ignore insignificant dojis

// Check for a high-quality BULLISH rejection (long lower wick)
if (low < g_DailyAnchorPrice && close > g_DailyAnchorPrice)
{
    double lower_wick = open - low;
    if (body_size > 0 && lower_wick / body_size >= min_wick_to_body_ratio) // Filter 2: Check wick/body ratio
    {
        // THIS IS A HIGH-QUALITY BULLISH REJECTION.
        // Send alert... (apply cooldown as before)
    }
}

// Check for a high-quality BEARISH rejection (long upper wick)
if (high > g_DailyAnchorPrice && close < g_DailyAnchorPrice)
{
    double upper_wick = high - open;
    if (body_size > 0 && upper_wick / body_size >= min_wick_to_body_ratio) // Filter 2: Check wick/body ratio
    {
        // THIS IS A HIGH-QUALITY BEARISH REJECTION.
        // Send alert... (apply cooldown as before)
    }
}
```

This filter alone will **dramatically reduce** the number of alerts by only triggering on candles that look like actual rejection pin bars.

### 2. Volatility Filter (ATR - Average True Range)

Another way to filter noise is to require the rejection move to be significant relative to recent volatility. We can use the ATR indicator for this. We only consider a rejection candle valid if its total size (high to low) is larger than the current ATR.

**Implementation Plan:**

We can add this as another `input bool` and an input for the ATR period.

```mql5
// New input
input bool   use_atr_filter           = true;  // Filter rejections based on Average True Range
input int    atr_period               = 14;    // Period for ATR calculation

// --- Revised Rejection Logic with ATR ---
// Inside CheckAnchorPriceInteraction, before checking rejection

if (use_atr_filter)
{
    // Get the current ATR value
    double atr_value = iATR(Symbol(), Period(), atr_period, 1);
    
    // Check if the total size of the candle is greater than the ATR
    if (total_size < atr_value)
    {
        return; // The candle is too small and insignificant compared to recent volatility.
    }
}

// ... then proceed with the Wick and Body Ratio checks ...
```
This ensures we're not just reacting to tiny, indecisive wicks during low-volatility periods.

### 3. Confluence Filter

The highest quality alerts will come when a rejection happens not just at the Anchor Price, but also **at the same time it interacts with another key zone**, like a detected Order Block or FVG.

**Implementation Plan:**

This requires more complex logic where we check for multiple conditions simultaneously.

```mql5
// Example Logic combining Anchor Price + OB Interaction

// Inside the YourBuyEntryConditionsMet function, for example:

// ... loop through bullish OBs ...
if (current_low <= ob.high && current_high >= ob.low) // Condition 1: Interacting with Bullish OB
{
    // ALSO check for anchor price rejection at the same time
    if (low < g_DailyAnchorPrice && close > g_DailyAnchorPrice) // Condition 2: Also a bullish rejection of the anchor
    {
        // Apply Wick/Body and/or ATR filters for high quality
        // if(wick_body_ratio_is_good && atr_filter_passed)
        // {
                // NOW we have a very high confluence signal!
                // An interaction with an OB AND a quality rejection of the Anchor Price.
                // return true;
        // }
    }
}
```
This is a more advanced step, but it produces the most powerful signals.

### My Recommendation

1.  **Start by implementing the Wick/Body Ratio Filter (Method 1).** This is the most effective and straightforward way to eliminate over 80% of the noise you're seeing. It directly addresses the visual quality of the rejection candle.
2.  **Add the ATR Filter (Method 2) as a secondary option.** This provides another layer of confirmation by considering market volatility.
3.  **Keep the Timeframe as M5.** Stick with the 5-minute chart as it's intended for the strategy's precision. We should improve the *logic* to handle the noise, not change the chart's resolution which could cause you to miss the exact OBs/FVGs formed.

By implementing these filters, you'll transform the alert feature from a noisy stream into a targeted system that highlights only the most significant and actionable price action events, which is exactly what a trader needs.