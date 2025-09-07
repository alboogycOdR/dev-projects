//+------------------------------------------------------------------+
//|                                                NY-Strategy-1.mq5 |
//|                        Copyright 2025, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Smart KeyLevels Strategy with FVG confirmation"
#property strict

//--- Include necessary helpers
#include <Helpers\GetRange.mqh>
#include <Helpers\GetSwingHighLows.mqh>
#include <Helpers\GetFVGs.mqh>
#include <Helpers\RiskManagement.mqh>
#include <Helpers\OrderManagement.mqh>
#include <Helpers\GetIndicators.mqh>
#include <Helpers\TextDisplay.mqh>
#include <Helpers\GetNews.mqh>
#include <Trade\Trade.mqh>

//--- Enumerations
enum TRADE_DIRECTION {
   NO_DIRECTION,   // No direction
   LONG,           // Bullish
   SHORT           // Bearish
};

//--- Structures
struct StrategyState {
   // Market structure
   TimeRange        asianRanges[];         // Asian range
   TimeRange        londonRanges[];        // London range
   FVG              bullishFVGs[];    // Bullish fair value gaps
   FVG              bearishFVGs[];    // Bearish fair value gaps
   SwingPoint       swingHighs[];     // Swing high points
   SwingPoint       swingLows[];      // Swing low points
   double           keyLevels[];     // Key levels
   double           prevDayHigh;     // Previous day high
   double           prevDayLow;      // Previous day low
   double           prevWeekHigh;    // Previous week high
   double           prevWeekLow;     // Previous week low

   // Position management
   double           entryPrice;       // Entry price for position
   double           stopLoss;         // Stop loss price
   double           beRRR;           // Breakeven risk to reward ratio

   // Session management
   double           startDayBalance;  // Balance at start of trading day
   datetime         lastReset;        // Last reset datetime
   datetime         lastDisplayUpdate;  // Last display update time
   double           startMonthBalance;  // Balance at start of trading month
   datetime         lastMonthReset;    // Last month reset datetime

   // Constructor with default values
   void StrategyState() {
      entryPrice = 0.0;
      stopLoss = 0.0;
      beRRR = 1.0;
      startDayBalance = 0.0;
      lastReset = 0;
      lastDisplayUpdate = 0;
      startMonthBalance = 0.0;
      lastMonthReset = 0;
   }
};

//--- Global variables
StrategyState state;  // Main strategy state

//--- Input parameters
// Opening Range parameters
input string     AsianStartTime = "01:00";       // 1800 NY = 0100 KE no DST (HH:MM)
input string     AsianEndTime = "07:00";         // 0000 NY = 0700 KE no DST (HH:MM)
input string     LondonStartTime = "07:00";      // 0000 NY = 0700 KE no DST (HH:MM)
input string     LondonEndTime = "13:00";        // 0600 NY = 1300 KE no DST (HH:MM)
input int        startTradingMinute = 30;          // Start minute for trading
input int        startTradingHourAM = 16;          // 0900 NY = 1600 KE no DST (24H)
input int        endTradingHourAM = 18;            // 1100 NY = 1800 KE no DST (24H)
input int        startTradingHourPM = 20;          // 1300 NY = 2000 KE no DST (24H)
input int        endTradingHourPM = 22;            // 1500 NY = 2200 KE no DST (24H)

// Market structure parameters
input bool       DrawOnChart = true;          // Draw ranges on chart
input int        MaxSwingPoints = 10;         // Number of swing points to identify
input int        MinFVGSearchRange = 10;      // Minimum bars to search for FVGs
input int        FVGLookBackBars = 2;         // FVG lookback bars
input int        SMA_Period = 20;             // SMA period for trend confirmation
input double     BufferPips = 1.0;            // Buffer in pips for stop loss
double           MinGapSize = 5.0;            // Minimum gap size in pips for FVGs

// Money management parameters
input double     RiskDollars = 100.0;         // Risk in dollars per trade
input double     MinRRR = 3.0;                // Minimum risk to reward ratio
input double     MaxDailyLoss = 188;          // Maximum daily loss in account currency
input double     DailyTarget = 190;           // Daily target in account currency
input double     MonthlyTarget = 800;         // Monthly target in account currency
input double     MonthlyMaxLoss = 800;        // Monthly maximum loss in account currency
input bool       UseMonthlyTarget = true;     // Use Monthly target

