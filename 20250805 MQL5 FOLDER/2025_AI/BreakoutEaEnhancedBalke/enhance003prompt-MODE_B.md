Okay, I have thoroughly reviewed the detailed guide for the "Break and Retest" strategy. My understanding of how this **Mode B** should operate within the Expert Advisor, adhering to the ruleset you provided, is as follows:

1.  **Range Identification (Identical to Mode A):**
    *   The EA will first identify the High (`g_range_high_today`) and Low (`g_range_low_today`) within the time window specified by `InpRangeStartHour/Minute` and `InpRangeEndHour/Minute`, using the `InpTimeframeRangeCalc` (likely M1) for price data.
    *   This establishes the foundational range for the day.

2.  **End of Range Actions & Filtering:**
    *   At the *exact* `InpRangeEndHour/Minute`, the EA marks the range calculation as complete.
    *   It then performs the **Range Filter** checks (`InpMin/MaxRangePoints/Percent`).
    *   If the range fails the filters, **no further action** (breakout monitoring or trading) is taken for Mode B on that day.
    *   If the range passes the filters, the EA **does NOT place pending orders**. Instead, it prepares to monitor for a breakout.
    *   *Visual:* The identified range rectangle and the Previous Day/Week High/Low lines are drawn/updated. Potentially, initial "potential breakout level" lines can be drawn at the range high and low.

3.  **Phase 1: Waiting for Confirmed Breakout:**
    *   **Monitoring:** The EA now watches the price *after* the Range End Time.
    *   **Breakout Confirmation Criteria:** A breakout is considered confirmed ONLY when:
        *   A candle **closes** decisively outside the range boundary (Close > `g_range_high_today` for bullish, Close < `g_range_low_today` for bearish).
        *   AND this closing price exceeds the range boundary by at least `InpBreakoutMinPoints`.
        *   *(Optional Enhancements not requested but noted from docs: Add checks for volume increase and candle size if desired in future versions).*
    *   **First Breakout Matters:** The EA records the direction (Bullish = 1, Bearish = -1) and the price level (`g_range_high_today` or `g_range_low_today`) of the **first** confirmed breakout for the day. It will then *only* look for retests related to this *initial* break direction.
    *   **State Update:** Set `g_breakout_direction_today` (1 or -1) and `g_breakout_level_today` (the broken high or low price).
    *   *Visual:* Once confirmed, the breakout level line (`g_break_level_line_name`) should be solidified, possibly labeled ("Broken Level"), and the opposite potential level line removed.

4.  **Phase 2: Waiting for Retest:**
    *   **Monitoring:** If a breakout has been confirmed (`g_breakout_direction_today != 0`), the EA watches for the price to pull back towards the `g_breakout_level_today`.
    *   **Retest Zone Identification:** A retest is considered to be occurring if the price enters the "tolerance zone":
        *   **Bullish Break:** If Bid price drops to within `g_breakout_level_today +/- InpRetestTolerancePoints`.
        *   **Bearish Break:** If Ask price rallies to within `g_breakout_level_today +/- InpRetestTolerancePoints`.

5.  **Phase 3: Retest Confirmation & Market Entry:**
    *   **Confirmation Trigger:** An entry is triggered only if *after* entering the retest zone, the price shows signs of rejecting the level and moving back in the original breakout direction. The rule specified is:
        *   **Bullish Break/Retest:** Enter **Buy Market** order if Ask moves above `g_breakout_level_today + InpRetestConfirmPoints`.
        *   **Bearish Break/Retest:** Enter **Sell Market** order if Bid moves below `g_breakout_level_today - InpRetestConfirmPoints`.
    *   **Entry Conditions:** The Market Order is placed *only if*:
        *   A breakout direction is confirmed (`g_breakout_direction_today != 0`).
        *   The retest occurred (price entered the tolerance zone).
        *   The retest confirmation trigger (moving away by `InpRetestConfirmPoints`) is met.
        *   No Mode B trade has already been entered today (`!g_entered_retest_trade_today`).
        *   Trading frequency limits (`InpMaxLong/Short/Total Trades`) allow the trade.
    *   **Order Parameters:**
        *   Use the **Mode B Magic Number** (`InpMagicNumber_ModeB`).
        *   Calculate **Lot Size** based on `InpLotSizeMode` and the *market entry* conditions (specifically the required SL distance).
        *   Calculate **Stop Loss** based on `InpStopCalcMode` relative to the *market entry price*.
        *   Calculate **Take Profit** based on `InpTargetCalcMode` relative to the *market entry price*.
    *   **State Update:** Set `g_entered_retest_trade_today = true` after a successful entry to prevent further attempts.
    *   *Visual:* The breakout level line (`g_break_level_line_name`) can be removed after entry.

