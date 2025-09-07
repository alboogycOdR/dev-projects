//+------------------------------------------------------------------+
//|                                                SB-Strategy-1.mq5 |
//|                        Copyright 2025, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Smart Breakout Strategy with Opening Range and FVG confirmation"
#property strict

//--- Include necessary helpers
#include <Helpers\GetRange.mqh>
#include <Helpers\GetSwingHighLows.mqh>
#include <Helpers\GetFVGs.mqh>
#include <Helpers\RiskManagement.mqh>
#include <Helpers\OrderManagement.mqh>
#include <Helpers\GetIndicators.mqh>
#include <Helpers\TextDisplay.mqh>
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
   TimeRange        ranges[];         // Opening range
   FVG              bullishFVGs[];    // Bullish fair value gaps
   FVG              bearishFVGs[];    // Bearish fair value gaps
   SwingPoint       swingHighs[];     // Swing high points
   SwingPoint       swingLows[];      // Swing low points
   string           biasDirection;    // Current bias direction
   int              lastRangeBarIndex;// Index of last range bar

   // Position management
   double           entryPrice;       // Entry price for position
   double           stopLoss;         // Stop loss price
   double           beRRR;            // Breakeven risk-reward ratio
   double           partialRRR;       // Partial take-profit risk-reward ratio
   bool             partialClosed;    // Partial position closed flag

   // Session management
   double           startDayBalance;  // Balance at start of trading day
   datetime         lastReset;        // Last reset datetime
   datetime         lastDisplayUpdate;  // Last display update time

   // Constructor with default values
   void StrategyState() {
      biasDirection = "";
      lastRangeBarIndex = 0;
      entryPrice = 0.0;
      stopLoss = 0.0;
      beRRR = 1.0;
      partialRRR = 1.0;
      partialClosed = false;
      startDayBalance = 0.0;
      lastReset = 0;
      lastDisplayUpdate = 0;
   }
};

//--- Global variables
StrategyState state;  // Main strategy state

//--- Input parameters
// Opening Range parameters
input string     ORStartTime = "16:30";       // Opening Range Start time (HH:MM)
input string     OREndTime = "17:00";         // Opening Range End time (HH:MM)
input int        startTradingHour = 17;       // Start trading hour (24h format)
input int        endTradingHour = 18;         // End trading hour (24h format)

// Market structure parameters
input bool       DrawOnChart = true;          // Draw ranges on chart
input int        MaxSwingPoints = 10;         // Number of swing points to identify
input int        MinFVGSearchRange = 10;      // Minimum bars to search for FVGs
input int        FVGLookBackBars = 2;         // FVG lookback bars
input int        SMA_Period = 20;             // SMA period for trend confirmation
input double     BufferPips = 1.0;            // Buffer in pips for stop loss

// Money management parameters
input double     RiskDollars = 100.0;         // Risk in dollars per trade
input double     MinRRR = 1.0;                // Minimum risk to reward ratio
input double     MaxDailyLoss = 200;          // Maximum daily loss in account currency
input double     DailyTarget = 200;           // Daily target in account currency

// Position management parameters
input bool       UseBreakeven = true;         // Move to breakeven
input double     BeRRR = 1.0;                 // Risk-reward ratio for breakeven
input bool       UsePartialProfit = true;     // Take partial profit
input double     PartialRRR = 1.0;            // Risk-reward ratio for partial profit
input double     PartialPercent = 0.5;        // Percentage to close on partial

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
   EventSetTimer(60);

   // Initialize strategy state
   state.startDayBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   state.beRRR = BeRRR;
   state.partialRRR = PartialRRR;

   // Initialize display
   if(ShowTextOnChart) {
      clearTextDisplay();
      addTextOnScreen("SB-Strategy-1 initialized", InfoTextColor);
   }

   Print("SB-Strategy-1 initialized successfully");
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
      state.partialClosed = false; // Reset partial flag for the new day
      Print("New day detected. Starting Day balance reset to: ", DoubleToString(state.startDayBalance, 2));
   }

   // Update market structure elements and display
   UpdateMarketStructure();

   // Update display if interval has passed
   if(ShowTextOnChart && now - state.lastDisplayUpdate >= DisplayUpdateInterval) {
      UpdateDisplayInfo();
      state.lastDisplayUpdate = now;
   }

   // Detect opening range
   bool rangeFound = GetRanges(ORStartTime, OREndTime, state.ranges, 0, "OR", DrawOnChart, PERIOD_CURRENT);
   if(!rangeFound) return;

   state.lastRangeBarIndex = state.ranges[0].endBarIndex;
   state.biasDirection = state.ranges[0].type;

   // Find FVGs within the opening range scope
   GetBullishFVGs(FVGLookBackBars, state.ranges[0].startBarIndex, state.bullishFVGs, MinFVGSearchRange, DrawOnChart, clrGreenYellow, false);
   GetBearishFVGs(FVGLookBackBars, state.ranges[0].startBarIndex, state.bearishFVGs, MinFVGSearchRange, DrawOnChart, clrDeepPink, false);

   // Process trading logic
   if(!HasActivePositionsOrOrders()) {
      ExecuteTradeSignal(CheckForEntrySignals());
   } else {
      ManagePositions();
   }
}