// Position management parameters
input bool       UseBreakeven = true;        // Use breakeven for positions
input double     BeRRR = 1.0;                // Breakeven risk to reward ratio

// Display parameters
input bool       ShowTextOnChart = true;      // Show strategy conditions on chart
input int        DisplayUpdateInterval = 5;   // Update display every N seconds
input color      InfoTextColor = clrWhite;    // Information text color
input color      PositiveCondColor = clrLime; // Positive condition text color
input color      NegativeCondColor = clrRed;  // Negative condition text color

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   // Clear chart objects and set timer
   ObjectsDeleteAll(ChartID(), "");
   EventSetTimer(5);

   // Initialize strategy state
   state.startDayBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   state.startMonthBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   state.beRRR = BeRRR;

   // Initialize display
   if(ShowTextOnChart) {
      clearTextDisplay();
      addTextOnScreen("NY-Strategy-1 initialized", InfoTextColor);
   }

   Print("NY-Strategy-1 initialized successfully");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   // ObjectsDeleteAll(ChartID(), ""); // keep objects for post-trading analysis
   EventKillTimer();
   Print("NY-Strategy-1 deinitialized");
}

//+------------------------------------------------------------------+
//| Timer event function                                             |
//+------------------------------------------------------------------+
void OnTimer() {
   // Check if trading is allowed by system
   isTradingAllowedBySystem();

   // Reset day balance on a new day
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);

   // Check if we need to reset for a new day
   MqlDateTime lastResetDT;
   if(state.lastReset > 0) {
      TimeToStruct(state.lastReset, lastResetDT);
   }

   // Reset if it's a new day or if lastReset has never been set
   if(state.lastReset == 0 || lastResetDT.day != dt.day || lastResetDT.mon != dt.mon || lastResetDT.year != dt.year) {
      state.startDayBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      state.lastReset = now;
      Print("New day detected. Starting Day balance reset to: ", DoubleToString(state.startDayBalance, 2));
   }

   // Reset month balance if needed
   if(UseMonthlyTarget) {
      MqlDateTime lastMonthResetDT;
      if(state.lastMonthReset > 0) {
         TimeToStruct(state.lastMonthReset, lastMonthResetDT);
      }

      // Reset if it's a new month or if lastMonthReset has never been set
      if(state.lastMonthReset == 0 || lastMonthResetDT.mon != dt.mon || lastMonthResetDT.year != dt.year) {
         state.startMonthBalance = AccountInfoDouble(ACCOUNT_BALANCE);
         state.lastMonthReset = now;
         Print("New month detected. Starting Month balance reset to: ", DoubleToString(state.startMonthBalance, 2));
      }
   }

   if(!IsNYHour() || !AccountRiskValid() || !IsTradingAllowedByNews()) {
      // If not in NY hour or not risk valid or news trading not allowed, do not execute trading logic
      return;
   }

   // Update market structure elements and display
   UpdateMarketStructure();

   // Update display if interval has passed
   if(ShowTextOnChart && now - state.lastDisplayUpdate >= DisplayUpdateInterval) {
      UpdateDisplayInfo();
      state.lastDisplayUpdate = now;
   }

   // Get key levels
   // Detect asian and london range
   bool asainRangeFound = GetRanges(AsianStartTime, AsianEndTime, state.asianRanges, 0, "AR", DrawOnChart, PERIOD_CURRENT, true, true, false);
   bool londonRangeFound = GetRanges(LondonStartTime, LondonEndTime, state.londonRanges, 0, "LR", DrawOnChart, PERIOD_CURRENT, true, true, false);
   if(!asainRangeFound || !londonRangeFound) return;

   state.prevDayHigh = iHigh(_Symbol, PERIOD_D1, 1);
   state.prevDayLow = iLow(_Symbol, PERIOD_D1, 1);
   state.prevWeekHigh = iHigh(_Symbol, PERIOD_W1, 1);
   state.prevWeekLow = iLow(_Symbol, PERIOD_W1, 1);

   ArrayResize(state.keyLevels, 8);
   state.keyLevels[0] = state.prevDayHigh;
   state.keyLevels[1] = state.prevDayLow;
   state.keyLevels[2] = state.prevWeekHigh;
   state.keyLevels[3] = state.prevWeekLow;
   state.keyLevels[4] = state.asianRanges[0].high;
   state.keyLevels[5] = state.asianRanges[0].low;
   state.keyLevels[6] = state.londonRanges[0].high;
   state.keyLevels[7] = state.londonRanges[0].low;

   // sort the key levels
   ArraySort(state.keyLevels);

   // Draw horisontal lines for previous day high and low
   if(DrawOnChart) {
      DrawKeyLevel(state.prevDayHigh, "PDH", clrDodgerBlue);
      DrawKeyLevel(state.prevDayLow, "PDL", clrLightPink);
      DrawKeyLevel(state.prevWeekHigh, "PWH", clrCornflowerBlue);
      DrawKeyLevel(state.prevWeekLow, "PWL", clrTomato);
   }

   // Process trading logic
   if(!HasActivePositionsOrOrders()) {
      ExecuteTradeSignal(CheckForEntrySignals());
   } else {
      ManagePositions();
   }
}

