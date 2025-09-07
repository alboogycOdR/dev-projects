//+------------------------------------------------------------------+
//|                                    London_FVG_Inversion_V1.mq5 |
//|                        Copyright 2023, Generated from Strategy |
//|                                              Strategy Developer |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Generated from Strategy"
#property link      "None"
#property version   "1.03" // Added Min FVG Size & Session Lines
#property strict

#include <Trade\Trade.mqh> // Trading class
#include <Object.mqh>     // For ObjectDelete

/*
Version 1.03):
Min FVG Points Input: Added MinFVGPoints input parameter (defaulting to 50).
Session Lines Inputs: Added SessionLineColor, SessionLineStyle, SessionLineWidth inputs.
minFVGPriceDiff Global: Stores the minimum point value converted to a price difference in OnInit.
openLineName, closeLineName Globals: Names for the vertical line objects.
FindFirstFVG_AfterLondonOpen:
Calculates currentFvgSize for each potential FVG found.
Adds && currentFvgSize >= minFVGPriceDiff to the if conditions that validate the FVG pattern. Only FVGs meeting both the pattern criteria and the minimum size will now be considered.
DrawSessionLines() Function: Created this new function to encapsulate the logic for drawing the vertical lines at the calculated start and end times for the current day. It checks if the lines already exist before drawing.
OnInit: Initializes openLineName and closeLineName. Calculates minFVGPriceDiff.
ResetDailyVariables: Added calls to ObjectDelete for openLineName and closeLineName.
OnTick: Added a call to DrawSessionLines(serverTimeCurrent); near the beginning (after the daily reset check) to ensure the lines are drawn/checked on each new bar's processing.
OnDeinit: Added cleanup for the new session line objects.
*/
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
input int             MinFVGPoints      = 50;     // *** ADDED: Minimum FVG size in Points ***
input color           FVGColor          = clrCornflowerBlue;
input ENUM_LINE_STYLE FVGStyle          = STYLE_DOT;
input int             FVGWidth          = 1;
input bool            FVGFilled         = true;

input group           "Visuals" // *** ADDED GROUP ***
input color           SessionLineColor  = clrBlack;
input ENUM_LINE_STYLE SessionLineStyle  = STYLE_DOT;
input int             SessionLineWidth  = 1;


//--- Global Variables
CTrade            trade;                  // Trading object
bool              fvgFoundToday     = false;
bool              fvgInvertedToday  = false;
bool              tradeOpenedToday  = false;
bool              fvgIsBearish      = false;
double            fvgHigh           = 0.0;
double            fvgLow            = 0.0;
datetime          fvgCompletionTime = 0;
double            inversionLevel    = 0.0;
datetime          inversionTime     = 0;
int               dayResetCheck     = -1;
string            fvgObjectName     = "";
string            openLineName      = "";   // *** ADDED: Name for London Open line ***
string            closeLineName     = "";  // *** ADDED: Name for London Close line ***
double            minFVGPriceDiff   = 0.0;  // *** ADDED: Store minimum FVG size in price terms ***


// Structure to hold FVG info
struct FVGInfo
{
   bool     found;
   bool     isBearish;
   double   high;
   double   low;
   datetime completionTime;
};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   if(_Period != PERIOD_M15) {
      Alert("Error: Please apply this EA to an M15 chart.");
      return(INIT_FAILED);
   }

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFillingBySymbol(_Symbol);

   //--- Initialize Object Names
   fvgObjectName = "FVG_Rect_" + (string)MagicNumber + "_" + _Symbol + "_" + EnumToString(_Period);
   openLineName = "OpenLine_" + (string)MagicNumber + "_" + _Symbol + "_" + EnumToString(_Period);   // *** ADDED ***
   closeLineName = "CloseLine_" + (string)MagicNumber + "_" + _Symbol + "_" + EnumToString(_Period); // *** ADDED ***

   //--- Calculate Minimum FVG Price Difference *** ADDED ***
   minFVGPriceDiff = MinFVGPoints * _Point;
   if (minFVGPriceDiff <= 0) {
        Alert("Warning: Minimum FVG Points results in zero or negative price difference. Setting to a small default.");
        minFVGPriceDiff = _Point; // Prevent zero division or issues
   }

   Print("London FVG Inversion V1.03 Initialized.");
   Print("FVG Object Name: ", fvgObjectName);
   Print("Session Line Names: ", openLineName, ", ", closeLineName);
   Print("Broker Server Time for London Session: ", LondonOpenHour, ":00 - ", LondonCloseHour, ":00");
   Print("Minimum FVG Size: ", MinFVGPoints, " points (", DoubleToString(minFVGPriceDiff,_Digits) , ")"); // Print calculated price diff

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

   //--- Delete previous day's objects *** MODIFIED ***
   ObjectDelete(0, fvgObjectName);
   ObjectDelete(0, openLineName);
   ObjectDelete(0, closeLineName);

   // Print("Daily variables reset and visual objects deleted for ", TimeToString(TimeCurrent(), TIME_DATE));
}

