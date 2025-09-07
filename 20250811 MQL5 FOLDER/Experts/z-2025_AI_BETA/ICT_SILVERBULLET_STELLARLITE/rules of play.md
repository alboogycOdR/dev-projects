Okay, let's break down how trade entries are formulated in your EA, focusing on the "Silver Bullet" within its killzone and the "2022 Model," and highlight the factors and differences.

**Overall Entry Trigger Flow:**

Regardless of the specific model, a trade entry is considered if the following top-level conditions in `OnTick()` are met:

1.  **Trading Allowed:** `IsTradingAllowed()` returns true (account/terminal allows trading).
2.  **Drawdown Limits Not Hit:** `CheckDrawdownLimits()` returns false.
3.  **No Existing Position (by this EA):** `positionInfo.SelectByMagic(_Symbol, magicNumber)` returns false, leading to `CheckForEntrySignals()` being called.
4.  **New Bar (Primarily):** Entry signals are primarily checked on the formation of a new bar (`currentBarTime > lastBarTime`).

Inside `CheckForEntrySignals()`:

1.  **Higher Timeframe (HTF) Bias Determined:**
    *   `DetermineHTFBias()` is called. It uses a Moving Average (default: 200 SMA on H1) to establish a directional bias.
        *   **Bullish Bias (ORDER_TYPE_BUY):** Current price > MA\ and MA\ > MA\ (price above a rising MA).
        *   **Bearish Bias (ORDER_TYPE_SELL):** Current price < MA\ and MA\ < MA\ (price below a falling MA).
    *   If no clear bias (or MA data is insufficient), it returns `(ENUM_ORDER_TYPE)-1`, and no further entry logic proceeds for that tick.

2.  **Strategy-Specific Checks (Silver Bullet then 2022 Model):**
    *   The EA prioritizes the Silver Bullet if its conditions are met.
    *   If Silver Bullet conditions are not met, it then checks the 2022 Model conditions.
    *   A `TradeSetup` struct is populated by these functions. If `setup.isValid` becomes true, lot size is calculated, and `OpenTrade()` is called.

**Execution Timeframe (`_Period`):**

Crucially, all the pattern recognition for FVG, MSS, Liquidity Sweeps, and NDOG/NWOG within `CheckSilverBulletEntry` and `Check2022ModelEntry` happens based on the `MqlRates rates[]` copied using `_Period`. This means **the timeframe of the chart you attach the EA to is the primary timeframe for identifying these entry patterns.**

---

**Silver Bullet Entry Formulation (within `CheckSilverBulletEntry`)**

This model is active only if `Use_SilverBullet` is true AND the current server time (formatted as "HH:MM") falls within `SB_StartTime` and `SB_EndTime` (the "Killzone" – e.g., 10:00-11:00 NY AM).

If within the Killzone, the following factors are assessed **on the chart's timeframe (`_Period`)**:

1.  **Liquidity Sweep (Factor 1):**
    *   **Goal:** To see if liquidity has been recently "engineered" or "taken" before a potential move in the direction of the HTF `bias`. This often means sweeping liquidity *counter* to the `bias` to grab stops or entice traders the wrong way.
    *   `double liquidityLevel = FindNearestLiquidityLevel(bias == ORDER_TYPE_SELL);`
        *   If HTF `bias` is BUY, it looks for the nearest *recent low* (potential sell-side liquidity).
        *   If HTF `bias` is SELL, it looks for the nearest *recent high* (potential buy-side liquidity).
    *   `bool liquiditySwept = CheckLiquiditySweep(liquidityLevel, bias == ORDER_TYPE_SELL ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, rates);`
        *   This checks if the `liquidityLevel` (the identified high/low) was actually breached by `rates` (current bar) or `rates` (previous bar).
        *   The second argument to `CheckLiquiditySweep` defines the "expected sweep direction":
            *   If HTF `bias` is BUY (we want to buy), it checks if a *low* was taken (`ORDER_TYPE_SELL` passed as sweep direction argument).
            *   If HTF `bias` is SELL (we want to sell), it checks if a *high* was taken (`ORDER_TYPE_BUY` passed as sweep direction argument).
    *   **In essence:** For a BUY setup, it's looking if a recent low was taken out. For a SELL setup, it's looking if a recent high was taken out.

