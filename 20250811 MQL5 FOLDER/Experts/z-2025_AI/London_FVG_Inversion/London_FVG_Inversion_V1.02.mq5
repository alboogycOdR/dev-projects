//+------------------------------------------------------------------+
//|                                    London_FVG_Inversion_V1.mq5 |
//|                        Copyright 2023, Generated from Strategy |
//|                                              Strategy Developer |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Generated from Strategy"
#property link      "None"
#property version   "1.02" // Incremented version (FVG Drawing Added)
#property strict

#include <Trade\Trade.mqh> // Trading class
#include <Object.mqh>     // For ObjectDelete convenience (optional but good practice)
/*
V1.02

fvgObjectName (Global): Stores a unique name for the rectangle.
OnInit: Creates this unique name.
ResetDailyVariables: Now includes ObjectDelete(0, fvgObjectName); to clear the old rectangle from the previous day.
DrawFVGRectangle() Function:
Checks if the FVG has been found for the day (fvgFoundToday && fvgCompletionTime != 0) and if the rectangle doesn't already exist (ObjectFind(...) < 0).
Calculates an endTime for the rectangle to make it extend into the future for visibility.
Uses ObjectCreate() to draw the rectangle with the globally stored fvgHigh, fvgLow, and fvgCompletionTime.
Sets visual properties (color, style, fill, background) using ObjectSetInteger() based on input parameters.
OnTick: The DrawFVGRectangle() function is called immediately after the first FVG is successfully found and its details are stored globally. This ensures it's only drawn once per identified daily FVG.

*/
//--- Input Parameters
input group           "Trading Session (Broker Server Time)"
input int             LondonOpenHour    = 10; // ===> IMPORTANT: Set BROKER Server Hour corresponding to 3 AM NYT <===
input int             LondonCloseHour   = 14; // ===> IMPORTANT: Set BROKER Server Hour corresponding to 7 AM NYT <===

input group           "Trade Settings"
input double          Lots              = 0.01;   // Lot size
input double          RiskRewardRatio   = 2.0;    // Risk:Reward Ratio (e.g., 2.0 for 1:2)
input int             StopLossPips      = 15;     // ===> V1: Fixed SL in Pips beyond inversion high/low <===
input ulong           MagicNumber       = 123450; // Magic number for EA orders

input group           "FVG Settings"
input int             MaxBarsToSearchFVG = 50;    // How many recent bars back to check for FVG within the session
input int             MaxBarsToCheckInvRetest = 50; // How many recent bars to check for Inversion/Retest
input color           FVGColor          = clrCornflowerBlue; // Color for the FVG rectangle
input ENUM_LINE_STYLE FVGStyle          = STYLE_DOT; // Style for the FVG rectangle border
input int             FVGWidth          = 1;       // Width for the FVG rectangle border
input bool            FVGFilled         = true;   // Fill the FVG rectangle?

//--- Global Variables
CTrade            trade;                  // Trading object
bool              fvgFoundToday     = false; // Flag if FVG found for the current day's London session
bool              fvgInvertedToday  = false; // Flag if the daily FVG has been inverted
bool              tradeOpenedToday  = false; // Flag if a trade has been opened based on today's setup
bool              fvgIsBearish      = false; // True if bearish FVG, false if bullish
double            fvgHigh           = 0.0;   // High price of the FVG zone
double            fvgLow            = 0.0;   // Low price of the FVG zone
datetime          fvgCompletionTime = 0;     // Time when the FVG pattern (3rd candle) completed
double            inversionLevel    = 0.0;   // The price level (FVG high or low) that was breached for inversion
datetime          inversionTime     = 0;     // Time the inversion occurred (time of the closing candle)
int               dayResetCheck     = -1;    // Helper to detect new day
string            fvgObjectName     = "";    // *** ADDED: Name for the FVG rectangle object ***

// Structure to hold FVG info
struct FVGInfo
{
   bool     found;
   bool     isBearish;
   double   high;
   double   low;
   datetime completionTime; // Time of the *third* candle (completion of pattern)
   // We don't strictly need indexFound globally anymore with the time-based approach
};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Check Timeframe
   if(_Period != PERIOD_M15)
   {
      Alert("Error: Please apply this EA to an M15 chart.");
      return(INIT_FAILED);
   }

   //--- Initialize trading object
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFillingBySymbol(_Symbol);

   //--- Initialize Object Name *** ADDED ***
   fvgObjectName = "FVG_Rect_" + (string)MagicNumber + "_" + _Symbol + "_" + EnumToString(_Period);

   Print("London FVG Inversion V1.02 Initialized.");
   Print("FVG Object Name: ", fvgObjectName);
   Print("Broker Server Time for London Session: ", LondonOpenHour, ":00 - ", LondonCloseHour, ":00");
   Print("Risk Reward Ratio: 1:", RiskRewardRatio);
   Print("V1 Fixed Stop Loss Pips: ", StopLossPips);


   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Reset daily variables                                           |
