//+------------------------------------------------------------------+
//|                                     SessionOpenRangeFVGStrategy.mq5 |
//|                                  Copyright 2023, Your Company Name. |
//|                                             https://www.example.com |
// added fixed pips sl
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Your Company Name."
#property link      "https://www.example.com"
#property version   "1.00"
#property strict

// Include helper modules
#include <Helpers/GetRange.mqh>
#include <Helpers/GetSwingHighLows.mqh>
#include <Helpers/GetFVGs.mqh>
#include <Helpers/RiskManagement.mqh>
#include <Helpers/OrderManagement.mqh>
#include <Helpers/GetIndicators.mqh>
#include <Helpers/TextDisplay.mqh>

// Enumerations
enum TRADE_STATE {
   STATE_NO_TRADE,      // No trade conditions met
   STATE_WAIT_BUY,      // Waiting for a bearish candle to buy
   STATE_WAIT_SELL,     // Waiting for a bullish candle to sell
   STATE_IN_TRADE,      // Already in a trade
   STATE_MAX_TRADES,    // Maximum trades reached
   STATE_MAX_LOSS       // Maximum loss reached
};

//+------------------------------------------------------------------+
//| Strategy state structure                                          |
//+------------------------------------------------------------------+
class StrategyState {
public:
   // Market structure
   TimeRange       openingRange;     // 16:30 to 17:00 range
   FVG             firstBullFVG;     // First bullish FVG
   FVG             firstBearFVG;     // First bearish FVG
   FVG             firstFVG;         // First FVG (either bullish or bearish)
   bool            isFirstFVGBullish; // Whether the first FVG is bullish (true) or bearish (false)

   // Previous day FVG storage
   FVG             prevDayFirstFVG;  // Previous day's first FVG
   bool            prevDayFVGExists; // Whether previous day's FVG exists
   bool            isPrevDayFVGBullish; // Whether previous day's first FVG is bullish

   SwingPoint      swingHighs[];     // Swing highs past 17:00
   SwingPoint      swingLows[];      // Swing lows past 17:00

   // Swing point tracking for position management
   SwingPoint      swingHighsSinceEntry[]; // Swing highs since position entry
   SwingPoint      swingLowsSinceEntry[];  // Swing lows since position entry
   datetime        entryTime;              // Time of position entry

   // Strategy state
   TRADE_STATE     currentState;     // Current trading state
   bool            fvgFound;         // Whether the FVG has been found
   datetime        sessionStartTime; // Start of trading session (17:00)
   datetime        sessionEndTime;   // End of trading session (19:00)
   datetime        lastCheck;        // Time of last check
   int             dayOfYear;        // Current day of year for daily resets

   // Risk management
   int             tradesOpenedToday; // Number of trades opened today
   datetime        tradeTimeLog[];    // Log of trade times
   double          dayProfit;         // Cumulative profit/loss for the day
   double          maxLossAmount;     // Maximum loss amount per day
   double          dayStartBalance;   // Account balance at start of day

   // Constructor
   StrategyState() {
      currentState = STATE_NO_TRADE;
      fvgFound = false;
      lastCheck = 0;
      tradesOpenedToday = 0;
      dayProfit = 0.0;
      maxLossAmount = 0.0;
      dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      isFirstFVGBullish = true; // Default
      prevDayFVGExists = false; // Default
      dayOfYear = 0;
      entryTime = 0;
   }
};

// Global variables
StrategyState State;

// Input parameters
// Time settings
input string TimeSettings = "===== Time Settings ====="; // Time Settings
input string OpenRangeStartTime = "16:30";             // Opening Range Start
input string OpenRangeEndTime = "17:00";               // Opening Range End
input string SessionStartTime = "17:00";               // Trading Session Start
input string SessionEndTime = "19:00";                 // Trading Session End

// Trade settings
input string TradeSettings = "===== Trade Settings ====="; // Trade Settings
input double RiskPerTrade = 77.0;                     // Risk Per Trade (in dollars)
input double RewardRiskRatio = 3.0;                    // Reward:Risk Ratio
input int    MaxTradesPerDay = 3;                      // Maximum Trades Per Day
input int    MaxTradesPerHour = 2;                     // Maximum Trades Per Hour
input double MaxLossPerDay = 3.0;                      // Max Loss Per Day (multiple of Risk)
input int    FixedStopLossPips = 150;                  // Fixed Stop Loss in pips

// FVG settings
input string FVGSettings = "===== FVG Settings ====="; // FVG Settings
input bool   IncludeFirstCandleFVG = false;            // Include FVGs on first candle of range
input int    MinFVGSearchBars = 200;                   // Minimum bars to search for FVGs

// Indicators
input string IndicatorSettings = "===== Indicator Settings ====="; // Indicator Settings
input int MADuration = 20;                            // Moving Average Period (5 min timeframe)

// Visualization
input string VisualSettings = "===== Visual Settings ====="; // Visualization Settings
input bool   ShowFVGs = true;                         // Show FVGs on chart
input bool   ShowSwingPoints = true;                  // Show Swing Points on chart
input bool   ShowOpeningRange = true;                 // Show Opening Range
input color  BullFVGColor = clrGreenYellow;           // Bullish FVG color
input color  BearFVGColor = clrDeepPink;              // Bearish FVG color
input color  SwingHighColor = clrDodgerBlue;          // Swing High color
input color  SwingLowColor = clrCrimson;              // Swing Low color
input color  OpenRangeColor = clrGoldenrod;           // Opening Range color

// Additional input parameters for trade management
input string TradeManagementSettings = "===== Trade Management Settings ====="; // Trade Management
input double BE_RRR_Level = 1.5;           // Move to Breakeven at R multiple
input double PARTIAL_PROFIT_PERCENT = 0.4; // Take partial profit percentage at BE level
input double PARTIAL_LOSS_RRR = 0.8;       // Take partial loss at R multiple
input double PARTIAL_LOSS_PERCENT = 0.5;   // Partial loss percentage
input int    MAX_SWING_POINTS = 3;         // Close trade after this many swing points taken

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   // Clear chart objects
   ObjectsDeleteAll(ChartID(), "");

   // Calculate maximum loss amount
   State.maxLossAmount = -(RiskPerTrade * MaxLossPerDay);

   // Standard 1-second timer for all modes
   EventSetTimer(1);

   // Set up session times
   SetupSessionTimes();

   // Initialize text display
   clearTextDisplay();

   // Initialize day of year
   MqlDateTime dt;
   datetime now = TimeCurrent();
   TimeToStruct(now, dt);
   State.dayOfYear = dt.day_of_year;

   // Reset trading state
   State.tradesOpenedToday = 0;
   State.currentState = STATE_NO_TRADE;
   State.fvgFound = false;
   State.dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   Print("EA initialized on day ", State.dayOfYear,
         ". Max loss amount: ", State.maxLossAmount,
         ", Trades opened today: ", State.tradesOpenedToday);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   // Clean up resources
   ObjectsDeleteAll(ChartID(), "");
   EventKillTimer();
}

//+------------------------------------------------------------------+
//| Timer event function                                             |
//+------------------------------------------------------------------+
void OnTimer() {
   // Check for day reset first (this still needs to happen regardless of trading hours)
   CheckDayReset();

   // Quick check if within trading hours - exit immediately if not
   if (!IsWithinTradingHours()) {
      // Do absolutely nothing if not in trading hours
      return;
   }

   // Exit early if we're at our daily limits
   if (State.currentState == STATE_MAX_TRADES || State.currentState == STATE_MAX_LOSS) {
      // Only update display if needed - for visual feedback
      clearTextDisplay();
      UpdateDailyPerformance();
      DisplayStatus();
      return;
   }

   // Continue with regular processing - we're in trading hours and below limits

   // Clear display
   clearTextDisplay();

   // Update daily performance
   UpdateDailyPerformance();

   // Update market structure
   UpdateMarketStructure();

   // Manage existing trades
   ManageExistingTrades();

   // Process trading logic
   ProcessTradingLogic();

   // Display current status
   DisplayStatus();
}

