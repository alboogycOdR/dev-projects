```mql5

```

**Explanation and Important Considerations:**

1.  **Completeness:** This code provides a *functional structure* and implements the core logic described in the framework. All listed helper functions are created with their intended logic.
2.  **`OnTimer()` vs `OnTick()`:** `OnTimer()` is used for efficiency, checking conditions every 60 seconds. For highly time-sensitive range definition or entry right at the M5 close, `OnTick` *might* be slightly more precise but is much more CPU intensive. `OnTimer` at 60s should be sufficient for this strategy.
3.  **Broker Server Time:** **CRITICAL:** All time inputs (`iRangeStartTime`, `iTradeStartTime`, etc.) and checks (`TimeCurrent()`) use the **broker's server time**. You *must* know your broker's server time zone (e.g., GMT+2, GMT+3) and adjust the input times accordingly to match the NY session (e.g., 9:30 EST might be 16:30 Server Time if GMT+2). The `StringToTimeOfDay` helper correctly converts the HH:MM input to a `datetime` for *today's* date using the server's clock.
4.  **Range Definition Precision:** The code uses M1 bars to find the absolute high/low within the specified *time* window (e.g., 09:30:00 to 09:44:59 for a 15-min range ending 09:45). This is more accurate than just taking the high/low of the M15 candle itself.
5.  **M15 Anchor Candle:** The High and Low of the *specific M15 candle* that finishes at the `RangeEndTime` are stored separately (`g_rangeM15CandleHigh`, `g_rangeM15CandleLow`). This is crucial for the Playbit SL/TP method which anchors to *that specific candle*.
6.  **M5 Candle Close Entry:** `CheckEntrySignals` explicitly looks at the close of the *last completed* M5 candle (`iClose(..., 1)`).
7.  **Stop Loss Calculation:** Implements both methods. The 50% range SL uses the *M15 anchor candle* midpoint. The ATR% SL uses the calculated Daily ATR and applies the offset from the *breakout level* (Range High/Low) as a practical way to set it before entry is known precisely. Minor adjustments are included to prevent SLs being *exactly* at the current market price which could cause immediate stop-outs on OrderSend.
8.  **Take Profit Calculation (Fib StdDev):** This is the most complex part involving MQL5 objects.
    *   A temporary Fibonacci Retracement object is created.
    *   It's anchored to the High/Low of the `g_rangeM15Candle`.
    *   Custom levels representing the Standard Deviations are applied.
    *   `ObjectGetValueByLevel` attempts to retrieve the price corresponding to the user's `iStandardDeviationTPLevel`.
    *   The object is deleted immediately after use.
    *   **Important:** This requires the underlying `OBJ_FIBO` functionality in MT5 to reliably map levels to prices. Thorough testing is needed. Small inaccuracies in anchoring or level interpretation could occur.
    *   It correctly anchors Low-to-High for buys (negative levels are profit targets) and High-to-Low for sells.
    *   It validates the TP to ensure it's on the correct side of the market before sending the order.
9.  **Lot Size Calculation:** Includes logic for both fixed lots and risk %. The risk % calculation determines the loss per point for 1 lot and adjusts the volume based on the SL distance and desired risk. It uses `_Point` for point size and handles normalization and min/max lots. **Crucially, the `value_per_point_one_lot` calculation needs testing on your specific symbol and broker**, as `TRADE_CALC_MODE` handling can vary. The provided code attempts common scenarios.
10. **Trade Management:** Basic EoD closing is implemented. Trailing stops are commented out but could be added within `ManageOpenTrade`.
11. **`OnTradeTransaction`:** Commented out but shows how you could add more sophisticated handling of SL/TP events if needed (like differentiating EA close from SL/TP hit).
12. **Filters:** The optional SFI filters are included but need ATR recalculation if not done for SL. The complex RelVol/Top20 SFI logic is *not* implemented as it goes beyond the scope of a single-symbol EA.
13. **Error Handling:** Includes basic checks and `Print` statements for debugging. More robust error handling (retries, global error states) could be added for production.
14. **Prefix:** Using `OBJ_PREFIX` ensures objects created by different instances or copies of the EA don't clash.

**How to Use:**

1.  Copy the code into MetaEditor.
2.  Compile it (F7). Fix any syntax errors.
3.  Attach the compiled EA (.ex5 file) to the chart of the symbol you want to trade (e.g., NQ futures contract, GER40 CFD, XAUUSD).
4.  **CRITICAL:** Adjust the `input` time parameters (`iRangeStartTime`, etc.) based on your **Broker's Server Time** relative to the desired NY session times (9:30, 9:45, 11:55, 11:59, 15:59 EST).
5.  Configure other parameters (Range Duration, SL/TP Method, Lot Size, Risk).
6.  Enable "Algo Trading" in your MT5 terminal.
7.  Backtest thoroughly before live trading! Pay close attention to the Journal tab during backtesting and live operation for error messages and logic flow confirmation. Test the Lot Size calculation especially.

This code provides a strong starting point for the requested "Optimized ORB EA", leaning heavily on the refined rules presented in the Playbit/Ty materials.