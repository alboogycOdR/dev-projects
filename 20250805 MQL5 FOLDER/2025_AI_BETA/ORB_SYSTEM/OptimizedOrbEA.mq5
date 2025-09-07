//+------------------------------------------------------------------+
//|                                               OptimizedOrbEA.mq5 |
//|                      Copyright © 2024, Your Name/Organization |
//|                                             https://example.com |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2024, Your Name/Organization"
#property link      "https://example.com"
#property version   "1.00"
#property strict
#property description "Optimized Opening Range Breakout EA based on Playbit/SFI principles"
//https://aistudio.google.com/prompts/1XchIpxi4rlmh3tKFvXmVK88scQo157VJ
#include <Trade\Trade.mqh> // Include Trading library
/*

Opening Range: Defined by the iOpeningRangeDurationMinutes (default 15 min) starting at iRangeStartTime.
Entry Trigger: Waiting for an iEntryConfirmationTimeframe candle (default M5) to close outside the defined range.
Stop Loss: Option between 50% of the M15 anchor candle's range (SL_RANGE_50_PERCENT, default) or a percentage of the daily ATR (SL_ATR_PERCENT).
Take Profit: Option to use Standard Deviation levels (via the customized Fib tool, iUseStandardDeviationTP=true, default) or rely on End-of-Day closure (iUseEODClose=true, default fallback).
Time Filters: Includes start/end times for looking for entries and a hard cutoff time to prevent late-day trades if the range hasn't broken (iHardCutoffTime, default 11:59 based on Playbit's 12:00 rule).
Risk Management: Implements both fixed lot sizing and risk percentage-based sizing.
Visuals: Options to draw the range and TP levels on the chart.


Next Steps & Crucial Considerations:
-  -  -  -  -  - -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -   
Broker Server Time: Double-check and correctly configure all the time inputs (iRangeStartTime, iTradeStartTime, iTradeEndTime, iHardCutoffTime, iCloseAllTradesTime) based on your specific broker's server time zone to align accurately with the intended market session (e.g., New York 9:30 AM EST start). This is the most common point of failure if misconfigured.
Thorough Backtesting: Use MetaTrader 5's Strategy Tester extensively. Test on the specific symbols you intend to trade (like NQ, ES, GER40, XAUUSD).
Pay attention to the "Journal" tab in the tester for errors or print messages.
Verify the range is being identified correctly.
Check if entries trigger only after the M5 close as intended.
Ensure SL and TP levels are calculated and placed logically.
Test the Lot Size Calculation (CalculateLotSize): Verify it calculates reasonable lot sizes based on your risk settings and the SL distance for your specific broker and symbol. The value_per_point_one_lot logic might need tweaking depending on how your broker handles contract size, tick value, and calculation modes for different instruments (CFDs vs Futures vs Forex). Run tests with LOT_RISK_PERCENT enabled.
Optimization: Utilize the Strategy Tester's optimization feature to experiment with different input parameter values (especially Range Duration, TP levels, SL method settings, and time filters) to find potentially better combinations for your chosen symbol(s).
Forward Testing (Demo): After successful backtesting, run the EA on a demo account for a period to observe its behavior in live market conditions (spread, slippage, real-time execution) before considering real money.


*/
// For backward compatibility with MQL4 order types
#define OP_BUY ORDER_TYPE_BUY
#define OP_SELL ORDER_TYPE_SELL

// --- Input Parameters ---
input string         iSymbolToTrade               = "";                    // Symbol to Trade (empty for current chart)
input long           iMagicNumber                 = 123456;                // EA Magic Number
input int            iOpeningRangeDurationMinutes = 15;                    // ORB duration (minutes). Default: 15 (Playbit)
input string         iRangeStartTime              = "09:30";               // Range Start Time (HH:MM) - Broker Server Time!
input string         iTradeStartTime              = "09:45";               // Time to Start Looking for Breakouts (HH:MM) - Broker Server Time! (Should be >= Range End)
input string         iTradeEndTime                = "11:55";               // Time to Stop Looking for New Entries (HH:MM) - Broker Server Time!
input string         iHardCutoffTime              = "11:59";               // Time to Stop Range Break Attempts if Not Broken (HH:MM) - Broker Server Time! (Playbit 12:00 Rule)
input string         iCloseAllTradesTime          = "15:59";               // Time to Close All Open Trades (HH:MM) - Broker Server Time!
input ENUM_TIMEFRAMES iEntryConfirmationTimeframe = PERIOD_M5;             // Timeframe for Candle Close Confirmation. Default: M5 (Playbit crucial rule)
input bool           iUseStandardDeviationTP      = true;                  // Use Standard Deviation levels via Fib tool for TP? (Playbit)
input double         iStandardDeviationTPLevel    = -2.0;                  // Which StdDev level for TP (e.g., -2.0). Default: -2.0 (Playbit)
input bool           iUseEODClose                 = true;                  // If StdDev TP not hit, close at EoD? (SFI fallback)

enum StopLossMethod
{
   SL_RANGE_50_PERCENT, // Stop Loss at 50% of the M15 Range Candle (Playbit/Video)
   SL_ATR_PERCENT       // Stop Loss at % of ATR from Breakout Level (SFI inspired)
};
input StopLossMethod iStopLossMethod              = SL_RANGE_50_PERCENT;   // Stop Loss Method
input int            iATRPeriod                   = 14;                    // ATR Period (if using SL_ATR_PERCENT)
input double         iATRStopLossPercent          = 0.10;                  // Percent of ATR for Stop Loss (e.g., 0.10 = 10%)

enum LotSizeMode
{
   LOT_FIXED,        // Fixed Lot Size
   LOT_RISK_PERCENT  // Risk % of Account Equity/Balance
};
input LotSizeMode    iLotSizeMode                 = LOT_RISK_PERCENT;      // Lot Sizing Method
input double         iFixedLotSize                = 0.01;                  // Fixed Lot Size (if LOT_FIXED)
input double         iRiskPercentPerTrade         = 1.0;                   // Risk % per Trade (if LOT_RISK_PERCENT)
input int            iMaxSpreadPoints             = 100;                   // Maximum allowable spread (in points)
input ulong          iSlippagePoints              = 30;                    // Maximum allowable slippage (in points)
input bool           iDrawRangeLines              = true;                  // Draw ORB range lines on chart?
input bool           iDrawTPLevels                = true;                  // Draw TP level line on chart?

// Optional SFI Inspired Filters (can be kept disabled)
input double         iMinOpeningPrice             = 0.0;                   // Min Opening Price (0.0 = disabled)
input double         iMinATRValue                 = 0.0;                   // Min Daily ATR Value (0.0 = disabled)

// --- Global Variables ---
CTrade      trade;                        // Trade object instance
string      g_symbol;                     // Symbol being traded
int         g_timer_interval = 60;        // Timer interval in seconds (1 minute)
string      OBJ_PREFIX = "ORB_EA_" + IntegerToString(iMagicNumber) + "_"; // Prefix for chart objects