//+------------------------------------------------------------------+
//| Set up session time variables                                    |
//+------------------------------------------------------------------+
void SetupSessionTimes() {
   // Today's date at midnight
   datetime today = TimeCurrent();
   today = today - (today % 86400); // Round down to midnight (00:00:00)

   // Simple string to hour/minute conversion
   int orStartHour = (int)StringToInteger(StringSubstr(OpenRangeStartTime, 0, 2));
   int orStartMin = (int)StringToInteger(StringSubstr(OpenRangeStartTime, 3, 2));

   int orEndHour = (int)StringToInteger(StringSubstr(OpenRangeEndTime, 0, 2));
   int orEndMin = (int)StringToInteger(StringSubstr(OpenRangeEndTime, 3, 2));

   int sessionStartHour = (int)StringToInteger(StringSubstr(SessionStartTime, 0, 2));
   int sessionStartMin = (int)StringToInteger(StringSubstr(SessionStartTime, 3, 2));

   int sessionEndHour = (int)StringToInteger(StringSubstr(SessionEndTime, 0, 2));
   int sessionEndMin = (int)StringToInteger(StringSubstr(SessionEndTime, 3, 2));

   // Convert to seconds and add to today's midnight
   State.sessionStartTime = today + (sessionStartHour * 3600) + (sessionStartMin * 60);
   State.sessionEndTime = today + (sessionEndHour * 3600) + (sessionEndMin * 60);
}

//+------------------------------------------------------------------+
//| Check if current time is within trading hours                    |
//+------------------------------------------------------------------+
bool IsWithinTradingHours() {
   datetime now = TimeCurrent();
   MqlDateTime dtNow;
   TimeToStruct(now, dtNow);

   // Get today's session times
   datetime today = now - (now % 86400);  // Today at midnight
   datetime todayStart = today + (State.sessionStartTime % 86400);  // Get just the time portion
   datetime todayEnd = today + (State.sessionEndTime % 86400);  // Get just the time portion

   // Basic check if within the overall session time window
   bool withinSessionWindow = (now >= todayStart && now <= todayEnd);

   // Optimize for the most profitable hour (based on backtest data)
   bool inOptimalHour = (dtNow.hour == 17);

   // For opening new positions, be stricter with timing
   if (!HasActivePositionsOrOrders()) {
      // Only open new positions during the optimal hour
      return withinSessionWindow && inOptimalHour;
   }

   // For managing existing positions, use the regular session window
   return withinSessionWindow;
}

//+------------------------------------------------------------------+
//| Update market structure: OR, FVGs, and Swing points               |
//+------------------------------------------------------------------+
void UpdateMarketStructure() {
   // Update opening range (if not already updated)
   if (!State.openingRange.valid) {
      UpdateOpeningRange();
   }

   // If we have an active position, we need swing points for management
   bool needSwingPoints = HasActivePositionsOrOrders();

   // If we're at daily limits and already have FVGs, we can skip most updates
   if ((State.currentState == STATE_MAX_TRADES || State.currentState == STATE_MAX_LOSS) &&
       State.fvgFound && State.openingRange.valid && !needSwingPoints) {
      return;
   }

   // Update swing points since trading session start
   UpdateSwingPoints();

   // Update FVGs (if not already found)
   if (!State.fvgFound) {
      UpdateFVGs();
   }
}

//+------------------------------------------------------------------+
//| Update the opening range (16:30 to 17:00)                        |
//+------------------------------------------------------------------+
void UpdateOpeningRange() {
   TimeRange range = CalculateRangeForDay(OpenRangeStartTime, OpenRangeEndTime, 0, "OR", ShowOpeningRange, PERIOD_CURRENT);
   State.openingRange = range;

   if (ShowOpeningRange && range.valid) {
      DrawRangeLevels(range, "OR", true, PERIOD_CURRENT, OpenRangeColor, OpenRangeColor, OpenRangeColor);
   }
}

//+------------------------------------------------------------------+
//| Update swing points since trading session start                   |
//+------------------------------------------------------------------+
void UpdateSwingPoints() {
   // Calculate how many bars are between current time and session start
   int barsSinceSessionStart = 0;
   datetime now = TimeCurrent();

   MqlDateTime nowStruct;
   TimeToStruct(now, nowStruct);

   MqlDateTime todaySessionStartStruct;
   TimeToStruct(State.sessionStartTime, todaySessionStartStruct);
   todaySessionStartStruct.year = nowStruct.year;
   todaySessionStartStruct.mon = nowStruct.mon;
   todaySessionStartStruct.day = nowStruct.day;

   datetime todaySessionStart = StructToTime(todaySessionStartStruct);

   for (int i = 0; i < 500; i++) {
      datetime barTime = iTime(_Symbol, PERIOD_M1, i);
      if (barTime <= todaySessionStart) {
         barsSinceSessionStart = i;
         break;
      }
   }

   // Get swing points on M1 timeframe
   GetSwingHighs(10, State.swingHighs, PERIOD_M1, barsSinceSessionStart, ShowSwingPoints, SwingHighColor);
   GetSwingLows(10, State.swingLows, PERIOD_M1, barsSinceSessionStart, ShowSwingPoints, SwingLowColor);
}

