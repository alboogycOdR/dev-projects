//+------------------------------------------------------------------+
//|                               FirstFVGPast1630.mq5                |
//|                                  Copyright 2024                   |
//|                          FVGs detected on M1 timeframe            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      "https://www.example.com"
#property version   "1.00"
#property strict

// Include helper modules
#include <Helpers/GetFVGs.mqh>
#include <Helpers/TextDisplay.mqh>

// Structure to store historical FVG data
struct HistoricalFVG {
   datetime date;           // Date of the FVG
   FVG      bullishFVG;     // First bullish FVG of the day
   FVG      bearishFVG;     // First bearish FVG of the day
   FVG      firstFVG;       // First FVG (either bullish or bearish)
   bool     exists;         // Whether any FVG exists for this day
   bool     isFirstFVGBullish; // Type of the first FVG
   color    lineColor;      // Color used for this day's lines
};

// Input parameters
input string TimeSettings = "===== Time Settings ====="; // Time Settings
input string SearchStartTime = "16:30";          // FVG Search Start Time (16:30 market hours)
input string SearchEndTime = "17:00";            // FVG Search End Time
input int    DaysToDisplay = 30;                 // Number of days to display (max 30)
input int    MinFVGSearchBars = 200;             // Minimum bars to search for FVGs

input string AdditionalLines = "===== Additional Lines ====="; // Additional Lines
input int    NYMidnightDays = 2;                // Number of NY-Midnight (7:00) lines to display
input int    DailyOpenDays = 1;                 // Number of daily open lines to display
input int    TimeMarkerDays = 5;                // Number of 16:30 time marker lines to display
input color  NYMidnightColor = clrYellow;       // NY-Midnight line color
input color  DailyOpenColor = clrOrange;        // Daily open line color
input color  TimeMarkerColor = clrDodgerBlue;   // Time marker line color

input string VisualSettings = "===== Visual Settings ====="; // Visual Settings
input bool   ShowBullishFVGs = true;             // Show Bullish FVGs
input bool   ShowBearishFVGs = true;             // Show Bearish FVGs
input bool   ShowOnlyFirst = true;               // Show only first FVG of each day
input bool   ShowScreenText = false;              // Show text information on screen
input color  BullFVGBaseColor = clrGreenYellow;  // Base color for Bullish FVGs
input color  BearFVGBaseColor = clrDeepPink;     // Base color for Bearish FVGs

// Add a new input parameter to clarify the logic
input bool   SkipFirstCandle = true;             // Skip first candle (16:30) when searching

// Global variables
HistoricalFVG g_HistoricalFVGs[30];             // Array to store 30 days of FVGs
int g_CurrentDay = 0;                           // Current day index
datetime g_LastUpdateTime = 0;                  // Last update time
color g_ColorPalette[10] = {clrRed, clrGreen, clrBlue, clrYellow, clrMagenta,
                           clrCyan, clrOrange, clrPurple, clrBrown, clrIndigo}; // Color palette
int g_prev_timeframe = PERIOD_CURRENT;         // Store current timeframe to detect changes

#property description "Displays historical FVGs and important price levels"

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   // Initialize FVG history array
   InitializeHistoricalFVGs();

   // Standard 1-second timer for more responsive updates and timeframe detection
   EventSetTimer(1);

   // Store the current timeframe
   g_prev_timeframe = Period();

   Print("Initial timeframe: ", EnumToString((ENUM_TIMEFRAMES)g_prev_timeframe));

   // Force update by resetting the timer
   g_LastUpdateTime = 0;

   // Update FVGs immediately
   UpdateAllVisuals();

   // Redraw the chart to ensure all objects are visible
   ChartRedraw();

   Print("FVG EA initialized on timeframe ", EnumToString((ENUM_TIMEFRAMES)Period()),
         " displaying ", DaysToDisplay, " days of FVGs.");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Chart event handler - we'll keep this for other chart events     |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
   // We'll rely on the timer for timeframe change detection instead
}

