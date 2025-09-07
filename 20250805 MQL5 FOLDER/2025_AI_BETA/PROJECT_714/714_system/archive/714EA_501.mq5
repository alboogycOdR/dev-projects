//+------------------------------------------------------------------+
//|                                             SevenOneFourEA_V5.01.mq5
//|                                                Developed by [Your Name/Handle]
//|                                                Based on The 714 Trading Method by Mashaya
//+------------------------------------------------------------------+
#property version "5.01" // Updated version
#property description "2024.05.06" // Date of this version
#property copyright "[Your Name/Handle]"
#property link    ""
#property strict

//--- Include necessary libraries (required for later versions, good practice now)
#include <Trade/Trade.mqh>       // For sending/managing orders (structure included)
#include <Object.mqh>   // For managing chart objects (visuals)
#include <Indicators/Indicators.mqh> // Potentially for future indicator-based confluence

//+------------------------------------------------------------------+
//| Input Parameters - Core Strategy Settings                         |
//+------------------------------------------------------------------+
//--- Primary Key Time Settings (UTC+2 / SAST) ---
input group "=== Primary Key Time Settings (UTC+2) ==="
input int      utcPlus2_KeyHour_1300     = 11;     // Key Hour (13:00 UTC+2 = 14:00 SAST)
input int      utcPlus2_KeyMinute_1300   = 0;      // Key Minute (0 = 13:00:00 UTC+2)

//--- Observation and Entry Settings ---
input group "=== Observation and Entry Settings ==="
input int      observation_Duration_Minutes = 60;   // Minutes to observe price action after Key Time
input int      entry_Candlestick_Index   = 15;     // M5 candle index for entry (15 = 75 mins after Key Time)

//--- Server Time Settings ---
input group "=== Server Time Settings ==="
input int      server_GMT_Offset_Manual  = 2;      // Server's GMT offset (Check Market Watch > Right-click Time)
//--- Session End Settings ---
input group "=== Session End Settings ==="
input int      session_End_UTC2_Hour     = 22;     // Session end hour UTC+2 (22 = 10:00 PM)
input int      session_End_UTC2_Minute   = 0;      // Session end minute UTC+2

//+------------------------------------------------------------------+
//| Input Parameters - Order Block Detection                          |
//+------------------------------------------------------------------+
input group "=== Order Block Detection Settings ==="
input int      ob_Lookback_Bars_For_Impulse = 50;  // Max bars to check for impulsive move after OB
input double   ob_MinMovePips             = 10;    // Min price move (pips) to confirm OB
input int      ob_MaxBlockCandles         = 3;     // Max candles to form OB body (initial + follow-up)
input bool     scan_before_obs_end_only   = true;  // Only detect OBs formed before observation end

//+------------------------------------------------------------------+
//| Input Parameters - Visual Settings                                |
//+------------------------------------------------------------------+
input group "=== Visual Display Settings ==="
input bool     visual_enabled            = true;    // Master switch for all visuals
input bool     visual_main_timing_lines  = true;    // Show Key Time & Observation End lines
input bool     visual_order_blocks       = true;    // Show detected Order Blocks
input bool     visual_obs_price_line     = true;    // Show price level during observation

//--- Visual Colors ---
input group "=== Visual Colors ==="
input color    vline_keytime_color       = clrSteelBlue;    // Key Time vertical line color
input color    vline_obsend_color        = clrSalmon;       // Observation End line color
input color    ob_bullish_color          = clrLimeGreen;    // Bullish Order Block color
input color    ob_bearish_color          = clrRed;          // Bearish Order Block color
input color    ob_mitigated_color        = clrGray;         // Mitigated Order Block color
input color    ob_label_color            = clrBlack;        // Order Block label color
input color    obs_price_line_color      = clrDarkGray;     // Observation price line color

//+------------------------------------------------------------------+
//| Input Parameters - Trade Management (Future Use)                  |
//+------------------------------------------------------------------+
input group "=== Trade Management Settings (Future Use) ==="
input long     magic_Number              = 71401;   // Unique identifier for EA trades
input double   risk_Percent_Placeholder  = 1.0;     // Risk % per trade (0.1-5.0 recommended)
input double   stop_Loss_Buffer_Pips     = 5;      // Buffer added to OB High/Low for SL
input int      take_Profit_Pips_Placeholder = 50;   // Take Profit distance in pips


//--- Global Variables ---
datetime   g_TodayKeyTime_Server;         // Server time for today's Primary Key Time (13:00 UTC+2 equivalent)
datetime   g_ObservationEndTime_Server;   // Server time for the end of the observation window
datetime   g_EntryTiming_Server;          // Server time for the target 15th candlestick entry window
double     g_KeyPrice_At_KeyTime;         // Price at the open of the Key Time bar on the server
int        g_InitialBias = 0;             // 0: Undetermined, 1: Bullish after key time (look for sells), -1: Bearish after key time (look for buys)
int        g_last_processed_bar_index = -1; // To process logic only on new closed bars
datetime   g_last_initialized_day_time = 0; // To track the server time of the last daily reset
string     visual_comment_text = "714EA"; // Prefix for chart comments/object descriptions
bool       g_entry_timed_window_alerted = false; // To control 15th candle window alert
bool       g_order_blocks_scanned_today = false; // To control daily OB detection scan
bool       g_key_price_obtained_today = false; // Flag to ensure key price is obtained only once per day when time is right
bool       g_bias_determined_today = false;    // Flag to track if bias has been determined for the day

//--- Structure to store detected Order Blocks details for the day
struct st_OrderBlock {
   datetime startTime;    // Time of the potential OB candle
   double   high;         // High of the potential OB candle
   double   low;          // Low of the potential OB candle
   ENUM_POSITION_TYPE type;       // POSITION_TYPE_BUY for Bullish, POSITION_TYPE_SELL for Bearish
   bool     isMitigated;  // Has price returned to and traded through this OB range?
   string   objectName;   // Name of the rectangle object if drawn
   string   labelName;    // Name of the text label if drawn
};

st_OrderBlock g_bullishOrderBlocks[100]; // Max 100 Bullish OBs per day
int g_bullishOB_count = 0;

st_OrderBlock g_bearishOrderBlocks[100]; // Max 100 Bearish OBs per day
int g_bearishOB_count = 0;

//--- Forward Declarations ---
double GetPipValue();
bool IsBullishOrderBlockCandidate(int index_in_array, const double &open_arr[], const double &high_arr[], const double &low_arr[], const double &close_arr[], int array_size);
bool IsBearishOrderBlockCandidate(int index_in_array, const double &open_arr[], const double &high_arr[], const double &low_arr[], const double &close_arr[], int array_size);
void DetectOrderBlocksForToday(int scan_newest_chart_index, int scan_oldest_chart_index);
void CalculateAndDrawDailyTimings();
void IsNewDayCheckAndReset();
void RemoveDailyVisualObjects();
void UpdateMitigationStatus(int current_closed_bar_index);
void ManageTrades();
bool YourBuyEntryConditionsMet(int closed_bar_index);
bool YourSellEntryConditionsMet(int closed_bar_index);
//double CalculateLotSize(double risk_perc, double entry_price, double stop_loss_price); // Commented out as it's fully commented
//bool CheckForTradableFVG(int closed_bar_index, ENUM_POSITION_TYPE trade_type); // Commented out
//bool YourHTFBiasCheck(ENUM_TIMEFRAMES htf, ENUM_POSITION_TYPE expected_trade_type); // Commented out
//bool YourPriceActionConfirmation(int closed_bar_index); // Commented out
//void PlaceBuyOrder(double risk_perc, double sl_buffer_pips, double tp_pips_placeholder, int bar_index, const st_OrderBlock &triggered_ob); // Commented out
//void PlaceSellOrder(double risk_perc, double sl_buffer_pips, double tp_pips_placeholder, int bar_index, const st_OrderBlock &triggered_ob); // Commented out