2.  **Market Structure Shift (MSS) (Factor 2):**
    *   **Goal:** To confirm a change in short-term order flow *in the direction of the HTF `bias`* after the liquidity sweep.
    *   `bool mssConfirmed = CheckMSS(bias, rates);`
        *   Your simplified `CheckMSS`:
            *   For a BUY `bias`: `rates.close > rates.high` (current bar closes strongly above the previous bar's high).
            *   For a SELL `bias`: `rates.close < rates.low` (current bar closes strongly below the previous bar's low).
    *   This indicates a break of the most immediate prior market structure.

3.  **Fair Value Gap (FVG) / Imbalance (Factor 3):**
    *   **Goal:** To find an area of imbalance (an FVG) that price might return to for an entry, *aligned with the HTF `bias`*.
    *   `FindFVG(rates, fvgHigh, fvgLow, bias);`
        *   If `bias` is BUY, it looks for a bullish FVG (where `rates[i].low > rates[i+2].high`, indicating a gap upwards).
        *   If `bias` is SELL, it looks for a bearish FVG (where `rates[i].high < rates[i+2].low`, indicating a gap downwards).
        *   The FVG also checks if the middle candle (`rates[i+1]`) showed "displacement" (strong move) and if the current price (`rates.close`) is reasonably positioned relative to the FVG (e.g., not too far past it).

4.  **NDOG/NWOG Filter (Factor 4 - Simplified as Small Bar Range):**
    *   **Goal:** In this code, it acts as a filter to see if the *current, developing bar* (`rates`) is a small-range bar (body is less than `NDOG_NWOG_Threshold` times ATR).
    *   `bool isNDOG_NWOG = CheckNDOG_NWOG(rates, 0);`
    *   **Interpretation:** This might be intended as a filter for low volatility just before entry, or ensuring the FVG itself isn't excessively large due to a volatile candle. It's checking `rates`, which would be the candle the EA is considering *entering on* if using a market order.

**Silver Bullet Entry Condition:**
A trade setup is considered valid IF (`liquiditySwept && mssConfirmed && fvgHigh > 0 && fvgLow > 0 && isNDOG_NWOG`) are all true.

**Trade Levels if Valid:**
*   `setup.orderType = bias;`
*   `setup.entryPrice`: Calculated using `CalculateEntryPrice`. This is either the midpoint of the identified FVG or an Optimal Trade Entry (OTE) level (e.g., 61.8% or 78.6% into the FVG, based on `OTE_Lower_Level`, `OTE_Upper_Level` inputs if `Use_OTE_Entry` is true).
*   `setup.stopLossPrice`: Calculated using `FindProtectiveStopLoss`, placed beyond the FVG structure or a nearby swing point (e.g., a bit below the low of the FVG for a buy).
*   Take Profit levels are calculated based on Risk:Reward ratios from the `stopLossPrice`.

---

**2022 Model Entry Formulation (within `Check2022ModelEntry`)**

This model is active if `Use_2022Model` is true and the Silver Bullet didn't trigger. **Critically, as coded, there is no specific time restriction (Killzone) for the 2022 Model.** It can trigger at any time.

The factors assessed **on the chart's timeframe (`_Period`)** are:

1.  **Inducement Sweep (Factor 1 - Similar to SB Liquidity Sweep but conceptually distinct):**
    *   **Goal (Conceptual "Inducement"):** To see a sweep of more obvious, recent liquidity (often a recent swing high/low that less experienced traders might target or place stops behind) *before* price moves to a true Point of Interest (like the FVG where the EA aims to enter).
    *   `inducementLevel = FindNearestLiquidityLevel(bias == ORDER_TYPE_SELL);` (Same logic as SB to find a recent high/low)
    *   `inducementSwept = CheckLiquiditySweep(inducementLevel, bias == ORDER_TYPE_SELL ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, rates);` (Same logic as SB to check if the level was breached in a direction counter to the HTF bias).
    *   **Difference from SB Sweep:** While the *code execution* for identifying and checking the sweep is identical to Silver Bullet's, the *narrative and timing* in ICT for "Inducement" often implies this happens a bit earlier in a sequence, clearing the path, whereas the Silver Bullet sweep might be the very final engineered liquidity before entry within a tight killzone window. The code currently does not distinguish the *quality* or *type* of the `FindNearestLiquidityLevel` for Inducement vs. Silver Bullet's sweep – it just finds the "nearest."

2.  **Market Structure Shift (MSS) (Factor 2):**
    *   `bool mssConfirmed = CheckMSS(bias, rates);`
    *   Identical MSS logic and goal as in the Silver Bullet model: a confirmation of order flow shifting in the direction of the HTF `bias` *after* the inducement sweep.

3.  **Fair Value Gap (FVG) / Imbalance (Factor 3):**
    *   `FindFVG(rates, fvgHigh, fvgLow, bias);`
    *   Identical FVG identification logic and goal as in the Silver Bullet model: finding an FVG aligned with the `bias` for a potential entry.

4.  **NDOG/NWOG Filter (Factor 4 - Simplified as Small Bar Range):**
    *   `bool isNDOG_NWOG = CheckNDOG_NWOG(rates,0);`
    *   Identical filter as in the Silver Bullet model.

**2022 Model Entry Condition:**
A trade setup is considered valid IF (`inducementSwept && mssConfirmed && fvgHigh > 0 && fvgLow > 0 && isNDOG_NWOG`) are all true.

**Trade Levels if Valid:**
The calculation of `setup.orderType`, `setup.entryPrice`, `setup.stopLossPrice`, and Take Profit levels is identical to the Silver Bullet model once a valid setup is identified.

---

**Key Differences Between Silver Bullet & 2022 Model (as Coded):**

1.  **Time Restriction (Killzone):**
    *   **Silver Bullet:** Strictly time-bound by `SB_StartTime` and `SB_EndTime`.
    *   **2022 Model:** No time restriction in the code; can trigger any time the conditions align.

2.  **Liquidity Concept Naming (Conceptual vs. Code):**
    *   **Silver Bullet:** Refers to `liquiditySwept`.
    *   **2022 Model:** Refers to `inducementSwept`.
    *   **In Code:** The functions `FindNearestLiquidityLevel` and `CheckLiquiditySweep` used to detect these are *identical* in their current implementation for both models. A discretionary trader might identify different *types* or *qualities* of liquidity for "inducement" versus a "killzone sweep," but the code doesn't have that nuance; it looks for the "nearest" level defined by `DOL_Lookback_Bars`.

3.  **Implicit Priority:**
    *   The EA checks for Silver Bullet first within its killzone. Only if that fails (or it's outside the killzone and SB is disabled) does it consider the 2022 Model.

**Factors That Play a Part (General Summary for Both):**

*   **Chart Timeframe (`_Period`):** This is where all entry patterns (sweeps, MSS, FVG, NDOG/NWOG) are identified.
*   **HTF Bias (MA-based):** Sets the overarching intended trade direction.
*   **Specific Time Window:** Exclusively for Silver Bullet (the "Killzone").
*   **Liquidity Sweep:** Evidence of recent highs/lows being taken, typically counter to the intended HTF bias move (to engineer liquidity).
*   **Market Structure Shift (MSS):** A break of immediate structure confirming a potential shift in order flow in the direction of the bias.
*   **Fair Value Gap (FVG):** An imbalance that serves as the Point of Interest for entry.
*   **Optimal Trade Entry (OTE - Optional):** If `Use_OTE_Entry` is true, the entry price is refined to a specific Fibonacci retracement level within the FVG. Otherwise, it's the FVG's midpoint.
*   **NDOG/NWOG (Small Bar Filter):** Ensures the bar being considered for entry (`rates`) has a small range, potentially filtering out entries during high-volatility spikes or indicating consolidation.
*   **Risk Management Parameters:** These don't *formulate* the entry signal itself but determine if a valid signal can be *taken* (e.g., drawdown limits) and how (lot size).

This detailed breakdown should give you a clear understanding of how the entry signals are generated step-by-step from the code's perspective.