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
//+------------------------------------------------------------------+
//| Input Parameters - Core Strategy Settings                         |
//+------------------------------------------------------------------+

input group "=== Primary Key Time Settings (UTC+2) ==="
input int      utcPlus2_KeyHour_1300     = 13;     // Key Hour (13:00 UTC+2 = 14:00 SAST)
input int      utcPlus2_KeyMinute_1300   = 0;      // Key Minute (0 = 13:00:00 UTC+2)
input group "=== Observation and Entry Settings ==="
input int      observation_Duration_Minutes = 60;   // Minutes to observe price action after Key Time
input int      entry_Candlestick_Index   = 15;     // M5 candle index for entry (15 = 75 mins after Key Time)
input group "=== Dynamic Entry Window Settings ==="
input bool     use_entry_search_window   = true;   // Enable to limit entry search to a specific window
input int      entry_search_end_hour_utc2= 17;     // Hour (UTC+2) to stop searching for new entries (e.g., 17 for 5 PM UTC+2)
input int      entry_search_end_minute_utc2= 0;      // Minute to stop searching for new entries
input group "=== Server Time Settings ==="
input int      server_GMT_Offset_Manual  = 0;      // Server's GMT offset (Check Market Watch > Right-click Time)
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
st_OrderBlock g_triggered_ob_for_trade;          // Stores the OB that triggered the current signal
bool          g_trade_signal_this_bar = false; // Flag to indicate if a signal was generated on the current bar
datetime   g_EntrySearchEndTime_Server; // Server time to stop searching for new entries for the day
datetime   g_last_processed_bar_time_OnTimer = 0; // To track the last bar processed in OnTimer

st_OrderBlock g_bullishOrderBlocks[100]; // Max 100 Bullish OBs per day
int g_bullishOB_count = 0;

st_OrderBlock g_bearishOrderBlocks[100]; // Max 100 Bearish OBs per day
int g_bearishOB_count = 0;

// Add this global variable near the top with other globals
//datetime g_last_processed_bar_time_OnTimer = 0; // Track last processed bar time in OnTimer

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
//double CalculateLotSize(double risk_perc, double entry_price, double stop_loss_price); 
//+------------------------------------------------------------------+
//| Function to calculate Lot Size based on risk                     |
//| Takes actual SL price or pip distance from entry                 |
//+------------------------------------------------------------------+
double CalculateLotSize(double risk_perc, double entry_price, double stop_loss_price)
{
   // Ensure valid inputs
   if (risk_perc <= 0 || risk_perc > 100) { 
      Print("CalculateLotSize Error: Invalid Risk % (", risk_perc, ")"); 
      return 0.0; 
   }
   if (entry_price <= 0 || stop_loss_price <= 0) { 
      Print("CalculateLotSize Error: Invalid entry (", entry_price, ") or SL price (", stop_loss_price,")"); 
      return 0.0;
   }
   if (AccountInfoDouble(ACCOUNT_EQUITY) <= 0) { 
      Print("CalculateLotSize Error: Account Equity is not positive."); 
      return 0.0;
   }

   // Calculate SL distance in points (absolute price difference)
   double sl_distance_price = MathAbs(entry_price - stop_loss_price);
   if (sl_distance_price <= SymbolInfoDouble(Symbol(), (ENUM_SYMBOL_INFO_DOUBLE)SYMBOL_TRADE_STOPS_LEVEL) * _Point) { // Check against min SL distance
      Print("CalculateLotSize Error: Stop Loss distance (", sl_distance_price, ") is too small or zero."); 
      return 0.0;
   }

   // Calculate monetary value of the risk
   double total_risk_amount_currency = AccountInfoDouble(ACCOUNT_EQUITY) * (risk_perc / 100.0);

   // Get information required to calculate loss per lot
   double tick_value = SymbolInfoDouble(Symbol(), (ENUM_SYMBOL_INFO_DOUBLE)SYMBOL_TRADE_TICK_VALUE);   // Value of one tick for one lot
   double tick_size  = SymbolInfoDouble(Symbol(), (ENUM_SYMBOL_INFO_DOUBLE)SYMBOL_TRADE_TICK_SIZE);    // Size of one tick (e.g., 0.00001 for EURUSD)
   double point_value = _Point;                //                технические средства реабилитации. 
   
   if (tick_value <= 0 || tick_size <= 0 || point_value <= 0) {
      Print("CalculateLotSize Error: Invalid symbol properties (TickValue: ", tick_value, ", TickSize: ", tick_size, ", Point: ", point_value,")");
      return 0.0;
   }
   
   // Calculate loss in deposit currency for 1.0 lot if SL is hit
   double loss_per_lot = (sl_distance_price / tick_size) * tick_value; 
   // Alternate way: double loss_per_lot = (sl_distance_price / point_value) * (tick_value / (tick_size / point_value));
   // Simplified if point is a multiple of tick_size: double loss_per_lot = (sl_distance_price / _Point) * SymbolInfoDouble(Symbol(), SYMBOL_TRADE_POINT_VALUE); -> MQL5 might not have SYMBOL_TRADE_POINT_VALUE

   if (loss_per_lot <= 0) {
      Print("CalculateLotSize Error: Calculated loss per lot is zero or negative (", loss_per_lot, ").");
      return 0.0;
   }

   // Calculate desired volume
   double volume = total_risk_amount_currency / loss_per_lot;

   // --- Normalize Volume to Symbol Requirements ---
   double min_volume = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double max_volume = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double volume_step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

   // Adjust volume to step
   volume = MathFloor(volume / volume_step) * volume_step;
   volume = NormalizeDouble(volume, 2); // Standard lot precision is usually 2 decimal places

   // Check against min and max volume
   if (volume < min_volume) {
      Print("CalculateLotSize Warning: Calculated volume ", DoubleToString(volume,2) , " is below minimum ", DoubleToString(min_volume,2), ". Setting to minimum.");
      volume = min_volume;
   }
   if (volume > max_volume) {
      Print("CalculateLotSize Warning: Calculated volume ", DoubleToString(volume,2), " exceeds maximum ", DoubleToString(max_volume,2), ". Setting to maximum.");
      volume = max_volume;
   }
   // Final check if still below min_volume after adjustments (e.g., if total_risk_amount_currency is too small)
   if (volume < min_volume && min_volume > 0) {
      Print("CalculateLotSize Error: Final calculated volume ", DoubleToString(volume,2), " is still below minimum ", DoubleToString(min_volume,2), " for allowed risk. Cannot trade.");
      return 0.0; 
   }

   Print(visual_comment_text + " - CalculateLotSize: Risk ", risk_perc, "%, SL Dist Price ", sl_distance_price, ", Loss/Lot ", loss_per_lot, ", Calc Volume ", volume);
   return volume;
}

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
// void OnTimer()
// {
//    // --- Check for New Day and Re-initialize Timings if needed ---
//    IsNewDayCheckAndReset();
   
//    // --- Process logic only on a NEW M5 closed bar ---
//    int total_bars = Bars(Symbol(), Period());
//    if (total_bars <= 1) return;
   
//    datetime current_completed_bar_time = iTime(Symbol(), Period(), 1); // Time of the *last fully completed bar*
//    if (current_completed_bar_time <= g_last_processed_bar_time_OnTimer) // Use time-based tracking
//    { // No new bar has closed since last OnTimer check
//       return;
//    }
//    g_last_processed_bar_time_OnTimer = current_completed_bar_time; // Update time of last processed completed bar
//    int current_completed_bar_chart_idx = 1; // We are always analyzing bar at index 1 in OnTimer as "current closed bar"

//    //Print("Processing New Closed Bar at Server Time: ", TimeToString(current_completed_bar_time, TIME_DATE|TIME_MINUTES), " (Chart Index: 1)");
//    //Print("Key Time Server Time: ", TimeToString(g_TodayKeyTime_Server, TIME_DATE|TIME_MINUTES));
   
//    // --- Obtain Key Price and Draw Observation Price Line once the key time bar opens/is available ---
//    if(current_completed_bar_time == g_TodayKeyTime_Server)
//    {
//         Print(visual_comment_text + " - Key Time bar reached at Server Time: ", TimeToString(current_completed_bar_time, TIME_DATE|TIME_MINUTES));
//    }
//    if (visual_enabled && visual_obs_price_line && !g_key_price_obtained_today && current_completed_bar_time >= g_TodayKeyTime_Server) 
//    {
//       // Find the bar index that starts exactly at or immediately after the Key Time
//       int key_time_actual_bar_idx = iBarShift(Symbol(), Period(), g_TodayKeyTime_Server, false);
//       if (key_time_actual_bar_idx >= 0 && key_time_actual_bar_idx < Bars(Symbol(), Period())) 
//       {
//          // Found the actual bar corresponding to the key time or first one after. Get its Open price.
//          g_KeyPrice_At_KeyTime = iOpen(Symbol(), Period(), key_time_actual_bar_idx);
//          if (g_KeyPrice_At_KeyTime > 0) 
//          { // Ensure a valid price was obtained (iOpen can return 0 if no data)
//             Print(visual_comment_text + " - Key Price obtained at Server Time: ", TimeToString(iTime(Symbol(),Period(),key_time_actual_bar_idx), TIME_DATE|TIME_MINUTES), ", Price: ", DoubleToString(g_KeyPrice_At_KeyTime, Digits()));
//             // Now draw the TREND object (horizontal line segment) using the accurate key price
//             string obs_price_line_name = "Trend_ObsPrice_" + Symbol() + "_" + EnumToString(Period()) + "_" + TimeToString(g_TodayKeyTime_Server, TIME_DATE|TIME_MINUTES|TIME_SECONDS);
//             // Ensure previous object is removed before creating (safer in OnTimer if reloads occur)
            
//             if(ObjectFind(0, obs_price_line_name) > 0) ObjectDelete(0, obs_price_line_name);
//             // Create the TREND object from Key Time to Observation End Time at the Key Price level
            
//             if(ObjectCreate(0, obs_price_line_name, OBJ_TREND, 0, g_TodayKeyTime_Server, g_KeyPrice_At_KeyTime, g_ObservationEndTime_Server, g_KeyPrice_At_KeyTime)) {
//                ObjectSetInteger(0, obs_price_line_name, OBJPROP_COLOR, obs_price_line_color);
//                ObjectSetInteger(0, obs_price_line_name, OBJPROP_STYLE, STYLE_SOLID);
//                ObjectSetInteger(0, obs_price_line_name, OBJPROP_WIDTH, 1);
//                ObjectSetInteger(0, obs_price_line_name, OBJPROP_SELECTABLE, false);
//                ObjectSetInteger(0, obs_price_line_name, OBJPROP_BACK, true);
//                ObjectSetString(0, obs_price_line_name, OBJPROP_TEXT, visual_comment_text + ": Obs Price Level");
//                ObjectSetInteger(0, obs_price_line_name, OBJPROP_RAY, false);
//                ObjectSetInteger(0, obs_price_line_name, OBJPROP_HIDDEN, true); // Hide on lower/higher TFs
//                ChartRedraw(0);
//                Print(visual_comment_text + " - Observation Price Trend line drawn successfully.");
//             }
//             else {
//                Print("Warning: Observation Price Trend line creation failed (GetLastError: ", GetLastError(), ").");
//             }
//          }
//          else {
//             Print("Warning: Failed to obtain valid Key Price at Server Time ", TimeToString(iTime(Symbol(), Period(), key_time_actual_bar_idx), TIME_DATE|TIME_MINUTES), ". Price was 0 or invalid.");
//          }
//          g_key_price_obtained_today = true; // Mark as attempted/obtained for today regardless of price validity or drawing success
//       }
//       else {
//          Print("Warning: Key Time bar index not found even though current time is after Key Time.");
//       }
//    }