//+------------------------------------------------------------------+
//| Update FVGs - find the first FVG after opening range                |
//+------------------------------------------------------------------+
void UpdateFVGs() {
   // Only update if we haven't found a valid FVG yet
   if (State.fvgFound)
      return;

   // Add debug info about FVG search
   addTextOnScreen("Searching for FVGs...", clrYellow);

   // Calculate the timestamp for FVG search start time
   datetime now = TimeCurrent();
   datetime today = now - (now % 86400);  // Today at midnight

   // Parse OpenRangeStartTime to get hours and minutes
   int orStartHour = (int)StringToInteger(StringSubstr(OpenRangeStartTime, 0, 2));
   int orStartMin = (int)StringToInteger(StringSubstr(OpenRangeStartTime, 3, 2));

   // FVG search will start at the opening range start
   int seconds = (orStartHour * 3600) + (orStartMin * 60);
   datetime fvgSearchTime = today + seconds;

   // If we don't want to include FVGs on the first candle, move the search time forward by 1 minute
   if (!IncludeFirstCandleFVG) {
      fvgSearchTime += 60; // Add 1 minute
      addTextOnScreen("Excluding first candle FVGs, start time: " + TimeToString(fvgSearchTime), clrYellow);
   } else {
      addTextOnScreen("Including first candle FVGs, start time: " + TimeToString(fvgSearchTime), clrYellow);
   }

   // Find bar index of FVG search time
   int barsSinceStart = 0;
   for (int i = 0; i < 500; i++) {
      datetime barTime = iTime(_Symbol, PERIOD_M1, i);
      if (barTime <= fvgSearchTime) {
         barsSinceStart = i;
         break;
      }
   }

   // Get FVGs
   FVG bullishFVGs[];
   FVG bearishFVGs[];

   GetBullishFVGs(0, barsSinceStart, bullishFVGs, MinFVGSearchBars, ShowFVGs, BullFVGColor, PERIOD_M1);
   GetBearishFVGs(0, barsSinceStart, bearishFVGs, MinFVGSearchBars, ShowFVGs, BearFVGColor, PERIOD_M1);

   // Debug information
   int bullSize = ArraySize(bullishFVGs);
   int bearSize = ArraySize(bearishFVGs);

   addTextOnScreen("Total Bullish FVGs found: " + IntegerToString(bullSize), clrWhite);
   addTextOnScreen("Total Bearish FVGs found: " + IntegerToString(bearSize), clrWhite);

   // Initialize with empty FVGs
   State.firstBullFVG.exists = false;
   State.firstBearFVG.exists = false;
   State.firstFVG.exists = false;

   // Format the time string for display
   string searchTimeStr = IncludeFirstCandleFVG ? OpenRangeStartTime : TimeToString(fvgSearchTime, TIME_MINUTES);

   // Debug the first few FVGs
   for (int i = 0; i < bullSize && i < 3; i++) {
      datetime fvgTime = bullishFVGs[i].time;
      addTextOnScreen("Bullish FVG " + IntegerToString(i) +
                     " Time: " + TimeToString(fvgTime) +
                     " After " + searchTimeStr + ": " + (fvgTime >= fvgSearchTime ? "Yes" : "No"),
                     clrLime);
   }

   for (int i = 0; i < bearSize && i < 3; i++) {
      datetime fvgTime = bearishFVGs[i].time;
      addTextOnScreen("Bearish FVG " + IntegerToString(i) +
                     " Time: " + TimeToString(fvgTime) +
                     " After " + searchTimeStr + ": " + (fvgTime >= fvgSearchTime ? "Yes" : "No"),
                     clrRed);
   }

   // Find the first (chronologically) bullish FVG after the search time
   // Search from the end of the array (oldest) to start (newest)
   datetime firstBullFVGTime = 0;
   for (int i = bullSize - 1; i >= 0; i--) {
      if (bullishFVGs[i].time >= fvgSearchTime) {
         State.firstBullFVG = bullishFVGs[i];
         firstBullFVGTime = State.firstBullFVG.time;
         addTextOnScreen("First Bull FVG after " + searchTimeStr + " - Index: " + IntegerToString(i) +
                        " Time: " + TimeToString(State.firstBullFVG.time), clrLime);
         break;
      }
   }

   // Find the first (chronologically) bearish FVG after the search time
   // Search from the end of the array (oldest) to start (newest)
   datetime firstBearFVGTime = 0;
   for (int i = bearSize - 1; i >= 0; i--) {
      if (bearishFVGs[i].time >= fvgSearchTime) {
         State.firstBearFVG = bearishFVGs[i];
         firstBearFVGTime = State.firstBearFVG.time;
         addTextOnScreen("First Bear FVG after " + searchTimeStr + " - Index: " + IntegerToString(i) +
                        " Time: " + TimeToString(State.firstBearFVG.time), clrRed);
         break;
      }
   }

   // Determine which FVG came first chronologically
   if (State.firstBullFVG.exists && State.firstBearFVG.exists) {
      // Both exist, compare times
      if (firstBullFVGTime <= firstBearFVGTime) {
         State.firstFVG = State.firstBullFVG;
         State.isFirstFVGBullish = true;
         addTextOnScreen("First FVG is BULLISH at " + TimeToString(State.firstFVG.time), clrYellow);
      } else {
         State.firstFVG = State.firstBearFVG;
         State.isFirstFVGBullish = false;
         addTextOnScreen("First FVG is BEARISH at " + TimeToString(State.firstFVG.time), clrYellow);
      }
   } else if (State.firstBullFVG.exists) {
      // Only bullish exists
      State.firstFVG = State.firstBullFVG;
      State.isFirstFVGBullish = true;
      addTextOnScreen("First FVG is BULLISH at " + TimeToString(State.firstFVG.time), clrYellow);
   } else if (State.firstBearFVG.exists) {
      // Only bearish exists
      State.firstFVG = State.firstBearFVG;
      State.isFirstFVGBullish = false;
      addTextOnScreen("First FVG is BEARISH at " + TimeToString(State.firstFVG.time), clrYellow);
   }

   // Mark as found if we have at least one FVG
   if (State.firstBullFVG.exists || State.firstBearFVG.exists) {
      State.fvgFound = true;
      addTextOnScreen("FVGs found and stored", clrYellow);
      Print("FVGs found and stored for day ", State.dayOfYear);
   } else {
      addTextOnScreen("No valid FVGs found after " + searchTimeStr, clrYellow);
   }
}

//+------------------------------------------------------------------+
//| Check and handle day reset                                       |
//+------------------------------------------------------------------+
void CheckDayReset() {
   // Get current date/time
   MqlDateTime dt;
   datetime now = TimeCurrent();
   TimeToStruct(now, dt);

   // Check if it's a new day
   if (State.dayOfYear == 0 || State.dayOfYear != dt.day_of_year) {
      // It's a new day - reset everything
      Print("New day detected! Previous: ", State.dayOfYear, ", Current: ", dt.day_of_year);

      // Store current day's FVG as previous day's FVG before resetting
      if (State.firstFVG.exists) {
         State.prevDayFirstFVG = State.firstFVG;
         State.prevDayFVGExists = true;
         State.isPrevDayFVGBullish = State.isFirstFVGBullish;

         // Draw horizontal lines for previous day's FVG
         DrawPreviousDayFVGLevels();

         Print("Stored previous day's FVG - High: ", State.prevDayFirstFVG.high,
               ", Low: ", State.prevDayFirstFVG.low,
               ", Type: ", (State.isPrevDayFVGBullish ? "Bullish" : "Bearish"));
      }

      // Reset counters
      State.tradesOpenedToday = 0;
      State.dayProfit = 0.0;
      ArrayFree(State.tradeTimeLog);

      // Update balance
      State.dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);

      // Reset FVG finding state
      State.fvgFound = false;
      State.firstBullFVG.exists = false;
      State.firstBearFVG.exists = false;
      State.firstFVG.exists = false;

      // Reset trade state if needed
      if (State.currentState == STATE_MAX_TRADES || State.currentState == STATE_MAX_LOSS) {
         State.currentState = STATE_NO_TRADE;
         Print("Daily limit state reset from: ", (State.currentState == STATE_MAX_TRADES ? "MAX_TRADES" : "MAX_LOSS"), " to NO_TRADE");
      }

      // Store the new day
      State.dayOfYear = dt.day_of_year;

      Print("Daily reset complete for day ", dt.day_of_year,
            ". Starting balance: ", State.dayStartBalance,
            ", FVG reset: ", !State.fvgFound);
   }
}