//+------------------------------------------------------------------+
void ResetDailyVariables()
{
   fvgFoundToday = false;
   fvgInvertedToday = false;
   tradeOpenedToday = false;
   fvgIsBearish = false;
   fvgHigh = 0.0;
   fvgLow = 0.0;
   fvgCompletionTime = 0;
   inversionLevel = 0.0;
   inversionTime = 0;

   //--- Delete previous day's FVG rectangle *** ADDED ***
   ObjectDelete(0, fvgObjectName); // Delete object from main chart (window 0)

   // Print("Daily variables reset and FVG object deleted for ", TimeToString(TimeCurrent(), TIME_DATE));
}

// Function remains the same
bool IsLondonSession(datetime checkTime)
{
   MqlDateTime dt;
   TimeToStruct(checkTime, dt);
   return(dt.hour >= LondonOpenHour && dt.hour < LondonCloseHour);
}

// Function remains the same
FVGInfo FindFirstFVG_AfterLondonOpen(datetime londonOpenTimeToday)
{
   FVGInfo fvg = { false }; // Initialize as not found
   MqlRates rates[];
   int startBarIndex = iBarShift(_Symbol, PERIOD_M15, londonOpenTimeToday) + 5;
   if (startBarIndex < 0) startBarIndex = MaxBarsToSearchFVG;
   int barsNeeded = startBarIndex;

   int barsCopied = CopyRates(_Symbol, PERIOD_M15, 0, barsNeeded, rates);

   if(barsCopied < 3) return fvg;
   ArraySetAsSeries(rates, true);

   for(int i = 2; i < barsCopied; i++)
   {
      if(rates[i].time < londonOpenTimeToday) continue;

      bool currentIsBearish = rates[i-2].low > rates[i].high;
      bool currentIsBullish = rates[i-2].high < rates[i].low;

      if(currentIsBearish || currentIsBullish)
      {
           // Potential FVG found, check if it's the *earliest* one AFTER the open time
           if (!fvg.found || rates[i].time < fvg.completionTime)
           {
               fvg.found = true;
               fvg.isBearish = currentIsBearish; // Assign based on which condition met
               fvg.completionTime = rates[i].time; // Time of the THIRD candle
               if (fvg.isBearish)
               {
                   fvg.high = rates[i-2].low;
                   fvg.low = rates[i].high;
               }
               else // It's bullish
               {
                   fvg.high = rates[i].low;
                   fvg.low = rates[i-2].high;
               }
               // Don't need to store indexFound if only drawing once
           }
           // Continue checking backwards to find the absolute first
      }
   }
   // After checking all relevant bars, if we found one, print it
   if (fvg.found)
   {
      PrintFormat("%s FVG Found: High=%.5f, Low=%.5f, CompletedTime=%s",
                  fvg.isBearish ? "Bearish" : "Bullish",
                  fvg.high, fvg.low, TimeToString(fvg.completionTime));
   }

   return fvg;
}

// Function remains the same
bool CheckFVGInversion(const FVGInfo &fvg) // Pass fvg structure
{
    if (!fvg.found || fvgInvertedToday) return false;

    MqlRates rates[];
    int barsToCopy = MaxBarsToCheckInvRetest;
    int barsCopied = CopyRates(_Symbol, PERIOD_M15, 1, barsToCopy, rates);

    if(barsCopied < 1) return false;

    for(int i = 0; i < barsCopied; i++)
    {
         if(rates[i].time <= fvg.completionTime) continue;

         if(!fvg.isBearish && rates[i].close < fvg.low)
         {
            fvgInvertedToday = true;
            inversionLevel = fvg.low;
            inversionTime = rates[i].time;
            PrintFormat("Bullish FVG Inverted (Bearish Signal): Level=%.5f, Time=%s", inversionLevel, TimeToString(inversionTime));
            return true;
         }
         if(fvg.isBearish && rates[i].close > fvg.high)
         {
            fvgInvertedToday = true;
            inversionLevel = fvg.high;
            inversionTime = rates[i].time;
            PrintFormat("Bearish FVG Inverted (Bullish Signal): Level=%.5f, Time=%s", inversionLevel, TimeToString(inversionTime));
            return true;
         }
    }

    return false;
}