//    //--- Step 4: Initial Trend Observation (Determine Bias) ---
//    if (!g_bias_determined_today && current_completed_bar_time >= g_ObservationEndTime_Server) {
//       Print("--- Attempting Bias Determination ---");
//       Print("g_TodayKeyTime_Server: ", TimeToString(g_TodayKeyTime_Server, TIME_DATE|TIME_SECONDS));
//       Print("g_ObservationEndTime_Server: ", TimeToString(g_ObservationEndTime_Server, TIME_DATE|TIME_SECONDS));

//       int key_bar_idx = iBarShift(Symbol(), Period(), g_TodayKeyTime_Server, false);
//       Print("key_bar_idx from iBarShift for g_TodayKeyTime_Server: ", key_bar_idx);
//       if(key_bar_idx >= 0) Print("Time of key_bar_idx: ", TimeToString(iTime(Symbol(),Period(),key_bar_idx), TIME_DATE|TIME_SECONDS));

//       int obs_end_bar_idx = iBarShift(Symbol(), Period(), g_ObservationEndTime_Server, false);
//       Print("obs_end_bar_idx from iBarShift for g_ObservationEndTime_Server: ", obs_end_bar_idx);
//       if(obs_end_bar_idx >= 0) Print("Time of obs_end_bar_idx: ", TimeToString(iTime(Symbol(),Period(),obs_end_bar_idx), TIME_DATE|TIME_SECONDS));

//       // Ensure we found both relevant bars and they are valid indices
//       if (key_bar_idx >= 0 && obs_end_bar_idx >= 0 && 
//           obs_end_bar_idx < Bars(Symbol(), Period()) && // obs_end_bar_idx must be a valid index on chart
//           key_bar_idx < Bars(Symbol(), Period()) &&   // key_bar_idx must also be a valid index
//           obs_end_bar_idx <= key_bar_idx)           // Obs end bar index should be newer or same as key time bar index
//       {
//          double price_at_obs_end = iClose(Symbol(), Period(), obs_end_bar_idx); // Price at CLOSE of the obs end bar
//          double price_at_keytime = iOpen(Symbol(), Period(), key_bar_idx);    // Price at OPEN of the key time bar
         
//          Print("Price at Key Time (", TimeToString(iTime(Symbol(),Period(),key_bar_idx), TIME_DATE|TIME_SECONDS), "): ", price_at_keytime);
//          Print("Price at Obs End (", TimeToString(iTime(Symbol(),Period(),obs_end_bar_idx), TIME_DATE|TIME_SECONDS), "): ", price_at_obs_end);
         
//          if (price_at_obs_end > price_at_keytime) {
//             g_InitialBias = 1; // Market moved up after the Key Time (Looking for SELL opportunities)
//             Print(visual_comment_text + " - Initial Bias determined: BULLISH movement after Key Time. Look for SELLS.");
//          }
//          else if (price_at_obs_end < price_at_keytime) {
//             g_InitialBias = -1; // Market moved down after the Key Time (Looking for BUY opportunities)
//             Print(visual_comment_text + " - Initial Bias determined: BEARISH movement after Key Time. Look for BUYS.");
//          }
//          else {
//             g_InitialBias = 0; // No clear move, or very small
//             Print(visual_comment_text + " - Initial Bias determined: SIDEWAYS/NO CLEAR TREND after Key Time. Skipping trading based on this strategy today.");
//          }
//          g_bias_determined_today = true; // Set this *after* successfully determining bias
         
//          // --- After bias is determined, perform OB detection scan if not already done for today ---
//          if (!g_order_blocks_scanned_today) {
//             datetime scan_start_period_time = g_TodayKeyTime_Server - PeriodSeconds(Period()) * ob_MaxBlockCandles * 2;
//             datetime scan_end_period_time = g_ObservationEndTime_Server + PeriodSeconds(Period()) * ob_Lookback_Bars_For_Impulse * 2;
            
//             int scan_to_chart_idx = iBarShift(Symbol(), Period(), scan_end_period_time, true);
//             int scan_from_chart_idx = iBarShift(Symbol(), Period(), scan_start_period_time, true);
            
//             if(scan_to_chart_idx < 0 || scan_from_chart_idx < 0) {
//                Print(visual_comment_text + " - Warning: Cannot establish a valid historical index range for Order Block detection scan based on calculated scan times.");
//                Print(" Calculated scan times: From ", TimeToString(scan_start_period_time, TIME_DATE|TIME_MINUTES), " to ", TimeToString(scan_end_period_time, TIME_DATE|TIME_MINUTES));
//                g_order_blocks_scanned_today = true;
//                return;
//             }
            
//             if (scan_to_chart_idx > scan_from_chart_idx) {
//                int temp = scan_to_chart_idx;
//                scan_to_chart_idx = scan_from_chart_idx;
//                scan_from_chart_idx = temp;
//             }
            
//             if(scan_from_chart_idx + MathMax(ob_Lookback_Bars_For_Impulse, ob_MaxBlockCandles) >= Bars(Symbol(), Period())) {
//                Print(visual_comment_text + " - Not enough historical bars available to perform OB detection scan with required lookahead from the oldest scan index.");
//                g_order_blocks_scanned_today = true;
//                return;
//             }
            
//             DetectOrderBlocksForToday(scan_to_chart_idx, scan_from_chart_idx);
//          }
//       }
//       else {
//          Print("Warning: Could not determine relevant bar indices for initial bias determination. key_bar_idx=", key_bar_idx, ", obs_end_bar_idx=", obs_end_bar_idx);
//          g_InitialBias = 0; // Keep it undetermined, try on next bar
//       }
//    }

//    //--- DYNAMIC ENTRY LOGIC: Check for entry conditions on *every new bar* after bias is set AND within the entry search window ---
//    g_trade_signal_this_bar = false; // Reset for current bar check

//    if (g_bias_determined_today && g_InitialBias != 0 && !PositionsTotal() > 0) // Ensure bias is set, not neutral, and no existing position
//    {
//        // Check if we are within the allowed entry search window (if enabled)
//        bool within_entry_search_window = true;
//        if(use_entry_search_window && g_EntrySearchEndTime_Server > 0)
//        {
//            if(current_completed_bar_time > g_EntrySearchEndTime_Server)
//            {
//                within_entry_search_window = false;
//                if(!g_entry_timed_window_alerted) {
//                    Print(visual_comment_text + " - Dynamic Entry Search Window has ended for today at ", TimeToString(g_EntrySearchEndTime_Server, TIME_DATE|TIME_MINUTES), ". No new entries will be sought.");
//                    g_entry_timed_window_alerted = true;
//                }
//            }
//        }

//        if(within_entry_search_window)
//        {
//            Print(visual_comment_text + " - Searching for dynamic entry. Current completed bar time: ", TimeToString(current_completed_bar_time, TIME_DATE|TIME_MINUTES));
//            bool entry_conditions_met = false;
//            if (g_InitialBias == -1) { // Looking for BUYS
//                entry_conditions_met = YourBuyEntryConditionsMet(current_completed_bar_chart_idx);
//                if (entry_conditions_met && g_trade_signal_this_bar) {
//                    Print(visual_comment_text + " - Dynamic Buy Entry conditions met by OB @ ", TimeToString(g_triggered_ob_for_trade.startTime, TIME_DATE|TIME_MINUTES));
//                    PlaceBuyOrder(risk_Percent_Placeholder, stop_Loss_Buffer_Pips, take_Profit_Pips_Placeholder, current_completed_bar_chart_idx, g_triggered_ob_for_trade);
//                }
//            }
//            else if (g_InitialBias == 1) { // Looking for SELLS
//                entry_conditions_met = YourSellEntryConditionsMet(current_completed_bar_chart_idx);
//                if (entry_conditions_met && g_trade_signal_this_bar) {
//                    Print(visual_comment_text + " - Dynamic Sell Entry conditions met by OB @ ", TimeToString(g_triggered_ob_for_trade.startTime, TIME_DATE|TIME_MINUTES));
//                    PlaceSellOrder(risk_Percent_Placeholder, stop_Loss_Buffer_Pips, take_Profit_Pips_Placeholder, current_completed_bar_chart_idx, g_triggered_ob_for_trade);
//                }
//            }
//        }
//    }

//    //--- Update mitigation status of detected Order Blocks as price moves ---
//    UpdateMitigationStatus(current_completed_bar_chart_idx);
   
