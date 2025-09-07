//+------------------------------------------------------------------+
//|                                       ForexTrendingFVG_EA_MQ5.mq5 |
//|                                  Copyright 2024, Your Name/Company |
//|                                              https://www.your.url |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Your Name/Company"
#property link      "https://www.your.url"
#property version   "1.01"
#property description "Automates a Forex trending strategy using MAs, FVG entries, and Trailing Stop Loss."
#property strict
/*

This Expert Advisor capitalizes on trending market conditions identified through a dual moving average crossover system, 
further qualified by the momentum indicated by a third moving average's rate of change. When a strong trend is confirmed, 
the EA seeks precise entries by detecting Fair Value Gaps (FVGs) and patiently waiting for price to retrace and retest the 
FVG's boundary within a defined number of bars. Risk is automatically managed via a stop-loss calculated from the FVG's 
size plus a configurable pip buffer (with minimum/maximum caps), while profit targets are determined by applying a user-defined 
risk-to-reward multiplier to that calculated risk. Optional trailing stop loss (Fixed points or ATR-based) with break-even trigger can further manage open positions.

*/
#include <Trade/Trade.mqh> // Include the CTrade library
/*
For a sell trade on a bearish FVG, the following conditions must be met:

1. A valid bearish FVG must be identified first:
   - The high of Candle 3 must be below the low of Candle 1 (candle3_high < candle1_low)
   - The FVG must be large enough (size > InpFVG_Min_Size_Points)

2. Trading filters must allow selling:
   - If MA Direction Filter is enabled: MA1 must be below MA2 (ma1_prev < ma2_prev)
   - If MA3 Trend Filter is enabled: MA3 percent change must be below the threshold (ma3_percent_change < InpMA3_PercentChange_Sell_Threshold)
   - Spread must be within limits
   - Trading must be allowed by time filters (if enabled)

3. A valid FVG retest must occur:
   - Price must touch or spike above the FVG Low (which is Candle 3's high)
   - This retest must happen within the specified number of bars (InpFVG_Retest_Bars)
   - The price must not have invalidated the FVG by closing fully inside/above it

4. Risk parameters must be acceptable:
   - The calculated stop loss cannot exceed maximum allowed (unless cap is allowed)
   - The entry must be at market price (SYMBOL_BID for sell trades)

These conditions ensure that the sell trade is taken only when price has rejected from a bearish fair value gap, aligned with the overall market trend, and within acceptable risk parameters.

*/
//--- Input Parameters ---

// MA Settings
//input group           "Moving Average Settings"
 ENUM_MA_METHOD  InpMA1_Method = MODE_SMA;       // MA1 Method (Simple or Exponential)
 int             InpMA1_Period = 50;           // Number of bars to average for MA1
 bool            InpMA1_Show = true;           // Show MA1 on the screen
 color           InpMA1_Color = clrBlue;       // MA1 Color
 ENUM_MA_METHOD  InpMA2_Method = MODE_SMA;       // MA2 Method (Simple or Exponential)
 int             InpMA2_Period = 20;           // Number of bars to average for MA2
 bool            InpMA2_Show = true;           // Show MA2 on the screen
 color           InpMA2_Color = clrRed;        // MA2 Color
 ENUM_MA_METHOD  InpMA3_Method = MODE_SMA;       // MA3 Method (Simple or Exponential)
 int             InpMA3_Period = 10;           // Number of bars to average for MA3
 bool            InpMA3_Show = true;           // Show MA3 on the screen
 color           InpMA3_Color = clrGreen;      // MA3 Color

// MA Trend Filters
//input group           "MA Trend Filters"
 bool            InpEnable_MA_Direction_Filter = false; // Enable MA1/MA2 Direction Filter?
// Description: If true: MA1 > MA2 = Buys Only, MA1 < MA2 = Sells Only.
 bool            InpEnable_MA3_Trend_Filter = false;    // Enable MA3 Percent Change Filter?
 double          InpMA3_PercentChange_Buy_Threshold = 1.0; // If Percent Change > this, allow Buys
 double          InpMA3_PercentChange_Sell_Threshold = -1.0;// If Percent Change < this, allow Sells (negative value)
 bool            InpShow_Percent_Change = false;      // Show Percent Change on the screen (Chart Comment)

// Fair Value Gap (FVG) Settings
input group           "Fair Value Gap (FVG) Settings"
input bool            InpShow_FVGs = true;                // Show FVGs on the screen
input bool            InpShow_FVG_Debug = true;          // Show detailed FVG debug info when trade triggered
input bool            InpFill_FVGs = true;                // Fill FVG rectangles (false = outline only)
input int             InpFVG_Min_Size_Points = 50;        // Minimum FVG size in points (0 = no minimum)
input int             InpFVG_Retest_Bars = 5;             // Price must retouch FVG within X bars
 color           InpFVG_Bullish_Color = clrDarkGreen;  // Bullish FVG Color
 color           InpFVG_Bearish_Color = clrDarkRed;    // Bearish FVG Color
 input bool            InpFVG_Skip_First_Retest_Bar = false; // Skip the first bar immediately after FVG formation for retest check?
 int             InpMax_FVGs_To_Draw = 10;           // Max number of recent FVGs to display

// Trade Entry Settings
input group           "Trade Entry Settings"
input double          InpLots = 0.1;                     // The number of lots to trade
input double          InpMax_Spread_Pips = 0;           // Only open if spread <= this (pips). 0 to disable.
input int             InpMax_Slippage_Points = 3;         // Maximum allowed slippage in Points
// Time Filters (Broker Time)
input bool            InpEnable_Time_Filter1 = false;     // Enable Time Filter 1?
input string          InpTime_Filter1_Start = "08:00";    // Time Filter 1 Start (HH:MM)
input string          InpTime_Filter1_End = "11:00";      // Time Filter 1 End (HH:MM)
input bool            InpEnable_Time_Filter2 = false;     // Enable Time Filter 2?
input string          InpTime_Filter2_Start = "14:00";    // Time Filter 2 Start (HH:MM)
input string          InpTime_Filter2_End = "17:00";      // Time Filter 2 End (HH:MM)
input bool            InpEnable_Time_Filter3 = false;     // Enable Time Filter 3?
input string          InpTime_Filter3_Start = "20:00";    // Time Filter 3 Start (HH:MM)
input string          InpTime_Filter3_End = "23:00";      // Time Filter 3 End (HH:MM)

// Trade Closing Settings (Simulated SL/TP)
input group           "Trade Closing Settings"
input double          InpSL_Extra_Pips = 1.0;             // Pips to add to FVG size for Stop Loss
input double          InpMin_StopLoss_Pips = 3.0;         // Minimum Risk (Stop Loss) in Pips
input double          InpMax_StopLoss_Pips = 15.0;        // Maximum Risk (Stop Loss) in Pips
input bool            InpAbort_If_SL_Exceeds_Max = false;  // Abort trade if calculated SL > Max SL Pips? (False = Cap SL at Max)
input double          InpRisk_Reward_Ratio = 1.5;         // Close trade at X times the Risk (Final SL Pips)
//input bool            InpEnable_Move_SL_To_BE = true;     // Move SL to BreakEven at 1/2 TP? <-- REMOVED
// Alternate Closing Conditions (Optional)
input bool            InpEnable_Fixed_TP = false;         // Enable Fixed Take Profit?
input double          InpFixed_TP_Pips = 20.0;            // Close trade when in profit X pips
input bool            InpEnable_Fixed_SL = false;         // Enable Fixed Stop Loss?
input double          InpFixed_SL_Pips = 10.0;            // Close trade when in loss X pips

// Trailing Stop Loss Settings <-- NEW GROUP
input group           "Trailing Stop Loss Settings"
enum ENUM_TRAILING_METHOD {
    TRAILING_METHOD_ATR    = 0, // Trail using ATR
    TRAILING_METHOD_POINTS = 1  // Trail using Fixed Points
};
input bool            InpEnable_Trailing_SL = true;      // Enable Trailing Stop Loss?
input ENUM_TRAILING_METHOD InpTrailing_Method = TRAILING_METHOD_ATR; // Trailing Method (ATR or Fixed Points)
input group           "--breakeven--"
input int             InpBE_Trigger_Points = 0;         // Move SL to BreakEven after Profit reaches X points (0 = disable BE trigger)
input int             InpBE_Extra_Points = 1;             // Add points to Entry Price for BreakEven SL (e.g., 1 point above/below entry)
input group           "--atr--"
input ENUM_TIMEFRAMES InpTrailing_ATR_Timeframe = PERIOD_CURRENT; // Timeframe for ATR Calculation
input int             InpTrailing_ATR_Period = 14;        // ATR Period
input double          InpTrailing_ATR_Multiplier = 3;   // ATR Multiplier for trailing distance
input group           "--fixed trailing--"
input int             InpTrailing_Fixed_Points = 200;     // Fixed Trailing distance in Points