// Daily State Variables
double      g_rangeHigh = 0.0;            // Today's ORB High
double      g_rangeLow = 0.0;             // Today's ORB Low
bool        g_rangeDefinedToday = false;  // Flag: Is the ORB range set for today?
bool        g_tradeTakenToday = false;    // Flag: Has a trade been taken today?
bool        g_cutoffReached = false;      // Flag: Has the HardCutoffTime been reached without a break?
datetime    g_lastCheckTime = 0;          // Last time check for daily reset

// Range Candle Specifics (M15 candle ending the range)
double      g_rangeM15CandleHigh = 0.0;   // High of the specific M15 candle defining the range end
double      g_rangeM15CandleLow = 0.0;    // Low of the specific M15 candle defining the range end

// Time boundary datetimes for today
datetime    g_rangeStartTimeDT = 0;
datetime    g_rangeEndTimeDT = 0;
datetime    g_tradeStartTimeDT = 0;
datetime    g_tradeEndTimeDT = 0;
datetime    g_hardCutoffTimeDT = 0;
datetime    g_closeAllTradesTimeDT = 0;

// Daily ATR (if used)
double      g_dailyAtrValue = 0.0;


//+------------------------------------------------------------------+
//| Helper: Convert "HH:MM" string to datetime for today             |
//+------------------------------------------------------------------+
datetime StringToTimeOfDay(string timeStr)
{
   string parts[];
   if(StringSplit(timeStr, ':', parts) != 2)
   {
      Print("Error: Invalid time format '", timeStr, "'. Use HH:MM.");
      return 0;
   }

   int hours = (int)StringToInteger(parts[0]);
   int minutes = (int)StringToInteger(parts[1]);

   if(hours < 0 || hours > 23 || minutes < 0 || minutes > 59)
   {
      Print("Error: Invalid hour or minute in '", timeStr, "'.");
      return 0;
   }

   datetime today_start = TimeCurrent(); // Get current server time
   MqlDateTime dt;
   TimeToStruct(today_start, dt);
   dt.hour = hours;
   dt.min = minutes;
   dt.sec = 0; // Reset seconds

   return StructToTime(dt);
}

//+------------------------------------------------------------------+
//| Helper: Check for new day and reset daily variables              |
//+------------------------------------------------------------------+
void CheckNewDay()
{
   datetime currentTime = TimeCurrent();
   MqlDateTime dt_now, dt_last;
   TimeToStruct(currentTime, dt_now);
   TimeToStruct(g_lastCheckTime, dt_last);

   // If day has changed or EA just started
   if(dt_now.day != dt_last.day || g_lastCheckTime == 0)
   {
      Print("New Trading Day Detected: ", TimeToString(currentTime, TIME_DATE));
      g_rangeHigh = 0.0;
      g_rangeLow = 0.0;
      g_rangeM15CandleHigh = 0.0;
      g_rangeM15CandleLow = 0.0;
      g_rangeDefinedToday = false;
      g_tradeTakenToday = false;
      g_cutoffReached = false;
      g_dailyAtrValue = 0.0; // Reset daily ATR

      // Recalculate today's time boundaries based on input strings
      g_rangeStartTimeDT = StringToTimeOfDay(iRangeStartTime);
      g_rangeEndTimeDT = g_rangeStartTimeDT + (iOpeningRangeDurationMinutes * 60); // Calculate end time
      g_tradeStartTimeDT = StringToTimeOfDay(iTradeStartTime);
      g_tradeEndTimeDT = StringToTimeOfDay(iTradeEndTime);
      g_hardCutoffTimeDT = StringToTimeOfDay(iHardCutoffTime);
      g_closeAllTradesTimeDT = StringToTimeOfDay(iCloseAllTradesTime);

      // --- Input Time Validation ---
      if (g_rangeStartTimeDT == 0 || g_rangeEndTimeDT == 0 || g_tradeStartTimeDT == 0 ||
          g_tradeEndTimeDT == 0 || g_hardCutoffTimeDT == 0 || g_closeAllTradesTimeDT == 0)
      {
         Print("Error: One or more time inputs are invalid. EA Cannot Continue.");
         ExpertRemove();
         return;
      }
       if (g_tradeStartTimeDT < g_rangeEndTimeDT) {
          Print("Warning: Trade Start Time (", iTradeStartTime, ") is before Range End Time. Setting Trade Start Time to Range End Time.");
          g_tradeStartTimeDT = g_rangeEndTimeDT;
      }
       if (g_tradeEndTimeDT <= g_tradeStartTimeDT) {
           Print("Error: Trade End Time (", iTradeEndTime, ") must be after Trade Start Time (", TimeToString(g_tradeStartTimeDT, TIME_MINUTES),"). EA Cannot Continue.");
           ExpertRemove();
           return;
       }
       if (g_hardCutoffTimeDT < g_rangeEndTimeDT) {
           Print("Error: Hard Cutoff Time (", iHardCutoffTime, ") must be after Range End Time (", TimeToString(g_rangeEndTimeDT, TIME_MINUTES),"). EA Cannot Continue.");
           ExpertRemove();
           return;
       }
      if (g_closeAllTradesTimeDT <= g_tradeEndTimeDT) {
           Print("Error: Close All Trades Time (", iCloseAllTradesTime, ") must be after Trade End Time (", iTradeEndTime, "). EA Cannot Continue.");
           ExpertRemove();
           return;
      }


      // --- Pre-calculate daily ATR if needed ---
      if(iStopLossMethod == SL_ATR_PERCENT && iMinATRValue == 0.0) // Calculate only if used and not filtered by min value
      {
         double atr_buffer[1];
         if(CopyBuffer(iATR(g_symbol, PERIOD_D1, iATRPeriod), 0, 1, 1, atr_buffer) > 0) // Get yesterday's ATR
         {
             g_dailyAtrValue = atr_buffer[0];
             Print("Daily ATR for SL calculation: ", DoubleToString(g_dailyAtrValue, _Digits));
         }
         else
         {
             Print("Warning: Could not get Daily ATR value. ATR Stop Loss will not work.");
             g_dailyAtrValue = 0.0;
         }
      }


      // --- Remove old graphical objects ---
      ObjectsDeleteAll(0, OBJ_PREFIX, -1, -1);
      Print("Daily variables reset.");
   }
   g_lastCheckTime = currentTime; // Update last check time
}