// Function remains the same
bool CheckRetest()
{
   if(!fvgFoundToday || !fvgInvertedToday || tradeOpenedToday || inversionLevel == 0.0 || inversionTime == 0) return false;

   MqlRates rates[];
   int barsToCopy = 5;
   int barsCopied = CopyRates(_Symbol, PERIOD_M15, 1, barsToCopy, rates);
   if(barsCopied < 1) return false;

   for(int i=0; i < barsCopied; i++)
   {
       if(rates[i].time <= inversionTime) continue;

       if(fvgIsBearish && rates[i].low <= inversionLevel && rates[i].low > (inversionLevel - StopLossPips*_Point*10))
       {
           PrintFormat("Retest for BUY occurred at %s (Low: %.5f <= Inversion: %.5f)", TimeToString(rates[i].time), rates[i].low, inversionLevel);
           return true;
       }
       if(!fvgIsBearish && rates[i].high >= inversionLevel && rates[i].high < (inversionLevel + StopLossPips*_Point*10))
       {
          PrintFormat("Retest for SELL occurred at %s (High: %.5f >= Inversion: %.5f)", TimeToString(rates[i].time), rates[i].high, inversionLevel);
          return true;
       }
   }
   return false;
}

// Function remains the same
void PlaceTrade()
{
   if(!fvgFoundToday || !fvgInvertedToday || tradeOpenedToday || inversionLevel == 0.0) return;

   bool positionExists = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
       if(PositionSelectByTicket(PositionGetTicket(i))) {
          if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol) {
              positionExists = true;
              break;
          }
       }
   }
   if(positionExists) { tradeOpenedToday = true; return; }

   double slDistance = StopLossPips * _Point * (SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 3 || SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 5 ? 10 : 1);
   double tpDistance = slDistance * RiskRewardRatio;
   double entryPrice = 0;
   double stopLoss = 0;
   double takeProfit = 0;
   string comment = "";

   if(fvgIsBearish) // Buy Logic
   {
       entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
       stopLoss = inversionLevel - slDistance;
       takeProfit = entryPrice + tpDistance;
       comment = "London FVG V1 Buy";
       if(!trade.Buy(Lots, _Symbol, 0, stopLoss, takeProfit, comment)) {
         PrintFormat("Buy Order failed: %s (Price: %.5f, SL: %.5f, TP: %.5f)", trade.ResultRetcodeDescription(), entryPrice, stopLoss, takeProfit);
       } else {
          PrintFormat("Buy Order Placed at Market (~%.5f): SL=%.5f, TP=%.5f", entryPrice, NormalizeDouble(stopLoss, _Digits), NormalizeDouble(takeProfit, _Digits));
          tradeOpenedToday = true;
       }
   }
   else // Sell Logic
   {
      entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      stopLoss = inversionLevel + slDistance;
      takeProfit = entryPrice - tpDistance;
      comment = "London FVG V1 Sell";
      if(!trade.Sell(Lots, _Symbol, 0, stopLoss, takeProfit, comment)) {
           PrintFormat("Sell Order failed: %s (Price: %.5f, SL: %.5f, TP: %.5f)", trade.ResultRetcodeDescription(), entryPrice, stopLoss, takeProfit);
      } else {
           PrintFormat("Sell Order Placed at Market (~%.5f): SL=%.5f, TP=%.5f", entryPrice, NormalizeDouble(stopLoss, _Digits), NormalizeDouble(takeProfit, _Digits));
           tradeOpenedToday = true;
       }
   }
}