//--- Trade object instance (For Future Use)
CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Check Timeframe ---
   if (Period() != PERIOD_M5) {
      Print("ERROR: 714 Method EA requires the M5 timeframe. Please switch to M5.");
      // Deinit is automatically called upon failure
      return(INIT_FAILED);
   }
   //--- Initialize Trade object (needed for future trade operations) ---
   trade.SetExpertMagicNumber(magic_Number);
   trade.SetDeviationInPoints(10); // Adjust slippage as needed (value is in points)
   //--- Perform daily calculation and initial visualization setup (before prices) ---
   // Key timings are calculated here, but price-dependent visuals drawn later
   CalculateAndDrawDailyTimings();
   // --- Start a timer for checking for new bars and time-based events ---
   EventSetTimer(5); // Check frequently (e.g., every 5 seconds) - logic runs on new bar
   
   Print("714 Method EA V5.01 Core initialized successfully on ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("Manual Server GMT Offset: ", server_GMT_Offset_Manual);
   Print("13:00 UTC+2 Equivalent (Server Time): ", TimeToString(g_TodayKeyTime_Server, TIME_DATE|TIME_MINUTES));
   Print("Observation End (Server Time): ", TimeToString(g_ObservationEndTime_Server, TIME_DATE|TIME_MINUTES));
   
   
   if (g_EntryTiming_Server > 0) Print("Target 15th M5 Candlestick Entry Time (Server Time): ", TimeToString(g_EntryTiming_Server, TIME_DATE|TIME_MINUTES));
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Stop timer ---
   EventKillTimer();
   //--- Remove visual objects created by this EA ---
   if(visual_enabled) RemoveDailyVisualObjects();
   Print("714 Method EA V5.01 Core deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   // --- Check for New Day and Re-initialize Timings if needed ---
   IsNewDayCheckAndReset();
   // --- Process logic only on a NEW M5 closed bar ---
   int total_bars = Bars(Symbol(), Period());
   if (total_bars <= 1) return;
   int closed_bar_index = total_bars - 1;
   if (closed_bar_index <= g_last_processed_bar_index) {
      return; // No new bar has closed or historical bars loading
   }

   // This is a new closed bar that we haven't processed for our main logic
   g_last_processed_bar_index = closed_bar_index;
   datetime current_closed_bar_time = iTime(Symbol(), Period(), 1);//closed_bar_index);
    Print("Processing New Closed Bar at Server Time: ", TimeToString(current_closed_bar_time, TIME_DATE|TIME_MINUTES), " (Index: ", closed_bar_index, ")");
    Print("Key Time Server Time: ", TimeToString(g_TodayKeyTime_Server, TIME_DATE|TIME_MINUTES));
   
   // --- Obtain Key Price and Draw Observation Price Line once the key time bar opens/is available ---
   // Only do this once per day (checked by flag g_key_price_obtained_today)
   // And only when the current closed bar's time is AT or AFTER the target Key Time (g_TodayKeyTime_Server)
   
   
   if(current_closed_bar_time == g_TodayKeyTime_Server)
   {
        Print(visual_comment_text + " - Key Time bar reached at Server Time: ", TimeToString(current_closed_bar_time, TIME_DATE|TIME_MINUTES));
   }
   if (visual_enabled && visual_obs_price_line && !g_key_price_obtained_today && current_closed_bar_time >= g_TodayKeyTime_Server) 
   {

      // Find the bar index that starts exactly at or immediately after the Key Time
      int key_time_actual_bar_idx = iBarShift(Symbol(), Period(), g_TodayKeyTime_Server, false);
      if (key_time_actual_bar_idx >= 0 && key_time_actual_bar_idx < Bars(Symbol(), Period())) 
      {
         // Found the actual bar corresponding to the key time or first one after. Get its Open price.
         g_KeyPrice_At_KeyTime = iOpen(Symbol(), Period(), key_time_actual_bar_idx);
         if (g_KeyPrice_At_KeyTime > 0) 
         { // Ensure a valid price was obtained (iOpen can return 0 if no data)
            Print(visual_comment_text + " - Key Price obtained at Server Time: ", TimeToString(iTime(Symbol(),Period(),key_time_actual_bar_idx), TIME_DATE|TIME_MINUTES), ", Price: ", DoubleToString(g_KeyPrice_At_KeyTime, Digits()));
            // Now draw the TREND object (horizontal line segment) using the accurate key price
            string obs_price_line_name = "Trend_ObsPrice_" + Symbol() + "_" + EnumToString(Period()) + "_" + TimeToString(g_TodayKeyTime_Server, TIME_DATE|TIME_MINUTES|TIME_SECONDS);
            // Ensure previous object is removed before creating (safer in OnTimer if reloads occur)
            
            if(ObjectFind(0, obs_price_line_name) > 0) ObjectDelete(0, obs_price_line_name);
            // Create the TREND object from Key Time to Observation End Time at the Key Price level
            
            if(ObjectCreate(0, obs_price_line_name, OBJ_TREND, 0, g_TodayKeyTime_Server, g_KeyPrice_At_KeyTime, g_ObservationEndTime_Server, g_KeyPrice_At_KeyTime)) {
               ObjectSetInteger(0, obs_price_line_name, OBJPROP_COLOR, obs_price_line_color);
               ObjectSetInteger(0, obs_price_line_name, OBJPROP_STYLE, STYLE_SOLID);
               ObjectSetInteger(0, obs_price_line_name, OBJPROP_WIDTH, 1);
               ObjectSetInteger(0, obs_price_line_name, OBJPROP_SELECTABLE, false);
               ObjectSetInteger(0, obs_price_line_name, OBJPROP_BACK, true);
               ObjectSetString(0, obs_price_line_name, OBJPROP_TEXT, visual_comment_text + ": Obs Price Level");
               ObjectSetInteger(0, obs_price_line_name, OBJPROP_RAY, false);
               ObjectSetInteger(0, obs_price_line_name, OBJPROP_HIDDEN, true); // Hide on lower/higher TFs
               ChartRedraw(0);
               Print(visual_comment_text + " - Observation Price Trend line drawn successfully.");
            }
            else {
               Print("Warning: Observation Price Trend line creation failed (GetLastError: ", GetLastError(), ").");
               // Can check GetLastError() for specific issues (e.g., insufficient bars, invalid time)
            }
         }
         else {
            Print("Warning: Failed to obtain valid Key Price at Server Time ", TimeToString(iTime(Symbol(), Period(), key_time_actual_bar_idx), TIME_DATE|TIME_MINUTES), ". Price was 0 or invalid.");
            // Continue without drawing line today
         }
         g_key_price_obtained_today = true; // Mark as attempted/obtained for today regardless of price validity or drawing success
      }
      else {
         // This should be handled by the time check `current_closed_bar_time >= g_TodayKeyTime_Server`, but defensive check.
         Print("Warning: Key Time bar index not found even though current time is after Key Time.");
      }
   }
   //--- Step 4: Initial Trend Observation (Determine Bias) ---
   // Run this logic only once per day, triggered by the first closed bar
   // that is at or after the Observation End Time.
   if (!g_bias_determined_today && current_closed_bar_time >= g_ObservationEndTime_Server) {
      // Find the bar index that starts exactly at or immediately after the Key Time (g_TodayKeyTime_Server)
      int key_bar_idx = iBarShift(Symbol(), Period(), g_TodayKeyTime_Server, false);
      // Find the bar index that starts exactly at or immediately after the Observation End Time (g_ObservationEndTime_Server)
      int obs_end_bar_idx = iBarShift(Symbol(), Period(), g_ObservationEndTime_Server, false);
      // Ensure we found both relevant bars and the end bar index is valid and at or after the key bar index
      if (key_bar_idx >= 0 && obs_end_bar_idx >= 0 && obs_end_bar_idx < Bars(Symbol(), Period()) && obs_end_bar_idx >= key_bar_idx) { // Used Bars() directly
         // We compare the Close of the bar at the Observation End to the Open of the bar at the Key Time
         double price_at_obs_end = iClose(Symbol(), Period(), obs_end_bar_idx);
         double price_at_keytime = iOpen(Symbol(), Period(), key_bar_idx);
         if (price_at_obs_end > price_at_keytime) {
            g_InitialBias = 1; // Market moved up after the Key Time (Looking for SELL opportunities)
            Print(visual_comment_text + " - Initial Bias determined: BULLISH movement after Key Time. Look for SELLS.");
         }
         else if (price_at_obs_end < price_at_keytime) {
            g_InitialBias = -1; // Market moved down after the Key Time (Looking for BUY opportunities)
            Print(visual_comment_text + " - Initial Bias determined: BEARISH movement after Key Time. Look for BUYS.");
         }
         else {
            g_InitialBias = 0; // No clear move, or very small
            Print(visual_comment_text + " - Initial Bias determined: SIDEWAYS/NO CLEAR TREND after Key Time. Skipping trading based on this strategy today.");
         }
         g_bias_determined_today = true; // Mark bias as determined for today
         // --- After bias is determined, perform OB detection scan if not already done for today ---
         if (!g_order_blocks_scanned_today) {
            // Scan for Order Blocks formed within or immediately preceding the observed move (Stage 2)
            // Define a scan range in times that covers the expected manipulation phase.
            // Scan from slightly before the Key Time up to slightly after the Observation End Time.
            datetime scan_start_period_time = g_TodayKeyTime_Server - PeriodSeconds(Period()) * ob_MaxBlockCandles * 2 ; // Scan a bit before key time
            datetime scan_end_period_time = g_ObservationEndTime_Server + PeriodSeconds(Period()) * ob_Lookback_Bars_For_Impulse * 2; // Scan a bit after observation end
            // Find the corresponding chart bar indices for these times using iBarShift with 'true' for reliability
            // scan_to_chart_idx will be the NEWEST index >= scan_end_period_time
            // scan_from_chart_idx will be the NEWEST index >= scan_start_period_time
            int scan_to_chart_idx = iBarShift(Symbol(), Period(), scan_end_period_time, true); // Find newest index >= end time
            int scan_from_chart_idx = iBarShift(Symbol(), Period(), scan_start_period_time, true); // Find newest index >= start time
            // Ensure valid indices are found
            if(scan_to_chart_idx < 0 || scan_from_chart_idx < 0) { // Check if indices are found in history
               Print(visual_comment_text + " - Warning: Cannot establish a valid historical index range for Order Block detection scan based on calculated scan times.");
               Print(" Calculated scan times: From ", TimeToString(scan_start_period_time, TIME_DATE|TIME_MINUTES), " to ", TimeToString(scan_end_period_time, TIME_DATE|TIME_MINUTES));
               g_order_blocks_scanned_today = true; // Avoid trying again today
               return;
            }
            // Ensure scan_to_chart_idx is not older than scan_from_chart_idx (newer index < older index)
            if (scan_to_chart_idx > scan_from_chart_idx) {
               int temp = scan_to_chart_idx;
               scan_to_chart_idx = scan_from_chart_idx;
               scan_from_chart_idx = temp; // Swap if order is wrong
            }
            // Ensure the entire range needed for lookahead from the oldest scan candidate bar is within available history (index >= 0)
            if( scan_from_chart_idx + MathMax(ob_Lookback_Bars_For_Impulse, ob_MaxBlockCandles) >= Bars(Symbol(), Period())) {
               Print(visual_comment_text + " - Not enough historical bars available to perform OB detection scan with required lookahead from the oldest scan index.");
               g_order_blocks_scanned_today = true;
               return;
            }
            // Perform the detection scan within this time range (scan from newer index to older index)
            DetectOrderBlocksForToday(scan_to_chart_idx, scan_from_chart_idx); // Pass newer index, then older index
         } // End if not g_order_blocks_scanned_today
      } // End if bias determined and relevant bar indices found
      else {
         Print("Warning: Could not determine relevant bar indices for initial bias determination.");
         g_InitialBias = 0; // Set to undetermined
      }
   } // End if !g_bias_determined_today and at/after Observation End Time
   //--- Step 5: Check the target 15th candlestick for potential entry ---
   // Only proceed if bias has been determined and we are at the exact bar time for the 15th candle.
   if (g_InitialBias != 0 && g_EntryTiming_Server > 0) { // Only check if bias is set and entry time calculated
      // Check if the current closed bar's time is EXACTLY the target entry timing.
      if (current_closed_bar_time == g_EntryTiming_Server) {
         Print(visual_comment_text + " - >>> Inside TARGET 15th M5 Candlestick Entry Window at Server Time: ", TimeToString(current_closed_bar_time, TIME_DATE|TIME_MINUTES));
         // Mark the alert flag to indicate we have processed this entry bar
         g_entry_timed_window_alerted = true;
         // --- THIS IS THE PLACEHOLDER FOR YOUR DETAILED ENTRY LOGIC ---
         // At this exact time (current_closed_bar_time / closed_bar_index), check for detailed confluence using the latest bar data:
         // 1. **Crucially: Find Relevant Detected OBs.** Iterate through `g_bullishOrderBlocks` or `g_bearishOrderBlocks`. Find any active (not mitigated) OBs *formed earlier in the manipulation phase* whose range is *near* the current price.
         // 2. **Check for Price Interaction and Confirmation.** Check if the `closed_bar_index` bar is interacting with a relevant OB (tapping, wicking into it) AND shows price action confirmation *at that spot* (e.g., reversal candle, break of microstructure).
         // 3. **Add other confluence checks.** Use your FVG detection code and HTF bias.
         bool entry_conditions_met = false;
         if (g_InitialBias == -1) { // If initial move was bearish, looking for BUYS
            // Call your function to check buy conditions at this bar index.
            // This function will check against the stored g_bullishOrderBlocks and look for confirmation.
            // You'll need to pass g_bullishOrderBlocks and g_bullishOB_count to this function or make them accessible
            // entry_conditions_met = YourBuyEntryConditionsMet(closed_bar_index, g_bullishOrderBlocks, g_bullishOB_count);
            Print(visual_comment_text + " - Placeholder: Buy entry conditions *potentially* checked at 15th candle (Need implementation).");
            if (entry_conditions_met) {
               Print(visual_comment_text + " - Buy Entry conditions met at 15th candle.");
               // --- PLACEHOLDER for placing BUY ORDER ---
               // Example: Find the triggering OB based on YourBuyEntryConditionsMet result and pass its details for SL/TP
               // PlaceBuyOrder(risk_Percent_Placeholder, stop_Loss_Buffer_Pips, take_Profit_Pips_Placeholder, closed_bar_index, g_TriggeredOB); // Need to set g_TriggeredOB inside YourBuyEntryConditionsMet or return the OB details
               // Print("Placeholder: Buy order placement function called. Trading disabled in V5.01.");
            }
         }
         else if (g_InitialBias == 1) { // If initial move was bullish, looking for SELLS
            // Call your function to check sell conditions at this bar index.
            // This function will check against the stored g_bearishOrderBlocks and look for confirmation.
            // You'll need to pass g_bearishOrderBlocks and g_bearishOB_count to this function or make them accessible
            // entry_conditions_met = YourSellEntryConditionsMet(closed_bar_index, g_bearishOrderBlocks, g_bearishOB_count);
            Print(visual_comment_text + " - Placeholder: Sell entry conditions *potentially* checked at 15th candle (Need implementation).");
            if (entry_conditions_met) {
               Print(visual_comment_text + " - Sell Entry conditions met at 15th candle.");
               // --- PLACEHOLDER for placing SELL ORDER ---
               // Example: Find the triggering OB based on YourSellEntryConditionsMet result and pass its details for SL/TP
               // PlaceSellOrder(risk_Percent_Placeholder, stop_Loss_Buffer_Pips, take_Profit_Pips_Placeholder, closed_bar_index, g_TriggeredOB); // Need to set g_TriggeredOB inside YourSellEntryConditionsMet or return the OB details
               // Print("Placeholder: Sell order placement function called. Trading disabled in V5.01.");
            }
         }
         // --- END OF ENTRY LOGIC PLACEHOLDER ---
      }
      // After the 15th candle bar, don't keep checking the timed entry window logic.
      // If the current closed bar's time has passed the 15th candle time, and we haven't already noted it:
      if (g_EntryTiming_Server > 0 && current_closed_bar_time > g_EntryTiming_Server && !g_entry_timed_window_alerted) {
         Print(visual_comment_text + " - Passed the exact target 15th M5 candlestick time (", TimeToString(g_EntryTiming_Server, TIME_DATE|TIME_MINUTES), "). No setup found at that bar.");
         // g_entry_timed_window_alerted flag is set above when we are *inside* the target bar time.
         // If we are here, it means we've passed that time, so no more checking needed for *this* exact timed entry.
      }
   } // End of 15th Candle Entry Trigger Check
   //--- Update mitigation status of detected Order Blocks as price moves ---
   UpdateMitigationStatus(closed_bar_index);
   //--- Step 6: Manage Trades (e.g., close at session end, BE, TP, Trailing) ---
   ManageTrades(); // Includes end-of-day close
}

//+------------------------------------------------------------------+
//| Order Block Detection Logic                                      |
//| Scans historical data arrays to identify OB candidates              |
//| (Adapted from previous SMC Indicator Logic)                      |
//+------------------------------------------------------------------+
// Helper function to calculate pip value
double GetPipValue()
{
   double pip_value = Point();
   if(Digits() == 3 || Digits() == 5) pip_value *= 10;
   return pip_value;
}

// Check if a candle at 'index_in_array' is a Bullish Order Block candidate
// (Bearish candle followed by consecutive bullish candles moving a minimum distance)
// Note: Index is relative to the start of the copied array
bool IsBullishOrderBlockCandidate(int index_in_array, const double &open_arr[], const double &high_arr[], const double &low_arr[], const double &close_arr[], int array_size)
{
   // Candle at 'index_in_array' must be bearish
   if (close_arr[index_in_array] >= open_arr[index_in_array]) return false;
   // Ensure there are enough bars *after* the potential OB candle (at index_in_array + 1)
   // for the impulse move check and block candle period check
   int needed_future_bars_for_checks = MathMax(ob_Lookback_Bars_For_Impulse, ob_MaxBlockCandles -1 ); // Bars needed *after* the candidate candle's time slot ends
   if (index_in_array + 1 + needed_future_bars_for_checks >= array_size) return false; // If checks extend beyond array bounds
   double cumulative_move_after_ob = 0;
   bool found_strong_move = false;
   // Scan *after* the potential OB candle (index_in_array + 1, ...) for the bullish move
   // Loop up to index_in_array + 1 + ob_Lookback_Bars_For_Impulse - 1
   for (int i = index_in_array + 1; i < index_in_array + 1 + ob_Lookback_Bars_For_Impulse && i < array_size; i++) {
      if (close_arr[i] > open_arr[i]) { // Found a bullish candle
         cumulative_move_after_ob += (close_arr[i] - open_arr[i]); // Add the points move
         // Check for the minimum cumulative move
         if ((cumulative_move_after_ob / GetPipValue()) >= ob_MinMovePips) {
            // Now check for consecutive bullish candles leading up to this point in the impulse scan
            bool consecutive_bullish_met = true;
            for(int k = index_in_array + 1; k <= i; k++) { // Check bars from directly after OB up to current candle 'i' in impulse scan
               if(close_arr[k] <= open_arr[k]) { // If any non-bullish candle is found in this sub-segment
                  consecutive_bullish_met = false;
                  break; // Not consecutive bullish sequence for this sub-segment
               }
            }
            if(consecutive_bullish_met && (i - (index_in_array+1) + 1) >= 2) { // Check if at least 2 consecutive bullish candles *in this specific segment* contributed to meeting the min move
               found_strong_move = true; // Criteria for strong move met by this segment
               break; // Stop scanning after this point as a sufficient move + consecutive sequence was found
            }
         }
      }
      else {
         // If a bearish or doji candle is encountered *immediately* after the OB candidate (i == index_in_array + 1)
         // And the move condition wasn't met yet, this might stop the search for the impulse, based on some definitions.
         // However, the provided indicator's logic simplified this by breaking *if any* non-bullish candle is found within the lookback range.
         // Let's keep the simple `else break` as interpreted from the original indicator logic: if a non-bullish candle is found at *any* point within the lookback, break the impulse scan for this OB candidate.
         break; // If a non-bullish candle breaks the consecutive search in the original logic sense
      }
   }
   if (!found_strong_move) return false; // No valid impulsive move after the candidate OB
   // Ensure no high *in the potential OB candle and next MaxBlockCandles bars* is higher than the OB candle's high
   bool no_higher_high_in_block_period = true;
   // Loop from the OB candle's index (index_in_array) up to index + ob_MaxBlockCandles - 1 in the array
   for(int j = index_in_array; j < index_in_array + ob_MaxBlockCandles && j < array_size; j++) {
      // Check highs of candles within the block period (starting *from* the OB candidate itself)
      if (high_arr[j] > high_arr[index_in_array]) { // If ANY candle in the block period has a higher high than the potential OB candle
         no_higher_high_in_block_period = false;
         break;
      }
   }
   if (!no_higher_high_in_block_period) return false;
   // If all checks passed, this is a valid Bullish Order Block candidate
   return true;
}

// Check if a candle at 'index_in_array' is a Bearish Order Block candidate
// (Bullish candle followed by consecutive bearish candles moving a minimum distance)
// Note: Index is relative to the start of the copied array
bool IsBearishOrderBlockCandidate(int index_in_array, const double &open_arr[], const double &high_arr[], const double &low_arr[], const double &close_arr[], int array_size)
{
   // Candle at 'index_in_array' must be bullish
   if (close_arr[index_in_array] <= open_arr[index_in_array]) return false;
   // Ensure there are enough bars *after* the potential OB candle (at index_in_array + 1)
   int needed_future_bars_for_checks = MathMax(ob_Lookback_Bars_For_Impulse, ob_MaxBlockCandles -1 );
   if (index_in_array + 1 + needed_future_bars_for_checks >= array_size) return false;
   double cumulative_move_after_ob = 0;
   bool found_strong_move = false;
   // Scan *after* the potential OB candle (index_in_array + 1, ...) for the bearish move
   for (int i = index_in_array + 1; i < index_in_array + 1 + ob_Lookback_Bars_For_Impulse && i < array_size; i++) {
      if (close_arr[i] < open_arr[i]) { // Found a bearish candle
         cumulative_move_after_ob += (open_arr[i] - close_arr[i]); // Add the points move
         // Check for the minimum cumulative move
         if ((cumulative_move_after_ob / GetPipValue()) >= ob_MinMovePips) {
            // Now check for consecutive bearish candles leading up to this point in the impulse scan
            bool consecutive_bearish_met = true;
            for(int k = index_in_array + 1; k <= i; k++) { // Check bars from directly after OB up to current candle 'i' in impulse scan
               if(close_arr[k] >= open_arr[k]) { // If any non-bearish candle is found in this sub-segment
                  consecutive_bearish_met = false;
                  break; // Not consecutive sequence for this sub-segment
               }
            }
            if(consecutive_bearish_met && (i - (index_in_array+1) + 1) >= 2) { // Check if at least 2 consecutive bearish candles *in this specific segment* contributed to meeting the min move
               found_strong_move = true; // Criteria for strong move met by this segment
               break; // Stop scanning after this point
            }
         }
      }
      else {
         // Let's keep the simple `else break` as interpreted from the original indicator logic.
         break; // If a non-bearish candle breaks the consecutive search
      }
   }
   if (!found_strong_move) return false; // No valid impulsive move after candidate OB
   // Ensure no low *in the potential OB candle and next MaxBlockCandles bars* is lower than the OB candle's low
   bool no_lower_low_in_block_period = true;
   // Loop from the OB candle's index (index_in_array) up to index + ob_MaxBlockCandles - 1 in the array
   for(int j = index_in_array; j < index_in_array + ob_MaxBlockCandles && j < array_size; j++) {
      // If we are checking a candle *after* the potential OB candle, ensure its low is not lower.
      if (j > index_in_array && low_arr[j] < low_arr[index_in_array]) {
         no_lower_low_in_block_period = false;
         break;
      }
   }
   if (!no_lower_low_in_block_period) return false;
   // If all checks passed, this is a valid Bearish Order Block candidate
   return true;
}


//+------------------------------------------------------------------+
//| Detects and Stores Order Blocks formed around the Key Time       |
//| Runs once per day after initial bias determination               |
//| Scan range limited to the expected manipulation period (Stage 2) |
//| scan_newest_chart_index is the newer chart index, scan_oldest_chart_index is the older chart index |
//+------------------------------------------------------------------+
// The function scans from newest index back to oldest index numerically in the chart history
void DetectOrderBlocksForToday(int scan_newest_chart_index, int scan_oldest_chart_index)
{
   if (g_order_blocks_scanned_today) return; // Only run detection scan once per day
   int total_bars = Bars(Symbol(), Period());
   // Ensure valid scan range (scan_newest_chart_index < scan_oldest_chart_index numerically for a range going backwards in time)
   if (scan_newest_chart_index < 0 || scan_oldest_chart_index < 0 || scan_newest_chart_index >= total_bars || scan_oldest_chart_index >= total_bars || scan_newest_chart_index >= scan_oldest_chart_index) { // Condition check correct based on index values
      Print(visual_comment_text + " - DetectOrderBlocksForToday Error: Invalid chart index scan range (newest: ", scan_newest_chart_index, ", oldest: ", scan_oldest_chart_index, ", total bars: ", total_bars, ").");
      g_order_blocks_scanned_today = true; // Avoid trying again
      return;
   }
   // Calculate the total number of bars required for copying, starting from the oldest scan bar index.
   // This range covers from scan_oldest_chart_index back to satisfy any OB lookahead, up to scan_newest_chart_index.
   int max_bars_ahead_needed_by_ob = MathMax(ob_Lookback_Bars_For_Impulse + 1, ob_MaxBlockCandles) ; // Furthest number of bars forward checked by OB candidate logic, including candidate itself
   int needed_total_bars_from_oldest_scan = (scan_oldest_chart_index - scan_newest_chart_index + 1) + max_bars_ahead_needed_by_ob ; // Number of bars covering the scan range and lookahead from oldest scan bar
   if (needed_total_bars_from_oldest_scan > total_bars - scan_newest_chart_index ) { // Check if total bars available from newest scan bar onwards is enough
      Print(visual_comment_text + " - Not enough historical bars available (need ", needed_total_bars_from_oldest_scan, " bars from chart index ", scan_newest_chart_index, " onwards. Have ", total_bars - scan_newest_chart_index, ") to perform OB detection scan with required lookahead.");
      g_order_blocks_scanned_today = true;
      return;
   }
   // Correct Indices to Copy: Copy enough bars starting from the oldest required bar backward in history
   int copy_start_chart_index = MathMax(0, scan_newest_chart_index - MathMax(ob_Lookback_Bars_For_Impulse, ob_MaxBlockCandles)); // Starting point for copying to have enough data backwards from newest scanned index
   int num_bars_to_copy = total_bars - copy_start_chart_index; // Number of bars from copy_start to end of history (chart index total_bars - 1)
   // Use Arrays to read necessary bar data efficiently over the history needed for scanning and lookahead checks
   double open_arr[], high_arr[], low_arr[], close_arr[];
   if (CopyOpen(Symbol(), Period(), copy_start_chart_index, num_bars_to_copy, open_arr) < num_bars_to_copy || // Check copied bars count against requested
         CopyHigh(Symbol(), Period(), copy_start_chart_index, num_bars_to_copy, high_arr) < num_bars_to_copy ||
         CopyLow(Symbol(), Period(), copy_start_chart_index, num_bars_to_copy, low_arr) < num_bars_to_copy ||
         CopyClose(Symbol(), Period(), copy_start_chart_index, num_bars_to_copy, close_arr) < num_bars_to_copy) {
      Print("Error copying price data for OB detection scan or insufficient data received: ", GetLastError());
      g_order_blocks_scanned_today = true;
      return;
   }
   // Reset daily OB counts (done in CalculateAndDrawDailyTimings)
   Print(visual_comment_text + " - Scanning chart indices from ", scan_newest_chart_index, " (newest) back to ", scan_oldest_chart_index, " (oldest) for Order Blocks in Stage 2 period. Using array data starting from chart index ", copy_start_chart_index, " (Array size: ", num_bars_to_copy, ")");
   // Iterate through the relevant M5 bars within the specified scan range (using chart indices).
   // These are the candidate OB candles. Loop from newest relevant bar back to oldest relevant bar.
   for (int chart_idx = scan_newest_chart_index; chart_idx <= scan_oldest_chart_index; chart_idx++) { // Loop from newest (lower index) to oldest (higher index)
      // Limit detection to candidates formed within or immediately preceding the core manipulation/observation period
      // If scan_before_obs_end_only is true, only consider candidates whose end time is roughly before observation end time.
      datetime ob_end_approx_time = iTime(Symbol(), Period(), chart_idx) + PeriodSeconds(Period()) * ob_MaxBlockCandles; // Approx end time of the OB block period from this candidate (adjust calculation to align with visual rect if needed)
      if(scan_before_obs_end_only && ob_end_approx_time >= g_ObservationEndTime_Server ) continue;
      int arr_idx = chart_idx - copy_start_chart_index; // Get the array index for this chart index (Correct)
      // Ensure we have enough bars *ahead* in the copied array from this candidate bar 'arr_idx' to perform the full OB checks
      int needed_future_bars_from_arr_idx = MathMax(ob_Lookback_Bars_For_Impulse + 1, ob_MaxBlockCandles) ; // Number of bars required for the check starting AT arr_idx and looking forward (including arr_idx itself)
      if (arr_idx + needed_future_bars_from_arr_idx >= num_bars_to_copy) { // If checks extend beyond array bounds from THIS starting point
         // Not enough future bars in the copied array from this candidate's position
         // This candidate is too close to the end of the copied data for its full check
         Print("Warning: Skipping OB candidate at chart index ", chart_idx, " (array index ", arr_idx, "). Not enough future data in copied array (Need ", needed_future_bars_from_arr_idx, ", Have ", num_bars_to_copy - arr_idx, " from this point)."); // Verbose skipping
         continue; // Cannot perform full check
      }
      // --- Check if this candle at array index 'arr_idx' is a Bullish or Bearish Order Block candidate ---
      bool is_bullish_ob = IsBullishOrderBlockCandidate(arr_idx, open_arr, high_arr, low_arr, close_arr, num_bars_to_copy);
      bool is_bearish_ob = IsBearishOrderBlockCandidate(arr_idx, open_arr, high_arr, low_arr, close_arr, num_bars_to_copy);
      if (is_bullish_ob) {
         if (g_bullishOB_count < 100) {
            // Store details using data corresponding to chart index 'chart_idx'
            g_bullishOrderBlocks[g_bullishOB_count].startTime = iTime(Symbol(), Period(), chart_idx);
            g_bullishOrderBlocks[g_bullishOB_count].high = iHigh(Symbol(), Period(), chart_idx);
            g_bullishOrderBlocks[g_bullishOB_count].low = iLow(Symbol(), Period(), chart_idx);
            g_bullishOrderBlocks[g_bullishOB_count].type = POSITION_TYPE_BUY;
            g_bullishOrderBlocks[g_bullishOB_count].isMitigated = false;
            g_bullishOrderBlocks[g_bullishOB_count].objectName = "BullOB_" + TimeToString(g_bullishOrderBlocks[g_bullishOB_count].startTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS) + "_" + IntegerToString(chart_idx); // Even more unique
            g_bullishOrderBlocks[g_bullishOB_count].labelName = g_bullishOrderBlocks[g_bullishOB_count].objectName + "_Label";
            // Print confirmation - can be verbose if many OBs found
            Print(visual_comment_text + " - Detected BULLISH Order Block at Server Time: ", TimeToString(g_bullishOrderBlocks[g_bullishOB_count].startTime, TIME_DATE|TIME_MINUTES), " (Chart Index ", chart_idx, ")");
            // Draw the OB visual if enabled and not already drawn
            if(visual_enabled && visual_order_blocks) {
               string ob_name = g_bullishOrderBlocks[g_bullishOB_count].objectName;
               // Delete if already exists (safety measure for rapid redraws)
               if(ObjectFind(0, ob_name) > 0) ObjectDelete(0, ob_name);
               // Draw rectangle over the time span of the OB candle and the following MaxBlockCandles-1
               if (ObjectCreate(0, ob_name, OBJ_RECTANGLE, 0, g_bullishOrderBlocks[g_bullishOB_count].startTime, g_bullishOrderBlocks[g_bullishOB_count].high, g_bullishOrderBlocks[g_bullishOB_count].startTime + PeriodSeconds(Period()) * (ob_MaxBlockCandles-1), g_bullishOrderBlocks[g_bullishOB_count].low)) {
                  ObjectSetInteger(0, ob_name, OBJPROP_COLOR, ob_bullish_color);
                  ObjectSetInteger(0, ob_name, OBJPROP_STYLE, STYLE_SOLID);
                  ObjectSetInteger(0, ob_name, OBJPROP_WIDTH, 1);
                  ObjectSetInteger(0, ob_name, OBJPROP_FILL, true);
                  ObjectSetInteger(0, ob_name, OBJPROP_BACK, true); // Send to back
                  ObjectSetInteger(0, ob_name, OBJPROP_SELECTABLE, false);
                  ObjectSetInteger(0, ob_name, OBJPROP_HIDDEN, true); // Hide on other TFs
                  // Add a label for the OB
                  string ob_label_name = g_bullishOrderBlocks[g_bullishOB_count].labelName;
                  if (!ObjectFind(0, ob_label_name)) {
                     datetime label_time = g_bullishOrderBlocks[g_bullishOB_count].startTime + PeriodSeconds(Period()) * (ob_MaxBlockCandles-1) / 2; // Center label
                     double label_price = (g_bullishOrderBlocks[g_bullishOB_count].high + g_bullishOrderBlocks[g_bullishOB_count].low) / 2;
                     ObjectCreate(0, ob_label_name, OBJ_TEXT, 0, label_time, label_price);
                     ObjectSetString(0, ob_label_name, OBJPROP_TEXT, "Bull OB");
                     ObjectSetInteger(0, ob_label_name, OBJPROP_COLOR, ob_label_color);
                     ObjectSetInteger(0, ob_label_name, OBJPROP_ANCHOR, ANCHOR_CENTER);
                     ObjectSetInteger(0, ob_label_name, OBJPROP_FONTSIZE, 7);
                     ObjectSetInteger(0, ob_label_name, OBJPROP_SELECTABLE, false);
                     ObjectSetInteger(0, ob_label_name, OBJPROP_BACK, false); // Send label to back?
                     ObjectSetInteger(0, ob_label_name, OBJPROP_HIDDEN, true); // Hide on other TFs
                  }
               }
               else {
                  Print(visual_comment_text + " - Error creating Bull OB visual object at chart index ", chart_idx, ": ", GetLastError());
               }
            }
            g_bullishOB_count++; // Increment counter
         }
         else {
            // Print(visual_comment_text + " - Warning: Maximum daily Bullish Order Blocks storage capacity reached. Skipping detection from chart index ", chart_idx);
         }
      } // End if is_bullish_ob
      if (is_bearish_ob) {
         if (g_bearishOB_count < 100) {
            g_bearishOrderBlocks[g_bearishOB_count].startTime = iTime(Symbol(), Period(), chart_idx);
            g_bearishOrderBlocks[g_bearishOB_count].high = iHigh(Symbol(), Period(), chart_idx);
            g_bearishOrderBlocks[g_bearishOB_count].low = iLow(Symbol(), Period(), chart_idx);
            g_bearishOrderBlocks[g_bearishOB_count].type = POSITION_TYPE_SELL;
            g_bearishOrderBlocks[g_bearishOB_count].isMitigated = false;
            g_bearishOrderBlocks[g_bearishOB_count].objectName = "BearOB_" + TimeToString(g_bearishOrderBlocks[g_bearishOB_count].startTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS) + "_" + IntegerToString(chart_idx); // Even more unique
            g_bearishOrderBlocks[g_bearishOB_count].labelName = g_bearishOrderBlocks[g_bearishOB_count].objectName + "_Label";
            // Print confirmation - can be verbose
            // Print(visual_comment_text + " - Detected BEARISH Order Block at Server Time: ", TimeToString(g_bearishOrderBlocks[g_bearishOB_count].startTime, TIME_DATE|TIME_MINUTES), " (Chart Index ", chart_idx, ")");
            // Draw the OB visual if enabled and not already drawn
            if(visual_enabled && visual_order_blocks) {
               string ob_name = g_bearishOrderBlocks[g_bearishOB_count].objectName;
               string ob_label_name = g_bearishOrderBlocks[g_bearishOB_count].labelName;
               if(ObjectFind(0, ob_name) > 0) ObjectDelete(0, ob_name); // Delete if already exists
               // Draw rectangle over the time span of the OB candle and the following MaxBlockCandles-1
               if (ObjectCreate(0, ob_name, OBJ_RECTANGLE, 0, g_bearishOrderBlocks[g_bearishOB_count].startTime, g_bearishOrderBlocks[g_bearishOB_count].high, g_bearishOrderBlocks[g_bearishOB_count].startTime + PeriodSeconds(Period()) * (ob_MaxBlockCandles-1), g_bearishOrderBlocks[g_bearishOB_count].low)) {
                  ObjectSetInteger(0, ob_name, OBJPROP_COLOR, ob_bearish_color);
                  ObjectSetInteger(0, ob_name, OBJPROP_STYLE, STYLE_SOLID);
                  ObjectSetInteger(0, ob_name, OBJPROP_WIDTH, 1);
                  ObjectSetInteger(0, ob_name, OBJPROP_FILL, true);
                  ObjectSetInteger(0, ob_name, OBJPROP_BACK, true); // Send to back
                  ObjectSetInteger(0, ob_name, OBJPROP_SELECTABLE, false);
                  ObjectSetInteger(0, ob_name, OBJPROP_HIDDEN, true); // Hide on other TFs
                  // Add a label for the OB
                  if (!ObjectFind(0, ob_label_name)) {
                     datetime label_time = g_bearishOrderBlocks[g_bearishOB_count].startTime + PeriodSeconds(Period()) * (ob_MaxBlockCandles-1) / 2; // Center label
                     double label_price = (g_bearishOrderBlocks[g_bearishOB_count].high + g_bearishOrderBlocks[g_bearishOB_count].low) / 2;
                     ObjectCreate(0, ob_label_name, OBJ_TEXT, 0, label_time, label_price);
                     ObjectSetString(0, ob_label_name, OBJPROP_TEXT, "Bear OB");
                     ObjectSetInteger(0, ob_label_name, OBJPROP_COLOR, ob_label_color);
                     ObjectSetInteger(0, ob_label_name, OBJPROP_ANCHOR, ANCHOR_CENTER);
                     ObjectSetInteger(0, ob_label_name, OBJPROP_FONTSIZE, 7);
                     ObjectSetInteger(0, ob_label_name, OBJPROP_SELECTABLE, false);
                     ObjectSetInteger(0, ob_label_name, OBJPROP_BACK, false); // Send label to back?
                     ObjectSetInteger(0, ob_label_name, OBJPROP_HIDDEN, true); // Hide on other TFs
                  }
               }
               else {
                  Print(visual_comment_text + " - Error creating Bear OB visual object at chart index ", chart_idx, ": ", GetLastError());
               }
            }
            g_bearishOB_count++; // Increment counter
         }
         else {
            // Print(visual_comment_text + " - Warning: Maximum daily Bearish Order Blocks storage capacity reached. Skipping detection from chart index ", chart_idx);
         }
      } // End if is_bearish_ob
   } // End of scan loop backwards through the chart indices
   Print(visual_comment_text + " - Order Block detection scan completed for Stage 2 period. Detected Bull OBs: ", g_bullishOB_count, ", Bear OBs: ", g_bearishOB_count);
   g_order_blocks_scanned_today = true; // Mark detection as completed for today
   ChartRedraw(0); // Redraw chart after drawing objects
}


//+------------------------------------------------------------------+
//| Function to perform daily calculation and initial visualization setup|
//| Calculates key times and draws static visual lines               |
//+------------------------------------------------------------------+
void CalculateAndDrawDailyTimings()
{
   // --- Calculate today's Primary Key Time (13:00 UTC+2) in server time ---
   datetime server_midnight = iTime(Symbol(), PERIOD_D1, 0);
   if(server_midnight == 0) {
      Print("Error getting server midnight time for timings calculation. Ensure enough D1 history is loaded.");
      g_last_initialized_day_time = 0; // Mark initialization failed for the day
      return;
   }
   int total_bars = Bars(Symbol(), Period()); // Declare and initialize total_bars
   // Target hour in GMT (13:00 UTC+2 is 11:00 GMT -> 13 - 2 = 11)
   int target_hour_gmt = utcPlus2_KeyHour_1300 - 2; // Assuming UTC+2 is always GMT+2
   // Calculate target hour in Server Time relative to server midnight
   int target_server_hour = target_hour_gmt + server_GMT_Offset_Manual;
   // Ensure target_server_hour is within 0-23
   target_server_hour = target_server_hour % 24;
   if(target_server_hour < 0) target_server_hour += 24;
   // Calculate the exact datetime in server time for the key time
   g_TodayKeyTime_Server = (datetime)(server_midnight + (long)target_server_hour * 3600L + (long)utcPlus2_KeyMinute_1300 * 60L);
   //--- Calculate the observation end time (after observation duration) in server time ---
   g_ObservationEndTime_Server = g_TodayKeyTime_Server + observation_Duration_Minutes * 60;
   //--- Calculate the specific 15th candlestick entry time in server time ---
   // Find the bar index that starts exactly at or immediately after the Key Time (g_TodayKeyTime_Server)
   // We want the 15th M5 bar starting *from* the bar at g_TodayKeyTime_Server as the first bar.
   int key_bar_idx_for_count = iBarShift(Symbol(), Period(), g_TodayKeyTime_Server, false);
   if (key_bar_idx_for_count >= 0) 
   { // Ensure the starting bar for the count exists
      // The index of the target bar relative to chart start is Key bar index + (Target count - 1)
      int target_entry_bar_idx = key_bar_idx_for_count + (entry_Candlestick_Index -1);
      // Get the time of the target entry bar (assuming enough bars exist)
      if(target_entry_bar_idx >= 0 && target_entry_bar_idx < Bars(Symbol(), Period())) {
         g_EntryTiming_Server = iTime(Symbol(), Period(), target_entry_bar_idx);
         Print(visual_comment_text + " - Calculated Target 15th M5 Candlestick Entry Time (Server Time): ", TimeToString(g_EntryTiming_Server, TIME_DATE|TIME_MINUTES));
      }
      else {
         Print(visual_comment_text + " - Warning: Not enough historical bars to determine the 15th candlestick time based on today's key time (idx: ", target_entry_bar_idx, ", bars: ", Bars(Symbol(),Period()), "). Ensure enough M5 history is loaded.");
         g_EntryTiming_Server = 0; // Indicate timing not calculated
      }
      // Key Price retrieval and Obs Price Line drawing moved to OnTimer
      // g_KeyPrice_At_KeyTime will be obtained later
   }
   else 
   {
      Print("Warning: Could not find a bar at or after the calculated Key Time (", TimeToString(g_TodayKeyTime_Server, TIME_DATE|TIME_MINUTES), ") to start the 15-bar count. Insufficient M5 data for this time.");
      g_EntryTiming_Server = 0;
      g_KeyPrice_At_KeyTime = 0; // Reset Key Price as bar wasn't found
   }
   //--- Draw Visual Lines ---
   if (visual_enabled) 
   {
      // Ensure previous visuals are removed before drawing new ones for the day
      RemoveDailyVisualObjects(); // This removes all lines, OBs, labels
      // Draw main timing lines if enabled
      if (visual_main_timing_lines) {
         // Draw Vertical Line at Key Time (13:00 UTC+2 Server Time)
         string key_time_vline_name = "VLine_KeyTime_" + Symbol() + "_" + EnumToString(Period()) + "_" + TimeToString(server_midnight, TIME_DATE|TIME_MINUTES|TIME_SECONDS); // Unique name based on server midnight for the day
         if(ObjectFind(0, key_time_vline_name) > 0) ObjectDelete(0, key_time_vline_name);
         if (g_TodayKeyTime_Server > 0 && ObjectCreate(0, key_time_vline_name, OBJ_VLINE, 0, g_TodayKeyTime_Server, 0.0)) {
            ObjectSetInteger(0, key_time_vline_name, OBJPROP_COLOR, vline_keytime_color);
            ObjectSetString(0, key_time_vline_name, OBJPROP_TEXT, visual_comment_text + ": 13:00 UTC+2 (" + TimeToString(g_TodayKeyTime_Server, TIME_DATE|TIME_MINUTES) + " Server)");
            ObjectSetInteger(0, key_time_vline_name, OBJPROP_RAY, false);
            ObjectSetInteger(0, key_time_vline_name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, key_time_vline_name, OBJPROP_HIDDEN, true); // Hide on lower/higher TFs
         }
         else {
            Print("Warning: Key Time vertical line not drawn (Time: ", TimeToString(g_TodayKeyTime_Server, TIME_DATE|TIME_MINUTES), ", GetLastError: ", GetLastError(), ")");
         }
         // Draw Vertical Line at Observation End Time (Server Time)
         string obs_end_vline_name = "VLine_ObsEnd_" + Symbol() + "_" + EnumToString(Period()) + "_" + TimeToString(server_midnight, TIME_DATE|TIME_MINUTES|TIME_SECONDS); // Unique name based on server midnight
         if(ObjectFind(0, obs_end_vline_name) > 0) ObjectDelete(0, obs_end_vline_name);
         if (g_ObservationEndTime_Server > 0 && ObjectCreate(0, obs_end_vline_name, OBJ_VLINE, 0, g_ObservationEndTime_Server, 0.0)) {
            ObjectSetInteger(0, obs_end_vline_name, OBJPROP_COLOR, vline_obsend_color);
            ObjectSetString(0, obs_end_vline_name, OBJPROP_TEXT, visual_comment_text + ": Obs End (" + TimeToString(g_ObservationEndTime_Server, TIME_DATE|TIME_MINUTES) + " Server)");
            ObjectSetInteger(0, obs_end_vline_name, OBJPROP_RAY, false);
            ObjectSetInteger(0, obs_end_vline_name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, obs_end_vline_name, OBJPROP_HIDDEN, true); // Hide on lower/higher TFs
         }
         else {
            Print("Warning: Observation End vertical line not drawn (Time: ", TimeToString(g_ObservationEndTime_Server, TIME_DATE|TIME_MINUTES), ", GetLastError: ", GetLastError(), ")");
         }
         ChartRedraw(0); // Redraw after drawing lines
         // Key Price related lines (OBJ_HLINE or OBJ_TREND) will be drawn in OnTimer once price is available
         // based on the g_KeyPrice_At_KeyTime and g_obs_price_line_drawn_today flag.
         // OBs visuals are drawn when they are detected later in DetectOrderBlocksForToday
      }
      // --- Update the last initialized day marker ---
      g_last_initialized_day_time = server_midnight;
      // Reset static OB count arrays.
      g_bullishOB_count = 0;
      g_bearishOB_count = 0;
      // Reset flags for daily logic execution
      g_bias_determined_today = false;
      g_order_blocks_scanned_today = false;
      g_entry_timed_window_alerted = false;
      g_key_price_obtained_today = false; // Reset the flag for obtaining the key price
      // Trigger the initial scan for OBs right after daily timing calculation IF bias is already determined
      // This might happen on backtesting start or EA load when market is already past observation window
      if (g_InitialBias != 0 && !g_order_blocks_scanned_today && g_last_initialized_day_time == server_midnight) { // Add check for current day initialization
         // Define scan range in times that covers the expected manipulation phase.
         // Scan from slightly before the Key Time up to slightly after the Observation End Time.
         datetime scan_start_period_time = g_TodayKeyTime_Server - PeriodSeconds(Period()) * ob_MaxBlockCandles * 2 ; // Scan a bit before key time
         datetime scan_end_period_time = g_ObservationEndTime_Server + PeriodSeconds(Period()) * ob_Lookback_Bars_For_Impulse * 2; // Scan a bit after observation end
         // Find the corresponding chart bar indices for these times using iBarShift with 'true' for reliability
         // scan_to_chart_idx will be the NEWEST index >= scan_end_period_time
         // scan_from_chart_idx will be the NEWEST index >= scan_start_period_time
         int scan_to_chart_idx = iBarShift(Symbol(), Period(), scan_end_period_time, true); // Find newest index >= end time
         int scan_from_chart_idx = iBarShift(Symbol(), Period(), scan_start_period_time, true); // Find newest index >= start time
         // Ensure valid indices are found
         if(scan_to_chart_idx < 0 || scan_from_chart_idx < 0) { // Check if indices are found in history
            Print(visual_comment_text + " - Warning: Cannot establish a valid historical index range for initial Order Block scan based on calculated scan times. Insufficient history.");
            g_order_blocks_scanned_today = true; // Avoid trying again today
            return; // This return exits the CalculateAndDrawDailyTimings function
         } // <<<< Ensuring this closing brace is present
         // Ensure scan_to_chart_idx is not older than scan_from_chart_idx (newer index < older index) for scan loop order
         if (scan_to_chart_idx > scan_from_chart_idx) { // This is correct numerical order for newest < oldest
            DetectOrderBlocksForToday(scan_to_chart_idx, scan_from_chart_idx); // Pass newer index, then older index
         }
         else { // Case where start time index is newer or same as end time index (e.g. short period, start and end are same bar or swapped indices if logic error in time calc)
            Print(visual_comment_text + " - Warning: Initial OB scan period too short or indices reversed. Scan from newer index ", scan_to_chart_idx, " back to older index ", scan_from_chart_idx);
            DetectOrderBlocksForToday(scan_from_chart_idx, scan_to_chart_idx); // Still attempt with calculated indices
         }
      } // End if initial bias != 0 and not scanned yet and is current day
   } // End of CalculateAndDrawDailyTimings()
}
//+------------------------------------------------------------------+
//| Checks for a new trading day and performs reset/recalc         |
//| This function runs from OnTimer to ensure daily resets.         |
//+------------------------------------------------------------------+
   void IsNewDayCheckAndReset() {
      datetime server_midnight_today = iTime(Symbol(), PERIOD_D1, 0); // Server midnight of the current day
      // If the server midnight bar time is later than the last time we initialized/reset
      if(server_midnight_today > g_last_initialized_day_time && g_last_initialized_day_time != 0) {
         Print("--- New Day Detected. Resetting EA state for ", TimeToString(server_midnight_today, TIME_DATE), " ---");
         // --- Reset daily state variables ---
         g_InitialBias = 0;
         g_KeyPrice_At_KeyTime = 0;
         g_last_processed_bar_index = -1; // Ensure first bar of new day is processed
         g_bias_determined_today = false;
         g_entry_timed_window_alerted = false; // Allow the entry window check/alert on the new day
         g_order_blocks_scanned_today = false; // Allow OB detection for the new day
         g_key_price_obtained_today = false; // Allow key price to be obtained on new day
         // --- Recalculate and redraw visuals for the new day (cleans old visuals internally) ---
         CalculateAndDrawDailyTimings(); // This function also updates g_last_initialized_day_time and resets OB counts
         // OB detection scan happens within OnTimer after bias is set, OR right after timings on a new day IF bias is already determined
         // The DetectOrderBlocksForToday is called conditionally in CalculateAndDrawDailyTimings now if bias is already determined (like during backtest init past Obs End)
         // Otherwise, OnTimer will call it later after the bias is determined live when the current time reaches Obs End time.
      }
      else if (g_last_initialized_day_time == 0) { // Special case for the very first time OnInit is called or after EA restart
         // This case is handled in OnInit which calls CalculateAndDrawDailyTimings initially.
         // Set g_last_initialized_day_time in CalculateAndDrawDailyTimings if it's 0 there.
         // Added check in CalculateAndDrawDailyTimings for this case.
      }
   }
//+------------------------------------------------------------------+
//| Function to remove all daily visual objects created by this EA   |
//| Removes vertical lines, horizontal lines, and Order Block visuals|
//+------------------------------------------------------------------+
   void RemoveDailyVisualObjects() {
      long chart_id = 0; // Current chart
      // --- Iterate backwards through chart objects to safely remove ---
      for (int i = ObjectsTotal(chart_id) - 1; i >= 0; i--) {
         string obj_name = ObjectName(chart_id, i);
         // Remove our specifically named lines (using substring search for the prefixes used in ObjectCreate)
         if (StringFind(obj_name, "VLine_KeyTime_", 0) == 0 ||
               StringFind(obj_name, "VLine_ObsEnd_", 0) == 0 ||
               StringFind(obj_name, "HLine_KeyPrice_", 0) == 0 || // Still check for this if it was created (though not explicitly drawn in V5.01 logic)
               StringFind(obj_name, "Trend_ObsPrice_", 0) == 0 ) { // Check for the Observation Price Trendline name
            ObjectDelete(chart_id, obj_name);
         }
         // Remove our OB rectangles and labels. Check names starting with OB prefixes or ending with _Label suffix and starting with OB prefix.
         else if (StringFind(obj_name, "BullOB_", 0) == 0) { // Starts with BullOB_ (covers rects)
            ObjectDelete(chart_id, obj_name);
         }
         else if (StringFind(obj_name, "BearOB_", 0) == 0) { // Starts with BearOB_ (covers rects)
            ObjectDelete(chart_id, obj_name);
         }
         else if (StringFind(obj_name, "_Label", StringLen(obj_name) - StringLen("_Label")) >= 0 ) { // Check if name ends with "_Label"
            // Now check if the object this label *belongs* to starts with one of our OB prefixes
            if (StringFind(obj_name, "BullOB_", 0) == 0 || StringFind(obj_name, "BearOB_", 0) == 0) {
               ObjectDelete(chart_id, obj_name); // Delete the label
            }
         }
         // Add more explicit cleanup logic for potential orphan labels if needed based on observation.
      }
      ChartRedraw(0); // Redraw after deletion
   }
//+------------------------------------------------------------------+
//| Update mitigation status of detected Order Blocks                |
//| Checks if price traded completely through the range of detected OBs|
//| Called on each new closed bar. Handles both Rectangles & Stored data|
//+------------------------------------------------------------------+
   void UpdateMitigationStatus(int current_closed_bar_index) {
      // Check only if there are potential OBs to check
      if (g_bullishOB_count == 0 && g_bearishOB_count == 0) return;
      // Iterate through the stored static arrays for both types of OBs
      // Use the PREVIOUS completed bar (index 1) for reliable check
      double check_high = iHigh(Symbol(), Period(), 1);
      double check_low = iLow(Symbol(), Period(), 1);
      for (int i = 0; i < g_bullishOB_count; i++) {
         // Ensure the OB hasn't been mitigated already
         if (!g_bullishOrderBlocks[i].isMitigated ) { // && (TimeCurrent() - g_bullishOrderBlocks[i].startTime < 24 * 3600 * 5) ) // Example: Remove OBs older than 5 days from check
            // Check if the previous completed bar's Low went below the Bullish OB's Low + buffer
            // Use _Point * 2 as a small buffer below OB low for clean penetration check
            if (check_low < g_bullishOrderBlocks[i].low - _Point * 2) {
               g_bullishOrderBlocks[i].isMitigated = true;
               Print(visual_comment_text + " - Bullish Order Block at ", TimeToString(g_bullishOrderBlocks[i].startTime, TIME_DATE|TIME_MINUTES), " mitigated by bar index ", current_closed_bar_index);
               // Update visual object color if drawn and exists
               if(visual_enabled && visual_order_blocks && ObjectFind(0, g_bullishOrderBlocks[i].objectName) > 0) {
                  ObjectSetInteger(0, g_bullishOrderBlocks[i].objectName, OBJPROP_COLOR, ob_mitigated_color);
                  // Update label text and color
                  if (ObjectFind(0, g_bullishOrderBlocks[i].labelName)) {
                     ObjectSetString(0, g_bullishOrderBlocks[i].labelName, OBJPROP_TEXT, "Bull OB Mitigated");
                     ObjectSetInteger(0, g_bullishOrderBlocks[i].labelName, OBJPROP_COLOR, clrGray);
                  }
                  ChartRedraw(0); // Redraw after modifying object
               }
            }
         }
      }
      for (int i = 0; i < g_bearishOB_count; i++) {
         // Ensure the OB hasn't been mitigated already
         if (!g_bearishOrderBlocks[i].isMitigated) { // && (TimeCurrent() - g_bearishOrderBlocks[i].startTime < 24 * 3600 * 5) ) // Optional: cleanup old mitigated OBs from storage
            // Check if the previous completed bar's High went above the Bearish OB's High + buffer
            // Use _Point * 2 as a small buffer above OB high
            if (check_high > g_bearishOrderBlocks[i].high + _Point * 2) {
               g_bearishOrderBlocks[i].isMitigated = true;
               Print(visual_comment_text + " - Bearish Order Block at ", TimeToString(g_bearishOrderBlocks[i].startTime, TIME_DATE|TIME_MINUTES), " mitigated by bar index ", current_closed_bar_index);
               // Update visual object color if drawn and exists
               if(visual_enabled && visual_order_blocks && ObjectFind(0, g_bearishOrderBlocks[i].objectName) > 0) {
                  ObjectSetInteger(0, g_bearishOrderBlocks[i].objectName, OBJPROP_COLOR, ob_mitigated_color);
                  // Update label text and color
                  if (ObjectFind(0, g_bearishOrderBlocks[i].labelName)) {
                     ObjectSetString(0, g_bearishOrderBlocks[i].labelName, OBJPROP_TEXT, "Bear OB Mitigated");
                     ObjectSetInteger(0, g_bearishOrderBlocks[i].labelName, OBJPROP_COLOR, clrGray);
                  }
                  ChartRedraw(0);
               }
            }
         }
      }
   }
//+------------------------------------------------------------------+
//| Basic Check and manage open positions (close at session end)     |
//| --- FOR FUTURE TRADE MANAGEMENT LOGIC ---                      |
//+------------------------------------------------------------------+
   void ManageTrades() {
      // Get current server time
      datetime now = TimeCurrent();
      // Calculate the session end hour in Server Time relative to server midnight
      // Convert Session End time from UTC+2 to GMT (22:00 UTC+2 is 20:00 GMT)
      int session_end_gmt_hour = session_End_UTC2_Hour - 2; // Assuming UTC+2 is GMT+2
      // Calculate the session end hour in Server Time relative to server midnight
      int session_end_server_hour = session_end_gmt_hour + server_GMT_Offset_Manual;
      // Ensure hour is within 0-23
      session_end_server_hour = session_end_server_hour % 24;
      if(session_end_server_hour < 0) session_end_server_hour += 24;
      // Calculate the exact session end datetime for TODAY in server time
      datetime server_midnight_today = iTime(Symbol(), PERIOD_D1, 0); // Server midnight of the current day
      datetime session_end_server_time = (datetime)(server_midnight_today + (long)session_end_server_hour * 3600L + (long)session_End_UTC2_Minute * 60L);
      // Check if current time has passed the session end time for today
      if(now >= session_end_server_time) {
         // Check all open positions for this symbol and magic number
         for (int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong position_ticket = PositionGetTicket(i);
            if (PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_MAGIC) == magic_Number) {
               Print(visual_comment_text + " - Closing trade #", position_ticket, " due to session end time (", TimeToString(now, TIME_DATE|TIME_MINUTES), ").");
               trade.PositionClose(position_ticket); // Close the position
            }
         }
      }
      // --- PLACEHOLDERS for future detailed trade management logic ---
      // Here you will add checks for open positions' profit
      // Apply the +20 pips Break-Even rule
      // Apply the +30 pips Partial Take Profit rule
      // Implement Trailing Stop logic
      // Example: Iterate through open positions
      // if(PositionsTotal() > 0) {
      //    for(int i = PositionsTotal() -1; i >= 0; i--) {
      //      ulong pos_ticket = PositionGetTicket(i);
      //      if(PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_MAGIC) == magic_Number) {
      // Your BE, Partial TP, Trailing Stop logic here
      //      }
      //    }
      // }
   }