//+------------------------------------------------------------------+
//| Helper: Define the Opening Range High/Low for today            |
//+------------------------------------------------------------------+
void DefineOpeningRange()
{
   if(g_rangeDefinedToday) return; // Already defined

   datetime currentTime = TimeCurrent();

   // Check if we are within the range definition window
   if(currentTime >= g_rangeStartTimeDT && currentTime < g_rangeEndTimeDT + g_timer_interval) // Add timer interval buffer
   {
       // Use M1 data for precise range finding within the exact time window
        int bars_m1 = Bars(g_symbol, PERIOD_M1, g_rangeStartTimeDT, currentTime);
        if (bars_m1 <= 0) return; // Not enough M1 bars yet

        double highs_m1[];
        double lows_m1[];
        ArrayResize(highs_m1, bars_m1);
        ArrayResize(lows_m1, bars_m1);

        if (CopyHigh(g_symbol, PERIOD_M1, 0, bars_m1, highs_m1) != bars_m1 ||
            CopyLow(g_symbol, PERIOD_M1, 0, bars_m1, lows_m1) != bars_m1)
        {
           Print("Error getting M1 High/Low data for range definition.");
           return;
        }

       double currentRangeHigh = highs_m1[ArrayMaximum(highs_m1)];
       double currentRangeLow = lows_m1[ArrayMinimum(lows_m1)];

       // Store the highest high and lowest low found so far within the window
       if(g_rangeHigh == 0.0 || currentRangeHigh > g_rangeHigh) g_rangeHigh = currentRangeHigh;
       if(g_rangeLow == 0.0 || currentRangeLow < g_rangeLow) g_rangeLow = currentRangeLow;

      // --- Finalize Range Definition ---
      if (currentTime >= g_rangeEndTimeDT && !g_rangeDefinedToday) // Finalize exactly at or after end time
      {
          if(g_rangeHigh > 0 && g_rangeLow > 0 && g_rangeHigh > g_rangeLow)
          {
              // Get the specific M15 candle data for anchoring SL/TP
              int bars_m15 = Bars(g_symbol, PERIOD_M15, g_rangeEndTimeDT - (iOpeningRangeDurationMinutes*60), g_rangeEndTimeDT); // Bars covering the range period
               if (bars_m15 > 0) {
                   // We need the candle that CLOSED at or just after g_rangeEndTimeDT
                   // The shift 1 corresponds to the most recently closed candle
                    g_rangeM15CandleHigh = iHigh(g_symbol, PERIOD_M15, 1);
                    g_rangeM15CandleLow  = iLow(g_symbol, PERIOD_M15, 1);

                   if (g_rangeM15CandleHigh > 0 && g_rangeM15CandleLow > 0)
                   {
                        g_rangeDefinedToday = true;
                        PrintFormat("ORB Range Defined [%s]: High=%.*f, Low=%.*f | M15 Anchor Candle H=%.*f, L=%.*f",
                           TimeToString(g_rangeEndTimeDT, TIME_MINUTES),
                           _Digits, g_rangeHigh, _Digits, g_rangeLow,
                           _Digits, g_rangeM15CandleHigh, _Digits, g_rangeM15CandleLow);

                        // --- Draw Lines ---
                        if(iDrawRangeLines)
                        {
                           string highLineName = OBJ_PREFIX + "RangeHigh";
                           string lowLineName = OBJ_PREFIX + "RangeLow";
                           ObjectCreate(0, highLineName, OBJ_HLINE, 0, g_rangeEndTimeDT, g_rangeHigh);
                           ObjectSetInteger(0, highLineName, OBJPROP_COLOR, clrOrangeRed);
                           ObjectSetInteger(0, highLineName, OBJPROP_WIDTH, 2);
                           ObjectSetInteger(0, highLineName, OBJPROP_STYLE, STYLE_SOLID);

                           ObjectCreate(0, lowLineName, OBJ_HLINE, 0, g_rangeEndTimeDT, g_rangeLow);
                           ObjectSetInteger(0, lowLineName, OBJPROP_COLOR, clrOrangeRed);
                           ObjectSetInteger(0, lowLineName, OBJPROP_WIDTH, 2);
                           ObjectSetInteger(0, lowLineName, OBJPROP_STYLE, STYLE_SOLID);
                        }
                         //--- Check Optional Filters ---
                         if (!CheckFilters()) {
                            Print("Filters not met. No trades will be taken today.");
                            g_cutoffReached = true; // Effectively disable trading for the day
                            g_rangeDefinedToday = false; // Allow redefinition tomorrow
                            return;
                         }

                    } else {
                         Print("Error getting M15 anchor candle High/Low.");
                         // Reset for safety? Or retry next tick? For now, just fail definition.
                          g_rangeHigh = 0; g_rangeLow = 0;
                    }
                } else {
                     Print("Error getting M15 bar count for anchor candle.");
                     g_rangeHigh = 0; g_rangeLow = 0;
                }
            } else {
                Print("Error: Invalid Range Found (High <= Low or zero). Range H=", g_rangeHigh, ", L=", g_rangeLow);
                 g_rangeHigh = 0; g_rangeLow = 0; // Reset to allow potential redefinition later if needed
            }
        }
     } else if (currentTime < g_rangeStartTimeDT) {
         // Too early to define range
         return;
     } else {
         // After range definition period but range not yet defined (e.g., error)
         // Print("Waiting for range definition period..."); // Avoid spamming log
     }

}

//+------------------------------------------------------------------+
//| Helper: Check and apply optional filters (SFI Inspired)         |
//+------------------------------------------------------------------+
bool CheckFilters()
{
    bool filtersPassed = true;

    // 1. Minimum Opening Price Filter
    if(iMinOpeningPrice > 0.0)
    {
       double openPrice = iOpen(g_symbol, Period(), 0); // Open of the current bar (approx market open)
       if(openPrice < iMinOpeningPrice)
       {
          Print("Filter Failed: Opening Price ", openPrice, " < Min Requirement ", iMinOpeningPrice);
          filtersPassed = false;
       }
    }

    // 2. Minimum Daily ATR Value Filter
    if(iMinATRValue > 0.0)
    {
       if (g_dailyAtrValue == 0) { // Needs recalculation if not done for SL
          double atr_buffer[1];
           if(CopyBuffer(iATR(g_symbol, PERIOD_D1, iATRPeriod), 0, 1, 1, atr_buffer) > 0) {
                g_dailyAtrValue = atr_buffer[0];
           } else {
                Print("Warning: Could not get Daily ATR for filtering.");
                // Decide how to handle this - fail filter or allow trade? Let's fail it.
                 filtersPassed = false;
           }
       }

       if(filtersPassed && g_dailyAtrValue < iMinATRValue)
       {
          Print("Filter Failed: Daily ATR ", g_dailyAtrValue, " < Min Requirement ", iMinATRValue);
          filtersPassed = false;
       }
    }

   // Add SFI Relative Volume / Top 20 logic here if implementing full SFI version
   // This would require significant extra data handling (historical 5-min volumes for past 14 days)
   // and potentially running on many symbols simultaneously or using a separate scanner script.
   // For this example, we are focusing on the Playbit core logic which is asset-specific.


    return filtersPassed;
}