void DrawKeyLevel(double price, string name, color clr) {
   if(!ObjectDelete(0, name)) {
      Print("Failed to delete line", GetLastError());
   }
   if(!ObjectCreate(0, name, OBJ_HLINE, 0, 0, price)) {
      Print("Failed to create object: ", GetLastError());
   }
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, "Name: " + name + DoubleToString(price, _Digits));
}

//+------------------------------------------------------------------+
//| Update the display with current strategy info                    |
//+------------------------------------------------------------------+
void UpdateDisplayInfo() {
   clearTextDisplay();

   // Show current time
   datetime currentTime = TimeCurrent();
   string timeStrMsg = "Current time: " + TimeToString(currentTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS);
   addTextOnScreen(timeStrMsg, InfoTextColor);

   // Show trading session info
   string tradeHoursAMMsg = "Trading Hours AM: " + IntegerToString(startTradingHourAM) + ":" + IntegerToString(startTradingMinute) + " - " + IntegerToString(endTradingHourAM) + ":00";
   addTextOnScreen(tradeHoursAMMsg, InfoTextColor);

   string tradeHoursPMMsg = "Trading Hours PM: " + IntegerToString(startTradingHourPM) + ":" + IntegerToString(startTradingMinute) + " - " + IntegerToString(endTradingHourPM) + ":00";
   addTextOnScreen(tradeHoursPMMsg, InfoTextColor);

   // Show account info
   string accountMsg = "Account Balance: $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2);
   addTextOnScreen(accountMsg, InfoTextColor);

   // Show day P/L
   double dayPnL = AccountInfoDouble(ACCOUNT_BALANCE) - state.startDayBalance;
   string dayPnLMsg = "Day P/L: $" + DoubleToString(dayPnL, 2);
   color pnlColor = (dayPnL >= 0) ? PositiveCondColor : NegativeCondColor;
   addTextOnScreen(dayPnLMsg, pnlColor);

   // Show month P/L
   double monthPnL = AccountInfoDouble(ACCOUNT_BALANCE) - state.startMonthBalance;
   string monthPnLMsg = "Month P/L: $" + DoubleToString(monthPnL, 2);
   color monthPnlColor = (monthPnL >= 0) ? PositiveCondColor : NegativeCondColor;
   addTextOnScreen(monthPnLMsg, monthPnlColor);

   // Show current trading conditions
   bool inNYHour = IsNYHour();
   bool riskValid = AccountRiskValid();
   bool newsAllowed = IsTradingAllowedByNews();
   string timeCondMsg = "Trading Hour: " + (inNYHour ? "YES" : "NO");
   string riskCondMsg = "Risk Valid: " + (riskValid ? "YES" : "NO");
   string newsCondMsg = "News Trading Allowed: " + (newsAllowed ? "YES" : "NO");

   addTextOnScreen(timeCondMsg, inNYHour ? PositiveCondColor : NegativeCondColor);
   addTextOnScreen(riskCondMsg, riskValid ? PositiveCondColor : NegativeCondColor);
   addTextOnScreen(newsCondMsg, newsAllowed ? PositiveCondColor : NegativeCondColor);

   // Show market structure
   if(ArraySize(state.asianRanges) > 0) {
      string rangeMsg = "AR High: " + DoubleToString(state.asianRanges[0].high, _Digits) +
                        " Mid: " + DoubleToString(state.asianRanges[0].middle, _Digits) +
                        " Low: " + DoubleToString(state.asianRanges[0].low, _Digits);
      addTextOnScreen(rangeMsg, InfoTextColor);
   }

   if(ArraySize(state.londonRanges) > 0) {
      string rangeMsg2 = "LR High: " + DoubleToString(state.londonRanges[0].high, _Digits) +
                        " Mid: " + DoubleToString(state.londonRanges[0].middle, _Digits) +
                        " Low: " + DoubleToString(state.londonRanges[0].low, _Digits);
      addTextOnScreen(rangeMsg2, InfoTextColor);
   }

   // show previous day high and low
   string prevDayMsg = "PDH: " + DoubleToString(state.prevDayHigh, _Digits) +
                        " PDL: " + DoubleToString(state.prevDayLow, _Digits);
   addTextOnScreen(prevDayMsg, InfoTextColor);

   string prevWeekMsg = "PWH: " + DoubleToString(state.prevWeekHigh, _Digits) +
                        " PWL: " + DoubleToString(state.prevWeekLow, _Digits);
   addTextOnScreen(prevWeekMsg, InfoTextColor);

   // Show current price vs. MA
   double prevClose = iClose(_Symbol, PERIOD_CURRENT, 1);
   bool aboveSMA = CheckIsAboveSMA(prevClose, SMA_Period);
   string maCondMsg = "Price vs SMA" + IntegerToString(SMA_Period) + ": " + (aboveSMA ? "ABOVE" : "BELOW");
   addTextOnScreen(maCondMsg, aboveSMA ? PositiveCondColor : NegativeCondColor);

   // Show FVG counts
   string fvgMsg = "FVGs: " + IntegerToString(ArraySize(state.bullishFVGs)) + " Bullish, " +
                   IntegerToString(ArraySize(state.bearishFVGs)) + " Bearish";
   addTextOnScreen(fvgMsg, InfoTextColor);

   bool closeAboveSwingHigh = prevClose > state.swingHighs[0].price;
   string swingHighCondMsg = "Price vs Swing High: " + (closeAboveSwingHigh ? "ABOVE" : "BELOW");
   addTextOnScreen(swingHighCondMsg, closeAboveSwingHigh  ? PositiveCondColor : NegativeCondColor);

   bool closeBelowSwingLow = prevClose < state.swingLows[0].price;
   string swingLowCondMsg = "Price vs Swing Low: " + (closeBelowSwingLow ? "BELOW" : "ABOVE");
   addTextOnScreen(swingLowCondMsg, closeBelowSwingLow ? PositiveCondColor : NegativeCondColor);

   // Show position details or signal conditions
   if(HasActivePositionsOrOrders()) {
      ShowPositionDetails();
   } else {
      ShowSignalConditions();
   }
}

