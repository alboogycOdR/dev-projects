//+------------------------------------------------------------------+
//|                        Copyright 2025, Forex Algo-Trader, Allan. |
//|                                 "https://t.me/Forex_Algo_Trader" |
//+------------------------------------------------------------------+
#property copyright "Forex Algo-Trader, Allan"
#property link      "https://t.me/Forex_Algo_Trader"
#property version   "1.00"
#property description "This EA trades based on Mitigation Order Blocks Strategy"
#property strict
//https://www.mql5.com/en/articles/17547
//--- Include the trade library for managing positions
#include <Trade/Trade.mqh>
CTrade obj_Trade;

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input double tradeLotSize = 0.01;           // Trade size for each position
input bool enableTrading = true;            // Toggle to allow or disable trading
input bool enableTrailingStop = true;       // Toggle to enable or disable trailing stop
input double trailingStopPoints = 30;       // Distance in points for trailing stop
input double minProfitToTrail = 50;         // Minimum profit in points before trailing starts (not used yet)
input int uniqueMagicNumber = 12345;        // Unique identifier for EA trades
input int consolidationBars = 7;            // Number of bars to check for consolidation
input double maxConsolidationSpread = 50;   // Maximum allowed spread in points for consolidation
input int barsToWaitAfterBreakout = 3;      // Bars to wait after breakout before checking impulse
input double impulseMultiplier = 1.0;       // Multiplier for detecting impulsive moves
input double stopLossDistance = 1500;       // Stop loss distance in points
input double takeProfitDistance = 1500;     // Take profit distance in points
input color bullishOrderBlockColor = clrGreen;    // Color for bullish order blocks
input color bearishOrderBlockColor = clrRed;     // Color for bearish order blocks
input color mitigatedOrderBlockColor = clrGray;  // Color for mitigated order blocks
input color labelTextColor = clrBlack;           // Color for text labels

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   //--- Set the magic number for the trade object to identify EA trades
   obj_Trade.SetExpertMagicNumber(uniqueMagicNumber);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   //--- Nothing to clean up yet, but kept for future use
}

//--- Struct to store price and index for highs and lows
struct PriceAndIndex {
   double price;  // Price value
   int    index;  // Bar index where this price occurs
};

//--- Global variables for tracking market state
PriceAndIndex rangeHighestHigh = {0, 0};    // Highest high in the consolidation range
PriceAndIndex rangeLowestLow = {0, 0};      // Lowest low in the consolidation range
bool isBreakoutDetected = false;            // Flag for when a breakout occurs
double lastImpulseLow = 0.0;                // Low price after breakout for impulse check
double lastImpulseHigh = 0.0;               // High price after breakout for impulse check
int breakoutBarNumber = -1;                 // Bar index where breakout happened
datetime breakoutTimestamp = 0;             // Time of the breakout
string orderBlockNames[];                   // Array of order block object names
datetime orderBlockEndTimes[];              // Array of order block end times
bool orderBlockMitigatedStatus[];           // Array tracking if order blocks are mitigated
bool isBullishImpulse = false;              // Flag for bullish impulsive move
bool isBearishImpulse = false;              // Flag for bearish impulsive move

#define OB_Prefix "OB REC "     // Prefix for order block object names