//+------------------------------------------------------------------+
//| Helper: Check for Breakout Entry Signals                       |
//+------------------------------------------------------------------+
void CheckEntrySignals()
{
   // --- Guard Clauses ---
   if (!g_rangeDefinedToday || g_tradeTakenToday || g_cutoffReached) return;

   datetime currentTime = TimeCurrent();
   if (currentTime < g_tradeStartTimeDT || currentTime >= g_tradeEndTimeDT) return; // Outside allowed entry time window

   // --- Check Hard Cutoff ---
   if (currentTime >= g_hardCutoffTimeDT)
   {
       if (!g_cutoffReached) { // Print only once
         Print("Hard Cutoff Time (", TimeToString(g_hardCutoffTimeDT, TIME_MINUTES), ") reached without breakout. No new entries today.");
         g_cutoffReached = true;
       }
       return;
   }

   // --- Get Confirmation Candle Close ---
   double m5_close_buffer[1];
   // Get the close of the most recently *completed* M5 bar
   if (CopyClose(g_symbol, iEntryConfirmationTimeframe, 1, 1, m5_close_buffer) != 1)
   {
       Print("Error: Cannot get close price on ", EnumToString(iEntryConfirmationTimeframe));
       return;
   }
   double lastM5Close = m5_close_buffer[0];

   // --- Check for Buy Signal ---
   if(lastM5Close > g_rangeHigh && g_rangeHigh > 0) // Ensure range high is valid
   {
       PrintFormat("Buy Signal: M5 Close %.5f > Range High %.5f at %s", lastM5Close, g_rangeHigh, TimeToString(currentTime, TIME_SECONDS));
       if(PlaceTrade(OP_BUY)) // Attempt to place trade
       {
           g_tradeTakenToday = true; // Mark trade as taken for the day
           Print("Buy Trade Placed Successfully.");
       }
       return; // Don't check for sell if buy triggered
   }

   // --- Check for Sell Signal ---
   if(lastM5Close < g_rangeLow && g_rangeLow > 0) // Ensure range low is valid
   {
       PrintFormat("Sell Signal: M5 Close %.5f < Range Low %.5f at %s", lastM5Close, g_rangeLow, TimeToString(currentTime, TIME_SECONDS));
       if(PlaceTrade(OP_SELL)) // Attempt to place trade
       {
           g_tradeTakenToday = true; // Mark trade as taken for the day
            Print("Sell Trade Placed Successfully.");
       }
       return;
   }
}

//+------------------------------------------------------------------+
//| Helper: Calculate Stop Loss Price based on method              |
//+------------------------------------------------------------------+
double CalculateStopLossPrice(ENUM_ORDER_TYPE orderType)
{
   double slPrice = 0.0;
   double point = _Point; // Or SymbolInfoDouble(g_symbol, SYMBOL_POINT);

   switch(iStopLossMethod)
   {
      case SL_RANGE_50_PERCENT:
         // Anchor SL based on the *M15 candle* defining the range end (as per Playbit video/slides context)
         if (g_rangeM15CandleHigh > 0 && g_rangeM15CandleLow > 0 && g_rangeM15CandleHigh > g_rangeM15CandleLow)
         {
            // Using the 0.5 fib/stdev level equivalent = midpoint of the M15 anchor candle
            double midPoint = (g_rangeM15CandleHigh + g_rangeM15CandleLow) / 2.0;
             slPrice = midPoint; // Set SL exactly at the 50% level of the M15 candle
             PrintFormat("SL Method: M15 50%%. Anchor H=%.*f, L=%.*f -> SL Price=%.*f",
                _Digits, g_rangeM15CandleHigh, _Digits, g_rangeM15CandleLow, _Digits, slPrice);
         } else {
             Print("Error: Cannot calculate SL_RANGE_50_PERCENT - Invalid M15 anchor candle range.");
             return 0.0; // Invalid
         }
         break;

      case SL_ATR_PERCENT:
      {
         if (g_dailyAtrValue <= 0.0 || iATRStopLossPercent <= 0.0)
         {
            Print("Error: Cannot calculate SL_ATR_PERCENT - Invalid ATR value (", g_dailyAtrValue, ") or ATR Percent (", iATRStopLossPercent, ")");
            return 0.0; // Invalid
         }
         double atr_stop_offset = g_dailyAtrValue * iATRStopLossPercent;
         // Calculate SL relative to the breakout level (g_rangeHigh/Low), not the exact entry point
         // (SFI paper calculated from entry, but entry price isn't known precisely before OrderSend)
         if(orderType == OP_BUY)
         {
             slPrice = g_rangeHigh - atr_stop_offset; // SL below the breakout high
         }
         else // OP_SELL
         {
             slPrice = g_rangeLow + atr_stop_offset; // SL above the breakout low
         }
         PrintFormat("SL Method: ATR Percent. Break Level=%.*f, ATR=%.*f, ATR Pct=%.2f -> Offset=%.*f -> SL Price=%.*f",
             _Digits, (orderType == OP_BUY ? g_rangeHigh : g_rangeLow),
             _Digits, g_dailyAtrValue, iATRStopLossPercent * 100.0,
             _Digits, atr_stop_offset, _Digits, slPrice);
         break;
      }

      default:
          Print("Error: Unknown Stop Loss Method");
          return 0.0;
   }

   // Basic validity check & normalization
   slPrice = NormalizeDouble(slPrice, _Digits);
   // Ensure SL is meaningfully different from potential entry level (avoid immediate stop out)
   double currentPrice = (orderType == OP_BUY ? SymbolInfoDouble(g_symbol, SYMBOL_ASK) : SymbolInfoDouble(g_symbol, SYMBOL_BID));
   if (orderType == OP_BUY && slPrice >= currentPrice - (2 * point) ) {
      Print("Warning: Buy SL Price ", slPrice, " too close to current Bid ", currentPrice, ". Potential immediate stop. Adjusting slightly lower.");
       slPrice = slPrice - (3 * point); // Adjust slightly more
       slPrice = NormalizeDouble(slPrice, _Digits);
   } else if (orderType == OP_SELL && slPrice <= currentPrice + (2 * point)) {
       Print("Warning: Sell SL Price ", slPrice, " too close to current Ask ", currentPrice, ". Potential immediate stop. Adjusting slightly higher.");
       slPrice = slPrice + (3 * point); // Adjust slightly more
       slPrice = NormalizeDouble(slPrice, _Digits);
   }

   if (slPrice <= 0) {
      Print("Error: Calculated SL Price is invalid (zero or negative).");
      return 0.0;
   }


   return slPrice;
}

//+------------------------------------------------------------------+
//| Helper: Get price value at specific Fibonacci level (MQL5 replacement)  |
//+------------------------------------------------------------------+
double ObjectGetValueByLevel(string obj_name, double level)
{
   // Get the object's Fibonacci lines coordinates
   double price1 = ObjectGetDouble(0, obj_name, OBJPROP_PRICE, 0);  // First line price
   double price2 = ObjectGetDouble(0, obj_name, OBJPROP_PRICE, 1);  // Second line price

   if(price1 == 0 || price2 == 0)
   {
      Print("Error getting Fibonacci prices from object ", obj_name);
      return 0.0;
   }

   // Calculate the price at the specific level based on the Fibonacci calculation
   double price_range = price2 - price1;
   double level_price = price1 + (price_range * level);
   
   return level_price;
}

