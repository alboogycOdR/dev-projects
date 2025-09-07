//+------------------------------------------------------------------+
//|                                            RangeBreakoutEA.mq5 |
//|                        Copyright 2024, Your Name/Company       |
//|                                             https://...........|
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Your Name/Company"
#property link      "https://.........."
#property version   "1.70"
#property description "Identifies a time-based range and places breakout pending orders."
#property description "Mode A (Range Breakout): Proactive. Places pending stop orders immediately at range end, anticipating a breakout."
#property description "Mode B (Break and Retest): Reactive. Waits for a breakout after range end, then waits for a pullback (retest) to the broken level, then enters with a market (or limit) order upon confirmation of the retest hold."
#property strict
/*
    Core Strategy: Time-Based Range Breakout
    The fundamental goal of this EA is to capitalize on price movements that break out of a trading range established during a specific, user-defined time window at the beginning of the trading day (or a chosen session).
    Core Functionality - Step-by-Step:
    Define Range Time: The user specifies a start time (Range Start Hour/Minute) and an end time (Range End Hour/Minute) using the broker's server time.
    Identify Range: During this defined time window, the EA continuously monitors the price action (using the specified Timeframe Range Calculation, typically M1 for precision) and determines the absolute highest high and lowest low price reached within that window. This High-Low pair defines the day's initial range.
    Filter Range (Optional): At the Range End Time, before placing orders, the EA checks if the calculated range size (High - Low) meets the user's criteria set in the Range Filter Settings (minimum/maximum size in points and/or percentage of the price). If the range is deemed too small or too large based on these filters, the EA skips trading for that day.
    Place Breakout Orders: If the range passes the filters, the EA immediately places two pending orders:
    A Buy Stop order placed Order Buffer Points above the identified Range High.
    A Sell Stop order placed Order Buffer Points below the identified Range Low.
    Calculate Order Parameters:
    Lot Size: Calculated based on the chosen Trading Volume mode (Fixed, Managed, Percent Risk, Money Risk). Risk-based modes require a Stop Loss to function correctly.
    Stop Loss (SL): Set according to the Stop Calc Mode (e.g., a factor of the range size, fixed points, percentage of entry price, or placed at the opposite range boundary). Can be turned off (not recommended).
    Take Profit (TP): Optionally set according to the Target Calc Mode (e.g., factor of range, fixed points, percentage, or turned off).
    Order Activation & Management:
    When the market price hits either the Buy Stop or Sell Stop, that order is filled, creating an open position. The other pending order is automatically cancelled by the broker/platform (standard pending stop behavior).
    The open position is then managed:
    The initial SL and TP are active.
    If Break-Even (BE Stop Calc Mode) is enabled, the SL will be moved to protect the entry price (plus a buffer) once a specified profit target is hit. This happens only once per trade.
    If Trailing Stop (TSL Calc Mode) is enabled, the SL will trail behind the price (at the specified distance and step) once a trigger profit level is met.
    Cleanup and Timing:
    Any untriggered pending orders are automatically deleted at the Delete Orders Hour/Minute.
    If Close Positions is enabled, all open positions managed by this EA (identified by its Magic Number) are closed at the Close Positions Hour/Minute.
    Daily Cycle & Repetition: The process resets at the beginning of each new trading day, identifying a new range and potentially placing new orders.
    Visuals & Context (Enhanced):
    Draws a rectangle on the chart visually representing the calculated range.
    Plots horizontal lines for the Previous Day High/Low and Previous Week High/Low for market context.
    Displays status information in the chart comment.
    Key Pillars of Robustness/Compatibility:
    Flexibility: Numerous input parameters allow tailoring to different instruments, strategies, risk appetites, and time preferences.
    Dynamic Symbol Data: Uses functions to get symbol-specific properties (digits, point size, stops level, etc.) rather than hardcoding, improving compatibility.
    Time Control: Explicit time settings for range, order deletion, and position closure provide control over the EA's activity window.
    Filtering: Range size filters help avoid trading in potentially unfavorable (too choppy or too volatile) conditions.
    Unique Identification: The Magic Number ensures the EA only manages its own trades, crucial when running multiple EAs or instances.
    Contextual Lines: Plotting previous key levels aids visual analysis and potential future strategy logic integration.


*/
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/SymbolInfo.mqh>
#include <Object.mqh> // For chart objects (potentially)
#include <ChartObjects/ChartObjectsShapes.mqh> // For Rectangle
/*
    reference vid  https://www.youtube.com/watch?v=mOa4dqxAh4g&t=289s
*/
/*
    20250421
    adding previous day and week high/low lines is an excellent way to add contextual support/resistance levels and make the system more visually informative across different market types.
        Storing these values globally is also smart for future strategy enhancements.
        We added global variables (g_prev_...) to hold the calculated price levels.
        We added global string variables for the new line object names, initializing them uniquely in OnInit.
        CalculateAndStorePreviousLevels uses CopyHigh and CopyLow with the D1 and W1 timeframes and index 1 (the previous completed bar/week) to get the historical data. It stores the results in the global variables. Basic error checking is included.
        DrawOrUpdatePreviousLevelLines checks if the global level variables are valid (greater than 0). For each valid level, it checks if the corresponding line object exists. If not, it creates it with the specified style (Gray color, dotted/dashed style, text label). If it already exists, it simply updates the price level of the existing line to the newly calculated value for the current day.
        The OnTick function now calls these two new functions right after detecting a new day and resetting variables. This ensures the levels and lines are updated daily.
        ResetDailyVariables was updated to also attempt to delete the previous day's level lines, cleaning up the chart.
        Now, when you run this modified EA, it should calculate the previous day's and week's high/low levels at the start of each new trading day and display them as distinct gray horizontal lines on the chart. These stored g_prev_... variables are then ready if you decide to incorporate them into future trading logic (e.g., filtering trades based on proximity to these levels). Remember to test again!


*/
//--- Include necessary class instances
CTrade          trade;
CPositionInfo   position;
CSymbolInfo     symbolInfo; // Helps get symbol properties


//--- ENUMS
enum ENUM_OPERATION_MODE
{
   MODE_RANGE_BREAKOUT = 0, // Original breakout mode
   MODE_BREAK_RETEST   = 1  // New Break and Retest mode
};
 

//--- Input Parameters
input group             "--- Operation Mode ---"
input ENUM_OPERATION_MODE InpOperationMode = MODE_RANGE_BREAKOUT; // Select strategy mode

//--- Input Parameters (Matching the provided list)
input group             "--- General Settings ---"
input ENUM_TIMEFRAMES   InpTimeframeRangeCalc = PERIOD_M1;      // Timeframe for Range Calculation
input long              InpMagicNumber        = 111;              // EA Magic Number
input string            InpOrderComment       = "RangeBreakout_1.40"; // Order Comment


input group             "--- Trading Volume ---"
enum ENUM_LOT_CALC_MODE
  {
   VOLUME_FIXED    = 0, // Fixed Lot Size
   VOLUME_MANAGED  = 1, // Lots per X Balance/Equity
   VOLUME_PERCENT  = 2, // Risk % of Balance (Needs SL!)
   VOLUME_MONEY    = 3  // Risk Fixed Money (Needs SL!)
  };
input ENUM_LOT_CALC_MODE InpLotSizeMode        = VOLUME_MANAGED;   // Lot Size Mode


input int InpRetestTolerancePoints = 10; // Defines how close price must come to the broken level for a retest.
input int InpRetestConfirmationPoints = 2; // How many points price must move away after retest to confirm entry.


input double            InpFixedLots          = 0.01;             // Fixed Lot Size (if VOLUME_FIXED)
input double            InpLotsPerXMoney      = 0.01;             // Fixed Lots (for VOLUME_MANAGED)
input double            InpMoneyForLots       = 1000.0;           // Per X Account Currency (for VOLUME_MANAGED)
input double            InpRiskPercentBalance = 0.5;              // Risk % of Balance (for VOLUME_PERCENT)
input double            InpRiskMoney          = 50.0;             // Risk Money Amount (for VOLUME_MONEY)

input group             "--- Order Settings ---"
input int               InpOrderBufferPoints  = 0;          // Buffer for Mode A Pending Orders
input int               InpBreakoutMinPoints  = 5;          // Min points price must break range by (Mode B)
input int               InpRetestTolerancePoints= 10;         // Max distance from broken level for retest (Mode B)
input int               InpRetestConfirmPoints= 2;          // Points price moves away after retest to enter (Mode B)
input long              InpMagicNumber        = 111;          // EA Magic Number
input string            InpOrderComment       = "RangeBKR_1.70"; // Order Comment

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group             "--- Take Profit (TP) Settings ---"
enum ENUM_TP_SL_CALC_MODE
  {
   CALC_MODE_OFF     = 0, // TP/SL Disabled
   CALC_MODE_FACTOR  = 1, // Factor of Range Size
   CALC_MODE_PERCENT = 2, // Percentage of Entry Price
   CALC_MODE_POINTS  = 3  // Fixed Points
  };
input ENUM_TP_SL_CALC_MODE InpTargetCalcMode   = CALC_MODE_OFF;    // TP Calculation Mode
input double               InpTargetValue      = 0.0;              // TP Value (Factor/Percent/Points)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group             "--- Stop Loss (SL) Settings ---"
// SL Calc Mode uses ENUM_TP_SL_CALC_MODE defined above
input ENUM_TP_SL_CALC_MODE InpStopCalcMode     = CALC_MODE_FACTOR; // SL Calculation Mode
input double               InpStopValue        = 1.0;              // SL Value (Factor/Percent/Points)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group             "--- Time Settings (Server Time) ---"
input int               InpRangeStartHour     = 0;                // Range Start Hour (0-23)
input int               InpRangeStartMinute   = 0;                // Range Start Minute (0-59)
input int               InpRangeEndHour       = 7;                // Range End Hour (0-23)
input int               InpRangeEndMinute     = 30;               // Range End Minute (0-59)
input int               InpDeleteOrdersHour   = 18;               // Delete Pending Orders Hour (0-23)
input int               InpDeleteOrdersMinute = 0;                // Delete Pending Orders Minute (0-59)
input int               InpStopTimeHour       = 18;         // Stop checking for NEW Mode B entries Hour
input int               InpStopTimeMinute     = 0;          // Stop checking for NEW Mode B entries Minute
input bool              InpClosePositions     = true;             // Close Positions at End Time?
input int               InpClosePosHour       = 18;               // Close Positions Hour (0-23)
input int               InpClosePosMinute     = 0;                // Close Positions Minute (0-59)

input group             "--- Trailing Stop Settings ---"
enum ENUM_TSL_MODE // TSL specific modes, inherits structure from TP/SL
  {
   TSL_MODE_OFF      = 0,
// Factor not suitable for Trailing/BE Trigger usually
   TSL_MODE_PERCENT  = 2,
   TSL_MODE_POINTS   = 3
  };
input ENUM_TSL_MODE     InpBEStepCalcMode     = TSL_MODE_OFF;      // BE Stop Calc Mode
input double            InpBETriggerValue     = 300.0;             // BE Stop Trigger Value (Points/Percent Profit)
input double            InpBEBufferValue      = 5.0;               // BE Stop Buffer Value (Points/Percent above/below Entry)
// TSL Calc Mode uses ENUM_TSL_MODE defined above
input ENUM_TSL_MODE     InpTSLCalcMode        = TSL_MODE_OFF;      // Trailing Stop Mode
input double            InpTSLTriggerValue    = 0.0;               // TSL Trigger Value (Points/Percent Profit to activate)
input double            InpTSLValue           = 100.0;             // TSL Value (Distance in Points/Percent)
input double            InpTSLStepValue       = 10.0;              // TSL Step Value (Points/Percent)

input group             "--- Trading Frequency Settings ---"
input int               InpMaxLongTrades      = 1;                // Max Concurrent Long Trades
input int               InpMaxShortTrades     = 1;                // Max Concurrent Short Trades
input int               InpMaxTotalTrades     = 2;                // Max Concurrent Total Trades (Long+Short)

input group             "--- Range Filter Settings ---"
input int               InpMinRangePoints     = 0;                // Min Range Points (0 = Disabled)
input double            InpMinRangePercent    = 0.0;              // Min Range Percent (0 = Disabled) - % of start price
input int               InpMaxRangePoints     = 10000;            // Max Range Points (Large = Disabled)
input double            InpMaxRangePercent    = 100.0;            // Max Range Percent (100 = Disabled) - % of start price

input group             "--- More Settings / Visuals ---"
input color             InpRangeColor         = clrAqua;          // Color for Range Rectangle
input color             InpBreakoutLevelColor = clrGold;        // <<< NEW for Mode B visual
input bool              InpChartComment       = true;             // Display Chart Comment?
input bool              InpDebugMode          = false;            // Enable Detailed Debug Logging?