//+------------------------------------------------------------------+
//| Update all visual elements                                       |
//+------------------------------------------------------------------+
void UpdateAllVisuals() {
   // Update and draw FVGs without deleting existing lines first
   UpdateHistoricalFVGs();

   // Draw NY-Midnight lines (7:00 open)
   DrawNYMidnightLines();

   // Draw daily open price lines
   DrawDailyOpenLines();

   // Draw time marker lines (16:30)
   DrawTimeMarkerLines();

   // Ensure the chart is redrawn to show all objects
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   // Clean up resources
   EventKillTimer();
   DeleteAllLines();
}

//+------------------------------------------------------------------+
//| Timer event function                                             |
//+------------------------------------------------------------------+
void OnTimer() {
   // Check if timeframe has changed since last check
   int currentPeriod = Period();
   if(g_prev_timeframe != currentPeriod) {
      Print("Timeframe change detected: ", EnumToString((ENUM_TIMEFRAMES)g_prev_timeframe),
            " to ", EnumToString((ENUM_TIMEFRAMES)currentPeriod));
      g_prev_timeframe = currentPeriod;

      // Force update
      g_LastUpdateTime = 0;

      // Force immediate update of all visuals
      UpdateAllVisuals();

      // Redraw the chart to ensure all objects are visible
      ChartRedraw();
      return; // Exit to avoid double-updating
   }

   // Update all visuals if needed
   UpdateAllVisuals();

   // Clear text display
   clearTextDisplay();

   // Display status
   DisplayStatus();
}

//+------------------------------------------------------------------+
//| Initialize the historical FVG array                              |
//+------------------------------------------------------------------+
void InitializeHistoricalFVGs() {
   // Initialize the array with empty values
   for(int i = 0; i < 30; i++) {
      g_HistoricalFVGs[i].exists = false;
      g_HistoricalFVGs[i].date = 0;

      // Assign different colors to different days (cycling through palette)
      int colorIndex = i % 10;
      g_HistoricalFVGs[i].lineColor = g_ColorPalette[colorIndex];
   }
}