//    //--- Step 6: Manage Trades (e.g., close at session end, BE, TP, Trailing) ---
//    ManageTrades();
// }
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
   
   datetime current_completed_bar_time = iTime(Symbol(), Period(), 1); // Time of the *last fully completed bar*
   if (current_completed_bar_time <= g_last_processed_bar_time_OnTimer) // Use time-based tracking
   { // No new bar has closed since last OnTimer check
      return;
   }
   g_last_processed_bar_time_OnTimer = current_completed_bar_time; // Update time of last processed completed bar
   int current_completed_bar_chart_idx = 1; // We are always analyzing bar at index 1 in OnTimer as "current closed bar"

   //Print("Processing New Closed Bar at Server Time: ", TimeToString(current_completed_bar_time, TIME_DATE|TIME_MINUTES), " (Chart Index: 1)");
   //Print("Key Time Server Time: ", TimeToString(g_TodayKeyTime_Server, TIME_DATE|TIME_MINUTES));
   
   // --- Obtain Key Price and Draw Observation Price Line once the key time bar opens/is available ---
   if(current_completed_bar_time == g_TodayKeyTime_Server) // More for live visual tracking if needed
   {
        Print(visual_comment_text + " - Key Time bar exactly reached at Server Time: ", TimeToString(current_completed_bar_time, TIME_DATE|TIME_MINUTES));
   }
   if (visual_enabled && visual_obs_price_line && !g_key_price_obtained_today && current_completed_bar_time >= g_TodayKeyTime_Server) 
   {
      int key_time_actual_bar_idx = iBarShift(Symbol(), Period(), g_TodayKeyTime_Server, false);
      if (key_time_actual_bar_idx >= 0 && key_time_actual_bar_idx < Bars(Symbol(), Period())) 
      {
         g_KeyPrice_At_KeyTime = iOpen(Symbol(), Period(), key_time_actual_bar_idx);
         if (g_KeyPrice_At_KeyTime > 0) 
         { 
            Print(visual_comment_text + " - Key Price obtained at Server Time: ", TimeToString(iTime(Symbol(),Period(),key_time_actual_bar_idx), TIME_DATE|TIME_MINUTES), ", Price: ", DoubleToString(g_KeyPrice_At_KeyTime, Digits()));
            string obs_price_line_name = "Trend_ObsPrice_" + Symbol() + "_" + EnumToString(Period()) + "_" + TimeToString(g_TodayKeyTime_Server, TIME_DATE|TIME_MINUTES|TIME_SECONDS);
            if(ObjectFind(0, obs_price_line_name) > 0) ObjectDelete(0, obs_price_line_name);
            if(ObjectCreate(0, obs_price_line_name, OBJ_TREND, 0, g_TodayKeyTime_Server, g_KeyPrice_At_KeyTime, g_ObservationEndTime_Server, g_KeyPrice_At_KeyTime)) {
               ObjectSetInteger(0, obs_price_line_name, OBJPROP_COLOR, obs_price_line_color); /* ... other props ... */
               Print(visual_comment_text + " - Observation Price Trend line drawn successfully.");
            } else { Print("Warning: Observation Price Trend line creation failed (GetLastError: ", GetLastError(), ")."); }
         } else { Print("Warning: Failed to obtain valid Key Price..."); }
         g_key_price_obtained_today = true; 
      } else { Print("Warning: Key Time bar index not found (for key price) even though current time is after Key Time."); }
   }

   //--- Step 4: Initial Trend Observation (Determine Bias) ---
   if (!g_bias_determined_today && current_completed_bar_time >= g_ObservationEndTime_Server) {
      Print("--- Attempting Bias Determination ---");
      Print("g_TodayKeyTime_Server: ", TimeToString(g_TodayKeyTime_Server, TIME_DATE|TIME_SECONDS));
      Print("g_ObservationEndTime_Server: ", TimeToString(g_ObservationEndTime_Server, TIME_DATE|TIME_SECONDS));

      int key_bar_idx = iBarShift(Symbol(), Period(), g_TodayKeyTime_Server, false);
      Print("key_bar_idx from iBarShift for g_TodayKeyTime_Server: ", key_bar_idx);
      if(key_bar_idx >= 0) Print("Time of key_bar_idx: ", TimeToString(iTime(Symbol(),Period(),key_bar_idx), TIME_DATE|TIME_SECONDS));

      int obs_end_bar_idx = iBarShift(Symbol(), Period(), g_ObservationEndTime_Server, false);
      Print("obs_end_bar_idx from iBarShift for g_ObservationEndTime_Server: ", obs_end_bar_idx);
      if(obs_end_bar_idx >= 0) Print("Time of obs_end_bar_idx: ", TimeToString(iTime(Symbol(),Period(),obs_end_bar_idx), TIME_DATE|TIME_SECONDS));

      if (key_bar_idx >= 0 && obs_end_bar_idx >= 0 && 
          obs_end_bar_idx < Bars(Symbol(), Period()) && 
          key_bar_idx < Bars(Symbol(), Period()) &&   
          obs_end_bar_idx <= key_bar_idx)          
      {
         double price_at_obs_end = iClose(Symbol(), Period(), obs_end_bar_idx); 
         double price_at_keytime = iOpen(Symbol(), Period(), key_bar_idx);    
         
         Print("Price at Key Time (", TimeToString(iTime(Symbol(),Period(),key_bar_idx), TIME_DATE|TIME_SECONDS), "): ", price_at_keytime);
         Print("Price at Obs End (", TimeToString(iTime(Symbol(),Period(),obs_end_bar_idx), TIME_DATE|TIME_SECONDS), "): ", price_at_obs_end);
         
         if (price_at_obs_end > price_at_keytime) {
            g_InitialBias = 1; 
            Print(visual_comment_text + " - Initial Bias determined: BULLISH movement after Key Time. Look for SELLS.");
         }
         else if (price_at_obs_end < price_at_keytime) {
            g_InitialBias = -1; 
            Print(visual_comment_text + " - Initial Bias determined: BEARISH movement after Key Time. Look for BUYS.");
         }
         else {
            g_InitialBias = 0; 
            Print(visual_comment_text + " - Initial Bias determined: SIDEWAYS/NO CLEAR TREND after Key Time. Skipping trading based on this strategy today.");
         }
         g_bias_determined_today = true; 
         
         // --- <<<< APPLY OB DETECTION SCAN CHANGES HERE >>>> ---
         // After bias is determined, perform OB detection scan if not already done for today
         if (g_InitialBias != 0 && !g_order_blocks_scanned_today) 
         {
             // Define the time window within which we believe relevant OBs might have formed
             datetime ob_scan_window_start_time;
             datetime ob_scan_window_end_time;

             if (scan_before_obs_end_only) {
                 ob_scan_window_start_time = g_TodayKeyTime_Server - PeriodSeconds(PERIOD_M5) * (ob_MaxBlockCandles + 5); // e.g., look before Key Time
                 ob_scan_window_end_time   = g_ObservationEndTime_Server - PeriodSeconds(PERIOD_M5); // Bar *before* obs end
             } else {
                 ob_scan_window_start_time = g_TodayKeyTime_Server - PeriodSeconds(PERIOD_M5) * (ob_MaxBlockCandles + 5);
                 ob_scan_window_end_time   = g_ObservationEndTime_Server + PeriodSeconds(PERIOD_M5) * 5; // e.g., 5 bars after obs end
             }

             // Get the chart indices for this historical scan window.
             // `false` for `exact` in iBarShift helps find the bar at or immediately after the specified time.
             int scan_oldest_bar_idx = iBarShift(Symbol(), Period(), ob_scan_window_start_time, false); 
             int scan_newest_bar_idx = iBarShift(Symbol(), Period(), ob_scan_window_end_time, false);   

             Print(visual_comment_text + " - OB Scan Trigger Info:");
             Print("  Scan Window Start Time: ", TimeToString(ob_scan_window_start_time, TIME_DATE|TIME_SECONDS), " -> Index (older): ", scan_oldest_bar_idx);
             Print("  Scan Window End Time:   ", TimeToString(ob_scan_window_end_time, TIME_DATE|TIME_SECONDS), " -> Index (newer): ", scan_newest_bar_idx);

             if (scan_oldest_bar_idx >= 0 && scan_newest_bar_idx >= 0 && scan_newest_bar_idx <= scan_oldest_bar_idx)
             {
                 Print("  Valid scan index range for DetectOrderBlocks: newest_idx=", scan_newest_bar_idx, ", oldest_idx=", scan_oldest_bar_idx);
                 DetectOrderBlocksForToday(scan_newest_bar_idx, scan_oldest_bar_idx); 
             }
             else
             {
                 Print(visual_comment_text + " - Warning: Cannot establish a valid historical index range for OB scan. Check scan times/indices.");
                 Print("  Failed Indices: scan_oldest_bar_idx=", scan_oldest_bar_idx, ", scan_newest_bar_idx=", scan_newest_bar_idx);
                 g_order_blocks_scanned_today = true; // Mark as attempted
             }
         }
         // --- <<<< END OF OB DETECTION SCAN CHANGES >>>> ---
      }
      else {
         Print("Warning: Could not determine relevant bar indices for initial bias determination. key_bar_idx=", key_bar_idx, ", obs_end_bar_idx=", obs_end_bar_idx);
         g_InitialBias = 0; // Keep it undetermined
         // Note: Do not set g_bias_determined_today = true here; let it retry on the next bar.
      }
   }

   //--- DYNAMIC ENTRY LOGIC --- (No changes here needed from last version we discussed)
   g_trade_signal_this_bar = false; 

   if (g_bias_determined_today && g_InitialBias != 0) // No need for !PositionsTotal() check here if PlaceOrder handles it
   {
       bool within_entry_search_window = true;
       if(use_entry_search_window && g_EntrySearchEndTime_Server > 0)
       {
           if(current_completed_bar_time > g_EntrySearchEndTime_Server)
           {
               within_entry_search_window = false;
               if(!g_entry_timed_window_alerted) {
                   Print(visual_comment_text + " - Dynamic Entry Search Window has ended for today at ", TimeToString(g_EntrySearchEndTime_Server, TIME_DATE|TIME_MINUTES), ". No new entries will be sought.");
                   g_entry_timed_window_alerted = true;
               }
           }
       }

       if(within_entry_search_window)
       {
           // Only attempt trade if no current position for this EA/symbol (moved check here)
           bool existing_trade = false;
           for(int i = PositionsTotal() - 1; i >= 0; i--) {
               if (PositionGetInteger(POSITION_MAGIC) == magic_Number && PositionGetString(POSITION_SYMBOL) == Symbol()) {
                   existing_trade = true;
                   break;
               }
           }

           if(!existing_trade) { // Only proceed if no trade open
               //Print(visual_comment_text + " - Searching for dynamic entry. Current completed bar time: ", TimeToString(current_completed_bar_time, TIME_DATE|TIME_MINUTES));
               bool entry_conditions_met = false;
               if (g_InitialBias == -1) { 
                   entry_conditions_met = YourBuyEntryConditionsMet(current_completed_bar_chart_idx);
                   if (entry_conditions_met && g_trade_signal_this_bar) {
                       Print(visual_comment_text + " - Dynamic Buy Entry conditions met by OB @ ", TimeToString(g_triggered_ob_for_trade.startTime, TIME_DATE|TIME_MINUTES));
                       PlaceBuyOrder(risk_Percent_Placeholder, stop_Loss_Buffer_Pips, take_Profit_Pips_Placeholder, current_completed_bar_chart_idx, g_triggered_ob_for_trade);
                   }
               }
               else if (g_InitialBias == 1) { 
                   entry_conditions_met = YourSellEntryConditionsMet(current_completed_bar_chart_idx);
                   if (entry_conditions_met && g_trade_signal_this_bar) {
                       Print(visual_comment_text + " - Dynamic Sell Entry conditions met by OB @ ", TimeToString(g_triggered_ob_for_trade.startTime, TIME_DATE|TIME_MINUTES));
                       PlaceSellOrder(risk_Percent_Placeholder, stop_Loss_Buffer_Pips, take_Profit_Pips_Placeholder, current_completed_bar_chart_idx, g_triggered_ob_for_trade);
                   }
               }
           } // End if !existing_trade
       } // End if within_entry_search_window
   } // End if bias determined

   //--- Update mitigation status of detected Order Blocks as price moves ---
   UpdateMitigationStatus(current_completed_bar_chart_idx);
   
   //--- Step 6: Manage Trades (e.g., close at session end, BE, TP, Trailing) ---
   ManageTrades();
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
//+------------------------------------------------------------------+
//| Check if a candle at 'index_in_array' is a Bullish OB candidate  |
//| (Original bearish candle, followed by bullish impulse)           |
//| Assumes array[0] is oldest data in the copied segment.           |
//| 'index_in_array' is the index of the candidate OB candle itself. |
//+------------------------------------------------------------------+
bool IsBullishOrderBlockCandidate(int index_in_array,         // Index of the candidate bearish candle in the COPIED array
                                const double &open_arr[], 
                                const double &high_arr[], 
                                const double &low_arr[], 
                                const double &close_arr[], 
                                int array_size)              // Total size of the copied array (number_of_bars_to_actually_copy)
{
   // 1. Candidate candle (at index_in_array) must be bearish
   if (close_arr[index_in_array] >= open_arr[index_in_array]) return false;

   // 2. Check for Impulsive Bullish Move *after* (at numerically higher indices) the candidate candle.
   //    This impulse must occur within 'ob_Lookback_Bars_For_Impulse' bars
   //    and must comprise at least 2 consecutive bullish candles that contribute to the min move.
   
   // Pre-check: Ensure there are enough bars AFTER the candidate for the required lookbacks.
   int max_lookahead_needed = MathMax(ob_Lookback_Bars_For_Impulse, ob_MaxBlockCandles -1); // -1 for MaxBlockCandles as it includes the current
   if (index_in_array + 1 + max_lookahead_needed >= array_size) { 
      // Not enough data *after* the candidate in the copied array for a full check.
      // Print("IsBullishOB: Candidate at arr_idx ", index_in_array, " lacks sufficient lookahead data. Array size: ", array_size);
      return false; 
   }

   double cumulative_bullish_move_points = 0;
   bool strong_impulse_found = false;
   int consecutive_bullish_candles_in_impulse = 0;

   // Loop for ob_Lookback_Bars_For_Impulse *after* the candidate: from (index_in_array + 1)
   for (int i = 1; i <= ob_Lookback_Bars_For_Impulse; i++) 
   {
      int current_impulse_check_idx = index_in_array + i;
      // This boundary check should ideally be covered by the pre-check above, but double-check for safety.
      if (current_impulse_check_idx >= array_size) break; 

      if (close_arr[current_impulse_check_idx] > open_arr[current_impulse_check_idx]) // Is it a bullish candle?
      {
         cumulative_bullish_move_points += (close_arr[current_impulse_check_idx] - open_arr[current_impulse_check_idx]);
         consecutive_bullish_candles_in_impulse++;

         // Check if min pips move achieved AND at least 2 consecutive bullish candles formed this part of impulse
         if ((cumulative_bullish_move_points / GetPipValue()) >= ob_MinMovePips && consecutive_bullish_candles_in_impulse >= 2) 
         {
            strong_impulse_found = true;
            break; // Sufficient impulse found
         }
      } 
      else // Non-bullish candle encountered, reset consecutive count and check
      {
         // If strict consecutive is needed FOR THE WHOLE IMPULSE, then break here.
         // If any bullish segment contributing to total pips move counts:
         // cumulative_bullish_move_points += (close_arr[current_impulse_check_idx] - open_arr[current_impulse_check_idx]); // Still add if non-bullish if that's the definition
         // For now, let's assume the impulse must be predominantly by consecutive bullish bars
         break; // Your previous logic implies a break on non-directional candle.
      }
   }
   if (!strong_impulse_found) return false;

   // 3. Validate OB Structure: No candle within the 'ob_MaxBlockCandles' period 
   //    (starting from the candidate candle at index_in_array and including up to ob_MaxBlockCandles-1 newer candles)
   //    should have a high greater than the candidate candle's high.
   double candidate_ob_high = high_arr[index_in_array]; // The high of the initial bearish candle
   for (int j = 0; j < ob_MaxBlockCandles; j++) 
   {
      int block_structure_check_idx = index_in_array + j;
      if (block_structure_check_idx >= array_size) break; // Boundary check

      if (high_arr[block_structure_check_idx] > candidate_ob_high) 
      {
         return false; // A candle forming the block had a higher high than the originating bearish candle
      }
   }
   
   return true; // All conditions for a Bullish OB met
}