//--- Global variables
datetime g_last_bar_time           = 0;
datetime g_last_day_processed      = 0;
double   g_range_high_today        = 0.0;
double   g_range_low_today         = 0.0; // Initialized in OnInit
bool     g_is_in_range_window      = false;
 
 
// To track BE status per position
long     g_be_activated_tickets[];
int      g_be_ticket_count = 0;
bool     g_daily_setup_complete      = false; // Flag: Range calc & initial checks/orders done
string   g_range_obj_name            = "";
string   g_buy_stop_line_name        = ""; // Mode A only
string   g_sell_stop_line_name       = ""; // Mode A only
long     g_be_activated_tickets[];          // Use long here due to previous testing feedback
int      g_be_ticket_count = 0;

 
bool     g_pending_orders_placed_today = false;
string   g_range_obj_name          = "";
string   g_buy_stop_line_name      = "";
string   g_sell_stop_line_name     = "";
// To track BE status per position
 

// <<< NEW Global Variables for Previous Levels >>>
double   g_prev_day_high           = 0.0;
double   g_prev_day_low            = 0.0;
double   g_prev_week_high          = 0.0;
double   g_prev_week_low           = 0.0;

string   g_pdh_line_name           = ""; // Previous Day High Line Name
string   g_pdl_line_name           = ""; // Previous Day Low Line Name
string   g_pwh_line_name           = ""; // Previous Week High Line Name
string   g_pwl_line_name           = ""; // Previous Week Low Line Name
// <<< END NEW Global Variables >>>

// <<< NEW State Variables for Mode B >>>
int      g_breakout_direction_today  = 0;   // 0=None, 1=Bullish Break, -1=Bearish Break
double   g_breakout_level_today      = 0.0; // The H/L level that was broken
bool     g_entered_retest_trade_today= false;// Only one retest entry per day/breakout direction
string   g_break_level_line_name     = ""; // Name for the breakout level line


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Initialize trading objects
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(3); // Allow small slippage
   trade.SetTypeFillingBySymbol(_Symbol);
   symbolInfo.Name(_Symbol);       // Set symbol for symbol info class

//--- Initialize range
   g_range_low_today = DBL_MAX; // Set low ridiculously high initially
   g_range_high_today = 0;      // Set high to 0

//--- Object Names
   g_range_obj_name       = "RangeRect_"   + IntegerToString(InpMagicNumber) + "_" + _Symbol + "_" + EnumToString(_Period);
   g_buy_stop_line_name   = "BuyStopLine_" + IntegerToString(InpMagicNumber) + "_" + _Symbol + "_" + EnumToString(_Period);
   g_sell_stop_line_name  = "SellStopLine_"+ IntegerToString(InpMagicNumber) + "_" + _Symbol + "_" + EnumToString(_Period);
   Print("g_range_obj_name: ", g_range_obj_name);
   Print("g_buy_stop_line_name: ", g_buy_stop_line_name);
   Print("g_sell_stop_line_name: ", g_sell_stop_line_name);

   g_pdh_line_name        = "PDH_Line_" + IntegerToString(InpMagicNumber) + "_" + _Symbol + "_" + EnumToString(_Period);
   g_pdl_line_name        = "PDL_Line_" + IntegerToString(InpMagicNumber) + "_" + _Symbol + "_" + EnumToString(_Period);
   g_pwh_line_name        = "PWH_Line_" + IntegerToString(InpMagicNumber) + "_" + _Symbol + "_" + EnumToString(_Period);
   g_pwl_line_name        = "PWL_Line_" + IntegerToString(InpMagicNumber) + "_" + _Symbol + "_" + EnumToString(_Period);

   g_break_level_line_name     = StringFormat("BreakLvl_%d_%s_%s",    InpMagicNumber, _Symbol, EnumToString(_Period)); // <<< NEW Name
//--- Resize BE tracking array initially (can grow dynamically if needed, but start small)
   ArrayResize(g_be_activated_tickets, 10);

//--- Basic Parameter Check
   if(InpRangeStartHour >= InpRangeEndHour && InpRangeStartMinute >= InpRangeEndMinute)
     {
      Print("Error: Range Start time must be before Range End time. EA stopping.");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if((InpLotSizeMode == VOLUME_PERCENT || InpLotSizeMode == VOLUME_MONEY) && InpStopCalcMode == CALC_MODE_OFF)
     {
      Print("Error: Risk Percent/Money lot sizing requires an active Stop Loss (Stop Calc Mode != OFF). EA stopping.");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpOperationMode == MODE_BREAK_RETEST && (InpBreakoutMinPoints <= 0 || InpRetestTolerancePoints <= 0))
     { 
        Print("Error: Mode B requires positive Breakout Min Points and Retest Tolerance Points."); 
        return(INIT_PARAMETERS_INCORRECT); 
     }
//PrintFormat("Range Breakout EA v%.2f initialized for %s (Magic: %d). Range: %02d:%02d - %02d:%02d.",
//            _Version, // Corrected from _Digits
//            _Symbol,
//            InpMagicNumber,
//            InpRangeStartHour, InpRangeStartMinute,
//            InpRangeEndHour, InpRangeEndMinute);

//    PrintFormat("Range Breakout EA v%s initialized for %s (Magic: %d). Range: %02d:%02d - %02d:%02d.",
//                "1.0", // <-- CORRECTED: Use MQLInfoString
//                _Symbol,
//                InpMagicNumber,
//                InpRangeStartHour, InpRangeStartMinute,
//                InpRangeEndHour, InpRangeEndMinute);

                  PrintFormat("Range Breakout EA v%s Initialized - Mode: %s | %s (Magic: %d) | Range: %02d:%02d-%02d:%02d",
               MQLInfoString(MQL_PROGRAM_VERSION),
               EnumToString(InpOperationMode),
               _Symbol, InpMagicNumber,
               InpRangeStartHour, InpRangeStartMinute, InpRangeEndHour, InpRangeEndMinute);


//--- OK
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Remove chart objects and comment
    ObjectDelete(0, g_range_obj_name);
   ObjectDelete(0, g_buy_stop_line_name);
   ObjectDelete(0, g_sell_stop_line_name);
   ObjectDelete(0, g_pdh_line_name);
   ObjectDelete(0, g_pdl_line_name);
   ObjectDelete(0, g_pwh_line_name);
   ObjectDelete(0, g_pwl_line_name);
   ObjectDelete(0, g_break_level_line_name); // <<< NEW
   Comment("");
   PrintFormat("Range Breakout EA (%s, Magic: %d) deinitialized. Reason: %d", _Symbol, InpMagicNumber, reason);
     }

//+------------------------------------------------------------------+
//| Calculate and store Previous Day/Week High/Low levels          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CalculateAndStorePreviousLevels()
  {
// --- Previous Day ---
   double pdh_arr[1];
   double pdl_arr[1];

// Copy the high of the previous D1 bar (index 1)
   if(CopyHigh(_Symbol, PERIOD_D1, 1, 1, pdh_arr) == 1)
     {
      g_prev_day_high = pdh_arr[0];
      if(InpDebugMode)
         PrintFormat("Previous Day High stored: %.*f", _Digits, g_prev_day_high);
     }
   else
     {
      g_prev_day_high = 0.0; // Indicate error or insufficient history
      PrintFormat("Error getting Previous Day High for %s: %d", _Symbol, GetLastError());
     }

// Copy the low of the previous D1 bar (index 1)
   if(CopyLow(_Symbol, PERIOD_D1, 1, 1, pdl_arr) == 1)
     {
      g_prev_day_low = pdl_arr[0];
      if(InpDebugMode)
         PrintFormat("Previous Day Low stored: %.*f", _Digits, g_prev_day_low);
     }
   else
     {
      g_prev_day_low = 0.0; // Indicate error
      PrintFormat("Error getting Previous Day Low for %s: %d", _Symbol, GetLastError());
     }

// --- Previous Week ---
   double pwh_arr[1];
   double pwl_arr[1];

// Copy the high of the previous W1 bar (index 1)
   if(CopyHigh(_Symbol, PERIOD_W1, 1, 1, pwh_arr) == 1)
     {
      g_prev_week_high = pwh_arr[0];
      if(InpDebugMode)
         PrintFormat("Previous Week High stored: %.*f", _Digits, g_prev_week_high);
     }
   else
     {
      g_prev_week_high = 0.0; // Indicate error
      PrintFormat("Error getting Previous Week High for %s: %d", _Symbol, GetLastError());
     }

// Copy the low of the previous W1 bar (index 1)
   if(CopyLow(_Symbol, PERIOD_W1, 1, 1, pwl_arr) == 1)
     {
      g_prev_week_low = pwl_arr[0];
      if(InpDebugMode)
         PrintFormat("Previous Week Low stored: %.*f", _Digits, g_prev_week_low);
     }
   else
     {
      g_prev_week_low = 0.0; // Indicate error
      PrintFormat("Error getting Previous Week Low for %s: %d", _Symbol, GetLastError());
     }
  }

//+------------------------------------------------------------------+
//| Draw or Update Previous Day/Week High/Low Lines                  |
//+------------------------------------------------------------------+
void DrawOrUpdatePreviousLevelLines()
  {
   datetime current_time = TimeCurrent(); // Use consistent time for all lines on update

// --- Previous Day High ---
   if(g_prev_day_high > 0) // Only draw if value is valid
     {
      if(ObjectFind(0, g_pdh_line_name) < 0) // Create if not found
        {
         ObjectCreate(0, g_pdh_line_name, OBJ_HLINE, 0, current_time, g_prev_day_high);
         ObjectSetInteger(0, g_pdh_line_name, OBJPROP_COLOR, clrGray);
         ObjectSetInteger(0, g_pdh_line_name, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, g_pdh_line_name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, g_pdh_line_name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, g_pdh_line_name, OBJPROP_BACK, true);
         ObjectSetString(0, g_pdh_line_name, OBJPROP_TEXT, "PDH"); // Add text description
         ObjectSetInteger(0, g_pdh_line_name, OBJPROP_ALIGN, ALIGN_RIGHT); // Position text
        }
      else // Update if found
        {
         ObjectSetDouble(0, g_pdh_line_name, OBJPROP_PRICE, 0, g_prev_day_high);
         // Optional: Update time anchor if needed, but usually not for HLINEs
         // ObjectSetInteger(0, g_pdh_line_name, OBJPROP_TIME, 0, current_time);
        }
     }
   else
     {
      ObjectDelete(0, g_pdh_line_name);   // Delete if level is invalid
     }

// --- Previous Day Low ---
   if(g_prev_day_low > 0)
     {
      if(ObjectFind(0, g_pdl_line_name) < 0)
        {
         ObjectCreate(0, g_pdl_line_name, OBJ_HLINE, 0, current_time, g_prev_day_low);
         ObjectSetInteger(0, g_pdl_line_name, OBJPROP_COLOR, clrGray);
         ObjectSetInteger(0, g_pdl_line_name, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, g_pdl_line_name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, g_pdl_line_name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, g_pdl_line_name, OBJPROP_BACK, true);
         ObjectSetString(0, g_pdl_line_name, OBJPROP_TEXT, "PDL");
         ObjectSetInteger(0, g_pdl_line_name, OBJPROP_ALIGN, ALIGN_RIGHT);
        }
      else
        {
         ObjectSetDouble(0, g_pdl_line_name, OBJPROP_PRICE, 0, g_prev_day_low);
        }
     }
   else
     {
      ObjectDelete(0, g_pdl_line_name);
     }

// --- Previous Week High ---
   if(g_prev_week_high > 0)
     {
      if(ObjectFind(0, g_pwh_line_name) < 0)
        {
         ObjectCreate(0, g_pwh_line_name, OBJ_HLINE, 0, current_time, g_prev_week_high);
         ObjectSetInteger(0, g_pwh_line_name, OBJPROP_COLOR, clrDarkGray); // Slightly different shade
         ObjectSetInteger(0, g_pwh_line_name, OBJPROP_STYLE, STYLE_DASHDOT); // Different Style
         ObjectSetInteger(0, g_pwh_line_name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, g_pwh_line_name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, g_pwh_line_name, OBJPROP_BACK, true);
         ObjectSetString(0, g_pwh_line_name, OBJPROP_TEXT, "PWH");
         ObjectSetInteger(0, g_pwh_line_name, OBJPROP_ALIGN, ALIGN_RIGHT);
        }
      else
        {
         ObjectSetDouble(0, g_pwh_line_name, OBJPROP_PRICE, 0, g_prev_week_high);
        }
     }
   else
     {
      ObjectDelete(0, g_pwh_line_name);
     }

// --- Previous Week Low ---
   if(g_prev_week_low > 0)
     {
      if(ObjectFind(0, g_pwl_line_name) < 0)
        {
         ObjectCreate(0, g_pwl_line_name, OBJ_HLINE, 0, current_time, g_prev_week_low);
         ObjectSetInteger(0, g_pwl_line_name, OBJPROP_COLOR, clrDarkGray);
         ObjectSetInteger(0, g_pwl_line_name, OBJPROP_STYLE, STYLE_DASHDOT);
         ObjectSetInteger(0, g_pwl_line_name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, g_pwl_line_name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, g_pwl_line_name, OBJPROP_BACK, true);
         ObjectSetString(0, g_pwl_line_name, OBJPROP_TEXT, "PWL");
         ObjectSetInteger(0, g_pwl_line_name, OBJPROP_ALIGN, ALIGN_RIGHT);
        }
      else
        {
         ObjectSetDouble(0, g_pwl_line_name, OBJPROP_PRICE, 0, g_prev_week_low);
        }
     }
   else
     {
      ObjectDelete(0, g_pwl_line_name);
     }


   ChartRedraw(); // Redraw chart to show changes
  }
 
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- Basic check: Only run once per bar for efficiency if possible
   datetime current_bar_time = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   if(current_bar_time == g_last_bar_time && MQL5InfoInteger(MQL5_TESTING) == false) // Only skip ticks when not testing
      return;
   g_last_bar_time = current_bar_time;