//+------------------------------------------------------------------+
//| Update historical FVGs for all days                              |
//+------------------------------------------------------------------+
void UpdateHistoricalFVGs() {
   // Get current time
   datetime now = TimeCurrent();
   MqlDateTime nowStruct;
   TimeToStruct(now, nowStruct);

   // Always redraw on timeframe change, but otherwise check time
   if(Period() == g_prev_timeframe && now - g_LastUpdateTime < 3600) {
      return;
   }

   // Update last update time
   g_LastUpdateTime = now;

   // We don't delete existing FVG lines to keep them persistent

   // Process each day, starting from today and going back
   int daysProcessed = 0;
   int dayOffset = 0;

   // Debugging counters
   int totalDaysChecked = 0;
   int daysWithNoData = 0;
   int daysWithNoFVGs = 0;

   // Continue until we've processed the requested number of trading days
   while(daysProcessed < DaysToDisplay && dayOffset < 100) { // Limit to 100 days to prevent infinite loop
      // Calculate the date for this offset
      datetime targetDate = now - (dayOffset * 86400); // 86400 seconds in a day
      MqlDateTime targetDateStruct;
      TimeToStruct(targetDate, targetDateStruct);

      // Skip weekends (0 = Sunday, 6 = Saturday)
      if(targetDateStruct.day_of_week == 0 || targetDateStruct.day_of_week == 6) {
         dayOffset++;
         continue;
      }

      // For today, check if we've reached the search time window
      if(dayOffset == 0) {  // If this is today
         // Calculate today's search start time
         MqlDateTime searchTimeStruct = targetDateStruct;
         searchTimeStruct.hour = (int)StringToInteger(StringSubstr(SearchStartTime, 0, 2));
         searchTimeStruct.min = (int)StringToInteger(StringSubstr(SearchStartTime, 3, 2));
         searchTimeStruct.sec = 0;
         datetime todaySearchStart = StructToTime(searchTimeStruct);

         // If current time is before search window, skip today
         if(now < todaySearchStart) {
            Print("Skipping today as current time ", TimeToString(now), " is before search window ",
                  TimeToString(todaySearchStart));
            dayOffset++;
            continue;
         }
      }

      // Set hours/minutes to midnight to get start of day
      targetDateStruct.hour = 0;
      targetDateStruct.min = 0;
      targetDateStruct.sec = 0;
      datetime dayStart = StructToTime(targetDateStruct);

      // Set hours/minutes to end of day
      targetDateStruct.hour = 23;
      targetDateStruct.min = 59;
      targetDateStruct.sec = 59;
      datetime dayEnd = StructToTime(targetDateStruct);

      // Calculate search time window within the day
      int searchStartHour = (int)StringToInteger(StringSubstr(SearchStartTime, 0, 2));
      int searchStartMin = (int)StringToInteger(StringSubstr(SearchStartTime, 3, 2));

      int searchEndHour = (int)StringToInteger(StringSubstr(SearchEndTime, 0, 2));
      int searchEndMin = (int)StringToInteger(StringSubstr(SearchEndTime, 3, 2));

      // Calculate search start and end times
      targetDateStruct.hour = searchStartHour;
      targetDateStruct.min = searchStartMin;
      targetDateStruct.sec = 0;
      datetime searchStart = StructToTime(targetDateStruct);

      // Skip the first candle (16:30) if requested
      if(SkipFirstCandle) {
         // Add one minute to skip the first candle
         searchStart += 60; // Add 60 seconds = 1 minute
      }

      targetDateStruct.hour = searchEndHour;
      targetDateStruct.min = searchEndMin;
      targetDateStruct.sec = 59;
      datetime searchEnd = StructToTime(targetDateStruct);

      // Find the bar indices corresponding to the search times
      int startBar = GetBarIndexFromTime(searchStart);
      int endBar = GetBarIndexFromTime(searchEnd);

      if(startBar < 0 || endBar < 0) {
         // Skip days where we can't find the bars
         daysWithNoData++;
         dayOffset++;
         totalDaysChecked++;

         // Debug why we're skipping
         MqlDateTime debugDateStruct;
         TimeToStruct(dayStart, debugDateStruct);
         string debugDateStr = IntegerToString(debugDateStruct.year) + "-" +
                             IntegerToString(debugDateStruct.mon) + "-" +
                             IntegerToString(debugDateStruct.day);

         Print("SKIPPING Day: ", debugDateStr, " - Cannot find bars for time window ",
               TimeToString(searchStart), " to ", TimeToString(searchEnd),
               " (StartBar=", startBar, ", EndBar=", endBar, ")");
         continue;
      }

      // Initialize FVG struct for this day
      g_HistoricalFVGs[daysProcessed].date = dayStart;
      g_HistoricalFVGs[daysProcessed].exists = false;

      // Get FVGs for this day
      FVG bullishFVGs[];
      FVG bearishFVGs[];

      GetBullishFVGs(startBar, endBar, bullishFVGs, MinFVGSearchBars, false, BullFVGBaseColor, PERIOD_M1);
      GetBearishFVGs(startBar, endBar, bearishFVGs, MinFVGSearchBars, false, BearFVGBaseColor, PERIOD_M1);

      // Store first bullish FVG if any
      if(ArraySize(bullishFVGs) > 0) {
         // Find the chronologically first bullish FVG (oldest in the array)
         int oldestIndex = ArraySize(bullishFVGs) - 1;
         g_HistoricalFVGs[daysProcessed].bullishFVG = bullishFVGs[oldestIndex];
         g_HistoricalFVGs[daysProcessed].exists = true;
      } else {
         g_HistoricalFVGs[daysProcessed].bullishFVG.exists = false;
      }

      // Store first bearish FVG if any
      if(ArraySize(bearishFVGs) > 0) {
         // Find the chronologically first bearish FVG (oldest in the array)
         int oldestIndex = ArraySize(bearishFVGs) - 1;
         g_HistoricalFVGs[daysProcessed].bearishFVG = bearishFVGs[oldestIndex];
         g_HistoricalFVGs[daysProcessed].exists = true;
      } else {
         g_HistoricalFVGs[daysProcessed].bearishFVG.exists = false;
      }

      // Determine which came first chronologically
      if(g_HistoricalFVGs[daysProcessed].bullishFVG.exists && g_HistoricalFVGs[daysProcessed].bearishFVG.exists) {
         if(g_HistoricalFVGs[daysProcessed].bullishFVG.time <= g_HistoricalFVGs[daysProcessed].bearishFVG.time) {
            g_HistoricalFVGs[daysProcessed].firstFVG = g_HistoricalFVGs[daysProcessed].bullishFVG;
            g_HistoricalFVGs[daysProcessed].isFirstFVGBullish = true;
         } else {
            g_HistoricalFVGs[daysProcessed].firstFVG = g_HistoricalFVGs[daysProcessed].bearishFVG;
            g_HistoricalFVGs[daysProcessed].isFirstFVGBullish = false;
         }
      } else if(g_HistoricalFVGs[daysProcessed].bullishFVG.exists) {
         g_HistoricalFVGs[daysProcessed].firstFVG = g_HistoricalFVGs[daysProcessed].bullishFVG;
         g_HistoricalFVGs[daysProcessed].isFirstFVGBullish = true;
      } else if(g_HistoricalFVGs[daysProcessed].bearishFVG.exists) {
         g_HistoricalFVGs[daysProcessed].firstFVG = g_HistoricalFVGs[daysProcessed].bearishFVG;
         g_HistoricalFVGs[daysProcessed].isFirstFVGBullish = false;
      }

      // Increment counters
      daysProcessed++;
      dayOffset++;
      totalDaysChecked++;

      // Debug: Print detailed information about this day
      string dayType = g_HistoricalFVGs[daysProcessed-1].exists ?
                      (g_HistoricalFVGs[daysProcessed-1].isFirstFVGBullish ? "Bullish" : "Bearish") :
                      "No FVG";

      if (!g_HistoricalFVGs[daysProcessed-1].exists) {
         daysWithNoFVGs++;
      }

      MqlDateTime debugDateStruct;
      TimeToStruct(dayStart, debugDateStruct);
      string debugDateStr = IntegerToString(debugDateStruct.year) + "-" +
                          IntegerToString(debugDateStruct.mon) + "-" +
                          IntegerToString(debugDateStruct.day);

      Print("Day #", daysProcessed, " (", debugDateStr, "): ",
           "StartBar=", startBar, " EndBar=", endBar,
           " BullFVGs=", ArraySize(bullishFVGs),
           " BearFVGs=", ArraySize(bearishFVGs),
           " Result=", dayType);
   }

   // Draw the FVG lines
   DrawFVGLines();

   // Update display information
   if(ShowScreenText) {
      addTextOnScreen("Processed " + IntegerToString(daysProcessed) + " trading days (skipped weekends)", clrGold);
      addTextOnScreen("Checked " + IntegerToString(totalDaysChecked) + " calendar days", clrSilver);
      addTextOnScreen("Found data for " + IntegerToString(daysProcessed) + " trading days", clrSilver);
      addTextOnScreen("No data for " + IntegerToString(daysWithNoData) + " days", clrSilver);
      addTextOnScreen("No FVGs in " + IntegerToString(daysWithNoFVGs) + " days with data", clrSilver);
   }

   // Add detailed debug info to display and log
   Print("SUMMARY: Processed ", totalDaysChecked, " calendar days, found ", daysProcessed, " trading days, ",
         daysWithNoData, " days had no bar data, ",
         daysWithNoFVGs, " days had no FVGs in the time window");
}

