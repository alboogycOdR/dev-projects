# Pine Script Indicator Enhancement Design: CRT Ranges and 3-Candle Models

## 1. Introduction

This document outlines the design and implementation strategy for enhancing the provided Pine Script indicator to accurately identify and visualize Candle Range Theory (CRT) ranges for both 4-hour and 1-hour timeframes, as well as to detect specific "3-candle models." The goal is to align the indicator more closely with institutional CRT methodologies, providing clear visual cues and potential signal generation based on these patterns.

## 2. Current Indicator Analysis and Identified Gaps

The existing `Institutional CRT Engine v3.4` Pine Script indicator already attempts to identify CRT ranges and entry logic. However, a detailed analysis reveals several areas that require refinement to meet the specified requirements:

*   **CRT Range Calculation:** The current implementation uses `request.security` to fetch higher timeframe data and attempts to set the `crt_high` and `crt_low` based on the previous bar's `htf_high` and `htf_low` when a new HTF candle starts and the completed candle was the target hour. While this is a good starting point, ensuring precise alignment with specific New York session hours (1 AM, 5 AM, 9 AM for 1H; 00:00, 04:00, 08:00 for 4H) requires careful handling of timezones and server time vs. exchange time. The current `hour(htf_time[1], 


America/New_York")` might not be robust enough for all brokers or time zone settings, and a more explicit handling of time conversion might be necessary to ensure the correct candle is always selected for the CRT range. Additionally, the current visualization of the CRT range uses a `box` object, which is good, but we need to ensure it accurately extends and represents the range for the entire trading day or until a new range is set.

*   **3-Candle Models:** The current indicator does not explicitly include logic for detecting "3-candle models." This is a significant gap that needs to be addressed. These models typically involve specific price action patterns over three consecutive candles that signal potential reversals or continuations. We will need to define the exact criteria for these models based on the user's understanding of CRT and then implement functions to identify them.

*   **Visualization and Alerts:** While the indicator has basic visualization for signals and alerts, the new CRT ranges and 3-candle models will require their own distinct visual representations and alert mechanisms to provide clear and actionable information to the user.

## 3. Implementation Strategy: CRT Range Drawing

To correctly draw the 4-hour and 1-hour CRT ranges, we will refine the existing `request.security` approach and ensure precise time synchronization. The strategy will involve:

### 3.1 Time Synchronization and Target Candle Identification

Pine Script operates on exchange time by default. To accurately identify the 1 AM, 5 AM, 9 AM NY (for 1H) and 00:00, 04:00, 08:00 NY (for 4H) candles, we will need to:

1.  **Determine New York Time:** Use `time()` and `hour()` functions in conjunction with the `timezone` argument to convert the current bar's time to New York time. This will allow us to precisely identify when the target CRT candle *should* close in New York time.
2.  **Identify the Target Candle:** Instead of relying solely on `htf_time[1]`, we will explicitly check if the *previous* higher timeframe candle (e.g., H1 or H4) closed at the exact target hour in New York time. This ensures that the CRT range is always derived from the correct candle, regardless of minor time discrepancies or data feed variations.
3.  **Robust Range Setting:** The `crt_high` and `crt_low` variables will be updated only when the identified target candle has fully closed and its high/low values are confirmed. This prevents premature range setting based on incomplete candle data.

### 3.2 Dynamic Range Visualization

The existing `box.new` function is suitable for drawing the CRT range. We will enhance its usage to:

1.  **Persistent Drawing:** Ensure the CRT range box persists on the chart until a new daily range is set. The `extend=extend.right` property is already being used, which is good for extending the box to the right.
2.  **Clear Labeling:** Add clear labels to the CRT high and low lines (e.g., "CRT High", "CRT Low") to improve readability.
3.  **Color Coding:** Potentially use different colors or styles for 1-hour and 4-hour CRT ranges to visually distinguish them.
4.  **Daily Reset:** Implement a mechanism to reset the CRT range at the start of each new trading day (New York time) to ensure that the range is always relevant to the current day's session.

## 4. Implementation Strategy: 3-Candle Models

Implementing 3-candle models will involve defining specific price action patterns and creating functions to detect them. Common 3-candle patterns include:

*   **Three White Soldiers / Three Black Crows:** These are strong reversal patterns. For Three White Soldiers, we would look for three consecutive long-bodied bullish candles closing higher than the previous one, often opening within the previous body. For Three Black Crows, it would be the inverse.
*   **Morning Star / Evening Star:** These are also reversal patterns. A Morning Star typically involves a large bearish candle, followed by a small-bodied candle (often a doji or spinning top) that gaps down, and then a large bullish candle that closes well into the first bearish candle's body. An Evening Star is the bearish equivalent.
*   **Three Inside Up / Three Inside Down:** These are continuation or reversal patterns depending on context. They involve a large first candle, followed by a smaller second candle (inside bar), and then a third candle that closes beyond the first candle's range in the direction of the reversal/continuation.

### 4.1 Pattern Detection Functions

We will create dedicated functions for each 3-candle model. Each function will take relevant candle data (open, high, low, close for the last three candles) as input and return a boolean indicating whether the pattern is detected. These functions will involve:

1.  **Candle Body and Wick Analysis:** Calculating candle body size, wick lengths, and comparing them to previous candles.
2.  **Price Relationship Checks:** Comparing open, high, low, and close prices across the three candles to identify specific relationships (e.g., higher highs, lower lows, closes within previous bodies).
3.  **Contextual Filtering:** Potentially incorporating volume or other indicators to confirm the strength of the pattern.

### 4.2 Integration with Entry Logic

Once detected, these 3-candle models can be integrated into the existing entry logic as additional confirmation signals or as standalone entry triggers, depending on the user's preference. This could involve:

1.  **Confluence with CRT:** If a 3-candle model appears near a CRT range sweep or a Market Structure Shift (MSS), it could strengthen the trade signal.
2.  **Alert Generation:** Generate specific alerts when a 3-candle model is detected, providing the user with timely notifications.

## 5. Visualizations and Alerts for 3-Candle Models

To make the detection of 3-candle models clear to the user, we will implement:

1.  **Chart Labels/Arrows:** Place distinct labels or arrows on the chart at the point where a 3-candle model is detected, indicating the type of pattern (e.g., "Morning Star", "Three White Soldiers").
2.  **Background Shading:** Optionally, shade the background of the three candles involved in the pattern with a specific color to visually highlight them.
3.  **Customizable Alerts:** Provide options for the user to enable/disable alerts for each specific 3-candle model, with customizable alert messages.

## 6. Refinement and Testing

After implementing these features, thorough testing will be crucial. This will involve:

1.  **Backtesting:** Using historical data to verify that the CRT ranges are drawn correctly and that the 3-candle models are detected accurately under various market conditions.
2.  **Forward Testing:** Observing the indicator's behavior in real-time on a demo account to ensure its stability and reliability.
3.  **Edge Case Handling:** Identifying and addressing any edge cases or unexpected behaviors.

This design provides a clear roadmap for enhancing the Pine Script indicator to meet the specified requirements for CRT ranges and 3-candle models. The next steps will involve translating this design into Pine Script code and rigorously testing the implementation.


