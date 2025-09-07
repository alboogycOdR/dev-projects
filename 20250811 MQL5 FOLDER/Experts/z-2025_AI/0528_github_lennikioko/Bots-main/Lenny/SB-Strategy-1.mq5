//+------------------------------------------------------------------+
//|                                                SB-Strategy-1.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Helpers\GetRange.mqh>
#include <Helpers\GetSwingHighLows.mqh>
#include <Helpers\GetFVGs.mqh>
#include <Helpers\RiskManagement.mqh>
#include <Helpers\OrderManagement.mqh>
#include <Helpers\GetIndicators.mqh>

TimeRange ranges[];
FVG bullishFVGz[];
FVG bearishFVGz[];
SwingPoint swingHighs[];
SwingPoint swingLows[];
string biasDirection = "";
int lastRangeBarIndex = 0;
double entryPrice = 0.0;
double stopLoss = 0.0;
double beRRR = 1.0;
double paritalRRR = 1.0;
bool partialClosed = false;

// money management
double startDayBalance = 0.0;
double maxDailyLoss = 200; // Maximum daily loss in account currency
double dailyTarget = 200; // Daily target
datetime lastReset;

// Input parameters
input string ORStartTime = "16:30";           // Opening Range Start time (HH:MM)
input string OREndTime = "17:00";             // Opening Range End time (HH:MM)
input int startTradingHour = 16;              // Start trading hour (1600 ==  9AM EST, No DST)
input int endTradingHour = 19;                // End trading hour (1900 == 12PM EST, No DST)
input bool DrawOnChart = true;                // Draw ranges on chart
input int MaxSwingPoints = 10;                 // Number of swing points to identify
input int MinFVGSearchRange = 10;             // Minimum bars to search for FVGs
input double RiskDollars = 100.0;             // Risk in dollars per trade
input double MinRRR = 1.0;                    // Minimum risk to reward ratio
input bool UseBreakeven = true;               // Move to breakeven
input bool UsePartialProfit = true;           // Take partial profit
input double PartialPercent = 0.5;            // Percentage to close on partial

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   // Initialize the EA
   ObjectsDeleteAll(ChartID(), "");
   EventSetTimer(60);

   startDayBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   Print("SB-Strategy-1 initialized");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   ObjectsDeleteAll(ChartID(), "");
   EventKillTimer();
   Print("SB-Strategy-1 deinitialized");
}

//+------------------------------------------------------------------+
//| Manage existing positions                                        |
//+------------------------------------------------------------------+

bool IsSBHour() {
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);

   int hour = dt.hour;
   int minute = dt.min;

   if(hour < startTradingHour || hour > endTradingHour) {
      return false;
   }

   // Only trade during minutes 0-15 and 45-59
   if((minute >= 0 && minute < 16) || (minute >= 45 && minute < 60)) {
      return true;
   }

   return false;
}

void ManagePositions() {
   if(!HasActivePositionsOrOrders()) {
      return;
   }

   // Move to breakeven after x
   if(UseBreakeven) {
      MoveSymbolStopLossToBreakeven(beRRR);
      Print("Position moved to breakeven");
   }

   // Take partial profit after x
   if(UsePartialProfit && !partialClosed) {
      partialClosed = TakePartialProfit(paritalRRR, PartialPercent);
      Print("Partial profit taken");
   }
}

