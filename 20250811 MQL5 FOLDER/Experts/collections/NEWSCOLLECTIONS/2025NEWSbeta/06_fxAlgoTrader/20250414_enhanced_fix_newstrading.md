You are correct. Looking back at the "new version" code (`compare_new.txt` based on our previous steps), the specific trading logic function `CheckForNewsTrade` from the *original* code (`compare_old.txt`) was **not fully implemented** in the new structure.

We created `UpdateTradeStatusAndCountdown` and `CheckForTradeOpportunities`, which were *intended* to replace and refactor `CheckForNewsTrade`, but `CheckForTradeOpportunities` currently only handles the `TRADE_BEFORE` logic and relies heavily on the `g_filtered_news_cache`.

Let's properly reintegrate the core functionality of the *original* `CheckForNewsTrade`, adapting it to fit the new structure (like using the correct helper functions and fitting within the `OnTick`/`OnTimer` logic).

We will keep the `UpdateTradeStatusAndCountdown` for handling post-trade countdowns and the high-level structure from the new code but replace the logic within `CheckForTradeOpportunities` with a version that more closely resembles the original `CheckForNewsTrade`'s data fetching and filtering specifically for trade candidates. This ensures we aren't solely reliant on the potentially less frequently updated `g_filtered_news_cache` for immediate trade decisions.

**Steps:**

1.  **Keep `UpdateTradeStatusAndCountdown`:** This function handles the "trade already executed" state and countdowns correctly. No changes needed here.
2.  **Replace `CheckForTradeOpportunities`:** Delete the current `CheckForTradeOpportunities` function.
3.  **Copy & Adapt Original `CheckForNewsTrade`:** Copy the entire `CheckForNewsTrade` function from `compare_old.txt`. We will then modify it to:
    *   Remove the "Post-Trade Logic" section (already handled by `UpdateTradeStatusAndCountdown`).
    *   Use the correct helper functions (`createButton` instead of `createButton1`, etc., if needed for countdown display - although `UpdateOrCreateTradeCountdown` mostly handles this).
    *   Ensure it respects the *trading-specific* input parameters (`p_tradeMode`, `p_time_range_past`/`_future` for its *own* filtering, `p_tradeOffset*`, `p_tradeLotSize`).
    *   Integrate the filter flags (`enableCurrencyFilter`, `enableImportanceFilter`, `enableTimeFilter`) and selected arrays (`selected_currencies`, `selected_importances`) into its *internal* filtering logic.
    *   Change the `triggeredNewsEvents` array to use the `triggeredEventId` variable for the single-trade logic.
4.  **Rename and Call:** Rename the adapted function back to `CheckForTradeOpportunities` and ensure it's called correctly from `UpdateTradeStatusAndCountdown` when `tradeExecuted` is false.

**Resulting Code (Replacing `CheckForTradeOpportunities` and Modifying `UpdateTradeStatusAndCountdown`):**