//+------------------------------------------------------------------+
//| Helper: Calculate Take Profit using StdDev via Fib Tool        |
//+------------------------------------------------------------------+
double CalculateTakeProfitPrice(ENUM_ORDER_TYPE orderType, double currentMarketPrice)
{
   if (!iUseStandardDeviationTP || !g_rangeDefinedToday || g_rangeM15CandleHigh <= g_rangeM15CandleLow) {
      return 0.0; // TP disabled or range invalid
   }

   string fib_obj_name = OBJ_PREFIX + "TempFiboTP_" + TimeToString(TimeCurrent(), TIME_SECONDS);
   datetime time1, time2;
   double price1, price2;
   double tpPrice = 0.0; // Declare tpPrice at the beginning of the function

   // Anchor to the M15 Range candle High/Low
   int anchor_shift = 1; // Use the closed M15 bar that defined the range
   time1 = iTime(g_symbol, PERIOD_M15, anchor_shift);
   time2 = iTime(g_symbol, PERIOD_M15, anchor_shift + 2); // Need a small time difference for Fibo


   double range_size = MathAbs(g_rangeM15CandleHigh - g_rangeM15CandleLow);

   if (range_size <= 0) {
      Print("Warning: M15 Anchor Candle range size is zero or negative. Cannot calculate TP.");
      return 0.0;
   }

   if(orderType == OP_BUY)
   {
      // Anchor Low to High for Buy TP projections (expecting negative levels for upside)
      price1 = g_rangeM15CandleLow;
      price2 = g_rangeM15CandleHigh;
      tpPrice = g_rangeM15CandleHigh - (range_size * iStandardDeviationTPLevel);

      
   }
   else // OP_SELL
   {
       // Project DOWNWARDS from the M15 LOW. Note: iStandardDeviationTPLevel is negative by default (-2.0)
       // So, Low + (Range * Negative Level) = Low - (Range * Positive Level Magnitude)
       if (iStandardDeviationTPLevel > 0) Print("Warning: Positive StdDev TP Level provided for a Sell signal. Using magnitude negatively.");
       // Ensure we use the absolute value if user accidentally puts positive, but keep direction negative.
       tpPrice = g_rangeM15CandleLow - (range_size * MathAbs(iStandardDeviationTPLevel));
   }

   // --- Create and Configure Fibo Object ---
   // Note: We're creating the Fibo object mainly for visualization/debugging purposes
   // since we now calculate tpPrice directly
   if (!ObjectCreate(0, fib_obj_name, OBJ_FIBO, 0, time1, price1, time2, price2))
   {
      Print("Error: Could not create Fibo object for TP calculation: ", GetLastError());
      // Don't return 0.0 here, as we've already calculated tpPrice directly
   }
   else {
      // Set properties
      ObjectSetInteger(0, fib_obj_name, OBJPROP_RAY_RIGHT, false); // Don't extend infinitely
      // Ensure enough levels exist (MQL5 default is often limited)
      ObjectSetInteger(0, fib_obj_name, OBJPROP_LEVELS, 15); // Set a generous number of levels

      // Define the custom Standard Deviation Levels (based on Playbit guide image)
      // IMPORTANT: OBJPROP_FIBOLEVELS takes INDEX first, then VALUE
      // Standard levels + deviations (can customize further)
      double levels[] = {0.0, 0.5, 1.0, -0.5, -1.0, -1.5, -2.0, -2.5, -3.0};
      string labels[] = {"0.0 (Anchor)", "0.5", "1.0 (Anchor)", "-0.5 SD", "-1.0 SD", "-1.5 SD", "-2.0 SD", "-2.5 SD", "-3.0 SD"};

      for(int i = 0; i < ArraySize(levels); i++)
      {
          ObjectSetDouble(0, fib_obj_name, OBJPROP_LEVELVALUE, i, levels[i]);
          ObjectSetString(0, fib_obj_name, OBJPROP_LEVELTEXT, i, labels[i]);
          // ObjectSetInteger(0, fib_obj_name, OBJPROP_LEVELCOLOR, i, clrMediumSeaGreen); // Optional color
          // ObjectSetInteger(0, fib_obj_name, OBJPROP_LEVELSTYLE, i, STYLE_DOT);         // Optional style
      }
   }

   // --- No need to get price from object as we calculated it directly ---
   // double tpPrice = ObjectGetValueByLevel(fib_obj_name, iStandardDeviationTPLevel);
   PrintFormat("Calculated TP using StdDev projection: Range=%.*f, Target Level=%.2f -> TP Price=%.*f",
        _Digits, range_size, iStandardDeviationTPLevel, _Digits, tpPrice);

   // --- Clean up the temporary Fibo object ---
   ObjectDelete(0, fib_obj_name);//?

   // --- Validate and Normalize TP Price ---
   tpPrice = NormalizeDouble(tpPrice, _Digits);

   if (tpPrice <= 0) {
      Print("Warning: Calculated TP Price is invalid (zero or negative): ", tpPrice);
      return 0.0;
   }

      // Ensure TP is on the correct side of the current market price
    if (orderType == OP_BUY && tpPrice <= currentMarketPrice) {
       Print("Warning: Buy TP Price ", DoubleToString(tpPrice, _Digits), " is not above current Ask ", DoubleToString(currentMarketPrice,_Digits), ". Setting TP to 0 (disabled).");
       return 0.0;
   } else if (orderType == OP_SELL && tpPrice >= currentMarketPrice) {
        Print("Warning: Sell TP Price ", DoubleToString(tpPrice, _Digits), " is not below current Bid ", DoubleToString(currentMarketPrice,_Digits), ". Setting TP to 0 (disabled).");
        return 0.0;
   }


    // Draw TP Line if enabled
    // if(iDrawTPLevels && tpPrice > 0)
    // {
    //    string tpLineName = OBJ_PREFIX + "TPLevel_" + (orderType == OP_BUY ? "B" : "S");
    //    if (!ObjectCreate(0, tpLineName, OBJ_HLINE, 0, TimeCurrent(), tpPrice)) {
    //       Print("Failed to create TP line object: ", GetLastError());
    //    } else {
    //        ObjectSetInteger(0, tpLineName, OBJPROP_COLOR, clrGreen);
    //        ObjectSetInteger(0, tpLineName, OBJPROP_WIDTH, 1);
    //        ObjectSetInteger(0, tpLineName, OBJPROP_STYLE, STYLE_DOT);
    //    }
    // }
    if(iDrawTPLevels && tpPrice > 0)
    {
       string tpLineName = OBJ_PREFIX + "TPLevel_" + (orderType == OP_BUY ? "B" : "S");
       if(ObjectFind(0, tpLineName) < 0) // Create only if it doesn't exist
       {
           if (!ObjectCreate(0, tpLineName, OBJ_HLINE, 0, TimeCurrent(), tpPrice)) {
              Print("Failed to create TP line object: ", GetLastError());
           } else {
               ObjectSetInteger(0, tpLineName, OBJPROP_COLOR, clrGreen);
               ObjectSetInteger(0, tpLineName, OBJPROP_WIDTH, 1);
               ObjectSetInteger(0, tpLineName, OBJPROP_STYLE, STYLE_DOT);
               ChartRedraw(); // Redraw chart to show the line immediately
           }
       } else { // Update existing line if needed
           ObjectSetDouble(0, tpLineName, OBJPROP_PRICE, 0, tpPrice);
           ObjectSetInteger(0, tpLineName, OBJPROP_TIME, 0, TimeCurrent()); // Update time maybe? Optional.
           ChartRedraw();
       }
    }

   return tpPrice;
}