// Function remains the same
bool IsLondonSession(datetime checkTime)
{
   MqlDateTime dt;
   TimeToStruct(checkTime, dt);
   return(dt.hour >= LondonOpenHour && dt.hour < LondonCloseHour);
}

//+------------------------------------------------------------------+
//| Find the first FVG after London Open (with Min Size Check)       |
//+------------------------------------------------------------------+
FVGInfo FindFirstFVG_AfterLondonOpen(datetime londonOpenTimeToday)
{
   FVGInfo fvg = { false };
   MqlRates rates[];
   int startBarIndex = iBarShift(_Symbol, PERIOD_M15, londonOpenTimeToday) + 5;
   if (startBarIndex < 0) startBarIndex = MaxBarsToSearchFVG;
   int barsNeeded = MathMax(3, startBarIndex); // Ensure at least 3 bars

   int barsCopied = CopyRates(_Symbol, PERIOD_M15, 0, barsNeeded, rates);

   if(barsCopied < 3) return fvg;
   ArraySetAsSeries(rates, true); // rates[0]=latest complete

   for(int i = 2; i < barsCopied; i++) // Check index i(3rd), i-1(2nd), i-2(1st)
   {
      // Ensure FVG completion is after session start
      if(rates[i].time < londonOpenTimeToday) continue;

      bool currentIsBearish = rates[i-2].low > rates[i].high;
      bool currentIsBullish = rates[i-2].high < rates[i].low;
      double currentFvgSize = 0;

      if(currentIsBearish) currentFvgSize = rates[i-2].low - rates[i].high;
      if(currentIsBullish) currentFvgSize = rates[i].low - rates[i-2].high;

      // Check if it's a valid pattern AND meets the minimum size requirement
      if((currentIsBearish || currentIsBullish) && currentFvgSize >= minFVGPriceDiff)
      {
         // PrintFormat("Potential FVG Check: Index=%d, Time=%s, Size=%.5f (%.1f pts), MinReq=%.5f (%d pts)", i, TimeToString(rates[i].time), currentFvgSize, currentFvgSize / _Point, minFVGPriceDiff, MinFVGPoints); // Debug Print

         // Potential FVG found and is large enough, check if it's the earliest
         if (!fvg.found || rates[i].time < fvg.completionTime)
         {
             fvg.found = true;
             fvg.isBearish = currentIsBearish;
             fvg.completionTime = rates[i].time;
             if (fvg.isBearish) {
                 fvg.high = rates[i-2].low;
                 fvg.low = rates[i].high;
             } else { // Bullish
                 fvg.high = rates[i].low;
                 fvg.low = rates[i-2].high;
             }
             // Keep looking backwards for an *even earlier* valid FVG after London Open
         }
      }
   }

   if (fvg.found) {
      PrintFormat("%s FVG Found: High=%.5f, Low=%.5f, Size=%.1f Pts, CompletedTime=%s",
                  fvg.isBearish ? "Bearish" : "Bullish",
                  fvg.high, fvg.low, fabs(fvg.high-fvg.low)/_Point, TimeToString(fvg.completionTime));
   }


   return fvg;
}


// Function remains the same
bool CheckFVGInversion(const FVGInfo &fvg)
{
    if (!fvg.found || fvgInvertedToday) return false;
    MqlRates rates[];
    int barsToCopy = MaxBarsToCheckInvRetest;
    int barsCopied = CopyRates(_Symbol, PERIOD_M15, 1, barsToCopy, rates);
    if(barsCopied < 1) return false;
    for(int i = 0; i < barsCopied; i++) {
         if(rates[i].time <= fvg.completionTime) continue;
         if(!fvg.isBearish && rates[i].close < fvg.low) {
            fvgInvertedToday = true; inversionLevel = fvg.low; inversionTime = rates[i].time;
            PrintFormat("Bullish FVG Inverted: Level=%.5f, Time=%s", inversionLevel, TimeToString(inversionTime)); return true;
         }
         if(fvg.isBearish && rates[i].close > fvg.high) {
            fvgInvertedToday = true; inversionLevel = fvg.high; inversionTime = rates[i].time;
            PrintFormat("Bearish FVG Inverted: Level=%.5f, Time=%s", inversionLevel, TimeToString(inversionTime)); return true;
         }
    }
    return false;
}