//--- Refresh symbol rates
   symbolInfo.RefreshRates();

//--- Get current server time structure
   MqlDateTime tm;
   TimeCurrent(tm);

//--- Check for new day
   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if(today != g_last_day_processed)
     {
      if(InpDebugMode)
         Print("New day detected: ", TimeToString(today));
      ResetDailyVariables();

       CalculateAndStorePreviousLevels();    // Get PDH/L, PWH/L
      DrawOrUpdatePreviousLevelLines();     // Draw PDH/L, PWH/L lines
      g_last_day_processed = today;         // Mark day as processed AFTER setup


      g_last_day_processed = today;
     }

   // --- Get Time Flags ---
   bool is_in_range           = IsInRangeWindow(tm);
   bool is_after_range_start  = IsAfterRangeStart(tm); // Need this check too
   bool is_range_period_over  = IsRangePeriodOver(tm);
   bool is_stop_time          = IsTimeToStopNewEntries(tm);
   bool is_delete_time        = IsTimeToDeleteOrders(tm);
   bool is_close_time         = InpClosePositions && IsTimeToClosePositions(tm);

// --- 1. Update Range during the specified window ---
   if(is_in_range && !g_daily_setup_complete)
     {
      datetime range_start_dt = GetDateTimeToday(InpRangeStartHour, InpRangeStartMinute);
      UpdateDailyRange(range_start_dt, TimeCurrent());
      UpdateChartObjects(); // Update visual range rectangle
     }
   else
     {
      g_is_in_range_window = false; // Clear flag outside window
     }

   // --- 2. Daily Setup (End of Range) ---
   // Perform end-of-range checks and place pending orders (Mode A) *ONCE*
   if(is_range_period_over && !g_daily_setup_complete && g_range_high_today > 0 && g_range_low_today < DBL_MAX)
     {
      g_daily_setup_complete = true; // Mark daily setup as done

      if(InpDebugMode) Print("Range Period Over. H:", g_range_high_today, " L:", g_range_low_today);

      if(CheckRangeFilters()) // Check filters AFTER range is finalized
        {
         if(InpOperationMode == MODE_RANGE_BREAKOUT)
           {
              PlaceBreakoutOrders(); // Mode A places pending orders
           }
         else // Mode B: Store breakout levels, start monitoring
           {
             if(InpDebugMode) Print("Mode B activated: Waiting for initial breakout.");
             // Initial level drawing can happen here if desired
             DrawOrUpdateBreakoutLevelLine(g_range_high_today); // Draw potential H break line
             DrawOrUpdateBreakoutLevelLine(g_range_low_today); // Draw potential L break line
           }
        }
       else
        {
          Print("Order placement skipped: Range did not pass filters.");
          // Update objects one last time to show final range even if filtered
           UpdateChartObjects();
        }
     }
    // --- 3. Mode B: Check for Breakout & Retest (ONLY after range window AND if no entry yet AND before stop time) ---
    if(InpOperationMode == MODE_BREAK_RETEST && g_daily_setup_complete && !is_stop_time)
    {
       if (g_breakout_direction_today == 0) // Check for initial breakout ONLY if setup is complete
       {
           CheckForInitialBreakout();
       }
       else if (!g_entered_retest_trade_today) // If breakout occurred, check for retest entry
       {
          CheckAndEnterRetest();
       }
    }

   // --- 4. Manage Open Positions --- (Applies to both modes)
   ManageOpenPositions();

   // --- 5. Delete Pending Orders --- (Relevant for Mode A)
   if(is_delete_time && InpOperationMode == MODE_RANGE_BREAKOUT)
     {
      DeletePendingOrdersByMagic();
     }

   // --- 6. Close Open Positions --- (Applies to both modes)
   if(is_close_time)
     {
      CloseOpenPositionsByMagic();
     }

   // --- 7. Update Chart Comment --- (Applies to both modes)
   if(InpChartComment)
      UpdateChartComment(tm);

  }
//+------------------------------------------------------------------+
//| Check if current time is within the Range window                 |
//+------------------------------------------------------------------+
bool IsInRangeWindow(const MqlDateTime &tm)
  {
   int current_minute_of_day = tm.hour * 60 + tm.min;
   int start_minute_of_day = InpRangeStartHour * 60 + InpRangeStartMinute;
   int end_minute_of_day = InpRangeEndHour * 60 + InpRangeEndMinute;

// Handle overnight ranges (e.g., 22:00 to 02:00)
   if(start_minute_of_day > end_minute_of_day)
      return (current_minute_of_day >= start_minute_of_day || current_minute_of_day < end_minute_of_day);
   else
      return (current_minute_of_day >= start_minute_of_day && current_minute_of_day < end_minute_of_day);
  }
//+------------------------------------------------------------------+
//| Check if current time is at or after the Range End time         |
//+------------------------------------------------------------------+
// bool IsAfterRangeEnd(const MqlDateTime &tm)
//   {
//    int current_minute_of_day = tm.hour * 60 + tm.min;
//    int end_minute_of_day = InpRangeEndHour * 60 + InpRangeEndMinute;

// // Special case: Range ends exactly at midnight 23:59 -> 00:00 scenario handled by >=
//    return (current_minute_of_day >= end_minute_of_day);
//   }

bool IsAfterRangeStart(const MqlDateTime &tm)
 {
   int current_minute_of_day = tm.hour * 60 + tm.min;
   int start_minute_of_day = InpRangeStartHour * 60 + InpRangeStartMinute;
   return (current_minute_of_day >= start_minute_of_day);
 }
 
bool IsRangePeriodOver(const MqlDateTime &tm) // Changed name from IsAfterRangeEnd for clarity
 {
   int current_minute_of_day = tm.hour * 60 + tm.min;
   int end_minute_of_day = InpRangeEndHour * 60 + InpRangeEndMinute;
   return (current_minute_of_day >= end_minute_of_day);
 }


//+------------------------------------------------------------------+
//| Check if it's time to delete pending orders                       |
//+------------------------------------------------------------------+
bool IsTimeToDeleteOrders(const MqlDateTime &tm)
  {
   return(tm.hour == InpDeleteOrdersHour && tm.min == InpDeleteOrdersMinute);
  }
//+------------------------------------------------------------------+
//| Check if it's time to close open positions                      |
//+------------------------------------------------------------------+
bool IsTimeToClosePositions(const MqlDateTime &tm)
  {
   return(tm.hour == InpClosePosHour && tm.min == InpClosePosMinute);
  }

  bool IsTimeToStopNewEntries(const MqlDateTime &tm) // New for Mode B cutoff
 {
    int current_minute_of_day = tm.hour * 60 + tm.min;
    int stop_minute_of_day = InpStopTimeHour * 60 + InpStopTimeMinute;
    return (current_minute_of_day >= stop_minute_of_day);
 }


//+------------------------------------------------------------------+
//| Reset variables at the start of a new day                        |
//+------------------------------------------------------------------+
// void ResetDailyVariables()
//   {
//    g_range_high_today = 0.0;
//    g_range_low_today = DBL_MAX; // Use DBL_MAX for initial low comparison
//    g_pending_orders_placed_today = false;
//    g_is_in_range_window = false;

// // Reset Break-Even Tracking Array
//    ArrayInitialize(g_be_activated_tickets, 0);
//    g_be_ticket_count = 0;

// // Optional: Delete previous day's range objects immediately
//    ResetLastError(); // Clear previous errors
//    ObjectDelete(0, g_range_obj_name);
//    int delete_error = GetLastError();
//    if(delete_error != 0 && InpDebugMode)
//       PrintFormat("Warning: Error deleting object '%s' in ResetDailyVariables: %d", g_range_obj_name, delete_error);

//    ObjectDelete(0, g_buy_stop_line_name);
//    ObjectDelete(0, g_sell_stop_line_name);

//    if(InpDebugMode)
//       Print("Daily variables reset.");
//   }

//+------------------------------------------------------------------+
//| Reset Daily Variables (Updated)                                  |
//+------------------------------------------------------------------+
void ResetDailyVariables()
  {
   g_range_high_today = 0.0;
   g_range_low_today = DBL_MAX;
   g_daily_setup_complete = false; // Use new flag name
   g_is_in_range_window = false;

   // Mode B Resets
   g_breakout_direction_today = 0;
   g_breakout_level_today = 0.0;
   g_entered_retest_trade_today = false;

   // Reset BE Tracking
   ArrayInitialize(g_be_activated_tickets, 0);
   g_be_ticket_count = 0;

   // Delete Visuals (Attempt to delete all potentially existing objects from yesterday)
   ResetLastError();
   ObjectDelete(0, g_range_obj_name);
   ObjectDelete(0, g_buy_stop_line_name);
   ObjectDelete(0, g_sell_stop_line_name);
   ObjectDelete(0, g_pdh_line_name);
   ObjectDelete(0, g_pdl_line_name);
   ObjectDelete(0, g_pwh_line_name);
   ObjectDelete(0, g_pwl_line_name);
   ObjectDelete(0, g_break_level_line_name); // <<< NEW
   // Print warning on error, but don't stop execution (as object might just not exist)
   int delete_error = GetLastError();
   if(delete_error != 0 && delete_error != ERR_OBJECT_DOES_NOT_EXIST && InpDebugMode)
      PrintFormat("Warning: Error during object deletion in ResetDailyVariables: %d", delete_error);

   if(InpDebugMode) Print("Daily variables reset.");
  }



//+------------------------------------------------------------------+
//| Construct datetime for today with specific hour/minute         |
//+------------------------------------------------------------------+
datetime GetDateTimeToday(int hour, int minute)
  {
   MqlDateTime tm;
   TimeCurrent(tm); // Get current server time components
   tm.hour = hour;
   tm.min = minute;
   tm.sec = 0;
   return(StructToTime(tm));
  }