//+------------------------------------------------------------------+
//| Check if a candle at 'index_in_array' is a Bearish OB candidate  |
//| (Original bullish candle, followed by bearish impulse)           |
//| Assumes array[0] is oldest data in the copied segment.           |
//| 'index_in_array' is the index of the candidate OB candle itself. |
//+------------------------------------------------------------------+
bool IsBearishOrderBlockCandidate(int index_in_array,       // Index of the candidate bullish candle in the COPIED array
                                 const double &open_arr[], 
                                 const double &high_arr[], 
                                 const double &low_arr[], 
                                 const double &close_arr[], 
                                 int array_size)            // Total size of the copied array
{
   // 1. Candidate candle (at index_in_array) must be bullish
   if (close_arr[index_in_array] <= open_arr[index_in_array]) return false;

   // 2. Check for Impulsive Bearish Move *after* (at numerically higher indices) the candidate candle.
   // Pre-check: Ensure there are enough bars AFTER the candidate.
   int max_lookahead_needed = MathMax(ob_Lookback_Bars_For_Impulse, ob_MaxBlockCandles -1);
   if (index_in_array + 1 + max_lookahead_needed >= array_size) {
      // Print("IsBearishOB: Candidate at arr_idx ", index_in_array, " lacks sufficient lookahead data. Array size: ", array_size);
      return false; 
   }

   double cumulative_bearish_move_points = 0;
   bool strong_impulse_found = false;
   int consecutive_bearish_candles_in_impulse = 0;

   // Loop for ob_Lookback_Bars_For_Impulse *after* the candidate
   for (int i = 1; i <= ob_Lookback_Bars_For_Impulse; i++) 
   {
      int current_impulse_check_idx = index_in_array + i;
      if (current_impulse_check_idx >= array_size) break;

      if (close_arr[current_impulse_check_idx] < open_arr[current_impulse_check_idx]) // Is it a bearish candle?
      {
         cumulative_bearish_move_points += (open_arr[current_impulse_check_idx] - close_arr[current_impulse_check_idx]);
         consecutive_bearish_candles_in_impulse++;

         if ((cumulative_bearish_move_points / GetPipValue()) >= ob_MinMovePips && consecutive_bearish_candles_in_impulse >= 2) 
         {
            strong_impulse_found = true;
            break;
         }
      } 
      else // Non-bearish candle encountered
      {
         break; 
      }
   }
   if (!strong_impulse_found) return false;

   // 3. Validate OB Structure: No candle within the 'ob_MaxBlockCandles' period 
   //    (starting from the candidate candle and including newer candles)
   //    should have a low lower than the candidate candle's low.
   double candidate_ob_low = low_arr[index_in_array]; // The low of the initial bullish candle
   for (int j = 0; j < ob_MaxBlockCandles; j++) 
   {
      int block_structure_check_idx = index_in_array + j;
      if (block_structure_check_idx >= array_size) break;

      if (low_arr[block_structure_check_idx] < candidate_ob_low) 
      {
         return false; // A candle forming the block had a lower low than the originating bullish candle
      }
   }

   return true; // All conditions for a Bearish OB met
}
 
 