//+------------------------------------------------------------------+
//| Helper: Calculate Lot Size based on Risk %                     |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLossPrice, double entryPriceGuess)
{
   if (iLotSizeMode == LOT_FIXED)
   {
      return(NormalizeDouble(iFixedLotSize, 2)); // Normalize fixed lots too
   }

   // --- Risk % Calculation ---
   if (iRiskPercentPerTrade <= 0)
   {
       Print("Error: Risk Percent must be greater than 0 for LOT_RISK_PERCENT mode.");
       return 0.0;
   }

   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE); // Or ACCOUNT_EQUITY
   if (account_balance <= 0)
   {
       Print("Error: Invalid account balance: ", account_balance);
       return 0.0;
   }

   double risk_amount_currency = account_balance * (iRiskPercentPerTrade / 100.0);
   double sl_distance_price = MathAbs(entryPriceGuess - stopLossPrice);

   if(sl_distance_price <= SymbolInfoDouble(g_symbol, SYMBOL_POINT)) // Avoid division by zero or tiny SL
   {
      Print("Error: Stop loss distance too small: ", sl_distance_price);
      return 0.0;
   }

   // Calculate value per point move for 1 lot
    double tick_value = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_VALUE);
    double tick_size = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_SIZE);
    double point_size = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
    double volume_step = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_STEP);
    double contract_size = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_CONTRACT_SIZE);
    long calc_mode = SymbolInfoInteger(g_symbol, SYMBOL_TRADE_CALC_MODE);
    
    // Get volume precision for normalization
    // long vol_digits = 0;
    // if(!SymbolInfoInteger(g_symbol, SYMBOL_VOLUME_LIMIT, vol_digits) || vol_digits == 0)
    // {
    //     vol_digits = 2; // Default to 2 digits precision if not available
    // }

    if (tick_value <= 0 || tick_size <= 0 || point_size <= 0 || volume_step <= 0 ) {
        Print("Error: Invalid symbol info for lot calculation (TickValue/TickSize/Point/VolStep)");
        return 0.0;
    }

   double sl_distance_points = sl_distance_price / point_size;
   double value_per_point_one_lot;

   // How tick value is defined depends on the symbol/broker
    if (calc_mode == SYMBOL_CALC_MODE_FUTURES) {
       value_per_point_one_lot = tick_value / (tick_size / point_size); // For Futures typically
    } else if (calc_mode == SYMBOL_CALC_MODE_CFD || calc_mode == SYMBOL_CALC_MODE_FOREX) {
       value_per_point_one_lot = tick_value * contract_size * point_size / tick_size; // Adjust for Forex/CFD potentially (Test this)
        // This might need conversion based on quote/deposit currency if different
    }
     else { // Default attempt, might need adjustments based on broker specifics
        value_per_point_one_lot = tick_value / (tick_size/ point_size); // Assuming similar to futures - VERIFY THIS PER SYMBOL/BROKER
        Print("Warning: Symbol Calc Mode not explicitly handled for Futures/CFD/Forex - Lot size calculation might be approximate. Mode: ", calc_mode);
    }

   if(value_per_point_one_lot <= 0) {
        Print("Error calculating value per point for 1 lot: ", value_per_point_one_lot);
        return 0.0;
   }


   double loss_per_lot = sl_distance_points * value_per_point_one_lot;

   if(loss_per_lot <= 0)
   {
       Print("Error: Calculated loss per lot is zero or negative.");
       return 0.0;
   }

   double desired_lots = risk_amount_currency / loss_per_lot;

   // Normalize and check Min/Max volume
    double normalized_lots = MathRound(desired_lots / volume_step) * volume_step;
    
       int vol_norm_digits = (int)MathMax(0,MathLog10(1.0 / volume_step)); // Calculate digits from step
    normalized_lots = NormalizeDouble(normalized_lots, vol_norm_digits); // Normalize to step precision

    normalized_lots = MathMax(SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MIN), normalized_lots);
    normalized_lots = MathMin(SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MAX), normalized_lots);


 // Final sanity check
   if (normalized_lots < SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MIN)) {
        Print("Warning: Calculated lot size ", normalized_lots, " is below minimum ", SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MIN), ". Setting to minimum.");
       normalized_lots = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MIN);
   }


 PrintFormat("Lot Size Calc Final: Balance=%.2f, Risk Pct=%.2f%%, Risk Amt=%.2f, SL Dist=%.*f, Value/Point/Lot=%.4f, Loss/Lot=%.2f -> Desired Lots=%.4f, Final Lots=%.*f",
                account_balance, iRiskPercentPerTrade, risk_amount_currency,
                _Digits, sl_distance_price, value_per_point_one_lot, loss_per_lot,
                desired_lots, vol_norm_digits, normalized_lots); // Use calculated digits for final lot size printing


   return(normalized_lots);
}