//+------------------------------------------------------------------+
//| Updates the daily High/Low range                               |
//+------------------------------------------------------------------+
bool UpdateDailyRange(datetime startTime, datetime endTime)
  {
   if(InpTimeframeRangeCalc == PERIOD_CURRENT)
     {
      Print("Error: 'Current' timeframe not suitable for Range Calculation. Please select a specific timeframe (e.g., M1).");
      return false;
     }

   MqlRates rates[];
   int bars_copied = CopyRates(_Symbol, InpTimeframeRangeCalc, startTime, endTime, rates);

   if(bars_copied <= 0)
     {
      if(InpDebugMode)
         PrintFormat("Error copying rates for range: %d. Start: %s, End: %s", bars_copied, TimeToString(startTime), TimeToString(endTime));
      return false;
     }

   double current_day_high = 0;
   double current_day_low = DBL_MAX;

   for(int i = 0; i < bars_copied; i++)
     {
      if(rates[i].high > current_day_high)
         current_day_high = rates[i].high;
      if(rates[i].low < current_day_low)
         current_day_low = rates[i].low;
     }

//--- Only update if valid data was found and range is sensible
   if(current_day_high > 0 && current_day_low < DBL_MAX)
     {
      // Update global range only if new high/low is found or it's the first update
      g_range_high_today = MathMax(g_range_high_today, current_day_high);
      g_range_low_today = MathMin(g_range_low_today, current_day_low);
     }
   else
     {
      if(InpDebugMode)
         Print("Could not find valid High/Low in copied rates.");
      return false;
     }

   if(InpDebugMode && (bars_copied > 0))
     {
      // Avoid printing constantly if called repeatedly during the window
      static datetime lastPrintTime = 0;
      if(TimeCurrent() - lastPrintTime > 5) // Print max every 5 seconds
        {
         // PrintFormat("Range Updated: H=%.*f, L=%.*f (%d bars copied from %s)",
         //             _Digits, g_range_high_today, _Digits, g_range_low_today,
         //             bars_copied, TimeToString(startTime, TIME_SECONDS));
         lastPrintTime = TimeCurrent();
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
//| Checks if the calculated range size meets filter criteria        |
//+------------------------------------------------------------------+
bool CheckRangeFilters()
  {
   if(g_range_high_today <= 0 || g_range_low_today >= DBL_MAX || g_range_high_today <= g_range_low_today)
     {
      if(InpDebugMode)
         Print("Range filter check skipped: Invalid range detected (H=", g_range_high_today, ", L=", g_range_low_today, ")");
      return false; // Cannot filter an invalid range
     }

   double range_in_points = MathRound((g_range_high_today - g_range_low_today) / symbolInfo.Point());

// Calculate % based on range start price (using the low as proxy, refinement needed for exact start price)
// Let's fetch the open price at the start of the range for % calc base
   MqlRates startRate[];
   datetime range_start_dt = GetDateTimeToday(InpRangeStartHour, InpRangeStartMinute);
   if(CopyRates(_Symbol, InpTimeframeRangeCalc, range_start_dt, range_start_dt + PeriodSeconds(InpTimeframeRangeCalc), startRate) <= 0)
     {
      if(InpDebugMode)
         Print("Could not get start price for range % filter. Skipping % filter.");
      // Decide: Either skip % check or fail filter. Let's skip for now.
     }

   double range_percent = 0.0;
   if(ArraySize(startRate) > 0 && startRate[0].open > 0)
     {
      range_percent = ((g_range_high_today - g_range_low_today) / startRate[0].open) * 100.0;
     }
   else // Fallback if start price fetch failed, using low (less accurate for %)
     {
      if(g_range_low_today > 0)
         range_percent = ((g_range_high_today - g_range_low_today) / g_range_low_today) * 100.0;
     }

   if(InpDebugMode)
      PrintFormat("Range Filter Check: Points=%.0f, Percent=%.2f%%", range_in_points, range_percent);

// Minimum filters
   if(InpMinRangePoints > 0 && range_in_points < InpMinRangePoints)
     {
      PrintFormat("Filter failed: Range Points (%.0f) < Min Points (%d)", range_in_points, InpMinRangePoints);
      return false;
     }
   if(InpMinRangePercent > 0 && range_percent < InpMinRangePercent)
     {
      if(range_percent > 0)  // Only print warning if % calc was possible
        {
         PrintFormat("Filter failed: Range Percent (%.2f%%) < Min Percent (%.2f%%)", range_percent, InpMinRangePercent);
         return false;
        }
      else
        {
         if(InpDebugMode)
            Print("Warning: Could not apply Min Range Percent filter due to price data issue.");
         // Potentially allow trading anyway, or strictly return false. Let's be strict.
         return false;
        }
     }

// Maximum filters
   if(InpMaxRangePoints > 0 && range_in_points > InpMaxRangePoints)
     {
      PrintFormat("Filter failed: Range Points (%.0f) > Max Points (%d)", range_in_points, InpMaxRangePoints);
      return false;
     }
   if(InpMaxRangePercent > 0 && range_percent > InpMaxRangePercent)
     {
      if(range_percent > 0) // Only print warning if % calc was possible
        {
         PrintFormat("Filter failed: Range Percent (%.2f%%) > Max Percent (%.2f%%)", range_percent, InpMaxRangePercent);
         return false;
        }
      else
        {
         if(InpDebugMode)
            Print("Warning: Could not apply Max Range Percent filter due to price data issue.");
         // Potentially allow trading anyway, or strictly return false. Let's be strict.
         return false;
        }
     }

   if(InpDebugMode)
      Print("Range filters passed.");
   return true;
  }
//+------------------------------------------------------------------+
//| Place the Buy Stop and Sell Stop orders                          |
//+------------------------------------------------------------------+
// void PlaceBreakoutOrders()
//   {
// //--- Double check if range is valid
//    if(g_range_high_today <= 0 || g_range_low_today >= DBL_MAX || g_range_high_today <= g_range_low_today)
//      {
//       Print("Order placement skipped: Invalid range.");
//       return;
//      }
// //--- Check filters first
//    if(!CheckRangeFilters())
//      {
//       Print("Order placement skipped: Range did not pass filters.");
//       UpdateChartObjects(); // Show range even if filtered
//       return;
//      }

// //--- Calculate prices for pending orders
//    double point = symbolInfo.Point();
//    double buy_stop_price = NormalizeDouble(g_range_high_today + InpOrderBufferPoints * point, _Digits);
//    double sell_stop_price = NormalizeDouble(g_range_low_today - InpOrderBufferPoints * point, _Digits);

// //--- Calculate initial SL/TP (prices relative to pending order prices)
//    double buy_sl = 0, buy_tp = 0, sell_sl = 0, sell_tp = 0;
//    CalculateSLTPPrices(buy_stop_price, g_range_high_today, g_range_low_today, true, buy_sl, buy_tp); // isBuy = true
//    CalculateSLTPPrices(sell_stop_price, g_range_high_today, g_range_low_today, false, sell_sl, sell_tp); // isBuy = false

//    if(InpDebugMode)
//       PrintFormat("Pre-calc: BuyStop=%.*f SL=%.*f TP=%.*f | SellStop=%.*f SL=%.*f TP=%.*f",
//                   _Digits, buy_stop_price, _Digits, buy_sl, _Digits, buy_tp,
//                   _Digits, sell_stop_price, _Digits, sell_sl, _Digits, sell_tp);

// //--- Calculate lot sizes (needs SL prices if risk-based)
//    double buy_lots = CalculateLotSize(buy_stop_price, buy_sl); // Pass SL price for risk calcs
//    double sell_lots = CalculateLotSize(sell_stop_price, sell_sl); // Pass SL price for risk calcs

// //--- Final check for valid calculations
//    if(buy_lots <= 0 || sell_lots <= 0)
//      {
//       Print("Order placement skipped: Could not calculate valid lot size.");
//       return;
//      }

// //--- Check Frequency Limits before placing
//    int current_longs = GetCurrentTradeCount(POSITION_TYPE_BUY);
//    int current_shorts = GetCurrentTradeCount(POSITION_TYPE_SELL);
//    int current_total = current_longs + current_shorts;

// //--- Place Buy Stop Order
//    bool buy_order_ok = false;
//    if(current_longs < InpMaxLongTrades && current_total < InpMaxTotalTrades)
//      {
//       if(trade.BuyStop(buy_lots, buy_stop_price, _Symbol, buy_sl, buy_tp, ORDER_TIME_GTC, 0, InpOrderComment))
//         {
//          PrintFormat("Buy Stop placed: %.2f lots at %.*f, SL %.*f, TP %.*f, Ticket: %d",
//                      buy_lots, _Digits, buy_stop_price, _Digits, buy_sl, _Digits, buy_tp, trade.ResultOrder());
//          buy_order_ok = true;
//         }
//       else
//         {
//          PrintFormat("Error placing Buy Stop: %d - %s", trade.ResultRetcode(), trade.ResultRetcodeDescription());
//         }
//      }
//    else
//       if(InpDebugMode)
//          Print("Skipping Buy Stop due to trade frequency limits.");

// //--- Place Sell Stop Order
//    bool sell_order_ok = false;
//    if(current_shorts < InpMaxShortTrades && current_total < InpMaxTotalTrades)
//      {
//       if(trade.SellStop(sell_lots, sell_stop_price, _Symbol, sell_sl, sell_tp, ORDER_TIME_GTC, 0, InpOrderComment))
//         {
//          PrintFormat("Sell Stop placed: %.2f lots at %.*f, SL %.*f, TP %.*f, Ticket: %d",
//                      sell_lots, _Digits, sell_stop_price, _Digits, sell_sl, _Digits, sell_tp, trade.ResultOrder());
//          sell_order_ok = true;
//         }
//       else
//         {
//          PrintFormat("Error placing Sell Stop: %d - %s", trade.ResultRetcode(), trade.ResultRetcodeDescription());
//         }
//      }
//    else
//       if(InpDebugMode)
//          Print("Skipping Sell Stop due to trade frequency limits.");

// //--- Update visuals after placement attempt
//    UpdateChartObjects(buy_stop_price, sell_stop_price, buy_order_ok, sell_order_ok);

//   }


//+------------------------------------------------------------------+
//| PlaceBreakoutOrders (Conditional for Mode A)                      |
//+------------------------------------------------------------------+
void PlaceBreakoutOrders() // Now explicitly Mode A
  {
    if(InpOperationMode != MODE_RANGE_BREAKOUT) return; // Only run in Mode A

    //--- Rest of the logic from the previous v1.60 PlaceBreakoutOrders is ok ---
    // Double check range validity...
    // Call CheckRangeFilters() already done before calling this function usually... maybe remove filter check from here? Or keep double check.
    // Calculate pending prices + buffer...
    // Calculate initial SL/TP for pending orders... (Call CalculateSLTPPrices with PENDING prices)
    // Calculate lot sizes... (Call CalculateLotSize with PENDING price and SL price)
    // Check frequency limits...
    // trade.BuyStop(...)
    // trade.SellStop(...)
    // UpdateChartObjects with pending order details...
    // ---

   // Keep the example structure for reference (IMPLEMENT FULLY)
   if(InpDebugMode) Print("PlaceBreakoutOrders called for Mode A.");
   // --- Calculate prices for pending orders ---
   double point = symbolInfo.Point();
   double buy_stop_price = NormalizeDouble(g_range_high_today + InpOrderBufferPoints * point, _Digits);
   double sell_stop_price = NormalizeDouble(g_range_low_today - InpOrderBufferPoints * point, _Digits);

   // --- Calculate initial SL/TP for pending orders ---
   double buy_sl=0, buy_tp=0, sell_sl=0, sell_tp=0;
   // Pass PENDING prices to SL/TP calc
   CalculateSLTPPrices(buy_stop_price, g_range_high_today, g_range_low_today, true, buy_sl, buy_tp);
   CalculateSLTPPrices(sell_stop_price, g_range_high_today, g_range_low_today, false, sell_sl, sell_tp);

    // --- Calculate lot sizes based on pending setup ---
   double buy_lots = CalculateLotSize(buy_stop_price, buy_sl);
   double sell_lots = CalculateLotSize(sell_stop_price, sell_sl);

   if(buy_lots <= 0 || sell_lots <= 0) {/* Print & return */}

   // --- Check Frequency ---
    int current_longs = GetCurrentTradeCount(POSITION_TYPE_BUY);
    int current_shorts = GetCurrentTradeCount(POSITION_TYPE_SELL);
    int current_total = current_longs + current_shorts;

    // --- Place Buy Stop ---
    bool buy_order_ok = false;
    if (current_longs < InpMaxLongTrades && current_total < InpMaxTotalTrades)
    {
        if(trade.BuyStop(buy_lots, buy_stop_price, _Symbol, buy_sl, buy_tp, ORDER_TIME_GTC, 0, InpOrderComment))
         {/*...*/ buy_order_ok = true;} else {/* Print Error */}
    } else {/* Debug Print */}

    // --- Place Sell Stop ---
     bool sell_order_ok = false;
    if (current_shorts < InpMaxShortTrades && current_total < InpMaxTotalTrades)
    {
        if(trade.SellStop(sell_lots, sell_stop_price, _Symbol, sell_sl, sell_tp, ORDER_TIME_GTC, 0, InpOrderComment))
        {/*...*/ sell_order_ok = true;} else {/* Print Error */}
    } else {/* Debug Print */}

     // --- Update visuals showing PENDING lines ---
   UpdateChartObjects(buy_stop_price, sell_stop_price, buy_order_ok, sell_order_ok); // Overload might need adjustment

  }
//+------------------------------------------------------------------+
//| <<< NEW: Check for Initial Breakout (Mode B) >>>               |
//+------------------------------------------------------------------+
void CheckForInitialBreakout()
  {
    if(g_breakout_direction_today != 0 || g_range_high_today <= 0 || g_range_low_today >= DBL_MAX) return; // Already broken or range invalid

    double point = symbolInfo.Point();
    double break_dist_price = InpBreakoutMinPoints * point;
    symbolInfo.RefreshRates(); // Ensure latest price
    double current_ask = symbolInfo.Ask();
    double current_bid = symbolInfo.Bid();

    // Check for Bullish Breakout (using Ask price)
    if(current_ask > g_range_high_today + break_dist_price)
     {
      g_breakout_direction_today = 1; // Bullish Break confirmed
      g_breakout_level_today = g_range_high_today;
      if(InpDebugMode) PrintFormat("Mode B: Initial Bullish Breakout confirmed above %. *f", _Digits, g_range_high_today);
      DrawOrUpdateBreakoutLevelLine(g_breakout_level_today); // Draw line at breakout level
      // Delete the potential Low breakout line if it exists
      ObjectDelete(0, g_break_level_line_name + "_Low");
      return; // Stop checking once first break confirmed
     }

    // Check for Bearish Breakout (using Bid price)
    if(current_bid < g_range_low_today - break_dist_price)
     {
       g_breakout_direction_today = -1; // Bearish Break confirmed
       g_breakout_level_today = g_range_low_today;
       if(InpDebugMode) PrintFormat("Mode B: Initial Bearish Breakout confirmed below %. *f", _Digits, g_range_low_today);
       DrawOrUpdateBreakoutLevelLine(g_breakout_level_today); // Draw line at breakout level
       // Delete the potential High breakout line if it exists
       ObjectDelete(0, g_break_level_line_name + "_High");
      return; // Stop checking once first break confirmed
     }
  }

//+------------------------------------------------------------------+
//| <<< NEW: Check for Retest and Enter Market Order (Mode B) >>>   |
//+------------------------------------------------------------------+
void CheckAndEnterRetest()
  {
    if(g_breakout_direction_today == 0 || g_entered_retest_trade_today || g_breakout_level_today <= 0) return; // Conditions not met

    double point = symbolInfo.Point();
    double tolerance_price = InpRetestTolerancePoints * point;
    double confirmation_price_dist = InpRetestConfirmPoints * point;
    symbolInfo.RefreshRates();
    double current_ask = symbolInfo.Ask();
    double current_bid = symbolInfo.Bid();
    bool in_retest_zone = false;
    bool confirmed_hold = false;

    // --- Check if Price is in the Retest Zone ---
    if(g_breakout_direction_today == 1) // Bullish Break, checking retest of High level
     {
        if(current_bid <= g_breakout_level_today + tolerance_price && current_bid >= g_breakout_level_today - tolerance_price) // Within tolerance zone around broken High
        {
             in_retest_zone = true;
             // Check for confirmation (moving UP away from level after retest)
             if(current_ask > g_breakout_level_today + confirmation_price_dist) // Simple check: Ask moved back up
             {
                confirmed_hold = true;
             }
        }
     }
    else // Bearish Break, checking retest of Low level
     {
       if(current_ask >= g_breakout_level_today - tolerance_price && current_ask <= g_breakout_level_today + tolerance_price ) // Within tolerance zone around broken Low
       {
            in_retest_zone = true;
            // Check for confirmation (moving DOWN away from level after retest)
             if(current_bid < g_breakout_level_today - confirmation_price_dist) // Simple check: Bid moved back down
            {
                confirmed_hold = true;
            }
       }
     }

    // --- Enter Trade if Retest Confirmed ---
    if(in_retest_zone && confirmed_hold)
     {
      if(InpDebugMode) PrintFormat("Mode B: Retest Confirmed at level %. *f, attempting entry.", _Digits, g_breakout_level_today);

      // Check frequency limits
       int current_longs = GetCurrentTradeCount(POSITION_TYPE_BUY);
       int current_shorts = GetCurrentTradeCount(POSITION_TYPE_SELL);
       int current_total = current_longs + current_shorts;

       if ((g_breakout_direction_today == 1 && current_longs >= InpMaxLongTrades) ||
           (g_breakout_direction_today == -1 && current_shorts >= InpMaxShortTrades) ||
           (current_total >= InpMaxTotalTrades))
       {
           if (InpDebugMode) Print("Mode B: Entry skipped due to trade frequency limits.");
           g_entered_retest_trade_today = true; // Prevent further attempts today even if limits clear later
           return;
       }


       // Calculate SL/TP based on MARKET entry price now
       double market_entry_price = (g_breakout_direction_today == 1) ? current_ask : current_bid; // Approx entry
       double sl=0, tp=0;
       // USE CURRENT RANGE H/L for factor calculation if needed
       CalculateSLTPPrices(market_entry_price, g_range_high_today, g_range_low_today, (g_breakout_direction_today == 1), sl, tp);

       // Calculate Lot Size based on MARKET SL
       double lots = CalculateLotSize(market_entry_price, sl);

        if (lots > 0)
        {
            if (g_breakout_direction_today == 1) // Enter Buy Market Order
            {
                if(trade.Buy(lots, _Symbol, current_ask, sl, tp, InpOrderComment))
                {
                   PrintFormat("Mode B: BUY Market Order placed: %.2f lots at ~%.*f, SL %.*f, TP %.*f, Ticket: %d",
                             lots, _Digits, current_ask, _Digits, sl, _Digits, tp, trade.ResultDeal()); // Deal for market
                    g_entered_retest_trade_today = true; // Set flag AFTER successful order
                } else { PrintFormat("Error placing Mode B Buy Order: %d - %s", trade.ResultRetcode(), trade.ResultRetcodeDescription()); }
            }
            else // Enter Sell Market Order
            {
                 if(trade.Sell(lots, _Symbol, current_bid, sl, tp, InpOrderComment))
                {
                    PrintFormat("Mode B: SELL Market Order placed: %.2f lots at ~%.*f, SL %.*f, TP %.*f, Ticket: %d",
                             lots, _Digits, current_bid, _Digits, sl, _Digits, tp, trade.ResultDeal());
                     g_entered_retest_trade_today = true;
                } else { PrintFormat("Error placing Mode B Sell Order: %d - %s", trade.ResultRetcode(), trade.ResultRetcodeDescription()); }
            }

            if (g_entered_retest_trade_today) {
                 ObjectDelete(0, g_break_level_line_name); // Clean up breakout line after entry
            }
        }
        else
        {
             Print("Mode B: Entry skipped - could not calculate valid lot size.");
        }
     }
  }

//+------------------------------------------------------------------+
//| Calculate Lot Size based on Input Mode                           |
//+------------------------------------------------------------------+
// double CalculateLotSize(double priceEntry, double priceSL) // Pass SL for risk modes
//   {
//    double lots = 0.0;
//    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
//    double point = symbolInfo.Point();
//    double min_lot = symbolInfo.LotsMin();
//    double max_lot = symbolInfo.LotsMax();
//    double step_lot = symbolInfo.LotsStep();

//    switch(InpLotSizeMode)
//      {
//       case VOLUME_FIXED:
//          lots = InpFixedLots;
//          break;

//       case VOLUME_MANAGED:
//          if(InpMoneyForLots > 0) // Avoid division by zero
//             lots = InpLotsPerXMoney * (balance / InpMoneyForLots);
//          else
//             lots = InpLotsPerXMoney; // Fallback or default if X money is zero
//          break;

//       case VOLUME_PERCENT:
//         {
//          if(InpStopCalcMode == CALC_MODE_OFF || priceSL == 0 || priceEntry == priceSL)
//            {
//             Print("Warning: Cannot calculate VOLUME_PERCENT lots without a valid SL. Using minimal lots.");
//             lots = min_lot; // Use minimum instead of failing entirely? Risky. Better to stop or use fixed. Default to min for now.
//             break;
//            }
//          double risk_amount_pct = balance * (InpRiskPercentBalance / 100.0);
//          double stop_loss_points = MathAbs(priceEntry - priceSL) / point;
//          double tick_value = symbolInfo.TickValue();
//          if(stop_loss_points > 0 && tick_value > 0)
//            {
//             lots = risk_amount_pct / (stop_loss_points * tick_value);
//            }
//          else
//            {
//             Print("Warning: SL points or Tick value is zero for VOLUME_PERCENT calc. Using minimal lots.");
//             lots = min_lot;
//            }
//         }
//       break;

//       case VOLUME_MONEY:
//         {
//          if(InpStopCalcMode == CALC_MODE_OFF || priceSL == 0 || priceEntry == priceSL)
//            {
//             Print("Warning: Cannot calculate VOLUME_MONEY lots without a valid SL. Using minimal lots.");
//             lots = min_lot;
//             break;
//            }
//          double stop_loss_points_money = MathAbs(priceEntry - priceSL) / point;
//          double tick_value_money = symbolInfo.TickValue();
//          if(stop_loss_points_money > 0 && tick_value_money > 0)
//            {
//             lots = InpRiskMoney / (stop_loss_points_money * tick_value_money);
//            }
//          else
//            {
//             Print("Warning: SL points or Tick value is zero for VOLUME_MONEY calc. Using minimal lots.");
//             lots = min_lot;
//            }
//         }
//       break;
//      }

// //--- Normalize and Clamp Lot Size
//    lots = MathRound(lots / step_lot) * step_lot; // Normalize to step
//    lots = NormalizeDouble(lots, 2); // Typically 2 decimal places for lots

//    if(lots < min_lot)
//       lots = min_lot;
//    if(lots > max_lot && max_lot > 0) // Some brokers might not report max_lot correctly
//       lots = max_lot;

//    if(InpDebugMode)
//       PrintFormat("Calculated Lot Size: %.2f (Mode: %s)", lots, EnumToString(InpLotSizeMode));

//    return lots;
//   }

//+------------------------------------------------------------------+
//| CalculateLotSize (Updated for Explicit Entry Price)             |
//+------------------------------------------------------------------+
double CalculateLotSize(double price_for_calc, double priceSL) // price_for_calc is pending or market price
  {
     // Keep the same logic as v1.60, just make sure 'priceEntry' uses price_for_calc
     // ...
   double lots = 0.0;
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
             if(InpStopCalcMode == CALC_MODE_OFF || priceSL == 0 || MathAbs(price_for_calc - priceSL) < point*SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL))
                 { Print("..."); lots = min_lot; break;}
             double risk_amount = balance * (InpRiskPercentBalance / 100.0);
             double sl_points = MathAbs(price_for_calc - priceSL) / point;
             double tick_val = symbolInfo.TickValue();
             lots = (sl_points > 0 && tick_val > 0) ? risk_amount / (sl_points * tick_val) : min_lot;
          } break;
       case VOLUME_MONEY:
           {
              if(InpStopCalcMode == CALC_MODE_OFF || priceSL == 0 || MathAbs(price_for_calc - priceSL) < point*SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL))
                  { Print("..."); lots = min_lot; break;}
              double sl_points = MathAbs(price_for_calc - priceSL) / point;
              double tick_val = symbolInfo.TickValue();
              lots = (sl_points > 0 && tick_val > 0) ? InpRiskMoney / (sl_points * tick_val) : min_lot;
           } break;
     }
     
    // Normalize and Clamp (using helper)
     lots = NormalizeAndClampLots(lots); // Call helper function

    return lots;
  }