// Account Protection
//input group           "Account Protection"
 bool            InpEnable_Account_Protection = true;// Enable Account Balance Protection?
 double          InpMin_Account_Balance = 0.0;       // If balance drops below this, close all & stop EA (0 = disable)
 ulong           InpMagicNumber = 198404;            // EA Magic Number

//--- Global Variables ---
CTrade        trade;                     // Trading object
int           ma1_handle = INVALID_HANDLE;
int           ma2_handle = INVALID_HANDLE;
int           ma3_handle = INVALID_HANDLE;
int           atr_handle = INVALID_HANDLE; // <-- NEW: ATR Handle
double        ma3_percent_change = 0.0;
string        ea_comment = "ForexTrendingFVG"; // Comment for Orders
double        pip_value;                   // Size of 1 pip (e.g., 0.0001 or 0.01)
int           digits_pips;               // Number of decimal places for pips (e.g., 4 or 2)
bool          stop_trading = false;        // Flag to stop trading if account balance drops
datetime      tf1_start_sec, tf1_end_sec;
datetime      tf2_start_sec, tf2_end_sec;
datetime      tf3_start_sec, tf3_end_sec;

// FVG Structure
struct FVGInfo
  {
   int       bar_index;     // Bar index where the FVG was formed (candle 3)
   double    high;          // Top of the FVG
   double    low;           // Bottom of the FVG
   bool      is_bullish;    // True if bullish, false if bearish
   bool      is_valid;      // Still valid for trading (not invalidated by price action)
   datetime  time_formed;   // Time of the bar when FVG formed
   string    object_name;   // Chart object name
  };

// Active Trade Info
struct ActiveTradeInfo
  {
   ulong     ticket;
   double    entry_price;
   double    stop_loss_price;   // Current SL price (can be trailed)
   double    take_profit_price; // Calculated TP based on R:R (initial target)
   double    stop_loss_pips;    // The initial SL distance in pips used for this trade
   datetime  entry_time;
   bool      is_buy;
   bool      be_triggered;      // <-- NEW: Has BreakEven been triggered?
   // FVG details relevant to the trade
   double    fvg_high;
   double    fvg_low;
   // Fixed TP/SL prices (if enabled)
   double    fixed_tp_price;
   double    fixed_sl_price;
  };
ActiveTradeInfo current_trade; // Stores info about the currently open trade

// --- Trade Limiting Flags ---
bool          buy_trade_taken_tf1 = false;
bool          sell_trade_taken_tf1 = false;
bool          buy_trade_taken_tf2 = false;
bool          sell_trade_taken_tf2 = false;
bool          buy_trade_taken_tf3 = false;
bool          sell_trade_taken_tf3 = false;
bool          buy_trade_taken_general = false; // For when no time filters are active
bool          sell_trade_taken_general = false; // For when no time filters are active
int           last_reset_day = 0; // Stores DayOfYear of last flag reset

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Initialize trade object
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetMarginMode(); // Use account's default margin mode
   trade.SetTypeFillingBySymbol(_Symbol);     // Use symbol's default filling mode
   trade.SetDeviationInPoints(InpMax_Slippage_Points); // Set slippage
   TesterHideIndicators(true);

//--- Calculate Pip Value and Digits
   pip_value = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 3 || SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 5)
     {
      pip_value *= 10;
      digits_pips = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) - 1;
     }
   else
     {
      digits_pips = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
     }
   if(pip_value == 0) // Safety check
     {
      Print("Error: Could not determine Pip value for ", _Symbol);
      return(INIT_FAILED);
     }

//--- Initialize Moving Averages
   // MA1
   ma1_handle = iMA(_Symbol, _Period, InpMA1_Period, 0, InpMA1_Method, PRICE_CLOSE);
   if(ma1_handle == INVALID_HANDLE)
     {
      Print("Error creating MA1 indicator - ", GetLastError());
      return(INIT_FAILED);
     }
 

   // MA2
   ma2_handle = iMA(_Symbol, _Period, InpMA2_Period, 0, InpMA2_Method, PRICE_CLOSE);
   if(ma2_handle == INVALID_HANDLE)
     {
      Print("Error creating MA2 indicator - ", GetLastError());
      return(INIT_FAILED);
     }
 
   // MA3
   ma3_handle = iMA(_Symbol, _Period, InpMA3_Period, 0, InpMA3_Method, PRICE_CLOSE);
   if(ma3_handle == INVALID_HANDLE)
     {
      Print("Error creating MA3 indicator - ", GetLastError());
      return(INIT_FAILED);
     }
 
//--- Initialize ATR Indicator (if trailing enabled and ATR method selected) <-- NEW
   if(InpEnable_Trailing_SL && InpTrailing_Method == TRAILING_METHOD_ATR)
     {
      // Use specified timeframe or current if PERIOD_CURRENT
      ENUM_TIMEFRAMES atr_tf = (InpTrailing_ATR_Timeframe == PERIOD_CURRENT) ? _Period : InpTrailing_ATR_Timeframe;
      atr_handle = iATR(_Symbol, atr_tf, InpTrailing_ATR_Period);
      if(atr_handle == INVALID_HANDLE)
        {
         Print("Error creating ATR indicator (TF: ", EnumToString(atr_tf), ", Period: ", InpTrailing_ATR_Period, ") - ", GetLastError());
         // Decide if this is fatal. Maybe allow running without ATR trailing? For now, fail init.
         return(INIT_FAILED);
        }
      Print("ATR Indicator Initialized for Trailing SL (TF: ", EnumToString(atr_tf), ", Period: ", InpTrailing_ATR_Period, ")");
     }


//--- Validate and Convert Time Filter Inputs
   tf1_start_sec = StringToTime(InpTime_Filter1_Start);
   tf1_end_sec = StringToTime(InpTime_Filter1_End);
   tf2_start_sec = StringToTime(InpTime_Filter2_Start);
   tf2_end_sec = StringToTime(InpTime_Filter2_End);
   tf3_start_sec = StringToTime(InpTime_Filter3_Start);
   tf3_end_sec = StringToTime(InpTime_Filter3_End);

   if((InpEnable_Time_Filter1 && (tf1_start_sec == 0 || tf1_end_sec == 0)) ||
      (InpEnable_Time_Filter2 && (tf2_start_sec == 0 || tf2_end_sec == 0)) ||
      (InpEnable_Time_Filter3 && (tf3_start_sec == 0 || tf3_end_sec == 0)))
     {
      Print("Error: Invalid time format in Time Filter settings (use HH:MM). Disabling EA.");
      return(INIT_FAILED);
     }
   // Adjust end times if they wrap around midnight (e.g., 22:00 - 02:00)
   if(tf1_end_sec <= tf1_start_sec) tf1_end_sec += 86400; // Add seconds in a day
   if(tf2_end_sec <= tf2_start_sec) tf2_end_sec += 86400;
   if(tf3_end_sec <= tf3_start_sec) tf3_end_sec += 86400;

//--- Validate Trailing Stop Inputs <-- NEW
   if(InpEnable_Trailing_SL)
     {
      if(InpBE_Trigger_Points < 0) {
         Print("Error: BreakEven Trigger Points cannot be negative. Disabling EA.");
         return(INIT_FAILED);
      }
      if(InpBE_Extra_Points < 0) {
          Print("Error: BreakEven Extra Points cannot be negative. Disabling EA.");
         return(INIT_FAILED);
      }
       if(InpTrailing_Method == TRAILING_METHOD_ATR) {
           if(InpTrailing_ATR_Period <= 0) {
               Print("Error: Trailing ATR Period must be positive. Disabling EA.");
               return(INIT_FAILED);
           }
           if(InpTrailing_ATR_Multiplier <= 0) {
                Print("Error: Trailing ATR Multiplier must be positive. Disabling EA.");
               return(INIT_FAILED);
           }
       } else { // Fixed Points
            if(InpTrailing_Fixed_Points <= 0) {
                Print("Error: Trailing Fixed Points must be positive. Disabling EA.");
               return(INIT_FAILED);
           }
       }
     }


//--- Initial Account Balance Check
   if(InpEnable_Account_Protection && InpMin_Account_Balance > 0)
     {
      if(AccountInfoDouble(ACCOUNT_BALANCE) < InpMin_Account_Balance)
        {
         Print("Account balance ", AccountInfoDouble(ACCOUNT_BALANCE), " is below threshold ", InpMin_Account_Balance, ". EA stopped.");
         stop_trading = true; // Stop immediately
        }
     }

