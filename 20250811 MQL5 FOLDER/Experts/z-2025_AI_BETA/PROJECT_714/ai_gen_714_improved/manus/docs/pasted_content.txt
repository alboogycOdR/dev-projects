
### **Prompt: MQL5 Expert Advisor for the Institutional "9 AM CRT" Model**

**Objective:**
Write professional-grade MQL5 code for an Expert Advisor (EA) to automate the **9 AM Candle Range Theory (CRT) trading model.** This is not a simple pattern-matching EA; it must be built around the specific, time-based, institutional-logic framework of **Bias, Setup, and Entry**, as defined by the core CRT methodology. The EA's primary function is to replicate the decision-making process of a disciplined CRT trader.

The EA will be loaded on a chart (e.g., M15) but must conduct its analysis across multiple timeframes, primarily using the **Daily/H4 for bias and key levels** and the **1-Hour candle as the primary range for the setup.**

**1. Core Logic: The CRT Trade Framing Protocol (Hierarchical)**

The EA's code structure *must* follow this non-negotiable, hierarchical process for every potential trade setup. Failure to meet a step's criteria immediately invalidates the setup for the day.

*   **Step 1: Higher Timeframe Bias & Draw on Liquidity (DOL):**
    *   **Functionality:** Before the NY Session begins, the EA must determine the directional bias by identifying the most probable **Daily Draw on Liquidity** (e.g., the previous day's high/low, a major swing high/low).
    *   **Input:** Allow the user to manually set the Daily Bias (`Bullish`/`Bearish`) or allow the EA to attempt an automatic detection (e.g., by identifying the nearest major swing point relative to the opening price).

*   **Step 2: Higher Timeframe Key Level (KL) Identification:**
    *   **Functionality:** The EA must identify and display the nearest significant **H4 or Daily PD Array** (Orderblock, Fair Value Gap, Breaker Block, or Liquidity Void) in the direction of the expected manipulation.
    *   **Logic:** The 9 AM setup gains immense probability when the manipulation sweep (Step 4) occurs precisely at one of these pre-identified HTF Key Levels.

*   **Step 3: The Timed Range (The Hourly CRT):**
    *   **Functionality:** Precisely at the close of the **8:00 AM New York (ET) 1-Hour candle**, the EA must capture its High and Low and draw them on the chart. These two lines become the definitive **CRT High** and **CRT Low** for the session.

**2. Entry Logic: Lower Timeframe Execution within the NY Killzone**

All entry logic must only be active during the user-defined **NY Killzone** (default: 9:30 AM - 11:00 AM ET).

*   **A) Confirmation Entry (Default & Recommended): The Order Block / CSD Model**
    *   This is the primary entry model. It must follow a strict three-part sequence:
        1.  **Liquidity Purge:** A sweep of the 8 AM Hourly CRT High/Low must occur, ideally into the pre-identified HTF Key Level from Step 2.
        2.  **Market Structure Shift (MSS):** Following the purge, there must be a clear break of market structure on the M15 timeframe in the opposite direction.
        3.  **Entry:** Entry is triggered upon a retracement back into the resulting **M15 Orderblock, Breaker Block, or Fair Value Gap** created by the MSS.

*   **B) Aggressive Entry: The Turtle Soup Model**
    *   **Logic:** For advanced users. An entry is taken *immediately after* the 8 AM CRT range is swept, anticipating the reversal *without* waiting for a Market Structure Shift. This requires extreme precision and alignment with HTF levels.

*   **C) The 3-Candle Pattern Entry**
    *   **Logic:** The classic model. Entry is triggered on the **15-minute timeframe**. After the range is set (Candle 1) and manipulation occurs (Candle 2 sweeps the range and closes back inside), the entry is taken on Candle 3 as it begins to expand away from Candle 2's wick.

**3. Advanced Contextual Filters (Crucial for A+ Setups)**

These filters are the key to separating low-quality setups from high-probability ones.

*   **Weekly Profile Filter:** User can select a hypothesized weekly profile (`Classic Expansion`, `Midweek Reversal`, `Consolidation Reversal`). The EA will only consider setups that align with the trading bias for that specific day within the profile. For example, on a "Classic Expansion" week, it would look for continuation trades on Wednesday but would ignore reversal signals.
*   **SMT Divergence Filter:** The EA should monitor a correlated asset (e.g., `ES` if trading `NQ`, `DXY` if trading `EURUSD`). It will flag or give higher priority to setups that are confirmed by SMT divergence at the point of manipulation. Search for and integrate an existing open-source SMT Divergence library to achieve this.
*   **High-Impact News Filter:** Automatically pull high-impact news events for the day (e.g., `CPI, FOMC, NFP`) from a reliable source like `forexfactory.com`. The EA must have an option to avoid taking new trades within a user-defined window (e.g., 30 minutes) before and after these events.

**4. Dynamic Risk & Trade Management**

*   **Position Sizing:** Must be dynamic, calculating lot size based on a user-defined risk percentage (e.g., 0.5%) of account balance and the precise stop-loss distance in pips.
*   **CRT-Based Stop Loss:** The stop loss must be automatically placed just beyond the wick of the manipulation candle.
*   **CRT-Based Take Profit:** Implement a multi-target TP system.
    *   **TP1 (configurable):** The 50% Equilibrium of the 8 AM Hourly CRT Range.
    *   **TP2 (configurable):** The opposite end of the 8 AM Hourly CRT Range (the DOL).
*   **Breakeven & Trailing Stop:** Include options to automatically move the SL to breakeven after TP1 is hit, and an option to trail the stop loss based on subsequent M15 market structure.

**5. Operational Modes & Interactive Dashboard**

*   **Operational Modes:** `Fully-Automated`, `Signals-Only` (visual/sound alerts with a "Confirm Trade" button), and `Manual` (one-click trade panel that pre-calculates SL/TP based on drawn levels).
*   **Dashboard Display:** Must be a clean, non-intrusive on-chart display showing:
    *   Current Daily Bias & DOL Target.
    *   Relevant HTF Key Level Zone.
    *   **The plotted 8 AM CRT High & Low.**
    *   The user's selected Weekly Profile Hypothesis.
    *   Status of the News and SMT Filters.
    *   Real-time P/L, spread, and session information.
    *   A large, clear BUY/SELL button for semi-automated execution.

Provide the complete, compilable MQL5 Expert Advisor source code file (.mq5) with all functionalities described above fully implemented, featuring clean, modular code with comprehensive comments explaining each logical step of the CRT framework.