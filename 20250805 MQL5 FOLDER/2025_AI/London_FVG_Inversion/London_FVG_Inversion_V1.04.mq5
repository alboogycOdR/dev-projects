//+------------------------------------------------------------------+
//|                                    London_FVG_Inversion_V1.mq5 |
//|                        Copyright 2023, Generated from Strategy |
//|                                              Strategy Developer |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Generated from Strategy"
#property link      "None"
#property version   "1.06" // FVG Detection uses Closed Candles ONLY
#property strict

#include <Trade\Trade.mqh> // Trading class
#include <Object.mqh>     // For ObjectDelete

//--- Input Parameters
input group           "Trading Session (Broker Server Time)"
input int             LondonOpenHour    = 10; // ===> IMPORTANT: Set BROKER Server Hour corresponding to 3 AM NYT <===
input int             LondonCloseHour   = 14; // ===> IMPORTANT: Set BROKER Server Hour corresponding to 7 AM NYT <===

input group           "Trade Settings"
input double          Lots              = 0.01;   // Lot size
input double          RiskRewardRatio   = 2.0;    // Risk:Reward Ratio (e.g., 2.0 for 1:2)
input int             StopLossPips      = 15;     // Fixed SL in Pips beyond inversion high/low
input ulong           MagicNumber       = 123450; // Magic number for EA orders

input group           "FVG Settings"
input int             MaxBarsToSearchFVG = 50;    // How many recent bars back to check for FVG within the session
input int             MaxBarsToCheckInvRetest = 50; // How many recent bars to check for Inversion/Retest
input int             MinFVGPoints      = 50;     // Minimum FVG size in Points
input color           FVGColor          = clrCornflowerBlue;
input ENUM_LINE_STYLE FVGStyle          = STYLE_DOT;
input int             FVGWidth          = 1;
input bool            FVGFilled         = true;

input group           "Visuals"
input color           SessionLineColor  = clrBlack;
input ENUM_LINE_STYLE SessionLineStyle  = STYLE_DOT;
input int             SessionLineWidth  = 1;


//--- Global Variables
CTrade            trade;
bool              fvgFoundToday     = false;
bool              fvgInvertedToday  = false;
bool              tradeOpenedToday  = false;
bool              fvgIsBearish      = false; // Now: true for ICT Bearish FVG (downward gap)
double            fvgHigh           = 0.0;   // Top of the FVG zone
double            fvgLow            = 0.0;   // Bottom of the FVG zone
datetime          fvgCompletionTime = 0;
double            inversionLevel    = 0.0;
datetime          inversionTime     = 0;
int               dayResetCheck     = -1;
string            fvgObjectName     = "";
string            openLineName      = "";
string            closeLineName     = "";
double            minFVGPriceDiff   = 0.0;


// Structure to hold FVG info
struct FVGInfo
{
   bool     found;
   bool     isBearish; // True if it's an ICT Bearish FVG (downward gap)
   double   high;      // Top of the FVG zone
   double   low;       // Bottom of the FVG zone
   datetime completionTime;
   MqlRates candle1;   // Candle 1 (chronologically first)
   MqlRates candle2;   // Candle 2
   MqlRates candle3;   // Candle 3 (completion candle)
};