```mql5
// --- Keep this function as is ---
//+------------------------------------------------------------------+
//| Updates trade status, countdowns, handles trade reset           |
//+------------------------------------------------------------------+
void UpdateTradeStatusAndCountdown()
{
   // Exit if trading is disabled
   if (p_tradeMode == NO_TRADE || p_tradeMode == PAUSE_TRADING) {
      DeleteTradeUI();
      return;
   }
   datetime currentTime = TimeTradeServer();
   // --- Post-Trade Logic ---
   if (tradeExecuted) {
      string countdownText = "";
      color bgColor = clrBlue; // Default countdown color
      if (currentTime < tradedNewsTime) { // Before news release
         int remainingSeconds = (int)(tradedNewsTime - currentTime);
         int hrs = remainingSeconds / 3600;
         int mins = (remainingSeconds % 3600) / 60;
         int secs = remainingSeconds % 60;
         countdownText = StringFormat("News In: %02d:%02d:%02d", hrs, mins, secs);
         bgColor = clrDarkSlateGray; // Or some neutral color for waiting
      }
      else {   // After news release
         int elapsed = (int)(currentTime - tradedNewsTime);
         if (elapsed < p_reset_delay_seconds) { // In reset window
            int remainingDelay = p_reset_delay_seconds - elapsed;
            countdownText = StringFormat("Released. Resetting in: %ds", remainingDelay);
            bgColor = CLR_RESET_BTN_BG; // Red during reset delay
         }
         else {   // Reset delay over
            Print("News time passed. Resetting trade status.");
            tradeExecuted = false;
            tradedNewsTime = 0;
            triggeredEventId = -1; // Reset triggered ID
            DeleteTradeUI();
            // Potentially trigger a check for new opportunities now?
            // CheckForTradeOpportunities(TimeTradeServer()); // Re-check immediately after reset? Optional.
            return; // Exit after reset
         }
      }
      // Update or Create Countdown UI Object
      UpdateOrCreateTradeCountdown(countdownText, bgColor);
      return; // Don't check for new trades while one is active/pending reset
   }

   // --- If not tradeExecuted, check for pre-trade opportunities ---
   CheckForTradeOpportunities(currentTime); // <<< This call remains
}


// *** DELETE the previous version of CheckForTradeOpportunities ***

// *** ADD THE ADAPTED VERSION BELOW ***

//+------------------------------------------------------------------+
//| Checks for news events meeting trade criteria                     |
//| (Adapted from original CheckForNewsTrade from compare_old.txt)   |
//+------------------------------------------------------------------+
void CheckForTradeOpportunities(datetime currentTime) {
   // This function now performs its own data fetch and filtering specifically for trading,
   // similar to the original CheckForNewsTrade, respecting the *trade* timeframe inputs.
   // It is NOT reliant on g_filtered_news_cache from the dashboard refresh cycle.

   // Constants for this check - could use separate inputs if needed
   ENUM_TIMEFRAMES trade_check_past = p_time_range_past;     // How far back to look for events relevant to trading decisions
   ENUM_TIMEFRAMES trade_check_future = p_time_range_future; // How far forward to look

   //--- Define the time bounds for fetching potential trade events ---
   // Using the EA's main timeframe inputs p_time_range_past/future for this specific check
   datetime lowerBound = currentTime - PeriodSeconds(trade_check_past);
   datetime upperBound = currentTime + PeriodSeconds(trade_check_future);

   //--- Retrieve calendar values for the trade check window ---
   MqlCalendarValue trade_values[];
   int totalTradeValues = CalendarValueHistory(trade_values, lowerBound, upperBound, NULL, NULL);

   if (totalTradeValues < 0) {
        Print(__FUNCTION__, ": Error fetching calendar history for trading check: ", GetLastError());
        DeleteTradeUI(); // Remove countdown if data fails
        return;
   }
   // Optional: Log event range checked for trading
   // Print("CheckForTradeOpportunities: Checking events from ", TimeToString(lowerBound, TIME_SECONDS), " to ", TimeToString(upperBound, TIME_SECONDS), ". Found: ", totalTradeValues);


   // --- Initialize candidate event variables for trade selection ---
   datetime candidateEventTime = 0;
   string candidateEventName = "";
   string candidateTradeSide = "";
   long candidateEventID = -1; // Use long for event_id matching

   int offsetSeconds = p_tradeOffsetHours * 3600 + p_tradeOffsetMinutes * 60 + p_tradeOffsetSeconds;

   // --- Loop through retrieved events to evaluate trade candidates ---
   for(int i = 0; i < totalTradeValues; i++) {
      MqlCalendarEvent event;
      if(!CalendarEventById(trade_values[i].event_id, event)) continue; // Skip if cannot get event info

      MqlCalendarValue value_details; // Needed for forecast/previous
      if (!CalendarValueById(trade_values[i].id, value_details)) continue; // Skip if cannot get value details


      // --- Apply Dashboard Filter Settings to Trade Candidate Selection ---
      // Currency Filter
      if (enableCurrencyFilter) {
         MqlCalendarCountry country;
         if(!CalendarCountryById(event.country_id, country)) continue; // Skip if error getting country
         bool currencyMatch = false;
         for (int k = 0; k < ArraySize(selected_currencies); k++) {
            if (country.currency == selected_currencies[k]) {
               currencyMatch = true;
               break;
            }
         }
         if (!currencyMatch) continue; // Skip if currency filter doesn't match
      }

      // Importance Filter
      if (enableImportanceFilter) {
         bool impactMatch = false;
         for (int k = 0; k < ArraySize(selected_importances); k++) {
            if (event.importance == selected_importances[k]) {
               impactMatch = true;
               break;
            }
         }
         if (!impactMatch) continue; // Skip if importance filter doesn't match
      }

      // Time Filter (Using trade check window 'upperBound' potentially)
      // Note: The primary time check for trading is whether currentTime is within the offset window.
      // Applying enableTimeFilter here might be redundant or conflicting if p_display_time_window is different.
      // Let's keep it commented unless specifically needed for trade logic independent of dashboard display window.
      /*
      if (enableTimeFilter && trade_values[i].time > upperBound) { // Using the trade fetch upper bound
          Print("CheckForTradeOpportunities: Event ", event.name, " skipped due to trade time filter boundary.");
          continue;
      }
      */

      //--- Check if this event was the one just traded (redundant due to tradeExecuted check, but safe) ---
      // Already handled because this function is only called if tradeExecuted is false


      // --- Evaluate based on TRADE_BEFORE mode ---
      if(p_tradeMode == TRADE_BEFORE) {
         datetime eventTime = trade_values[i].time;
         datetime tradeStartTime = eventTime - offsetSeconds;

         // Is current time within the trade window *before* the event?
         if(currentTime >= tradeStartTime && currentTime < eventTime) {
             // Get Forecast vs Previous for decision (using value_details already fetched)
             double forecast = value_details.GetForecastValue();
             double previous = value_details.GetPreviousValue();

             // Check if values are valid for comparison
             if(forecast == value_details.EMPTY_VALUE || previous == value_details.EMPTY_VALUE || forecast == previous) {
                // Print("Skipping trade check for event ", event.name, " - F/P Empty or Equal.");
                continue;
             }

             // Determine trade side
             string side = (forecast > previous) ? "BUY" : "SELL";

             // Select the *earliest* upcoming valid candidate IN the trade window
             if(candidateEventTime == 0 || eventTime < candidateEventTime) {
                candidateEventTime = eventTime;
                candidateEventName = event.name;
                candidateEventID = event.id; // Or use event_id? MqlCalendarEvent.id seems correct
                candidateTradeSide = side;
                // Print("Trade Candidate Found: ", candidateEventName, " Time: ", TimeToString(eventTime, TIME_SECONDS), " Side: ", side);
             }
         }
         // --- Check if event is upcoming (for pre-trade countdown) ---
         else if (currentTime < tradeStartTime && eventTime > currentTime) {
             // If no candidate is yet in the trade window, show countdown for the soonest *potential* one
             if (candidateEventTime == 0 || eventTime < candidateEventTime) { // Is this the earliest *potential* trade?
                  int remainingSeconds = (int)(tradeStartTime - currentTime); // Time until trade window opens
                  if (remainingSeconds > 0 && remainingSeconds < 4 * 3600) { // Limit countdown display (e.g., < 4 hrs)
                      int hrs = remainingSeconds / 3600;
                      int mins = (remainingSeconds % 3600) / 60;
                      int secs = remainingSeconds % 60;
                      string countdownText = StringFormat("Trade Window In: %02d:%02d:%02d", hrs, mins, secs);
                      UpdateOrCreateTradeCountdown(countdownText, clrSteelBlue); // Use specific color for this state
                  } else {
                      // Potential candidate is too far out, ensure no countdown shows if it wasn't already set by post-trade logic
                      // (Avoid deleting countdown if post-trade is active)
                      if (!tradeExecuted) { // Only delete if not in post-trade countdown
                          DeleteTradeUI();
                      }
                  }
             }
         } // End countdown check
      } // End TRADE_BEFORE check

       // --- Add logic for TRADE_AFTER mode here if required ---
       // else if (p_tradeMode == TRADE_AFTER) {
       //    // Logic: Check if currentTime is AFTER eventTime + offset
       //    // Compare Actual vs Forecast (or Previous?) based on your strategy
       // }

   } // End loop through trade_values


   // --- Execute Trade If Candidate Found (for TRADE_BEFORE) ---
   if (p_tradeMode == TRADE_BEFORE && candidateEventID != -1 && candidateEventTime != 0) {

       // Re-check timing to be precise for execution attempt
       datetime tradeStartTime = candidateEventTime - offsetSeconds;
       if (currentTime >= tradeStartTime && currentTime < candidateEventTime) {

          // Re-check tradeExecuted flag just before execution attempt (safety)
          if (!tradeExecuted) {
              Print("Attempting ", candidateTradeSide, " trade for event: ", candidateEventName, " (ID: ", candidateEventID, ") at ", TimeToString(currentTime));

              // Create News Trade Info Label (from original createLabel1 - adapted)
              // Note: Requires TRADE_INFO_LABEL to be defined
              string newsInfo = "Trading: " + candidateEventName + " ("+TimeToString(candidateEventTime, TIME_MINUTES)+")";
               // Using the newer createLabel helper
               createLabel(TRADE_INFO_LABEL, 385, 10, newsInfo, clrCornflowerBlue, 9, FONT_LABEL); // Position next to panel?


              // --- Place Trade ---
              bool tradeResult = false;
              if (candidateTradeSide == "BUY") {
                 tradeResult = trade.Buy(p_tradeLotSize, _Symbol, 0, 0, 0, "News Buy " + candidateEventName);
              } else if (candidateTradeSide == "SELL") {
                 tradeResult = trade.Sell(p_tradeLotSize, _Symbol, 0, 0, 0, "News Sell " + candidateEventName);
              }

              if (tradeResult) {
                 Print("Trade successful. Ticket: ", trade.ResultDeal());
                 tradeExecuted = true;
                 tradedNewsTime = candidateEventTime; // Record time of the *event*, not the trade time
                 triggeredEventId = candidateEventID; // Store ID of traded event
                 DeleteTradeUI(); // Remove any "Trade Window In" countdown
                 UpdateTradeStatusAndCountdown(); // Start the post-trade countdown immediately
                 ObjectDelete(0, TRADE_INFO_LABEL); // Remove info label after execution attempt
              } else {
                 Print("Trade FAILED! Error: ", trade.ResultRetcode(), " - ", trade.ResultComment());
                  ObjectDelete(0, TRADE_INFO_LABEL); // Remove info label after execution attempt
                 // Consider what to do on failure - retry? block event?
              }
          } // end !tradeExecuted check
       } // end check currentTime in trade window NOW

   } else {
      // If no candidate was identified *AND* we are not in post-trade mode, ensure no stale countdown exists
      // (Unless it's the 'Trade Window In' countdown set above)
       if (!tradeExecuted) { // Only clear UI if not in post-trade phase
           bool countdownExists = (ObjectFind(0, TRADE_COUNTDOWN) >= 0);
            string currentText = countdownExists ? ObjectGetString(0, TRADE_COUNTDOWN, OBJPROP_TEXT) : "";
           // If countdown exists but it's NOT the "Trade Window In" type, remove it.
            if (countdownExists && StringFind(currentText, "Trade Window In:") < 0) {
               DeleteTradeUI();
           } else if (!countdownExists) {
                // If no candidate AND no countdown exists at all, ensure related labels are gone too.
                DeleteTradeUI();
           }
           // If no candidate, but 'Trade Window In' countdown exists, leave it.
            ObjectDelete(0, TRADE_INFO_LABEL); // Always remove trade info label if no trade executed this tick
       }
   }
}

// --- Keep other functions like UpdateOrCreateTradeCountdown, DeleteTradeUI, GetEventName ---
//+------------------------------------------------------------------+
//| Update or Create the Trade Countdown UI                          |
//+------------------------------------------------------------------+
void UpdateOrCreateTradeCountdown(string text, color bgColor)
{
   int x = 30, y = 10; // Position top-left, adjust as needed
   int w = 240, h = 20; // Size
   if (ObjectFind(0, TRADE_COUNTDOWN) < 0) {
      // Create button style label - Use the refined createButton
      createButton(TRADE_COUNTDOWN, x, y, w, h, text, clrWhiteSmoke, 9, bgColor, CLR_BORDER, FONT_LABEL, false, false); // Not selectable
      ChartRedraw(0); // Draw it now
   }
   else {
      ObjectSetString(0, TRADE_COUNTDOWN, OBJPROP_TEXT, text);
      ObjectSetInteger(0, TRADE_COUNTDOWN, OBJPROP_BGCOLOR, bgColor);
      // Minimal redraw from OnTick
   }
}
// ... (DeleteTradeUI, GetEventName, etc.)
```