//+------------------------------------------------------------------+
//| Function to calculate Lot Size based on risk (Needs real impl.)  |
//| Takes actual SL price or pip distance from entry                 |
//| --- FOR FUTURE TRADE EXECUTION ---                               |
//+------------------------------------------------------------------+
   /*
   // This function needs to correctly calculate lot size based on ACCOUNT_EQUITY,
   // risk_perc, SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE/SIZE), and the distance
   // from the proposed EntryPrice to the calculated StopLossPrice.

   double CalculateLotSize(double risk_perc, double entry_price, double stop_loss_price)
   {
        // Ensure valid inputs
        if (risk_perc <= 0 || risk_perc > 100) { Print("CalculateLotSize Error: Invalid Risk %"); return 0.0; }
        if (entry_price <= 0 || stop_loss_price <= 0) { Print("CalculateLotSize Error: Invalid entry or SL price"); return 0.0;}
        if (AccountInfoDouble(ACCOUNT_EQUITY) <= 0) { Print("CalculateLotSize Error: Account Equity is not positive."); return 0.0;}

        // Calculate risk per share/point
        double risk_per_point = MathAbs(entry_price - stop_loss_price);
         if (risk_per_point <= 0) { Print("CalculateLotSize Error: Stop Loss is at Entry Price."); return 0.0;}

        // Calculate the monetary value of the risk per standard lot (100,000 units or based on symbol volume step if different)
        // Using SYMBOL_TRADE_TICK_VALUE which is usually defined per standard lot (or per base unit with scaling)
        double tick_value = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE); // Value of a tick in deposit currency
        double tick_size = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);   // Size of a tick in quote currency points

        if (tick_value <= 0 || tick_size <= 0) { Print("CalculateLotSize Error: Invalid tick value or size."); return 0.0; }

        // How many ticks is the stop loss? distance_in_points / tick_size
        // Risk per lot = (distance_in_points / tick_size) * tick_value * standard_lot_size_ratio (usually 1 if tick_value is per standard lot)
        // A safer bet might be using SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE) and SYMBOL_VOLUME_STEP if tick_value definition is tricky

        // More robust calc based on monetary value per risk point:
        double risk_per_lot = risk_per_point / tick_size * tick_value * SymbolInfoDouble(Symbol(), SYMBOL_TRADE_CONTRACT_SIZE); // Risk amount in deposit currency per standard lot
        if (risk_per_lot <= 0) { Print("CalculateLotSize Error: Calculated risk per lot is zero or negative."); return 0.0; }


        // Total Risk Amount allowed
        double total_risk_amount = AccountInfoDouble(ACCOUNT_EQUITY) * (risk_perc / 100.0);

        // Required Volume in lots = Total Risk Amount / Risk per Lot
        double volume = total_risk_amount / risk_per_lot;


        // --- Normalize Volume to Symbol Requirements ---
        double min_volume = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
        double max_volume = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
        double volume_step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

        // Ensure calculated volume is at least minimum allowed
        volume = MathMax(volume, min_volume);

        // Round volume down to the nearest step size
        volume = MathFloor(volume / volume_step) * volume_step;

        // Ensure volume does not exceed maximum allowed
        volume = MathMin(volume, max_volume);

         if(volume < min_volume) { Print("CalculateLotSize Warning: Final calculated volume ", volume, " is below minimum allowed ", min_volume, " after normalization."); return 0.0; } // Cannot trade below min


        Print("Calculated Lot Size: ", volume);
        return volume;
   }
   */
