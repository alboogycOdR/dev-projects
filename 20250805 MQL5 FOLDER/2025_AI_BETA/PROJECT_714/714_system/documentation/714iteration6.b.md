Excellent! This is a key refinement to make the EA behave more like the "Remix" or AOI-based approach demonstrated by the speaker in the source videos. The current strict entry *only* on the 15th M5 candle after the key time is indeed quite rigid.

Here's how we can introduce more dynamic entry timing flexibility, aligning with the source videos where the speaker looks for interaction with an Area of Interest (AOI) at *any point* after the contrarian bias is established:

**Conceptual Changes for Dynamic Entry Timing:**

1.  **Decouple Entry from the 15th Candle:** The primary change is that we will no longer *only* check for entry conditions on the `g_EntryTiming_Server` (15th candle bar).
2.  **Continuous AOI Monitoring:** Once `g_InitialBias` is determined for the day (after the observation window), the EA will, on *every new M5 bar*, check if the current price is interacting with any relevant, unmitigated Order Blocks (or other AOIs you might add later).
3.  **Entry Triggered by AOI Interaction + Confirmation:** If price interacts with a valid AOI and the price action confirmation rules are met *on that bar*, a trade can be considered.
4.  **Time Window for Entries (Optional but Recommended):**
    *   While we want flexibility, we probably don't want the EA to look for entries indefinitely throughout the entire trading day after the bias is set. The source videos usually focus on a specific period for these setups (e.g., London session, early NY session).
    *   We can introduce new input parameters to define an "Entry Search Window End Time." For example, entries based on the 1 PM SAST bias might only be considered valid for the next, say, 3-4 hours.
    *   This prevents the EA from taking late signals that might no longer be relevant to the initial 1 PM context.
5.  **Preventing Multiple Trades on Same Signal/Bar:** We need to ensure that if a valid setup occurs and a trade is taken (or attempted), the EA doesn't immediately try to take another trade on the same signal or the very next bar if conditions still *technically* meet the criteria. The `g_trade_signal_this_bar` flag will be helpful, but we might need a broader "trade taken today for this bias" flag if we only want one attempt per daily bias signal. For now, we'll stick to `g_trade_signal_this_bar` to prevent immediate re-entry.

**MQL5 Code Implementation Steps & Modifications:**

Let's modify the EA.

**1. New Input Parameters for Entry Window (Optional but Recommended):**

Add these to your input parameter section, perhaps within `=== Observation and Entry Settings ===`:

```mql5
//--- Entry Search Window Settings (Optional) ---
input group "=== Dynamic Entry Window Settings ==="
input bool     use_entry_search_window   = true;   // Enable to limit entry search to a specific window
input int      entry_search_end_hour_utc2= 17;     // Hour (UTC+2) to stop searching for new entries (e.g., 17 for 5 PM UTC+2)
input int      entry_search_end_minute_utc2= 0;      // Minute to stop searching for new entries
```

**2. New Global Variable for Entry Search End Time:**

```mql5
//--- Global Variables ---
// ... (existing global variables) ...
datetime   g_EntrySearchEndTime_Server; // Server time to stop searching for new entries for the day
// ... (rest of existing global variables) ...
```

**3. Modify `CalculateAndDrawDailyTimings()`:**

We need to calculate `g_EntrySearchEndTime_Server` here if `use_entry_search_window` is true.

```mql5
// ... (inside CalculateAndDrawDailyTimings, after g_ObservationEndTime_Server is calculated) ...

   //--- Calculate the specific 15th candlestick entry time in server time (Still keep this for reference/potential alternate mode)---
   // ... (existing g_EntryTiming_Server calculation logic) ...

   //--- Calculate Entry Search End Time (if enabled) ---
   if(use_entry_search_window)
   {
      datetime server_midnight = iTime(Symbol(), PERIOD_D1, 0);
      if(server_midnight > 0)
      {
         int target_end_hour_gmt = entry_search_end_hour_utc2 - 2; // Assuming UTC+2 is always GMT+2
         int target_end_server_hour = target_end_hour_gmt + server_GMT_Offset_Manual;
         target_end_server_hour = target_end_server_hour % 24;
         if(target_end_server_hour < 0) target_end_server_hour += 24;
         g_EntrySearchEndTime_Server = (datetime)(server_midnight + (long)target_end_server_hour * 3600L + (long)entry_search_end_minute_utc2 * 60L);
         Print(visual_comment_text + " - Dynamic Entry Search Window End (Server Time): ", TimeToString(g_EntrySearchEndTime_Server, TIME_DATE|TIME_MINUTES));
      }
      else
      {
         g_EntrySearchEndTime_Server = 0; // Could not calculate
         Print(visual_comment_text + " - Warning: Could not calculate Dynamic Entry Search End Time.");
      }
   }
   else
   {
      g_EntrySearchEndTime_Server = 0; // Not used
   }

// ... (rest of the function, including g_last_initialized_day_time update etc.) ...
```