//+------------------------------------------------------------------+
//| Calculate SL and TP price levels                                |
//| Modifies sl_price and tp_price by reference                       |
//+------------------------------------------------------------------+
// void CalculateSLTPPrices(double stop_order_price, double range_high, double range_low, bool is_buy_order, double &sl_price, double &tp_price)
//   {
//    double point = symbolInfo.Point();
//    double digits = (double)symbolInfo.Digits(); // Use symbol digits for normalization
//    double range_size_points = 0;
//    if(range_high > range_low)
//       range_size_points = MathRound((range_high - range_low) / point);
//    else
//      {
//       if(InpStopCalcMode == CALC_MODE_FACTOR || InpTargetCalcMode == CALC_MODE_FACTOR)
//         {
//          if(InpDebugMode)
//             Print("Warning: Cannot calculate SL/TP Factor - Invalid Range.");
//          // If modes rely on range factor, must disable or handle error
//          sl_price = 0;
//          tp_price = 0;
//          return;
//         }
//      }

//    sl_price = 0; // Default to no SL
//    tp_price = 0; // Default to no TP

// //--- Calculate Stop Loss Price ---
//    switch(InpStopCalcMode)
//      {
//       case CALC_MODE_OFF:
//          sl_price = 0; // Explicitly no SL
//          break;
//       case CALC_MODE_FACTOR:
//         {
//          double sl_factor_points = range_size_points * InpStopValue;
//          if(is_buy_order)
//             sl_price = (InpStopValue == 1.0) ? range_low : stop_order_price - sl_factor_points * point;
//          else // Sell Order
//             sl_price = (InpStopValue == 1.0) ? range_high : stop_order_price + sl_factor_points * point;
//         }
//       break;
//       case CALC_MODE_PERCENT:
//         {
//          double sl_percent_diff = stop_order_price * (InpStopValue / 100.0);
//          if(is_buy_order)
//             sl_price = stop_order_price - sl_percent_diff;
//          else // Sell Order
//             sl_price = stop_order_price + sl_percent_diff;
//         }
//       break;
//       case CALC_MODE_POINTS:
//          if(is_buy_order)
//             sl_price = stop_order_price - InpStopValue * point;
//          else // Sell Order
//             sl_price = stop_order_price + InpStopValue * point;
//          break;
//      }

// //--- Calculate Take Profit Price ---
//    switch(InpTargetCalcMode)
//      {
//       case CALC_MODE_OFF:
//          tp_price = 0; // Explicitly no TP
//          break;
//       case CALC_MODE_FACTOR:
//         {
//          double tp_factor_points = range_size_points * InpTargetValue;
//          if(is_buy_order)
//             tp_price = stop_order_price + tp_factor_points * point;
//          else // Sell Order
//             tp_price = stop_order_price - tp_factor_points * point;
//         }
//       break;
//       case CALC_MODE_PERCENT:
//         {
//          double tp_percent_diff = stop_order_price * (InpTargetValue / 100.0);
//          if(is_buy_order)
//             tp_price = stop_order_price + tp_percent_diff;
//          else // Sell Order
//             tp_price = stop_order_price - tp_percent_diff;
//         }
//       break;
//       case CALC_MODE_POINTS:
//          if(is_buy_order)
//             tp_price = stop_order_price + InpTargetValue * point;
//          else // Sell Order
//             tp_price = stop_order_price - InpTargetValue * point;
//          break;
//      }

// //--- Normalize prices (important!)
//    if(sl_price != 0)
//       sl_price = NormalizeDouble(sl_price, (int)digits);
//    if(tp_price != 0)
//       tp_price = NormalizeDouble(tp_price, (int)digits);

// //--- Ensure SL/TP levels are valid relative to current price and stops level
// // Basic check, more robust needed for production
//    double stops_level_points = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
//    double min_distance = stops_level_points * point;
//    double current_ask = symbolInfo.Ask();
//    double current_bid = symbolInfo.Bid();