//+------------------------------------------------------------------+
//| Placeholder function to check specific Buy Entry Conditions      |
//| YOU WILL INTEGRATE YOUR OB/FVG AND CONFIRMATION LOGIC HERE       |
//| This function runs on the 15th candle bar if bias is bearish (-1)|
//+------------------------------------------------------------------+
   bool YourBuyEntryConditionsMet(int closed_bar_index) {
      // This function runs *exactly* on the 15th M5 candlestick bar IF the Initial Bias was BEARISH (-1)
      // You must find and use detected BULLISH OBs here from the g_bullishOrderBlocks array.
      // Check if price is interacting with them AT THIS BAR and if your confirmation logic is met.
      // --- Iterate through detected BULLISH OBs (stored after bias determination) ---
      // for (int i = 0; i < g_bullishOB_count; i++)
      // {
      //     // Ensure OB is not mitigated and is a BULLISH OB
      //     if (!g_bullishOrderBlocks[i].isMitigated && g_bullishOrderBlocks[i].type == POSITION_TYPE_BUY)
      //     {
      // Check if the price range of the current closed bar ('closed_bar_index') is intersecting with this OB's High/Low range.
      // double current_high = iHigh(Symbol(), Period(), closed_bar_index);
      // double current_low = iLow(Symbol(), Period(), closed_bar_index);
      // Check for interaction (e.g., wick or body crossing into or touching the OB zone)
      // A precise check: Is current low below OB high AND current high above OB low? (Or current low <= OB high if checking wick into upper OB bound)
      // bool price_is_interacting_with_this_ob = (current_low <= g_bullishOrderBlocks[i].high && current_high >= g_bullishOrderBlocks[i].low); // Strict intersect check
      // if (price_is_interacting_with_this_ob)
      // {
      // --- Check for Price Action Confirmation at This Bar (the 15th Candle) ---
      // Example: Check if the 15th candle is a strong bullish rejection from this OB zone.
      // bool confirmed_by_price_action = YourPriceActionConfirmation(closed_bar_index);
      // --- Check for FVG Confluence at This Bar ---
      // Use your FVG detection to see if a relevant (Bullish) FVG is also near this OB / interacted with by this bar.
      // bool fvg_confluence_found = CheckForTradableFVG(closed_bar_index, POSITION_TYPE_BUY); // You need to implement CheckForTradableFVG
      // --- Check HTF Bias (Optional Confluence) ---
      // bool htf_aligned = YourHTFBiasCheck(PERIOD_H1, POSITION_TYPE_BUY);
      // --- If ALL necessary conditions are met for THIS OB and THIS 15th CANDLE ---
      // if (confirmed_by_price_action && fvg_confluence_found && htf_aligned)
      // {
      // BUY setup confirmed! Return true. The EA can then find which OB triggered.
      // You might return the index 'i' of the confirmed OB or a struct containing its details
      // so the PlaceBuyOrder function knows the SL level (OB.low - buffer)
      // Example: Store triggered OB details in a global temp variable or pass a struct pointer
      // g_TriggeredOB = g_bullishOrderBlocks[i];
      // return true; // Setup found based on *this* bullish OB and bar
      // }
      // } // End if price is interacting
      // } // End if OB is active bullish
      // } // End loop through bullish OBs
      // Return false if no BUY setup was confirmed at any relevant Bullish OB for this 15th bar.
      return false; // Default return (no conditions met in placeholder)
   }