**4. Modify `OnTimer()` - Main Logic Change:**

The section checking for entry at the 15th candle needs to be replaced or augmented.

```mql5
void OnTimer()
{
   // --- Check for New Day and Re-initialize Timings if needed ---
   IsNewDayCheckAndReset();
   // --- Process logic only on a NEW M5 closed bar ---
   int total_bars = Bars(Symbol(), Period());
   if (total_bars <= 1) return;
   int closed_bar_index = total_bars - 1; // Index of the most recently closed bar (current is 0)
                                          // In OnTimer, we usually process bar index 1 (the most recently completed bar)
                                          // Let's use index 1 consistently for closed bar data.
   if (closed_bar_index == 0) return; // Not enough history yet, or chart hasn't formed a new bar for index 1
   
   datetime current_completed_bar_time = iTime(Symbol(), Period(), 1); // Time of the *last fully completed bar*

   if (current_completed_bar_time <= g_last_processed_bar_time_OnTimer) // Use a dedicated time tracker for OnTimer's last bar
   { // No new bar has closed since last OnTimer check on the closed bar
      return;
   }
   g_last_processed_bar_time_OnTimer = current_completed_bar_time; // Update time of last processed completed bar
   int current_completed_bar_chart_idx = 1; // We are always analyzing bar at index 1 in OnTimer as "current closed bar"

   Print("Processing New Closed Bar at Server Time: ", TimeToString(current_completed_bar_time, TIME_DATE|TIME_MINUTES), " (Chart Index: 1)");

   // --- Obtain Key Price and Draw Observation Price Line (No change here) ---
   if (visual_enabled && visual_obs_price_line && !g_key_price_obtained_today && current_completed_bar_time >= g_TodayKeyTime_Server) 
   {
       // ... (existing key price and obs line drawing logic for the Key Time bar - may need adjustment to use index 1 consistently if this runs before key time bar truly forms based on current_completed_bar_time)
       // For simplicity now, this logic relies on current_completed_bar_time passing the KEY TIME, 
       // and then iBarShift to find the actual key time bar if it's in the past.
      int key_time_actual_bar_idx_on_chart = iBarShift(Symbol(), Period(), g_TodayKeyTime_Server, false); 
      if (key_time_actual_bar_idx_on_chart >=0 && key_time_actual_bar_idx_on_chart < Bars(Symbol(), Period())) {
         g_KeyPrice_At_KeyTime = iOpen(Symbol(), Period(), key_time_actual_bar_idx_on_chart);
         if (g_KeyPrice_At_KeyTime > 0) {
            // ... (rest of existing obs price line drawing code) ...
            Print(visual_comment_text + " - Observation Price Trend line drawn from ", TimeToString(g_TodayKeyTime_Server, TIME_DATE|TIME_MINUTES), " to ", TimeToString(g_ObservationEndTime_Server, TIME_DATE|TIME_MINUTES) , " at price ", DoubleToString(g_KeyPrice_At_KeyTime, Digits()));
         } else { /* ... */ }
         g_key_price_obtained_today = true;
      } else { /* ... */ }
   }

   //--- Determine Bias (No change here) ---
   if (!g_bias_determined_today && current_completed_bar_time >= g_ObservationEndTime_Server) {
      // ... (existing bias determination logic, it correctly uses iBarShift to find key_bar_idx and obs_end_bar_idx based on server times) ...
      // It's crucial that OB detection runs *after* bias is determined, using appropriate bar indices for its scan.
   }

   //--- DYNAMIC ENTRY LOGIC: Check for entry conditions on *every new bar* after bias is set AND within the entry search window ---
   g_trade_signal_this_bar = false; // Reset for current bar check

   if (g_bias_determined_today && g_InitialBias != 0 && !PositionsTotal() > 0 ) // Ensure bias is set, not neutral, and no existing position FOR THIS EA's MAGIC NUMBER (add magic num check in PositionsTotal() loop if used)
   {
       // Check if we are within the allowed entry search window (if enabled)
       bool within_entry_search_window = true;
       if(use_entry_search_window && g_EntrySearchEndTime_Server > 0)
       {
           if(current_completed_bar_time > g_EntrySearchEndTime_Server)
           {
               within_entry_search_window = false;
               if(!g_entry_timed_window_alerted) { // Use this flag to print message once per day after window closes
                   Print(visual_comment_text + " - Dynamic Entry Search Window has ended for today at ", TimeToString(g_EntrySearchEndTime_Server, TIME_DATE|TIME_MINUTES) , ". No new entries will be sought.");
                   g_entry_timed_window_alerted = true; // Re-purpose flag or use a new one for end of search window
               }
           }
       }

       if(within_entry_search_window)
       {
           Print(visual_comment_text + " - Searching for dynamic entry. Current completed bar time: ", TimeToString(current_completed_bar_time, TIME_DATE|TIME_MINUTES));
           bool entry_conditions_met = false;
           if (g_InitialBias == -1) { // Looking for BUYS
               entry_conditions_met = YourBuyEntryConditionsMet(current_completed_bar_chart_idx); // Pass the current completed bar's index (1)
               if (entry_conditions_met && g_trade_signal_this_bar) { // g_trade_signal_this_bar is set true inside Your...Met
                   Print(visual_comment_text + " - Dynamic Buy Entry conditions met by OB @ ", TimeToString(g_triggered_ob_for_trade.startTime, TIME_DATE|TIME_MINUTES));
                   PlaceBuyOrder(risk_Percent_Placeholder, stop_Loss_Buffer_Pips, take_Profit_Pips_Placeholder, current_completed_bar_chart_idx, g_triggered_ob_for_trade);
                   // Consider a flag here to prevent re-entry attempts for X bars if a trade was just placed/attempted
               }
           }
           else if (g_InitialBias == 1) { // Looking for SELLS
               entry_conditions_met = YourSellEntryConditionsMet(current_completed_bar_chart_idx); // Pass current completed bar's index (1)
               if (entry_conditions_met && g_trade_signal_this_bar) {
                   Print(visual_comment_text + " - Dynamic Sell Entry conditions met by OB @ ", TimeToString(g_triggered_ob_for_trade.startTime, TIME_DATE|TIME_MINUTES));
                   PlaceSellOrder(risk_Percent_Placeholder, stop_Loss_Buffer_Pips, take_Profit_Pips_Placeholder, current_completed_bar_chart_idx, g_triggered_ob_for_trade);
                   // Consider a flag here
               }
           }
           if(entry_conditions_met && g_trade_signal_this_bar){
              // A trade was attempted/logged by PlaceOrder functions.
              // Optional: you might set a flag here like `g_trade_attempted_today = true;`
              // if you only want one trade signal per day from this bias.
           }
       }
   }
   
   // --- Update OB Mitigation (No change here, but ensure it uses current_completed_bar_chart_idx if checking against 'current' bar data, currently uses index 1 directly) ---
   UpdateMitigationStatus(current_completed_bar_chart_idx); // Or keep as current_closed_bar_index which is 'total_bars - 1' - consistency needed
                                                           // The UpdateMitigationStatus uses index 1 directly (iHigh(...,1)) so it's consistent with current completed bar

   // --- Manage Trades (No change here) ---
   ManageTrades();
}
```
**Add this new global variable for OnTimer logic:**
```mql5
datetime   g_last_processed_bar_time_OnTimer = 0; // To track the last bar processed in OnTimer
```
**Explanation of Changes for Dynamic Entry:**