//+------------------------------------------------------------------+
//| Helper: Place the actual trade order                           |
//+------------------------------------------------------------------+
bool PlaceTrade(ENUM_ORDER_TYPE orderType)
{
   // --- Check Spread ---
   long spread = SymbolInfoInteger(g_symbol, SYMBOL_SPREAD);
   if(spread > iMaxSpreadPoints)
   {
      Print("Trade execution stopped: Spread (", spread, ") > Max Spread (", iMaxSpreadPoints, ")");
      return false;
   }

   // --- Get Current Prices for Calc ---
   double ask = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(g_symbol, SYMBOL_BID);
   double entryPrice = (orderType == OP_BUY) ? ask : bid;

   // --- Calculate SL ---
   double slPrice = CalculateStopLossPrice(orderType);
   if (slPrice <= 0.0)
   {
       Print("Error: Invalid Stop Loss calculated. Cannot place trade.");
       return false;
   }
    // Ensure SL is valid relative to market price for OrderSend
    if(orderType == OP_BUY && slPrice >= bid) // For BUY, SL must be BELOW current BID
    {
        Print("Error: Calculated Buy SL price ", slPrice, " is not below current Bid price ", bid);
        // Could attempt small adjustment, but safer to abort if fundamentally wrong
        return false;
    }
    if(orderType == OP_SELL && slPrice <= ask) // For SELL, SL must be ABOVE current ASK
    {
        Print("Error: Calculated Sell SL price ", slPrice, " is not above current Ask price ", ask);
        return false;
    }


   // --- Calculate TP ---
   double tpPrice = CalculateTakeProfitPrice(orderType, entryPrice); // Pass entry guess
    // If tpPrice is 0, it means either disabled or couldn't calculate
    if (iUseStandardDeviationTP && tpPrice <= 0.0)
    {
        Print("Warning: Could not calculate Standard Deviation TP. Setting TP to 0 (disabled for this trade).");
        // Fallback to EoD close if enabled
        if (!iUseEODClose) {
             Print("Error: StdDev TP failed and EoD Close is disabled. No TP set - trade risky. Aborting placement.");
             return false;
        }
        tpPrice = 0.0; // Ensure TP is 0 for OrderSend if calc failed but EoD is fallback
    }
    else if (!iUseStandardDeviationTP)
    {
         tpPrice = 0.0; // Set to 0 if explicitly disabled
    }


   // --- Calculate Lot Size ---
   double lotSize = CalculateLotSize(slPrice, entryPrice);
   if(lotSize <= 0.0)
   {
      Print("Error: Invalid Lot Size calculated. Cannot place trade.");
      return false;
   }

   // Declare the margin variable
   double margin;
   
   // Debug parameters before attempting margin calculation
   Print("--- Margin Calculation Parameters ---");
   Print("Order Type: ", EnumToString(orderType));
   Print("Symbol: \"", g_symbol, "\"");
   Print("Lot Size: ", DoubleToString(lotSize, 2));
   Print("Entry Price: ", DoubleToString(entryPrice, _Digits));
   Print("---------------------------------");

   // --- Check Free Margin ---
   if(!OrderCalcMargin(orderType, g_symbol, lotSize, entryPrice, margin))
   {
       Print("Error in OrderCalcMargin: ", GetLastError());
       return false;
   }

   // Check if g_symbol is valid
   if(g_symbol == "" || g_symbol == NULL)
   {
       Print("Critical Error: Symbol variable is empty when calculating margin!");
       
       // Try to recover the symbol
       g_symbol = Symbol();
       if(g_symbol == "" || g_symbol == NULL)
       {
           Print("Failed to recover symbol. Aborting trade.");
           return false;
       }
       else
       {
           Print("Recovered symbol: ", g_symbol);
       }
   }
   
   // Ensure symbol is still selected in Market Watch
   if(!SymbolInfoInteger(g_symbol, SYMBOL_SELECT))
   {
       Print("Warning: Symbol ", g_symbol, " is not selected in Market Watch. Attempting to select it.");
       SymbolSelect(g_symbol, true);
   }
   
   // Debug symbol information
   Print("Symbol status before margin calculation:");
   Print("- Exists: ", SymbolInfoInteger(g_symbol, SYMBOL_EXIST) ? "Yes" : "No");
   Print("- Selected: ", SymbolInfoInteger(g_symbol, SYMBOL_SELECT) ? "Yes" : "No");
   
   // Reset any previous error
   ResetLastError();

   // --- Calculate Margin ---
   if(!OrderCalcMargin(orderType, g_symbol, lotSize, entryPrice, margin))
   {
       int error_code = GetLastError();
       Print("Error in OrderCalcMargin: ", error_code);
       
       // Try with direct Symbol() as fallback
       if(g_symbol != _Symbol)
       {
           Print("Trying with chart symbol as fallback...");
           ResetLastError();
           if(!OrderCalcMargin(orderType, _Symbol, lotSize, entryPrice, margin))
           {
               error_code = GetLastError();
               Print("Also failed with _Symbol. Error: ", error_code);
               return false;
           }
           else
           {
               Print("Successfully calculated margin using chart symbol: ", margin);
           }
       }
       else
       {
           return false;
       }
   }
   else
   {
       Print("Successfully calculated margin: ", margin);
   }

   if(AccountInfoDouble(ACCOUNT_MARGIN_FREE) < margin)
   {
       Print("Trade execution stopped: Insufficient free margin. Required: ", margin, ", Available: ", AccountInfoDouble(ACCOUNT_MARGIN_FREE));
       return false;
   }


   // --- Execute Trade ---
   Print("Attempting to place ", EnumToString(orderType), " order. Lots=", lotSize, " SL=", slPrice, " TP=", tpPrice);
   bool result = false;
   string comment = "Optimized ORB EA";

   if (orderType == OP_BUY)
   {
      result = trade.Buy(lotSize, g_symbol, ask, slPrice, tpPrice, comment);
   }
   else if (orderType == OP_SELL)
   {
       result = trade.Sell(lotSize, g_symbol, bid, slPrice, tpPrice, comment);
   }

   if(!result)
   {
      Print("OrderSend failed: Error ", trade.ResultRetcode(), " - ", trade.ResultComment());
      return false;
   }

   return true;
}


//+------------------------------------------------------------------+
//| Helper: Manage Open Trade (EoD Close, etc.)                    |
//+------------------------------------------------------------------+
void ManageOpenTrade()
{
    // Check only if a trade *might* have been taken today OR if range was defined
    // More robust check: loop through open positions
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            // Check if it's our EA's position and for the correct symbol
            if(PositionGetInteger(POSITION_MAGIC) == iMagicNumber &&
               PositionGetString(POSITION_SYMBOL) == g_symbol)
            {
                datetime currentTime = TimeCurrent();

                // Check for End-of-Day Close condition
                if ((iUseEODClose || !iUseStandardDeviationTP) && // Close if EOD is on, OR if StdDev TP was disabled/failed
                     currentTime >= g_closeAllTradesTimeDT)
                {
                     Print("Closing trade ", ticket, " due to End-of-Day Time (", TimeToString(g_closeAllTradesTimeDT, TIME_MINUTES), ")");
                     if(!trade.PositionClose(ticket, iSlippagePoints))
                     {
                         Print("Failed to close position ", ticket, " at EoD: ", trade.ResultRetcode(), " - ", trade.ResultComment());
                         // Consider retry logic if critical
                     } else {
                         g_tradeTakenToday = false; // Allow new trades next valid day even if closed at EOD
                         Print("Position ", ticket, " closed successfully at EoD.");
                         // Important: If EoD close happens, make sure g_tradeTakenToday allows trading tomorrow.
                         // CheckNewDay should handle this reset.
                     }
                     // No further management needed for this position once close attempt is made
                     return;
                 }

                 // --- Optional Advanced: Implement Trailing Stop Logic here ---
                 // e.g., if UseTrailingStop = true
                 // Check if profit reached certain level (e.g. +1 Std Dev or positive R value)
                 // If yes, trade.StopLossModify(ticket, newSLPrice);

            }
        }
    }
}