//    if(sl_price != 0)
//      {
//       if(is_buy_order && stop_order_price - sl_price < min_distance)
//         {
//          if(InpDebugMode)
//             Print("Buy SL adjusted due to stops level.");
//          sl_price = NormalizeDouble(stop_order_price - min_distance - point, (int)digits);
//         }
//       else
//          if(!is_buy_order && sl_price - stop_order_price < min_distance)
//            {
//             if(InpDebugMode)
//                Print("Sell SL adjusted due to stops level.");
//             sl_price = NormalizeDouble(stop_order_price + min_distance + point, (int)digits);
//            }
//      }
//    if(tp_price != 0)
//      {
//       if(is_buy_order && tp_price - stop_order_price < min_distance)
//         {
//          if(InpDebugMode)
//             Print("Buy TP adjusted due to stops level.");
//          tp_price = NormalizeDouble(stop_order_price + min_distance + point, (int)digits);
//         }
//       else
//          if(!is_buy_order && stop_order_price - tp_price < min_distance)
//            {
//             if(InpDebugMode)
//                Print("Sell TP adjusted due to stops level.");
//             tp_price = NormalizeDouble(stop_order_price - min_distance - point, (int)digits);
//            }
//      }

//   }
//+------------------------------------------------------------------+
//| Calculate SL/TP (Updated for Explicit Entry Price)               |
//+------------------------------------------------------------------+
void CalculateSLTPPrices(double entry_price_for_calc, double range_high, double range_low, bool is_buy_order, double &sl_price, double &tp_price)
 {
    // --- Logic largely same as v1.60, BUT ensure PERCENT calcs use entry_price_for_calc ---
     // --- FACTOR calcs still use range_high/range_low for range size ---
      // --- POINT calcs use entry_price_for_calc ---

     // Example Snippet Update (Factor Mode remains same using range size, Percent/Points adapt)
     // ... (point, digits, range_size_points calculation) ...

    // Calculate SL
     switch(InpStopCalcMode)
     {
          // case CALC_MODE_FACTOR: remains mostly same logic as v1.60 using range_size_points / range boundaries...
          case CALC_MODE_PERCENT:
            {
                double sl_diff = entry_price_for_calc * (InpStopValue / 100.0); // Use passed entry price
                sl_price = is_buy_order ? entry_price_for_calc - sl_diff : entry_price_for_calc + sl_diff;
            } break;
          case CALC_MODE_POINTS:
               sl_price = is_buy_order ? entry_price_for_calc - InpStopValue * point : entry_price_for_calc + InpStopValue * point;
              break;
          // ... other cases ...
          default: sl_price = 0; break;
     }
     // Calculate TP (similarly adapt Percent/Points to use entry_price_for_calc)
      switch(InpTargetCalcMode)
     {
         // case CALC_MODE_FACTOR: remains mostly same...
         case CALC_MODE_PERCENT:
             {
                 double tp_diff = entry_price_for_calc * (InpTargetValue / 100.0); // Use passed entry price
                 tp_price = is_buy_order ? entry_price_for_calc + tp_diff : entry_price_for_calc - tp_diff;
             } break;
         case CALC_MODE_POINTS:
               tp_price = is_buy_order ? entry_price_for_calc + InpTargetValue * point : entry_price_for_calc - InpTargetValue * point;
               break;
         // ... other cases ...
         default: tp_price = 0; break;
     }

    // ... (Normalize and Validate against stops level - keep this logic) ...
 }

//+------------------------------------------------------------------+
//| Manages open positions (TSL, BE)                               |
//+------------------------------------------------------------------+
void ManageOpenPositions()
  {
   if(InpTSLCalcMode == TSL_MODE_OFF && InpBEStepCalcMode == TSL_MODE_OFF)
      return; // Nothing to manage if both are off

   int total_positions = PositionsTotal();
   for(int i = total_positions - 1; i >= 0; i--) // Loop backwards when modifying
     {
      if(position.SelectByIndex(i)) // Select position by index
        {
         if(position.Magic() == InpMagicNumber && position.Symbol() == _Symbol)
           {
            ApplyBreakEven(position.Ticket(), position.PriceOpen(), position.StopLoss(), (ENUM_POSITION_TYPE)position.PositionType());
            // Apply TSL *after* BE, BE takes precedence if conditions overlap initially
            ApplyTrailingStop(position.Ticket(), position.PriceOpen(), position.StopLoss(), (ENUM_POSITION_TYPE)position.PositionType());
           }
        }
      else
        {
         Print("Error selecting position #", i);
        }
     }
  }
//+------------------------------------------------------------------+
//| Apply Trailing Stop Logic                                       |
//+------------------------------------------------------------------+
void ApplyTrailingStop(ulong ticket, double open_price, double current_sl, ENUM_POSITION_TYPE type)
  {
   if(InpTSLCalcMode == TSL_MODE_OFF)
      return;

   symbolInfo.RefreshRates(); // Get latest prices
   double point = symbolInfo.Point();
   int digits = (int)symbolInfo.Digits();
   double current_bid = symbolInfo.Bid();
   double current_ask = symbolInfo.Ask();
   double tsl_trigger_dist_points = 0;
   double tsl_dist_points = 0;
   double tsl_step_points = 0;
   bool need_modify = false;
   double new_sl = current_sl; // Start with current SL

// Calculate trigger, distance, and step in POINTS
   if(InpTSLCalcMode == TSL_MODE_PERCENT)
     {
      tsl_trigger_dist_points = MathRound(open_price * (InpTSLTriggerValue / 100.0) / point);
      tsl_dist_points = MathRound(open_price * (InpTSLValue / 100.0) / point);
      tsl_step_points = MathRound(open_price * (InpTSLStepValue / 100.0) / point);
     }
   else // TSL_MODE_POINTS
     {
      tsl_trigger_dist_points = InpTSLTriggerValue;
      tsl_dist_points = InpTSLValue;
      tsl_step_points = InpTSLStepValue;
     }

// Don't trail if trigger or distance is zero
   if(tsl_trigger_dist_points <= 0 || tsl_dist_points <=0)
      return;

   if(type == POSITION_TYPE_BUY)
     {
      // Check if trigger level is reached
      if(current_ask > open_price + tsl_trigger_dist_points * point)
        {
         double potential_new_sl = current_ask - tsl_dist_points * point;
         // Modify only if new SL is better than current SL and move is >= step
         if(potential_new_sl > current_sl + tsl_step_points * point || current_sl <= open_price)  // Trail if SL below or at entry
           {
            new_sl = potential_new_sl;
            need_modify = true;
           }
        }
     }
   else // POSITION_TYPE_SELL
     {
      // Check if trigger level is reached
      if(current_bid < open_price - tsl_trigger_dist_points * point)
        {
         double potential_new_sl = current_bid + tsl_dist_points * point;
         // Modify only if new SL is better than current SL and move is >= step
         if(potential_new_sl < current_sl - tsl_step_points * point || current_sl >= open_price)  // Trail if SL above or at entry
           {
            new_sl = potential_new_sl;
            need_modify = true;
           }
        }
     }

// Modify the position if needed
   if(need_modify)
     {
      double current_tp = position.TakeProfit(); // Keep original TP
      double sl_norm = NormalizeDouble(new_sl, digits);
      double tp_norm = NormalizeDouble(current_tp, digits); // Normalize TP too

      // Add check against stops level for modification
      double stops_level_dist = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
      bool sl_valid = false;
      if(type == POSITION_TYPE_BUY)
         sl_valid = (current_ask - sl_norm > stops_level_dist);
      else
         sl_valid = (sl_norm - current_bid > stops_level_dist);

      if(sl_valid)
        {
         if(trade.PositionModify(ticket, sl_norm, tp_norm))
           {
            if(InpDebugMode)
               PrintFormat("Trailing Stop updated for ticket %d: New SL = %.*f", ticket, digits, sl_norm);
           }
         else
           {
            PrintFormat("Error modifying Trailing Stop for ticket %d: %d - %s", ticket, trade.ResultRetcode(), trade.ResultRetcodeDescription());
           }
        }
      else
         if(InpDebugMode)
           {
            PrintFormat("Skipping Trailing Stop modification for ticket %d: New SL %.*f too close to market.", ticket, digits, sl_norm);
           }

     }
  }
//+------------------------------------------------------------------+
//| Apply Break Even Logic                                          |
//+------------------------------------------------------------------+
void ApplyBreakEven(ulong ticket, double open_price, double current_sl, ENUM_POSITION_TYPE type)
  {
   if(InpBEStepCalcMode == TSL_MODE_OFF)
      return;

// Check if BE was already activated for this ticket
   if(IsBeActivated(ticket))
      return;

   symbolInfo.RefreshRates(); // Get latest prices
   double point = symbolInfo.Point();
   int digits = (int)symbolInfo.Digits();
   double current_bid = symbolInfo.Bid();
   double current_ask = symbolInfo.Ask();
   double be_trigger_dist_points = 0;
   double be_buffer_dist_points = 0;
   bool   trigger_met = false;
   double new_be_sl = 0;

// Calculate trigger and buffer in POINTS
   if(InpBEStepCalcMode == TSL_MODE_PERCENT)
     {
      be_trigger_dist_points = MathRound(open_price * (InpBETriggerValue / 100.0) / point);
      be_buffer_dist_points = MathRound(open_price * (InpBEBufferValue / 100.0) / point);
     }
   else // TSL_MODE_POINTS
     {
      be_trigger_dist_points = InpBETriggerValue;
      be_buffer_dist_points = InpBEBufferValue;
     }

// Don't activate BE if trigger is zero or negative
   if(be_trigger_dist_points <= 0)
      return;

   if(type == POSITION_TYPE_BUY)
     {
      // Check trigger
      if(current_ask > open_price + be_trigger_dist_points * point)
        {
         trigger_met = true;
         new_be_sl = open_price + be_buffer_dist_points * point; // Target SL slightly above entry
        }
     }
   else // POSITION_TYPE_SELL
     {
      // Check trigger
      if(current_bid < open_price - be_trigger_dist_points * point)
        {
         trigger_met = true;
         new_be_sl = open_price - be_buffer_dist_points * point; // Target SL slightly below entry
        }
     }

// Apply modification if triggered and new SL is better than current
   if(trigger_met)
     {
      // Only modify if the new break-even SL is actually better than the current SL
      bool is_better = (type == POSITION_TYPE_BUY) ? (new_be_sl > current_sl) : (new_be_sl < current_sl);

      if(is_better)
        {
         double current_tp = position.TakeProfit(); // Keep original TP
         double sl_norm = NormalizeDouble(new_be_sl, digits);
         double tp_norm = NormalizeDouble(current_tp, digits);

         // Check stops level
         double stops_level_dist = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
         bool sl_valid = false;
         if(type == POSITION_TYPE_BUY)
            sl_valid = (current_ask - sl_norm > stops_level_dist);
         else
            sl_valid = (sl_norm - current_bid > stops_level_dist);

         if(sl_valid)
           {
            if(trade.PositionModify(ticket, sl_norm, tp_norm))
              {
               if(InpDebugMode)
                  PrintFormat("Break Even Stop activated for ticket %d: New SL = %.*f", ticket, digits, sl_norm);
               MarkBeActivated(ticket); // Mark as done for this ticket
              }
            else
              {
               PrintFormat("Error modifying Break Even Stop for ticket %d: %d - %s", ticket, trade.ResultRetcode(), trade.ResultRetcodeDescription());
              }
           }
         else
            if(InpDebugMode)
              {
               PrintFormat("Skipping Break Even Stop modification for ticket %d: New SL %.*f too close to market.", ticket, digits, sl_norm);
              }

        }
     }
  }