**Key Changes in this Reintegration:**

1.  **`CheckForTradeOpportunities` Source:** The function now directly uses `CalendarValueHistory` with the *trade-specific* time ranges (`trade_check_past`/`_future`), mimicking the original `CheckForNewsTrade`.
2.  **Filtering:** It incorporates the dashboard's filter flags (`enableCurrencyFilter`, etc.) and selected arrays (`selected_currencies`, etc.) directly into its candidate evaluation loop.
3.  **Candidate Logic:** It replicates the original logic for finding the *earliest* event that satisfies the `TRADE_BEFORE` condition (time within offset, valid forecast/previous, filters passed).
4.  **Countdown:** It retains the logic to show the "Trade Window In:" countdown for the next *potential* trade, but only if no trade is currently executing or pending reset.
5.  **Trade Execution:** The execution block is similar to the original, attempting the Buy/Sell based on Forecast > Previous. It now uses `triggeredEventId` instead of the `triggeredNewsEvents` array. It also creates/deletes the `TRADE_INFO_LABEL` around the execution attempt.
6.  **Dependencies:** It no longer depends on `g_filtered_news_cache` for its core decision-making, making trade timing more independent of the potentially slower dashboard refresh cycle.
7.  **Clean Up:** It ensures that countdowns/labels are cleaned up correctly if no trade candidate is found or if trading is inactive.

**Integration:**

*   Replace the *entire* `CheckForTradeOpportunities` function in your latest code with this new version.
*   Make sure the call to `CheckForTradeOpportunities(currentTime)` remains inside `UpdateTradeStatusAndCountdown` within the `if (!tradeExecuted)` block.
*   Double-check that all necessary global variables (`p_*` inputs, filter flags, `selected_*` arrays, `tradeExecuted`, `tradedNewsTime`, `triggeredEventId`) are accessible.
*   Ensure the helper functions (`CalendarEventById`, `CalendarValueById`, `CalendarCountryById`, `GetImpactColor`, `ArrayGetIndexOfString`, `ArrayGetIndexOfEnum`, `GetEventName`, `UpdateOrCreateTradeCountdown`, `DeleteTradeUI`) are correctly defined and available.

Compile and test this version thoroughly, especially the trade triggering and countdown behaviour in relation to filter settings.