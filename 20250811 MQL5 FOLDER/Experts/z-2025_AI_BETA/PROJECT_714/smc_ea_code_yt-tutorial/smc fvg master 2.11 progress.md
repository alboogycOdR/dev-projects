Okay, let's break down every SMC "item" (pattern) and key level being calculated and potentially drawn by your "Master SMC EA" `version 2.11`.

**I. Core SMC Patterns / Concepts Detected:**

1.  **Swing Points (Highs/Lows):**
    *   **What:** Identifies 3-bar fractal swing highs and lows on the `InpAnalysisTimeframe`.
        *   **Swing High (SH):** A bar (`rates[2]`) whose high is greater than the high of the preceding bar (`rates[3]`) and the succeeding bar (`rates[1]`).
        *   **Swing Low (SL):** A bar (`rates[2]`) whose low is lower than the low of the preceding bar (`rates[3]`) and the succeeding bar (`rates[1]`).
    *   **Calculation:** Done in `swingPoints()` by comparing `rates[2].high/low` with `rates[1].high/low` and `rates[3].high/low`.
    *   **Storage:** Recent SH/SL values and times are stored in `Highs[]`, `Lows[]`, `HighsTime[]`, `LowsTime[]`. The most recent confirmed swing times are also stored in `lastTimeH`, `lastTimeL`, and the one before that in `prevTimeH`, `prevTimeL`.
    *   **Visuals:**
        *   No direct arrows for simple SH/SL are drawn by default (commented out).
        *   Information is used for BoS/CHoCH/EQH/EQL.

2.  **Break of Structure (BoS):**
    *   **What:** Indicates a continuation of the current market structure/trend.
        *   **Bullish BoS:** A higher low structure (`rates[indexLastL].low > rates[indexPrevL].low`) is in place, and then price breaks *above* the last significant swing high (`rates[indexLastH].high`). The break is confirmed by `rates[1].close > rates[indexLastH].high` while `rates[2].close < rates[indexLastH].high`.
        *   **Bearish BoS:** A lower high structure (`rates[indexLastH].high < rates[indexPrevH].high`) is in place, and then price breaks *below* the last significant swing low (`rates[indexLastL].low`). The break is confirmed by `rates[1].close < rates[indexLastL].low` while `rates[2].close > rates[indexLastL].low`.
    *   **Calculation:** Done in `swingPoints()` using `lastTimeH/L` and `prevTimeH/L` which point to `rates[indexLastH/L]` and `rates[indexPrevH/L]` respectively, comparing current price action (`rates[1]`, `rates[2]`) against these past swing points.
    *   **Visuals:** Draws a horizontal trend line at the broken structure level and a text marker "BoS" (with Wingdings arrow) using `createObj()`.

3.  **Change of Character (CHoCH / sometimes SMS - Shift in Market Structure):**
    *   **What:** Indicates a *potential* shift in market structure/trend from bullish to bearish or vice-versa.
        *   **Bullish CHoCH:** A prior downtrend (lower highs and lower lows) is established (`rates[indexLastH].high < rates[indexPrevH].high && rates[indexLastL].low < rates[indexPrevL].low`), and then price breaks *above* the last significant lower high (`rates[indexLastH].high`).
        *   **Bearish CHoCH:** A prior uptrend (higher lows and higher highs) is established (`rates[indexLastH].high > rates[indexPrevH].high && rates[indexLastL].low > rates[indexPrevL].low`), and then price breaks *below* the last significant higher low (`rates[indexLastL].low`).
    *   **Calculation:** Done in `swingPoints()` using `lastTimeH/L` and `prevTimeH/L` similarly to BoS, but checking for a break of structure that *opposes* the preceding short-term trend.
    *   **Visuals:** Draws a horizontal trend line at the broken structure level and a text marker "CHoCH" (with Wingdings arrow) using `createObj()`.