// Function remains the same
bool CheckRetest()
{
   if(!fvgFoundToday || !fvgInvertedToday || tradeOpenedToday || inversionLevel == 0.0 || inversionTime == 0) return false;
   MqlRates rates[];
   int barsToCopy = 5; int barsCopied = CopyRates(_Symbol, PERIOD_M15, 1, barsToCopy, rates); if(barsCopied < 1) return false;
   double buffer = StopLossPips * _Point * (SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 3 || SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 5 ? 10 : 1); // Buffer using SL pips
   for(int i=0; i < barsCopied; i++) {
       if(rates[i].time <= inversionTime) continue;
       if(fvgIsBearish && rates[i].low <= inversionLevel && rates[i].low > (inversionLevel - buffer)) {
           PrintFormat("Retest for BUY at %s", TimeToString(rates[i].time)); return true;
       }
       if(!fvgIsBearish && rates[i].high >= inversionLevel && rates[i].high < (inversionLevel + buffer)) {
          PrintFormat("Retest for SELL at %s", TimeToString(rates[i].time)); return true;
       }
   }
   return false;
}

// Function remains the same
void PlaceTrade()
{
   if(!fvgFoundToday || !fvgInvertedToday || tradeOpenedToday || inversionLevel == 0.0) return;
   bool positionExists = false; for(int i=PositionsTotal()-1; i>=0; i--) { if(PositionSelectByTicket(PositionGetTicket(i))) { if(PositionGetInteger(POSITION_MAGIC)==MagicNumber && PositionGetString(POSITION_SYMBOL)==_Symbol) { positionExists=true; break; }}} if(positionExists){ tradeOpenedToday=true; return; }
   double slDistance = StopLossPips * _Point * (SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)==3||SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)==5 ? 10 : 1); double tpDistance = slDistance * RiskRewardRatio;
   double entryPrice=0; double stopLoss=0; double takeProfit=0; string comment="";
   if(fvgIsBearish) { /* Buy */ entryPrice=SymbolInfoDouble(_Symbol, SYMBOL_ASK); stopLoss=inversionLevel-slDistance; takeProfit=entryPrice+tpDistance; comment="Lon FVG V1 Buy"; if(!trade.Buy(Lots,_Symbol,0,stopLoss,takeProfit,comment)) PrintFormat("Buy Fail: %s",trade.ResultRetcodeDescription()); else { PrintFormat("BUY: SL=%.5f TP=%.5f",NormalizeDouble(stopLoss,_Digits),NormalizeDouble(takeProfit,_Digits)); tradeOpenedToday=true; }}
   else { /* Sell */ entryPrice=SymbolInfoDouble(_Symbol,SYMBOL_BID); stopLoss=inversionLevel+slDistance; takeProfit=entryPrice-tpDistance; comment="Lon FVG V1 Sell"; if(!trade.Sell(Lots,_Symbol,0,stopLoss,takeProfit,comment)) PrintFormat("Sell Fail: %s",trade.ResultRetcodeDescription()); else { PrintFormat("SELL: SL=%.5f TP=%.5f",NormalizeDouble(stopLoss,_Digits),NormalizeDouble(takeProfit,_Digits)); tradeOpenedToday=true; }}
}

// Function remains the same
void DrawFVGRectangle()
{
    if(fvgFoundToday && fvgCompletionTime != 0 && ObjectFind(0, fvgObjectName) < 0) {
        long barDuration = PeriodSeconds(); if(barDuration<=0) barDuration=15*60; datetime endTime = fvgCompletionTime + (datetime)(barDuration*20);
        if(ObjectCreate(0,fvgObjectName,OBJ_RECTANGLE,0,fvgCompletionTime,fvgHigh,endTime,fvgLow)){
            ObjectSetInteger(0,fvgObjectName,OBJPROP_COLOR,FVGColor); ObjectSetInteger(0,fvgObjectName,OBJPROP_STYLE,FVGStyle); ObjectSetInteger(0,fvgObjectName,OBJPROP_WIDTH,FVGWidth); ObjectSetInteger(0,fvgObjectName,OBJPROP_FILL,FVGFilled); ObjectSetInteger(0,fvgObjectName,OBJPROP_BACK,true); ObjectSetString(0,fvgObjectName,OBJPROP_TOOLTIP, fvgIsBearish?"First Bearish FVG":"First Bullish FVG");
            ChartRedraw(0); //Print("Drew FVG Rectangle: ",fvgObjectName);
        } else { Print("Error creating FVG rect: ",GetLastError()); }
    }
}

