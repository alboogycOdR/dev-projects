

### **Design Document Addendum: Appendix A - The Core Logic Engine**

*(This section should be provided to the developer along with the original design document.)*

**Objective:** To provide a developer with the precise, mathematical, and pseudo-code definitions required to translate "The Apex Protocol" trading strategy into Pine Script code. This eliminates all interpretive guesswork.

#### **1. Higher Timeframe (HTF) Bias Logic**

*   **Function:** Determine if the market's primary trend is Bullish or Bearish.
*   **Method:**
    1.  Use the `security()` function in Pine Script to request data from the user-defined `HTF Timeframe` (default "4H").
    2.  Calculate the `HTF EMA Length` (default 50) on that timeframe's closing prices.
    3.  **Bullish Condition:** `IF close` of the current H4 candle is `>` the `HTF EMA`.
    4.  **Bearish Condition:** `IF close` of the current H4 candle is `<` the `HTF EMA`.
*   **Result:** A boolean variable `isBullishBias` that is used to color the background and validate setups.

#### **2. Liquidity Sweep (Manipulation) Logic**

*   **Function:** Detect when a key liquidity level has been "swept" or "raided."
*   **Key Levels to Monitor:** Asian Session High/Low (ASH/ASL) and Previous Day High/Low (PDH/PDL).
*   **Bullish Sweep (Stop Hunt Below a Low) Method:**
    1.  Identify a key low (e.g., `asianSessionLow`).
    2.  The sweep is confirmed when:
        *   `low[1] < keyLow` (The previous candle's low broke beneath the level).
        *   AND `close[1] > keyLow` (The candle *closed back above* the level).
        *   *Alternative Condition:* Or `low[1] < keyLow` followed by `close[0] > open[0]` (the current candle is a strong bullish candle, confirming rejection).
    3.  **Result:** Set a boolean flag `isBullishSweep = true`. The price of `low[1]` is now the logged "manipulation wick low."

*   **Bearish Sweep (Stop Hunt Above a High) Method:**
    1.  Identify a key high (e.g., `asianSessionHigh`).
    2.  The sweep is confirmed when:
        *   `high[1] > keyHigh` (The previous candle's high broke above the level).
        *   AND `close[1] < keyHigh` (The candle *closed back below* the level).
    3.  **Result:** Set a boolean flag `isBearishSweep = true`. The price of `high[1]` is now the logged "manipulation wick high."

#### **3. Change of Character (CHoCH) Logic**

*   **Function:** Confirm that momentum has shifted after a liquidity sweep.
*   **Method:** Use the built-in `ta.pivothigh()` and `ta.pivotlow()` functions to identify swing points. The `lookback period` for pivots should be a user input.

*   **Bullish CHoCH (For a Buy Setup):**
    1.  Condition: A `isBullishSweep` must be true.
    2.  Identify the last significant `ta.pivothigh()` that formed *before* the liquidity sweep.
    3.  The CHoCH is confirmed when the `high` of a candle **breaks and closes above** the price of that pivot high.
    4.  **Result:** Set a boolean flag `isBullishCHoCH = true`.

*   **Bearish CHoCH (For a Sell Setup):**
    1.  Condition: A `isBearishSweep` must be true.
    2.  Identify the last significant `ta.pivotlow()` that formed *before* the liquidity sweep.
    3.  The CHoCH is confirmed when the `low` of a candle **breaks and closes below** the price of that pivot low.
    4.  **Result:** Set a boolean flag `isBearishCHoCH = true`.

#### **4. Entry Zone Identification Logic (FVG/OB)**

*   **Function:** Find the optimal entry zone created during the CHoCH price leg.
*   **Priority Rule:** The script must prioritize a **Fair Value Gap (FVG)** over an **Order Block (OB)**.
*   **Search Method:** Once a CHoCH is confirmed, loop backwards from the confirmation candle towards the manipulation wick.

*   **Codable Definition of a Bullish Fair Value Gap (FVG):**
    *   A three-candle pattern. Look for a candle (`candle A`) where `high[A]` is lower than the `low` of the candle two bars after it (`candle C`).
    *   The gap is the space between `high[A]` and `low[C]`.
    *   The entry price is the top of this gap.

*   **Codable Definition of a Bearish Order Block (OB):**
    *   An Order Block is the **last up-candle (bullish close)** before the strong down-move that created the Bearish CHoCH.
    *   The entry zone is the `open` price of that up-candle.

*   **Entry Selection Logic:**
    1.  If `isBullishCHoCH` is true, loop backwards from the CHoCH candle.
    2.  The **first valid FVG** you find becomes the `entryZone`.
    3.  If **no FVG is found** after searching X bars, use the **Order Block** as the `entryZone`.

---

**Conclusion for the Developer:**

With this appendix, the project is fully specified. The original document provides the **Functional Requirements** (the "what"), and this annex provides the **Logical Requirements** (the "how"). By coding these specific definitions, you will accurately replicate the trading logic of The Apex Protocol.