//+------------------------------------------------------------------+
//| Show details of current open position                            |
//+------------------------------------------------------------------+
void ShowPositionDetails() {
   addTextOnScreen("=== POSITION DETAILS ===", InfoTextColor);

   for(int i = 0; i < PositionsTotal(); i++) {
      ulong ticket = PositionGetTicket(i);
      if(ticket != 0 && PositionGetString(POSITION_SYMBOL) == _Symbol) {
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentPrice = (posType == POSITION_TYPE_BUY) ?
                               SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                               SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double slPrice = PositionGetDouble(POSITION_SL);
         double tpPrice = PositionGetDouble(POSITION_TP);
         double volume = PositionGetDouble(POSITION_VOLUME);
         double profit = PositionGetDouble(POSITION_PROFIT);

         // Position details
         string posTypeStr = (posType == POSITION_TYPE_BUY) ? "LONG" : "SHORT";
         string posMsg = "Position: " + posTypeStr + " | Volume: " + DoubleToString(volume, 2);
         addTextOnScreen(posMsg, InfoTextColor);

         // Entry and current price
         string priceMsg = "Entry: " + DoubleToString(openPrice, _Digits) +
                           " | Current: " + DoubleToString(currentPrice, _Digits);
         addTextOnScreen(priceMsg, InfoTextColor);

         // Stop loss and take profit
         string slTpMsg = "SL: " + DoubleToString(slPrice, _Digits) +
                          " | TP: " + DoubleToString(tpPrice, _Digits);
         addTextOnScreen(slTpMsg, InfoTextColor);

         // Profit condition
         string profitMsg = "Profit: $" + DoubleToString(profit, 2);
         color profitColor = (profit >= 0) ? PositiveCondColor : NegativeCondColor;
         addTextOnScreen(profitMsg, profitColor);
      }
   }
}