//+------------------------------------------------------------------+
//| Draw the Session Vertical Lines                                 |
//+------------------------------------------------------------------+
void DrawSessionLines(datetime currentTime) // *** NEW FUNCTION ***
{
   // Only draw if they don't exist for the current day check
   if(ObjectFind(0, openLineName) < 0 || ObjectFind(0, closeLineName) < 0)
   {
       MqlDateTime dt;
       TimeToStruct(currentTime, dt); // Get date parts from current time

       // Calculate exact open time for *today*
       dt.hour = LondonOpenHour;
       dt.min = 0;
       dt.sec = 0;
       datetime openTimeToday = StructToTime(dt);

       // Calculate exact close time for *today*
       dt.hour = LondonCloseHour;
       datetime closeTimeToday = StructToTime(dt);

       // Create Open Line if it doesn't exist
       if(ObjectFind(0, openLineName) < 0)
       {
            if(ObjectCreate(0, openLineName, OBJ_VLINE, 0, openTimeToday, 0)) {
                ObjectSetInteger(0, openLineName, OBJPROP_COLOR, SessionLineColor);
                ObjectSetInteger(0, openLineName, OBJPROP_STYLE, SessionLineStyle);
                ObjectSetInteger(0, openLineName, OBJPROP_WIDTH, SessionLineWidth);
                ObjectSetString(0, openLineName, OBJPROP_TOOLTIP, "London Open");
                // Print("Drew London Open Line");
            } else Print("Error creating Open Line: ", GetLastError());
       }

       // Create Close Line if it doesn't exist
        if(ObjectFind(0, closeLineName) < 0)
       {
           if(ObjectCreate(0, closeLineName, OBJ_VLINE, 0, closeTimeToday, 0)) {
                ObjectSetInteger(0, closeLineName, OBJPROP_COLOR, SessionLineColor);
                ObjectSetInteger(0, closeLineName, OBJPROP_STYLE, SessionLineStyle);
                ObjectSetInteger(0, closeLineName, OBJPROP_WIDTH, SessionLineWidth);
                ObjectSetString(0, closeLineName, OBJPROP_TOOLTIP, "London Close");
                // Print("Drew London Close Line");
           } else Print("Error creating Close Line: ", GetLastError());
        }
         ChartRedraw(0); // Redraw after potentially adding lines
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

   datetime serverTimeCurrent = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(serverTimeCurrent, dt);

   //--- Check for new day first ---
   if(dt.day != dayResetCheck) {
      ResetDailyVariables();
      dayResetCheck = dt.day;
      Print("New day detected, variables/objects reset.");
   }

   // --- Draw Session Lines (check every tick/bar if needed, handles missing lines) ---
    DrawSessionLines(serverTimeCurrent); // *** CALL DRAW SESSION LINES ***

   // --- Core Logic only within session ---
   if (!IsLondonSession(serverTimeCurrent)) return;

   MqlDateTime todayDT; TimeToStruct(serverTimeCurrent, todayDT); todayDT.hour=LondonOpenHour; todayDT.min=0; todayDT.sec=0;
   datetime londonOpenTimeToday = StructToTime(todayDT);

   //--- Trading Logic Flow ---
   FVGInfo tempFVG = { false };

   // 1. Find FIRST FVG (if not found today) - Now includes size check
   if(!fvgFoundToday) {
       tempFVG = FindFirstFVG_AfterLondonOpen(londonOpenTimeToday);
       if(tempFVG.found) {
          // Store FVG details globally
          fvgFoundToday = true; fvgIsBearish = tempFVG.isBearish; fvgHigh = tempFVG.high; fvgLow = tempFVG.low; fvgCompletionTime = tempFVG.completionTime;
          // Print("Stored first valid FVG details.");
          DrawFVGRectangle(); // Draw it once found
       }
   }

   // 2. Check for Inversion (if FVG found, but not inverted yet)
   if(fvgFoundToday && !fvgInvertedToday) {
       // Construct temporary FVGInfo from globals for checking
       tempFVG.found = true; tempFVG.isBearish = fvgIsBearish; tempFVG.high = fvgHigh; tempFVG.low = fvgLow; tempFVG.completionTime = fvgCompletionTime;
       if (CheckFVGInversion(tempFVG)) { /* Flags updated inside */ }
   }

   // 3. Check Retest & Place Trade (if FVG found, inverted, and no trade today)
   if(fvgFoundToday && fvgInvertedToday && !tradeOpenedToday) {
        if(CheckRetest()) { PlaceTrade(); }
   }

   // --- Reset if Session ends without a trade trigger ---
   if(dt.hour >= LondonCloseHour && !tradeOpenedToday && fvgFoundToday) {
      Print("London session ended without trade trigger after FVG found/inverted. Resetting.");
      ResetDailyVariables();
   }
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Cleanup drawings on EA removal
   ObjectDelete(0, fvgObjectName);
   ObjectDelete(0, openLineName);
   ObjectDelete(0, closeLineName);
   Print("London FVG Inversion V1.03 Deinitialized. Reason: ", reason);
}
//+------------------------------------------------------------------+