//+------------------------------------------------------------------+
//| Placeholder function to check specific Sell Entry Conditions     |
//| YOU WILL INTEGRATE YOUR OB/FVG AND CONFIRMATION LOGIC HERE       |
//| This function runs on the 15th candle bar if bias is bullish (1) |
//+------------------------------------------------------------------+
   bool YourSellEntryConditionsMet(int closed_bar_index) {
      // This function runs *exactly* on the 15th M5 candlestick bar IF the Initial Bias was BULLISH (1)
      // You must find and use detected BEARISH OBs here from the g_bearishOrderBlocks array.
      // Check if price is interacting with them AT THIS BAR and if your confirmation logic is met.
      // --- Iterate through detected BEARISH OBs (stored after bias determination) ---
      // for (int i = 0; i < g_bearishOB_count; i++)
      // {
      //     // Ensure OB is not mitigated and is a BEARISH OB
      //     if (!g_bearishOrderBlocks[i].isMitigated && g_bearishOrderBlocks[i].type == POSITION_TYPE_SELL)
      //     {
      // Check if the price range of the current closed bar ('closed_bar_index') is intersecting with this OB's High/Low range.
      // double current_high = iHigh(Symbol(), Period(), closed_bar_index);
      // double current_low = iLow(Symbol(), Period(), closed_bar_index);
      // Check for interaction (e.g., wick or body crossing into or touching the OB zone)
      // bool price_is_interacting_with_this_ob = (current_low <= g_bearishOrderBlocks[i].high && current_high >= g_bearishOrderBlocks[i].low); // Strict intersect check
      // if (price_is_interacting_with_this_ob)
      // {
      // --- Check for Price Action Confirmation at This Bar (the 15th Candle) ---
      // Example: Check if the 15th candle is a strong bearish rejection from this OB zone, or confirms an M-formation near the OB.
      // bool confirmed_by_price_action = YourPriceActionConfirmation(closed_bar_index); // Adapt for Bearish checks
      // --- Check for FVG Confluence at This Bar ---
      // Use your FVG detection to see if a relevant (Bearish) FVG is also near this OB / interacted with by this bar.
      // bool fvg_confluence_found = CheckForTradableFVG(closed_bar_index, POSITION_TYPE_SELL);
      // --- Check HTF Bias (Optional Confluence) ---
      // bool htf_aligned = YourHTFBiasCheck(PERIOD_H1, POSITION_TYPE_SELL);
      // --- If ALL necessary conditions are met for THIS OB and THIS 15th CANDLE ---
      // if (confirmed_by_price_action && fvg_confluence_found && htf_aligned)
      // {
      // SELL setup confirmed! Return true.
      // You might return the index 'i' of the confirmed OB or its details for SL/TP
      // Example: Store triggered OB details
      // g_TriggeredOB = g_bearishOrderBlocks[i];
      // return true; // Setup found based on *this* bearish OB and bar
      // }
      // } // End if price is interacting
      // } // End if OB is active bearish
      // } // End loop through bearish OBs
      // Return false if no SELL setup was confirmed at any relevant Bearish OB for this 15th bar.
      return false; // Default return (no conditions met in placeholder)
   }
