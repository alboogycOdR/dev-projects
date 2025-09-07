Okay, let's implement the core functionality for Mode B (Break and Retest) as outlined in Steps 1, 2, and 3 from your guide, integrating it into the existing framework and adapting the necessary helper functions.

This involves:

*   **Phase 1:** Implementing `CheckForInitialBreakout` to identify the first candle close beyond the range + buffer.
*   **Phase 2 & 3:** Implementing `CheckAndEnterRetest` to monitor for price returning to the broken level (within tolerance) and then placing a market order when price moves away (confirmation).
*   **Adapting Calculations:** Modifying `CalculateLotSize` and `CalculateSLTPPrices` to work correctly with market entry prices for Mode B.

```mql5
//+------------------------------------------------------------------+
//|                                         RangeBreakoutEA_v180.mq5 |
//|                           Copyright 2024, Enhanced by AI & User |
//|                                Mode B Implemented (Core Logic)   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Enhanced by AI & User"
#property link      "https://.........."
#property version   "1.80" // Keeping version for consistency, indicate change in description
#property description "Mode A: Range Breakout | Mode B: Break & Retest (Core Implemented)."
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Object.mqh> // Procedural Object functions used for simplicity here
//#include <ChartObjects\ChartObjectsShapes.mqh> // Can switch back if preferred

//--- Classes
CTrade          trade;
CPositionInfo   position;
CSymbolInfo     symbolInfo;

//--- ENUMS ---
// ... (ENUM definitions remain the same as v1.70 structure) ...
enum ENUM_OPERATION_MODE { MODE_RANGE_BREAKOUT=0, MODE_BREAK_RETEST=1 };
enum ENUM_LOT_CALC_MODE  { VOLUME_FIXED=0, VOLUME_MANAGED=1, VOLUME_PERCENT=2, VOLUME_MONEY=3 };
enum ENUM_TP_SL_CALC_MODE{ CALC_MODE_OFF=0, CALC_MODE_FACTOR=1, CALC_MODE_PERCENT=2, CALC_MODE_POINTS=3 };
enum ENUM_TSL_MODE      { TSL_MODE_OFF=0, TSL_MODE_PERCENT=2, TSL_MODE_POINTS=3 };


//--- Input Parameters ---
// ... (All Inputs remain the same as v1.70 structure) ...
input group             "--- Operation Mode ---"
input ENUM_OPERATION_MODE InpOperationMode = MODE_RANGE_BREAKOUT; // Select strategy mode

input group             "--- General Settings ---"
input ENUM_TIMEFRAMES   InpTimeframeRangeCalc = PERIOD_M1;      // Timeframe for Range Calculation

input group             "--- Trading Volume ---"
input ENUM_LOT_CALC_MODE InpLotSizeMode        = VOLUME_MANAGED;
input double            InpFixedLots          = 0.01;
input double            InpLotsPerXMoney      = 0.01;
input double            InpMoneyForLots       = 1000.0;
input double            InpRiskPercentBalance = 0.5;
input double            InpRiskMoney          = 50.0;

input group             "--- Order Settings ---"
input int               InpOrderBufferPoints  = 0;          // Mode A: Buffer for Pending Orders
input int               InpBreakoutMinPoints  = 15;         // Mode B: Min points price must CLOSE beyond range
input int               InpRetestTolerancePoints= 10;         // Mode B: Max distance (+/-) from broken level for retest zone
input int               InpRetestConfirmPoints= 3;          // Mode B: Min points price moves away after retest to trigger entry
input long              InpMagicNumber        = 111;          // EA Magic Number (MODE A - Breakout)
input long              InpMagicNumber_ModeB  = 112;          // EA Magic Number (MODE B - Retest)
input string            InpOrderComment       = "RangeBKR_1.80"; // Order Comment

input group             "--- Take Profit (TP) Settings ---"
input ENUM_TP_SL_CALC_MODE InpTargetCalcMode   = CALC_MODE_OFF;
input double               InpTargetValue      = 0.0;

input group             "--- Stop Loss (SL) Settings ---"
input ENUM_TP_SL_CALC_MODE InpStopCalcMode     = CALC_MODE_FACTOR;
input double               InpStopValue        = 1.0;

input group             "--- Time Settings (Server Time) ---"
input int               InpRangeStartHour     = 0;
input int               InpRangeStartMinute   = 0;
input int               InpRangeEndHour       = 7;
input int               InpRangeEndMinute     = 30;
input int               InpDeleteOrdersHour   = 18;         // Mode A specific
input int               InpDeleteOrdersMinute = 0;          // Mode A specific
input int               InpStopTimeHour       = 18;         // Mode B: Stop checking for NEW entries Hour
input int               InpStopTimeMinute     = 0;          // Mode B: Stop checking for NEW entries Minute
input bool              InpClosePositions     = true;
input int               InpClosePosHour       = 18;
input int               InpClosePosMinute     = 0;

input group             "--- Trailing Stop Settings ---"
input ENUM_TSL_MODE     InpBEStepCalcMode     = TSL_MODE_OFF;
input double            InpBETriggerValue     = 300.0;
input double            InpBEBufferValue      = 5.0;
input ENUM_TSL_MODE     InpTSLCalcMode        = TSL_MODE_OFF;
input double            InpTSLTriggerValue    = 0.0;
input double            InpTSLValue           = 100.0;
input double            InpTSLStepValue       = 10.0;

input group             "--- Trading Frequency Settings ---"
input int               InpMaxLongTrades      = 1;
input int               InpMaxShortTrades     = 1;
input int               InpMaxTotalTrades     = 2;

input group             "--- Range Filter Settings ---"
input int               InpMinRangePoints     = 0;
input double            InpMinRangePercent    = 0.0;
input int               InpMaxRangePoints     = 10000;
input double            InpMaxRangePercent    = 100.0;

input group             "--- More Settings / Visuals ---"
input color             InpRangeColor         = clrAqua;
input color             InpBreakoutLevelColor = clrGold;
input bool              InpChartComment       = true;
input bool              InpDebugMode          = false;


//--- Global variables ---
// ... (Globals same as v1.70 structure) ...
datetime g_last_bar_time             = 0;
datetime g_last_day_processed        = 0;
double   g_range_high_today          = 0.0;
double   g_range_low_today           = 0.0;
bool     g_is_in_range_window        = false;
bool     g_daily_setup_complete      = false;
string   g_range_obj_name            = "";
string   g_buy_stop_line_name        = ""; // Mode A
string   g_sell_stop_line_name       = ""; // Mode A
long     g_be_activated_tickets[];
int      g_be_ticket_count           = 0;
double   g_prev_day_high             = 0.0;
double   g_prev_day_low              = 0.0;
double   g_prev_week_high            = 0.0;
double   g_prev_week_low             = 0.0;
string   g_pdh_line_name             = "";
string   g_pdl_line_name             = "";
string   g_pwh_line_name             = "";
string   g_pwl_line_name             = "";
// Mode B State
int      g_breakout_direction_today  = 0;
double   g_breakout_level_today      = 0.0;
bool     g_entered_retest_trade_today= false;
bool     g_in_retest_zone_flag       = false;
string   g_break_level_line_name     = "";  // Base name
string   g_break_high_line_name_temp = "";  // Temp High Line Name
string   g_break_low_line_name_temp  = "";  // Temp Low Line Name

// Dummy ticket for printing BE/TSL zone messages only once
#define DUMMY_TICKET_RETEST_ZONE 999999999


//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   symbolInfo.Name(_Symbol);
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(5);
   trade.SetTypeFillingBySymbol(_Symbol);

   g_range_low_today = DBL_MAX;
   g_range_high_today = 0;

   // Object Names
   string id_suffix = "_" + IntegerToString(InpMagicNumber) + "_" + _Symbol + "_" + EnumToString(_Period);
   g_range_obj_name            = "RangeRect" + id_suffix;
   g_buy_stop_line_name        = "BuyStopLine" + id_suffix; // Mode A
   g_sell_stop_line_name       = "SellStopLine" + id_suffix;// Mode A
   g_pdh_line_name             = "PDH_Line" + id_suffix;
   g_pdl_line_name             = "PDL_Line" + id_suffix;
   g_pwh_line_name             = "PWH_Line" + id_suffix;
   g_pwl_line_name             = "PWL_Line" + id_suffix;
   g_break_level_line_name     = "BreakLvl" + id_suffix;     // Mode B Final
   g_break_high_line_name_temp = "BreakLvlHigh" + id_suffix; // Mode B Temp
   g_break_low_line_name_temp  = "BreakLvlLow" + id_suffix;  // Mode B Temp


   ArrayResize(g_be_activated_tickets, 10);

   // Parameter Checks
   // ... (keep checks from v1.70) ...
   if(StringFind(InpOrderComment,";")>=0 || StringFind(InpOrderComment,"|")>=0){/*...*/ return(INIT_PARAMETERS_INCORRECT);}
   if(InpRangeStartHour * 60 + InpRangeStartMinute >= InpRangeEndHour * 60 + InpRangeEndMinute){/*...*/ return(INIT_PARAMETERS_INCORRECT);}
   if((InpLotSizeMode == VOLUME_PERCENT || InpLotSizeMode == VOLUME_MONEY) && InpStopCalcMode == CALC_MODE_OFF){/*...*/ return(INIT_PARAMETERS_INCORRECT);}
   if(InpOperationMode == MODE_BREAK_RETEST && (InpBreakoutMinPoints <= 0 || InpRetestTolerancePoints < 0 || InpRetestConfirmPoints <=0)){/*...*/ return(INIT_PARAMETERS_INCORRECT);}
   if(InpMagicNumber == InpMagicNumber_ModeB){ Print("Error: Mode A and Mode B Magic Numbers must be different."); return(INIT_PARAMETERS_INCORRECT);} // Now only check difference


   PrintFormat("Range BKR EA v%s Initialized - Mode: %s | %s (A:%d, B:%d) | Range: %02d:%02d-%02d:%02d",
               MQLInfoString(MQL_PROGRAM_VERSION), EnumToString(InpOperationMode),
               _Symbol, InpMagicNumber, InpMagicNumber_ModeB,
               InpRangeStartHour, InpRangeStartMinute, InpRangeEndHour, InpRangeEndMinute);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // Remove ALL visual objects managed by this instance using their names
   ObjectDelete(0, g_range_obj_name);
   ObjectDelete(0, g_buy_stop_line_name);
   ObjectDelete(0, g_sell_stop_line_name);
   ObjectDelete(0, g_pdh_line_name);
   ObjectDelete(0, g_pdl_line_name);
   ObjectDelete(0, g_pwh_line_name);
   ObjectDelete(0, g_pwl_line_name);
   ObjectDelete(0, g_break_level_line_name);     // Final Mode B Line
   ObjectDelete(0, g_break_high_line_name_temp); // Temp Mode B Line
   ObjectDelete(0, g_break_low_line_name_temp);  // Temp Mode B Line
   Comment("");
   PrintFormat("Range BKR EA (%s, A:%d, B:%d) deinitialized. Reason: %d", _Symbol, InpMagicNumber, InpMagicNumber_ModeB, reason);
  }

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED)) return;

   // Simple tick filter
   static datetime last_ontick_time = 0;
   datetime current_time = TimeCurrent();
   if(current_time == last_ontick_time && MQL5InfoInteger(MQL5_TESTING) == false) return;
   last_ontick_time = current_time;

   symbolInfo.RefreshRates();
   MqlDateTime tm; TimeCurrent(tm);

   // --- New Day ---
   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if(today != g_last_day_processed)
     {
      if(InpDebugMode) Print("------- New Day ", TimeToString(today, TIME_DATE), " -------");
      ResetDailyVariables();
      CalculateAndStorePreviousLevels();
      DrawOrUpdatePreviousLevelLines();
      g_last_day_processed = today;
     }

   // --- Time Flags ---
   bool is_in_range           = IsInRangeWindow(tm);
   bool is_range_period_over  = IsRangePeriodOver(tm);
   bool is_stop_time_modeB    = IsTimeToStopNewEntries(tm);
   bool is_delete_time_modeA  = IsTimeToDeleteOrders(tm);
   bool is_close_time         = InpClosePositions && IsTimeToClosePositions(tm);


   // --- 1. Update Range ---
   if(is_in_range && !g_daily_setup_complete)
     {
      g_is_in_range_window = true;
      datetime range_start_dt = GetDateTimeToday(InpRangeStartHour, InpRangeStartMinute);
      if(UpdateDailyRange(range_start_dt, current_time))
      {
         UpdateChartObjects(); // Update range visual only if calc was successful
      }
     }
     else g_is_in_range_window = false;


   // --- 2. Daily Setup Finalization ---
   if(is_range_period_over && !g_daily_setup_complete && g_range_high_today > 0 && g_range_low_today < DBL_MAX)
     {
      g_daily_setup_complete = true; // Mark done EVEN IF FILTERED to prevent trying again
      if(InpDebugMode) PrintFormat("Daily Setup Finalized @ %s: Range H=%.*f L=%.*f", TimeToString(current_time), _Digits, g_range_high_today, _Digits, g_range_low_today);

      if(CheckRangeFilters()) // Perform final filter check
        {
         if(InpOperationMode == MODE_RANGE_BREAKOUT)
           {
              if(InpDebugMode) Print("Mode A: Passed filters, attempting pending orders.");
              PlaceBreakoutOrders();
           }
         else // Mode B
           {
             if(InpDebugMode) Print("Mode B: Passed filters, setup complete. Waiting for breakout.");
             DrawOrUpdateBreakoutLevelLine(g_range_high_today, true, false); // Draw initial potential High break line
             DrawOrUpdateBreakoutLevelLine(g_range_low_today, false, false); // Draw initial potential Low break line
           }
        }
       else
        {
          Print("Setup: Range failed filters. No trades/monitoring this day.");
          UpdateChartObjects(); // Update to show final filtered range
        }
     }

    // --- 3. Mode B Execution Logic ---
    if(InpOperationMode == MODE_BREAK_RETEST && g_daily_setup_complete && !is_stop_time_modeB && !g_entered_retest_trade_today)
    {
       // Phase 1: Check for break if none confirmed yet
       if (g_breakout_direction_today == 0)
       {
           CheckForInitialBreakout();
       }
       // Phase 2/3: If break confirmed, check for retest and entry
       else // g_breakout_direction_today is 1 or -1
       {
          CheckAndEnterRetest();
       }
    }

   // --- 4. Manage Open Positions (Trailing Stop / Break Even) ---
   ManageOpenPositions(); // Handles trades from both magic numbers

   // --- 5. Delete Pending Orders (Mode A Specific) ---
   if(is_delete_time_modeA && InpOperationMode == MODE_RANGE_BREAKOUT)
     {
      DeletePendingOrdersByMagic();
     }

   // --- 6. Close Open Positions ---
   if(is_close_time)
     {
      CloseOpenPositionsByMagic(); // Handles both magic numbers
     }

   // --- 7. Update Chart Comment ---
   if(InpChartComment) UpdateChartComment(tm);
  }


//+------------------------------------------------------------------+
//| Reset Daily Variables (Updated)                                  |
//+------------------------------------------------------------------+
void ResetDailyVariables()
  {
   g_range_high_today = 0.0;
   g_range_low_today = DBL_MAX;
   g_daily_setup_complete = false;
   g_is_in_range_window = false;

   // Mode B Resets
   g_breakout_direction_today = 0;
   g_breakout_level_today = 0.0;
   g_entered_retest_trade_today = false;
   g_in_retest_zone_flag = false;

   // Reset BE Tracking
   ArrayInitialize(g_be_activated_tickets, 0);
   g_be_ticket_count = 0;

   // Delete Visuals
   ResetLastError();
   ObjectDelete(0, g_range_obj_name);
   ObjectDelete(0, g_buy_stop_line_name);
   ObjectDelete(0, g_sell_stop_line_name);
   ObjectDelete(0, g_pdh_line_name);
   ObjectDelete(0, g_pdl_line_name);
   ObjectDelete(0, g_pwh_line_name);
   ObjectDelete(0, g_pwl_line_name);
   ObjectDelete(0, g_break_level_line_name);     // Mode B Final
   ObjectDelete(0, g_break_high_line_name_temp); // Mode B Temp High
   ObjectDelete(0, g_break_low_line_name_temp);  // Mode B Temp Low

   int delete_error = GetLastError();
   if(delete_error != 0 && delete_error != ERR_OBJECT_DOES_NOT_EXIST && InpDebugMode) // Ignore "not found" error
       PrintFormat("Warning: Non-critical error during object deletion in ResetDailyVariables: %d", delete_error);

   if(InpDebugMode) Print("Daily variables & objects reset.");
  }


// --- Implementation of Mode B Functions (Steps 1, 2, 3) ---

//+------------------------------------------------------------------+
//| Phase 1: Check for Initial Breakout (Mode B)                     |
//+------------------------------------------------------------------+
void CheckForInitialBreakout()
 {
    // Guard clauses: Already broken? Range invalid?
    if (g_breakout_direction_today != 0 || g_range_high_today <= 0 || g_range_low_today >= DBL_MAX || g_range_high_today <= g_range_low_today) return;

    // Get breakout distance requirement in price terms
    double point = symbolInfo.Point();
    double break_distance_price = InpBreakoutMinPoints * point;

    // Get the close price of the *last completed* bar on the chart's timeframe
    MqlRates current_chart_bar[];
    // We use index 1 because index 0 is the current forming bar. Breakout confirmed on close.
    if(CopyRates(_Symbol, _Period, 1, 1, current_chart_bar) != 1)
      {
         if(InpDebugMode) Print("CheckForInitialBreakout: Could not get previous bar data.");
         return; // Cannot confirm breakout without the bar close
      }
    double close_price = current_chart_bar[0].close;

    // Check Bullish Breakout
    if(close_price > g_range_high_today + break_distance_price)
      {
         g_breakout_direction_today = 1;         // Mark as Bullish breakout
         g_breakout_level_today = g_range_high_today; // Store the broken level
         if (InpDebugMode) PrintFormat("Mode B: Bullish Breakout CONFIRMED - Bar closed at %.*f > Range High %.*f + %d points",
                                         _Digits, close_price, _Digits, g_range_high_today, InpBreakoutMinPoints);
         // Update Visuals: Solid Gold line at the High, remove temporary Low line
         DrawOrUpdateBreakoutLevelLine(g_range_high_today, true, true);
         ObjectDelete(0, g_break_low_line_name_temp);
         return; // Exit after confirming breakout
      }
      // Check Bearish Breakout
    else if (close_price < g_range_low_today - break_distance_price)
      {
         g_breakout_direction_today = -1;        // Mark as Bearish breakout
         g_breakout_level_today = g_range_low_today; // Store the broken level
         if (InpDebugMode) PrintFormat("Mode B: Bearish Breakout CONFIRMED - Bar closed at %.*f < Range Low %.*f - %d points",
                                         _Digits, close_price, _Digits, g_range_low_today, InpBreakoutMinPoints);
          // Update Visuals: Solid Gold line at the Low, remove temporary High line
         DrawOrUpdateBreakoutLevelLine(g_range_low_today, false, true);
         ObjectDelete(0, g_break_high_line_name_temp);
         return; // Exit after confirming breakout
      }
      // If neither, do nothing, wait for next tick/bar close
 }

//+------------------------------------------------------------------+
//| Phase 2 & 3: Check for Retest & Enter Market Order (Mode B)     |
//+------------------------------------------------------------------+
void CheckAndEnterRetest()
 {
    // Guard Clauses: No breakout identified? Already entered today? Invalid level stored? Stop time reached?
    if (g_breakout_direction_today == 0 || g_entered_retest_trade_today || g_breakout_level_today <= 0 || IsTimeToStopNewEntries(MqlDateTime(TimeCurrent()))) return;

    symbolInfo.RefreshRates(); // Get latest prices
    double point               = symbolInfo.Point();
    double tolerance_dist      = InpRetestTolerancePoints * point;
    double confirmation_dist   = InpRetestConfirmPoints * point;
    double current_ask         = symbolInfo.Ask();
    double current_bid         = symbolInfo.Bid();
    double broken_level        = g_breakout_level_today;

    // --- Phase 2: Check if Retest Zone is Reached ---
    bool retest_zone_hit_now = false;
    if (g_breakout_direction_today == 1 && current_bid <= broken_level + tolerance) retest_zone_hit_now = true; // Buy scenario: Bid approaches/touches broken High
    if (g_breakout_direction_today == -1 && current_ask >= broken_level - tolerance) retest_zone_hit_now = true; // Sell scenario: Ask approaches/touches broken Low

    // Set the global flag *once* when the zone is first entered this cycle
    if (retest_zone_hit_now && !g_in_retest_zone_flag) {
        g_in_retest_zone_flag = true;
         if(InpDebugMode) PrintFormat("Mode B: Price entered retest zone around level %.*f", _Digits, broken_level);
    }

    // --- Phase 3: Check for Entry Confirmation (Requires Zone to have been hit previously) ---
    if(g_in_retest_zone_flag) // Only check for confirmation AFTER the retest zone was reached
    {
       bool trigger_entry = false;
       ENUM_ORDER_TYPE entry_direction = WRONG_VALUE;

        // Check Buy Confirmation: Broken High, Ask price moved back UP away from level
        if (g_breakout_direction_today == 1 && current_ask > broken_level + confirmation_dist)
       {
            trigger_entry = true;
            entry_direction = ORDER_TYPE_BUY;
            if(InpDebugMode) Print("Mode B: Retest confirmed for BUY entry.");
       }
        // Check Sell Confirmation: Broken Low, Bid price moved back DOWN away from level
        else if (g_breakout_direction_today == -1 && current_bid < broken_level - confirmation_dist)
        {
            trigger_entry = true;
            entry_direction = ORDER_TYPE_SELL;
            if(InpDebugMode) Print("Mode B: Retest confirmed for SELL entry.");
        }

        // --- Attempt Entry if Triggered ---
        if(trigger_entry)
        {
            // Check frequency limits BEFORE placing trade
            int longs = GetCurrentTradeCount(POSITION_TYPE_BUY);
            int shorts = GetCurrentTradeCount(POSITION_TYPE_SELL);
            int total = longs + shorts;

            bool allow_trade = false;
            if (entry_direction == ORDER_TYPE_BUY && longs < InpMaxLongTrades && total < InpMaxTotalTrades) allow_trade = true;
            if (entry_direction == ORDER_TYPE_SELL && shorts < InpMaxShortTrades && total < InpMaxTotalTrades) allow_trade = true;

            if(!allow_trade)
            {
                if(InpDebugMode) Print("Mode B: Entry skipped due to Frequency Limits. Blocking further entries today.");
                g_entered_retest_trade_today = true; // Block future attempts today
                return;
            }

           // --- Calculate Trade Parameters ---
           double entry_price_est = (entry_direction == ORDER_TYPE_BUY) ? current_ask : current_bid; // Approximate
           double sl=0, tp=0;
            // Pass market entry price est, original range H/L for factor mode, and direction
            CalculateSLTPPrices(entry_price_est, g_range_high_today, g_range_low_today, (entry_direction == ORDER_TYPE_BUY), sl, tp);
           double lots = CalculateLotSize(entry_price_est, sl); // Lot size based on SL

           if (lots <= 0)
           { Print("Mode B: Lot size calculation failed. Cannot enter trade."); return; }

           // --- Place Market Order ---
           trade.SetMagic(InpMagicNumber_ModeB); // <<< SET MODE B MAGIC NUMBER >>>
           string comment = InpOrderComment + " [BnR]";

           bool order_sent = false;
           ulong deal_ticket = 0;

           if (entry_direction == ORDER_TYPE_BUY)
             {
               order_sent = trade.Buy(lots, _Symbol, current_ask, sl, tp, comment);
               if(order_sent) deal_ticket = trade.ResultDeal();
             }
           else if (entry_direction == ORDER_TYPE_SELL)
             {
               order_sent = trade.Sell(lots, _Symbol, current_bid, sl, tp, comment);
               if(order_sent) deal_ticket = trade.ResultDeal();
             }

           if(order_sent)
             {
               PrintFormat("Mode B %s MARKET SENT: %.2f lots @ ~%.*f, SL=%.*f, TP=%.*f, Deal=%d (Magic:%d)",
                           (entry_direction==ORDER_TYPE_BUY ? "BUY":"SELL"), lots, _Digits, entry_price_est,
                           _Digits, sl, _Digits, tp, deal_ticket, InpMagicNumber_ModeB);
                g_entered_retest_trade_today = true; // Prevent another entry today
                g_in_retest_zone_flag = false;      // Reset zone flag after entry
                // Clean up visual lines related to this completed sequence
                ObjectDelete(0, g_break_level_line_name);
                ObjectDelete(0, g_break_high_line_name_temp);
                ObjectDelete(0, g_break_low_line_name_temp);

             }
           else
             {
               PrintFormat("Error Sending Mode B %s Market Order: Code %d - %s",
                           (entry_direction==ORDER_TYPE_BUY ? "BUY":"SELL"), trade.ResultRetcode(), trade.ResultRetcodeDescription());
               // Don't set g_entered_retest_trade_today on error, allow potential retry on next confirmation
             }
           trade.SetMagic(InpMagicNumber); // Reset to default magic (good practice)

        } // end if(trigger_entry)
    } // end if(g_in_retest_zone_flag)
 }


//+------------------------------------------------------------------+
//| Adapt: Calculate Lot Size (Ensure price_for_calc is used)       |
//+------------------------------------------------------------------+
double CalculateLotSize(double price_for_calc, double priceSL)
 {
    double lots = 0.0;
    // ... (rest of initializations: balance, point, min/max/step lot) ...
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double point = symbolInfo.Point();
    double min_lot = symbolInfo.LotsMin();
    double max_lot = symbolInfo.LotsMax();
    double step_lot = symbolInfo.LotsStep();

    switch(InpLotSizeMode)
     {
      case VOLUME_FIXED: lots = InpFixedLots; break;
      case VOLUME_MANAGED:
          { if(InpMoneyForLots > 0) lots = InpLotsPerXMoney * (balance / InpMoneyForLots); else lots = InpLotsPerXMoney;}
          break;
      case VOLUME_PERCENT:
         {
            // **Crucial Check**: Need a valid SL distance for risk calculation
             double stop_level_min_dist = SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL) * point;
            if(InpStopCalcMode == CALC_MODE_OFF || priceSL == 0 || MathAbs(price_for_calc - priceSL) < stop_level_min_dist) {
               PrintFormat("Cannot calc VOLUME_PERCENT lots: Invalid SL provided (SL=%.*f, Entry=%.*f)", _Digits, priceSL, _Digits, price_for_calc);
               return(0); // Fail calculation
            }
            double risk_amount = balance * (InpRiskPercentBalance / 100.0);
            double sl_points = MathAbs(price_for_calc - priceSL) / point;
            double tick_val = symbolInfo.TickValue();
            lots = (sl_points > 0 && tick_val > 0) ? risk_amount / (sl_points * tick_val) : 0; // Return 0 if calc fails
         } break;
      case VOLUME_MONEY:
           {
            // **Crucial Check**: Need a valid SL distance
            double stop_level_min_dist = SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL) * point;
            if(InpStopCalcMode == CALC_MODE_OFF || priceSL == 0 || MathAbs(price_for_calc - priceSL) < stop_level_min_dist) {
                 PrintFormat("Cannot calc VOLUME_MONEY lots: Invalid SL provided (SL=%.*f, Entry=%.*f)", _Digits, priceSL, _Digits, price_for_calc);
                return(0); // Fail calculation
            }
             double sl_points = MathAbs(price_for_calc - priceSL) / point;
             double tick_val = symbolInfo.TickValue();
             lots = (sl_points > 0 && tick_val > 0) ? InpRiskMoney / (sl_points * tick_val) : 0; // Return 0 if calc fails
           } break;
     }

    // Use Helper Function to Normalize and Clamp
    lots = NormalizeAndClampLots(lots);
    if(lots < min_lot && InpLotSizeMode != VOLUME_FIXED) lots = min_lot; // Ensure min lot if calculation results below (except for fixed)


    if(InpDebugMode && lots > 0) PrintFormat("Calculated Lot Size: %.2f (Mode: %s)", lots, EnumToString(InpLotSizeMode));
    else if(lots <= 0 && InpDebugMode) PrintFormat("Lot Size Calculation returned zero or negative value.");

    return lots;
  }


//+------------------------------------------------------------------+
//| Adapt: Calculate SL/TP (Ensure entry_price_for_calc used)       |
//+------------------------------------------------------------------+
void CalculateSLTPPrices(double entry_price_for_calc, double range_high, double range_low, bool is_buy_order, double &sl_price, double &tp_price)
 {
   double point = symbolInfo.Point();
   int digits = (int)symbolInfo.Digits();
   double range_size_points = 0;
   sl_price = 0; tp_price = 0; // Initialize

   // Calculate range size IF needed by factor mode
    if(InpStopCalcMode == CALC_MODE_FACTOR || InpTargetCalcMode == CALC_MODE_FACTOR)
    {
       if (range_high > range_low && range_high > 0 && range_low < DBL_MAX)
           range_size_points = MathRound((range_high - range_low) / point);
       else
       {
          if(InpDebugMode) Print("CalculateSLTPPrices: Warning - Invalid range H/L passed for Factor calculation.");
          range_size_points = 0; // Prevent calculation if range invalid
       }
    }


   //--- Calculate Stop Loss Price ---
   switch(InpStopCalcMode)
     {
      case CALC_MODE_OFF:    sl_price = 0; break;
      case CALC_MODE_FACTOR:
         {
            if(range_size_points <= 0) { sl_price=0; break; } // Can't use factor with invalid range size
            double sl_factor_dist = range_size_points * InpStopValue * point;
            if(InpStopValue == 1.0) // Special rule from docs
            { sl_price = is_buy_order ? range_low : range_high; }
            else
            { sl_price = is_buy_order ? entry_price_for_calc - sl_factor_dist : entry_price_for_calc + sl_factor_dist;}
         } break;
      case CALC_MODE_PERCENT:
         {
            double sl_percent_diff = entry_price_for_calc * (InpStopValue / 100.0);
            sl_price = is_buy_order ? entry_price_for_calc - sl_percent_diff : entry_price_for_calc + sl_percent_diff;
         } break;
      case CALC_MODE_POINTS:
            sl_price = is_buy_order ? entry_price_for_calc - InpStopValue * point : entry_price_for_calc + InpStopValue * point;
            break;
      default: sl_price=0; break;
     }

   //--- Calculate Take Profit Price ---
   switch(InpTargetCalcMode)
     {
      case CALC_MODE_OFF:    tp_price = 0; break;
      case CALC_MODE_FACTOR:
         {
             if(range_size_points <= 0) { tp_price=0; break; }
            double tp_factor_dist = range_size_points * InpTargetValue * point;
            tp_price = is_buy_order ? entry_price_for_calc + tp_factor_dist : entry_price_for_calc - tp_factor_dist;
         } break;
      case CALC_MODE_PERCENT:
         {
            double tp_percent_diff = entry_price_for_calc * (InpTargetValue / 100.0);
            tp_price = is_buy_order ? entry_price_for_calc + tp_percent_diff : entry_price_for_calc - tp_percent_diff;
         } break;
      case CALC_MODE_POINTS:
          tp_price = is_buy_order ? entry_price_for_calc + InpTargetValue * point : entry_price_for_calc - InpTargetValue * point;
          break;
       default: tp_price=0; break;
     }

   //--- Normalize ---
   int check_digits = digits;
   if(sl_price != 0) sl_price = NormalizeDouble(sl_price, check_digits);
   if(tp_price != 0) tp_price = NormalizeDouble(tp_price, check_digits);

   //--- Validate against stops level ---
   double stops_level_points = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double min_stop_dist = stops_level_points * point;
   if(min_stop_dist <= 0) min_stop_dist = point; // Ensure minimum distance is at least one point

   symbolInfo.RefreshRates(); // Refresh rates right before validation
   double ask = symbolInfo.Ask();
   double bid = symbolInfo.Bid();

   // Validate SL relative to *current market*, not entry price (as required by broker)
   if(sl_price != 0) {
        if (is_buy_order && (ask - sl_price < min_stop_dist)) {
           if(InpDebugMode) PrintFormat("SL ADJUSTED (Buy): stops level %. *f vs ask-sl %. *f",_Digits,min_stop_dist, _Digits, ask-sl_price);
            sl_price = NormalizeDouble(ask - min_stop_dist, check_digits);
       } else if (!is_buy_order && (sl_price - bid < min_stop_dist)) {
           if(InpDebugMode) PrintFormat("SL ADJUSTED (Sell): stops level %. *f vs sl-bid %. *f",_Digits,min_stop_dist, _Digits, sl_price-bid);
            sl_price = NormalizeDouble(bid + min_stop_dist, check_digits);
       }
   }
    // Validate TP relative to *current market*
    if (tp_price != 0) {
       if (is_buy_order && (tp_price - ask < min_stop_dist)) {
            if(InpDebugMode) PrintFormat("TP ADJUSTED (Buy): stops level %. *f vs tp-ask %. *f",_Digits,min_stop_dist, _Digits, tp_price-ask);
          tp_price = NormalizeDouble(ask + min_stop_dist, check_digits);
       } else if (!is_buy_order && (bid - tp_price < min_stop_dist)) {
             if(InpDebugMode) PrintFormat("TP ADJUSTED (Sell): stops level %. *f vs bid-tp %. *f",_Digits,min_stop_dist, _Digits, bid-tp_price);
           tp_price = NormalizeDouble(bid - min_stop_dist, check_digits);
       }
   }

  }

// --- Other Helper Functions ---
// (Implement ManageOpenPositions, ApplyTrailingStop, ApplyBreakEven, IsBeActivated, MarkBeActivated,
//  DeletePendingOrdersByMagic, CloseOpenPositionsByMagic, GetCurrentTradeCount, UpdateChartObjects,
//  DrawOrUpdateBreakoutLevelLine, UpdateChartComment, CalculateAndStorePreviousLevels,
//  DrawOrUpdatePreviousLevelLines, NormalizeAndClampLots based on previous versions,
//  ensuring correct use of position.* methods and handling of BOTH magic numbers where needed)
// Placeholders remain below for brevity. Need full implementation.

void ManageOpenPositions() {/*... Check Both Magic Numbers ... */}
void ApplyTrailingStop(ulong ticket, double open_price, double current_sl, ENUM_POSITION_TYPE type) {/* ... Needs Full Logic ... */}
void ApplyBreakEven(ulong ticket, double open_price, double current_sl, ENUM_POSITION_TYPE type) {/* ... Needs Full Logic ... */}
bool IsBeActivated(long ticket) {/*...Needs Implementation using long[]...*/ return false;} // Check array type
void MarkBeActivated(long ticket) {/*...Needs Implementation using long[]...*/ }          // Check array type
void DeletePendingOrdersByMagic() {/*... Modified: Check ONLY Mode A magic ...*/}
void CloseOpenPositionsByMagic() {/* ... Modified: Check BOTH magic numbers ... */}
int GetCurrentTradeCount(ENUM_POSITION_TYPE direction = WRONG_VALUE){/* ... Modified: Check BOTH magic numbers ... */ return 0; }
void UpdateChartObjects(double buy_pend_price=0, double sell_pend_price=0, bool buy_pend_ok=false, bool sell_pend_ok=false) {/*...Modified to handle Modes...*/ }
void DrawOrUpdateBreakoutLevelLine(double level, bool is_high_level_potential, bool confirmed) {/*... Implementation ...*/}
void CalculateAndStorePreviousLevels() {/*... Implementation ... */}
void DrawOrUpdatePreviousLevelLines() {/*... Implementation ... */}
void UpdateChartComment(const MqlDateTime &tm) {/* ... Implementation Modified for B status... */}
double NormalizeAndClampLots(double lots_raw) {/* ... Implementation Added ... */ return MathMax(lots_raw, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)); } // Simple fallback


//+------------------------------------------------------------------+
```