//+------------------------------------------------------------------+
//| OnInit                                                          |
//+------------------------------------------------------------------+
int OnInit()
{
   if(_Period != PERIOD_M15) { Alert("EA for M15 chart only."); return(INIT_FAILED); }
   trade.SetExpertMagicNumber(MagicNumber); trade.SetDeviationInPoints(10); trade.SetTypeFillingBySymbol(_Symbol);
   fvgObjectName = "FVG_Rect_" + (string)MagicNumber + "_" + _Symbol + "_" + EnumToString(_Period);
   openLineName = "OpenLine_" + (string)MagicNumber + "_" + _Symbol + "_" + EnumToString(_Period);
   closeLineName = "CloseLine_" + (string)MagicNumber + "_" + _Symbol + "_" + EnumToString(_Period);
   minFVGPriceDiff = MinFVGPoints * _Point;
   if (minFVGPriceDiff <= 0) { minFVGPriceDiff = _Point; } // Fallback
   Print("London FVG Inversion V1.04 Initialized. Min FVG Pts: ", MinFVGPoints);
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| ResetDailyVariables                                              |
//+------------------------------------------------------------------+
void ResetDailyVariables()
{
   fvgFoundToday=false; fvgInvertedToday=false; tradeOpenedToday=false; fvgIsBearish=false;
   fvgHigh=0.0; fvgLow=0.0; fvgCompletionTime=0; inversionLevel=0.0; inversionTime=0;
   ObjectDelete(0,fvgObjectName); ObjectDelete(0,openLineName); ObjectDelete(0,closeLineName);
}
//+------------------------------------------------------------------+
//| IsLondonSession                                                  |
//+------------------------------------------------------------------+
bool IsLondonSession(datetime checkTime)
{
   MqlDateTime dt; TimeToStruct(checkTime, dt);
   return(dt.hour >= LondonOpenHour && dt.hour < LondonCloseHour);
}

//+------------------------------------------------------------------+
//| FindFirstFVG_AfterLondonOpen (Corrected Definition)              |
//+------------------------------------------------------------------+
FVGInfo FindFirstFVG_AfterLondonOpen(datetime londonOpenTimeToday)
{
   FVGInfo fvg = { false };
   MqlRates rates[];
   int startBarIndex = iBarShift(_Symbol, PERIOD_M15, londonOpenTimeToday) + 5;
   if (startBarIndex < 0 || startBarIndex < MaxBarsToSearchFVG ) startBarIndex = MaxBarsToSearchFVG; // Ensure enough bars to check back
   int barsNeeded = MathMax(3, startBarIndex);

   int barsCopied = CopyRates(_Symbol, PERIOD_M15, 0, barsNeeded, rates);

   if(barsCopied < 3) return fvg;
   ArraySetAsSeries(rates, true); // rates[0]=latest complete, rates[i-2] = 1st candle, rates[i-1]=2nd, rates[i]=3rd

   for(int i = 2; i < barsCopied; i++) // Iterate backwards to check for 3-candle patterns
   {
      // Ensure FVG *completion* (time of 3rd candle) is after session start
      if(rates[i].time < londonOpenTimeToday) continue;

      double currentFvgSize = 0;
      bool isCurrentBullishFVG = false;
      bool isCurrentBearishFVG = false;

      // *** CORRECTED ICT Bullish FVG (Upward Gap) ***
      // Low of 1st candle (rates[i-2].low) is HIGHER than the High of 3rd candle (rates[i].high)
      if(rates[i-2].low > rates[i].high)
      {
          isCurrentBullishFVG = true;
          currentFvgSize = rates[i-2].low - rates[i].high; // Gap is between these levels
      }

      // *** CORRECTED ICT Bearish FVG (Downward Gap) ***
      // High of 1st candle (rates[i-2].high) is LOWER than the Low of 3rd candle (rates[i].low)
      else if(rates[i-2].high < rates[i].low)
      {
          isCurrentBearishFVG = true;
          currentFvgSize = rates[i].low - rates[i-2].high; // Gap is between these levels
      }


      // Check if valid pattern AND meets the minimum size
      if((isCurrentBullishFVG || isCurrentBearishFVG) && currentFvgSize >= minFVGPriceDiff)
      {
         // This is a valid FVG, check if it's the earliest one *after* the London Open
         if (!fvg.found || rates[i].time < fvg.completionTime)
         {
             fvg.found = true;
             fvg.isBearish = isCurrentBearishFVG; // Set if it's bearish or bullish (true for bearish, false for bullish)
             fvg.completionTime = rates[i].time; // Time of the 3rd candle's completion
             // Store the candles forming this FVG
             fvg.candle1 = rates[i-2]; // 1st candle
             fvg.candle2 = rates[i-1]; // 2nd candle
             fvg.candle3 = rates[i];   // 3rd candle

             if (isCurrentBullishFVG) // This is an ICT Bullish FVG (gap points upwards)
             {
                 fvg.low  = rates[i].high;       // Bottom of the gap (high of 3rd candle)
                 fvg.high = rates[i-2].low;     // Top of the gap (low of 1st candle)
             }
             else // isCurrentBearishFVG (gap points downwards)
             {
                 fvg.high = rates[i-2].high;    // Top of the gap (high of 1st candle)
                 fvg.low  = rates[i].low;      // Bottom of the gap (low of 3rd candle)
             }
             // Continue searching to ensure this is the *absolute first* one after the open.
             // If found an earlier one (smaller rates[i].time) that also meets criteria, it will update fvg.
         }
      }
   }
   
   // After checking all relevant bars, if we found an FVG, print it with candle details
   if (fvg.found) {
      string fvgType = fvg.isBearish ? "Bearish (Downward Gap)" : "Bullish (Upward Gap)";
      double fvgSizePts = MathAbs(fvg.high - fvg.low) / _Point;

      PrintFormat("=== First Valid FVG Found ===");
      PrintFormat("Type: %s", fvgType);
      PrintFormat("FVG Zone: Top=%.5f, Bottom=%.5f", fvg.high, fvg.low);
      PrintFormat("FVG Size: %.1f Points", fvgSizePts);
      PrintFormat("Completed Time: %s", TimeToString(fvg.completionTime));
      Print("--- Forming Candles ---");
      PrintFormat("Candle 1 Time: %s | O: %.5f H: %.5f L: %.5f C: %.5f", TimeToString(fvg.candle1.time), fvg.candle1.open, fvg.candle1.high, fvg.candle1.low, fvg.candle1.close);
      PrintFormat("Candle 2 Time: %s | O: %.5f H: %.5f L: %.5f C: %.5f", TimeToString(fvg.candle2.time), fvg.candle2.open, fvg.candle2.high, fvg.candle2.low, fvg.candle2.close);
      PrintFormat("Candle 3 Time: %s | O: %.5f H: %.5f L: %.5f C: %.5f", TimeToString(fvg.candle3.time), fvg.candle3.open, fvg.candle3.high, fvg.candle3.low, fvg.candle3.close);
      Print("==========================");
   }

   return fvg;
}

//+------------------------------------------------------------------+
//| CheckFVGInversion (logic changes for inversion)                 |
//+------------------------------------------------------------------+
bool CheckFVGInversion(const FVGInfo &fvg) // Pass fvg structure
{
    if (!fvg.found || fvgInvertedToday) return false;

    MqlRates rates[];
    int barsToCopy = MaxBarsToCheckInvRetest;
    int barsCopied = CopyRates(_Symbol, PERIOD_M15, 1, barsToCopy, rates); // last N completed bars

    if(barsCopied < 1) return false;

    for(int i = 0; i < barsCopied; i++)
    {
         // Check only bars strictly AFTER the FVG pattern completed
         if(rates[i].time <= fvg.completionTime) continue;

         // Original FVG was an ICT Bullish FVG (upward gap), now look for close BELOW its LOW to invert it (bearish signal)
         if(!fvg.isBearish && rates[i].close < fvg.low)
         {
            fvgInvertedToday = true;
            inversionLevel = fvg.low; // Inversion happened at the FVG's bottom boundary
            inversionTime = rates[i].time;
            PrintFormat("ICT Bullish FVG Inverted (Bearish Signal): Level=%.5f, Time=%s", inversionLevel, TimeToString(inversionTime));
            return true;
         }
         // Original FVG was an ICT Bearish FVG (downward gap), now look for close ABOVE its HIGH to invert it (bullish signal)
         if(fvg.isBearish && rates[i].close > fvg.high)
         {
            fvgInvertedToday = true;
            inversionLevel = fvg.high; // Inversion happened at the FVG's top boundary
            inversionTime = rates[i].time;
            PrintFormat("ICT Bearish FVG Inverted (Bullish Signal): Level=%.5f, Time=%s", inversionLevel, TimeToString(inversionTime));
            return true;
         }
    }
    return false; // No inversion found
}

//+------------------------------------------------------------------+
//| CheckRetest (logic changes for entry direction)                 |
//+------------------------------------------------------------------+
bool CheckRetest()
{
   // Uses global: fvgFoundToday, fvgInvertedToday, tradeOpenedToday, inversionLevel, inversionTime, fvgIsBearish
   if(!fvgFoundToday || !fvgInvertedToday || tradeOpenedToday || inversionLevel == 0.0 || inversionTime == 0) return false;

   MqlRates rates[]; int barsToCopy = 5;
   int barsCopied = CopyRates(_Symbol, PERIOD_M15, 1, barsToCopy, rates); if(barsCopied < 1) return false;

   double buffer = StopLossPips * _Point * (SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 3 || SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 5 ? 10 : 1);

   for(int i=0; i < barsCopied; i++) {
       if(rates[i].time <= inversionTime) continue;

       // If original FVG was Bearish (downward gap) and inverted -> Bullish setup (retest support)
       // inversionLevel would be the fvg.high (top of the original bearish FVG)
       if(fvgIsBearish && rates[i].low <= inversionLevel && rates[i].low > (inversionLevel - buffer)) {
           PrintFormat("Retest for BUY (orig Bearish FVG inverted) at %s", TimeToString(rates[i].time));
           return true;
       }
       // If original FVG was Bullish (upward gap) and inverted -> Bearish setup (retest resistance)
       // inversionLevel would be the fvg.low (bottom of the original bullish FVG)
       if(!fvgIsBearish && rates[i].high >= inversionLevel && rates[i].high < (inversionLevel + buffer)) {
          PrintFormat("Retest for SELL (orig Bullish FVG inverted) at %s", TimeToString(rates[i].time));
          return true;
       }
   }
   return false;
}

//+------------------------------------------------------------------+
//| PlaceTrade (logic changes for entry direction)                  |
//+------------------------------------------------------------------+
void PlaceTrade()
{
   if(!fvgFoundToday || !fvgInvertedToday || tradeOpenedToday || inversionLevel == 0.0) return;
   bool positionExists = false; for(int i=PositionsTotal()-1; i>=0; i--) { if(PositionSelectByTicket(PositionGetTicket(i))) { if(PositionGetInteger(POSITION_MAGIC)==MagicNumber && PositionGetString(POSITION_SYMBOL)==_Symbol) { positionExists=true; break; }}} if(positionExists){ tradeOpenedToday=true; return; }
   double slDistance = StopLossPips * _Point * (SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)==3||SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)==5 ? 10 : 1);
   double tpDistance = slDistance * RiskRewardRatio; double entryPrice=0; double stopLoss=0; double takeProfit=0; string comment="";

   // If original FVG was Bearish (downward gap) and it inverted -> it became support, so we BUY
   if(fvgIsBearish)
   {
       entryPrice=SymbolInfoDouble(_Symbol, SYMBOL_ASK);
       stopLoss = inversionLevel - slDistance; // SL below the inverted FVG's high (which is now support)
       takeProfit = entryPrice + tpDistance;
       comment="Lon FVG Buy (Inv Bear)";
       if(!trade.Buy(Lots,_Symbol,0,stopLoss,takeProfit,comment)) PrintFormat("Buy Fail: %s",trade.ResultRetcodeDescription());
       else { PrintFormat("BUY: SL=%.5f TP=%.5f (Orig Bearish FVG)",NormalizeDouble(stopLoss,_Digits),NormalizeDouble(takeProfit,_Digits)); tradeOpenedToday=true; }
   }
   // If original FVG was Bullish (upward gap) and it inverted -> it became resistance, so we SELL
   else // !fvgIsBearish (original was Bullish FVG)
   {
      entryPrice=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      stopLoss = inversionLevel + slDistance; // SL above the inverted FVG's low (which is now resistance)
      takeProfit = entryPrice - tpDistance;
      comment="Lon FVG Sell (Inv Bull)";
      if(!trade.Sell(Lots,_Symbol,0,stopLoss,takeProfit,comment)) PrintFormat("Sell Fail: %s",trade.ResultRetcodeDescription());
      else { PrintFormat("SELL: SL=%.5f TP=%.5f (Orig Bullish FVG)",NormalizeDouble(stopLoss,_Digits),NormalizeDouble(takeProfit,_Digits)); tradeOpenedToday=true; }
   }
}
//+------------------------------------------------------------------+
//| FindFirstFVG_AfterLondonOpen (Uses CLOSED Candles Only)          |
//+------------------------------------------------------------------+
FVGInfo FindFirstFVG_AfterLondonOpen(datetime londonOpenTimeToday)
{
   FVGInfo fvg = { false };
   MqlRates rates[];
   // Calculate a potential starting bar index near London open
   // Add extra buffer as we now start copying from completed bar 1
   int shiftBuffer = 10; // Look a bit further back
   int startBarIndex = iBarShift(_Symbol, PERIOD_M15, londonOpenTimeToday) + shiftBuffer;
   if (startBarIndex <= 0 || startBarIndex < MaxBarsToSearchFVG ) startBarIndex = MaxBarsToSearchFVG;
   int barsNeeded = MathMax(3, startBarIndex);

   // *** MODIFIED: Start copying from index 1 (first *completed* bar) ***
   int barsCopied = CopyRates(_Symbol, PERIOD_M15, 1, barsNeeded, rates);

   if(barsCopied < 3)
   {
        // Print("FindFirstFVG: Not enough closed bar history (copied ", barsCopied, ")");
        return fvg; // Need at least 3 completed bars
   }
   // Standard array order: rates[0] = oldest copied bar, rates[barsCopied-1] = most recent completed bar
   // We check candles rates[i] (C3), rates[i-1] (C2), rates[i-2] (C1)

   // Iterate backwards through the *completed* bars to find the first FVG after London open
   for(int i = barsCopied - 1; i >= 2; i--) // Start from newest group, go back
   {
      // Ensure FVG pattern completion time (candle i's time) is valid
      if(rates[i].time < londonOpenTimeToday) continue;

      // Sanity check candle ranges (using only completed bars)
      double candle1Range = rates[i-2].high - rates[i-2].low;
      double candle3Range = rates[i].high - rates[i].low;

      if(candle1Range < minCandlePriceRange || candle3Range < minCandlePriceRange) continue;


      // Corrected ICT Definitions based on completed bars
      bool isCurrentBullishFVG = rates[i-2].low > rates[i].high;  // Low[1] > High[3] ?
      bool isCurrentBearishFVG = rates[i-2].high < rates[i].low; // High[1] < Low[3] ?

      double currentFvgSize = 0;
      double fvgZoneHigh = 0;
      double fvgZoneLow = 0;

      if (isCurrentBullishFVG) {
          fvgZoneHigh = rates[i-2].low;
          fvgZoneLow  = rates[i].high;
          currentFvgSize = fvgZoneHigh - fvgZoneLow;
      } else if (isCurrentBearishFVG) {
          fvgZoneHigh = rates[i-2].high;
          fvgZoneLow  = rates[i].low;
          currentFvgSize = fvgZoneHigh - fvgZoneLow;
      }

      // Check if valid pattern AND meets the minimum size
      if ((isCurrentBullishFVG || isCurrentBearishFVG) && currentFvgSize >= minFVGPriceDiff)
      {
          // Found a valid FVG. Check if it's earlier than any previously stored candidate.
          // Since we iterate backwards from most recent, we want the *latest* i (smallest i index)
          // which corresponds to the earliest time after the open.
           if (!fvg.found || rates[i].time < fvg.completionTime) // Store if first or earlier than previous earliest
           {
             fvg.found = true;
             fvg.isBearish = isCurrentBearishFVG;
             fvg.completionTime = rates[i].time;
             fvg.high = fvgZoneHigh;
             fvg.low = fvgZoneLow;
            // Continue loop to find the absolute EARLIEST one after London Open
           }
      }
   } // End loop

   // Print if found after checking all valid possibilities
   if (fvg.found) {
      PrintFormat("First Valid %s FVG (Closed Bars Only): Top=%.5f, Bottom=%.5f, Size=%.1f Pts, Time=%s",
                  fvg.isBearish ? "Bearish" : "Bullish",
                  fvg.high, fvg.low, fabs(fvg.high-fvg.low)/_Point, TimeToString(fvg.completionTime));
   }

   return fvg;
}
// Function DrawFVGRectangle remains the same
void DrawFVGRectangle()
{
    if(fvgFoundToday && fvgCompletionTime != 0 && ObjectFind(0, fvgObjectName) < 0) {
        long barDuration = PeriodSeconds(); if(barDuration<=0) barDuration=15*60; datetime endTime = fvgCompletionTime + (datetime)(barDuration*20);
        if(ObjectCreate(0,fvgObjectName,OBJ_RECTANGLE,0,fvgCompletionTime,fvgHigh,endTime,fvgLow)){
            ObjectSetInteger(0,fvgObjectName,OBJPROP_COLOR,FVGColor); ObjectSetInteger(0,fvgObjectName,OBJPROP_STYLE,FVGStyle); ObjectSetInteger(0,fvgObjectName,OBJPROP_WIDTH,FVGWidth); ObjectSetInteger(0,fvgObjectName,OBJPROP_FILL,FVGFilled); ObjectSetInteger(0,fvgObjectName,OBJPROP_BACK,true);
            ObjectSetString(0,fvgObjectName,OBJPROP_TOOLTIP, fvgIsBearish?"ICT Bearish FVG (Closed)":"ICT Bullish FVG (Closed)"); // Clarified tooltip
            ChartRedraw(0);
        } else { Print("Error creating FVG rect: ",GetLastError()); }
    }
}