//--- Initialize active trade info
   ResetActiveTradeInfo();

//--- Initialize Day for Trade Limiting Reset ---
   MqlDateTime current_time_struct;
   TimeCurrent(current_time_struct);
   last_reset_day = current_time_struct.day_of_year;
   Print("Trade Limiting Initialized for Day: ", last_reset_day);
   // Reset flags on init just in case
   ResetTradeLimitFlags();

//--- Cleanup old chart objects from previous runs (optional but good practice)
   ObjectsDeleteAll(0, ea_comment + "_FVG", 0, OBJ_RECTANGLE);

   Print("ForexTrendingFVG_EA_MQ5 Initialized Successfully for ", _Symbol);
   Print("Pip value: ", DoubleToString(pip_value, _Digits), ", Pip Digits: ", digits_pips);
//---
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Release indicator handles
   if(ma1_handle != INVALID_HANDLE) IndicatorRelease(ma1_handle);
   if(ma2_handle != INVALID_HANDLE) IndicatorRelease(ma2_handle);
   if(ma3_handle != INVALID_HANDLE) IndicatorRelease(ma3_handle);
   if(atr_handle != INVALID_HANDLE) IndicatorRelease(atr_handle); // <-- NEW

//--- Remove chart objects created by this EA
   Comment(""); // Clear comment
   ObjectsDeleteAll(0, ea_comment + "_FVG", 0, OBJ_RECTANGLE);

   Print("ForexTrendingFVG_EA_MQ5 Deinitialized. Reason: ", reason);
//---
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- Check if trading is globally stopped
   if(stop_trading)
     {
      // Optionally ensure all positions are closed one last time
      if(PositionSelect(_Symbol))
         {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            {
            Print("Closing position ", PositionGetInteger(POSITION_TICKET), " due to account protection stop.");
            trade.PositionClose(_Symbol);
            ResetActiveTradeInfo();
            }
         }
      Comment("Trading Stopped - Account Balance Below Threshold");
      return;
     }

//--- Account Balance Check (on every tick if enabled)
   if(InpEnable_Account_Protection && InpMin_Account_Balance > 0)
     {
      if(AccountInfoDouble(ACCOUNT_BALANCE) < InpMin_Account_Balance)
        {
         Print("Account balance ", AccountInfoDouble(ACCOUNT_BALANCE), " dropped below threshold ", InpMin_Account_Balance, ". Closing positions and stopping EA.");
         stop_trading = true; // Set flag to stop future actions
         // Close open position managed by this EA
         if(PositionSelect(_Symbol))
            {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
               {
               trade.PositionClose(_Symbol);
               ResetActiveTradeInfo();
               }
            }
         Comment("Trading Stopped - Account Balance Below Threshold");
         return; // Exit OnTick
        }
     }

//--- Daily Reset Check ---
   MqlDateTime current_time_struct_tick;
   TimeCurrent(current_time_struct_tick);
   int current_day_of_year = current_time_struct_tick.day_of_year;
   if(current_day_of_year != last_reset_day)
     {
      Print("New day detected (", current_day_of_year, " vs ", last_reset_day, "). Resetting trade limits.");
      ResetTradeLimitFlags();
      last_reset_day = current_day_of_year; // Update the tracked day
     }
   // ---

//--- Check if new bar has started (optimization)
   static datetime last_bar_time = 0;
   MqlRates rates[1];
   if(CopyRates(_Symbol, _Period, 0, 1, rates) < 1) return; // Not enough data yet
   if(rates[0].time == last_bar_time && current_trade.ticket == 0) // Only check for new trades on new bar if no trade open
     {
      // Still need to manage open trade, update comment etc.
      ManageCurrentTrade();
      UpdateDisplay();
      return;
     }
   last_bar_time = rates[0].time;


//--- Get latest indicator data
   double ma1_values[2];
   double ma2_values[2];
   double ma3_values[3]; // Need 3 for percent change calculation

   if(CopyBuffer(ma1_handle, 0, 0, 2, ma1_values) < 2 ||
      CopyBuffer(ma2_handle, 0, 0, 2, ma2_values) < 2 ||
      CopyBuffer(ma3_handle, 0, 0, 3, ma3_values) < 3)
     {
      Print("Error copying indicator buffers - ", GetLastError());
      return; // Wait for next tick
     }

   // MA values [0] is current forming bar, [1] is last closed bar, [2] is bar before that
   double ma1_current = ma1_values[0];
   double ma1_prev = ma1_values[1];
   double ma2_current = ma2_values[0];
   double ma2_prev = ma2_values[1];
   double ma3_current_x = ma3_values[0]; // Current forming bar value (x)
   double ma3_prev_y = ma3_values[1];    // Previous closed bar value (y)
   double ma3_prev2 = ma3_values[2];   // Bar before previous


//--- Calculate MA3 Percent Change (using closed bar values for stability: y and prev2)
   // Formula: (y - prev2) / y * 10000
   if(ma3_prev_y != 0) // Avoid division by zero
     {
      ma3_percent_change = (ma3_prev_y - ma3_prev2) / ma3_prev_y * 10000.0;
     }
   else
     {
      ma3_percent_change = 0.0;
     }

//--- Update Display (Comment)
   UpdateDisplay();

//--- Manage Existing Trade first
   if(ManageCurrentTrade())
     {
      return; // Trade is open and being managed, maybe closed this tick. No new trades.
     }

//--- Check General Trading Conditions (only if no trade is open) ---

   // Time Filter - Get Active Window (0=None, 1=TF1, 2=TF2, 3=TF3, 4=No Filters)
   int active_window = GetActiveTimeFilterWindow();

   if(active_window == 0)
     { // Trading not allowed by time filters
      // Optional: Print("Trading outside allowed hours.");
       DrawFVGs(3); // Keep drawing FVGs even outside trading hours if enabled
       return;
     }

   // Spread Filter
   if(!IsSpreadOk())
     {
      Print("Spread too high: ", DoubleToString(GetCurrentSpreadPips(), 1), " pips. Limit: ", InpMax_Spread_Pips);
      DrawFVGs(3); // Keep drawing FVGs even if spread is high
      return;
     }

//--- Check Trend Conditions for New Trade
   bool allow_buys = true;
   bool allow_sells = true;

   // MA1 vs MA2 Direction Filter
   if(InpEnable_MA_Direction_Filter)
     {
      // Use values from the last closed bar for decision stability
      if(ma1_prev > ma2_prev)
        {
         allow_sells = false; // Only Buys allowed
        }
      else if(ma1_prev < ma2_prev)
        {
         allow_buys = false; // Only Sells allowed
        }
      else
        {
         // MAs are equal - perhaps disallow both? Or follow MA3? Let's disallow for now.
         allow_buys = false;
         allow_sells = false;
        }
     }

   // MA3 Percent Change Filter
   if(InpEnable_MA3_Trend_Filter)
     {
      if(ma3_percent_change <= InpMA3_PercentChange_Buy_Threshold)
        {
         allow_buys = false; // Do not enter buys unless % change is higher
        }
      if(ma3_percent_change >= InpMA3_PercentChange_Sell_Threshold)
        {
         allow_sells = false; // Do not enter sells unless % change is lower (more negative)
        }
     }

//--- Identify and Check FVGs for Entry (passing the active window code)
   FindAndEnterTrade(allow_buys, allow_sells, active_window);

//--- Draw FVGs (after potential trade entry)
   DrawFVGs(3); // Look back 3 bars for potential FVGs to draw

  }
//+------------------------------------------------------------------+
//| Check Spread                                                     |
//+------------------------------------------------------------------+
bool IsSpreadOk()
  {
   if(InpMax_Spread_Pips <= 0) return true; // Filter disabled

   int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double spread_pips = PointsToPips(spread_points);

   return (spread_pips <= InpMax_Spread_Pips);
  }
//+------------------------------------------------------------------+
//| Get Current Spread in Pips                                       |
//+------------------------------------------------------------------+
double GetCurrentSpreadPips()
  {
   int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return PointsToPips(spread_points);
  }