//+------------------------------------------------------------------+
//| Draw the FVG Rectangle                                          |
//+------------------------------------------------------------------+
void DrawFVGRectangle()
{
    // Check if FVG was found today and if the object *doesn't* already exist
    if(fvgFoundToday && fvgCompletionTime != 0 && ObjectFind(0, fvgObjectName) < 0)
    {
        // Calculate an end time for the rectangle (e.g., 20 bars into the future)
        long barDuration = PeriodSeconds(); // Duration of one M15 bar
        if(barDuration <=0) barDuration = 15*60; // Fallback if PeriodSeconds fails
        datetime endTime = fvgCompletionTime + (datetime)(barDuration * 20); // Extend 20 M15 bars

        if(ObjectCreate(0, fvgObjectName, OBJ_RECTANGLE, 0, fvgCompletionTime, fvgHigh, endTime, fvgLow))
        {
            ObjectSetInteger(0, fvgObjectName, OBJPROP_COLOR, FVGColor);
            ObjectSetInteger(0, fvgObjectName, OBJPROP_STYLE, FVGStyle);
            ObjectSetInteger(0, fvgObjectName, OBJPROP_WIDTH, FVGWidth);
            ObjectSetInteger(0, fvgObjectName, OBJPROP_FILL, FVGFilled);
            ObjectSetInteger(0, fvgObjectName, OBJPROP_BACK, true); // Draw in background
            ObjectSetString(0, fvgObjectName, OBJPROP_TOOLTIP, fvgIsBearish ? "First Bearish FVG" : "First Bullish FVG");
            ChartRedraw(0); // Redraw chart to show the object
            Print("Drew FVG Rectangle: ", fvgObjectName);
        }
        else
        {
            Print("Error creating FVG rectangle: ", GetLastError());
        }
    }
}


//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime lastBarTime = 0;
   datetime currentBarOpenTime = (datetime)SeriesInfoInteger(_Symbol, PERIOD_M15, SERIES_LASTBAR_DATE);

   if(currentBarOpenTime == lastBarTime) return;
   lastBarTime = currentBarOpenTime;

   MqlDateTime dt;
   datetime serverTimeCurrent = TimeCurrent();
   TimeToStruct(serverTimeCurrent, dt);

   //--- Check for new day first to reset variables and drawings ---
   if(dt.day != dayResetCheck)
   {
      ResetDailyVariables();
      dayResetCheck = dt.day;
      Print("New day detected, resetting variables and deleting old FVG object.");
   }

   // Exit if not London session
   if (!IsLondonSession(serverTimeCurrent)) return;

   MqlDateTime todayDT;
   TimeToStruct(serverTimeCurrent, todayDT);
   todayDT.hour = LondonOpenHour; todayDT.min = 0; todayDT.sec = 0;
   datetime londonOpenTimeToday = StructToTime(todayDT);

   //--- Trading Logic Flow ---
   FVGInfo tempFVG = { false }; // Use a temporary variable inside the tick

   // 1. Find the FIRST FVG if not found yet for today
   if(!fvgFoundToday)
   {
       tempFVG = FindFirstFVG_AfterLondonOpen(londonOpenTimeToday);
       if(tempFVG.found)
       {
          // Store FVG details globally *once* per day
          fvgFoundToday = true;
          fvgIsBearish = tempFVG.isBearish;
          fvgHigh = tempFVG.high;
          fvgLow = tempFVG.low;
          fvgCompletionTime = tempFVG.completionTime; // Correct time stored
          Print("Stored first FVG details. Completion Time: ", TimeToString(fvgCompletionTime));

          //--- DRAW THE RECTANGLE (only happens once when FVG is first found) ---
          DrawFVGRectangle(); // *** CALL DRAW FUNCTION ***
       }
   }

    // 2. Check for inversion if FVG is found but not yet inverted
   if(fvgFoundToday && !fvgInvertedToday)
   {
       // We need the stored FVG details to check for inversion
       tempFVG.found = true;
       tempFVG.isBearish = fvgIsBearish;
       tempFVG.high = fvgHigh;
       tempFVG.low = fvgLow;
       tempFVG.completionTime = fvgCompletionTime;

       if (CheckFVGInversion(tempFVG)) {
          // Flags updated inside the function
       }
   }

    // 3. Check for retest and place trade if inverted and no trade placed
   if(fvgFoundToday && fvgInvertedToday && !tradeOpenedToday)
   {
        if(CheckRetest()) {
            PlaceTrade();
        }
   }

   // --- Check Session End ---
   if(dt.hour >= LondonCloseHour && !tradeOpenedToday && fvgFoundToday)
   {
      Print("London session ended without trigger after FVG found. Resetting for next day.");
      ResetDailyVariables(); // Reset if session ends before a trade
   }
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Cleanup: Optionally delete the object on EA removal/chart change
   ObjectDelete(0, fvgObjectName);
   Print("London FVG Inversion V1.02 Deinitialized. Reason: ", reason);
}
//+------------------------------------------------------------------+