//+------------------------------------------------------------------+
//| Draw horizontal lines for previous day's FVG levels              |
//+------------------------------------------------------------------+
void DrawPreviousDayFVGLevels() {
   if (!State.prevDayFVGExists) return;

   // Create unique object names
   string highLineObjName = "PrevDayFVG_High_Line";
   string lowLineObjName = "PrevDayFVG_Low_Line";

   // Delete existing lines if present
   ObjectDelete(ChartID(), highLineObjName);
   ObjectDelete(ChartID(), lowLineObjName);

   // Set colors based on FVG type
   color highColor = State.isPrevDayFVGBullish ? BullFVGColor : BearFVGColor;
   color lowColor = State.isPrevDayFVGBullish ? BullFVGColor : BearFVGColor;

   // Get current time for line end
   datetime currentTime = TimeCurrent();
   // Set line start to previous day's FVG time
   datetime lineStartTime = State.prevDayFirstFVG.time;

   // Create high level line
   ObjectCreate(ChartID(), highLineObjName, OBJ_TREND, 0, lineStartTime, State.prevDayFirstFVG.high, currentTime, State.prevDayFirstFVG.high);
   ObjectSetInteger(ChartID(), highLineObjName, OBJPROP_COLOR, highColor);
   ObjectSetInteger(ChartID(), highLineObjName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(ChartID(), highLineObjName, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(ChartID(), highLineObjName, OBJPROP_RAY_RIGHT, true);
   ObjectSetString(ChartID(), highLineObjName, OBJPROP_TEXT, "Prev Day FVG High");

   // Create low level line
   ObjectCreate(ChartID(), lowLineObjName, OBJ_TREND, 0, lineStartTime, State.prevDayFirstFVG.low, currentTime, State.prevDayFirstFVG.low);
   ObjectSetInteger(ChartID(), lowLineObjName, OBJPROP_COLOR, lowColor);
   ObjectSetInteger(ChartID(), lowLineObjName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(ChartID(), lowLineObjName, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(ChartID(), lowLineObjName, OBJPROP_RAY_RIGHT, true);
   ObjectSetString(ChartID(), lowLineObjName, OBJPROP_TEXT, "Prev Day FVG Low");
}

//+------------------------------------------------------------------+
//| Update daily performance by comparing with starting balance       |
//+------------------------------------------------------------------+
void UpdateDailyPerformance() {
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   State.dayProfit = currentBalance - State.dayStartBalance;
}

//+------------------------------------------------------------------+
//| Check if we can open more trades based on limits                 |
//+------------------------------------------------------------------+
bool CanOpenMoreTrades() {
   // Debug info - add trade count to journal if at limit
   if(State.tradesOpenedToday >= MaxTradesPerDay) {
      Print("Max daily trades reached. Current count: ", State.tradesOpenedToday, "/", MaxTradesPerDay);
      State.currentState = STATE_MAX_TRADES;
      return false;
   }

   // Check maximum loss per day
   if(State.dayProfit <= State.maxLossAmount) {
      Print("Max daily loss reached. Current P/L: ", DoubleToString(State.dayProfit, 2), ", Limit: ", DoubleToString(State.maxLossAmount, 2));
      State.currentState = STATE_MAX_LOSS;
      return false;
   }

   // Check maximum trades per hour
   datetime now = TimeCurrent();
   int tradesInLastHour = 0;

   for(int i = 0; i < ArraySize(State.tradeTimeLog); i++) {
      if(now - State.tradeTimeLog[i] < 3600) { // 3600 seconds = 1 hour
         tradesInLastHour++;
      }
   }

   if(tradesInLastHour >= MaxTradesPerHour) {
      // We don't change the state for hourly limits, just return false
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Process trading logic based on strategy rules                     |
//+------------------------------------------------------------------+
void ProcessTradingLogic() {
   // If already in a trade, return immediately
   if (HasActivePositionsOrOrders()) {
      State.currentState = STATE_IN_TRADE;
      return;
   }

   // Reset state if not in a trade
   if (State.currentState == STATE_IN_TRADE) {
      State.currentState = STATE_NO_TRADE;
   }

   // Check if we've reached our trading limits - return immediately if so
   if(!CanOpenMoreTrades()) {
      return; // State is already set by CanOpenMoreTrades
   }

   // Check day of week filter - avoid Sundays and Saturdays
   if (!CheckDayOfWeekFilter()) {
      return;
   }

   // Check volatility filter - avoid extremely volatile or quiet markets
   if (!CheckVolatilityFilter()) {
      return;
   }

   // Check for buy signal conditions
   if (State.currentState == STATE_NO_TRADE || State.currentState == STATE_WAIT_BUY) {
      if (CheckBuyConditions()) {
         State.currentState = STATE_WAIT_BUY;

         // Check if previous candle is bearish
         if (IsBearishCandle()) {
            ExecuteBuyTrade();
            State.currentState = STATE_IN_TRADE;

            // Update trade counters
            State.tradesOpenedToday++;
            ArrayResize(State.tradeTimeLog, ArraySize(State.tradeTimeLog) + 1);
            State.tradeTimeLog[ArraySize(State.tradeTimeLog) - 1] = TimeCurrent();
         }
      } else {
         State.currentState = STATE_NO_TRADE;
      }
   }

   // Check for sell signal conditions
   if (State.currentState == STATE_NO_TRADE || State.currentState == STATE_WAIT_SELL) {
      if (CheckSellConditions()) {
         State.currentState = STATE_WAIT_SELL;

         // Check if previous candle is bullish
         if (IsBullishCandle()) {
            ExecuteSellTrade();
            State.currentState = STATE_IN_TRADE;

            // Update trade counters
            State.tradesOpenedToday++;
            ArrayResize(State.tradeTimeLog, ArraySize(State.tradeTimeLog) + 1);
            State.tradeTimeLog[ArraySize(State.tradeTimeLog) - 1] = TimeCurrent();
         }
      } else {
         State.currentState = STATE_NO_TRADE;
      }
   }
}

//+------------------------------------------------------------------+
//| Check if current day of week is suitable for trading             |
//+------------------------------------------------------------------+
bool CheckDayOfWeekFilter() {
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);

   // Avoid Sunday (0) and Saturday (6)
   if (dt.day_of_week == 0 || dt.day_of_week == 6) {
      return false;
   }

   // Based on backtest, focus more on Tuesday-Friday (best performance)
   // Monday has mixed results
   if (dt.day_of_week == 1) { // Monday
      // Additional filter for Mondays if needed
      // For example, we could check for specific market conditions
   }

   return true;
}

//+------------------------------------------------------------------+
//| Check if current market volatility is suitable for trading       |
//+------------------------------------------------------------------+
bool CheckVolatilityFilter() {
   // Create ATR indicator handle
   int atrHandle = iATR(_Symbol, PERIOD_M15, 14);

   if (atrHandle == INVALID_HANDLE) {
      Print("Error creating ATR handle: ", GetLastError());
      return true; // Allow trading if we can't calculate ATR
   }

   // Arrays to store ATR values
   double atrValues[];
   ArraySetAsSeries(atrValues, true);

   // Get the last 5 ATR values
   if (CopyBuffer(atrHandle, 0, 0, 5, atrValues) <= 0) {
      Print("Error copying ATR values: ", GetLastError());
      IndicatorRelease(atrHandle);
      return true; // Allow trading if we can't get ATR values
   }

   // Release the indicator handle
   IndicatorRelease(atrHandle);

   // Calculate average of last 5 ATR values
   double atrAverage = 0;
   for (int i = 0; i < 5; i++) {
      atrAverage += atrValues[i];
   }
   atrAverage /= 5;

   // Current ATR is the first value in the array
   double currentAtr = atrValues[0];

   // Range of acceptable volatility (0.8 to 1.5 times the average)
   double minVolatility = atrAverage * 0.8;
   double maxVolatility = atrAverage * 1.5;

   // Current volatility should be within acceptable range
   if (currentAtr < minVolatility) {
      // Too low volatility, not enough movement for our strategy
      return false;
   }

   if (currentAtr > maxVolatility) {
      // Too high volatility, might be risky or erratic
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Check if all buy conditions are met                               |
//+------------------------------------------------------------------+
bool CheckBuyConditions() {
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // 1. Price is above middle of 16:30 to 17:00 range
   bool aboveMiddle = currentPrice > State.openingRange.middle;

   // 2. Price above Moving Average 20 of five minutes
   bool aboveMA = CheckIsAboveSMA(currentPrice, MADuration, PERIOD_M5);

   // 3. Previous swing high that is past 17:00 has been taken
   bool swingHighTaken = CheckSwingHighTaken();

   // 4. Price is above the high of the first presented fair value gap
   bool aboveFVGHigh = false;

   // Check based on the first FVG
   if (State.firstFVG.exists) {
      // Price should be above the high of the FVG for a buy
      aboveFVGHigh = currentPrice > State.firstFVG.high;
   }

   // 5. Price is above the previous day's first FVG high past 9:30
   bool abovePrevDayFVGHigh = true; // Default to true if no previous day FVG
   if (State.prevDayFVGExists) {
      abovePrevDayFVGHigh = currentPrice > State.prevDayFirstFVG.high;
   }

   // 6. Stronger trend confirmation - price above MA50 on higher timeframe
   bool strongTrend = CheckIsAboveSMA(currentPrice, 50, PERIOD_M15);

   return aboveMiddle && aboveMA && swingHighTaken && aboveFVGHigh && abovePrevDayFVGHigh && strongTrend;
}

//+------------------------------------------------------------------+
//| Check if all sell conditions are met                              |
//+------------------------------------------------------------------+
bool CheckSellConditions() {
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // 1. Price is below middle of 16:30 to 17:00 range
   bool belowMiddle = currentPrice < State.openingRange.middle;

   // 2. Price below Moving Average 20 of five minutes
   bool belowMA = !CheckIsAboveSMA(currentPrice, MADuration, PERIOD_M5);

   // 3. Previous swing low that is past 17:00 has been taken
   bool swingLowTaken = CheckSwingLowTaken();

   // 4. Price is below the low of the first presented fair value gap
   bool belowFVGLow = false;

   // Check based on the first FVG
   if (State.firstFVG.exists) {
      // Price should be below the low of the FVG for a sell
      belowFVGLow = currentPrice < State.firstFVG.low;
   }

   // 5. Price is below the previous day's first FVG low past 9:30
   bool belowPrevDayFVGLow = true; // Default to true if no previous day FVG
   if (State.prevDayFVGExists) {
      belowPrevDayFVGLow = currentPrice < State.prevDayFirstFVG.low;
   }

   // 6. Stronger trend confirmation - price below MA50 on higher timeframe
   bool strongTrend = !CheckIsAboveSMA(currentPrice, 50, PERIOD_M15);

   return belowMiddle && belowMA && swingLowTaken && belowFVGLow && belowPrevDayFVGLow && strongTrend;
}

//+------------------------------------------------------------------+
//| Check if a swing low has been taken                              |
//+------------------------------------------------------------------+
bool CheckSwingLowTaken() {
   if (ArraySize(State.swingLows) == 0)
      return false;

   // Check if the most recent swing low has been taken
   bool taken = State.swingLows[0].taken;
   addTextOnScreen("Most recent swing low taken: " + (taken ? "Yes" : "No"), clrCrimson);
   return taken;
}

//+------------------------------------------------------------------+
//| Check if a swing high has been taken                             |
//+------------------------------------------------------------------+
bool CheckSwingHighTaken() {
   if (ArraySize(State.swingHighs) == 0)
      return false;

   // Check if the most recent swing high has been taken
   bool taken = State.swingHighs[0].taken;
   addTextOnScreen("Most recent swing high taken: " + (taken ? "Yes" : "No"), clrDodgerBlue);
   return taken;
}

//+------------------------------------------------------------------+
//| Check if previous candle is bearish                               |
//+------------------------------------------------------------------+
bool IsBearishCandle() {
   double open = iOpen(_Symbol, PERIOD_M1, 1);
   double close = iClose(_Symbol, PERIOD_M1, 1);

   return close < open;
}

//+------------------------------------------------------------------+
//| Check if previous candle is bullish                              |
//+------------------------------------------------------------------+
bool IsBullishCandle() {
   double open = iOpen(_Symbol, PERIOD_M1, 1);
   double close = iClose(_Symbol, PERIOD_M1, 1);

   return close > open;
}

//+------------------------------------------------------------------+
//| Execute buy trade                                                |
//+------------------------------------------------------------------+
void ExecuteBuyTrade() {
   double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Use fixed stop loss in pips
   double stopLoss = entryPrice - (FixedStopLossPips * _Point);

   // Calculate take profit using the Reward:Risk Ratio
   double takeProfit = CalculateTpPrice(entryPrice, stopLoss, RewardRiskRatio);

   // Use direct risk amount in dollars
   double riskDollars = RiskPerTrade;
   double lotSize = CalculateLotSize(riskDollars, entryPrice, stopLoss);

   // Execute the order using the global trade object from OrderManagement.mqh
   trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, lotSize, entryPrice, stopLoss, takeProfit, "OR FVG Strategy");

   // Record entry time for swing point tracking
   State.entryTime = TimeCurrent();

   // Clear swing point arrays for this new position
   ArrayFree(State.swingHighsSinceEntry);
   ArrayFree(State.swingLowsSinceEntry);

   Print("Buy trade executed. Entry time recorded: ", TimeToString(State.entryTime));
}

//+------------------------------------------------------------------+
//| Execute sell trade                                               |
//+------------------------------------------------------------------+
void ExecuteSellTrade() {
   double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Use fixed stop loss in pips
   double stopLoss = entryPrice + (FixedStopLossPips * _Point);

   // Calculate take profit using the Reward:Risk Ratio
   double takeProfit = CalculateTpPrice(entryPrice, stopLoss, RewardRiskRatio);

   // Use direct risk amount in dollars
   double riskDollars = RiskPerTrade;
   double lotSize = CalculateLotSize(riskDollars, entryPrice, stopLoss);

   // Execute the order using the global trade object from OrderManagement.mqh
   trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, lotSize, entryPrice, stopLoss, takeProfit, "OR FVG Strategy");

   // Record entry time for swing point tracking
   State.entryTime = TimeCurrent();

   // Clear swing point arrays for this new position
   ArrayFree(State.swingHighsSinceEntry);
   ArrayFree(State.swingLowsSinceEntry);

   Print("Sell trade executed. Entry time recorded: ", TimeToString(State.entryTime));
}

//+------------------------------------------------------------------+
//| Get the most recent swing high price                             |
//+------------------------------------------------------------------+
double GetMostRecentSwingHigh() {
   if (ArraySize(State.swingHighs) == 0)
      return 0;

   // The most recent swing high is at index 0
   double mostRecentPrice = State.swingHighs[0].price;

   // Debug information
   addTextOnScreen("Most recent swing high: " + DoubleToString(mostRecentPrice, _Digits) +
                  " (bar " + IntegerToString(State.swingHighs[0].bar) + ")", clrDodgerBlue);

   return mostRecentPrice;
}

//+------------------------------------------------------------------+
//| Get the most recent swing low price                              |
//+------------------------------------------------------------------+
double GetMostRecentSwingLow() {
   if (ArraySize(State.swingLows) == 0)
      return 0;

   // The most recent swing low is at index 0
   double mostRecentPrice = State.swingLows[0].price;

   // Debug information
   addTextOnScreen("Most recent swing low: " + DoubleToString(mostRecentPrice, _Digits) +
                  " (bar " + IntegerToString(State.swingLows[0].bar) + ")", clrCrimson);

   return mostRecentPrice;
}

//+------------------------------------------------------------------+
//| Display current status on chart                                  |
//+------------------------------------------------------------------+
void DisplayStatus() {
   // Display opening range info
   string orStatus = "Opening Range: ";
   if (State.openingRange.valid) {
      orStatus += "High: " + DoubleToString(State.openingRange.high, _Digits) +
                  ", Low: " + DoubleToString(State.openingRange.low, _Digits) +
                  ", Middle: " + DoubleToString(State.openingRange.middle, _Digits);
   } else {
      orStatus += "Not available";
   }
   addTextOnScreen(orStatus, clrWhite);

   // Display FVG info
   string bullFVGStatus = "Bullish FVG: ";
   if (State.firstBullFVG.exists) {
      // Format time with a completely explicit approach
      MqlDateTime timeStruct;
      TimeToStruct(State.firstBullFVG.time, timeStruct);

      // Ensure minutes have 2 digits
      string minuteStr = IntegerToString(timeStruct.min);
      if(timeStruct.min < 10) minuteStr = "0" + minuteStr;

      // Format full time string
      string formattedTime = IntegerToString(timeStruct.year) + "." +
                            IntegerToString(timeStruct.mon) + "." +
                            IntegerToString(timeStruct.day) + " " +
                            IntegerToString(timeStruct.hour) + ":" +
                            minuteStr;

      bullFVGStatus += "High: " + DoubleToString(State.firstBullFVG.high, _Digits) +
                      ", Low: " + DoubleToString(State.firstBullFVG.low, _Digits) +
                      ", Time: " + formattedTime;
   } else {
      bullFVGStatus += "Not found";
   }
   addTextOnScreen(bullFVGStatus, clrLime);

   string bearFVGStatus = "Bearish FVG: ";
   if (State.firstBearFVG.exists) {
      // Format time with a completely explicit approach
      MqlDateTime timeStruct;
      TimeToStruct(State.firstBearFVG.time, timeStruct);

      // Ensure minutes have 2 digits
      string minuteStr = IntegerToString(timeStruct.min);
      if(timeStruct.min < 10) minuteStr = "0" + minuteStr;

      // Format full time string
      string formattedTime = IntegerToString(timeStruct.year) + "." +
                            IntegerToString(timeStruct.mon) + "." +
                            IntegerToString(timeStruct.day) + " " +
                            IntegerToString(timeStruct.hour) + ":" +
                            minuteStr;

      bearFVGStatus += "High: " + DoubleToString(State.firstBearFVG.high, _Digits) +
                      ", Low: " + DoubleToString(State.firstBearFVG.low, _Digits) +
                      ", Time: " + formattedTime;
   } else {
      bearFVGStatus += "Not found";
   }
   addTextOnScreen(bearFVGStatus, clrRed);

   // Display First FVG info (regardless of type)
   string firstFVGStatus = "First FVG: ";
   if (State.firstFVG.exists) {
      // Format time with a completely explicit approach
      MqlDateTime timeStruct;
      TimeToStruct(State.firstFVG.time, timeStruct);

      // Ensure minutes have 2 digits
      string minuteStr = IntegerToString(timeStruct.min);
      if(timeStruct.min < 10) minuteStr = "0" + minuteStr;

      // Format full time string
      string formattedTime = IntegerToString(timeStruct.year) + "." +
                            IntegerToString(timeStruct.mon) + "." +
                            IntegerToString(timeStruct.day) + " " +
                            IntegerToString(timeStruct.hour) + ":" +
                            minuteStr;

      string fvgType = State.isFirstFVGBullish ? "BULLISH" : "BEARISH";

      firstFVGStatus += "Type: " + fvgType +
                       ", High: " + DoubleToString(State.firstFVG.high, _Digits) +
                       ", Low: " + DoubleToString(State.firstFVG.low, _Digits) +
                       ", Time: " + formattedTime;
   } else {
      firstFVGStatus += "Not found";
   }
   addTextOnScreen(firstFVGStatus, clrYellow);

   // Display Previous Day FVG info
   string prevDayFVGStatus = "Prev Day FVG: ";
   if (State.prevDayFVGExists) {
      string fvgType = State.isPrevDayFVGBullish ? "BULLISH" : "BEARISH";

      prevDayFVGStatus += "Type: " + fvgType +
                         ", High: " + DoubleToString(State.prevDayFirstFVG.high, _Digits) +
                         ", Low: " + DoubleToString(State.prevDayFirstFVG.low, _Digits);
   } else {
      prevDayFVGStatus += "Not available";
   }
   addTextOnScreen(prevDayFVGStatus, clrOrange);

   // Display trading state
   string stateStr = "State: ";
   switch (State.currentState) {
      case STATE_NO_TRADE:  stateStr += "No Trade Signal"; break;
      case STATE_WAIT_BUY:  stateStr += "Waiting for Bearish Candle to BUY"; break;
      case STATE_WAIT_SELL: stateStr += "Waiting for Bullish Candle to SELL"; break;
      case STATE_IN_TRADE:  stateStr += "In Trade"; break;
      case STATE_MAX_TRADES: stateStr += "Maximum Trades Reached"; break;
      case STATE_MAX_LOSS:  stateStr += "Maximum Loss Reached"; break;
   }
   addTextOnScreen(stateStr, clrYellow);

   // Display risk management info
   addTextOnScreen("Risk Management:", clrOrange);
   addTextOnScreen("  Risk Per Trade: $" + DoubleToString(RiskPerTrade, 2), clrWhite);
   addTextOnScreen("  Trades Today: " + IntegerToString(State.tradesOpenedToday) +
                  "/" + IntegerToString(MaxTradesPerDay),
                  State.tradesOpenedToday >= MaxTradesPerDay ? clrRed : clrGreen);

   int tradesInLastHour = 0;
   datetime now = TimeCurrent();
   for(int i = 0; i < ArraySize(State.tradeTimeLog); i++) {
      if(now - State.tradeTimeLog[i] < 3600) {
         tradesInLastHour++;
      }
   }

   addTextOnScreen("  Trades Last Hour: " + IntegerToString(tradesInLastHour) +
                  "/" + IntegerToString(MaxTradesPerHour),
                  tradesInLastHour >= MaxTradesPerHour ? clrRed : clrGreen);

   addTextOnScreen("  Day P/L: " + DoubleToString(State.dayProfit, 2) +
                  " (Max Loss: " + DoubleToString(State.maxLossAmount, 2) + ")",
                  State.dayProfit < 0 ? (State.dayProfit <= State.maxLossAmount ? clrRed : clrOrange) : clrGreen);

   // Display conditions for buy setup with line breaks
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   bool aboveMiddle = currentPrice > State.openingRange.middle;
   bool aboveMA = CheckIsAboveSMA(currentPrice, MADuration, PERIOD_M5);
   bool swingHighTaken = CheckSwingHighTaken();
   bool aboveFVGHigh = false;

   // Check based on the first FVG
   if (State.firstFVG.exists) {
      // For buy conditions, price should be above the high
      aboveFVGHigh = currentPrice > State.firstFVG.high;
   }

   // Check against previous day's FVG high
   bool abovePrevDayFVGHigh = true; // Default to true if no previous day FVG
   if (State.prevDayFVGExists) {
      abovePrevDayFVGHigh = currentPrice > State.prevDayFirstFVG.high;
   }

   addTextOnScreen("BUY Conditions:", clrGreen);
   addTextOnScreen("  Above Middle: " + (aboveMiddle ? "Yes" : "No"), aboveMiddle ? clrGreen : clrRed);
   addTextOnScreen("  Above MA20: " + (aboveMA ? "Yes" : "No"), aboveMA ? clrGreen : clrRed);
   addTextOnScreen("  SwingHigh Taken: " + (swingHighTaken ? "Yes" : "No"), swingHighTaken ? clrGreen : clrRed);
   addTextOnScreen("  Above FVG High: " + (aboveFVGHigh ? "Yes" : "No"), aboveFVGHigh ? clrGreen : clrRed);
   addTextOnScreen("  Above Prev Day FVG High: " + (abovePrevDayFVGHigh ? "Yes" : "No"), abovePrevDayFVGHigh ? clrGreen : clrRed);

   // Display conditions for sell setup with line breaks
   double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bool belowMiddle = bidPrice < State.openingRange.middle;
   bool belowMA = !CheckIsAboveSMA(bidPrice, MADuration, PERIOD_M5);
   bool swingLowTaken = CheckSwingLowTaken();
   bool belowFVGLow = false;

   // Check based on the first FVG
   if (State.firstFVG.exists) {
      // For sell conditions, price should be below the low
      belowFVGLow = bidPrice < State.firstFVG.low;
   }

   // Check against previous day's FVG low
   bool belowPrevDayFVGLow = true; // Default to true if no previous day FVG
   if (State.prevDayFVGExists) {
      belowPrevDayFVGLow = bidPrice < State.prevDayFirstFVG.low;
   }

   addTextOnScreen("SELL Conditions:", clrRed);
   addTextOnScreen("  Below Middle: " + (belowMiddle ? "Yes" : "No"), belowMiddle ? clrGreen : clrRed);
   addTextOnScreen("  Below MA20: " + (belowMA ? "Yes" : "No"), belowMA ? clrGreen : clrRed);
   addTextOnScreen("  SwingLow Taken: " + (swingLowTaken ? "Yes" : "No"), swingLowTaken ? clrGreen : clrRed);
   addTextOnScreen("  Below FVG Low: " + (belowFVGLow ? "Yes" : "No"), belowFVGLow ? clrGreen : clrRed);
   addTextOnScreen("  Below Prev Day FVG Low: " + (belowPrevDayFVGLow ? "Yes" : "No"), belowPrevDayFVGLow ? clrGreen : clrRed);

   // Add swing point tracking information
   if (HasActivePositionsOrOrders() && State.entryTime > 0) {
      // Get position type
      ENUM_POSITION_TYPE posType = POSITION_TYPE_BUY; // Default

      for (int i = 0; i < PositionsTotal(); i++) {
         ulong ticket = PositionGetTicket(i);
         if (ticket != 0 && PositionGetString(POSITION_SYMBOL) == _Symbol) {
            posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            break;
         }
      }

      // Count taken and untaken swing points
      int takenSwingPoints = 0;
      int untakenSwingPoints = 0;

      if (posType == POSITION_TYPE_BUY) {
         // For buy positions, count taken swing lows
         for (int j = 0; j < ArraySize(State.swingLowsSinceEntry); j++) {
            if (State.swingLowsSinceEntry[j].taken) {
               takenSwingPoints++;
            }
         }

         // For buy positions, count untaken swing highs
         for (int j = 0; j < ArraySize(State.swingHighsSinceEntry); j++) {
            if (!State.swingHighsSinceEntry[j].taken) {
               untakenSwingPoints++;
            }
         }

         addTextOnScreen("Swing Lows Taken: " + IntegerToString(takenSwingPoints) +
                        "/" + IntegerToString(MAX_SWING_POINTS),
                        takenSwingPoints >= MAX_SWING_POINTS ? clrRed : clrYellow);

         addTextOnScreen("Swing Highs Not Taken: " + IntegerToString(untakenSwingPoints) +
                        "/" + IntegerToString(MAX_SWING_POINTS),
                        untakenSwingPoints >= MAX_SWING_POINTS ? clrRed : clrYellow);
      } else {
         // For sell positions, count taken swing highs
         for (int j = 0; j < ArraySize(State.swingHighsSinceEntry); j++) {
            if (State.swingHighsSinceEntry[j].taken) {
               takenSwingPoints++;
            }
         }

         // For sell positions, count untaken swing lows
         for (int j = 0; j < ArraySize(State.swingLowsSinceEntry); j++) {
            if (!State.swingLowsSinceEntry[j].taken) {
               untakenSwingPoints++;
            }
         }

         addTextOnScreen("Swing Highs Taken: " + IntegerToString(takenSwingPoints) +
                        "/" + IntegerToString(MAX_SWING_POINTS),
                        takenSwingPoints >= MAX_SWING_POINTS ? clrRed : clrYellow);

         addTextOnScreen("Swing Lows Not Taken: " + IntegerToString(untakenSwingPoints) +
                        "/" + IntegerToString(MAX_SWING_POINTS),
                        untakenSwingPoints >= MAX_SWING_POINTS ? clrRed : clrYellow);
      }
   }
}

//+------------------------------------------------------------------+
//| Manage existing trades based on R multiples                      |
//+------------------------------------------------------------------+
void ManageExistingTrades() {
   // Only proceed if we have active positions
   if (!HasActivePositionsOrOrders()) {
      return;
   }

   // Check if a new candle has formed since last check
   static datetime lastCandleTime = 0;
   datetime currentCandleTime = iTime(_Symbol, PERIOD_M1, 0);

   // If this is a new candle, manage trades
   if (currentCandleTime > lastCandleTime) {
      lastCandleTime = currentCandleTime;

      // Update swing points since position entry
      UpdateSwingPointsSinceEntry();

      // Check for breakeven and partial profit targets
      CheckBreakevenAndPartialProfit();

      // Check for partial loss targets
      CheckPartialLoss();

      // Check for swing point exit conditions
      CheckSwingPointExits();
   }
}

//+------------------------------------------------------------------+
//| Check if trades should be closed based on swing point count      |
//+------------------------------------------------------------------+
void CheckSwingPointExits() {
   // Iterate through positions
   for (int i = 0; i < PositionsTotal(); i++) {
      ulong ticket = PositionGetTicket(i);

      // Skip positions for other symbols
      if (ticket == 0 || PositionGetString(POSITION_SYMBOL) != _Symbol) {
         continue;
      }

      // Get position type
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // --- Scenario 1: Count taken swing points ---
      int swingPointsTaken = 0;

      // For buy positions, count taken swing lows
      if (posType == POSITION_TYPE_BUY) {
         for (int j = 0; j < ArraySize(State.swingLowsSinceEntry); j++) {
            if (State.swingLowsSinceEntry[j].taken) {
               swingPointsTaken++;
            }
         }

         // Close trade if MAX_SWING_POINTS swing lows have been taken
         if (swingPointsTaken >= MAX_SWING_POINTS) {
            if (ClosePositionWithReason(ticket, "BUY", MAX_SWING_POINTS, "swing lows taken")) {
               continue; // Skip to next position after closure
            }
         }
      }
      // For sell positions, count taken swing highs
      else {
         for (int j = 0; j < ArraySize(State.swingHighsSinceEntry); j++) {
            if (State.swingHighsSinceEntry[j].taken) {
               swingPointsTaken++;
            }
         }

         // Close trade if MAX_SWING_POINTS swing highs have been taken
         if (swingPointsTaken >= MAX_SWING_POINTS) {
            if (ClosePositionWithReason(ticket, "SELL", MAX_SWING_POINTS, "swing highs taken")) {
               continue; // Skip to next position after closure
            }
         }
      }

      // --- Scenario 2: Count formed but not taken swing points ---
      int swingPointsFormedNotTaken = 0;

      // For buy positions, count swing highs that formed but were NOT taken
      if (posType == POSITION_TYPE_BUY) {
         for (int j = 0; j < ArraySize(State.swingHighsSinceEntry); j++) {
            if (!State.swingHighsSinceEntry[j].taken) {
               swingPointsFormedNotTaken++;
            }
         }

         // Close trade if MAX_SWING_POINTS swing highs formed but not taken
         if (swingPointsFormedNotTaken >= MAX_SWING_POINTS) {
            if (ClosePositionWithReason(ticket, "BUY", MAX_SWING_POINTS, "swing highs formed but not taken")) {
               continue; // Skip to next position after closure
            }
         }
      }
      // For sell positions, count swing lows that formed but were NOT taken
      else {
         for (int j = 0; j < ArraySize(State.swingLowsSinceEntry); j++) {
            if (!State.swingLowsSinceEntry[j].taken) {
               swingPointsFormedNotTaken++;
            }
         }

         // Close trade if MAX_SWING_POINTS swing lows formed but not taken
         if (swingPointsFormedNotTaken >= MAX_SWING_POINTS) {
            if (ClosePositionWithReason(ticket, "SELL", MAX_SWING_POINTS, "swing lows formed but not taken")) {
               continue; // Skip to next position after closure
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Close position with a detailed reason message                    |
//+------------------------------------------------------------------+
bool ClosePositionWithReason(ulong ticket, string direction, int count, string reason) {
   if (trade.PositionClose(ticket)) {
      Print("Closed ", direction, " position #", ticket, " due to ", count, " ", reason);

      // Reset entry time and swing point arrays
      State.entryTime = 0;
      ArrayFree(State.swingHighsSinceEntry);
      ArrayFree(State.swingLowsSinceEntry);
      return true;
   } else {
      Print("Failed to close position. Error: ", GetLastError());
      return false;
   }
}

//+------------------------------------------------------------------+
//| Update swing points since position entry                         |
//+------------------------------------------------------------------+
void UpdateSwingPointsSinceEntry() {
   // Only track swing points if we have an active position
   if (!HasActivePositionsOrOrders() || State.entryTime == 0) {
      return;
   }

   // Get the position type (buy or sell)
   ENUM_POSITION_TYPE posType = POSITION_TYPE_BUY; // Default
   bool positionFound = false; // Add this variable declaration

   for (int i = 0; i < PositionsTotal(); i++) {
      ulong ticket = PositionGetTicket(i);
      if (ticket != 0 && PositionGetString(POSITION_SYMBOL) == _Symbol) {
         posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         positionFound = true; // Set to true when position is found
         break;
      }
   }

   if (!positionFound) {
      return; // No position found
   }

   // Find bar index of entry time
   int entryBarIndex = 0;
   for (int i = 0; i < 500; i++) {
      datetime barTime = iTime(_Symbol, PERIOD_M1, i);
      if (barTime <= State.entryTime) {
         entryBarIndex = i;
         break;
      }
   }

   // Get swing points since entry - for both position types, track both highs and lows
   // We need both to implement the complete exit criteria
   GetSwingLows(MAX_SWING_POINTS * 2, State.swingLowsSinceEntry, PERIOD_M1, entryBarIndex, false, SwingLowColor);
   GetSwingHighs(MAX_SWING_POINTS * 2, State.swingHighsSinceEntry, PERIOD_M1, entryBarIndex, false, SwingHighColor);

   // Debug info
   if (posType == POSITION_TYPE_BUY) {
      int takenLowsCount = 0;
      int untakenHighsCount = 0;

      for (int i = 0; i < ArraySize(State.swingLowsSinceEntry); i++) {
         if (State.swingLowsSinceEntry[i].taken) {
            takenLowsCount++;
         }
      }

      for (int i = 0; i < ArraySize(State.swingHighsSinceEntry); i++) {
         if (!State.swingHighsSinceEntry[i].taken) {
            untakenHighsCount++;
         }
      }

      Print("LONG position: ", takenLowsCount, " swing lows taken, ",
            untakenHighsCount, " swing highs formed but not taken.");
   } else {
      int takenHighsCount = 0;
      int untakenLowsCount = 0;

      for (int i = 0; i < ArraySize(State.swingHighsSinceEntry); i++) {
         if (State.swingHighsSinceEntry[i].taken) {
            takenHighsCount++;
         }
      }

      for (int i = 0; i < ArraySize(State.swingLowsSinceEntry); i++) {
         if (!State.swingLowsSinceEntry[i].taken) {
            untakenLowsCount++;
         }
      }

      Print("SHORT position: ", takenHighsCount, " swing highs taken, ",
            untakenLowsCount, " swing lows formed but not taken.");
   }
}

//+------------------------------------------------------------------+
//| Check if trades have reached breakeven and partial profit levels |
//+------------------------------------------------------------------+
void CheckBreakevenAndPartialProfit() {
   for (int i = 0; i < PositionsTotal(); i++) {
      ulong ticket = PositionGetTicket(i);

      // Skip positions for other symbols
      if (ticket == 0 || PositionGetString(POSITION_SYMBOL) != _Symbol) {
         continue;
      }

      // Get position details
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double stopLoss = PositionGetDouble(POSITION_SL);
      double takeProfit = PositionGetDouble(POSITION_TP);
      double currentPrice = posType == POSITION_TYPE_BUY ?
                           SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                           SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      // Calculate initial risk (in price points)
      double initialRisk = MathAbs(entryPrice - stopLoss);

      // Calculate current profit/loss in R multiples
      double currentProfitPoints = posType == POSITION_TYPE_BUY ?
                                 currentPrice - entryPrice :
                                 entryPrice - currentPrice;
      double profitInR = currentProfitPoints / initialRisk;

      // Check if the position has reached our BE level for profit target
      if (profitInR >= BE_RRR_Level) {
         // Skip if SL already at or better than breakeven
         bool slAlreadyAtBE = (posType == POSITION_TYPE_BUY && stopLoss >= entryPrice) ||
                              (posType == POSITION_TYPE_SELL && stopLoss <= entryPrice);

         if (!slAlreadyAtBE) {
            // Move stop loss to breakeven
            if (trade.PositionModify(ticket, entryPrice, takeProfit)) {
               Print("Trade reached ", DoubleToString(BE_RRR_Level, 1), "R: SL moved to breakeven");
            } else {
               Print("Failed to move SL to breakeven. Error: ", GetLastError());
            }
         }

         // Take partial profit
         TakePartialProfitByPercent(ticket, PARTIAL_PROFIT_PERCENT);
      }

      // Implement trailing stop after 3R profit
      if (profitInR >= 3.0) {
         // Calculate new stop level
         double newStopLevel;
         if (posType == POSITION_TYPE_BUY) {
            // For buy positions, trail 1.5R behind current price
            newStopLevel = currentPrice - (initialRisk * 1.5);
            // Only move stop if it would be higher than current stop
            if (newStopLevel > stopLoss) {
               if (trade.PositionModify(ticket, newStopLevel, takeProfit)) {
                  Print("Trailing stop updated to ", DoubleToString(newStopLevel, _Digits));
               }
            }
         } else {
            // For sell positions, trail 1.5R behind current price
            newStopLevel = currentPrice + (initialRisk * 1.5);
            // Only move stop if it would be lower than current stop
            if (newStopLevel < stopLoss) {
               if (trade.PositionModify(ticket, newStopLevel, takeProfit)) {
                  Print("Trailing stop updated to ", DoubleToString(newStopLevel, _Digits));
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check if trades have reached partial loss levels                 |
//+------------------------------------------------------------------+
void CheckPartialLoss() {
   for (int i = 0; i < PositionsTotal(); i++) {
      ulong ticket = PositionGetTicket(i);

      // Skip positions for other symbols
      if (ticket == 0 || PositionGetString(POSITION_SYMBOL) != _Symbol) {
         continue;
      }

      // Get position details
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double stopLoss = PositionGetDouble(POSITION_SL);
      double currentPrice = posType == POSITION_TYPE_BUY ?
                           SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                           SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      // Calculate initial risk (in price points)
      double initialRisk = MathAbs(entryPrice - stopLoss);

      // Calculate current loss in R multiples
      double currentLossPoints = posType == POSITION_TYPE_BUY ?
                              entryPrice - currentPrice :
                              currentPrice - entryPrice;
      double lossInR = currentLossPoints / initialRisk;

      // Check if the position has reached our partial loss target
      if (lossInR >= PARTIAL_LOSS_RRR) {
         // Take partial loss
         TakePartialProfitByPercent(ticket, PARTIAL_LOSS_PERCENT);
      }
   }
}

//+------------------------------------------------------------------+
//| Take partial profit/loss by percentage                           |
//+------------------------------------------------------------------+
bool TakePartialProfitByPercent(ulong ticket, double percent) {
   if (!PositionSelectByTicket(ticket)) {
      Print("Failed to select position with ticket #", ticket);
      return false;
   }

   // Get position details
   double positionVolume = PositionGetDouble(POSITION_VOLUME);

   // Calculate lot size to close
   double lotToClose = NormalizeDouble(positionVolume * percent, 2);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   // Ensure we're closing valid lot size
   lotToClose = MathFloor(lotToClose / stepLot) * stepLot;
   lotToClose = MathMax(lotToClose, minLot);

   // Ensure we're not trying to close more than we have
   lotToClose = MathMin(lotToClose, positionVolume);

   // Check if there's enough volume to close
   if (lotToClose < minLot || lotToClose > positionVolume) {
      Print("Invalid lot size to close: ", lotToClose,
            " (min: ", minLot, ", position volume: ", positionVolume, ")");
      return false;
   }

   // Close the partial position
   bool success = trade.PositionClosePartial(ticket, lotToClose);
   if (success) {
      string actionType = PositionGetDouble(POSITION_PROFIT) >= 0 ? "profit" : "loss";
      Print("Partial ", actionType, " taken: Closed ",
            DoubleToString(lotToClose, 2), " lots (",
            DoubleToString(percent * 100, 0), "% of position)");
   } else {
      Print("Failed to take partial position. Error: ", GetLastError());
   }

   return success;
}