//+------------------------------------------------------------------+
//| Get Active Time Filter Window                                    |
//+------------------------------------------------------------------+
// Returns:
// 0: Not allowed
// 1: Allowed by Filter 1
// 2: Allowed by Filter 2
// 3: Allowed by Filter 3
// 4: Allowed (no filters enabled)
int GetActiveTimeFilterWindow()
  {
   // If no filters enabled, always allow
   if(!InpEnable_Time_Filter1 && !InpEnable_Time_Filter2 && !InpEnable_Time_Filter3)
     {
      return 4; // Special code for 'no filters active'
     }

   MqlDateTime current_time_struct;
   TimeCurrent(current_time_struct); // Use Broker Time (Server Time)
   datetime current_seconds_today = current_time_struct.hour * 3600 + current_time_struct.min * 60 + current_time_struct.sec;

   bool allowed = false;
   int allowed_filter_num = 0;

   // Check Filter 1
   if(InpEnable_Time_Filter1)
     {
      if(tf1_end_sec > 86400) // Wraps midnight
        {
         if(current_seconds_today >= tf1_start_sec || current_seconds_today < (tf1_end_sec - 86400))
            allowed = true;
        }
      else // Within the same day
        {
         if(current_seconds_today >= tf1_start_sec && current_seconds_today < tf1_end_sec)
            allowed = true;
        }
      if(allowed) allowed_filter_num = 1;
     }

   // Check Filter 2 (if not already allowed)
   if(!allowed && InpEnable_Time_Filter2)
     {
       if(tf2_end_sec > 86400) // Wraps midnight
        {
         if(current_seconds_today >= tf2_start_sec || current_seconds_today < (tf2_end_sec - 86400))
            allowed = true;
        }
      else // Within the same day
        {
         if(current_seconds_today >= tf2_start_sec && current_seconds_today < tf2_end_sec)
            allowed = true;
        }
      if(allowed) allowed_filter_num = 2;
     }

   // Check Filter 3 (if not already allowed)
   if(!allowed && InpEnable_Time_Filter3)
     {
      if(tf3_end_sec > 86400) // Wraps midnight
        {
         if(current_seconds_today >= tf3_start_sec || current_seconds_today < (tf3_end_sec - 86400))
            allowed = true;
        }
      else // Within the same day
        {
         if(current_seconds_today >= tf3_start_sec && current_seconds_today < tf3_end_sec)
            allowed = true;
        }
      if(allowed) allowed_filter_num = 3;
     }

   // Return the window number if allowed
   if(allowed_filter_num != 0) return allowed_filter_num;

   return 0; // Not allowed by any active filter
  }

//+------------------------------------------------------------------+
//| Identify FVG at a given shift                                    |
//+------------------------------------------------------------------+
// Looks for FVG formed by bars shift, shift+1, shift+2
// Returns true if FVG found, fills fvg_info
bool IdentifyFVG(int shift, FVGInfo &fvg_info)
  {
   MqlRates rates[3];
   // We need 3 bars: shift (candle 3), shift+1 (candle 2), shift+2 (candle 1)
   if(CopyRates(_Symbol, _Period, shift, 3, rates) < 3)
      return false; // Not enough history

   // rates[0] = candle 3 (bar 'shift')
   // rates[1] = candle 2 (bar 'shift+1')
   // rates[2] = candle 1 (bar 'shift+2')

   double candle1_high = rates[0].high;   double candle1_low = rates[0].low;
   double candle3_high = rates[2].high;   double candle3_low = rates[2].low;

   // Check for Bullish FVG (Gap between Candle 1 High and Candle 3 Low)
   if(candle3_low > candle1_high)
     {
      // Calculate FVG size in points
      int fvg_size_points = (int)((candle3_low - candle1_high) / _Point);
      
      // Check if FVG is big enough
      if(InpFVG_Min_Size_Points > 0 && fvg_size_points < InpFVG_Min_Size_Points)
         return false; // FVG is too small
         
      fvg_info.is_bullish = true;
      fvg_info.high = candle3_low;    // Top of bullish FVG is Candle 3 Low
      fvg_info.low = candle1_high;   // Bottom of bullish FVG is Candle 1 High
      fvg_info.bar_index = (int)rates[0].tick_volume; // Use volume as proxy for bar index if needed, better: use time
      fvg_info.time_formed = rates[2].time;
      fvg_info.is_valid = true; // Initially valid
      fvg_info.object_name = StringFormat("%s_FVG_%s_%d", ea_comment, _Symbol, fvg_info.time_formed);
      return true;
     }

   // Check for Bearish FVG (Gap between Candle 1 Low and Candle 3 High)
   if(candle3_high < candle1_low)
     {
      // Calculate FVG size in points
      int fvg_size_points = (int)((candle1_low - candle3_high) / _Point);
      
      // Check if FVG is big enough
      if(InpFVG_Min_Size_Points > 0 && fvg_size_points < InpFVG_Min_Size_Points)
         return false; // FVG is too small
         
      fvg_info.is_bullish = false;
      fvg_info.high = candle1_low;    // Top of bearish FVG is Candle 1 Low
      fvg_info.low = candle3_high;   // Bottom of bearish FVG is Candle 3 High
      fvg_info.bar_index = (int)rates[0].tick_volume; // As above
      fvg_info.time_formed = rates[2].time;
      fvg_info.is_valid = true; // Initially valid
      fvg_info.object_name = StringFormat("%s_FVG_%s_%d", ea_comment, _Symbol, fvg_info.time_formed);

      return true;
     }

   return false; // No FVG found
  }

//+------------------------------------------------------------------+
//| Draw FVG Rectangles                                              |
//+------------------------------------------------------------------+
void DrawFVGs(int lookback_bars)
  {
   if(!InpShow_FVGs)
     {
      // If showing is turned off, remove existing rectangles
      ObjectsDeleteAll(0, ea_comment + "_FVG", 0, OBJ_RECTANGLE);
      return;
     }

   // --- Simple cleanup: Remove ALL old FVG rectangles first ---
   // A more sophisticated approach would track drawn objects and only remove outdated ones.
   ObjectsDeleteAll(0, ea_comment + "_FVG", 0, OBJ_RECTANGLE);

   int drawn_count = 0;
   // Start from shift=1 (last closed bar) because FVG is confirmed after candle 3 closes.
   for(int i = 1; i < lookback_bars + InpMax_FVGs_To_Draw + 5 && drawn_count < InpMax_FVGs_To_Draw; i++)
     {
      FVGInfo fvg;
      if(IdentifyFVG(i, fvg))
        {
         DrawFVGRectangle(fvg);
         drawn_count++;
        }
     }
  }