//+------------------------------------------------------------------+
//| Timer event function                                             |
//+------------------------------------------------------------------+
void OnTimer() {
  isTradingAllowedBySystem();
  ResetDayBalance(startDayBalance, lastReset);

  GetSwingLows(MaxSwingPoints, swingLows, PERIOD_CURRENT, 500, DrawOnChart, clrCrimson);
  GetSwingHighs(MaxSwingPoints, swingHighs, PERIOD_CURRENT, 500, DrawOnChart, clrDodgerBlue);

  // draw FVGs outside of opening range and SB hour
  GetBullishFVGs(2, MinFVGSearchRange, bullishFVGz, MinFVGSearchRange, DrawOnChart, clrGreenYellow, false);
  GetBearishFVGs(2, MinFVGSearchRange, bearishFVGz, MinFVGSearchRange, DrawOnChart, clrDeepPink, false);


  double prevClose = iClose(_Symbol, PERIOD_CURRENT, 1);

   // Reset for a new day
   bool rangeFound = GetRanges(ORStartTime, OREndTime, ranges, 0, "OR", DrawOnChart, PERIOD_CURRENT);
   if(rangeFound) {
      lastRangeBarIndex = ranges[0].endBarIndex;
      biasDirection = ranges[0].type;

      Print("Opening Range detected: ", biasDirection,
            " High: ", DoubleToString(ranges[0].high, _Digits),
            " Low: ", DoubleToString(ranges[0].low, _Digits),
            " Middle: ", DoubleToString(ranges[0].middle, _Digits));

      GetBullishFVGs(2, ranges[0].startBarIndex, bullishFVGz, MinFVGSearchRange, DrawOnChart, clrGreenYellow, false);
      GetBearishFVGs(2, ranges[0].startBarIndex, bearishFVGz, MinFVGSearchRange, DrawOnChart, clrDeepPink, false);

      if(!HasActivePositionsOrOrders()) {

         // if we form a swing low after the OR range ends and we are above the 20 SMA and the middle of the range and have formed bullish FVGs buy
         if (ArraySize(swingLows) > 0 && swingLows[0].bar < lastRangeBarIndex) {
            Print("Swing Low formed after range");
            if(CheckIsAboveSMA(prevClose, 20)) {
               Print("SMA20 condition met");
               if(prevClose > ranges[0].middle) {
                  Print("Middle condition met");
                  if(ArraySize(bullishFVGz) > 0) {
                     Print("Presence of bullish FVGs met");
                     if(IsSBHour() && !CheckMaxDailyLossExceeded(startDayBalance, maxDailyLoss) && !CheckDailyTargetReached(startDayBalance, dailyTarget)) {
                        Print("SB hour & account risk conditions met");
                        entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK); // used to calculate Be and partials
                        stopLoss = ranges[0].middle - (1 * GetPipValue()); // Place SL 1 pips below swing low
                        double takeProfit = CalculateTpPrice(entryPrice, stopLoss, MinRRR);
                        double lotSize = CalculateLotSize(RiskDollars, entryPrice, stopLoss, true);

                        if(!trade.Buy(lotSize, _Symbol, 0, stopLoss, takeProfit, "OR-BUY")) {
                           Print("Failed to place buy order. Error: ", GetLastError());
                        } else {
                           Print("Buy order placed successfully.");
                        }
                     } else {
                        Print("Not in SB hour or account risk invalid, skipping order placement.");
                        return;
                     }

                  }
               }
            }
         }

         // if we form a swing high after the OR range ends and we are below the 20 SMA and the middle of the range and have formed bearish FVGs sell
         if (ArraySize(swingHighs) > 0 && swingHighs[0].bar < lastRangeBarIndex) {
            Print("Swing High formed after range");
            if(!CheckIsAboveSMA(prevClose, 20)) {
               Print("SMA20 condition met");
               if(prevClose < ranges[0].middle) {
                  Print("Middle condition met");
                  if(ArraySize(bearishFVGz) > 0) {
                     Print("Presence of bearish FVGs met");
                     if(IsSBHour() && !CheckMaxDailyLossExceeded(startDayBalance, maxDailyLoss) && !CheckDailyTargetReached(startDayBalance, dailyTarget)) {
                        Print("SB hour & account risk conditions met");
                        entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID); // used to calculate Be and partials
                        stopLoss = ranges[0].middle + (1 * GetPipValue()); // Place SL 1 pips above midpoint
                        double takeProfit = CalculateTpPrice(entryPrice, stopLoss, MinRRR);
                        double lotSize = CalculateLotSize(RiskDollars, entryPrice, stopLoss, true);

                        if(!trade.Sell(lotSize, _Symbol, 0, stopLoss, takeProfit, "OR-SELL")) {
                           Print("Failed to place sell order. Error: ", GetLastError());
                        } else {
                           Print("Sell order placed successfully.");
                        }
                     } else {
                        Print("Not in SB hour or account risk invalid, skipping order placement.");
                        return;
                     }
                  }
               }
            }
         }
      } else {
        ManagePositions();
      }
   }
}