4.  **Fair Value Gap (FVG) / Imbalance:**
    *   **What:** A 3-candle pattern indicating inefficient price delivery, leaving a "gap" or imbalance.
        *   **Bullish FVG:** `rates[1].low > rates[3].high` (gap between candle 1 low and candle 3 high). Also checks for strength in candles 1, 2, and 3.
        *   **Bearish FVG:** `rates[1].high < rates[3].low` (gap between candle 1 high and candle 3 low). Also checks for strength.
    *   **Calculation:** Done in `FVG()`. Key levels are `rates[3].high` and `rates[1].low` (for Bullish FVG boundaries) or `rates[1].high` and `rates[3].low` (for Bearish FVG boundaries).
    *   **Storage:** Recent Bullish/Bearish FVG boundaries (high/low of the gap) and the time of the middle candle (`rates[2].time`) are stored in `Bu/BeFVGHighs[]`, `Bu/BeFVGLows[]`, `Bu/BeFVGTime[]`.
    *   **Visuals:**
        *   Draws a dotted rectangle from `rates[3].time` to `rates[0].time` (of `InpAnalysisTimeframe`) spanning the FVG's price boundaries.
        *   Attaches a text label ("Bu FVG" or "Be FVG") using `CreateAttachedText`.

5.  **Order Block (OB):**
    *   **What:** The last opposing candle before a strong impulsive move that often leads to a BoS/CHoCH. Assumed to be an area where institutions accumulated orders.
        *   **Bullish OB:** Identified using `rates[3]` as the OB candle if `rates[3]` is a swing low and `rates[1]` shows strong displacement upwards past `rates[3].high`.
        *   **Bearish OB:** Identified using `rates[3]` as the OB candle if `rates[3]` is a swing high and `rates[1]` shows strong displacement downwards below `rates[3].low`.
    *   **Calculation:** Done in `orderBlock()`. The zone is defined by `rates[3].high` and `rates[3].low`.
        *   Optionally filtered by `InpFilterObVolume`: `rates[3].tick_volume` must be greater than that of `rates[4]` and `rates[2]`.
    *   **Storage:** Recent OB high, low, and time are stored in `bullish/bearishOrderBlockHigh/Low/Time[]`.
    *   **Visuals:**
        *   Draws a solid rectangle from `rates[3].time` to `rates[0].time` (of `InpAnalysisTimeframe`) spanning the OB's high and low.
        *   Attaches a text label ("Bu OB" or "Be OB") using `CreateAttachedText`.
    *   **Invalidation:** OB is considered invalidated (and its visual removed) if `rates[1].close` (on `InpAnalysisTimeframe`) closes beyond the OB's outer boundary.

6.  **Rejection Block (RB):**
    *   **What:** A specific candle (`rates[2]`) that forms a swing high/low with a significant wick, suggesting price rejection from that area. Can be bullish or bearish, and the candle itself can be green (bullish body) or red (bearish body).
        *   **Bullish RB Green:** `rates[2]` is a green-bodied candle forming a swing low. Zone: `rates[2].low` to `rates[2].open`.
        *   **Bullish RB Red:** `rates[2]` is a red-bodied candle forming a swing low. Zone: `rates[2].low` to `rates[2].close`.
        *   **Bearish RB Red:** `rates[2]` is a red-bodied candle forming a swing high. Zone: `rates[2].open` to `rates[2].high`.
        *   **Bearish RB Green:** `rates[2]` is a green-bodied candle forming a swing high. Zone: `rates[2].close` to `rates[2].high`.
    *   **Calculation:** Done in `rBlock()`. Conditions check candle color (`open` vs `close`) and standard 3-bar swing conditions for `rates[2]`.
    *   **Storage:** Recent RB boundaries and times are stored in the respective `bullish/bearish` `Green/Red` `High/Low/TimeValues[]` arrays.
    *   **Visuals:**
        *   Draws a solid rectangle from `rates[2].time` to `rates[0].time` (of `InpAnalysisTimeframe`) spanning the defined RB zone.
        *   Attaches a text label (e.g., "Bu rBG", "Be rBR") using `CreateAttachedText`.
    *   **Invalidation:** RB is considered invalidated if `rates[1].low` wicks below a bullish RB's low, or `rates[1].high` wicks above a bearish RB's high.

