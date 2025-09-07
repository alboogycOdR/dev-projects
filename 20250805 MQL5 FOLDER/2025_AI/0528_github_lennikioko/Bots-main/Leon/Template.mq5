//+------------------------------------------------------------------+
//|                                                TestingRanges.mq5 |
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

// Global variables
FVG bullFVGs[];
FVG bearFVGs[];

SwingPoint swingHighs[];
SwingPoint swingLows[];

OpeningRange ranges[];

ENUM_TIMEFRAMES lastTimeframe;  // To track timeframe changes

// Input parameters for customizing swing points
input bool ShowFVGs = true;          // Show swing points on chart
input color BullishFVGColor = clrGreenYellow; // Bullish FVG color
input color BearishFVGColor = clrDeepPink; // Bearish FVG color
input int MaxBarsToAnalyze = 100;

input bool ShowSwingPoints = true;          // Show swing points on chart
input color SwingHighColor = clrDodgerBlue; // Swing high color
input color SwingLowColor = clrCrimson;     // Swing low color
input int MaxSwingPoints = 10;              // Number of swing points to identify
`
input string ORStartTime = "16:30";           // Start time (HH:MM)
input string OREndTime = "17:00";             // End time (HH:MM)
input int ORDaysBack = 0;                     // Number of past days to analyze
input string ORRangeName = "OR";         // Name prefix for the range objects
input bool DrawOnChart = true;              // Draw ranges on chart
input color ORLineColor = clrDodgerBlue;      // Line color
input color ORHighPointColor = clrGreen;      // High point color
input color ORLowPointColor = clrRed;         // Low point color
input color ORMidLevelColor = clrGoldenrod;   // Middle level color
input ENUM_TIMEFRAMES TimeframeToUse = PERIOD_CURRENT;  // Max bars to scan for swing points

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   ObjectsDeleteAll(ChartID(), "");
   EventSetTimer(1);

   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   // Delete all objects from the chart
   ObjectsDeleteAll(ChartID(), "");
   EventKillTimer();
}


//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTimer() {
   // Check for timeframe changes
   ENUM_TIMEFRAMES currentTimeframe = Period();
   if(currentTimeframe != lastTimeframe) {
      // Clear all objects
      ObjectsDeleteAll(ChartID(), "");

      // Update tracked timeframe
      lastTimeframe = currentTimeframe;
   }

   // Update swing points with automatic plotting
    GetBullishFVGs(2, MaxBarsToAnalyze, bullFVGs, 10, ShowFVGs, BullishFVGColor);
    GetBearishFVGs(2, MaxBarsToAnalyze, bearFVGs, 10, ShowFVGs, BearishFVGColor);

    GetSwingHighs(MaxSwingPoints, swingHighs, PERIOD_CURRENT, MaxBarsToAnalyze, ShowSwingPoints, SwingHighColor);
    GetSwingLows(MaxSwingPoints, swingLows, PERIOD_CURRENT, MaxBarsToAnalyze, ShowSwingPoints, SwingLowColor);

    // Update ranges
    OpeningRange GetRanges(ORStartTime, OREndTime, ranges, ORDaysBack, ORRangeName, true, TimeframeToUse);
}