//+------------------------------------------------------------------+
//| Helper functions for Break Even tracking                       |
//+------------------------------------------------------------------+
bool IsBeActivated(ulong ticket)
  {
   for(int i = 0; i < g_be_ticket_count; i++)
     {
      if(g_be_activated_tickets[i] == ticket)
         return true;
     }
   return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void MarkBeActivated(ulong ticket)
  {
   if(!IsBeActivated(ticket)) // Add only if not already present
     {
      // Resize array if needed (simple dynamic growth)
      if((uint)g_be_ticket_count >= ArraySize(g_be_activated_tickets))
         ArrayResize(g_be_activated_tickets, g_be_ticket_count + 10);

      g_be_activated_tickets[g_be_ticket_count] = ticket;
      g_be_ticket_count++;
      if(InpDebugMode)
         Print("Ticket ", ticket, " marked for Break Even.");
     }
  }

//+------------------------------------------------------------------+
//| Delete all pending orders for this EA instance                  |
//+------------------------------------------------------------------+
void DeletePendingOrdersByMagic()
  {
   int orders = OrdersTotal();
   int deleted_count = 0;
   for(int i = orders - 1; i >= 0; i--) // Loop backwards
     {
      ulong order_ticket = OrderGetTicket(i);
      if(order_ticket > 0) // Check if ticket is valid
        {
         if(OrderGetInteger(ORDER_MAGIC) == InpMagicNumber && OrderGetString(ORDER_SYMBOL) == _Symbol)
           {
            // Check if it's a pending order type we manage
            ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if(type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP)
              {
               if(trade.OrderDelete(order_ticket))
                 {
                  deleted_count++;
                 }
               else
                 {
                  PrintFormat("Error deleting pending order ticket %d: %d - %s", order_ticket, trade.ResultRetcode(), trade.ResultRetcodeDescription());
                 }
              }
           }
        }
     }
   if(deleted_count > 0 && InpDebugMode)
      Print("Deleted ", deleted_count, " pending orders at Delete Time.");
  }
//+------------------------------------------------------------------+
//| Close all open positions for this EA instance                   |
//+------------------------------------------------------------------+
void CloseOpenPositionsByMagic()
  {
   int closed_count = 0;
   int total_positions = PositionsTotal();
   for(int i = total_positions - 1; i >= 0; i--)
     {
      if(position.SelectByIndex(i))
        {
         if(position.Magic() == InpMagicNumber && position.Symbol() == _Symbol)
           {
            if(trade.PositionClose(position.Ticket()))
              {
               closed_count++;
               if(InpDebugMode)
                  Print("Closed position ticket ", position.Ticket(), " at Close Time.");
              }
            else
              {
               PrintFormat("Error closing position ticket %d at Close Time: %d - %s", position.Ticket(), trade.ResultRetcode(), trade.ResultRetcodeDescription());
              }
           }
        }
     }
   if(closed_count > 0 && InpDebugMode)
      Print("Closed ", closed_count, " positions at Close Time.");

  }
//+------------------------------------------------------------------+
//| Get count of current open trades for this EA by type            |
//+------------------------------------------------------------------+
int GetCurrentTradeCount(ENUM_POSITION_TYPE direction = WRONG_VALUE) // WRONG_VALUE = count all
  {
   int count = 0;
   int total_positions = PositionsTotal();
   for(int i=0; i< total_positions; i++)
     {
      if(position.SelectByIndex(i))
        {
         if(position.Symbol() == _Symbol && position.Magic() == InpMagicNumber)
           {
            if(direction == WRONG_VALUE || position.PositionType() == direction)
              {
               count++;
              }
           }
        }
     }
   return count;
  }
//+------------------------------------------------------------------+
//| Update chart visual objects                                    |
//+------------------------------------------------------------------+
// void UpdateChartObjects(double buy_price=0, double sell_price=0, bool buy_ok=false, bool sell_ok=false)
//   {
// // Added Debug Print:
// //  if(InpDebugMode)
// //    {
// //     PrintFormat("UpdateChartObjects called. Range H: %f, L: %f", g_range_high_today, g_range_low_today);
// //    }

//    if(g_range_high_today <= 0 || g_range_low_today >= DBL_MAX)
//      {
//       if(InpDebugMode)
//          Print("UpdateChartObjects: Exiting due to invalid range.");
//       return; // Don't draw invalid range
//      }

//    datetime range_start = GetDateTimeToday(InpRangeStartHour, InpRangeStartMinute);
//    datetime range_end = GetDateTimeToday(InpRangeEndHour, InpRangeEndMinute);
// // Handle overnight
//    if(range_end < range_start)
//       range_end = range_end + PeriodSeconds(PERIOD_D1);

// //--- Update or Create Range Rectangle
//    if(ObjectFind(0,g_range_obj_name)<0)
//      {
//       Print("=======================");
//       Print("CREATE RANGE RECTANGLE");
//       Print("=======================");
//       ObjectCreate(0, g_range_obj_name, OBJ_RECTANGLE, 0, range_start, g_range_high_today, range_end, g_range_low_today);
//       ObjectSetInteger(0, g_range_obj_name, OBJPROP_COLOR, InpRangeColor);
//       ObjectSetInteger(0, g_range_obj_name, OBJPROP_STYLE, STYLE_SOLID);
//       ObjectSetInteger(0, g_range_obj_name, OBJPROP_WIDTH, 3);
//       ObjectSetInteger(0, g_range_obj_name, OBJPROP_BACK, false); // Draw behind candles
//       ObjectSetInteger(0, g_range_obj_name, OBJPROP_SELECTABLE, false);
//       Print("range_start: ", range_start, " range_end: ", range_end);
//       Print("g_range_high_today: ", g_range_high_today, " g_range_low_today: ", g_range_low_today);
//       if(InpDebugMode)
//          Print("Range Rectangle created.");
//      }
//    else
//       if(ObjectFind(0,g_range_obj_name)>=0)
//         {
//          if(InpDebugMode)
//            {


//             Print("=======================");
//             Print("Range Rectangle found.");
//             Print("=======================");
//            }
//          // Only need to update price levels if they change during the window
//          // Use OBJPROP_PRICE with modifier 0 for the first price (high)
//          ObjectSetDouble(0, g_range_obj_name, OBJPROP_PRICE, 0, g_range_high_today);
//          // Use OBJPROP_PRICE with modifier 1 for the second price (low)
//          ObjectSetDouble(0, g_range_obj_name, OBJPROP_PRICE, 1, g_range_low_today);
//          // Time might need updating if range extends beyond initial end time estimate (though less common with fixed times)
//          // Use OBJPROP_TIME with modifier 0 for the first time coordinate
//          ObjectSetInteger(0, g_range_obj_name, OBJPROP_TIME, 0, range_start);

//          // Use OBJPROP_TIME with modifier 1 for the second time coordinate
//          ObjectSetInteger(0, g_range_obj_name, OBJPROP_TIME, 1, range_end); // Use calculated end time
//          Print("g_range_obj_name: ", g_range_obj_name);
//          Print("g_range_high_today: ", g_range_high_today, " g_range_low_today: ", g_range_low_today);
//          Print("range_start: ", range_start, " range_end: ", range_end);
//         }

// //--- Draw pending order lines (if they were placed or intended)
//    datetime future_time = range_end + PeriodSeconds(PERIOD_H1)*2; // Place line somewhat into the future

//    if(buy_price > 0 && buy_ok)    // Only draw if price valid and order potentially placed
//      {
//       if(!ObjectFind(0, g_buy_stop_line_name))
//         {
//          ObjectCreate(0, g_buy_stop_line_name, OBJ_HLINE, 0, range_end, buy_price); // Start line at range end
//          ObjectSetInteger(0, g_buy_stop_line_name, OBJPROP_COLOR, clrLimeGreen);
//          ObjectSetInteger(0, g_buy_stop_line_name, OBJPROP_STYLE, STYLE_DOT);
//          ObjectSetInteger(0, g_buy_stop_line_name, OBJPROP_WIDTH, 1);
//          ObjectSetInteger(0, g_buy_stop_line_name, OBJPROP_SELECTABLE, false);
//          // ObjectSetInteger(0, g_buy_stop_line_name, OBJPROP_TIME2, future_time); // Can extend line
//         }
//       else
//         {
//          // Corrected: Use OBJPROP_PRICE, modifier 0 for HLINE price
//          ObjectSetDouble(0, g_buy_stop_line_name, OBJPROP_PRICE, 0, buy_price);
//          // Corrected: Use OBJPROP_TIME, modifier 0 for HLINE time
//          ObjectSetInteger(0, g_buy_stop_line_name, OBJPROP_TIME, 0, range_end);
//         }
//      }
//    else
//      {
//       ObjectDelete(0, g_buy_stop_line_name); // Delete if not placed
//      }

//    if(sell_price > 0 && sell_ok)    // Only draw if price valid and order potentially placed
//      {
//       if(!ObjectFind(0, g_sell_stop_line_name))
//         {
//          ObjectCreate(0, g_sell_stop_line_name, OBJ_HLINE, 0, range_end, sell_price);
//          ObjectSetInteger(0, g_sell_stop_line_name, OBJPROP_COLOR, clrRed);
//          ObjectSetInteger(0, g_sell_stop_line_name, OBJPROP_STYLE, STYLE_DOT);
//          ObjectSetInteger(0, g_sell_stop_line_name, OBJPROP_WIDTH, 1);
//          ObjectSetInteger(0, g_sell_stop_line_name, OBJPROP_SELECTABLE, false);
//          // ObjectSetInteger(0, g_sell_stop_line_name, OBJPROP_TIME2, future_time);
//         }
//       else
//         {
//          // Corrected: Use OBJPROP_PRICE, modifier 0 for HLINE price
//          ObjectSetDouble(0, g_sell_stop_line_name, OBJPROP_PRICE, 0, sell_price);
//          // Corrected: Use OBJPROP_TIME, modifier 0 for HLINE time
//          ObjectSetInteger(0, g_sell_stop_line_name, OBJPROP_TIME, 0, range_end);
//         }
//      }
//    else
//      {
//       ObjectDelete(0, g_sell_stop_line_name); // Delete if not placed
//      }

//    ChartRedraw();
//   }

//+------------------------------------------------------------------+
//| UpdateChartObjects (COMPLETE for v1.80)                           |
//| Draws Range Rectangle & Mode A Pending Lines conditionally      |
//| Note: Mode B breakout level lines are handled separately         |
//+------------------------------------------------------------------+
void UpdateChartObjects(double buy_pend_price=0, double sell_pend_price=0, bool buy_pend_ok=false, bool sell_pend_ok=false)
  {
   // --- Draw/Update Range Rectangle ---
   // Check if range is valid before attempting to draw/update
   if(g_range_high_today <= 0 || g_range_low_today >= DBL_MAX || g_range_high_today <= g_range_low_today)
    {
       // Optionally delete if it exists from a previous valid state on this tick
       ObjectDelete(0, g_range_obj_name);
       if(InpDebugMode) Print("UpdateChartObjects: Not drawing range - values invalid.");
       // We might still want to draw/delete pending lines below even if range becomes invalid momentarily
    }
   else
    {
       datetime range_start = GetDateTimeToday(InpRangeStartHour, InpRangeStartMinute);
       datetime range_end   = GetDateTimeToday(InpRangeEndHour, InpRangeEndMinute);
       // Handle overnight range for correct time span
       if(range_end < range_start && range_end != 0) range_end = range_end + PeriodSeconds(PERIOD_D1); // Add a day if end time is earlier than start

       if(ObjectFind(0, g_range_obj_name) < 0) // If object doesn't exist, create it
         {
          ResetLastError();
          if(ObjectCreate(0, g_range_obj_name, OBJ_RECTANGLE, 0, range_start, g_range_high_today, range_end, g_range_low_today))
          {
             ObjectSetInteger(0, g_range_obj_name, OBJPROP_COLOR, InpRangeColor);
             ObjectSetInteger(0, g_range_obj_name, OBJPROP_STYLE, STYLE_SOLID);
             ObjectSetInteger(0, g_range_obj_name, OBJPROP_WIDTH, 1); // Default width 1
             ObjectSetInteger(0, g_range_obj_name, OBJPROP_BACK, true); // Draw behind candles
             ObjectSetInteger(0, g_range_obj_name, OBJPROP_SELECTABLE, false);
              if(InpDebugMode) Print("Range Rectangle object created: ", g_range_obj_name);
          }
           else if (InpDebugMode) Print("Error creating Range Rectangle object: ", g_range_obj_name, " Code: ", GetLastError());
         }
       else // If object exists, update its coordinates
         {
            // Update price levels
            ObjectSetDouble(0, g_range_obj_name, OBJPROP_PRICE, 0, g_range_high_today); // Modifier 0 = Price 1
            ObjectSetDouble(0, g_range_obj_name, OBJPROP_PRICE, 1, g_range_low_today);  // Modifier 1 = Price 2
            // Update time levels
            ObjectSetInteger(0, g_range_obj_name, OBJPROP_TIME, 0, range_start); // Modifier 0 = Time 1
            ObjectSetInteger(0, g_range_obj_name, OBJPROP_TIME, 1, range_end);   // Modifier 1 = Time 2
            // Ensure color is correct in case it was changed externally (unlikely but safe)
            ObjectSetInteger(0, g_range_obj_name, OBJPROP_COLOR, InpRangeColor);
         }
    } // End if range is valid

   // --- Draw/Update/Delete Mode A Pending Order Lines ---
   // Use the 'ok' flags passed from PlaceBreakoutOrders to know if placement was successful/attempted
   datetime range_end_time_for_line = GetDateTimeToday(InpRangeEndHour, InpRangeEndMinute); // Anchor lines at range end

   // Buy Stop Line (Mode A)
   if(InpOperationMode == MODE_RANGE_BREAKOUT && buy_pend_price > 0 && buy_pend_ok)
    {
       if(ObjectFind(0, g_buy_stop_line_name) < 0) // Create if not found
       {
          ResetLastError();
          if(ObjectCreate(0, g_buy_stop_line_name, OBJ_HLINE, 0, range_end_time_for_line, buy_pend_price))
           {
             ObjectSetInteger(0, g_buy_stop_line_name, OBJPROP_COLOR, clrLimeGreen); // Buy line color
             ObjectSetInteger(0, g_buy_stop_line_name, OBJPROP_STYLE, STYLE_DOT);
             ObjectSetInteger(0, g_buy_stop_line_name, OBJPROP_WIDTH, 1);
             ObjectSetInteger(0, g_buy_stop_line_name, OBJPROP_SELECTABLE, false);
           }
          else if (InpDebugMode) Print("Error creating Buy Stop line: ", g_buy_stop_line_name, " Code: ", GetLastError());
       }
       else // Update if found
       {
          ObjectSetDouble(0, g_buy_stop_line_name, OBJPROP_PRICE, 0, buy_pend_price); // Modifier 0 = Price 1
          ObjectSetInteger(0, g_buy_stop_line_name, OBJPROP_TIME, 0, range_end_time_for_line); // Modifier 0 = Time 1
          ObjectSetInteger(0, g_buy_stop_line_name, OBJPROP_COLOR, clrLimeGreen); // Ensure color
       }
    }
   else // If not in Mode A, or price/ok is invalid, delete the line
    {
      ObjectDelete(0, g_buy_stop_line_name);
    }

   // Sell Stop Line (Mode A)
   if(InpOperationMode == MODE_RANGE_BREAKOUT && sell_pend_price > 0 && sell_pend_ok)
    {
        if(ObjectFind(0, g_sell_stop_line_name) < 0) // Create if not found
       {
           ResetLastError();
          if(ObjectCreate(0, g_sell_stop_line_name, OBJ_HLINE, 0, range_end_time_for_line, sell_pend_price))
           {
              ObjectSetInteger(0, g_sell_stop_line_name, OBJPROP_COLOR, clrRed); // Sell line color
              ObjectSetInteger(0, g_sell_stop_line_name, OBJPROP_STYLE, STYLE_DOT);
              ObjectSetInteger(0, g_sell_stop_line_name, OBJPROP_WIDTH, 1);
              ObjectSetInteger(0, g_sell_stop_line_name, OBJPROP_SELECTABLE, false);
           }
           else if (InpDebugMode) Print("Error creating Sell Stop line: ", g_sell_stop_line_name, " Code: ", GetLastError());
       }
       else // Update if found
       {
           ObjectSetDouble(0, g_sell_stop_line_name, OBJPROP_PRICE, 0, sell_pend_price); // Modifier 0 = Price 1
           ObjectSetInteger(0, g_sell_stop_line_name, OBJPROP_TIME, 0, range_end_time_for_line); // Modifier 0 = Time 1
            ObjectSetInteger(0, g_sell_stop_line_name, OBJPROP_COLOR, clrRed); // Ensure color
       }
    }
    else // If not in Mode A, or price/ok is invalid, delete the line
    {
        ObjectDelete(0, g_sell_stop_line_name);
    }

    // --- Mode B Breakout Level lines are explicitly handled by DrawOrUpdateBreakoutLevelLine() ---
    // This function focuses only on the Range Rectangle and Mode A pending lines.

   // Request chart redraw to make changes visible
   ChartRedraw();
  }

  //+------------------------------------------------------------------+
//| <<< NEW: Draw or Update Mode B Breakout Level Line >>>          |
//+------------------------------------------------------------------+
void DrawOrUpdateBreakoutLevelLine(double level)
 {
   if(level <= 0 || InpOperationMode != MODE_BREAK_RETEST) return; // Only in Mode B with valid level

   // Use direction to slightly alter name (allows separate lines until one confirmed)
   string line_name = (g_breakout_direction_today >= 0) ? g_break_level_line_name + "_High" : g_break_level_line_name + "_Low";
    if (g_breakout_direction_today != 0) // If break confirmed, use the single final name
        line_name = g_break_level_line_name;


   datetime time_anchor = GetDateTimeToday(InpRangeEndHour, InpRangeEndMinute); // Anchor at range end

    if(ObjectFind(0, line_name) < 0) // Create if not found
    {
        if(ObjectCreate(0, line_name, OBJ_HLINE, 0, time_anchor, level))
        {
           ObjectSetInteger(0, line_name, OBJPROP_COLOR, InpBreakoutLevelColor);
           ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_SOLID); // Make it solid
           ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 2);      // Make it thicker
           ObjectSetInteger(0, line_name, OBJPROP_SELECTABLE, false);
           ObjectSetInteger(0, line_name, OBJPROP_BACK, true);
           // Add label indicating level type only *after* break confirmation
            if(g_breakout_direction_today != 0) ObjectSetString(0, line_name, OBJPROP_TEXT, StringFormat("Broken Lvl (%.*f)",_Digits,level));
        } else {/* Print error */}
    } else {
         ObjectSetDouble(0, line_name, OBJPROP_PRICE, 0, level); // Just update price if needed
         ObjectSetInteger(0, line_name, OBJPROP_TIME, 0, time_anchor); // Update time anchor
         // Update text if breakout direction confirmed later
         if(g_breakout_direction_today != 0 && StringLen(ObjectGetString(0, line_name, OBJPROP_TEXT)) == 0) ObjectSetString(0, line_name, OBJPROP_TEXT, StringFormat("Broken Lvl (%.*f)",_Digits,level));

    }
      ChartRedraw(); // May redraw often, consider moving outside loop if needed
 }