//+------------------------------------------------------------------+
//| Get the bar index corresponding to a specific time               |
//+------------------------------------------------------------------+
int GetBarIndexFromTime(datetime targetTime) {
   MqlDateTime targetStruct;
   TimeToStruct(targetTime, targetStruct);

   for(int i = 0; i < 10000; i++) { // Limit search to 10,000 bars
      datetime barTime = iTime(_Symbol, PERIOD_M1, i);
      MqlDateTime barStruct;
      TimeToStruct(barTime, barStruct);

      // Check if we're on the same day and the bar time matches or is just before target time
      if(barStruct.day == targetStruct.day &&
         barStruct.mon == targetStruct.mon &&
         barStruct.year == targetStruct.year &&
         barTime <= targetTime) {
         return i;
      }

      // If we've gone past the day we're looking for, stop searching
      if(barTime < targetTime &&
         (barStruct.day != targetStruct.day ||
          barStruct.mon != targetStruct.mon ||
          barStruct.year != targetStruct.year)) {
         return -1;
      }
   }
   return -1; // Not found
}

//+------------------------------------------------------------------+
//| Draw horizontal lines for all historical FVGs                    |
//+------------------------------------------------------------------+
void DrawFVGLines() {
   Print("Drawing FVG lines on timeframe: ", EnumToString((ENUM_TIMEFRAMES)Period()));

   for(int i = 0; i < DaysToDisplay; i++) {
      if(!g_HistoricalFVGs[i].exists)
         continue;

      // Format date string for labels
      MqlDateTime dateStruct;
      TimeToStruct(g_HistoricalFVGs[i].date, dateStruct);
      string dateStr = IntegerToString(dateStruct.year) + "-" +
                      IntegerToString(dateStruct.mon) + "-" +
                      IntegerToString(dateStruct.day);

      // Draw based on the user's preferences
      if(ShowOnlyFirst) {
         // Show only the first FVG of each day
         if(g_HistoricalFVGs[i].firstFVG.exists) {
            string objNameHigh = "FirstFVG_High_" + IntegerToString(i);
            string objNameLow = "FirstFVG_Low_" + IntegerToString(i);
            string objType = g_HistoricalFVGs[i].isFirstFVGBullish ? "Bullish" : "Bearish";

            DrawHorizontalLine(objNameHigh, g_HistoricalFVGs[i].firstFVG.high, g_HistoricalFVGs[i].lineColor,
                             dateStr + " " + objType + " FVG High");

            DrawHorizontalLine(objNameLow, g_HistoricalFVGs[i].firstFVG.low, g_HistoricalFVGs[i].lineColor,
                             dateStr + " " + objType + " FVG Low");
         }
      } else {
         // Show both bullish and bearish FVGs if available
         if(ShowBullishFVGs && g_HistoricalFVGs[i].bullishFVG.exists) {
            string objNameHigh = "BullFVG_High_" + IntegerToString(i);
            string objNameLow = "BullFVG_Low_" + IntegerToString(i);

            DrawHorizontalLine(objNameHigh, g_HistoricalFVGs[i].bullishFVG.high,
                             BullFVGBaseColor, dateStr + " Bullish FVG High");

            DrawHorizontalLine(objNameLow, g_HistoricalFVGs[i].bullishFVG.low,
                             BullFVGBaseColor, dateStr + " Bullish FVG Low");
         }

         if(ShowBearishFVGs && g_HistoricalFVGs[i].bearishFVG.exists) {
            string objNameHigh = "BearFVG_High_" + IntegerToString(i);
            string objNameLow = "BearFVG_Low_" + IntegerToString(i);

            DrawHorizontalLine(objNameHigh, g_HistoricalFVGs[i].bearishFVG.high,
                             BearFVGBaseColor, dateStr + " Bearish FVG High");

            DrawHorizontalLine(objNameLow, g_HistoricalFVGs[i].bearishFVG.low,
                             BearFVGBaseColor, dateStr + " Bearish FVG Low");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Draw a horizontal line with proper labeling                      |
//+------------------------------------------------------------------+
void DrawHorizontalLine(string name, double price, color lineColor, string description) {
   // Get FVG time from the object name
   string parts[];
   StringSplit(name, '_', parts);
   int dayIndex = (int)StringToInteger(parts[ArraySize(parts)-1]);

   // Get FVG formation time
   datetime fvgTime = 0;

   // Determine if this is a bullish or bearish FVG high/low line
   if(StringFind(name, "FirstFVG") >= 0) {
      fvgTime = g_HistoricalFVGs[dayIndex].firstFVG.time;
   } else if(StringFind(name, "BullFVG") >= 0) {
      fvgTime = g_HistoricalFVGs[dayIndex].bullishFVG.time;
   } else if(StringFind(name, "BearFVG") >= 0) {
      fvgTime = g_HistoricalFVGs[dayIndex].bearishFVG.time;
   }

   // If we couldn't get the time, use current time as a fallback
   if(fvgTime == 0) {
      fvgTime = TimeCurrent();
   }

   // Set the line to extend to the current time
   datetime currentTime = TimeCurrent();

   // Check if object already exists
   if(ObjectFind(0, name) >= 0) {
      // Update existing object
      ObjectMove(0, name, 0, fvgTime, price);
      ObjectMove(0, name, 1, currentTime, price);
   } else {
      // Create a new trend line (horizontal) starting at the FVG time
      if(!ObjectCreate(0, name, OBJ_TREND, 0, fvgTime, price, currentTime, price)) {
         Print("Error creating line: ", GetLastError());
         return;
      }

      // Set line properties
      ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true); // Extend to the right
   }

   // Always update description for hover text
   ObjectSetString(0, name, OBJPROP_TOOLTIP, description);
   ObjectSetString(0, name, OBJPROP_TEXT, description);
}

//+------------------------------------------------------------------+
//| Delete all FVG lines                                             |
//+------------------------------------------------------------------+
void DeleteAllFVGLines() {
   ObjectsDeleteAll(0, "FirstFVG_");
   ObjectsDeleteAll(0, "BullFVG_");
   ObjectsDeleteAll(0, "BearFVG_");
}

//+------------------------------------------------------------------+
//| Display status information                                       |
//+------------------------------------------------------------------+
void DisplayStatus() {
   if(!ShowScreenText) return;  // Exit early if screen text is disabled

   addTextOnScreen("FVG EA - Displaying first FVGs past 16:30 for last " + IntegerToString(DaysToDisplay) + " days", clrWhite);
   addTextOnScreen("Search window: " + SearchStartTime + " to " + SearchEndTime + " (based on M1 timeframe)", clrWhite);
   addTextOnScreen("Current Timeframe: " + EnumToString((ENUM_TIMEFRAMES)Period()), clrWhite);

   // Display information about additional lines
   addTextOnScreen("Additional Lines:", clrWhite);
   addTextOnScreen("- NY-Midnight (7:00) lines: " + IntegerToString(NYMidnightDays), NYMidnightColor);
   addTextOnScreen("- Daily Open lines: " + IntegerToString(DailyOpenDays), DailyOpenColor);
   addTextOnScreen("- 16:30 Time Markers: " + IntegerToString(TimeMarkerDays), TimeMarkerColor);

   // Display information for each day that has FVGs
   int fvgCount = 0;
   for(int i = 0; i < DaysToDisplay; i++) {
      if(g_HistoricalFVGs[i].exists) {
         fvgCount++;

         // Format date string
         MqlDateTime dateStruct;
         TimeToStruct(g_HistoricalFVGs[i].date, dateStruct);
         string dateStr = IntegerToString(dateStruct.year) + "-" +
                         IntegerToString(dateStruct.mon, 2, '0') + "-" +
                         IntegerToString(dateStruct.day, 2, '0');

         if(ShowOnlyFirst) {
            // Show info about the first FVG
            if(g_HistoricalFVGs[i].firstFVG.exists) {
               string fvgType = g_HistoricalFVGs[i].isFirstFVGBullish ? "Bullish" : "Bearish";

               addTextOnScreen(dateStr + ": First FVG - " + fvgType +
                              " H: " + DoubleToString(g_HistoricalFVGs[i].firstFVG.high, _Digits) +
                              " L: " + DoubleToString(g_HistoricalFVGs[i].firstFVG.low, _Digits),
                              g_HistoricalFVGs[i].lineColor);
            }
         } else {
            // Show both FVG types if they exist
            if(g_HistoricalFVGs[i].bullishFVG.exists) {
               addTextOnScreen(dateStr + ": Bull FVG - " +
                              "H: " + DoubleToString(g_HistoricalFVGs[i].bullishFVG.high, _Digits) +
                              " L: " + DoubleToString(g_HistoricalFVGs[i].bullishFVG.low, _Digits),
                              BullFVGBaseColor);
            }

            if(g_HistoricalFVGs[i].bearishFVG.exists) {
               addTextOnScreen(dateStr + ": Bear FVG - " +
                              "H: " + DoubleToString(g_HistoricalFVGs[i].bearishFVG.high, _Digits) +
                              " L: " + DoubleToString(g_HistoricalFVGs[i].bearishFVG.low, _Digits),
                              BearFVGBaseColor);
            }
         }
      }
   }

   // Show total count
   addTextOnScreen("Total days with FVGs found: " + IntegerToString(fvgCount), clrYellow);
}

//+------------------------------------------------------------------+
//| Calculate a brighter/darker color variation                      |
//+------------------------------------------------------------------+
color ModifyColor(color baseColor, int dayOffset) {
   // Extract color components
   uchar r = (uchar)(baseColor >> 16);
   uchar g = (uchar)(baseColor >> 8);
   uchar b = (uchar)baseColor;

   // Modify based on day offset
   r = (uchar)MathMin(255, r + (dayOffset * 8));
   g = (uchar)MathMin(255, g + (dayOffset * 8));
   b = (uchar)MathMin(255, b + (dayOffset * 8));

   // Reconstruct color
   return ((color)((r << 16) | (g << 8) | b));
}

//+------------------------------------------------------------------+
//| Draw NY-Midnight (7:00) lines for specified number of days       |
//+------------------------------------------------------------------+
void DrawNYMidnightLines() {
   datetime now = TimeCurrent();
   int dayOffset = 0;
   int daysProcessed = 0;

   // Process until we've drawn the requested number of days
   while(daysProcessed < NYMidnightDays && dayOffset < 50) {
      datetime targetDate = now - (dayOffset * 86400);
      MqlDateTime targetDateStruct;
      TimeToStruct(targetDate, targetDateStruct);

      // Skip weekends
      if(targetDateStruct.day_of_week == 0 || targetDateStruct.day_of_week == 6) {
         dayOffset++;
         continue;
      }

      // Set to 7:00 (NY-Midnight)
      targetDateStruct.hour = 7;
      targetDateStruct.min = 0;
      targetDateStruct.sec = 0;
      datetime nyMidnightTime = StructToTime(targetDateStruct);

      // Get the price at 7:00
      double openPrice = iOpen(_Symbol, PERIOD_M1, iBarShift(_Symbol, PERIOD_M1, nyMidnightTime, false));

      // Only proceed if we have a valid price
      if(openPrice > 0) {
         // Format date for label
         string dateStr = IntegerToString(targetDateStruct.year) + "-" +
                         IntegerToString(targetDateStruct.mon, 2, '0') + "-" +
                         IntegerToString(targetDateStruct.day, 2, '0');

         // Draw the line
         string objName = "NYMidnight_" + dateStr;
         DrawHorizontalRayLine(objName, openPrice, nyMidnightTime, NYMidnightColor,
                           dateStr + " NY-Midnight (7:00) " + DoubleToString(openPrice, _Digits));

         daysProcessed++;
      }

      dayOffset++;
   }
}

//+------------------------------------------------------------------+
//| Draw daily open price lines for specified number of days         |
//+------------------------------------------------------------------+
void DrawDailyOpenLines() {
   int tradingDaysProcessed = 0;
   int shift = 0;

   // Process until we've drawn the requested number of days
   while(tradingDaysProcessed < DailyOpenDays && shift < 50) {
      // Get the daily open price directly using shift values
      double openPrice = iOpen(_Symbol, PERIOD_D1, shift);

      // Get the time for this daily bar
      datetime barTime = iTime(_Symbol, PERIOD_D1, shift);

      // Convert to structured time for formatting
      MqlDateTime barTimeStruct;
      TimeToStruct(barTime, barTimeStruct);

      // Only proceed if we have a valid price and it's not a weekend
      if(openPrice > 0 && barTimeStruct.day_of_week != 0 && barTimeStruct.day_of_week != 6) {
         // Format date for label
         string dateStr = IntegerToString(barTimeStruct.year) + "-" +
                         IntegerToString(barTimeStruct.mon, 2, '0') + "-" +
                         IntegerToString(barTimeStruct.day, 2, '0');

         // Draw the line
         string objName = "DailyOpen_" + dateStr;
         DrawHorizontalRayLine(objName, openPrice, barTime, DailyOpenColor,
                           dateStr + " Daily Open " + DoubleToString(openPrice, _Digits));

         tradingDaysProcessed++;
      }

      shift++;
   }
}

//+------------------------------------------------------------------+
//| Draw time marker lines at 16:30 for specified number of days     |
//+------------------------------------------------------------------+
void DrawTimeMarkerLines() {
   datetime now = TimeCurrent();
   int dayOffset = 0;
   int daysProcessed = 0;

   // Process until we've drawn the requested number of days
   while(daysProcessed < TimeMarkerDays && dayOffset < 50) {
      datetime targetDate = now - (dayOffset * 86400);
      MqlDateTime targetDateStruct;
      TimeToStruct(targetDate, targetDateStruct);

      // Skip weekends
      if(targetDateStruct.day_of_week == 0 || targetDateStruct.day_of_week == 6) {
         dayOffset++;
         continue;
      }

      // Set to 16:30
      targetDateStruct.hour = 16;
      targetDateStruct.min = 30;
      targetDateStruct.sec = 0;
      datetime markerTime = StructToTime(targetDateStruct);

      // Format date for label
      string dateStr = IntegerToString(targetDateStruct.year) + "-" +
                     IntegerToString(targetDateStruct.mon, 2, '0') + "-" +
                     IntegerToString(targetDateStruct.day, 2, '0');

            // Draw the line - using vertical line for time marker
      string objName = "TimeMarker_" + dateStr;

      if(ObjectFind(0, objName) >= 0) {
         // Update existing line
         ObjectMove(0, objName, 0, markerTime, 0);
      } else {
         // Create new line
         if(!ObjectCreate(0, objName, OBJ_VLINE, 0, markerTime, 0)) {
            Print("Error creating vertical line: ", GetLastError());
         } else {
            ObjectSetInteger(0, objName, OBJPROP_COLOR, TimeMarkerColor);
            ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DASH);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, objName, OBJPROP_BACK, false);
         }
      }
      // Always update tooltip
      ObjectSetString(0, objName, OBJPROP_TOOLTIP, dateStr + " 16:30 Marker");

      daysProcessed++;
      dayOffset++;
   }
}

//+------------------------------------------------------------------+
//| Draw a horizontal ray line starting at a specific time           |
//+------------------------------------------------------------------+
void DrawHorizontalRayLine(string name, double price, datetime startTime, color lineColor, string description) {
   // Check if object already exists
   if(ObjectFind(0, name) >= 0) {
      // Update existing object
      ObjectMove(0, name, 0, startTime, price);
      ObjectMove(0, name, 1, startTime + 86400, price);
   } else {
      // Create a ray line starting at the specified time
      if(!ObjectCreate(0, name, OBJ_TREND, 0, startTime, price, startTime + 86400, price)) {
         Print("Error creating line: ", GetLastError());
         return;
      }

      // Set line properties
      ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true); // Extend to the right
   }

   // Always update description for hover text
   ObjectSetString(0, name, OBJPROP_TOOLTIP, description);
}

//+------------------------------------------------------------------+
//| Delete all lines created by this EA                              |
//+------------------------------------------------------------------+
void DeleteAllLines() {
   DeleteAllFVGLines();
   ObjectsDeleteAll(0, "NYMidnight_");
   ObjectsDeleteAll(0, "DailyOpen_");
   ObjectsDeleteAll(0, "TimeMarker_");
}