//+------------------------------------------------------------------+
//| Expert Initialization Function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("--- Optimized ORB EA v1 Initializing ---");
   
   // More robust symbol initialization
   g_symbol = (iSymbolToTrade == "" ? _Symbol : iSymbolToTrade); // Use chart symbol if input is empty
   
   if(g_symbol == "" || g_symbol == NULL)
   {
      Print("Error: No valid symbol specified! Using current chart symbol.");
      g_symbol = Symbol();
   }
   
   if(g_symbol == "" || g_symbol == NULL)
   {
      Print("Critical Error: Cannot determine a valid symbol. EA cannot continue.");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   // Make sure symbol exists and is selected in Market Watch
   if(!SymbolSelect(g_symbol, true))
   {
      Print("Warning: Could not select symbol ", g_symbol, " in Market Watch. Using anyway, but check if symbol exists.");
   }
   
   Print("Successfully initialized with Symbol: ", g_symbol);
    
   // --- Basic Setup ---
   trade.SetExpertMagicNumber(iMagicNumber);
   trade.SetMarginMode();                     // Use account's default margin mode
   if (!trade.SetTypeFillingBySymbol(g_symbol)) // Set filling type based on symbol properties
   {
        Print("Error setting order filling type for symbol ", g_symbol);
       // Attempt default anyway? Or fail? Let's try default.
       trade.SetTypeFilling(ORDER_FILLING_FOK); // Or IOC, depending on common broker types
   }
   trade.SetDeviationInPoints(iSlippagePoints); // Set allowed slippage

   // --- Input Validation (Add more checks as needed) ---
    if (iOpeningRangeDurationMinutes <= 0) {
        Print("Error: Opening Range Duration must be positive."); return(INIT_PARAMETERS_INCORRECT);
    }
   if(iLotSizeMode == LOT_FIXED && iFixedLotSize <= 0) {
      Print("Error: Fixed Lot Size must be positive."); return(INIT_PARAMETERS_INCORRECT);
   }
   if(iLotSizeMode == LOT_RISK_PERCENT && iRiskPercentPerTrade <= 0) {
       Print("Error: Risk Percent must be positive."); return(INIT_PARAMETERS_INCORRECT);
   }

    Print("Symbol: ", g_symbol);
    Print("Magic Number: ", iMagicNumber);
    Print("ORB Duration: ", iOpeningRangeDurationMinutes, " mins");
    Print("Range Start Time: ", iRangeStartTime);
    Print("Range End Time (Calculated): ", TimeToString(StringToTimeOfDay(iRangeStartTime) + (iOpeningRangeDurationMinutes*60), TIME_MINUTES)); // Show calculated end
    Print("Trade Start Time: ", iTradeStartTime);
    Print("Trade End Time: ", iTradeEndTime);
    Print("Hard Cutoff Time: ", iHardCutoffTime);
    Print("EoD Close Time: ", iCloseAllTradesTime);
    Print("Entry Confirmation TF: ", EnumToString(iEntryConfirmationTimeframe));
    Print("Use StdDev TP: ", (iUseStandardDeviationTP ? "Yes, Level=" + DoubleToString(iStandardDeviationTPLevel) : "No"));
    Print("Use EoD Close: ", (iUseEODClose ? "Yes" : "No"));
    Print("SL Method: ", EnumToString(iStopLossMethod));
   if (iStopLossMethod == SL_ATR_PERCENT) Print(" - ATR Period: ", iATRPeriod, ", ATR SL Pct: ", iATRStopLossPercent * 100.0, "%");
   Print("Lot Size Mode: ", EnumToString(iLotSizeMode));
   if (iLotSizeMode == LOT_FIXED) Print(" - Fixed Lots: ", iFixedLotSize);
   if (iLotSizeMode == LOT_RISK_PERCENT) Print(" - Risk %: ", iRiskPercentPerTrade);


   // --- Set Timer ---
   if(!EventSetTimer(g_timer_interval))
   {
      Print("Error setting timer!");
      return(INIT_FAILED);
   }
   Print("Timer set for every ", g_timer_interval, " seconds.");
   // Initial check to set correct day's times
    g_lastCheckTime = 0; // Force CheckNewDay to run on first timer event
    CheckNewDay();

   Print("--- Initialization Complete ---");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert Deinitialization Function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("--- Optimized ORB EA Deinitializing --- Reason: ", reason);
   EventKillTimer();
   Print("Timer stopped.");
   // --- Remove chart objects ---
    ObjectsDeleteAll(0, OBJ_PREFIX, -1, -1);
   Print("Chart objects removed.");
   Print("--- Deinitialization Complete ---");
}

//+------------------------------------------------------------------+
//| Expert Timer Function                                            |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Check connection and trade permission
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !TerminalInfoInteger(TERMINAL_CONNECTED))
   {
      // Optional: Add a check to avoid running logic excessively when disconnected/disabled
       // static datetime last_warn_time = 0;
       // if (TimeCurrent() - last_warn_time > 300) { // Warn every 5 mins
       //    Print("Warning: Trading disabled or terminal disconnected.");
       //    last_warn_time = TimeCurrent();
       // }
      return;
   }

   // Use a simple mutex or check if processing already
    static bool isProcessing = false;
    if (isProcessing) return;
    isProcessing = true;

   // Verify g_symbol integrity
   if(g_symbol == "" || g_symbol == NULL)
   {
      Print("WARNING: g_symbol is empty in OnTimer! Attempting to restore...");
      g_symbol = (iSymbolToTrade == "" ? Symbol() : iSymbolToTrade);
      
      if(g_symbol == "" || g_symbol == NULL)
      {
         Print("ERROR: Could not restore g_symbol in OnTimer. Trading might fail!");
      }
      else
      {
         Print("Successfully restored g_symbol to: ", g_symbol);
         SymbolSelect(g_symbol, true); // Ensure it's selected
      }
   }

   // --- Core Logic ---
   CheckNewDay();          // Handle daily resets first
   DefineOpeningRange();   // Attempt to define range if not already done
   CheckEntrySignals();    // Check for entry signals if range is defined
   ManageOpenTrade();      // Check for EoD close or other management

    // --- Release Mutex ---
   isProcessing = false;
}

//+------------------------------------------------------------------+
//| Trade Event Function (Optional - For handling SL/TP hits etc.)   |
//+------------------------------------------------------------------+
/*
void OnTradeTransaction(const MqlTradeTransaction &trans,
                       const MqlTradeRequest &request,
                       const MqlTradeResult &result)
{
   // This function is called when trade events happen (order filled, SL/TP hit, closed)
   // Useful for more complex state management if needed.
   // Example: Detect if our trade was closed by SL/TP vs EoD.
   if (trans.type == TRADE_TRANSACTION_DEAL_ADD && trans.magic == iMagicNumber && trans.symbol == g_symbol)
   {
      if(trans.entry == ENTRY_IN || trans.entry == ENTRY_OUT || trans.entry == ENTRY_INOUT ) { // Deals modifying position
          // Check deal reason for SL/TP hit if needed
          ulong deal_ticket = trans.deal;
           if (HistoryDealSelect(deal_ticket)) {
               long reason = HistoryDealGetInteger(deal_ticket, DEAL_REASON);
                if (reason == DEAL_REASON_SL) {
                    Print("Position closed by Stop Loss. Ticket: ", HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID));
                   g_tradeTakenToday = false; // Ready for next day if stopped out
               } else if (reason == DEAL_REASON_TP) {
                    Print("Position closed by Take Profit. Ticket: ", HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID));
                   g_tradeTakenToday = false; // Ready for next day if TP hit
               } else if (reason == DEAL_REASON_CLOSE) {
                  // Could be manual close or EA close (like EoD)
                   Print("Position closed (Reason: Close). Ticket: ", HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID));
                   // If it's our EoD close, CheckNewDay should handle g_tradeTakenToday reset.
                   // If manual close, maybe keep g_tradeTakenToday = true to prevent re-entry? Decide policy.
                   // Let's assume EoD handles it or it's manual intervention. Allow new trades next day.
                    g_tradeTakenToday = false;
               }
          }
      }
       if(trans.entry == ENTRY_IN && PositionGetInteger(POSITION_TICKET)>0) // Entry deal resulted in an open position
       {
         // Could recalculate more precise TP here if StdDev Fib method was deferred
         Print("Deal executed for order ",trans.order,", Position: ",trans.position);
       }
    }
     // Handle order placement results, modify confirmations etc. here if needed.
}
*/
//+------------------------------------------------------------------+