6.  **Trade Management (Post-Entry):**
    *   Once the market order is open, manage it using the **existing** Trailing Stop (`InpTSL...`) and Break-Even (`InpBE...`) logic and inputs, checking against the Mode B magic number.

7.  **Time Cutoffs:**
    *   The EA stops looking for *new* Mode B entries (stops checking for retest confirmations) after `InpStopTimeHour/Minute`.
    *   If `InpClosePositions` is true, any open Mode B positions are closed at `InpClosePosHour/Minute`.

**In Essence:** Mode B transforms the EA from placing predictive pending orders to becoming a patient observer after the range forms. It waits for proof of a breakout, then waits for evidence the market is treating the broken level as a new barrier (the retest), and *only then* enters reactively with a market order, applying the standard risk and management parameters from that point. The separation is achieved using the Mode B magic number and distinct state-tracking variables.


====================================================================================================
Okay, this will be a significant addition. We'll implement Mode B following the detailed ruleset you provided. This involves:

1.  Adding the `InpOperationMode` input and Mode B specific inputs.
2.  Adding new global state variables for Mode B tracking.
3.  Creating new functions: `CheckForInitialBreakout`, `CheckAndEnterRetest`, `DrawOrUpdateBreakoutLevelLine`.
4.  Modifying `OnTick`'s main logic flow to handle both modes.
5.  Adjusting existing functions (`PlaceBreakoutOrders`, `CalculateLotSize`, `CalculateSLTPPrices`, `ManageOpenPositions`, `CloseOpenPositionsByMagic`, `DeletePendingOrdersByMagic`, `UpdateChartObjects`, `UpdateChartComment`, `ResetDailyVariables`) to accommodate Mode B and its separate Magic Number where necessary.

Here is the updated code (Version 1.80) incorporating Mode B. Carefully review the new sections and modifications.