//+------------------------------------------------------------------+
//| Draw a single FVG Rectangle                                      |
//+------------------------------------------------------------------+
void DrawFVGRectangle(const FVGInfo &fvg)
  {
   if(!InpShow_FVGs) return;

   // Get times for rectangle boundaries
   datetime time1 = 0; // Candle 1 start time 
   datetime time3 = fvg.time_formed; // Candle 3 start time (already stored in fvg structure)

   // We need to get the time of Candle 1 (which is 2 bars before Candle 3)
   int shift = 0;
   
   // First, get the shift of the fvg.time_formed candle (Candle 3)
   MqlRates rates[1];
   datetime begin_time = 0;
   datetime end_time = TimeCurrent() + PeriodSeconds(_Period);
   for(int i = 1; i < 1000; i++) // Safe search limit
   {
      if(CopyRates(_Symbol, _Period, i, 1, rates) > 0)
      {
         if(rates[0].time == fvg.time_formed)
         {
            shift = i; // Found the shift of Candle 3
            break;
         }
      }
      else
      {
         break; // No more data
      }
   }
   
   // If we couldn't find the exact shift, use fallback method
   if(shift == 0)
   {
      // Fallback: estimate time (less accurate)
      time1 = fvg.time_formed - (2 * PeriodSeconds(_Period));
      Print("Warning: Using estimated time for FVG rectangle. Original time: ", TimeToString(fvg.time_formed));
   }
   else
   {
      // We know Candle 3 is at 'shift', so Candle 1 is at 'shift+2'
      if(CopyRates(_Symbol, _Period, shift+2, 1, rates) > 0)
      {
         time1 = rates[0].time;
      }
      else
      {
         // Fallback if we can't get the exact bar
         time1 = fvg.time_formed - (2 * PeriodSeconds(_Period));
         Print("Warning: Couldn't get Candle 1 time for FVG at shift ", shift+2);
      }
   }

   color rect_color = fvg.is_bullish ? InpFVG_Bullish_Color : InpFVG_Bearish_Color;

   // Delete existing object with the same name first to avoid errors
   ObjectDelete(0, fvg.object_name);

   // Create the rectangle - Important: Use the start times of Candle 1 and Candle 3
   if(!ObjectCreate(0, fvg.object_name, OBJ_RECTANGLE, 0, time1, fvg.low, time3, fvg.high))
     {
      Print("Error creating FVG rectangle ", fvg.object_name, " - ", GetLastError());
      return;
     }

   ObjectSetInteger(0, fvg.object_name, OBJPROP_COLOR, rect_color);
   ObjectSetInteger(0, fvg.object_name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, fvg.object_name, OBJPROP_BACK, true); // Draw in background
   ObjectSetInteger(0, fvg.object_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, fvg.object_name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, fvg.object_name, OBJPROP_FILL, InpFill_FVGs); // Fill rectangle based on user preference
   ObjectSetString(0, fvg.object_name, OBJPROP_TOOLTIP, fvg.is_bullish ? "Bullish FVG" : "Bearish FVG");
   // Time property needs to be set correctly
   ObjectSetInteger(0, fvg.object_name, OBJPROP_TIME, 0, time1);
   ObjectSetInteger(0, fvg.object_name, OBJPROP_TIME, 1, time3);

   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Find and Enter Trade based on FVG Retest                         |
//+------------------------------------------------------------------+
void FindAndEnterTrade(bool allow_buys, bool allow_sells, int active_window)
  {
   // Look for the most recent FVG within a reasonable lookback (e.g., 10 bars)

   // --- Check if trade already taken for this window ---
   // This is an extra safety check in case ManageCurrentTrade failed to detect an existing position
   if(current_trade.ticket != 0) return; // Don\'t proceed if EA knows a trade is open

   FVGInfo latest_fvg;
   bool fvg_found = false;
   int fvg_shift = -1;

   for(int i = 1; i < 10; i++) // Start from closed bar 1
     {
      if(IdentifyFVG(i, latest_fvg))
        {
         fvg_found = true;
         fvg_shift = i;
         break; // Found the most recent one
        }
     }

   if(!fvg_found) return; // No recent FVG found

   // --- Check for Retest ---
   MqlRates recent_bars[];
   int bars_to_check = MathMax(1, InpFVG_Retest_Bars); // Ensure at least 1 bar
   // Copy enough bars: from current (0) back to the oldest bar needed for check
   int oldest_shift_needed = fvg_shift; // Need at least the FVG formation bars
   int bars_needed = oldest_shift_needed + 1; // +1 because CopyRates counts from 0

   if(CopyRates(_Symbol, _Period, 0, bars_needed, recent_bars) < bars_needed)
     {
      Print("Not enough bars for FVG retest check (Need: ", bars_needed, ", FVG Shift: ", fvg_shift, ").");
      return;
     }

   bool retest_occurred = false;
   int retest_bar_index = -1; // Relative index within recent_bars array

   // Define the range of shifts (relative to current bar 0) to check for retest
   // Check starts from the bar *immediately after* FVG formation (shift = fvg_shift - 1)
   // Check goes back for InpFVG_Retest_Bars bars, but not beyond bar 0
   //--- Check starts relative to FVG formation, optionally skipping the first bar ---
   int start_offset = InpFVG_Skip_First_Retest_Bar ? 2 : 1; // Offset: 1=start immediately after, 2=skip first bar
   int start_shift_check = fvg_shift - start_offset;
   // Adjust end shift to maintain the same number of retest bars relative to the new start
   // Ensure we check at least one bar if Retest_Bars is > 0
   int bars_in_window = MathMax(1, InpFVG_Retest_Bars); 
   int end_shift_check = MathMax(0, start_shift_check - bars_in_window + 1); 
   
   // Ensure start_shift_check is valid (not negative)
   // If start_shift_check is negative, it means the FVG formed too recently to begin the check
   // at the desired offset (e.g., FVG at shift 1, trying to start check at shift -1 if skipping).
   if(start_shift_check < 0)
     {
        if(InpShow_FVG_Debug)
        {
          Print("FVG formed too recently (Shift=", fvg_shift, ", StartOffset=", start_offset, "). Cannot start retest check yet.");
        }
        return; // Cannot check retest if FVG just formed on the last closed bar (shift=1)
     }
     
     if(InpShow_FVG_Debug)
       {
          Print("=== FVG Retest Check Details ===");
          Print("FVG Found at Shift (Candle 3): ", fvg_shift, " Time: ", TimeToString(latest_fvg.time_formed));
          string skip_info = InpFVG_Skip_First_Retest_Bar ? " (Skipping 1st bar)" : "";
          Print("Checking Shifts [", end_shift_check, " to ", start_shift_check, "] for Retest (Max ", bars_in_window, " bars", skip_info, ")");
          Print("FVG High: ", DoubleToString(latest_fvg.high, _Digits), " | FVG Low: ", DoubleToString(latest_fvg.low, _Digits));
       }

   // Iterate from the most recent bar in the window backwards
   for(int k = start_shift_check; k >= end_shift_check; k--)
     {
      if(latest_fvg.is_bullish && allow_buys)
        {
         // Bullish FVG: Price needs to touch or dip below FVG High (latest_fvg.high which is Candle 3 Low)
         if(InpShow_FVG_Debug)
         {
            Print("Checking Shift ", k, " [Bullish]: Bar Low=", DoubleToString(recent_bars[k].low, _Digits), " vs FVG High=", DoubleToString(latest_fvg.high, _Digits));
         }

         if(recent_bars[k].low <= latest_fvg.high) // Price dipped into or below the top of the Bullish FVG
         {
            if(InpShow_FVG_Debug)
            {
               Print("  ✓ RETEST TOUCH DETECTED at shift ", k);
            }

            // Check if FVG wasn't invalidated (bar didn't close BELOW the FVG Low)
            if(recent_bars[k].close < latest_fvg.low)
            {
               if(InpShow_FVG_Debug)
               {
                  Print("  ✗ FVG INVALIDATED at shift ", k, ": Close=", DoubleToString(recent_bars[k].close, _Digits), " < FVG Low=", DoubleToString(latest_fvg.low, _Digits));
               }
               // Invalidation means we stop checking this FVG
               latest_fvg.is_valid = false; // Mark FVG as invalid
               retest_occurred = false; // Reset flag if invalidated on this bar
               break; // Stop checking further back for this specific FVG
            }
            else
            {
               if(InpShow_FVG_Debug)
               {
                  Print("  ✓ FVG VALID at shift ", k, ": Close=", DoubleToString(recent_bars[k].close, _Digits), " >= FVG Low=", DoubleToString(latest_fvg.low, _Digits));
               }
               retest_occurred = true;
               retest_bar_index = k; // Store the shift where valid retest occurred
               break; // Found a valid retest, no need to check older bars
            }
         }
        }
      else if(!latest_fvg.is_bullish && allow_sells)
        {
         // Bearish FVG: Price needs to touch or spike above FVG Low (latest_fvg.low which is Candle 3 High)
         if(InpShow_FVG_Debug)
         {
            Print("Checking Shift ", k, " [Bearish]: Bar High=", DoubleToString(recent_bars[k].high, _Digits), " vs FVG Low=", DoubleToString(latest_fvg.low, _Digits));
         }

         if(recent_bars[k].high >= latest_fvg.low) // Price spiked into or above the bottom of the Bearish FVG
         {
            if(InpShow_FVG_Debug)
            {
               Print("  ✓ RETEST TOUCH DETECTED at shift ", k);
            }

            // Check if FVG wasn't invalidated (bar didn't close ABOVE the FVG High)
            if(recent_bars[k].close > latest_fvg.high)
            {
               if(InpShow_FVG_Debug)
               {
                  Print("  ✗ FVG INVALIDATED at shift ", k, ": Close=", DoubleToString(recent_bars[k].close, _Digits), " > FVG High=", DoubleToString(latest_fvg.high, _Digits));
               }
               // Invalidation means we stop checking this FVG
               latest_fvg.is_valid = false; // Mark FVG as invalid
               retest_occurred = false; // Reset flag if invalidated on this bar
               break; // Stop checking further back for this specific FVG
            }
            else
            {
               if(InpShow_FVG_Debug)
               {
                   Print("  ✓ FVG VALID at shift ", k, ": Close=", DoubleToString(recent_bars[k].close, _Digits), " <= FVG High=", DoubleToString(latest_fvg.high, _Digits));
               }
               retest_occurred = true;
               retest_bar_index = k; // Store the shift where valid retest occurred
               break; // Found a valid retest, no need to check older bars
            }
         }
        }
     }

   // If Debug enabled and no retest found, print why
   if(InpShow_FVG_Debug && !retest_occurred && latest_fvg.is_valid)
   {
        Print("No valid retest occurred within the checked shifts [", end_shift_check, " to ", start_shift_check, "] for FVG at shift ", fvg_shift);
   }
   else if (InpShow_FVG_Debug && !latest_fvg.is_valid)
   {
        Print("FVG at shift ", fvg_shift, " was invalidated during retest check.");
   }
   

   if(!retest_occurred) return; // No valid retest found or FVG invalidated

   // --- Calculate SL and TP ---
   double fvg_width_pips = PointsToPips(MathAbs(latest_fvg.high - latest_fvg.low) / _Point);
   double calculated_sl_pips = fvg_width_pips + InpSL_Extra_Pips;

   // Apply Min/Max SL Caps
   double final_sl_pips = MathMax(InpMin_StopLoss_Pips, calculated_sl_pips);

   // Check if SL exceeds Max and if we should abort
   if(InpMax_StopLoss_Pips > 0 && final_sl_pips > InpMax_StopLoss_Pips) // Check if Max SL is enabled (>0)
     {
      if(InpAbort_If_SL_Exceeds_Max)
        {
         Print("Trade aborted: Calculated SL (", DoubleToString(final_sl_pips, 1), ") exceeds Max SL (", InpMax_StopLoss_Pips, ")");
         return; // Abort the trade
        }
      else
        {
         Print("Calculated SL (", DoubleToString(final_sl_pips, 1), ") capped at Max SL (", InpMax_StopLoss_Pips, ")");
         final_sl_pips = InpMax_StopLoss_Pips; // Cap the SL
        }
     }

   double tp_pips = final_sl_pips * InpRisk_Reward_Ratio;

   // --- Prepare and Execute Trade ---
   double entry_price = SymbolInfoDouble(_Symbol, latest_fvg.is_bullish ? SYMBOL_ASK : SYMBOL_BID); // Use current market price for entry
   double sl_price = 0;
   double tp_price = 0; // Calculated TP price based on R:R
   double fixed_tp_price_calc = 0;
   double fixed_sl_price_calc = 0;


   if(latest_fvg.is_bullish && allow_buys)
     {
      // --- Check if Buy trade already taken for this session/window ---
      if(HasTradeTaken(true, active_window))
        {
         // Optional: Print("Buy trade already taken for window ", active_window, ". Skipping.");
         return; // Skip entry
        }

      sl_price = entry_price - PipsToPoints(final_sl_pips);
      tp_price = entry_price + PipsToPoints(tp_pips);
      if(InpEnable_Fixed_TP) fixed_tp_price_calc = entry_price + PipsToPoints(InpFixed_TP_Pips);
      if(InpEnable_Fixed_SL) fixed_sl_price_calc = entry_price - PipsToPoints(InpFixed_SL_Pips);

      // Add FVG Debug Info
      if(InpShow_FVG_Debug)
        {
         Print("=== Bullish FVG Trade Trigger Details ===");
         Print("FVG Size: ", DoubleToString(fvg_width_pips, 1), " pips");
         Print("FVG High (Candle 3 Low): ", DoubleToString(latest_fvg.high, _Digits));
         Print("FVG Low (Candle 1 High): ", DoubleToString(latest_fvg.low, _Digits));
         Print("FVG Formation Time: ", TimeToString(latest_fvg.time_formed));
         Print("Bars Since Formation: ", fvg_shift);
         Print("====================================");
        }

      // --- Open Buy Trade ---
      if(trade.Buy(InpLots, _Symbol, entry_price, 0, 0, ea_comment)) // SL/TP are NOT set on order, managed internally
        {
         Print("BUY Order Opened: ", trade.ResultDeal(), " at ", entry_price,
               " | Initial SL Pips: ", DoubleToString(final_sl_pips, 1), " (Price: ", DoubleToString(sl_price, _Digits), ")",
               " | TP Pips: ", DoubleToString(tp_pips, 1), " (Price: ", DoubleToString(tp_price, _Digits), ")");

         // Store active trade details
         current_trade.ticket = trade.ResultDeal();
         current_trade.entry_price = entry_price; // Store actual executed price if available, else requested price
         // It's better to query position price after opening
         if(PositionSelectByTicket(current_trade.ticket)) {
            current_trade.entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
            // Recalculate SL/TP based on actual entry price
            sl_price = current_trade.entry_price - PipsToPoints(final_sl_pips);
            tp_price = current_trade.entry_price + PipsToPoints(tp_pips);
            if(InpEnable_Fixed_TP) fixed_tp_price_calc = current_trade.entry_price + PipsToPoints(InpFixed_TP_Pips);
            if(InpEnable_Fixed_SL) fixed_sl_price_calc = current_trade.entry_price - PipsToPoints(InpFixed_SL_Pips);
             Print("Actual Entry: ", current_trade.entry_price, " | Revised SL: ", sl_price, " | Revised TP: ", tp_price);
         } else {
             Print("Warning: Could not select position by ticket ", current_trade.ticket, " immediately after opening.");
         }


         current_trade.stop_loss_price = sl_price;
         current_trade.take_profit_price = tp_price;
         current_trade.stop_loss_pips = final_sl_pips;
         current_trade.entry_time = TimeCurrent();
         current_trade.is_buy = true;
         current_trade.be_triggered = false; // <-- Initialize BE flag
         current_trade.fvg_high = latest_fvg.high;
         current_trade.fvg_low = latest_fvg.low;
         current_trade.fixed_tp_price = fixed_tp_price_calc;
         current_trade.fixed_sl_price = fixed_sl_price_calc;

         // --- Mark Buy trade as taken for this session/window ---
         MarkTradeTaken(true, active_window);
        }
      else
        {
         Print("Error Opening BUY Order: ", trade.ResultRetcode(), " - ", trade.ResultComment());
        }
     }
   else if(!latest_fvg.is_bullish && allow_sells)
     {
      // --- Check if Sell trade already taken for this session/window ---
      if(HasTradeTaken(false, active_window))
        {
         // Optional: Print("Sell trade already taken for window ", active_window, ". Skipping.");
         return; // Skip entry
        }

      sl_price = entry_price + PipsToPoints(final_sl_pips);
      tp_price = entry_price - PipsToPoints(tp_pips);
      if(InpEnable_Fixed_TP) fixed_tp_price_calc = entry_price - PipsToPoints(InpFixed_TP_Pips);
      if(InpEnable_Fixed_SL) fixed_sl_price_calc = entry_price + PipsToPoints(InpFixed_SL_Pips);

      // Add FVG Debug Info
      if(InpShow_FVG_Debug)
        {
         Print("=== Bearish FVG Trade Trigger Details ===");
         Print("FVG Size: ", DoubleToString(fvg_width_pips, 1), " pips");
         Print("FVG High (Candle 1 Low): ", DoubleToString(latest_fvg.high, _Digits));
         Print("FVG Low (Candle 3 High): ", DoubleToString(latest_fvg.low, _Digits));
         Print("FVG Formation Time: ", TimeToString(latest_fvg.time_formed));
         Print("Bars Since Formation: ", fvg_shift);
         Print("====================================");
        }

      // --- Open Sell Trade ---
      if(trade.Sell(InpLots, _Symbol, entry_price, 0, 0, ea_comment))
        {
         Print("SELL Order Opened: ", trade.ResultDeal(), " at ", entry_price,
               " | Initial SL Pips: ", DoubleToString(final_sl_pips, 1), " (Price: ", DoubleToString(sl_price, _Digits), ")",
               " | TP Pips: ", DoubleToString(tp_pips, 1), " (Price: ", DoubleToString(tp_price, _Digits), ")");

         // Store active trade details
         current_trade.ticket = trade.ResultDeal();
         current_trade.entry_price = entry_price; // Store actual executed price if available, else requested price
         // It's better to query position price after opening
         if(PositionSelectByTicket(current_trade.ticket)) {
            current_trade.entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
            // Recalculate SL/TP based on actual entry price
            sl_price = current_trade.entry_price + PipsToPoints(final_sl_pips);
            tp_price = current_trade.entry_price - PipsToPoints(tp_pips);
            if(InpEnable_Fixed_TP) fixed_tp_price_calc = current_trade.entry_price - PipsToPoints(InpFixed_TP_Pips);
            if(InpEnable_Fixed_SL) fixed_sl_price_calc = current_trade.entry_price + PipsToPoints(InpFixed_SL_Pips);
            Print("Actual Entry: ", current_trade.entry_price, " | Revised SL: ", sl_price, " | Revised TP: ", tp_price);

         } else {
             Print("Warning: Could not select position by ticket ", current_trade.ticket, " immediately after opening.");
         }

         current_trade.stop_loss_price = sl_price;
         current_trade.take_profit_price = tp_price;
         current_trade.stop_loss_pips = final_sl_pips;
         current_trade.entry_time = TimeCurrent();
         current_trade.is_buy = false;
         current_trade.be_triggered = false; // <-- Initialize BE flag
         current_trade.fvg_high = latest_fvg.high;
         current_trade.fvg_low = latest_fvg.low;
         current_trade.fixed_tp_price = fixed_tp_price_calc;
         current_trade.fixed_sl_price = fixed_sl_price_calc;

         // --- Mark Sell trade as taken for this session/window ---
         MarkTradeTaken(false, active_window);
        }
      else
        {
         Print("Error Opening SELL Order: ", trade.ResultRetcode(), " - ", trade.ResultComment());
        }
     }
  }

//+------------------------------------------------------------------+
//| Manage Current Open Trade                                        |
//+------------------------------------------------------------------+
// Returns true if a trade is open, false otherwise. Closes trade if conditions met.
bool ManageCurrentTrade()
  {
   // Check if we *think* a trade is open based on our variable
   if(current_trade.ticket == 0)
     {
      // Double check if there's a position with our magic number just in case
      if(PositionSelect(_Symbol))
        {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
           {
            Print("Warning: Found position ", PositionGetInteger(POSITION_TICKET), " but internal tracker was empty. Attempting to close.");
            trade.PositionClose(_Symbol);
           }
        }
      return false; // No trade known to the EA
     }

   // Select the position using the stored ticket
   if(!PositionSelectByTicket(current_trade.ticket))
     {
      // Position no longer exists (closed manually, by broker, etc.)
      Print("Position ", current_trade.ticket, " not found. Resetting trade info.");
      ResetActiveTradeInfo();
      return false; // No trade open
     }

   // --- Position exists, get current details ---
   double ask_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double current_price_for_close = current_trade.is_buy ? bid_price : ask_price; // Use Bid for Buy close, Ask for Sell close
   double current_price_for_trail = current_trade.is_buy ? ask_price : bid_price; // Use Ask for Buy trail calc, Bid for Sell trail calc
   double current_profit_points = 0;
   if(current_trade.is_buy)
     {
       current_profit_points = (bid_price - current_trade.entry_price) / _Point;
     }
   else
     {
        current_profit_points = (current_trade.entry_price - ask_price) / _Point;
     }

   double current_profit_monetary = PositionGetDouble(POSITION_PROFIT); // For logging
   datetime current_time = TimeCurrent();
   int stop_level_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);


   string close_reason = "";

   // --- Check Closing Conditions (Highest Priority First) ---

   // 1. Standard Stop Loss (FVG-Based initially, potentially trailed later)
   if(current_trade.is_buy && current_price_for_close <= current_trade.stop_loss_price)
      close_reason = "Stop Loss"; // Generic SL reason now
   if(!current_trade.is_buy && current_price_for_close >= current_trade.stop_loss_price)
      close_reason = "Stop Loss";

   // 2. R:R Take Profit
   if(close_reason == "" && InpRisk_Reward_Ratio > 0) // Check if TP enabled
     {
      if(current_trade.is_buy && current_price_for_close >= current_trade.take_profit_price)
         close_reason = "Take Profit (R:R)";
      if(!current_trade.is_buy && current_price_for_close <= current_trade.take_profit_price)
         close_reason = "Take Profit (R:R)";
     }

   // 3. Fixed Take Profit (if enabled and not already closing)
   if(close_reason == "" && InpEnable_Fixed_TP)
     {
        if(current_trade.is_buy && current_price_for_close >= current_trade.fixed_tp_price)
            close_reason = "Fixed Take Profit";
        if(!current_trade.is_buy && current_price_for_close <= current_trade.fixed_tp_price)
            close_reason = "Fixed Take Profit";
     }

   // 4. Fixed Stop Loss (if enabled and not already closing)
    if(close_reason == "" && InpEnable_Fixed_SL)
     {
        // This acts as an *additional* SL, potentially wider than the FVG/trailed one
        if(current_trade.is_buy && current_price_for_close <= current_trade.fixed_sl_price)
            close_reason = "Fixed Stop Loss";
        if(!current_trade.is_buy && current_price_for_close >= current_trade.fixed_sl_price)
            close_reason = "Fixed Stop Loss";
     }


   // --- Check Trailing Stop / BreakEven Logic (Only if position is not already marked for closure) ---
   if(close_reason == "")
     {
       // 5. BreakEven Trigger Logic (if enabled and not yet triggered)
       if(InpEnable_Trailing_SL && InpBE_Trigger_Points > 0 && !current_trade.be_triggered)
         {
           if(current_profit_points >= InpBE_Trigger_Points)
             {
               // Calculate potential BE SL price
               double be_sl_price = 0;
               if(current_trade.is_buy)
                 {
                   be_sl_price = current_trade.entry_price + InpBE_Extra_Points * _Point;
                 }
               else
                 {
                   be_sl_price = current_trade.entry_price - InpBE_Extra_Points * _Point;
                 }
               be_sl_price = NormalizeDouble(be_sl_price, _Digits);

               // Check if BE SL is better than current SL
               bool is_better = (current_trade.is_buy && be_sl_price > current_trade.stop_loss_price) ||
                                (!current_trade.is_buy && be_sl_price < current_trade.stop_loss_price);

               // Check StopLevel constraint: New SL must be far enough from current market price
               double price_diff_points = 0;
               if(current_trade.is_buy)
                 {
                    price_diff_points = (current_price_for_trail - be_sl_price) / _Point; // Ask - New SL
                 }
               else
                 {
                    price_diff_points = (be_sl_price - current_price_for_trail) / _Point; // New SL - Bid
                 }

               if(is_better && price_diff_points >= stop_level_points)
                 {
                   Print("Trade ", current_trade.ticket, ": BreakEven triggered (Profit: ", DoubleToString(current_profit_points,0), " points). Moving SL to ", DoubleToString(be_sl_price, _Digits));
                   current_trade.stop_loss_price = be_sl_price; // Update the monitored SL price
                   current_trade.be_triggered = true; // Mark as triggered
                 }
                else if (is_better) {
                   // BE triggered profit-wise, but SL placement violates StopLevel. Wait for price to move further.
                   // Print("Trade ", current_trade.ticket, ": BE Triggered profit-wise, but StopLevel prevents SL move (Diff: ", price_diff_points, ", Needed: ", stop_level_points, ")");
                }
             }
         } // End BreakEven Check

       // 6. Trailing Stop Logic (if enabled and BE is done or not required)
       bool can_trail = InpEnable_Trailing_SL && (InpBE_Trigger_Points <= 0 || current_trade.be_triggered);
       if(can_trail)
         {
            double trailing_distance_points = 0;

            // Calculate trailing distance
            if(InpTrailing_Method == TRAILING_METHOD_ATR)
            {
                double atr_points = GetATRPoints();
                if(atr_points > 0) // Ensure we got a valid ATR
                {
                    trailing_distance_points = atr_points * InpTrailing_ATR_Multiplier;
                }
            }
            else // Fixed Points
            {
                trailing_distance_points = InpTrailing_Fixed_Points;
            }

            if(trailing_distance_points > 0)
            {
               // Calculate potential new SL
               double new_sl_price = 0;
               if(current_trade.is_buy)
               {
                   new_sl_price = current_price_for_trail - trailing_distance_points * _Point; // Trail below Ask
               }
               else
               {
                   new_sl_price = current_price_for_trail + trailing_distance_points * _Point; // Trail above Bid
               }
               new_sl_price = NormalizeDouble(new_sl_price, _Digits);

               // Check if new SL is better than current SL
               bool is_better = (current_trade.is_buy && new_sl_price > current_trade.stop_loss_price) ||
                                (!current_trade.is_buy && new_sl_price < current_trade.stop_loss_price);

               // Check StopLevel constraint
               double price_diff_points = 0;
               if(current_trade.is_buy)
                 {
                    price_diff_points = (current_price_for_trail - new_sl_price) / _Point; // Ask - New SL
                 }
               else
                 {
                    price_diff_points = (new_sl_price - current_price_for_trail) / _Point; // New SL - Bid
                 }

               if(is_better && price_diff_points >= stop_level_points)
                 {
                    // Print("Trade ", current_trade.ticket, ": Trailing SL. New SL: ", DoubleToString(new_sl_price, _Digits), " (Dist: ", trailing_distance_points, " pts)"); // Optional debug
                    current_trade.stop_loss_price = new_sl_price; // Update SL
                 }
                 else if (is_better)
                 {
                    // New SL is better profit-wise, but too close to market price due to StopLevel
                    // Print("Trade ", current_trade.ticket, ": Trailing SL blocked by StopLevel (Diff: ", price_diff_points, ", Needed: ", stop_level_points, ")");
                 }

            } // end if trailing_distance_points > 0
         } // End Trailing Logic

     } // End Check Trailing/BE Logic block


   // --- Execute Close if Reason Found ---
   if(close_reason != "")
     {
      Print("Closing Trade ", current_trade.ticket, " Reason: ", close_reason, " Profit: ", DoubleToString(current_profit_monetary, 2));
      if(trade.PositionClose(current_trade.ticket))
        {
         Print("Trade ", current_trade.ticket, " successfully closed.");
         ResetActiveTradeInfo();
         return false; // Trade was closed this tick
        }
      else
        {
         Print("Error closing trade ", current_trade.ticket, ": ", trade.ResultRetcode(), " - ", trade.ResultComment());
         // Don't reset info yet, try again next tick
        }
     }

   // If we reach here, trade is still open
   return true;
  }