**II. Key Price Levels Calculated:**

1.  **Fair Value Gap Consequent Encroachment (FVG CE / 0.5 Level):**
    *   **What:** The midpoint (50% level) of a detected FVG.
    *   **Calculation:** `(FVG_High_Boundary + FVG_Low_Boundary) / 2.0`. Done in `FVG()`.
    *   **Storage:** Stored in `BuFVG_CE[]` and `BeFVG_CE[]`.
    *   **Visuals:** If `InpDrawFvgCE` is true, a horizontal trend line (default `STYLE_DASHDOTDOT`) is drawn across the FVG at this 0.5 level. A text label ("CE 50%") is attached using `CreateAttachedText`.

2.  **Previous Day High (PDH) & Previous Day Low (PDL):**
    *   **What:** The highest and lowest price reached during the *previous* trading day.
    *   **Calculation:** Done in `UpdatePeriodicLevels()`. Uses `CopyHigh(_Symbol, PERIOD_D1, 1, 1, ...)` and `CopyLow(_Symbol, PERIOD_D1, 1, 1, ...)` to get the high/low of the bar at index 1 of the Daily timeframe.
    *   **Storage:** Stored in global variables `g_pdh` and `g_pdl`. Updated once per day.
    *   **Visuals:** If `InpDrawPDH`/`InpDrawPDL` is true, a horizontal line (`OBJ_HLINE`) is drawn at these levels, with a text label "PDH" or "PDL" managed by `DrawHorizontalLine()`.

3.  **Previous Week High (PWH) & Previous Week Low (PWL):**
    *   **What:** The highest and lowest price reached during the *previous* trading week.
    *   **Calculation:** Done in `UpdatePeriodicLevels()`. Uses `CopyHigh(_Symbol, PERIOD_W1, 1, 1, ...)` and `CopyLow(_Symbol, PERIOD_W1, 1, 1, ...)` for the Weekly timeframe.
    *   **Storage:** Stored in global variables `g_pwh` and `g_pwl`. Updated once per week.
    *   **Visuals:** If `InpDrawPWH`/`InpDrawPWL` is true, a horizontal line is drawn at these levels, with a text label "PWH" or "PWL".

4.  **Equal Highs (EQH) & Equal Lows (EQL):**
    *   **What:** Two (or more, though currently detects pairs) consecutive swing highs or swing lows that are at approximately the same price level (within `InpEqTolerancePips`). These represent areas of engineered liquidity.
    *   **Calculation:** Done in `swingPoints()`. When a new potential swing high (`highvalue_swing`) is forming and it's higher than the last confirmed swing high (`Highs[0]`), it checks if `MathAbs(highvalue_swing - Highs[0]) <= InpEqTolerancePips*_Point`. A similar check is done for lows.
    *   **Storage:** Not explicitly stored in separate arrays, but the underlying swing points are. The "EQH/EQL" status is determined dynamically for drawing.
    *   **Visuals:** If `InpDrawEqHL` is true, a text marker ("=EQH=" or "=EQL=") is drawn near *both* swing points that form the equal high/low using `CreateAttachedText` (actually `createObj` calls `CreateAttachedText` if the text parameter is filled).

5.  **Moving Average (SMA):**
    *   **What:** A simple moving average.
    *   **Calculation:** Handle created in `OnInit()` using `iMA(_Symbol, InpSmaTimeframe, InpSmaPeriod, ...)`. Buffer data is copied into the `sma[]` array in `OnTick()`.
    *   **Storage:** Recent SMA values (from `InpSmaTimeframe`) are stored in the local `sma[]` array within `OnTick`. Not a persistent "key level" stored globally other than its configuration.
    *   **Visuals:** The SMA line is drawn on the chart automatically by the `iMA` indicator handle itself if it's plotted on the main chart. The EA code doesn't draw it, only uses its values.

This breakdown should cover all the primary SMC patterns and key price levels that your EA is currently designed to identify, calculate, and (in most cases) visualize. The next step is to define how the EA will use these "puzzle pieces" to make trading decisions.