//+------------------------------------------------------------------+
//| Placeholder function to check for tradable FVG/Imbalance       |
//| YOU NEED TO IMPLEMENT THIS                                     |
//+------------------------------------------------------------------+
   /*
   // This function needs to check for FVGs *formed during the manipulation phase*
   // and see if the current bar 'closed_bar_index' is interacting with them, aligning with 'trade_type'.
   bool CheckForTradableFVG(int closed_bar_index, ENUM_POSITION_TYPE trade_type)
   {
        // Example Outline:
        // 1. Identify bars in the manipulation phase (between g_TodayKeyTime_Server and g_ObservationEndTime_Server).
        // 2. Scan these bars for FVGs according to your FVG definition logic. (Gap between High of candle N and Low of candle N+2 for Bullish FVG, Low of N and High of N+2 for Bearish FVG).
        // 3. If a relevant (e.g., Bullish FVG for BUY) FVG is found:
        // 4. Check if the price at 'closed_bar_index' (the 15th candle) is interacting with that FVG's range (wicking into it, partially filling it etc.).
        // 5. Return true if a tradable FVG setup is confirmed, false otherwise.

        Print("Placeholder: CheckForTradableFVG called for bar ", closed_bar_index, ", Type: ", (trade_type == POSITION_TYPE_BUY ? "BUY" : "SELL"));
        return false; // Default
   }
   */