//+------------------------------------------------------------------+
//| Reset Active Trade Info                                          |
//+------------------------------------------------------------------+
void ResetActiveTradeInfo()
  {
   current_trade.ticket = 0;
   current_trade.entry_price = 0;
   current_trade.stop_loss_price = 0;
   current_trade.take_profit_price = 0;
   current_trade.stop_loss_pips = 0;
   current_trade.entry_time = 0;
   current_trade.is_buy = false;
   current_trade.be_triggered = false; // <-- NEW
   current_trade.fvg_high = 0;
   current_trade.fvg_low = 0;
   current_trade.fixed_tp_price = 0;
   current_trade.fixed_sl_price = 0;
  }

//+------------------------------------------------------------------+
//| Helper to get ATR value in points                                |
//+------------------------------------------------------------------+
double GetATRPoints()
  {
   if(atr_handle == INVALID_HANDLE) return 0; // Should not happen if initialized correctly

   double atr_values[1];
   // Get ATR from the last closed bar (index 1)
   if(CopyBuffer(atr_handle, 0, 1, 1, atr_values) < 1)
     {
      Print("Error copying ATR buffer - ", GetLastError());
      return 0; // Return 0 if error, SL won't trail based on ATR this tick
     }

   // ATR value is usually in price units, convert to points
   double atr_in_points = atr_values[0] / _Point;
   return atr_in_points;
  }