//+------------------------------------------------------------------+
//| Update chart comment display                                     |
//+------------------------------------------------------------------+
// void UpdateChartComment(const MqlDateTime &tm)
//   {
//    string comment_text = StringFormat("--- Range Breakout EA v%.2f (%s, M%d) ---\n",
//                                       "1.0", _Symbol, InpMagicNumber);
//    comment_text += StringFormat("Server Time: %s\n", TimeToString(TimeCurrent(), TIME_SECONDS));
//    comment_text += StringFormat("Range Window: %02d:%02d - %02d:%02d\n",
//                                 InpRangeStartHour, InpRangeStartMinute, InpRangeEndHour, InpRangeEndMinute);

//    if(g_range_high_today > 0 && g_range_low_today < DBL_MAX)
//      {
//       double range_size = g_range_high_today - g_range_low_today;
//       comment_text += StringFormat("Range High: %.*f\n", _Digits, g_range_high_today);
//       comment_text += StringFormat("Range Low:  %.*f\n", _Digits, g_range_low_today);
//       comment_text += StringFormat("Range Size: %.*f (%.0f Points)\n", _Digits, range_size, range_size / symbolInfo.Point());
//      }
//    else
//      {
//       comment_text += "Range: Waiting...\n";
//      }

//    if(g_is_in_range_window)
//       comment_text += "Status: Identifying Range\n";
//    else
//       if(g_pending_orders_placed_today)
//          comment_text += "Status: Pending Orders Placed/Managed\n";
//       else
//          if(IsAfterRangeEnd(tm) && !g_pending_orders_placed_today)  // Check if filtered
//             comment_text += "Status: Range Filtered / No Orders Placed\n";
//          else
//             comment_text += "Status: Waiting for Range Window\n";

//    int buys = GetCurrentTradeCount(POSITION_TYPE_BUY);
//    int sells = GetCurrentTradeCount(POSITION_TYPE_SELL);
//    comment_text += StringFormat("Open Positions: Longs=%d, Shorts=%d, Total=%d\n", buys, sells, buys+sells);

//    Comment(comment_text);
//   }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| UpdateChartComment (COMPLETE - Shows Mode A/B Status)           |
//+------------------------------------------------------------------+
void UpdateChartComment(const MqlDateTime &tm) // Pass tm struct to get current time info if needed
  {
   // Only proceed if the input wants the comment
   if(!InpChartComment)
    {
      Comment(""); // Clear comment if disabled
      return;
    }

   string comment_text = ""; // Initialize empty string

   // --- Header ---
   comment_text += StringFormat("--- Range BKR EA v%s (%s, M%d", // Base Magic
                               MQLInfoString(MQL_PROGRAM_VERSION),
                               _Symbol, InpMagicNumber);
   // Add Mode B magic only if different
   if(InpMagicNumber_ModeB != InpMagicNumber)
       comment_text += StringFormat(" / B:%d", InpMagicNumber_ModeB);
   comment_text += ") ---\n";

   // --- Operation Mode ---
    comment_text += StringFormat("Mode: %s\n", EnumToString(InpOperationMode));

   // --- Time Info ---
   comment_text += StringFormat("Server Time: %s\n", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
   comment_text += StringFormat("Range Window: %02d:%02d - %02d:%02d\n",
                                InpRangeStartHour, InpRangeStartMinute, InpRangeEndHour, InpRangeEndMinute);

   // --- Range Details ---
   if(g_range_high_today > 0 && g_range_low_today < DBL_MAX && g_range_high_today > g_range_low_today) // Ensure valid range
     {
      double range_size = g_range_high_today - g_range_low_today;
      double range_points = MathRound(range_size / symbolInfo.Point()); // Use refreshed point size
      comment_text += StringFormat("Range High: %.*f\n", _Digits, g_range_high_today);
      comment_text += StringFormat("Range Low:  %.*f\n", _Digits, g_range_low_today);
      comment_text += StringFormat("Range Size: %.*f (%.0f Points)\n", _Digits, range_size, range_points);
     }
   else if(g_is_in_range_window) // If still calculating
     {
        comment_text += "Range: Calculating...\n";
        if(g_range_high_today > 0) comment_text += StringFormat("Current H: %.*f\n", _Digits, g_range_high_today);
        if(g_range_low_today < DBL_MAX) comment_text += StringFormat("Current L: %.*f\n", _Digits, g_range_low_today);
     }
   else // If before range starts or range invalid after window
     {
       comment_text += "Range: Waiting / Invalid\n";
     }

   // --- Status Line ---
   string status = "Status: Initializing/Waiting"; // Default fallback
   if(g_is_in_range_window) status = "Status: Identifying Range";
   else if (!g_daily_setup_complete && IsRangePeriodOver(tm)) status = "Status: Setup Pending (Post-Range Window)"; // Corner case
   else if (!g_daily_setup_complete) status = "Status: Waiting for Range End";
   else // Daily Setup is Complete
    {
      // Check Stop Time first
      if (IsTimeToStopNewEntries(tm) && InpOperationMode == MODE_BREAK_RETEST && !g_entered_retest_trade_today)
       {
          status = "Status: Stopped Checking for New Retest Entry";
       }
      // --- Mode Specific Status ---
      else if (InpOperationMode == MODE_RANGE_BREAKOUT)
       {
         // Check if pending orders exist (more accurate status)
         if(CheckIfPendingOrdersExist(InpMagicNumber)) // Function to check for pending orders
           status = "Status: Pending Breakout Orders Active";
         else
           status = "Status: Awaiting Breakout / Orders Managed"; // If no pending, assume triggered or deleted
       }
      else // Mode B Specific Status
       {
         if(g_entered_retest_trade_today) status = "Status: Retest Entry Attempted/Complete for Today";
         else if (g_breakout_direction_today == 0) status = "Status: Waiting for Initial Breakout";
         else if (g_in_retest_zone_flag) // Retest Zone Entered, Waiting for Confirmation
           status = StringFormat("Status: Price in Retest Zone (%.*f)", _Digits, g_breakout_level_today);
         else if (g_breakout_direction_today == 1) // Waiting for Retest to Touch Zone
           status = StringFormat("Status: Waiting for Retest of High (%.*f)", _Digits, g_breakout_level_today);
         else if (g_breakout_direction_today == -1)// Waiting for Retest to Touch Zone
           status = StringFormat("Status: Waiting for Retest of Low (%.*f)", _Digits, g_breakout_level_today);
         else status = "Status: Breakout Confirmed - State Unknown"; // Fallback shouldn't happen
       }
    }
   comment_text += status + "\n";

   // --- Open Positions Count ---
   int buys = GetCurrentTradeCount(POSITION_TYPE_BUY); // Counts both magics
   int sells = GetCurrentTradeCount(POSITION_TYPE_SELL); // Counts both magics
   comment_text += StringFormat("Open Pos: L=%d, S=%d, T=%d (Limit: %d)", buys, sells, buys + sells, InpMaxTotalTrades);


   // --- Set the Chart Comment ---
   Comment(comment_text);
  }

//+------------------------------------------------------------------+
//| Helper to check if pending orders exist for a magic number       |
//+------------------------------------------------------------------+
bool CheckIfPendingOrdersExist(long magic_to_check)
{
    int total_orders = OrdersTotal();
    for(int i=0; i<total_orders; i++)
    {
        ulong ticket = OrderGetTicket(i);
        if(order.Select(ticket))
        {
            if(order.Symbol() == _Symbol && order.Magic() == magic_to_check)
            {
                ENUM_ORDER_TYPE type = order.OrderType();
                if(type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP)
                {
                    return true; // Found at least one pending order
                }
            }
        }
    }
    return false; // No pending orders found for this magic/symbol
}
// --- Helper: Normalize and Clamp Lots ---
double NormalizeAndClampLots(double lots_raw) // Added this helper
{
    double min_lot = symbolInfo.LotsMin();
    double max_lot = symbolInfo.LotsMax();
    double step_lot = symbolInfo.LotsStep();
    double lots_calc = lots_raw;

    // Normalize to step
    if(step_lot > 0) lots_calc = MathRound(lots_calc / step_lot) * step_lot;
    lots_calc = NormalizeDouble(lots_calc, 2); // Standard normalization

    // Clamp between Min and Max
    if(lots_calc < min_lot) lots_calc = min_lot;
    if(lots_calc > max_lot && max_lot > 0) lots_calc = max_lot;

    return lots_calc;
}
//+------------------------------------------------------------------+
// NOTE: Ensure the other functions (IsRangePeriodOver, etc.) are fully implemented.
// NOTE: You need to call `UpdateChartComment(tm)` within the `OnTick` loop.