// Function DrawSessionLines remains the same
void DrawSessionLines(datetime currentTime)
{
   if(ObjectFind(0, openLineName) < 0 || ObjectFind(0, closeLineName) < 0) {
       MqlDateTime dt; TimeToStruct(currentTime, dt);
       dt.hour=LondonOpenHour; dt.min=0; dt.sec=0; datetime openTimeToday=StructToTime(dt);
       dt.hour=LondonCloseHour; datetime closeTimeToday=StructToTime(dt);
       if(ObjectFind(0, openLineName)<0 && ObjectCreate(0,openLineName,OBJ_VLINE,0,openTimeToday,0)) { ObjectSetInteger(0,openLineName,OBJPROP_COLOR,SessionLineColor); ObjectSetInteger(0,openLineName,OBJPROP_STYLE,SessionLineStyle); ObjectSetInteger(0,openLineName,OBJPROP_WIDTH,SessionLineWidth); ObjectSetString(0,openLineName,OBJPROP_TOOLTIP,"London Open");}
       if(ObjectFind(0, closeLineName)<0 && ObjectCreate(0,closeLineName,OBJ_VLINE,0,closeTimeToday,0)) { ObjectSetInteger(0,closeLineName,OBJPROP_COLOR,SessionLineColor); ObjectSetInteger(0,closeLineName,OBJPROP_STYLE,SessionLineStyle); ObjectSetInteger(0,closeLineName,OBJPROP_WIDTH,SessionLineWidth); ObjectSetString(0,closeLineName,OBJPROP_TOOLTIP,"London Close");}
       ChartRedraw(0);
   }
}