//+------------------------------------------------------------------+
//| Show current signal conditions                                   |
//+------------------------------------------------------------------+
void ShowSignalConditions() {

   addTextOnScreen("=== SIGNAL CONDITIONS ===", InfoTextColor);

   double prevClose = iClose(_Symbol, PERIOD_CURRENT, 1);
   bool inNYHour = IsNYHour();
   bool riskValid = AccountRiskValid();
   bool newsAllowed = IsTradingAllowedByNews();
   bool tradingConditionsValid = inNYHour && riskValid && newsAllowed;

   // Long conditions
   bool aboveSMA = CheckIsAboveSMA(prevClose, SMA_Period);
   bool swingLowsRejLevel = SwingLowsRejectingLevel(state.swingLows, state.keyLevels, prevClose);
   bool hasBullishFVGs = (ArraySize(state.bullishFVGs) > 0);

   string longCondMsg = "LONG Signal Conditions:";
   addTextOnScreen(longCondMsg, InfoTextColor);

   string aboveSMAMsg = "- Price Above SMA" + IntegerToString(SMA_Period) + ": " + (aboveSMA ? "YES" : "NO");
   string bullishFVGMsg = "- Bullish FVGs Present: " + (hasBullishFVGs ? "YES" : "NO");
   string swingLowsRejLevelMsg = "- Swing Lows rej KeyLev: " + (swingLowsRejLevel ? "YES" : "NO");

   addTextOnScreen(aboveSMAMsg, aboveSMA ? PositiveCondColor : NegativeCondColor);
   addTextOnScreen(bullishFVGMsg, hasBullishFVGs ? PositiveCondColor : NegativeCondColor);
   addTextOnScreen(swingLowsRejLevelMsg, swingLowsRejLevel ? PositiveCondColor : NegativeCondColor);

   // Short conditions
   bool belowSMA = !aboveSMA;
   bool swingHighsRejLevel = SwingHighsRejectingLevel(state.swingHighs, state.keyLevels, prevClose);
   bool hasBearishFVGs = (ArraySize(state.bearishFVGs) > 0);

   string shortCondMsg = "SHORT Signal Conditions:";
   addTextOnScreen(shortCondMsg, InfoTextColor);

   string belowSMAMsg = "- Price Below SMA" + IntegerToString(SMA_Period) + ": " + (belowSMA ? "YES" : "NO");
   string bearishFVGMsg = "- Bearish FVGs Present: " + (hasBearishFVGs ? "YES" : "NO");
   string swingHighsRejLevelMsg = "- Swing Highs rej KeyLev: " + (swingHighsRejLevel ? "YES" : "NO");

   addTextOnScreen(belowSMAMsg, belowSMA ? PositiveCondColor : NegativeCondColor);
   addTextOnScreen(bearishFVGMsg, hasBearishFVGs ? PositiveCondColor : NegativeCondColor);
   addTextOnScreen(swingHighsRejLevelMsg, swingHighsRejLevel ? PositiveCondColor : NegativeCondColor);

   // Overall signal status
   bool longSignalValid =  aboveSMA && swingLowsRejLevel && hasBullishFVGs && tradingConditionsValid;
   bool shortSignalValid = belowSMA && swingHighsRejLevel && hasBearishFVGs && tradingConditionsValid;

   string signalStatusMsg = "Ready to Trade: ";
   if(longSignalValid) signalStatusMsg += "LONG";
   else if(shortSignalValid) signalStatusMsg += "SHORT";
   else signalStatusMsg += "NO";

   color signalColor = (longSignalValid || shortSignalValid) ? PositiveCondColor : NegativeCondColor;
   addTextOnScreen(signalStatusMsg, signalColor);
}