1.  **`use_entry_search_window`, `entry_search_end_hour_utc2`, `entry_search_end_minute_utc2` (Inputs):** These allow you to define a window *after the bias is established* during which the EA will actively look for entries. For example, if bias is set around 2 PM SAST, you might only want to look for entries until 5 PM SAST.
2.  **`g_EntrySearchEndTime_Server` (Global):** Stores the calculated server time for when the entry search should stop.
3.  **`CalculateAndDrawDailyTimings()` Modified:** This function now calculates `g_EntrySearchEndTime_Server` based on your inputs.
4.  **`OnTimer()` Logic Shift:**
    *   The previous `if (current_closed_bar_time == g_EntryTiming_Server)` block (which checked only the 15th candle) is **replaced/augmented**.
    *   Now, *after* `g_bias_determined_today` is true and `g_InitialBias` is not neutral:
        *   It checks if `current_completed_bar_time` is still within the `g_EntrySearchEndTime_Server` (if `use_entry_search_window` is true).
        *   If within the window (or if the window isn't used), it calls `YourBuyEntryConditionsMet(1)` or `YourSellEntryConditionsMet(1)` on **every new completed M5 bar (index 1)**.
        *   `g_trade_signal_this_bar` (which is set inside `Your...Met` functions) is checked. If true, it calls the respective `Place...Order` function.
    *   **Consistency for bar index in `OnTimer()`**: It's generally safer in `OnTimer()` to work with fixed completed bar indices like `1` (most recent closed), `2` (second most recent closed), etc., rather than `total_bars - 1` which can shift during historical data loading in the Strategy Tester. I've adjusted `current_completed_bar_chart_idx` to `1` for checks that happen on *every new bar*.
        *   The `g_last_processed_bar_time_OnTimer` ensures that the logic for dynamic entries runs only once per new completed bar.
5.  **`YourBuyEntryConditionsMet` & `YourSellEntryConditionsMet`:**
    *   These functions still check for OB interaction and PA confirmation.
    *   They now take `closed_bar_index` which will be `1` (the most recent completed bar) when called dynamically from `OnTimer`.
    *   The `g_trade_signal_this_bar` flag is set to `true` within these functions if conditions are met, signaling `OnTimer` to proceed with order placement.
6.  **`g_entry_timed_window_alerted` Re-purposed (or use a new flag):** This flag is now used to print a "search window ended" message once per day if `use_entry_search_window` is true.

**Further Considerations for Dynamic Entries:**

*   **Trade Frequency:** Dynamic checking on every bar can lead to more signals. Ensure your OB detection, PA confirmation, and any other confluence rules (FVG, HTF bias) are robust enough to filter for high-quality setups.
*   **Max Trades Per Day/Signal:** If you only want the EA to take *one* trade attempt per daily 714 bias, you'll need an additional global flag (e.g., `g_trade_attempted_today_for_bias`). Set this to `true` after a trade is placed/attempted and reset it in `IsNewDayCheckAndReset`. In `OnTimer()`, check this flag before calling `Your...EntryConditionsMet`.
*   **What Defines an "Active AOI"?:** The `Your...EntryConditionsMet` functions iterate through *all* unmitigated OBs found earlier in the day. For dynamic entries, you might want to refine this to only consider OBs that are "fresh" or in close proximity to the current price, or perhaps only the nearest N valid OBs.
*   **"Looking Left for AOI":** The speaker's visual demonstration often involves manually identifying strong S/R by "looking left." Your current `DetectOrderBlocksForToday` automates finding OBs. If you want to incorporate broader S/R, you'd need an algorithm for that (e.g., using Fractals to identify swing points and draw zones, or a Pivot Point indicator, etc.). For now, it will dynamically check against the detected Order Blocks.

**Testing this Change:**

*   When backtesting, enable `use_entry_search_window` and set `entry_search_end_hour_utc2`.
*   Observe in visual mode. After `g_ObservationEndTime_Server`, the EA should print logs showing it's "Searching for dynamic entry..." on new bars.
*   Watch if entries are (hypothetically) triggered when price interacts with one of your drawn (and stored) OBs during this search window, assuming your (yet-to-be-fully-implemented) `YourPriceActionConfirmation` would be true.

This change makes the EA significantly more aligned with the flexible AOI-based entry approach seen in the videos. Remember to implement and test the actual trade entry conditions within `YourBuyEntryConditionsMet` and `YourSellEntryConditionsMet` with strong PA confirmation.