//+------------------------------------------------------------------+
//| Update the display with current strategy info                    |
//+------------------------------------------------------------------+
void UpdateDisplayInfo() {
   clearTextDisplay();

   // Show basic strategy information
   addTextOnScreen("SB-Strategy-1 Status", InfoTextColor);

   // Show trading session info
   string tradeHoursMsg = "Trading Hours: " + IntegerToString(startTradingHour) + ":00 - " + IntegerToString(endTradingHour) + ":00";
   addTextOnScreen(tradeHoursMsg, InfoTextColor);

   // Show account info
   string accountMsg = "Account Balance: $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2);
   addTextOnScreen(accountMsg, InfoTextColor);

   // Show day P/L
   double dayPnL = AccountInfoDouble(ACCOUNT_BALANCE) - state.startDayBalance;
   string dayPnLMsg = "Day P/L: $" + DoubleToString(dayPnL, 2);
   color pnlColor = (dayPnL >= 0) ? PositiveCondColor : NegativeCondColor;
   addTextOnScreen(dayPnLMsg, pnlColor);

   // Show current trading conditions
   bool inSBHour = IsSBHour();
   bool riskValid = AccountRiskValid();
   string timeCondMsg = "Trading Hour: " + (inSBHour ? "YES" : "NO");
   string riskCondMsg = "Risk Valid: " + (riskValid ? "YES" : "NO");

   addTextOnScreen(timeCondMsg, inSBHour ? PositiveCondColor : NegativeCondColor);
   addTextOnScreen(riskCondMsg, riskValid ? PositiveCondColor : NegativeCondColor);

   // Show market structure
   if(ArraySize(state.ranges) > 0) {
      string orMsg = "OR Type: " + state.biasDirection;
      addTextOnScreen(orMsg, InfoTextColor);

      string rangeMsg = "OR High: " + DoubleToString(state.ranges[0].high, _Digits) +
                        " Mid: " + DoubleToString(state.ranges[0].middle, _Digits) +
                        " Low: " + DoubleToString(state.ranges[0].low, _Digits);
      addTextOnScreen(rangeMsg, InfoTextColor);
   }

   // Show current price vs. MA
   double prevClose = iClose(_Symbol, PERIOD_CURRENT, 1);
   bool aboveSMA = CheckIsAboveSMA(prevClose, SMA_Period);
   string maCondMsg = "Price vs SMA" + IntegerToString(SMA_Period) + ": " + (aboveSMA ? "ABOVE" : "BELOW");
   addTextOnScreen(maCondMsg, aboveSMA ? PositiveCondColor : NegativeCondColor);

   // Show FVG counts
   string fvgMsg = "FVGs: " + IntegerToString(ArraySize(state.bullishFVGs)) + " Bullish, " +
                   IntegerToString(ArraySize(state.bearishFVGs)) + " Bearish";
   addTextOnScreen(fvgMsg, InfoTextColor);

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

         // Calculate distance to BE in pips
         double pipsToBreakeven = 0;
         if(posType == POSITION_TYPE_BUY && openPrice > slPrice) {
            pipsToBreakeven = (openPrice - currentPrice) / GetPipValue();
         } else if(posType == POSITION_TYPE_SELL && openPrice < slPrice) {
            pipsToBreakeven = (currentPrice - openPrice) / GetPipValue();
         }

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

         // Profit and BE condition
         string profitMsg = "Profit: $" + DoubleToString(profit, 2);
         color profitColor = (profit >= 0) ? PositiveCondColor : NegativeCondColor;
         addTextOnScreen(profitMsg, profitColor);

         // BE condition
         string beCondMsg = "";
         if(UseBreakeven && !state.partialClosed) {
            beCondMsg = "BE Status: " + (pipsToBreakeven <= 0 ? "ACTIVE" :
                        DoubleToString(MathAbs(pipsToBreakeven), 1) + " pips away");
            addTextOnScreen(beCondMsg, (pipsToBreakeven <= 0) ? PositiveCondColor : InfoTextColor);
         }

         // Partial profit condition
         string partialMsg = "";
         if(UsePartialProfit) {
            partialMsg = "Partial Status: " + (state.partialClosed ? "TAKEN" : "WAITING");
            addTextOnScreen(partialMsg, state.partialClosed ? PositiveCondColor : InfoTextColor);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Show current signal conditions                                   |
//+------------------------------------------------------------------+
void ShowSignalConditions() {
   if(ArraySize(state.ranges) == 0) return;

   addTextOnScreen("=== SIGNAL CONDITIONS ===", InfoTextColor);

   double prevClose = iClose(_Symbol, PERIOD_CURRENT, 1);
   bool inSBHour = IsSBHour();
   bool riskValid = AccountRiskValid();
   bool tradingConditionsValid = inSBHour && riskValid;

   // Long conditions
   bool swingLowValid = (ArraySize(state.swingLows) > 0 && state.swingLows[0].bar < state.lastRangeBarIndex);
   bool aboveSMA = CheckIsAboveSMA(prevClose, SMA_Period);
   bool aboveMiddle = (prevClose > state.ranges[0].middle);
   bool hasBullishFVGs = (ArraySize(state.bullishFVGs) > 0);

   string longCondMsg = "LONG Signal Conditions:";
   addTextOnScreen(longCondMsg, InfoTextColor);

   string swingLowMsg = "- Swing Low After OR: " + (swingLowValid ? "YES" : "NO");
   string aboveSMAMsg = "- Price Above SMA" + IntegerToString(SMA_Period) + ": " + (aboveSMA ? "YES" : "NO");
   string aboveMiddleMsg = "- Price Above OR Middle: " + (aboveMiddle ? "YES" : "NO");
   string bullishFVGMsg = "- Bullish FVGs Present: " + (hasBullishFVGs ? "YES" : "NO");

   addTextOnScreen(swingLowMsg, swingLowValid ? PositiveCondColor : NegativeCondColor);
   addTextOnScreen(aboveSMAMsg, aboveSMA ? PositiveCondColor : NegativeCondColor);
   addTextOnScreen(aboveMiddleMsg, aboveMiddle ? PositiveCondColor : NegativeCondColor);
   addTextOnScreen(bullishFVGMsg, hasBullishFVGs ? PositiveCondColor : NegativeCondColor);

   // Short conditions
   bool swingHighValid = (ArraySize(state.swingHighs) > 0 && state.swingHighs[0].bar < state.lastRangeBarIndex);
   bool belowSMA = !aboveSMA;
   bool belowMiddle = (prevClose < state.ranges[0].middle);
   bool hasBearishFVGs = (ArraySize(state.bearishFVGs) > 0);

   string shortCondMsg = "SHORT Signal Conditions:";
   addTextOnScreen(shortCondMsg, InfoTextColor);

   string swingHighMsg = "- Swing High After OR: " + (swingHighValid ? "YES" : "NO");
   string belowSMAMsg = "- Price Below SMA" + IntegerToString(SMA_Period) + ": " + (belowSMA ? "YES" : "NO");
   string belowMiddleMsg = "- Price Below OR Middle: " + (belowMiddle ? "YES" : "NO");
   string bearishFVGMsg = "- Bearish FVGs Present: " + (hasBearishFVGs ? "YES" : "NO");

   addTextOnScreen(swingHighMsg, swingHighValid ? PositiveCondColor : NegativeCondColor);
   addTextOnScreen(belowSMAMsg, belowSMA ? PositiveCondColor : NegativeCondColor);
   addTextOnScreen(belowMiddleMsg, belowMiddle ? PositiveCondColor : NegativeCondColor);
   addTextOnScreen(bearishFVGMsg, hasBearishFVGs ? PositiveCondColor : NegativeCondColor);

   // Overall signal status
   bool longSignalValid = swingLowValid && aboveSMA && aboveMiddle && hasBullishFVGs && tradingConditionsValid;
   bool shortSignalValid = swingHighValid && belowSMA && belowMiddle && hasBearishFVGs && tradingConditionsValid;

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
bool IsSBHour() {
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);

   return (dt.hour >= startTradingHour && dt.hour < endTradingHour);
}

//+------------------------------------------------------------------+
//| Check account risk conditions                                    |
//+------------------------------------------------------------------+
bool AccountRiskValid() {
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double dayPnL = currentBalance - state.startDayBalance;

   // Check if daily loss is exceeded (negative dayPnL beyond the limit)
   bool lossExceeded = (dayPnL <= -MaxDailyLoss);

   // Check if daily target is reached (positive dayPnL reaching the target)
   bool targetReached = (dayPnL >= DailyTarget);

   // Debug output
   if(lossExceeded) Print("Daily loss limit exceeded: $", DoubleToString(dayPnL, 2));
   if(targetReached) Print("Daily profit target reached: $", DoubleToString(dayPnL, 2));

   // Return valid if neither condition is true
   return !(lossExceeded || targetReached);
}

//+------------------------------------------------------------------+
//| Check for entry signals                                          |
//+------------------------------------------------------------------+
TRADE_DIRECTION CheckForEntrySignals() {
   double prevClose = iClose(_Symbol, PERIOD_CURRENT, 1);
   bool aboveSMA = CheckIsAboveSMA(prevClose, SMA_Period);

   // LONG signal
   if(ArraySize(state.swingLows) > 0 &&
      state.swingLows[0].bar < state.lastRangeBarIndex &&
      aboveSMA &&
      prevClose > state.ranges[0].middle &&
      ArraySize(state.bullishFVGs) > 0) {
      return LONG;
   }

   // SHORT signal
   if(ArraySize(state.swingHighs) > 0 &&
      state.swingHighs[0].bar < state.lastRangeBarIndex &&
      !aboveSMA &&
      prevClose < state.ranges[0].middle &&
      ArraySize(state.bearishFVGs) > 0) {
      return SHORT;
   }

   return NO_DIRECTION;
}

//+------------------------------------------------------------------+
//| Execute trade based on signal                                    |
//+------------------------------------------------------------------+
void ExecuteTradeSignal(TRADE_DIRECTION signal) {
   // Check trading conditions
   if(!IsSBHour() || !AccountRiskValid() || signal == NO_DIRECTION) {
      Print("Trading conditions not met: ",
            IsSBHour() ? "In SB hour" : "Not in SB hour", ", ",
            AccountRiskValid() ? "Account risk valid" : "Account risk invalid");
      return;
   }

   double entryPrice, stopLoss, takeProfit, lotSize;

   switch(signal) {
      case LONG:
         Print("Executing LONG signal");

         // Calculate trade parameters
         entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         stopLoss = state.ranges[0].middle - (BufferPips * GetPipValue());
         takeProfit = CalculateTpPrice(entryPrice, stopLoss, MinRRR);
         lotSize = CalculateLotSize(RiskDollars, entryPrice, stopLoss, true);

         // Store entry price for position management
         state.entryPrice = entryPrice;
         state.stopLoss = stopLoss;
         state.partialClosed = false;

         // Execute buy order
         if(!trade.Buy(lotSize, _Symbol, 0, stopLoss, takeProfit, "OR-BUY")) {
            Print("Failed to place buy order. Error: ", GetLastError());
         } else {
            Print("Buy order placed successfully.");
         }
         break;

      case SHORT:
         Print("Executing SHORT signal");

         // Calculate trade parameters
         entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         stopLoss = state.ranges[0].middle + (BufferPips * GetPipValue());
         takeProfit = CalculateTpPrice(entryPrice, stopLoss, MinRRR);
         lotSize = CalculateLotSize(RiskDollars, entryPrice, stopLoss, true);

         // Store entry price for position management
         state.entryPrice = entryPrice;
         state.stopLoss = stopLoss;
         state.partialClosed = false;

         // Execute sell order
         if(!trade.Sell(lotSize, _Symbol, 0, stopLoss, takeProfit, "OR-SELL")) {
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
   // Move to breakeven if condition met
   if(UseBreakeven) {
      MoveSymbolStopLossToBreakeven(state.beRRR);
   }

   // Take partial profit if condition met and not already taken
   if(UsePartialProfit && !state.partialClosed) {
      state.partialClosed = TakePartialProfit(state.partialRRR, PartialPercent);
      if(state.partialClosed) {
         Print("Partial profit taken");
      }
   }
}