// OnTick remains the same (apart from any Print statements you might want to adjust for clarity)
void OnTick()
{
   static datetime lastBarTime = 0;
   datetime currentBarOpenTime = (datetime)SeriesInfoInteger(_Symbol, PERIOD_M15, SERIES_LASTBAR_DATE);
   if(currentBarOpenTime == lastBarTime) return;
   lastBarTime = currentBarOpenTime;
   datetime serverTimeCurrent = TimeCurrent(); MqlDateTime dt; TimeToStruct(serverTimeCurrent, dt);
   if(dt.day != dayResetCheck) { ResetDailyVariables(); dayResetCheck = dt.day; Print("New day reset."); }
   DrawSessionLines(serverTimeCurrent);
   if (!IsLondonSession(serverTimeCurrent)) return;
   MqlDateTime todayDT; TimeToStruct(serverTimeCurrent,todayDT); todayDT.hour=LondonOpenHour; todayDT.min=0; todayDT.sec=0; datetime londonOpenTimeToday=StructToTime(todayDT);
   FVGInfo tempFVG = { false };
   if(!fvgFoundToday) {
       tempFVG = FindFirstFVG_AfterLondonOpen(londonOpenTimeToday);
       if(tempFVG.found) {
          fvgFoundToday=true; fvgIsBearish=tempFVG.isBearish; fvgHigh=tempFVG.high; fvgLow=tempFVG.low; fvgCompletionTime=tempFVG.completionTime;
          DrawFVGRectangle();
       }
   }
   if(fvgFoundToday && !fvgInvertedToday) {
       tempFVG.found=true; tempFVG.isBearish=fvgIsBearish; tempFVG.high=fvgHigh; tempFVG.low=fvgLow; tempFVG.completionTime=fvgCompletionTime;
       if (CheckFVGInversion(tempFVG)) { /* updated globally */ }
   }
   if(fvgFoundToday && fvgInvertedToday && !tradeOpenedToday) {
        if(CheckRetest()) { PlaceTrade(); }
   }
   if(dt.hour >= LondonCloseHour && !tradeOpenedToday && fvgFoundToday) { Print("Session end, no trade."); ResetDailyVariables(); }
}

// OnDeinit remains the same
void OnDeinit(const int reason)
{
   ObjectDelete(0, fvgObjectName); ObjectDelete(0, openLineName); ObjectDelete(0, closeLineName);
   Print("London FVG Inversion V1.04 Deinitialized. Reason: ", reason);
}
//+------------------------------------------------------------------+