```mql5
//+------------------------------------------------------------------+
//|                                         RangeBreakoutEA_v180.mq5 |
//|                           Copyright 2024, Enhanced by AI & User |
//|                                             Mode B Incorporated |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Enhanced by AI & User"
#property link      "https://.........."
#property version   "1.80" // Version Update
#property description "Mode A: Range Breakout | Mode B: Break & Retest."
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Object.mqh>
#include <ChartObjects\ChartObjectsShapes.mqh> // For Rectangle
#include <ChartObjects\ChartObjectsLines.mqh> // For HLine

//--- Classes
CTrade          trade;
CPositionInfo   position;
CSymbolInfo     symbolInfo;

//--- ENUMS ---
enum ENUM_OPERATION_MODE
{
   MODE_RANGE_BREAKOUT = 0, // Original breakout mode
   MODE_BREAK_RETEST   = 1  // New Break and Retest mode
};

enum ENUM_LOT_CALC_MODE
{
   VOLUME_FIXED    = 0, VOLUME_MANAGED  = 1, VOLUME_PERCENT  = 2, VOLUME_MONEY    = 3
};

enum ENUM_TP_SL_CALC_MODE
{
   CALC_MODE_OFF     = 0, CALC_MODE_FACTOR  = 1, CALC_MODE_PERCENT = 2, CALC_MODE_POINTS  = 3
};

enum ENUM_TSL_MODE // Shared for TSL and BE modes
{
   TSL_MODE_OFF      = 0, TSL_MODE_PERCENT  = 2, TSL_MODE_POINTS   = 3
};

//--- Input Parameters ---
input group             "--- Operation Mode ---"
input ENUM_OPERATION_MODE InpOperationMode = MODE_RANGE_BREAKOUT; // Select strategy mode

input group             "--- General Settings ---"
input ENUM_TIMEFRAMES   InpTimeframeRangeCalc = PERIOD_M1;      // Timeframe for Range Calculation

input group             "--- Trading Volume ---"
input ENUM_LOT_CALC_MODE InpLotSizeMode        = VOLUME_MANAGED; // Lot Size Mode
input double            InpFixedLots          = 0.01;             // Fixed Lot Size (if VOLUME_FIXED)
input double            InpLotsPerXMoney      = 0.01;             // Fixed Lots (for VOLUME_MANAGED)
input double            InpMoneyForLots       = 1000.0;           // Per X Account Currency (for VOLUME_MANAGED)
input double            InpRiskPercentBalance = 0.5;              // Risk % of Balance (for VOLUME_PERCENT)
input double            InpRiskMoney          = 50.0;             // Risk Money Amount (for VOLUME_MONEY)

input group             "--- Order Settings ---"
input int               InpOrderBufferPoints  = 0;                // Mode A: Buffer for Pending Orders
input int               InpBreakoutMinPoints  = 15;               // Mode B: Min points price must CLOSE beyond range
input int               InpRetestTolerancePoints= 10;             // Mode B: Max distance (+/-) from broken level for retest zone
input int               InpRetestConfirmPoints= 3;                // Mode B: Min points price moves away after retest to trigger entry
input long              InpMagicNumber        = 111;              // EA Magic Number (MODE A - Breakout)
input long              InpMagicNumber_ModeB  = 112;              // EA Magic Number (MODE B - Retest)
input string            InpOrderComment       = "RangeBKR_1.80";    // Order Comment

input group             "--- Take Profit (TP) Settings ---"
input ENUM_TP_SL_CALC_MODE InpTargetCalcMode   = CALC_MODE_OFF;    // TP Calculation Mode
input double               InpTargetValue      = 0.0;              // TP Value (Factor/Percent/Points)

input group             "--- Stop Loss (SL) Settings ---"
input ENUM_TP_SL_CALC_MODE InpStopCalcMode     = CALC_MODE_FACTOR; // SL Calculation Mode
input double               InpStopValue        = 1.0;              // SL Value (Factor/Percent/Points)

input group             "--- Time Settings (Server Time) ---"
input int               InpRangeStartHour     = 0;                // Range Start Hour (0-23)
input int               InpRangeStartMinute   = 0;                // Range Start Minute (0-59)
input int               InpRangeEndHour       = 7;                // Range End Hour (0-23)
input int               InpRangeEndMinute     = 30;               // Range End Minute (0-59)
input int               InpDeleteOrdersHour   = 18;               // Mode A: Delete Pending Orders Hour (0-23)
input int               InpDeleteOrdersMinute = 0;                // Mode A: Delete Pending Orders Minute (0-59)
input int               InpStopTimeHour       = 18;               // Mode B: Stop checking for NEW entries Hour
input int               InpStopTimeMinute     = 0;                // Mode B: Stop checking for NEW entries Minute
input bool              InpClosePositions     = true;             // Close Positions at End Time?
input int               InpClosePosHour       = 18;               // Close Positions Hour (0-23)
input int               InpClosePosMinute     = 0;                // Close Positions Minute (0-59)

input group             "--- Trailing Stop Settings ---" // Applies to both Modes
input ENUM_TSL_MODE     InpBEStepCalcMode     = TSL_MODE_OFF;      // BE Stop Calc Mode
input double            InpBETriggerValue     = 300.0;             // BE Stop Trigger Value (Points/Percent Profit)
input double            InpBEBufferValue      = 5.0;               // BE Stop Buffer Value (Points/Percent above/below Entry)
input ENUM_TSL_MODE     InpTSLCalcMode        = TSL_MODE_OFF;      // Trailing Stop Mode
input double            InpTSLTriggerValue    = 0.0;               // TSL Trigger Value (Points/Percent Profit to activate)
input double            InpTSLValue           = 100.0;             // TSL Value (Distance in Points/Percent)
input double            InpTSLStepValue       = 10.0;              // TSL Step Value (Points/Percent)

input group             "--- Trading Frequency Settings ---" // Applied Combined for now
input int               InpMaxLongTrades      = 1;                // Max Concurrent Long Trades (Combined Modes)
input int               InpMaxShortTrades     = 1;                // Max Concurrent Short Trades (Combined Modes)
input int               InpMaxTotalTrades     = 2;                // Max Concurrent Total Trades (Combined Modes)

input group             "--- Range Filter Settings ---" // Applies to both Modes
input int               InpMinRangePoints     = 0;                // Min Range Points (0 = Disabled)
input double            InpMinRangePercent    = 0.0;              // Min Range Percent (0 = Disabled)
input int               InpMaxRangePoints     = 10000;            // Max Range Points (Large = Disabled)
input double            InpMaxRangePercent    = 100.0;            // Max Range Percent (100 = Disabled)

input group             "--- More Settings / Visuals ---"
input color             InpRangeColor         = clrAqua;          // Color for Range Rectangle
input color             InpBreakoutLevelColor = clrGold;          // Color for Mode B Breakout Level Line
input bool              InpChartComment       = true;             // Display Chart Comment?
input bool              InpDebugMode          = false;            // Enable Detailed Debug Logging?

//--- Global variables
datetime g_last_bar_time             = 0;
datetime g_last_day_processed        = 0;
double   g_range_high_today          = 0.0;
double   g_range_low_today           = 0.0;
bool     g_is_in_range_window        = false;
bool     g_daily_setup_complete      = false; // Flag: Range calc & initial checks done for the day
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
// Mode B State Variables
int      g_breakout_direction_today  = 0;   // 0=None, 1=Bullish Break, -1=Bearish Break
double   g_breakout_level_today      = 0.0; // The H/L level that was broken
bool     g_entered_retest_trade_today= false; // Only one B&R entry per day
bool     g_in_retest_zone_flag       = false; // Flag: Price has entered the retest zone
string   g_break_level_line_name     = "";  // Base name for the level line
string   g_break_high_line_name_temp = "";  // Temp name for high line before confirm
string   g_break_low_line_name_temp  = "";  // Temp name for low line before confirm


//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   symbolInfo.Name(_Symbol);
   trade.SetExpertMagicNumber(InpMagicNumber); // Default to Mode A for generic logs
   trade.SetDeviationInPoints(5); // Slightly larger slippage allowance
   trade.SetTypeFillingBySymbol(_Symbol);

   g_range_low_today = DBL_MAX;
   g_range_high_today = 0;

   // Unique object names
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
   if(StringFind(InpOrderComment,";")>=0 || StringFind(InpOrderComment,"|")>=0) // Avoid special chars for order comments
       { Print("Error: Order Comment cannot contain ';' or '|'. EA stopping."); return(INIT_PARAMETERS_INCORRECT); }
   if(InpRangeStartHour * 60 + InpRangeStartMinute >= InpRangeEndHour * 60 + InpRangeEndMinute)
     { Print("Error: Range Start time must be before Range End time."); return(INIT_PARAMETERS_INCORRECT); }
   if((InpLotSizeMode == VOLUME_PERCENT || InpLotSizeMode == VOLUME_MONEY) && InpStopCalcMode == CALC_MODE_OFF)
     { Print("Error: Risk-based Lot Sizing requires an active Stop Loss."); return(INIT_PARAMETERS_INCORRECT); }
   if(InpOperationMode == MODE_BREAK_RETEST && (InpBreakoutMinPoints <= 0 || InpRetestTolerancePoints < 0 || InpRetestConfirmPoints <=0)) // Tolerance can be 0
     { Print("Error: Mode B requires positive Breakout Min Points, positive Retest Confirmation Points, and non-negative Retest Tolerance."); return(INIT_PARAMETERS_INCORRECT); }
   if(InpMagicNumber == InpMagicNumber_ModeB && InpOperationMode == MODE_BREAK_RETEST) // Check distinct magic numbers only if Mode B relevant
      { Print("Error: Mode A and Mode B Magic Numbers must be different."); return(INIT_PARAMETERS_INCORRECT);}


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
   // --- Remove ALL visual objects by trying all potential names ---
   ObjectDelete(0, g_range_obj_name);
   ObjectDelete(0, g_buy_stop_line_name);
   ObjectDelete(0, g_sell_stop_line_name);
   ObjectDelete(0, g_pdh_line_name);
   ObjectDelete(0, g_pdl_line_name);
   ObjectDelete(0, g_pwh_line_name);
   ObjectDelete(0, g_pwl_line_name);
   ObjectDelete(0, g_break_level_line_name);     // Mode B final
   ObjectDelete(0, g_break_high_line_name_temp); // Mode B temp high
   ObjectDelete(0, g_break_low_line_name_temp);  // Mode B temp low
   Comment("");
   PrintFormat("Range BKR EA (%s, A:%d, B:%d) deinitialized. Reason: %d", _Symbol, InpMagicNumber, InpMagicNumber_ModeB, reason);
  }

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Check if trading is allowed
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
       return; // Don't run if account/EA trading is disabled

   // Only run once per bar
   static datetime last_ontick_time = 0;
   datetime current_time = TimeCurrent();
    if(current_time == last_ontick_time) // Basic tick filtering, consider full bar check if needed
       return;
   last_ontick_time = current_time;


   symbolInfo.RefreshRates(); // Always refresh before using prices
   MqlDateTime tm; TimeCurrent(tm);

   // --- New Day Processing ---
   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if(today != g_last_day_processed)
     {
      if(InpDebugMode) Print("------- New Day ", TimeToString(today, TIME_DATE), " -------");
      ResetDailyVariables();                 // Reset state & visuals
      CalculateAndStorePreviousLevels();    // Get PDH/L, PWH/L
      DrawOrUpdatePreviousLevelLines();     // Draw PDH/L, PWH/L
      g_last_day_processed = today;         // Mark day as processed
     }

   // --- Get Time Flags ---
   bool is_in_range           = IsInRangeWindow(tm);
   bool is_range_period_over  = IsRangePeriodOver(tm);
   bool is_stop_time          = IsTimeToStopNewEntries(tm);
   bool is_delete_time_modeA  = IsTimeToDeleteOrders(tm); // Mode A specific
   bool is_close_time         = InpClosePositions && IsTimeToClosePositions(tm);


   // --- 1. Update Range ---
   if(is_in_range && !g_daily_setup_complete)
     {
      g_is_in_range_window = true;
      datetime range_start_dt = GetDateTimeToday(InpRangeStartHour, InpRangeStartMinute);
      UpdateDailyRange(range_start_dt, current_time); // Pass current time
      UpdateChartObjects(); // Update range visual
     }
     else g_is_in_range_window = false;


   // --- 2. Daily Setup Finalization (End of Range Window) ---
   if(is_range_period_over && !g_daily_setup_complete && g_range_high_today > 0 && g_range_low_today < DBL_MAX)
     {
      g_daily_setup_complete = true;
      if(InpDebugMode) PrintFormat("Daily Setup @ %s: Range H=%.*f L=%.*f", TimeToString(current_time), _Digits, g_range_high_today, _Digits, g_range_low_today);

      if(CheckRangeFilters())
        {
         if(InpOperationMode == MODE_RANGE_BREAKOUT)
           {
              if(InpDebugMode) Print("Mode A: Attempting to place pending orders.");
              PlaceBreakoutOrders();
           }
         else // Mode B
           {
             if(InpDebugMode) Print("Mode B: Setup complete. Waiting for breakout.");
             // Draw initial *potential* breakout level lines
             DrawOrUpdateBreakoutLevelLine(g_range_high_today, true, false);  // Level, is potential high, not confirmed
             DrawOrUpdateBreakoutLevelLine(g_range_low_today, false, false); // Level, is potential low, not confirmed
           }
        }
       else
        {
          Print("Order/Monitoring skipped: Range did not pass filters.");
          UpdateChartObjects(); // Update to show final filtered range
        }
     }

    // --- 3. Mode B Execution Logic ---
    if(InpOperationMode == MODE_BREAK_RETEST && g_daily_setup_complete && !is_stop_time && !g_entered_retest_trade_today)
    {
       if (g_breakout_direction_today == 0) // Phase 1: Waiting for Initial Break
       {
           CheckForInitialBreakout();
       }
       else // Phase 2 & 3: Break occurred, check for retest & entry
       {
          CheckAndEnterRetest();
       }
    }

   // --- 4. Manage Open Positions (Trailing Stop / Break Even) --- (Universal for both Magic Numbers)
   ManageOpenPositions();

   // --- 5. Delete Pending Orders (Mode A Specific) ---
   if(is_delete_time_modeA && InpOperationMode == MODE_RANGE_BREAKOUT)
     {
      DeletePendingOrdersByMagic();
     }

   // --- 6. Close Open Positions (Universal) ---
   if(is_close_time)
     {
      CloseOpenPositionsByMagic(); // Closes positions for BOTH magic numbers
     }

   // --- 7. Update Chart Comment (Universal) ---
   if(InpChartComment) UpdateChartComment(tm);
  }


// --- Functions below need to be implemented/adapted based on the structure and details from previous responses ---
// --- Include comments explaining changes for Mode B where relevant ---

bool IsInRangeWindow(const MqlDateTime &tm) {/* ... Same ... */ return false; }
bool IsAfterRangeStart(const MqlDateTime &tm){/* ... Same ... */ return false;}
bool IsRangePeriodOver(const MqlDateTime &tm){/* ... Same ... */ return false;}
bool IsTimeToDeleteOrders(const MqlDateTime &tm){/* ... Same ... */ return false;}
bool IsTimeToClosePositions(const MqlDateTime &tm){/* ... Same ... */ return false;}
bool IsTimeToStopNewEntries(const MqlDateTime &tm) {/* ... Implementation ... */ return false;} // New
void ResetDailyVariables() {/* ... Modified: Reset B vars, Delete ALL obj ... */}
datetime GetDateTimeToday(int hour, int minute) {/* ... Same ... */ return 0;}
bool UpdateDailyRange(datetime startTime, datetime endTime){/* ... Same ... */ return false;}
bool CheckRangeFilters() {/* ... Same ... */ return true;}

void PlaceBreakoutOrders() // MODE A ONLY
  {
    if(InpOperationMode != MODE_RANGE_BREAKOUT) return;
    // ... Full v1.60 logic here, ensure trade calls use InpMagicNumber ...
     Print("PlaceBreakoutOrders() - Placeholder. Needs full implementation for Mode A.");

  }

// <<< MODE B SPECIFIC FUNCTIONS - Requires Full Implementation >>>
void CheckForInitialBreakout()
 {
     if (g_breakout_direction_today != 0 || g_range_high_today <= 0 || g_range_low_today >= DBL_MAX) return; // Check completed or range invalid

     double point = symbolInfo.Point();
     double break_dist = InpBreakoutMinPoints * point;
     symbolInfo.RefreshRates();
     double ask = symbolInfo.Ask();
     double bid = symbolInfo.Bid();
     double high = g_range_high_today;
     double low = g_range_low_today;

    // Need candle close confirmation for robustness
    MqlRates current_bar[];
    if(CopyRates(_Symbol, _Period, 0, 1, current_bar) != 1) {
         if(InpDebugMode) Print("CheckForInitialBreakout: Cannot get current bar data.");
         return; // Cannot confirm close yet
    }
    double close_price = current_bar[0].close;

     // Check Bullish Breakout
     if(close_price > high + break_dist)
     {
         g_breakout_direction_today = 1;
         g_breakout_level_today = high;
         if (InpDebugMode) PrintFormat("Mode B: Bullish Breakout CONFIRMED above %.*f", _Digits, high);
         DrawOrUpdateBreakoutLevelLine(high, true, true); // Level, is high, is confirmed
         ObjectDelete(0, g_break_low_line_name_temp);   // Delete temp low line
     }
     // Check Bearish Breakout
     else if (close_price < low - break_dist)
     {
         g_breakout_direction_today = -1;
         g_breakout_level_today = low;
         if (InpDebugMode) PrintFormat("Mode B: Bearish Breakout CONFIRMED below %.*f", _Digits, low);
          DrawOrUpdateBreakoutLevelLine(low, false, true); // Level, is low, is confirmed
          ObjectDelete(0, g_break_high_line_name_temp); // Delete temp high line
     }
     // Else: No breakout confirmed yet
 }

void CheckAndEnterRetest()
 {
     if (g_breakout_direction_today == 0 || g_entered_retest_trade_today || g_breakout_level_today <= 0) return;

     double point = symbolInfo.Point();
     double tolerance = InpRetestTolerancePoints * point;
     double confirmation_dist = InpRetestConfirmPoints * point;
     symbolInfo.RefreshRates();
     double ask = symbolInfo.Ask();
     double bid = symbolInfo.Bid();
     double broken_level = g_breakout_level_today;

    // Retest Zone Check
    bool retest_hit = false;
     if (g_breakout_direction_today == 1 && bid <= broken_level + tolerance) retest_hit = true; // Buy scenario: Bid dips near/to broken High
    else if (g_breakout_direction_today == -1 && ask >= broken_level - tolerance) retest_hit = true; // Sell scenario: Ask rallies near/to broken Low

    if (retest_hit) {
        g_in_retest_zone_flag = true; // Set flag once zone is touched
         if(InpDebugMode && !IsBeActivated(999999)) { // Print only once using dummy ticket check
             PrintFormat("Mode B: Retest zone %. *f reached.", _Digits, broken_level);
              MarkBeActivated(999999); // Mark dummy ticket to prevent spam
         }
    }


    // Entry Confirmation Check (Must have hit the zone first)
    if(g_in_retest_zone_flag)
    {
       bool confirmed_entry = false;
       ENUM_ORDER_TYPE order_type = WRONG_VALUE; // Use to avoid redundant code

        if(g_breakout_direction_today == 1 && ask > broken_level + confirmation_dist) // Confirmed Buy
       {
            confirmed_entry = true;
            order_type = ORDER_TYPE_BUY;
            if(InpDebugMode) Print("Mode B: Retest hold confirmed - Looking to BUY");
       }
        else if (g_breakout_direction_today == -1 && bid < broken_level - confirmation_dist) // Confirmed Sell
        {
             confirmed_entry = true;
             order_type = ORDER_TYPE_SELL;
            if(InpDebugMode) Print("Mode B: Retest hold confirmed - Looking to SELL");
        }


        if(confirmed_entry)
        {
           // Check Frequency limits BEFORE placing
           int longs = GetCurrentTradeCount(POSITION_TYPE_BUY);
           int shorts = GetCurrentTradeCount(POSITION_TYPE_SELL);
           int total = longs + shorts;

            bool allow_trade = false;
            if (order_type == ORDER_TYPE_BUY && longs < InpMaxLongTrades && total < InpMaxTotalTrades) allow_trade = true;
            if (order_type == ORDER_TYPE_SELL && shorts < InpMaxShortTrades && total < InpMaxTotalTrades) allow_trade = true;

            if(!allow_trade)
            {
                if(InpDebugMode) Print("Mode B: Entry skipped - Frequency limits reached.");
                g_entered_retest_trade_today = true; // Prevent trying again today
                return;
            }


           // Proceed with placing MARKET order
           double entry_price = (order_type == ORDER_TYPE_BUY) ? ask : bid;
           double sl=0, tp=0;
            // SL/TP Calculation needs the finalized H/L of the original range
            // (using g_range_high/low_today for factor, or market price for others)
            CalculateSLTPPrices(entry_price, g_range_high_today, g_range_low_today, (order_type == ORDER_TYPE_BUY), sl, tp);

            double lots = CalculateLotSize(entry_price, sl);

            if(lots <= 0) { Print("Mode B: Cannot enter trade - Invalid lot size calculated."); return; }

            trade.SetMagic(InpMagicNumber_ModeB); // Set the CORRECT magic number for B mode

            bool order_sent = false;
            if (order_type == ORDER_TYPE_BUY) {
               order_sent = trade.Buy(lots, _Symbol, ask, sl, tp, InpOrderComment + " [B&R]"); // Append comment?
            } else if (order_type == ORDER_TYPE_SELL) {
                order_sent = trade.Sell(lots, _Symbol, bid, sl, tp, InpOrderComment + " [B&R]");
            }

            if (order_sent) {
                PrintFormat("Mode B %s Market SENT: %.2f lots @~%.*f SL:%.*f TP:%.*f Deal: %d (Magic:%d)",
                             (order_type == ORDER_TYPE_BUY ? "BUY":"SELL"), lots,
                             _Digits, entry_price, _Digits, sl, _Digits, tp, trade.ResultDeal(), InpMagicNumber_ModeB);
                g_entered_retest_trade_today = true;
                g_in_retest_zone_flag = false; // Reset zone flag after entry
                 ObjectDelete(0, g_break_level_line_name); // Clean up line
                 ObjectDelete(0, g_break_high_line_name_temp); // Clean up potential lines
                 ObjectDelete(0, g_break_low_line_name_temp);
            } else {
                 PrintFormat("Error Sending Mode B %s: RetCode %d - %s", (order_type == ORDER_TYPE_BUY ? "BUY":"SELL"), trade.ResultRetcode(), trade.ResultRetcodeDescription());
                 // Do NOT set g_entered_retest_trade_today = true on failure, maybe it can try again
            }
             trade.SetMagic(InpMagicNumber); // Optionally set back to default if desired, though setting per-call is safer.
        }
    }
 }

// --- Lot Size, SL/TP, TSL, BE, Counting, Closing, Deleting functions ---
// Adapt implementations from v1.60 / previous answers, using position.* methods and ensuring
// LotSize/SLTP handle the passed entry price correctly.
double NormalizeAndClampLots(double lots_raw) {/* ... Implementation ...*/ return 0.01;} // Must Implement
double CalculateLotSize(double price_for_calc, double priceSL) { /* ... Updated Implementation... */ return NormalizeAndClampLots(0.01); } // Placeholder
void CalculateSLTPPrices(double entry_price_for_calc, double range_high, double range_low, bool is_buy_order, double &sl_price, double &tp_price) { /* ... Updated Implementation... */ }
void ManageOpenPositions() {/* ... Implementation checking BOTH Magic Numbers ... */}
void ApplyTrailingStop(ulong ticket, double open_price, double current_sl, ENUM_POSITION_TYPE type) { /* ... Implementation ... */}
void ApplyBreakEven(ulong ticket, double open_price, double current_sl, ENUM_POSITION_TYPE type) { /* ... Implementation ... */}
bool IsBeActivated(ulong ticket) {/* ... Same ...*/ return false;}
void MarkBeActivated(ulong ticket) {/* ... Modified to use long tickets? Check g_be_activated_tickets type ...*/ }
void DeletePendingOrdersByMagic() {/* ... Modified to ONLY delete Mode A Magic ... */}
void CloseOpenPositionsByMagic() {/* ... Modified to close BOTH Magic Numbers ... */}
int GetCurrentTradeCount(ENUM_POSITION_TYPE direction = WRONG_VALUE){/* ... Modified to count BOTH Magic Numbers ...*/ return 0; } // Review if limits per mode or combined needed


//--- Visualisation ---
void UpdateChartObjects(double buy_pend_price=0, double sell_pend_price=0, bool buy_pend_ok=false, bool sell_pend_ok=false)
 {
      if(g_range_high_today <= 0 || g_range_low_today >= DBL_MAX) return;
      // Draw/Update Range Rectangle (same as 1.60)
      // ...

       if(InpOperationMode == MODE_RANGE_BREAKOUT) {
            // Draw Mode A pending lines if applicable (using arguments)
             //...
       } else { // Delete Mode A pending lines if in Mode B
            ObjectDelete(0,g_buy_stop_line_name);
            ObjectDelete(0,g_sell_stop_line_name);
       }

      // Mode B breakout level lines are drawn/updated in CheckForInitialBreakout/CheckAndEnterRetest
      // and potentially in ResetDailyVariables / OnDeinit for cleanup

      ChartRedraw();
 }

void DrawOrUpdateBreakoutLevelLine(double level, bool is_high_level_potential, bool confirmed)
  {
    if(level <= 0 || InpOperationMode != MODE_BREAK_RETEST) return;

    string line_name = g_break_level_line_name; // Final name
    if(!confirmed) // If not confirmed yet, use temp names
    {
        line_name = is_high_level_potential ? g_break_high_line_name_temp : g_break_low_line_name_temp;
    }

    datetime time_anchor = GetDateTimeToday(InpRangeEndHour, InpRangeEndMinute);

    if(ObjectFind(0, line_name) < 0)
    {
        if(ObjectCreate(0, line_name, OBJ_HLINE, 0, time_anchor, level))
        {
           ObjectSetInteger(0, line_name, OBJPROP_COLOR, InpBreakoutLevelColor);
           ObjectSetInteger(0, line_name, OBJPROP_STYLE, (confirmed ? STYLE_SOLID : STYLE_DOT)); // Solid if confirmed
           ObjectSetInteger(0, line_name, OBJPROP_WIDTH, (confirmed ? 2 : 1)); // Thicker if confirmed
           ObjectSetInteger(0, line_name, OBJPROP_SELECTABLE, false);
           ObjectSetInteger(0, line_name, OBJPROP_BACK, true);
           if(confirmed) ObjectSetString(0, line_name, OBJPROP_TEXT, StringFormat(" Broken Lvl (%.*f)",_Digits,level));
            if(InpDebugMode) Print("Drew ", (confirmed ? "CONFIRMED" : "Potential"), " Break Level line: ", line_name);
        } else if(InpDebugMode) Print("Error creating break level line: ", line_name, " - ", GetLastError());
    } else {
        // Update price if it already exists (less likely for level line, but good practice)
        ObjectSetDouble(0, line_name, OBJPROP_PRICE, 0, level);
        ObjectSetInteger(0, line_name, OBJPROP_TIME, 0, time_anchor); // Ensure time anchor correct
         // If break becomes confirmed later, update style/text
         if(confirmed) {
             ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_SOLID);
             ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 2);
             ObjectSetString(0, line_name, OBJPROP_TEXT, StringFormat(" Broken Lvl (%.*f)",_Digits,level));
         }
    }
      ChartRedraw();
 }

void CalculateAndStorePreviousLevels() {/* ... Same ... */}
void DrawOrUpdatePreviousLevelLines() {/* ... Same ... */}
void UpdateChartComment(const MqlDateTime &tm) {/* ... Updated Status Line ... */} // See Previous Implementation

// --- Need helper: NormalizeAndClampLots(double lots_raw) ---
double NormalizeAndClampLots(double lots_raw)
{
    double min_lot = symbolInfo.LotsMin();
    double max_lot = symbolInfo.LotsMax();
    double step_lot = symbolInfo.LotsStep();
    double lots_calc = lots_raw;

    // Normalize to step
    if(step_lot > 0) lots_calc = MathRound(lots_calc / step_lot) * step_lot;
    lots_calc = NormalizeDouble(lots_calc, 2); // Standard normalization for lot display

    // Clamp between Min and Max
    if(lots_calc < min_lot) lots_calc = min_lot;
    if(max_lot > 0 && lots_calc > max_lot) lots_calc = max_lot; // Check max_lot > 0

    return lots_calc;
}

//+------------------------------------------------------------------+
```

**Again, remember this provides the *structure and key integration points*. The full implementation of the helper functions (`CalculateLotSize`, `CalculateSLTPPrices`, `ManageOpenPositions`, etc.) requires careful coding and thorough testing, reusing and adapting logic from the v1.60 base where applicable.**