//+------------------------------------------------------------------+
//| Expert OnTick function                                           |
//+------------------------------------------------------------------+
void OnTick() {
   //--- Apply trailing stop to open positions if enabled
   if (enableTrailingStop) {
      applyTrailingStop(trailingStopPoints, obj_Trade, uniqueMagicNumber);
   }

   //--- Check for a new bar to process logic only once per bar
   static bool isNewBar = false;
   int currentBarCount = iBars(_Symbol, _Period);
   static int previousBarCount = currentBarCount;
   if (previousBarCount == currentBarCount) {
      isNewBar = false;
   } else if (previousBarCount != currentBarCount) {
      isNewBar = true;
      previousBarCount = currentBarCount;
   }

   //--- Exit if not a new bar to avoid redundant processing
   if (!isNewBar)
      return;

   //--- Define the starting bar index for consolidation checks
   int startBarIndex = 1;

   //--- Calculate dynamic font size based on chart scale (0 = zoomed out, 5 = zoomed in)
   int chartScale = (int)ChartGetInteger(0, CHART_SCALE); // Scale ranges from 0 to 5
   int dynamicFontSize = 8 + (chartScale * 2);           // Font size: 8 (min) to 18 (max)

   //--- Check for consolidation or extend the existing range
   if (!isBreakoutDetected) {
      if (rangeHighestHigh.price == 0 && rangeLowestLow.price == 0) {
         //--- Check if bars are in a tight consolidation range
         bool isConsolidated = true;
         for (int i = startBarIndex; i < startBarIndex + consolidationBars - 1; i++) {
            if (MathAbs(high(i) - high(i + 1)) > maxConsolidationSpread * Point()) {
               isConsolidated = false;
               break;
            }
            if (MathAbs(low(i) - low(i + 1)) > maxConsolidationSpread * Point()) {
               isConsolidated = false;
               break;
            }
         }
         if (isConsolidated) {
            //--- Find the highest high in the consolidation range
            rangeHighestHigh.price = high(startBarIndex);
            rangeHighestHigh.index = startBarIndex;
            for (int i = startBarIndex + 1; i < startBarIndex + consolidationBars; i++) {
               if (high(i) > rangeHighestHigh.price) {
                  rangeHighestHigh.price = high(i);
                  rangeHighestHigh.index = i;
               }
            }
            //--- Find the lowest low in the consolidation range
            rangeLowestLow.price = low(startBarIndex);
            rangeLowestLow.index = startBarIndex;
            for (int i = startBarIndex + 1; i < startBarIndex + consolidationBars; i++) {
               if (low(i) < rangeLowestLow.price) {
                  rangeLowestLow.price = low(i);
                  rangeLowestLow.index = i;
               }
            }
            //--- Log the established consolidation range
            Print("Consolidation range established: Highest High = ", rangeHighestHigh.price,
                  " at index ", rangeHighestHigh.index,
                  " and Lowest Low = ", rangeLowestLow.price,
                  " at index ", rangeLowestLow.index);
         }
      } else {
         //--- Check if the current bar extends the existing range
         double currentHigh = high(1);
         double currentLow = low(1);
         if (currentHigh <= rangeHighestHigh.price && currentLow >= rangeLowestLow.price) {
            Print("Range extended: High = ", currentHigh, ", Low = ", currentLow);
         } else {
            Print("No extension: Bar outside range.");
         }
      }
   }

   //--- Detect a breakout from the consolidation range
   if (rangeHighestHigh.price > 0 && rangeLowestLow.price > 0) {
      double currentClosePrice = close(1);
      if (currentClosePrice > rangeHighestHigh.price) {
         Print("Upward breakout at ", currentClosePrice, " > ", rangeHighestHigh.price);
         isBreakoutDetected = true;
      } else if (currentClosePrice < rangeLowestLow.price) {
         Print("Downward breakout at ", currentClosePrice, " < ", rangeLowestLow.price);
         isBreakoutDetected = true;
      }
   }

   //--- Reset state after a breakout is detected
   if (isBreakoutDetected) {
      Print("Breakout detected. Resetting for the next range.");
      breakoutBarNumber = 1;
      breakoutTimestamp = TimeCurrent();
      lastImpulseHigh = rangeHighestHigh.price;
      lastImpulseLow = rangeLowestLow.price;

      isBreakoutDetected = false;
      rangeHighestHigh.price = 0;
      rangeHighestHigh.index = 0;
      rangeLowestLow.price = 0;
      rangeLowestLow.index = 0;
   }

   //--- Check for impulsive movement after breakout and create order blocks
   if (breakoutBarNumber >= 0 && TimeCurrent() > breakoutTimestamp + barsToWaitAfterBreakout * PeriodSeconds()) {
      double impulseRange = lastImpulseHigh - lastImpulseLow;
      double impulseThresholdPrice = impulseRange * impulseMultiplier;
      isBullishImpulse = false;
      isBearishImpulse = false;
      for (int i = 1; i <= barsToWaitAfterBreakout; i++) {
         double closePrice = close(i);
         if (closePrice >= lastImpulseHigh + impulseThresholdPrice) {
            isBullishImpulse = true;
            Print("Impulsive upward move: ", closePrice, " >= ", lastImpulseHigh + impulseThresholdPrice);
            break;
         } else if (closePrice <= lastImpulseLow - impulseThresholdPrice) {
            isBearishImpulse = true;
            Print("Impulsive downward move: ", closePrice, " <= ", lastImpulseLow - impulseThresholdPrice);
            break;
         }
      }
      if (!isBullishImpulse && !isBearishImpulse) {
         Print("No impulsive movement detected.");
      }

      bool isOrderBlockValid = isBearishImpulse || isBullishImpulse;

      if (isOrderBlockValid) {
         datetime blockStartTime = iTime(_Symbol, _Period, consolidationBars + barsToWaitAfterBreakout + 1);
         double blockTopPrice = lastImpulseHigh;
         int visibleBarsOnChart = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
         datetime blockEndTime = blockStartTime + (visibleBarsOnChart / 1) * PeriodSeconds();
         double blockBottomPrice = lastImpulseLow;
         string orderBlockName = OB_Prefix + "(" + TimeToString(blockStartTime) + ")";
         color orderBlockColor = isBullishImpulse ? bullishOrderBlockColor : bearishOrderBlockColor;
         string orderBlockLabel = isBullishImpulse ? "Bullish OB" : "Bearish OB";

         if (ObjectFind(0, orderBlockName) < 0) {
            //--- Create a rectangle for the order block
            ObjectCreate(0, orderBlockName, OBJ_RECTANGLE, 0, blockStartTime, blockTopPrice, blockEndTime, blockBottomPrice);
            ObjectSetInteger(0, orderBlockName, OBJPROP_TIME, 0, blockStartTime);
            ObjectSetDouble(0, orderBlockName, OBJPROP_PRICE, 0, blockTopPrice);
            ObjectSetInteger(0, orderBlockName, OBJPROP_TIME, 1, blockEndTime);
            ObjectSetDouble(0, orderBlockName, OBJPROP_PRICE, 1, blockBottomPrice);
            ObjectSetInteger(0, orderBlockName, OBJPROP_FILL, true);
            ObjectSetInteger(0, orderBlockName, OBJPROP_COLOR, orderBlockColor);
            ObjectSetInteger(0, orderBlockName, OBJPROP_BACK, false);

            //--- Add a text label in the middle of the order block with dynamic font size
            datetime labelTime = blockStartTime + (blockEndTime - blockStartTime) / 2;
            double labelPrice = (blockTopPrice + blockBottomPrice) / 2;
            string labelObjectName = orderBlockName + orderBlockLabel;
            if (ObjectFind(0, labelObjectName) < 0) {
               ObjectCreate(0, labelObjectName, OBJ_TEXT, 0, labelTime, labelPrice);
               ObjectSetString(0, labelObjectName, OBJPROP_TEXT, orderBlockLabel);
               ObjectSetInteger(0, labelObjectName, OBJPROP_COLOR, labelTextColor);
               ObjectSetInteger(0, labelObjectName, OBJPROP_FONTSIZE, dynamicFontSize);
               ObjectSetInteger(0, labelObjectName, OBJPROP_ANCHOR, ANCHOR_CENTER);
            }
            ChartRedraw(0);

            //--- Store the order block details in arrays
            ArrayResize(orderBlockNames, ArraySize(orderBlockNames) + 1);
            orderBlockNames[ArraySize(orderBlockNames) - 1] = orderBlockName;
            ArrayResize(orderBlockEndTimes, ArraySize(orderBlockEndTimes) + 1);
            orderBlockEndTimes[ArraySize(orderBlockEndTimes) - 1] = blockEndTime;
            ArrayResize(orderBlockMitigatedStatus, ArraySize(orderBlockMitigatedStatus) + 1);
            orderBlockMitigatedStatus[ArraySize(orderBlockMitigatedStatus) - 1] = false;

            Print("Order Block created: ", orderBlockName);
         }
      }

      //--- Reset breakout tracking variables
      breakoutBarNumber = -1;
      breakoutTimestamp = 0;
      lastImpulseHigh = 0;
      lastImpulseLow = 0;
      isBullishImpulse = false;
      isBearishImpulse = false;
   }

   //--- Process existing order blocks for mitigation and trading
   for (int j = ArraySize(orderBlockNames) - 1; j >= 0; j--) {
      string currentOrderBlockName = orderBlockNames[j];
      bool doesOrderBlockExist = false;

      //--- Retrieve order block properties
      double orderBlockHigh = ObjectGetDouble(0, currentOrderBlockName, OBJPROP_PRICE, 0);
      double orderBlockLow = ObjectGetDouble(0, currentOrderBlockName, OBJPROP_PRICE, 1);
      datetime orderBlockStartTime = (datetime)ObjectGetInteger(0, currentOrderBlockName, OBJPROP_TIME, 0);
      datetime orderBlockEndTime = (datetime)ObjectGetInteger(0, currentOrderBlockName, OBJPROP_TIME, 1);
      color orderBlockCurrentColor = (color)ObjectGetInteger(0, currentOrderBlockName, OBJPROP_COLOR);

      //--- Check if the order block is still valid (not expired)
      if (time(1) < orderBlockEndTime) {
         doesOrderBlockExist = true;
      }

      //--- Get current market prices
      double currentAskPrice = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
      double currentBidPrice = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);

      //--- Check for mitigation and execute trades if trading is enabled
      if (enableTrading && orderBlockCurrentColor == bullishOrderBlockColor && close(1) < orderBlockLow && !orderBlockMitigatedStatus[j]) {
         //--- Sell trade when price breaks below a bullish order block
         double entryPrice = currentBidPrice;
         double stopLossPrice = entryPrice + stopLossDistance * _Point;
         double takeProfitPrice = entryPrice - takeProfitDistance * _Point;
         obj_Trade.Sell(tradeLotSize, _Symbol, entryPrice, stopLossPrice, takeProfitPrice);
         orderBlockMitigatedStatus[j] = true;
         ObjectSetInteger(0, currentOrderBlockName, OBJPROP_COLOR, mitigatedOrderBlockColor);
         string blockDescription = "Bullish Order Block";
         string textObjectName = currentOrderBlockName + blockDescription;
         if (ObjectFind(0, textObjectName) >= 0) {
            ObjectSetString(0, textObjectName, OBJPROP_TEXT, "Mitigated " + blockDescription);
         }
         Print("Sell trade entered upon mitigation of bullish OB: ", currentOrderBlockName);
      } else if (enableTrading && orderBlockCurrentColor == bearishOrderBlockColor && close(1) > orderBlockHigh && !orderBlockMitigatedStatus[j]) {
         //--- Buy trade when price breaks above a bearish order block
         double entryPrice = currentAskPrice;
         double stopLossPrice = entryPrice - stopLossDistance * _Point;
         double takeProfitPrice = entryPrice + takeProfitDistance * _Point;
         obj_Trade.Buy(tradeLotSize, _Symbol, entryPrice, stopLossPrice, takeProfitPrice);
         orderBlockMitigatedStatus[j] = true;
         ObjectSetInteger(0, currentOrderBlockName, OBJPROP_COLOR, mitigatedOrderBlockColor);
         string blockDescription = "Bearish Order Block";
         string textObjectName = currentOrderBlockName + blockDescription;
         if (ObjectFind(0, textObjectName) >= 0) {
            ObjectSetString(0, textObjectName, OBJPROP_TEXT, "Mitigated " + blockDescription);
         }
         Print("Buy trade entered upon mitigation of bearish OB: ", currentOrderBlockName);
      }

      //--- Remove expired order blocks from arrays
      if (!doesOrderBlockExist) {
         bool removedName = ArrayRemove(orderBlockNames, j, 1);
         bool removedTime = ArrayRemove(orderBlockEndTimes, j, 1);
         bool removedStatus = ArrayRemove(orderBlockMitigatedStatus, j, 1);
         if (removedName && removedTime && removedStatus) {
            Print("Success removing OB DATA from arrays at index ", j);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Price data accessors (kept as necessary functions)               |
//+------------------------------------------------------------------+
double high(int index) { return iHigh(_Symbol, _Period, index); }   //--- Get high price of a bar
double low(int index) { return iLow(_Symbol, _Period, index); }     //--- Get low price of a bar
double open(int index) { return iOpen(_Symbol, _Period, index); }   //--- Get open price of a bar
double close(int index) { return iClose(_Symbol, _Period, index); } //--- Get close price of a bar
datetime time(int index) { return iTime(_Symbol, _Period, index); } //--- Get time of a bar

//+------------------------------------------------------------------+
//| Trailing stop function                                           |
//+------------------------------------------------------------------+
void applyTrailingStop(double trailingPoints, CTrade &trade_object, int magicNo = 0) {
   //--- Calculate trailing stop levels based on current market prices
   double buyStopLoss = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID) - trailingPoints * _Point, _Digits);
   double sellStopLoss = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK) + trailingPoints * _Point, _Digits);
   
   //--- Loop through all open positions
   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if (ticket > 0) {
         if (PositionGetString(POSITION_SYMBOL) == _Symbol && 
             (magicNo == 0 || PositionGetInteger(POSITION_MAGIC) == magicNo)) {
            //--- Adjust stop loss for buy positions
            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && 
                buyStopLoss > PositionGetDouble(POSITION_PRICE_OPEN) && 
                (buyStopLoss > PositionGetDouble(POSITION_SL) || PositionGetDouble(POSITION_SL) == 0)) {
               trade_object.PositionModify(ticket, buyStopLoss, PositionGetDouble(POSITION_TP));
            } 
            //--- Adjust stop loss for sell positions
            else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && 
                       sellStopLoss < PositionGetDouble(POSITION_PRICE_OPEN) && 
                       (sellStopLoss < PositionGetDouble(POSITION_SL) || PositionGetDouble(POSITION_SL) == 0)) {
               trade_object.PositionModify(ticket, sellStopLoss, PositionGetDouble(POSITION_TP));
            }
         }
      }
   }
}