//+------------------------------------------------------------------+
//| Detects and Stores Order Blocks formed around the Key Time       |
//| Runs once per day after initial bias determination               |
//| Scan range limited to the expected manipulation period (Stage 2) |
//| scan_newest_chart_index is the newer chart index, scan_oldest_chart_index is the older chart index |
//+------------------------------------------------------------------+
// The function scans from newest index back to oldest index numerically in the chart history
// void DetectOrderBlocksForToday(int scan_newest_chart_index, int scan_oldest_chart_index)
// {
//    if (g_order_blocks_scanned_today) return; // Only run detection scan once per day
//    int total_bars = Bars(Symbol(), Period());
//    // Ensure valid scan range (scan_newest_chart_index < scan_oldest_chart_index numerically for a range going backwards in time)
//    if (scan_newest_chart_index < 0 || scan_oldest_chart_index < 0 || scan_newest_chart_index >= total_bars || scan_oldest_chart_index >= total_bars || scan_newest_chart_index >= scan_oldest_chart_index) { // Condition check correct based on index values
//       Print(visual_comment_text + " - DetectOrderBlocksForToday Error: Invalid chart index scan range (newest: ", scan_newest_chart_index, ", oldest: ", scan_oldest_chart_index, ", total bars: ", total_bars, ").");
//       g_order_blocks_scanned_today = true; // Avoid trying again
//       return;
//    }
//    // Calculate the total number of bars required for copying, starting from the oldest scan bar index.
//    // This range covers from scan_oldest_chart_index back to satisfy any OB lookahead, up to scan_newest_chart_index.
//    int max_bars_ahead_needed_by_ob = MathMax(ob_Lookback_Bars_For_Impulse + 1, ob_MaxBlockCandles) ; // Furthest number of bars forward checked by OB candidate logic, including candidate itself
//    int needed_total_bars_from_oldest_scan = (scan_oldest_chart_index - scan_newest_chart_index + 1) + max_bars_ahead_needed_by_ob ; // Number of bars covering the scan range and lookahead from oldest scan bar
//    if (needed_total_bars_from_oldest_scan > total_bars - scan_newest_chart_index ) { // Check if total bars available from newest scan bar onwards is enough
//       Print(visual_comment_text + " - Not enough historical bars available (need ", needed_total_bars_from_oldest_scan, " bars from chart index ", scan_newest_chart_index, " onwards. Have ", total_bars - scan_newest_chart_index, ") to perform OB detection scan with required lookahead.");
//       g_order_blocks_scanned_today = true;
//       return;
//    }
//    // Correct Indices to Copy: Copy enough bars starting from the oldest required bar backward in history
//    int copy_start_chart_index = MathMax(0, scan_newest_chart_index - MathMax(ob_Lookback_Bars_For_Impulse, ob_MaxBlockCandles)); // Starting point for copying to have enough data backwards from newest scanned index
//    int num_bars_to_copy = total_bars - copy_start_chart_index; // Number of bars from copy_start to end of history (chart index total_bars - 1)
//    // Use Arrays to read necessary bar data efficiently over the history needed for scanning and lookahead checks
//    double open_arr[], high_arr[], low_arr[], close_arr[];
//    if (CopyOpen(Symbol(), Period(), copy_start_chart_index, num_bars_to_copy, open_arr) < num_bars_to_copy || // Check copied bars count against requested
//          CopyHigh(Symbol(), Period(), copy_start_chart_index, num_bars_to_copy, high_arr) < num_bars_to_copy ||
//          CopyLow(Symbol(), Period(), copy_start_chart_index, num_bars_to_copy, low_arr) < num_bars_to_copy ||
//          CopyClose(Symbol(), Period(), copy_start_chart_index, num_bars_to_copy, close_arr) < num_bars_to_copy) {
//       Print("Error copying price data for OB detection scan or insufficient data received: ", GetLastError());
//       g_order_blocks_scanned_today = true;
//       return;
//    }
//    // Reset daily OB counts (done in CalculateAndDrawDailyTimings)
//    Print(visual_comment_text + " - Scanning chart indices from ", scan_newest_chart_index, " (newest) back to ", scan_oldest_chart_index, " (oldest) for Order Blocks in Stage 2 period. Using array data starting from chart index ", copy_start_chart_index, " (Array size: ", num_bars_to_copy, ")");
//    // Iterate through the relevant M5 bars within the specified scan range (using chart indices).
//    // These are the candidate OB candles. Loop from newest relevant bar back to oldest relevant bar.
//    for (int chart_idx = scan_newest_chart_index; chart_idx <= scan_oldest_chart_index; chart_idx++) { // Loop from newest (lower index) to oldest (higher index)
//       // Limit detection to candidates formed within or immediately preceding the core manipulation/observation period
//       // If scan_before_obs_end_only is true, only consider candidates whose end time is roughly before observation end time.
//       datetime ob_end_approx_time = iTime(Symbol(), Period(), chart_idx) + PeriodSeconds(Period()) * ob_MaxBlockCandles; // Approx end time of the OB block period from this candidate (adjust calculation to align with visual rect if needed)
//       if(scan_before_obs_end_only && ob_end_approx_time >= g_ObservationEndTime_Server ) continue;
//       int arr_idx = chart_idx - copy_start_chart_index; // Get the array index for this chart index (Correct)
//       // Ensure we have enough bars *ahead* in the copied array from this candidate bar 'arr_idx' to perform the full OB checks
//       int needed_future_bars_from_arr_idx = MathMax(ob_Lookback_Bars_For_Impulse + 1, ob_MaxBlockCandles) ; // Number of bars required for the check starting AT arr_idx and looking forward (including arr_idx itself)
//       if (arr_idx + needed_future_bars_from_arr_idx >= num_bars_to_copy) { // If checks extend beyond array bounds from THIS starting point
//          // Not enough future bars in the copied array from this candidate's position
//          // This candidate is too close to the end of the copied data for its full check
//          Print("Warning: Skipping OB candidate at chart index ", chart_idx, " (array index ", arr_idx, "). Not enough future data in copied array (Need ", needed_future_bars_from_arr_idx, ", Have ", num_bars_to_copy - arr_idx, " from this point)."); // Verbose skipping
//          continue; // Cannot perform full check
//       }
//       // --- Check if this candle at array index 'arr_idx' is a Bullish or Bearish Order Block candidate ---
//       bool is_bullish_ob = IsBullishOrderBlockCandidate(arr_idx, open_arr, high_arr, low_arr, close_arr, num_bars_to_copy);
//       bool is_bearish_ob = IsBearishOrderBlockCandidate(arr_idx, open_arr, high_arr, low_arr, close_arr, num_bars_to_copy);
//       if (is_bullish_ob) {
//          if (g_bullishOB_count < 100) {
//             // Store details using data corresponding to chart index 'chart_idx'
//             g_bullishOrderBlocks[g_bullishOB_count].startTime = iTime(Symbol(), Period(), chart_idx);
//             g_bullishOrderBlocks[g_bullishOB_count].high = iHigh(Symbol(), Period(), chart_idx);
//             g_bullishOrderBlocks[g_bullishOB_count].low = iLow(Symbol(), Period(), chart_idx);
//             g_bullishOrderBlocks[g_bullishOB_count].type = POSITION_TYPE_BUY;
//             g_bullishOrderBlocks[g_bullishOB_count].isMitigated = false;
//             g_bullishOrderBlocks[g_bullishOB_count].objectName = "BullOB_" + TimeToString(g_bullishOrderBlocks[g_bullishOB_count].startTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS) + "_" + IntegerToString(chart_idx); // Even more unique
//             g_bullishOrderBlocks[g_bullishOB_count].labelName = g_bullishOrderBlocks[g_bullishOB_count].objectName + "_Label";
//             // Print confirmation - can be verbose if many OBs found
//             Print(visual_comment_text + " - Detected BULLISH Order Block at Server Time: ", TimeToString(g_bullishOrderBlocks[g_bullishOB_count].startTime, TIME_DATE|TIME_MINUTES), " (Chart Index ", chart_idx, ")");
//             // Draw the OB visual if enabled and not already drawn
//             if(visual_enabled && visual_order_blocks) {
//                string ob_name = g_bullishOrderBlocks[g_bullishOB_count].objectName;
//                // Delete if already exists (safety measure for rapid redraws)
//                if(ObjectFind(0, ob_name) > 0) ObjectDelete(0, ob_name);
//                // Draw rectangle over the time span of the OB candle and the following MaxBlockCandles-1
//                if (ObjectCreate(0, ob_name, OBJ_RECTANGLE, 0, g_bullishOrderBlocks[g_bullishOB_count].startTime, g_bullishOrderBlocks[g_bullishOB_count].high, g_bullishOrderBlocks[g_bullishOB_count].startTime + PeriodSeconds(Period()) * (ob_MaxBlockCandles-1), g_bullishOrderBlocks[g_bullishOB_count].low)) {
//                   ObjectSetInteger(0, ob_name, OBJPROP_COLOR, ob_bullish_color);
//                   ObjectSetInteger(0, ob_name, OBJPROP_STYLE, STYLE_SOLID);
//                   ObjectSetInteger(0, ob_name, OBJPROP_WIDTH, 1);
//                   ObjectSetInteger(0, ob_name, OBJPROP_FILL, true);
//                   ObjectSetInteger(0, ob_name, OBJPROP_BACK, true); // Send to back
//                   ObjectSetInteger(0, ob_name, OBJPROP_SELECTABLE, false);
//                   ObjectSetInteger(0, ob_name, OBJPROP_HIDDEN, true); // Hide on other TFs
//                   // Add a label for the OB
//                   string ob_label_name = g_bullishOrderBlocks[g_bullishOB_count].labelName;
//                   if (!ObjectFind(0, ob_label_name)) {
//                      datetime label_time = g_bullishOrderBlocks[g_bullishOB_count].startTime + PeriodSeconds(Period()) * (ob_MaxBlockCandles-1) / 2; // Center label
//                      double label_price = (g_bullishOrderBlocks[g_bullishOB_count].high + g_bullishOrderBlocks[g_bullishOB_count].low) / 2;
//                      ObjectCreate(0, ob_label_name, OBJ_TEXT, 0, label_time, label_price);
//                      ObjectSetString(0, ob_label_name, OBJPROP_TEXT, "Bull OB");
//                      ObjectSetInteger(0, ob_label_name, OBJPROP_COLOR, ob_label_color);
//                      ObjectSetInteger(0, ob_label_name, OBJPROP_ANCHOR, ANCHOR_CENTER);
//                      ObjectSetInteger(0, ob_label_name, OBJPROP_FONTSIZE, 7);
//                      ObjectSetInteger(0, ob_label_name, OBJPROP_SELECTABLE, false);
//                      ObjectSetInteger(0, ob_label_name, OBJPROP_BACK, false); // Send label to back?
//                      ObjectSetInteger(0, ob_label_name, OBJPROP_HIDDEN, true); // Hide on other TFs
//                   }
//                }
//                else {
//                   Print(visual_comment_text + " - Error creating Bull OB visual object at chart index ", chart_idx, ": ", GetLastError());
//                }
//             }
//             g_bullishOB_count++; // Increment counter
//          }
//          else {
//             // Print(visual_comment_text + " - Warning: Maximum daily Bullish Order Blocks storage capacity reached. Skipping detection from chart index ", chart_idx);
//          }
//       } // End if is_bullish_ob
//       if (is_bearish_ob) {
//          if (g_bearishOB_count < 100) {
//             g_bearishOrderBlocks[g_bearishOB_count].startTime = iTime(Symbol(), Period(), chart_idx);
//             g_bearishOrderBlocks[g_bearishOB_count].high = iHigh(Symbol(), Period(), chart_idx);
//             g_bearishOrderBlocks[g_bearishOB_count].low = iLow(Symbol(), Period(), chart_idx);
//             g_bearishOrderBlocks[g_bearishOB_count].type = POSITION_TYPE_SELL;
//             g_bearishOrderBlocks[g_bearishOB_count].isMitigated = false;
//             g_bearishOrderBlocks[g_bearishOB_count].objectName = "BearOB_" + TimeToString(g_bearishOrderBlocks[g_bearishOB_count].startTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS) + "_" + IntegerToString(chart_idx); // Even more unique
//             g_bearishOrderBlocks[g_bearishOB_count].labelName = g_bearishOrderBlocks[g_bearishOB_count].objectName + "_Label";
//             // Print confirmation - can be verbose
//             // Print(visual_comment_text + " - Detected BEARISH Order Block at Server Time: ", TimeToString(g_bearishOrderBlocks[g_bearishOB_count].startTime, TIME_DATE|TIME_MINUTES), " (Chart Index ", chart_idx, ")");
//             // Draw the OB visual if enabled and not already drawn
//             if(visual_enabled && visual_order_blocks) {
//                string ob_name = g_bearishOrderBlocks[g_bearishOB_count].objectName;
//                string ob_label_name = g_bearishOrderBlocks[g_bearishOB_count].labelName;
//                if(ObjectFind(0, ob_name) > 0) ObjectDelete(0, ob_name); // Delete if already exists
//                // Draw rectangle over the time span of the OB candle and the following MaxBlockCandles-1
//                if (ObjectCreate(0, ob_name, OBJ_RECTANGLE, 0, g_bearishOrderBlocks[g_bearishOB_count].startTime, g_bearishOrderBlocks[g_bearishOB_count].high, g_bearishOrderBlocks[g_bearishOB_count].startTime + PeriodSeconds(Period()) * (ob_MaxBlockCandles-1), g_bearishOrderBlocks[g_bearishOB_count].low)) {
//                   ObjectSetInteger(0, ob_name, OBJPROP_COLOR, ob_bearish_color);
//                   ObjectSetInteger(0, ob_name, OBJPROP_STYLE, STYLE_SOLID);
//                   ObjectSetInteger(0, ob_name, OBJPROP_WIDTH, 1);
//                   ObjectSetInteger(0, ob_name, OBJPROP_FILL, true);
//                   ObjectSetInteger(0, ob_name, OBJPROP_BACK, true); // Send to back
//                   ObjectSetInteger(0, ob_name, OBJPROP_SELECTABLE, false);
//                   ObjectSetInteger(0, ob_name, OBJPROP_HIDDEN, true); // Hide on other TFs
//                   // Add a label for the OB
//                   if (!ObjectFind(0, ob_label_name)) {
//                      datetime label_time = g_bearishOrderBlocks[g_bearishOB_count].startTime + PeriodSeconds(Period()) * (ob_MaxBlockCandles-1) / 2; // Center label
//                      double label_price = (g_bearishOrderBlocks[g_bearishOB_count].high + g_bearishOrderBlocks[g_bearishOB_count].low) / 2;
//                      ObjectCreate(0, ob_label_name, OBJ_TEXT, 0, label_time, label_price);
//                      ObjectSetString(0, ob_label_name, OBJPROP_TEXT, "Bear OB");
//                      ObjectSetInteger(0, ob_label_name, OBJPROP_COLOR, ob_label_color);
//                      ObjectSetInteger(0, ob_label_name, OBJPROP_ANCHOR, ANCHOR_CENTER);
//                      ObjectSetInteger(0, ob_label_name, OBJPROP_FONTSIZE, 7);
//                      ObjectSetInteger(0, ob_label_name, OBJPROP_SELECTABLE, false);
//                      ObjectSetInteger(0, ob_label_name, OBJPROP_BACK, false); // Send label to back?
//                      ObjectSetInteger(0, ob_label_name, OBJPROP_HIDDEN, true); // Hide on other TFs
//                   }
//                }
//                else {
//                   Print(visual_comment_text + " - Error creating Bear OB visual object at chart index ", chart_idx, ": ", GetLastError());
//                }
//             }
//             g_bearishOB_count++; // Increment counter
//          }
//          else {
//             // Print(visual_comment_text + " - Warning: Maximum daily Bearish Order Blocks storage capacity reached. Skipping detection from chart index ", chart_idx);
//          }
//       } // End if is_bearish_ob
//    } // End of scan loop backwards through the chart indices
//    Print(visual_comment_text + " - Order Block detection scan completed for Stage 2 period. Detected Bull OBs: ", g_bullishOB_count, ", Bear OBs: ", g_bearishOB_count);
//    g_order_blocks_scanned_today = true; // Mark detection as completed for today
//    ChartRedraw(0); // Redraw chart after drawing objects
// }
//+------------------------------------------------------------------+
//| Detects and Stores Order Blocks formed within the specified scan range |
//| scan_newest_candidate_chart_idx: Chart index of the NEWEST bar to check as potential OB start
//| scan_oldest_candidate_chart_idx: Chart index of the OLDEST bar to check as potential OB start
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Detects and Stores Order Blocks formed within the specified scan range |
//| scan_newest_candidate_chart_idx: Chart index of the NEWEST bar to check as potential OB start
//| scan_oldest_candidate_chart_idx: Chart index of the OLDEST bar to check as potential OB start
//+------------------------------------------------------------------+
void DetectOrderBlocksForToday(int scan_newest_candidate_chart_idx, int scan_oldest_candidate_chart_idx)
{
    if (g_order_blocks_scanned_today) {
        //Print(visual_comment_text + " - OB Scan already completed for today. Skipping.");
        return;
    }
    int total_bars_on_chart = Bars(Symbol(), Period());

    // --- Input Validation ---
    // scan_newest_candidate_chart_idx: e.g., chart index 10 (10 M5 bars ago from current bar 0, a more recent bar)
    // scan_oldest_candidate_chart_idx: e.g., chart index 50 (50 M5 bars ago from current bar 0, an older bar)
    // Condition: newest_idx <= oldest_idx (numerically, as chart indices count backwards)
    if (scan_newest_candidate_chart_idx < 0 || scan_oldest_candidate_chart_idx < 0 ||
        scan_newest_candidate_chart_idx >= total_bars_on_chart || scan_oldest_candidate_chart_idx >= total_bars_on_chart ||
        scan_newest_candidate_chart_idx > scan_oldest_candidate_chart_idx) {
        Print(visual_comment_text + " - DetectOrderBlocks Error: Invalid chart index scan range. NewestCandIdx:", scan_newest_candidate_chart_idx, " OldestCandIdx:", scan_oldest_candidate_chart_idx);
        g_order_blocks_scanned_today = true;
        return;
    }

    // --- Determine Data Copy Range ---
    // The Is...Candidate functions need to look 'forward' in the array (newer candles) from the candidate.
    // If `scan_newest_candidate_chart_idx` is the newest bar we consider as an OB *start*,
    // Is...Candidate will need to look `max_lookahead_needed` bars newer than it.
    // Chart indices: 0 = current, 1 = last closed. A newer bar has a SMALLER chart index.
    // To look at bars *newer* than `scan_newest_candidate_chart_idx` for impulse checks, we need indices `scan_newest_candidate_chart_idx - 1`, `-2`, etc.
    // The OLDEST data point needed is related to `scan_oldest_candidate_chart_idx`.
    // The NEWEST data point needed by Is...Candidate for impulse check on `scan_newest_candidate_chart_idx` is approx. `scan_newest_candidate_chart_idx - max_lookahead_needed`.
    
    int max_lookahead_into_newer_bars = MathMax(ob_Lookback_Bars_For_Impulse, ob_MaxBlockCandles -1); // -1 because MaxBlockCandles includes the OB candle itself.

    // The actual newest chart bar we need to *access* data for is the `scan_newest_candidate_chart_idx` 
    // minus `max_lookahead_into_newer_bars` IF `Is...Candidate` logic iterates that way.
    // HOWEVER, our `Is...Candidate` functions (as written previously) take `index_in_array` for the candidate
    // and check `index_in_array + 1`, `+2`, etc. which are NEWER bars if array[0]=oldest.

    // Let's align with that: array[0] = oldest data, array[N-1] = newest data.
    // Candidate for OB at array index `k`. Impulse and block structure are at `k+1, k+2 ...`
    // We are checking chart_idx from `scan_oldest_candidate_chart_idx` down to `scan_newest_candidate_chart_idx`.
    // The `scan_oldest_candidate_chart_idx` is the oldest bar we might check. For it, `Is...Candidate` needs data for bars *newer* than it.
    // The data that needs to be copied:
    // Start copying from chart index 0 (most recent bar).
    // Go back enough bars to include the `scan_oldest_candidate_chart_idx`
    // PLUS the number of bars Is...Candidate will look *ahead* (newer) from that oldest candidate for its checks.
    
    int chart_idx_of_oldest_candidate_bar = scan_oldest_candidate_chart_idx;
    // For Is...Candidate to check the candidate at `chart_idx_of_oldest_candidate_bar` (which will be `arr_idx_x` in the array),
    // it will need `max_lookahead_into_newer_bars` available *after* it in the array.
    // These newer bars have SMALLER chart indices.
    // The array segment needed runs from the oldest OB candidate (e.g. chart_idx 50)
    // down to (chart_idx 50 - `max_lookahead_into_newer_bars`).
    // And for the newest OB candidate (e.g. chart_idx 10), we need down to (chart_idx 10 - `max_lookahead_into_newer_bars`).
    // So, the overall newest chart bar whose data we need is (`scan_newest_candidate_chart_idx` - `max_lookahead_into_newer_bars`).
    // However, `CopyOpen` etc., copy *backwards from current bar (0)*.
    // We need to copy enough bars so that our `scan_oldest_candidate_chart_idx` is included,
    // and also, from that point, when mapped to array indices, there are enough *subsequent* array elements (newer bars) for `Is...Candidate`.

    // Simpler copy: Copy from chart index 0 back to `scan_oldest_candidate_chart_idx` + enough for IsCandidate lookahead for *that* oldest one.
    // Actually, let's calculate total bars required slightly differently to ensure all candidate checks are covered:
    // The "earliest" bar (smallest chart index) that could be part of an impulse or structure check occurs
    // if `scan_newest_candidate_chart_idx` is the OB start. Then impulse is at `scan_newest_candidate_chart_idx - ob_Lookback_Bars_For_Impulse`.
    // But this isn't right. Is...Candidate expects the *candidate bar's index in the array* and looks FORWARD in that array.

    // We will iterate `chart_candidate_idx` from `scan_oldest_candidate_chart_idx` (e.g., 50) down to `scan_newest_candidate_chart_idx` (e.g., 10).
    // The array data we need: `array[0]` must be data for chart index (say) `X`. `array[N-1]` is data for chart index `0`.
    // If candidate is `chart_idx=Y`, its data is at `array[(X-Y)]`.
    // For this `array[(X-Y)]` to be processed by `Is...Candidate`, we need elements up to `array[(X-Y) + max_lookahead_needed]` to be valid.
    // So, `(X-Y) + max_lookahead_needed < N`.
    // We need to copy at least `scan_oldest_candidate_chart_idx + 1` bars.
    // Let `copy_start_chart_idx = 0`.
    // Let `num_bars_to_copy_total = scan_oldest_candidate_chart_idx + 1;` (this copies from chart_idx 0 to scan_oldest_candidate_chart_idx inclusive)

    int copy_from_chart_index = 0; // Copy starting from the current bar backwards
    int number_of_bars_to_copy_for_scan = scan_oldest_candidate_chart_idx + 1; // This ensures the oldest candidate is included
    
    // Now ensure we have enough bars FOR THE LOOKAHEAD from the OLDEST possible start of an impulse
    // that could follow the NEWEST OB candidate.
    // This means we need data for bars from `scan_oldest_candidate_chart_idx` (oldest OB) 
    // down to (`scan_newest_candidate_chart_idx - max_lookahead_into_newer_bars` - if that's how Is...Candidate worked with chart indices).
    // With our current Is...Candidate looking at `arr_idx + k`, it's simpler.
    // We need `scan_oldest_candidate_chart_idx` (our oldest candidate's chart_idx)
    // to have enough `max_lookahead_into_newer_bars` *newer than it* available.
    // The total span of chart indices to consider is from `scan_oldest_candidate_chart_idx`
    // down to effectively (`scan_newest_candidate_chart_idx - max_lookahead_into_newer_bars`), but
    // we always copy from chart index 0.

    // The copy range should cover all bars from the present (index 0) up to
    // the oldest candidate plus its structure (`scan_oldest_candidate_chart_idx + ob_MaxBlockCandles -1`),
    // and the impulse check (from that oldest OB start) needs to look `ob_Lookback_Bars_For_Impulse` newer than the structure.
    // So, the data actually needs to span from chart_idx 0 back to a sufficient depth.
    // The most "future" index needed by `Is...Candidate` from any `arr_idx_of_candidate` is `arr_idx_of_candidate + max_lookahead_into_newer_bars`.
    // This `arr_idx_of_candidate + max_lookahead_into_newer_bars` must be `< num_bars_to_copy`.
    
    int actual_oldest_chart_index_to_copy = scan_oldest_candidate_chart_idx; // Oldest OB *start*
    int number_of_bars_to_actually_copy = actual_oldest_chart_index_to_copy + 1 + max_lookahead_into_newer_bars; // Copy enough for oldest + its lookahead

    if (number_of_bars_to_actually_copy > total_bars_on_chart) {
        number_of_bars_to_actually_copy = total_bars_on_chart; // Cap at available
    }
    if (number_of_bars_to_actually_copy <= max_lookahead_into_newer_bars) { // Need more than just lookahead
        Print(visual_comment_text + " - DetectOrderBlocks Error: Not enough bars on chart to cover scan and lookahead properly. Needed:", number_of_bars_to_actually_copy);
        g_order_blocks_scanned_today = true;
        return;
    }

    double open_arr[], high_arr[], low_arr[], close_arr[];
    datetime time_arr[];

    if (CopyOpen(Symbol(), Period(), 0, number_of_bars_to_actually_copy, open_arr)    != number_of_bars_to_actually_copy ||
        CopyHigh(Symbol(), Period(), 0, number_of_bars_to_actually_copy, high_arr)    != number_of_bars_to_actually_copy ||
        CopyLow(Symbol(), Period(), 0, number_of_bars_to_actually_copy, low_arr)     != number_of_bars_to_actually_copy ||
        CopyClose(Symbol(), Period(), 0, number_of_bars_to_actually_copy, close_arr)   != number_of_bars_to_actually_copy ||
        CopyTime(Symbol(),Period(), 0, number_of_bars_to_actually_copy, time_arr)      != number_of_bars_to_actually_copy) {
        Print("Error copying price/time data for OB scan. Needed:", number_of_bars_to_actually_copy, ". Error:", GetLastError());
        g_order_blocks_scanned_today = true;
        return;
    }
    // Arrays now hold: [0] = data for chart_idx `number_of_bars_to_actually_copy-1`, ..., [N-1] = data for chart_idx 0
    
    Print(visual_comment_text + " - OB SCAN: ChartCandIdxRange [",scan_newest_candidate_chart_idx," to ",scan_oldest_candidate_chart_idx,"]. Copied ", number_of_bars_to_actually_copy," bars for context.");
    g_bullishOB_count = 0; 
    g_bearishOB_count = 0; 

    // Loop through the CHART INDICES that we want to test as the START of an OB.
    // From older possible start towards newer possible start.
    for (int chart_candidate_idx = scan_oldest_candidate_chart_idx; chart_candidate_idx >= scan_newest_candidate_chart_idx; chart_candidate_idx--)
    {
        // Map this chart_candidate_idx (e.g., 50 for oldest, 10 for newest in scan window)
        // to an index in our copied array.
        // Copied array's index 0 corresponds to chart_idx = (number_of_bars_to_actually_copy - 1)
        // Copied array's index `i` corresponds to chart_idx = (number_of_bars_to_actually_copy - 1) - `i`
        // So, for a given chart_candidate_idx, its index in the copied array is:
        int arr_idx_of_candidate = (number_of_bars_to_actually_copy - 1) - chart_candidate_idx;

        if (arr_idx_of_candidate < 0 || arr_idx_of_candidate >= number_of_bars_to_actually_copy) {
            Print("Dev Error: arr_idx_of_candidate mapping OOB. ChartIdx:", chart_candidate_idx, " ArrIdx:", arr_idx_of_candidate, " ArraySize:", number_of_bars_to_actually_copy);
            continue;
        }
        
        datetime ob_candidate_start_time = time_arr[arr_idx_of_candidate]; // Time of the candidate being tested

        // Filter by scan_before_obs_end_only, considering the whole block structure
        if (scan_before_obs_end_only) {
             datetime ob_structure_ends_at_time =(datetime) (ob_candidate_start_time + ((long)PeriodSeconds(PERIOD_M5) * (long)ob_MaxBlockCandles));
             if (ob_structure_ends_at_time > g_ObservationEndTime_Server) { // Check if any part of block (based on candidate start) extends beyond ObsEnd
                 continue;
             }
        }
        
        // The Is...Candidate functions expect `arr_idx_of_candidate` and will look at `+1, +2`... for impulse.
        // So we need to ensure arr_idx_of_candidate + max_lookahead_into_newer_bars < number_of_bars_to_actually_copy.
        if (arr_idx_of_candidate + max_lookahead_into_newer_bars >= number_of_bars_to_actually_copy) {
            // This candidate is too close to the "newest" end of our copied array to have enough following bars for checks.
            // This typically happens if `scan_oldest_candidate_chart_idx` was not old enough relative to copy boundary.
            // Print("Skipping OB Candidate (ChartIdx:", chart_candidate_idx, ", ArrIdx:", arr_idx_of_candidate,") due to insufficient subsequent data in copied array for Is...Candidate checks.");
            continue;
        }

        bool is_bullish_ob = IsBullishOrderBlockCandidate(arr_idx_of_candidate, open_arr, high_arr, low_arr, close_arr, number_of_bars_to_actually_copy);
        bool is_bearish_ob = IsBearishOrderBlockCandidate(arr_idx_of_candidate, open_arr, high_arr, low_arr, close_arr, number_of_bars_to_actually_copy);

        if (is_bullish_ob && g_bullishOB_count < 100) {
            st_OrderBlock new_ob; // Local instance
            new_ob.startTime    = time_arr[arr_idx_of_candidate];
            // Store the H/L of the *initial* bearish candle that defines the Bullish OB
            new_ob.high         = high_arr[arr_idx_of_candidate]; 
            new_ob.low          = low_arr[arr_idx_of_candidate];
            new_ob.type         = POSITION_TYPE_BUY;
            new_ob.isMitigated  = false;
            string obj_name_part = TimeToString(new_ob.startTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS) + "_B" + IntegerToString(chart_candidate_idx);
            new_ob.objectName   = "BullOB_" + obj_name_part;
            new_ob.labelName    = "Lbl_BullOB_" + obj_name_part;
            g_bullishOrderBlocks[g_bullishOB_count] = new_ob; // Assign to global array

            Print(visual_comment_text + " - Detected BULLISH OB Starting: ", TimeToString(new_ob.startTime, TIME_DATE|TIME_SECONDS), " (Chart Idx:", chart_candidate_idx,")");

            if(visual_enabled && visual_order_blocks) {
                double block_visual_high = new_ob.high; // Start with candidate's high/low
                double block_visual_low  = new_ob.low;
                // Determine true H/L for the visual representation of the block (ob_MaxBlockCandles duration)
                for(int k=0; k < ob_MaxBlockCandles && (arr_idx_of_candidate+k < number_of_bars_to_actually_copy); k++) {
                    block_visual_high = MathMax(block_visual_high, high_arr[arr_idx_of_candidate+k]);
                    block_visual_low  = MathMin(block_visual_low,  low_arr[arr_idx_of_candidate+k]);
                }
                datetime rect_time1 = new_ob.startTime; 
                datetime rect_time2 = new_ob.startTime + (datetime)((long)PeriodSeconds(Period()) * ob_MaxBlockCandles); 

                if(ObjectFind(0, new_ob.objectName) >= 0) ObjectDelete(0, new_ob.objectName); // Use >=0 for ObjectFind
                if(ObjectCreate(0, new_ob.objectName, OBJ_RECTANGLE, 0, rect_time1, block_visual_high, rect_time2, block_visual_low)) {
                    ObjectSetInteger(0, new_ob.objectName, OBJPROP_COLOR, ob_bullish_color);
                    ObjectSetInteger(0, new_ob.objectName, OBJPROP_STYLE, STYLE_SOLID);
                    ObjectSetInteger(0, new_ob.objectName, OBJPROP_WIDTH, 1);
                    ObjectSetInteger(0, new_ob.objectName, OBJPROP_FILL, true);
                    ObjectSetInteger(0, new_ob.objectName, OBJPROP_BACK, true); 
                    ObjectSetInteger(0, new_ob.objectName, OBJPROP_SELECTABLE, false);
                    ObjectSetInteger(0, new_ob.objectName, OBJPROP_HIDDEN, true);
                    
                    if(ObjectFind(0, new_ob.labelName) >=0 ) ObjectDelete(0,new_ob.labelName);
                    datetime lbl_time = rect_time1 + (datetime)((long)PeriodSeconds(Period()) * (ob_MaxBlockCandles / 2));
                    double lbl_price = (block_visual_high + block_visual_low) / 2.0;
                    if(ObjectCreate(0, new_ob.labelName, OBJ_TEXT, 0, lbl_time, lbl_price)) {
                        ObjectSetString(0, new_ob.labelName, OBJPROP_TEXT, "Bull OB"); 
                        ObjectSetInteger(0, new_ob.labelName, OBJPROP_COLOR, ob_label_color);
                        ObjectSetInteger(0, new_ob.labelName, OBJPROP_ANCHOR, ANCHOR_CENTER);
                        ObjectSetInteger(0, new_ob.labelName, OBJPROP_FONTSIZE, 7);
                        /* ... other label props ...*/
                    }
                } else { Print("Err Creating BullOB rect:", GetLastError(), " for OB at ", TimeToString(new_ob.startTime,TIME_DATE|TIME_SECONDS));}
            }
            g_bullishOB_count++;
        }
        
        if (is_bearish_ob && g_bearishOB_count < 100) { 
            st_OrderBlock new_ob; // Local instance
            new_ob.startTime    = time_arr[arr_idx_of_candidate];
            new_ob.high         = high_arr[arr_idx_of_candidate];
            new_ob.low          = low_arr[arr_idx_of_candidate];
            new_ob.type         = POSITION_TYPE_SELL;
            new_ob.isMitigated  = false; // Initialize
            string obj_name_part = TimeToString(new_ob.startTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS) + "_S" + IntegerToString(chart_candidate_idx);
            new_ob.objectName   = "BearOB_" + obj_name_part;
            new_ob.labelName    = "Lbl_BearOB_" + obj_name_part; // Corrected: Label name consistent
            g_bearishOrderBlocks[g_bearishOB_count] = new_ob;

            // CORRECTED PRINT STATEMENT for Bearish OB
            Print(visual_comment_text + " - Detected BEARISH OB Starting: ", TimeToString(new_ob.startTime, TIME_DATE|TIME_SECONDS), " (Chart Idx:", chart_candidate_idx,", Arr Idx:", arr_idx_of_candidate, ")");
            
            if(visual_enabled && visual_order_blocks) { 
                double block_visual_high = new_ob.high; 
                double block_visual_low  = new_ob.low;
                for(int k=0; k < ob_MaxBlockCandles && (arr_idx_of_candidate+k < number_of_bars_to_actually_copy); k++) {
                    block_visual_high = MathMax(block_visual_high, high_arr[arr_idx_of_candidate+k]);
                    block_visual_low  = MathMin(block_visual_low,  low_arr[arr_idx_of_candidate+k]);
                }
                datetime rect_time1 = new_ob.startTime; 
                datetime rect_time2 = new_ob.startTime + (datetime)((long)PeriodSeconds(Period()) * ob_MaxBlockCandles);

                if(ObjectFind(0, new_ob.objectName) >= 0) ObjectDelete(0, new_ob.objectName);
                if(ObjectCreate(0, new_ob.objectName, OBJ_RECTANGLE, 0, rect_time1, block_visual_high, rect_time2, block_visual_low)) {
                    ObjectSetInteger(0, new_ob.objectName, OBJPROP_COLOR, ob_bearish_color);
                     // Add all other OBJPROP for bearish rectangle like you did for bullish
                    ObjectSetInteger(0, new_ob.objectName, OBJPROP_STYLE, STYLE_SOLID);
                    ObjectSetInteger(0, new_ob.objectName, OBJPROP_WIDTH, 1);
                    ObjectSetInteger(0, new_ob.objectName, OBJPROP_FILL, true);
                    ObjectSetInteger(0, new_ob.objectName, OBJPROP_BACK, true); 
                    ObjectSetInteger(0, new_ob.objectName, OBJPROP_SELECTABLE, false);
                    ObjectSetInteger(0, new_ob.objectName, OBJPROP_HIDDEN, true);

                    if(ObjectFind(0, new_ob.labelName) >=0 ) ObjectDelete(0,new_ob.labelName);
                    datetime lbl_time = rect_time1 + (datetime)((long)PeriodSeconds(Period()) * (ob_MaxBlockCandles / 2));
                    double lbl_price = (block_visual_high + block_visual_low) / 2.0;
                     if(ObjectCreate(0, new_ob.labelName, OBJ_TEXT, 0, lbl_time, lbl_price)) {
                         ObjectSetString(0, new_ob.labelName, OBJPROP_TEXT, "Bear OB");
                         // ... set other label properties similar to Bull OB ...
                         ObjectSetInteger(0, new_ob.labelName, OBJPROP_COLOR, ob_label_color);
                         ObjectSetInteger(0, new_ob.labelName, OBJPROP_ANCHOR, ANCHOR_CENTER);
                         ObjectSetInteger(0, new_ob.labelName, OBJPROP_FONTSIZE, 7);
                         ObjectSetInteger(0, new_ob.labelName, OBJPROP_SELECTABLE, false);
                         ObjectSetInteger(0, new_ob.labelName, OBJPROP_BACK, false);
                         ObjectSetInteger(0, new_ob.labelName, OBJPROP_HIDDEN, true);
                     }
                } else { Print("Err Creating BearOB rect:", GetLastError(), " for OB at ", TimeToString(new_ob.startTime,TIME_DATE|TIME_SECONDS));}
            }
            g_bearishOB_count++;
        }
    } // End of main scan loop
    Print(visual_comment_text + " - Order Block detection scan completed. Found BullOBs:", g_bullishOB_count, ", BearOBs:", g_bearishOB_count);
    g_order_blocks_scanned_today = true;
    ChartRedraw(0);
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
   g_TodayKeyTime_Server = (datetime) (server_midnight + (long)((long)target_server_hour * 3600L + (long)utcPlus2_KeyMinute_1300 * 60L));
   //--- Calculate the observation end time (after observation duration) in server time ---
   g_ObservationEndTime_Server = (datetime) (g_TodayKeyTime_Server + (long)(observation_Duration_Minutes * 60L));

   //--- Calculate Entry Search End Time (if enabled) ---
   if(use_entry_search_window)
   {
      if(server_midnight > 0)
      {
         int target_end_hour_gmt = entry_search_end_hour_utc2 - 2; // Assuming UTC+2 is always GMT+2
         int target_end_server_hour = target_end_hour_gmt + server_GMT_Offset_Manual;
         target_end_server_hour = target_end_server_hour % 24;
         if(target_end_server_hour < 0) target_end_server_hour += 24;
         g_EntrySearchEndTime_Server = (datetime)(server_midnight + (long)((long)target_end_server_hour * 3600L + (long)entry_search_end_minute_utc2 * 60L));
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

   //--- Calculate the specific 15th candlestick entry time in server time ---
   // Find the bar index that starts exactly at or immediately after the Key Time (g_TodayKeyTime_Server)
   // We want the 15th M5 bar starting *from* the bar at g_TodayKeyTime_Server as the first bar.
   g_EntryTiming_Server = 0; // Initialize to 0
   if (g_TodayKeyTime_Server > 0) {
      // Simply calculate the future time directly based on the key time
      // The 15th bar starts 14 * 5 minutes after the Key Time bar starts
      g_EntryTiming_Server = (datetime) (g_TodayKeyTime_Server + (long)((long)(entry_Candlestick_Index - 1) * (long)PeriodSeconds(PERIOD_M5)));
      Print(visual_comment_text + " - REF: Target 15th M5 Candlestick Window STARTS at (Server Time): ", TimeToString(g_EntryTiming_Server, TIME_DATE|TIME_MINUTES));
   }
   else 
   {
      Print("Warning: Could not calculate 15th candle timing - Key Time not set.");
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
      datetime session_end_server_time = (datetime)(server_midnight_today + (long)((long)session_end_server_hour * 3600L + (long)session_End_UTC2_Minute * 60L));
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
bool YourBuyEntryConditionsMet(int closed_bar_index) 
{
   if (g_InitialBias != -1) return false; // Safety check, should be -1 if this is called

   g_trade_signal_this_bar = false; // Reset flag for this bar

   // Get current bar's price data (using the closed_bar_index passed, which is the 15th candle)
   double current_high = iHigh(Symbol(), Period(), closed_bar_index);
   double current_low  = iLow(Symbol(), Period(), closed_bar_index);
   double current_open = iOpen(Symbol(), Period(), closed_bar_index);
   double current_close= iClose(Symbol(), Period(), closed_bar_index);
   datetime current_bar_time = iTime(Symbol(), Period(), closed_bar_index);

   for (int i = 0; i < g_bullishOB_count; i++)
   {
      // Ensure OB is not mitigated and is relevant (formed before current bar)
      if (!g_bullishOrderBlocks[i].isMitigated && g_bullishOrderBlocks[i].startTime < current_bar_time)
      {
         // Interaction Check: Current bar's low wicks into or touches the OB zone
         // OB zone is from g_bullishOrderBlocks[i].low to g_bullishOrderBlocks[i].high
         bool price_is_interacting = (current_low <= g_bullishOrderBlocks[i].high && current_high >= g_bullishOrderBlocks[i].low);
         
         if (price_is_interacting)
         {
            Print(visual_comment_text + " - Buy Check: Interaction with Bullish OB @ ", TimeToString(g_bullishOrderBlocks[i].startTime, TIME_DATE|TIME_MINUTES), " (Low:", g_bullishOrderBlocks[i].low, ", High:", g_bullishOrderBlocks[i].high, ")");
            Print("Current Bar (", closed_bar_index, ") Low: ", current_low, ", High: ", current_high, ", Close: ", current_close);

            // Basic Price Action Confirmation:
            // 1. Candle wicks into the OB (current_low touches or goes below OB high, but preferably current_low < OB high for meaningful wick)
            // 2. Candle closes bullish (Close > Open)
            // 3. Candle closes above the midpoint of the OB
            // Refined: Current bar low must have wicked below the OB's *highest point* if the OB candle was bearish.
            // Let's assume OB's [low, high] range is what we defined as the visual rectangle.
            bool pa_confirmation_met = false;
            if (current_low < g_bullishOrderBlocks[i].high &&  // Wick pierced the OB's top
                current_close > current_open &&                  // Closed bullish
                current_close > (g_bullishOrderBlocks[i].high + g_bullishOrderBlocks[i].low) / 2.0) // Closed above OB midpoint
            {
               pa_confirmation_met = true;
               Print(visual_comment_text + " - Basic PA Confirmation MET for Bullish OB.");
            }
            
            // Add FVG and HTF Bias checks here if desired using placeholder functions
            // bool fvg_confluence = CheckForTradableFVG(closed_bar_index, POSITION_TYPE_BUY);
            // bool htf_aligned = YourHTFBiasCheck(PERIOD_H1, POSITION_TYPE_BUY);

            if (pa_confirmation_met) // && fvg_confluence && htf_aligned -> Add these when ready
            {
               g_triggered_ob_for_trade = g_bullishOrderBlocks[i]; // Store the OB that triggered
               g_trade_signal_this_bar = true;
               Print(visual_comment_text + " - !!! BUY Signal Confirmed on 15th Candle from Bullish OB @ ", TimeToString(g_triggered_ob_for_trade.startTime, TIME_DATE|TIME_MINUTES));
               return true; 
            }
         }
      }
   }
   return false; // No buy setup confirmed on this bar
}
//+------------------------------------------------------------------+
//| Placeholder function to check specific Sell Entry Conditions     |
//| YOU WILL INTEGRATE YOUR OB/FVG AND CONFIRMATION LOGIC HERE       |
//| This function runs on the 15th candle bar if bias is bullish (1) |
//+------------------------------------------------------------------+
    bool YourSellEntryConditionsMet(int closed_bar_index) 
{
   if (g_InitialBias != 1) return false; // Safety check

   g_trade_signal_this_bar = false; // Reset flag

   double current_high = iHigh(Symbol(), Period(), closed_bar_index);
   double current_low  = iLow(Symbol(), Period(), closed_bar_index);
   double current_open = iOpen(Symbol(), Period(), closed_bar_index);
   double current_close= iClose(Symbol(), Period(), closed_bar_index);
   datetime current_bar_time = iTime(Symbol(), Period(), closed_bar_index);

   for (int i = 0; i < g_bearishOB_count; i++)
   {
      if (!g_bearishOrderBlocks[i].isMitigated && g_bearishOrderBlocks[i].startTime < current_bar_time)
      {
         // Interaction Check: Current bar's high wicks into or touches the OB zone
         bool price_is_interacting = (current_low <= g_bearishOrderBlocks[i].high && current_high >= g_bearishOrderBlocks[i].low);

         if (price_is_interacting)
         {
            Print(visual_comment_text + " - Sell Check: Interaction with Bearish OB @ ", TimeToString(g_bearishOrderBlocks[i].startTime, TIME_DATE|TIME_MINUTES), " (Low:", g_bearishOrderBlocks[i].low, ", High:", g_bearishOrderBlocks[i].high, ")");
            Print("Current Bar (", closed_bar_index, ") Low: ", current_low, ", High: ", current_high, ", Close: ", current_close);

            // Basic Price Action Confirmation:
            // 1. Candle wicks into the OB (current_high touches or goes above OB low)
            // 2. Candle closes bearish (Close < Open)
            // 3. Candle closes below the midpoint of the OB
            bool pa_confirmation_met = false;
            if (current_high > g_bearishOrderBlocks[i].low && // Wick pierced the OB's bottom
                current_close < current_open &&                 // Closed bearish
                current_close < (g_bearishOrderBlocks[i].high + g_bearishOrderBlocks[i].low) / 2.0) // Closed below OB midpoint
            {
               pa_confirmation_met = true;
               Print(visual_comment_text + " - Basic PA Confirmation MET for Bearish OB.");
            }

            // Add FVG and HTF Bias checks here
            // bool fvg_confluence = CheckForTradableFVG(closed_bar_index, POSITION_TYPE_SELL);
            // bool htf_aligned = YourHTFBiasCheck(PERIOD_H1, POSITION_TYPE_SELL);

            if (pa_confirmation_met) // && fvg_confluence && htf_aligned
            {
               g_triggered_ob_for_trade = g_bearishOrderBlocks[i];
               g_trade_signal_this_bar = true;
               Print(visual_comment_text + " - !!! SELL Signal Confirmed on 15th Candle from Bearish OB @ ", TimeToString(g_triggered_ob_for_trade.startTime, TIME_DATE|TIME_MINUTES));
               return true;
            }
         }
      }
   }
   return false; // No sell setup confirmed
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
 
   // Example: Pass the specific Order Block struct or its index that confirmed the entry
  //+------------------------------------------------------------------+
//| Function to place a Buy Order                                    |
//| Takes the details of the OB that triggered the entry             |
//+------------------------------------------------------------------+
void PlaceBuyOrder(double risk_perc, double sl_buffer_pips_input, double tp_pips_placeholder_input, int bar_index, const st_OrderBlock &triggered_ob_ref)
{
   // Check if a trade was already attempted for this signal bar
   // if (PositionsTotal() > 0) { // Simple check if any position exists, can be refined to check for OUR magic number & symbol
   //    for(int i = PositionsTotal() -1; i >=0; i--) {
   //       if(PositionGetInteger(POSITION_MAGIC) == magic_Number && PositionGetString(POSITION_SYMBOL) == Symbol()) {
   //          Print(visual_comment_text, " - Trade already open for this signal. Skipping new Buy order.");
   //          return;
   //       }
   //    }
   // }
   for(int i = PositionsTotal() - 1; i >= 0; i--) 
   {
    if (PositionGetInteger(POSITION_MAGIC) == magic_Number && 
        PositionGetString(POSITION_SYMBOL) == Symbol()) {
        Print(visual_comment_text, " - An existing trade for this EA/Symbol (#", PositionGetTicket(i), ") is already open. Skipping new order.");
        return; // Exit if a trade by this EA on this symbol exists
    }
    }

   double entry_price = NormalizeDouble(SymbolInfoDouble(Symbol(), SYMBOL_ASK), _Digits); // Market entry at current ASK
   
   // SL based on the low of the *triggered* bullish OB (candle that was confirmed)
   // The triggered_ob_ref.low is the low of the *initial* candidate candle for that OB structure.
   // For simplicity and safety, we'll use this, but a more robust OB would define its overall structure's low.
   double sl_price_calc = triggered_ob_ref.low - sl_buffer_pips_input * _Point;
   sl_price_calc = NormalizeDouble(sl_price_calc, _Digits);

   // Ensure SL is at least SYMBOL_TRADE_STOPS_LEVEL points away
   long min_sl_distance_points = SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);
   if (entry_price - sl_price_calc < (double)min_sl_distance_points * _Point) {
       sl_price_calc = entry_price - (double)min_sl_distance_points * _Point * 1.1; // Add 10% buffer if too close
       sl_price_calc = NormalizeDouble(sl_price_calc, _Digits);
       Print(visual_comment_text + " - Adjusted SL for Buy order due to min stops level. New SL: ", sl_price_calc);
   }

   // TP calculation
   double tp_price_calc = entry_price + tp_pips_placeholder_input * _Point;
   tp_price_calc = NormalizeDouble(tp_price_calc, _Digits);
    // Ensure TP is at least SYMBOL_TRADE_STOPS_LEVEL points away
   if (tp_price_calc - entry_price < (double)min_sl_distance_points * _Point) {
       tp_price_calc = entry_price + (double)min_sl_distance_points * _Point * 1.1; // Add 10% buffer
       tp_price_calc = NormalizeDouble(tp_price_calc, _Digits);
       Print(visual_comment_text + " - Adjusted TP for Buy order due to min stops level. New TP: ", tp_price_calc);
   }


   double lot_size = CalculateLotSize(risk_perc, entry_price, sl_price_calc);

   if (lot_size > 0)
   {
      Print(visual_comment_text + " - Attempting BUY order: Lots=", lot_size, ", Entry~", entry_price, ", SL=", sl_price_calc, ", TP=", tp_price_calc, " triggered by OB @ ", TimeToString(triggered_ob_ref.startTime, TIME_DATE|TIME_MINUTES));
      // --- ACTUAL TRADING DISABLED ---
      // To enable, uncomment the line below AND ensure CTrade object is initialized in OnInit
      if (trade.Buy(lot_size, Symbol(), entry_price, sl_price_calc, tp_price_calc, "714EA_Buy_OB"))
      {
         Print(visual_comment_text + " - BUY Order Sent Successfully. Ticket: ", trade.ResultOrder());
      }
      else
      {
         Print(visual_comment_text + " - Error placing BUY order: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      }
   }
   else
   {
      Print(visual_comment_text + " - BUY Order NOT Placed. Calculated lot size is zero or invalid.");
   }
}
   
//+------------------------------------------------------------------+
//| Placeholder function to place a Sell Order                       |
//| YOU WILL IMPLEMENT THIS WHEN READY TO TRADE                      |
//| Should take the details of the OB/Zone that triggered the entry  |
//+------------------------------------------------------------------+
 
   // Example: Pass the specific Order Block struct or its index that confirmed the entry
 void PlaceSellOrder(double risk_perc, double sl_buffer_pips_input, double tp_pips_placeholder_input, int bar_index, const st_OrderBlock &triggered_ob_ref)
{
   //  if (PositionsTotal() > 0) 
   //  {
   //    for(int i = PositionsTotal() -1; i >=0; i--) 
   //    {
   //       if(PositionGetInteger(POSITION_MAGIC) == magic_Number && PositionGetString(POSITION_SYMBOL) == Symbol()) 
   //       {
   //          Print(visual_comment_text, " - Trade already open for this signal. Skipping new Sell order.");
   //          return;
   //       }
   //    }
   // }
   for(int i = PositionsTotal() - 1; i >= 0; i--) 
   {
    if (PositionGetInteger(POSITION_MAGIC) == magic_Number && 
        PositionGetString(POSITION_SYMBOL) == Symbol()) {
        Print(visual_comment_text, " - An existing trade for this EA/Symbol (#", PositionGetTicket(i), ") is already open. Skipping new order.");
        return; // Exit if a trade by this EA on this symbol exists
    }
    }

   double entry_price = NormalizeDouble(SymbolInfoDouble(Symbol(), SYMBOL_BID), _Digits); // Market entry at current BID

   // SL based on the high of the triggered bearish OB
   double sl_price_calc = triggered_ob_ref.high + sl_buffer_pips_input * _Point;
   sl_price_calc = NormalizeDouble(sl_price_calc, _Digits);
   
   // Ensure SL is at least SYMBOL_TRADE_STOPS_LEVEL points away
   long min_sl_distance_points = SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);
    if (sl_price_calc - entry_price < (double)min_sl_distance_points * _Point) {
       sl_price_calc = entry_price + (double)min_sl_distance_points * _Point * 1.1;
       sl_price_calc = NormalizeDouble(sl_price_calc, _Digits);
       Print(visual_comment_text + " - Adjusted SL for Sell order due to min stops level. New SL: ", sl_price_calc);
   }

   // TP calculation
   double tp_price_calc = entry_price - tp_pips_placeholder_input * _Point;
   tp_price_calc = NormalizeDouble(tp_price_calc, _Digits);
   // Ensure TP is at least SYMBOL_TRADE_STOPS_LEVEL points away
   if (entry_price - tp_price_calc < (double)min_sl_distance_points * _Point) {
       tp_price_calc = entry_price - (double)min_sl_distance_points * _Point * 1.1;
       tp_price_calc = NormalizeDouble(tp_price_calc, _Digits);
       Print(visual_comment_text + " - Adjusted TP for Sell order due to min stops level. New TP: ", tp_price_calc);
   }


   double lot_size = CalculateLotSize(risk_perc, entry_price, sl_price_calc);

   if (lot_size > 0)
   {
      Print(visual_comment_text + " - Attempting SELL order: Lots=", lot_size, ", Entry~", entry_price, ", SL=", sl_price_calc, ", TP=", tp_price_calc, " triggered by OB @ ", TimeToString(triggered_ob_ref.startTime, TIME_DATE|TIME_MINUTES));
      // --- ACTUAL TRADING DISABLED ---
      // To enable, uncomment the line below
      if (trade.Sell(lot_size, Symbol(), entry_price, sl_price_calc, tp_price_calc, "714EA_Sell_OB"))
      {
         Print(visual_comment_text + " - SELL Order Sent Successfully. Ticket: ", trade.ResultOrder());
      }
      else
      {
         Print(visual_comment_text + " - Error placing SELL order: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      }
   }
   else
   {
      Print(visual_comment_text + " - SELL Order NOT Placed. Calculated lot size is zero or invalid.");
   }
}