//+------------------------------------------------------------------+
//| Update Chart Display (Comment)                                   |
//+------------------------------------------------------------------+
void UpdateDisplay()
  {
   string comment_text = ea_comment + " | " + _Symbol + " | " + EnumToString(_Period);

   if(InpShow_Percent_Change)
     {
      comment_text += "\nMA3 %Change: " + DoubleToString(ma3_percent_change, 5);
     }

   if(current_trade.ticket != 0)
     {
      comment_text += "\nOpen Trade: " + (string)current_trade.ticket;
      comment_text += " (" + (current_trade.is_buy ? "BUY" : "SELL") + ")";
      comment_text += " | Entry: " + DoubleToString(current_trade.entry_price, _Digits);
      comment_text += "\nSL: " + DoubleToString(current_trade.stop_loss_price, _Digits) + " (Initial: " + DoubleToString(current_trade.stop_loss_pips, 1) + " pips)";
      comment_text += " | TP: " + DoubleToString(current_trade.take_profit_price, _Digits);
      if(InpEnable_Trailing_SL) {
           comment_text += " | Trail: ";
           if(current_trade.be_triggered) comment_text += "[BE Set]";
           else if (InpBE_Trigger_Points > 0) comment_text += "[BE Pending]";
           else comment_text += "[ON]"; // Trailing enabled but no BE trigger
      } else {
          comment_text += " | Trail: [OFF]";
      }
     }
    else
     {
        comment_text += "\nNo active trade.";
        // Display potential filter status
        string filter_status = "Filters: ";
        if (InpEnable_MA_Direction_Filter) filter_status += "MA Dir [ON], "; else filter_status += "MA Dir [OFF], ";
        if (InpEnable_MA3_Trend_Filter) filter_status += "MA3 Trend [ON], "; else filter_status += "MA3 Trend [OFF], ";
        if (InpMax_Spread_Pips > 0) filter_status += "Spread<" + DoubleToString(InpMax_Spread_Pips, 1) + " [ON], "; else filter_status += "Spread [OFF], ";
        if (InpEnable_Time_Filter1 || InpEnable_Time_Filter2 || InpEnable_Time_Filter3) filter_status += "Time [ON]"; else filter_status += "Time [OFF]";
        comment_text += "\n" + filter_status;
     }

     if (stop_trading) {
        comment_text = "!!! TRADING STOPPED - LOW BALANCE !!!";
     }


   Comment(comment_text);
  }