//+------------------------------------------------------------------+
//| Placeholder function to check Higher Timeframe Bias             |
//| --- YOU CAN IMPLEMENT THIS FOR ADDITIONAL CONFLUENCE ---         |
//+------------------------------------------------------------------+
   /*
   bool YourHTFBiasCheck(ENUM_TIMEFRAMES htf, ENUM_POSITION_TYPE expected_trade_type)
   {
        // This function checks if the overall trend or bias on a higher timeframe (e.g., H1) aligns with the expected trade type.
        // Use iMA(), iMACD(), iBearsPower/BullsPower, or simple series of HH/HL and LH/LL checks on the higher timeframe.

        Print("Placeholder: YourHTFBiasCheck called for TF ", EnumToString(htf), ", Expected: ", (expected_trade_type == POSITION_POSITION_BUY ? "BUY" : "SELL")); // Corrected enum
        return true; // Default - assumes HTF bias aligns
   }
   */
//+------------------------------------------------------------------+
//| Placeholder function to check Price Action Confirmation at OB/FVG|
//| --- YOU NEED TO IMPLEMENT THIS ---                             |
//+------------------------------------------------------------------+
   /*
   // This function needs to analyze the specific candlestick pattern(s) on the
   // 'closed_bar_index' (the 15th candle) right at or near the detected OB/FVG to confirm a reversal.
   // It could take parameters about the specific OB/FVG range if needed.
   // For sells, this might also check if the price action at this bar confirms the M-formation structure mentioned in the strategy.
   bool YourPriceActionConfirmation(int closed_bar_index)
   {
         // Example: Basic rejection wick check
         // double current_high = iHigh(Symbol(), Period(), closed_bar_index);
         // double current_low = iLow(Symbol(), Period(), closed_bar_index);
         // double current_open = iOpen(Symbol(), Period(), closed_bar_index);
         // double current_close = iClose(Symbol(), Period(), closed_bar_index);

         // bool bullish_rejection = (current_close > current_open && (current_open - current_low) / GetPipValue() > ... threshold ... ); // Long lower wick
         // bool bearish_rejection = (current_close < current_open && (current_high - current_open) / GetPipValue() > ... threshold ... ); // Long upper wick

         // if (g_InitialBias == -1 && bullish_rejection) return true; // Looking for buys (bias bearish) and got bullish rejection
         // if (g_InitialBias == 1 && bearish_rejection) return true; // Looking for sells (bias bullish) and got bearish rejection


        Print("Placeholder: YourPriceActionConfirmation called for bar ", closed_bar_index);
        return true; // Default
   }
   */