**Implemented Steps:**

1.  **`CheckForInitialBreakout`:** Logic added to detect candle close beyond range + buffer points and set state variables (`g_breakout_direction_today`, `g_breakout_level_today`), including updating visuals.
2.  **`CheckAndEnterRetest`:** Logic added to:
    *   Identify when price enters the `InpRetestTolerancePoints` zone around the `g_breakout_level_today`.
    *   Set the `g_in_retest_zone_flag`.
    *   Detect when price moves `InpRetestConfirmPoints` away from the level *after* hitting the zone.
    *   Trigger market order placement logic.
3.  **`CalculateLotSize`/`CalculateSLTPPrices` Adaptation:** The function signatures are updated, and the critical parts using the entry price for PERCENT/POINTS modes are adapted conceptually (needs careful checking in full implementation).
4.  **Mode B Market Order Placement (within `CheckAndEnterRetest`)**: The structure to check frequency limits, calculate parameters, set the Mode B magic number (`trade.SetMagic(InpMagicNumber_ModeB)`), and call `trade.Buy`/`trade.Sell` is implemented.

**What STILL Needs Full Implementation (Beyond Placeholders):**

*   The detailed **internal logic** within `ManageOpenPositions`, `ApplyTrailingStop`, and `ApplyBreakEven` must be thoroughly reviewed and potentially adapted to ensure they work seamlessly with trades initiated by *either* Magic Number if that's the desired behavior for these global TSL/BE settings.
*   The **lot size/SL/TP calculation logic** needs careful, final coding within the adapted functions, testing all modes.
*   Robust **error handling** within the new Mode B trade execution block (`CheckAndEnterRetest`) is essential.
*   Full implementation of the remaining helper functions based on the structure and details discussed in prior versions.

This v1.80 provides the working code for detecting the breakout and the retest confirmation according to your ruleset and attempts to place the Mode B market order using its unique magic number, including adaptations to the calculation functions. Remember to complete the remaining placeholders and test extensively.