//+------------------------------------------------------------------+
//| Convert Points to Pips                                           |
//+------------------------------------------------------------------+
double PointsToPips(double points_val)
  {
   return points_val * pow(10, digits_pips - _Digits); // Adjust based on pip definition
  }
//+------------------------------------------------------------------+
//| Convert Pips to Points                                           |
//+------------------------------------------------------------------+
double PipsToPoints(double pips_val)
  {
   return NormalizeDouble(pips_val / pow(10, digits_pips - _Digits), _Digits); // Convert pips back to points
  }
//+------------------------------------------------------------------+
//| Get Bar Index from Time                                          |
//+------------------------------------------------------------------+
int TimeToBarIndex(datetime time) {
    MqlRates rates[];
    datetime start_time = time;
    datetime end_time = time +PeriodSeconds(_Period); // Look for the bar that starts at this time
    int copied = CopyRates(_Symbol, _Period, start_time, end_time, rates);

    if(copied > 0 && rates[0].time == time) {
        // We need the *shift* relative to the current bar (bar 0)
        MqlRates current_rate[1];
        if(CopyRates(_Symbol, _Period, 0, 1, current_rate) > 0) {
             long bars_diff = (current_rate[0].time - rates[0].time) / PeriodSeconds(_Period);
             return (int)bars_diff;
        }
    }
    // Fallback or error
    return -1; // Indicate failure
}
//+------------------------------------------------------------------+
//| Get Seconds in Current Period                                    |
//+------------------------------------------------------------------+
long PeriodSeconds() {
    return PeriodSeconds(_Period);
}
//+------------------------------------------------------------------+
//| Reset Trade Limiting Flags (called daily or on init)             |
//+------------------------------------------------------------------+
void ResetTradeLimitFlags()
  {
   buy_trade_taken_tf1 = false;
   sell_trade_taken_tf1 = false;
   buy_trade_taken_tf2 = false;
   sell_trade_taken_tf2 = false;
   buy_trade_taken_tf3 = false;
   sell_trade_taken_tf3 = false;
   buy_trade_taken_general = false;
   sell_trade_taken_general = false;
   Print("Trade limiting flags reset.");
  }
//+------------------------------------------------------------------+
//| Check if a specific trade type has been taken for the window     |
//+------------------------------------------------------------------+
bool HasTradeTaken(bool is_buy_check, int window_code)
  {
   switch(window_code)
     {
      case 1: // Time Filter 1
         return is_buy_check ? buy_trade_taken_tf1 : sell_trade_taken_tf1;
      case 2: // Time Filter 2
         return is_buy_check ? buy_trade_taken_tf2 : sell_trade_taken_tf2;
      case 3: // Time Filter 3
         return is_buy_check ? buy_trade_taken_tf3 : sell_trade_taken_tf3;
      case 4: // No Filters Active (General)
         return is_buy_check ? buy_trade_taken_general : sell_trade_taken_general;
      default: // Should not happen, but treat as trade taken to be safe
         Print("Error: Invalid window_code (", window_code, ") in HasTradeTaken.");
         return true;
     }
  }
//+------------------------------------------------------------------+
//| Mark a specific trade type as taken for the window               |
//+------------------------------------------------------------------+
void MarkTradeTaken(bool is_buy_trade, int window_code)
  {
   switch(window_code)
     {
      case 1: // Time Filter 1
         if(is_buy_trade) buy_trade_taken_tf1 = true; else sell_trade_taken_tf1 = true;
         break;
      case 2: // Time Filter 2
         if(is_buy_trade) buy_trade_taken_tf2 = true; else sell_trade_taken_tf2 = true;
         break;
      case 3: // Time Filter 3
         if(is_buy_trade) buy_trade_taken_tf3 = true; else sell_trade_taken_tf3 = true;
         break;
      case 4: // No Filters Active (General)
         if(is_buy_trade) buy_trade_taken_general = true; else sell_trade_taken_general = true;
         break;
      default:
         Print("Error: Invalid window_code (", window_code, ") in MarkTradeTaken.");
         break;
     }
     Print("Trade marked as taken: ", (is_buy_trade ? "BUY" : "SELL"), " for window code: ", window_code);
  }