//+------------------------------------------------------------------+
//|                                         OpeningRangeStrategy.mq5 |
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

TimeRange ranges[];
FVG bullishFVGz[];
FVG bearishFVGz[];
SwingPoint swingHighs[];
SwingPoint swingLows[];
string biasDirection = "";
int barsSinceRangeEnd = 0;
double sma20 = 0.0;

// Input parameters
input string ORStartTime = "16:30";           // Opening Range Start time (HH:MM)
input string OREndTime = "17:00";             // Opening Range End time (HH:MM)
input bool DrawOnChart = true;                // Draw ranges on chart
input ENUM_TIMEFRAMES RangeTimeframe = PERIOD_M1; // Timeframe for Opening Range
input ENUM_TIMEFRAMES SwingTimeframe = PERIOD_M1; // Timeframe for Swing Points
input ENUM_TIMEFRAMES SMATimeframe = PERIOD_M5;   // Timeframe for 20 SMA
input int SMA_Period = 20;                    // SMA Period
input int MaxSwingPoints = 5;                 // Number of swing points to identify
input int MinFVGSearchRange = 10;             // Minimum bars to search for FVGs
input double RiskDollars = 100.0;             // Risk in dollars per trade
input double MinRRR = 2.0;                    // Minimum risk to reward ratio
input bool UseBreakeven = true;               // Move to breakeven
input int BarsToBreakeven = 3;                // Bars after entry to move to breakeven
input bool UsePartialProfit = true;           // Take partial profit
input int BarsToPartial = 5;                  // Bars after entry to take partial profit
input double PartialPercent = 0.5;            // Percentage to close on partial

// Variables for tracking
int lastRangeBarIndex = -1;
int entryBar = -1;
int orderState = 0; // 0: no order, 1: entry placed, 2: moved to breakeven, 3: partial profit taken

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   // Initialize the EA
   ObjectsDeleteAll(ChartID(), "");
   EventSetTimer(60);

   Print("OpeningRangeStrategy initialized");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   ObjectsDeleteAll(ChartID(), "");
   EventKillTimer();
   Print("OpeningRangeStrategy deinitialized");
}

//+------------------------------------------------------------------+
//| Check for entry conditions                                       |
//+------------------------------------------------------------------+
void CheckEntryConditions() {
   if(biasDirection == "Bullish" && ArraySize(swingLows) > 0) {
      Print("Bullish bias detected");
      if (swingLows[0].price < sma20) {
         Print("SMA20 condition met");
         if (swingLows[0].price < ranges[0].middle) {
            Print("Middle condition met");
            if (ArraySize(bullishFVGz) > 0 && swingLows[0].price > bullishFVGz[0].midpoint) {
              Print("FVG condition met");
              double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
              double stopLoss = swingLows[0].price - (10 * _Point); // Place SL below swing low
              double takeProfit = CalculateTpPrice(entryPrice, stopLoss, MinRRR);
              double lotSize = CalculateLotSize(RiskDollars, entryPrice, stopLoss, true);

              if(trade.Buy(lotSize, _Symbol, 0, stopLoss, takeProfit, "OR-BUY")) {
                Print("BUY order placed: Entry=", DoubleToString(entryPrice, _Digits),
                      " SL=", DoubleToString(stopLoss, _Digits),
                      " TP=", DoubleToString(takeProfit, _Digits),
                      " Lots=", DoubleToString(lotSize, 2));
              }
            }
         }
      }
   }

   if(biasDirection == "Bearish" && ArraySize(swingHighs) > 0) {
      Print("Bearish bias detected");
      if (swingHighs[0].price > sma20) {
         if (swingHighs[0].price > ranges[0].middle) {
            if (ArraySize(bearishFVGz) > 0 && swingHighs[0].price < bearishFVGz[0].midpoint) {
              double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
              double stopLoss = swingHighs[0].price + (10 * _Point); // Place SL above swing high
              double takeProfit = CalculateTpPrice(entryPrice, stopLoss, MinRRR);
              double lotSize = CalculateLotSize(RiskDollars, entryPrice, stopLoss, true);

              if(trade.Sell(lotSize, _Symbol, 0, stopLoss, takeProfit, "OR-SELL")) {
                Print("SELL order placed: Entry=", DoubleToString(entryPrice, _Digits),
                      " SL=", DoubleToString(stopLoss, _Digits),
                      " TP=", DoubleToString(takeProfit, _Digits),
                      " Lots=", DoubleToString(lotSize, 2));
              }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Manage existing positions                                        |
//+------------------------------------------------------------------+
void ManagePositions() {
   if(!HasActivePositionsOrOrders()) {
      orderState = 0;
      return;
   }

   int currentBar = iBarShift(_Symbol, RangeTimeframe, TimeCurrent());
   int barsSinceEntry = entryBar - currentBar;

   // Move to breakeven after specified bars
   if(UseBreakeven && orderState == 1 && barsSinceEntry >= BarsToBreakeven) {
      MoveSymbolStopLossToBreakeven();
      orderState = 2;
      Print("Position moved to breakeven");
   }

   // Take partial profit after specified bars
   if(UsePartialProfit && orderState >= 2 && barsSinceEntry >= BarsToPartial) {
      TakePartialProfit(PartialPercent);
      orderState = 3;
      Print("Partial profit taken");
   }
}

//+------------------------------------------------------------------+
//| Timer event function                                             |
//+------------------------------------------------------------------+
void OnTimer() {
  sma20 = iMA(_Symbol, SMATimeframe, SMA_Period, 0, MODE_SMA, PRICE_CLOSE);

   GetSwingHighs(MaxSwingPoints, swingHighs, SwingTimeframe, 500, DrawOnChart, clrCrimson);
   GetSwingLows(MaxSwingPoints, swingLows, SwingTimeframe, 500, DrawOnChart, clrCrimson);
   // Reset for a new day
   bool rangeFound = GetRanges(ORStartTime, OREndTime, ranges, 0, "OR", DrawOnChart, RangeTimeframe);
      if(rangeFound) {
         lastRangeBarIndex = ranges[0].endBarIndex;
         biasDirection = ranges[0].type;
         barsSinceRangeEnd = 0;
         orderState = 0;

         Print("Opening Range detected: ", biasDirection,
              " High: ", DoubleToString(ranges[0].high, _Digits),
              " Low: ", DoubleToString(ranges[0].low, _Digits),
              " Middle: ", DoubleToString(ranges[0].middle, _Digits));

         // Get FVGs within the Opening Range
         GetBullishFVGs(ranges[0].startBarIndex, ranges[0].endBarIndex, bullishFVGz, MinFVGSearchRange, DrawOnChart, clrGreenYellow, PERIOD_M1);
         GetBearishFVGs(ranges[0].startBarIndex, ranges[0].endBarIndex, bearishFVGz, MinFVGSearchRange, DrawOnChart, clrDeepPink, PERIOD_M1);

    if (HasActivePositionsOrOrders()) {
      ManagePositions();
    } else {
        CheckEntryConditions();
    }
  }
}