//+------------------------------------------------------------------+
//| Placeholder function to place a Buy Order                        |
//| YOU WILL IMPLEMENT THIS WHEN READY TO TRADE                      |
//| Should take the details of the OB/Zone that triggered the entry  |
//+------------------------------------------------------------------+
   /*
   // Example: Pass the specific Order Block struct or its index that confirmed the entry
   void PlaceBuyOrder(double risk_perc, double sl_buffer_pips, double tp_pips_placeholder, int bar_index, const st_OrderBlock &triggered_ob)
   {
        Print(visual_comment_text + " - Placeholder: PlaceBuyOrder called. Trading disabled in V5.01.");

        // 1. Determine actual entry price (e.g. Ask for instant execution at the triggering bar)
        // double entry_price = NormalizeDouble(SymbolInfoDouble(Symbol(), SYMBOL_ASK), _Digits);
        // Or entry might be based on the OB's price range itself: double entry_price = triggered_ob.high; // Example: entry at top of bullish OB wick

        // 2. Determine actual Stop Loss price level based on the triggering BULLISH OB's LOW + buffer
        // double sl_price = triggered_ob.low - sl_buffer_pips * _Point;

        // 3. Determine actual Take Profit price level (~50 pips or based on previous highs/structure)
        // double tp_price = entry_price + tp_pips_placeholder * _Point; // Simple +pips example
        // OR identify a target structure (previous day/week high/low, next significant range limit etc.)
        // double tp_price = FindBuyTPTarget(entry_price); // You'll implement this

        // 4. Calculate Lot Size based on Risk % and the ACTUAL distance to SL
        //    double actual_sl_pips_distance = MathAbs(entry_price - sl_price) / _Point;
        //    double lot_size = CalculateLotSize(risk_perc, entry_price, sl_price); // Call your updated func

        // 5. Send the order using the 'trade' object (Ensure trade.CheckFx())
        // if (lot_size > 0 && trade.Buy(lot_size, Symbol(), entry_price, sl_price, tp_price, "714 Buy", magic_Number))
        // {
        //      Print(visual_comment_text + " - Attempting BUY order... Ticket=", trade.ResultOrder(), ", Lots=", lot_size, ", Entry=", entry_price, ", SL=", sl_price, ", TP=", tp_price);
        // }
        // else
        //     // Add detailed error logging for trade requests
        // {
        //      Print(visual_comment_text + " - Error placing BUY order: ", GetLastError());
        // }
   }
   */
//+------------------------------------------------------------------+
//| Placeholder function to place a Sell Order                       |
//| YOU WILL IMPLEMENT THIS WHEN READY TO TRADE                      |
//| Should take the details of the OB/Zone that triggered the entry  |
//+------------------------------------------------------------------+
   /*
   // Example: Pass the specific Order Block struct or its index that confirmed the entry
   void PlaceSellOrder(double risk_perc, double sl_buffer_pips, double tp_pips_placeholder, int bar_index, const st_OrderBlock &triggered_ob)
   {
        Print(visual_comment_text + " - Placeholder: PlaceSellOrder called. Trading disabled in V5.01.");

        // 1. Determine actual entry price (e.g. Bid for instant execution at the triggering bar)
        // double entry_price = NormalizeDouble(SymbolInfoDouble(Symbol(), SYMBOL_BID), _Digits);
         // Or entry might be based on the OB's price range itself: double entry_price = triggered_ob.low; // Example: entry at bottom of bearish OB wick


        // 2. Determine actual Stop Loss price level based on the triggering BEARISH OB's HIGH + buffer
        // double sl_price = triggered_ob.high + sl_buffer_pips * _Point;


        // 3. Determine actual Take Profit price level (~50 pips or based on previous lows/structure)
        // double tp_price = entry_price - tp_pips_placeholder * _Point; // Simple -pips example
        // OR identify a target structure (previous day/week high/low, next significant range limit etc.)
        // double tp_price = FindSellTPTarget(entry_price); // You'll implement this

        // 4. Calculate Lot Size based on Risk % and the ACTUAL distance to SL
        //    double actual_sl_pips_distance = MathAbs(entry_price - sl_price) / _Point;
        //    double lot_size = CalculateLotSize(risk_perc, entry_price, sl_price); // Call your updated func


        // 5. Send the order using the 'trade' object
        // if (lot_size > 0 && trade.Sell(lot_size, Symbol(), entry_price, sl_price, tp_price, "714 Sell", magic_Number))
        // {
        //      Print(visual_comment_text + " - Attempting SELL order... Ticket=", trade.ResultOrder(), ", Lots=", lot_size, ", Entry=", entry_price, ", SL=", sl_price, ", TP=", tp_price);
        // }
        // else
        //     // Add detailed error logging for trade requests
        // {
        //      Print(visual_comment_text + " - Error placing SELL order: ", GetLastError());
        // }
   }
