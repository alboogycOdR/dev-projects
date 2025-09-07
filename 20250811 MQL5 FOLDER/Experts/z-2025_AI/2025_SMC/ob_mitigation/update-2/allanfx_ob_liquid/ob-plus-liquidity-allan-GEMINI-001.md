Okay, I understand the requirements. You want to significantly modify the `ob-allan.txt` code to implement a specific SMC strategy. Instead of trading the *breakout* of the Order Block (OB), the new logic will:

1.  Identify Order Blocks similarly to how `ob-allan` currently does (consolidation -> breakout -> impulse -> define OB range).
2.  Define a "Liquidity Zone" just outside the OB (below the low for Bullish OB, above the high for Bearish OB), calculated using ATR.
3.  Wait for the price (specifically, the low/high of the previous candle) to **enter this Liquidity Zone** (the "grab").
4.  Wait for the price (specifically, the close of the previous candle) to **reverse and close back *inside* the original Order Block range**.
5.  If conditions 3 & 4 are met, enter a trade **in the direction consistent with the Order Block type** (Buy at Bullish OB, Sell at Bearish OB).
6.  Use the `orderBlockMitigatedStatus` (or similar) to ensure only one trade is taken per valid setup from a single OB.

Let's integrate these changes into the `ob-allan.txt` structure.

```mql5


```

**Key Changes Implemented:**

1.  **Inputs Added:** `ATR_Period`, `ATR_Multiplier`, `stopLossBufferPips`, `takeProfitRR`.
2.  **Indicator Handle:** `atrHandle` added for ATR.
3.  **`GetATR` Function:** Added a function to retrieve ATR values reliably.
4.  **OB Identification:** The core logic for identifying consolidation, breakout, and impulse remains similar to establish the *potential* OB zone (`lastImpulseHigh`, `lastImpulseLow`).
5.  **OB Creation:** OB rectangles are drawn based on the consolidation range after a confirmed impulse. Colors and prefixes are updated.
6.  **`orderBlockMitigatedStatus` Renamed:** Changed to `orderBlockTradedStatus` to better reflect its new purpose (tracking if a trade was taken based on the SMC signal).
7.  **New Processing Function:** `ProcessOrderBlocksForSMCEntry()` added to contain the new trading logic, keeping `OnTick` cleaner.
8.  **Liquidity Zone Calculation:** Inside `ProcessOrderBlocksForSMCEntry()`, the liquidity zone (`liqTop`, `liqBottom`) is calculated for each relevant OB using the ATR value and multiplier.
9.  **SMC Entry Logic:**
    *   Checks the *previous completed bar* (index 1).
    *   For Bullish OB: Checks if `low1` pierced the `liqBottom` AND `close1` closed back above `obLow`.
    *   For Bearish OB: Checks if `high1` pierced the `liqTop` AND `close1` closed back below `obHigh`.
10. **Trade Execution:**
    *   If the SMC signal is valid and the OB hasn't been traded (`orderBlockTradedStatus[j] == false`), a market order is placed.
    *   Trade direction is now *aligned* with the OB type (Buy for Bullish, Sell for Bearish).
    *   SL is placed beyond the liquidity zone (with buffer).
    *   TP is calculated based on the SL distance and `takeProfitRR`.
    *   `orderBlockTradedStatus[j]` is set to `true`.
    *   OB visualization is updated with `tradedBullishColor` or `tradedBearishColor`.
11. **Original Mitigation Logic Removed:** The old logic in `ob-allan` that traded when price closed *beyond* the OB is completely replaced by the new SMC entry logic.
12. **Trailing Stop:** The trailing stop function remains but is now optional via `enableTrailingStop`.
13. **Minor Improvements:** Added some `Print` statements for debugging, basic SL/TP validation before placing orders, cached `Point()`, updated comments.

This revised code should now implement the SMC liquidity grab and reversal strategy as you described, using the identified Order Blocks as the core zones of interest. Remember to test thoroughly in the strategy tester and on a demo account.