//+------------------------------------------------------------------+
//| Update market structure elements                                 |
//+------------------------------------------------------------------+
void UpdateMarketStructure() {
   // Get swing points
   GetSwingLows(MaxSwingPoints, state.swingLows, PERIOD_CURRENT, 500, DrawOnChart, clrCrimson);
   GetSwingHighs(MaxSwingPoints, state.swingHighs, PERIOD_CURRENT, 500, DrawOnChart, clrDodgerBlue);

   // Get FVGs outside of opening range - for overall market context
   GetBullishFVGs(FVGLookBackBars, MinFVGSearchRange, state.bullishFVGs, MinFVGSearchRange, DrawOnChart, clrGreenYellow, false);
   GetBearishFVGs(FVGLookBackBars, MinFVGSearchRange, state.bearishFVGs, MinFVGSearchRange, DrawOnChart, clrDeepPink, false);
}

//+------------------------------------------------------------------+
//| Check if current time is within Smart Breakout trading hours     |
//+------------------------------------------------------------------+
bool IsNYHour() {
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);

   if(dt.hour == startTradingHourAM && dt.min >= startTradingMinute) {
      return true;
   }

   if(dt.hour > startTradingHourAM && dt.hour < endTradingHourAM) {
      return true;
   }

   if(dt.hour == startTradingHourPM && dt.min >= startTradingMinute) {
      return true;
   }

   if(dt.hour > startTradingHourPM && dt.hour < endTradingHourPM) {
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Check account risk conditions                                    |
//+------------------------------------------------------------------+
bool AccountRiskValid() {
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double dayPnL = currentBalance - state.startDayBalance;
   double monthPnL = currentBalance - state.startMonthBalance;

   // Check if daily loss is exceeded (negative dayPnL beyond the limit)
   bool lossExceeded = (dayPnL <= -MaxDailyLoss);

   // Check if daily target is reached (positive dayPnL reaching the target)
   bool targetReached = (dayPnL >= DailyTarget);

   // Check if monthly target is reached (positive monthPnL reaching the target)
   bool monthlyTargetReached, monthlyLossExceeded;
   if(UseMonthlyTarget) {
      monthlyTargetReached = (monthPnL >= MonthlyTarget);
   }
   monthlyLossExceeded = (monthPnL <= -MonthlyMaxLoss);

   // Debug output
   if(lossExceeded) Print("Daily loss limit exceeded: $", DoubleToString(dayPnL, 2));
   if(targetReached) Print("Daily profit target reached: $", DoubleToString(dayPnL, 2));
   if(UseMonthlyTarget && monthlyTargetReached) Print("Monthly profit target reached: $", DoubleToString(monthPnL, 2));
   if(monthlyLossExceeded) Print("Monthly loss limit exceeded: $", DoubleToString(monthPnL, 2));

   // Return valid if neither condition is true
   return !(lossExceeded || targetReached || monthlyLossExceeded || (UseMonthlyTarget && monthlyTargetReached));
}

bool SwingHighsRejectingLevel(SwingPoint &swingHighs[], double &keyLevels[], double prevClose) {
   // Check if we have at least 2 swing highs and 1 key level
   if(ArraySize(swingHighs) < 2 || ArraySize(keyLevels) < 1) {
      return false;
   }

   // Loop through each key level
   for(int i = 0; i < ArraySize(keyLevels); i++) {
      double keyLevel = keyLevels[i];

      if(MathMax(swingHighs[0].price, swingHighs[1].price) >= keyLevel && keyLevel > prevClose) {
         Print("Strong reaction at key level: ", DoubleToString(keyLevel, _Digits));
         if(i - 1 >= 0) {
            Print("Next key level: ", DoubleToString(keyLevels[i - 1], _Digits));
            return true;
         } else {
            Print("No next key level found");
            return false;
         }
      }
   }

   // No key level met both conditions
   return false;
}

bool SwingLowsRejectingLevel(SwingPoint &swingLows[], double &keyLevels[], double prevClose) {
   // Check if we have at least 2 swing lows and 1 key level
   if(ArraySize(swingLows) < 2 || ArraySize(keyLevels) < 1) {
      return false;
   }

   // Loop through each key level
   for(int i = 0; i < ArraySize(keyLevels); i++) {
      double keyLevel = keyLevels[i];

      if(MathMin(swingLows[0].price, swingLows[1].price) <= keyLevel && prevClose > keyLevel) {
         Print("Strong reaction at key level: ", DoubleToString(keyLevel, _Digits));
         if(i + 1 < ArraySize(keyLevels)) {
            Print("Next key level: ", DoubleToString(keyLevels[i + 1], _Digits));
            return true;
         } else {
            Print("No next key level found");
            return false;
         }
      }
   }

   // No key level met both conditions
   return false;
}

int FilterFVG(FVG &fvgs[], int idx = 0) {
   if(!fvgs[idx].isFilled && fvgs[idx].gapSize >= MinGapSize * GetPipValue()) {
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check for entry signals                                          |
//+------------------------------------------------------------------+
TRADE_DIRECTION CheckForEntrySignals() {
   double prevClose = iClose(_Symbol, PERIOD_CURRENT, 1);
   double prevHigh = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double prevLow = iLow(_Symbol, PERIOD_CURRENT, 1);
   bool aboveSMA = CheckIsAboveSMA(prevClose, SMA_Period);

   // LONG signal
   if(ArraySize(state.swingLows) > 0 && aboveSMA && ArraySize(state.bullishFVGs) > 0) {
      if(ArraySize(state.bullishFVGs) >= 1 && FilterFVG(state.bullishFVGs)) {
         Print("Found at least 1 valid bullish FVG");
         if(SwingLowsRejectingLevel(state.swingLows, state.keyLevels, prevClose)) {
            Print("Found swing lows rejecting key level");
            if(prevLow > state.bullishFVGs[0].low && prevLow < state.bullishFVGs[0].high && prevClose > state.bullishFVGs[0].high && prevClose > prevLow) {
               Print("Price is inside bullish FVGs");
               return LONG;
            }
         }
      }
   }

   // SHORT signal
   if(ArraySize(state.swingHighs) > 0 && !aboveSMA && ArraySize(state.bearishFVGs) > 0) {
      if(ArraySize(state.bearishFVGs) >= 1 && FilterFVG(state.bearishFVGs)) {
         Print("Found at least 1 valid bearish FVG");
         if(SwingHighsRejectingLevel(state.swingHighs, state.keyLevels, prevClose)) {
            Print("Found swing highs rejecting key level");
            if(prevHigh < state.bearishFVGs[0].low && prevHigh > state.bearishFVGs[0].high && prevClose < state.bearishFVGs[0].high && prevClose < prevHigh) {
               Print("Price is inside bearish FVGs");
               return SHORT;
            }
         }
      }
   }

   return NO_DIRECTION;
}

//+------------------------------------------------------------------+
//| Execute trade based on signal                                    |
//+------------------------------------------------------------------+
void ExecuteTradeSignal(TRADE_DIRECTION signal) {
   // Check trading conditions
   if(!IsNYHour() || !AccountRiskValid() || signal == NO_DIRECTION || !IsTradingAllowedByNews() ) {
      Print("Trading conditions not met: ",
            IsNYHour() ? "In NY hour" : "NOT in NY hour", ", ",
            AccountRiskValid() ? "Account risk valid" : "Account risk NOT valid", ", ",
            IsTradingAllowedByNews() ? "News trading allowed" : "News trading NOT allowed");
      return;
   }

   double entryPrice, stopLoss, takeProfit, lotSize;
   double highestSwingLow, lowestFVGCandleLow, lowestSwingHigh, highestFVGCandleHigh;

   switch(signal) {
      case LONG:
         Print("Executing LONG signal");

         // Calculate trade parameters
         entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         highestSwingLow = MathMax(state.swingLows[0].price, state.swingLows[1].price);
         lowestFVGCandleLow = MathMin(iLow(_Symbol, PERIOD_CURRENT, state.bullishFVGs[0].bar), iLow(_Symbol, PERIOD_CURRENT, state.bullishFVGs[0].bar + 1));
         stopLoss = lowestFVGCandleLow - (BufferPips * GetPipValue());
         takeProfit = CalculateTpPrice(entryPrice, stopLoss, MinRRR);
         lotSize = CalculateLotSize(RiskDollars, entryPrice, stopLoss, true);

         // Store entry price for position management
         state.entryPrice = entryPrice;
         state.stopLoss = stopLoss;

         // Execute buy order
         if(!trade.Buy(lotSize, _Symbol, 0, stopLoss, takeProfit, "NY-BUY")) {
            Print("Failed to place buy order. Error: ", GetLastError());
         } else {
            Print("Buy order placed successfully.");
         }
         break;

      case SHORT:
         Print("Executing SHORT signal");

         // Calculate trade parameters
         entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         lowestSwingHigh = MathMin(state.swingHighs[0].price, state.swingHighs[1].price);
         highestFVGCandleHigh = MathMax(iHigh(_Symbol, PERIOD_CURRENT, state.bearishFVGs[0].bar), iHigh(_Symbol, PERIOD_CURRENT, state.bearishFVGs[0].bar + 1));
         stopLoss = highestFVGCandleHigh + (BufferPips * GetPipValue());
         takeProfit = CalculateTpPrice(entryPrice, stopLoss, MinRRR);
         lotSize = CalculateLotSize(RiskDollars, entryPrice, stopLoss, true);

         // Store entry price for position management
         state.entryPrice = entryPrice;
         state.stopLoss = stopLoss;

         // Execute sell order
         if(!trade.Sell(lotSize, _Symbol, 0, stopLoss, takeProfit, "NY-SELL")) {
            Print("Failed to place sell order. Error: ", GetLastError());
         } else {
            Print("Sell order placed successfully.");
         }
         break;

      case NO_DIRECTION:
         // No action needed
         break;
   }
}

//+------------------------------------------------------------------+
//| Manage existing positions                                        |
//+------------------------------------------------------------------+
void ManagePositions() {
   if(UseBreakeven) {
      MoveSymbolStopLossToBreakeven(state.beRRR);
   }

   for(int i = 0; i < PositionsTotal(); i++) {
      ulong ticket = PositionGetTicket(i);
      if(ticket != 0 && PositionGetString(POSITION_SYMBOL) == _Symbol) {
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double prevClose = iClose(_Symbol, PERIOD_CURRENT, 1);
         double prevHigh = iHigh(_Symbol, PERIOD_CURRENT, 1);
         double prevLow = iLow(_Symbol, PERIOD_CURRENT, 1);
         double currentPrice = (posType == POSITION_TYPE_BUY) ?
                               SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                               SymbolInfoDouble(_Symbol, SYMBOL_ASK);

         // close in profit if candle close below SMA or below swing low and current price is below previous low
         if(posType == POSITION_TYPE_BUY) {
            if(currentPrice > openPrice && currentPrice < prevLow && (prevClose < state.swingLows[0].price || !CheckIsAboveSMA(prevClose, SMA_Period))) {
               if(!trade.PositionClose(ticket)) {
                  Print("Failed to close long position. Error: ", GetLastError());
               } else {
                  Print("Long position closed successfully. Ticket: ", ticket);
               }
            }
         }

         // close in profit if candle close above SMA or above swing high
         if(posType == POSITION_TYPE_SELL) {
            if(currentPrice < openPrice  && currentPrice > prevHigh && (prevClose > state.swingHighs[0].price || CheckIsAboveSMA(prevClose, SMA_Period))) {
               if(!trade.PositionClose(ticket)) {
                  Print("Failed to close long position. Error: ", GetLastError());
               } else {
                  Print("Long position closed successfully. Ticket: ", ticket);
               }
            }
         }
      }
   }
}
