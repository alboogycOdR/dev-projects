//+------------------------------------------------------------------+
//|                        Copyright 2025, Forex Algo-Trader, Allan. |
//|                                 "https://t.me/Forex_Algo_Trader" |
//+------------------------------------------------------------------+
#property copyright "Forex Algo-Trader, Allan (SMC Liquidity Mod)"
#property link      "https://t.me/Forex_Algo_Trader"
#property version   "1.10" // Version updated
#property description "This EA trades SMC setups: Liquidity grab beyond OB + reversal into OB"
#property strict

//--- Include the trade library for managing positions
#include <Trade/Trade.mqh>
CTrade obj_Trade;

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "Trading Setup"
input double tradeLotSize = 0.01;           // Trade size for each position
input bool enableTrading = true;            // Toggle to allow or disable trading
input int uniqueMagicNumber = 12346;        // Unique identifier for EA trades (Changed)

input group "Order Block Identification"
input int consolidationBars = 7;            // Number of bars to check for consolidation
input double maxConsolidationSpread = 50;   // Maximum allowed spread in points for consolidation
input int barsToWaitAfterBreakout = 3;      // Bars to wait after breakout before checking impulse
input double impulseMultiplier = 1.0;       // Multiplier for detecting impulsive moves (still used for OB validation)

input group "SMC Liquidity & Entry"
input int    ATR_Period = 14;               // ATR period for liquidity zone calculation
input double ATR_Multiplier = 0.5;          // ATR multiplier for liquidity zone size (k)
input double stopLossBufferPips = 5;        // Extra pips buffer for Stop Loss placement
input double takeProfitRR = 2.0;            // Risk:Reward Ratio for Take Profit calculation

input group "Visualization"
input color bullishOrderBlockColor = clrDodgerBlue;   // Color for bullish order blocks (Changed for clarity)
input color bearishOrderBlockColor = clrTomato;     // Color for bearish order blocks (Changed for clarity)
input color tradedBullishColor = clrMediumSeaGreen; // Color for traded bullish order blocks
input color tradedBearishColor = clrOrangeRed;    // Color for traded bearish order blocks
input color labelTextColor = clrBlack;           // Color for text labels

input group "Trailing Stop (Optional)"
input bool enableTrailingStop = true;       // Toggle to enable or disable trailing stop
input double trailingStopPoints = 30;       // Distance in points for trailing stop

//--- Global variables for indicator handles
int atrHandle = INVALID_HANDLE;

//--- Struct to store price and index for highs and lows
struct PriceAndIndex {
   double price;  // Price value
   int    index;  // Bar index where this price occurs
};

//--- Global variables for tracking market state
PriceAndIndex rangeHighestHigh = {0, 0};    // Highest high in the consolidation range
PriceAndIndex rangeLowestLow = {0, 0};      // Lowest low in the consolidation range
bool isBreakoutDetected = false;            // Flag for when a breakout occurs
double lastImpulseLow = 0.0;                // Low price after breakout for impulse check (used for OB creation)
double lastImpulseHigh = 0.0;               // High price after breakout for impulse check (used for OB creation)
int breakoutBarNumber = -1;                 // Bar index where breakout happened
datetime breakoutTimestamp = 0;             // Time of the breakout
string orderBlockNames[];                   // Array of order block object names
datetime orderBlockEndTimes[];              // Array of order block end times
bool orderBlockTradedStatus[];              // << RENAMED: Array tracking if order blocks have been traded based on the NEW SMC logic
bool isBullishImpulse = false;              // Flag for bullish impulsive move (for OB creation)
bool isBearishImpulse = false;              // Flag for bearish impulsive move (for OB creation)

#define OB_Prefix "OB_SMC_"     // Prefix for order block object names (Changed)

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   //--- Set the magic number for the trade object to identify EA trades
   obj_Trade.SetExpertMagicNumber(uniqueMagicNumber);

   //--- Initialize ATR indicator handle
   atrHandle = iATR(_Symbol, _Period, ATR_Period);
   if(atrHandle == INVALID_HANDLE) {
      Print("Error creating ATR indicator: ", GetLastError());
      return(INIT_FAILED);
   }

   // Ensure array sizes are initialized (important if EA is reloaded)
   ArrayResize(orderBlockNames, 0);
   ArrayResize(orderBlockEndTimes, 0);
   ArrayResize(orderBlockTradedStatus, 0); // Renamed array

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   //--- Release indicator handles
   if(atrHandle != INVALID_HANDLE) {
      IndicatorRelease(atrHandle);
   }
   //--- Clean up chart objects (optional, based on preference)
   // ObjectsDeleteAll(0, OB_Prefix); // Uncomment to remove all OBs on deinit
   Print("EA Deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Get ATR value                                                    |
//+------------------------------------------------------------------+
double GetATR(int shift = 1) // Default to previous completed bar
{
   if(atrHandle == INVALID_HANDLE) {
      Print("ATR handle is invalid in GetATR.");
      return 0.0;
   }

   double atr_buffer[];
   // Ensure enough bars calculated
   int calculated = BarsCalculated(atrHandle);
   if(calculated < shift + 1) {
       Print("ATR not calculated enough bars (", calculated, "), need ", shift + 1);
       return 0.0; // Not enough data
   }

   // Copy data
   if(CopyBuffer(atrHandle, 0, shift, 1, atr_buffer) <= 0) {
      Print("Error copying ATR buffer: ", GetLastError());
      return 0.0;
   }

   // Basic validation
   if(atr_buffer[0] <= 0 || !MathIsValidNumber(atr_buffer[0])) {
       Print("Invalid ATR value retrieved: ", atr_buffer[0]);
       return 0.0;
   }

   return atr_buffer[0];
}


//+------------------------------------------------------------------+
//| Expert OnTick function                                           |
//+------------------------------------------------------------------+
void OnTick() {
   //--- Apply trailing stop to open positions if enabled
   if (enableTrailingStop) {
      applyTrailingStop(trailingStopPoints, obj_Trade, uniqueMagicNumber);
   }

   //--- Check for a new bar to process logic only once per bar
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if (currentBarTime == lastBarTime) {
      return; // Not a new bar, exit
   }
   lastBarTime = currentBarTime;
   // --- NEW BAR LOGIC STARTS HERE ---

   //--- Define the starting bar index for consolidation checks
   int startBarIndex = 1; // Check from the last completed bar backwards

   //--- Calculate dynamic font size based on chart scale (0 = zoomed out, 5 = zoomed in)
   int chartScale = (int)ChartGetInteger(0, CHART_SCALE); // Scale ranges from 0 to 5
   int dynamicFontSize = MathMax(8, 8 + (chartScale * 2)); // Font size: 8 (min) to 18 (max), ensure min 8

   // --- Stage 1: Identify Consolidation and Potential Breakout ---
   // --- (Logic is similar to original ob-allan, identifies the *potential* OB zone) ---

   // Check for consolidation or extend the existing range IF no breakout is currently detected
   if (!isBreakoutDetected) {
       // If no range is established, try to find one
       if (rangeHighestHigh.price == 0 && rangeLowestLow.price == 0) {
           bool isConsolidated = true;
           // Check consolidation over the defined period
           for (int i = startBarIndex; i < startBarIndex + consolidationBars -1 ; i++) { // Check range relative to previous bar
               if (i + 1 >= Bars(_Symbol, _Period)) { isConsolidated = false; break; } // Avoid out of bounds
               if (MathAbs(high(i) - high(i + 1)) > maxConsolidationSpread * Point()) { isConsolidated = false; break; }
               if (MathAbs(low(i) - low(i + 1)) > maxConsolidationSpread * Point()) { isConsolidated = false; break; }
           }

           if (isConsolidated) {
               // Find the highest high and lowest low in the consolidation range
               rangeHighestHigh.price = high(startBarIndex); rangeHighestHigh.index = startBarIndex;
               rangeLowestLow.price = low(startBarIndex);   rangeLowestLow.index = startBarIndex;
               for (int i = startBarIndex + 1; i < startBarIndex + consolidationBars; i++) {
                   if (i >= Bars(_Symbol, _Period)) break; // Avoid out of bounds
                   if (high(i) > rangeHighestHigh.price) { rangeHighestHigh.price = high(i); rangeHighestHigh.index = i; }
                   if (low(i) < rangeLowestLow.price)   { rangeLowestLow.price = low(i);   rangeLowestLow.index = i; }
               }
               // Check if the range is valid (not zero)
               if (rangeHighestHigh.price > rangeLowestLow.price) {
                  // Print("Consolidation range established: HH=", rangeHighestHigh.price, " at ", rangeHighestHigh.index,
                  //       ", LL=", rangeLowestLow.price, " at ", rangeLowestLow.index);
               } else {
                  // Invalid range, reset
                  rangeHighestHigh.price = 0; rangeHighestHigh.index = 0;
                  rangeLowestLow.price = 0;   rangeLowestLow.index = 0;
                  // Print("Invalid consolidation range detected (High <= Low). Resetting.");
               }
           }
       } else {
           // If a range exists, check if the current bar *stayed within* it (no breakout yet)
           // Note: Original 'ob-allan' extended the range here, this version just waits for breakout.
           double currentHigh = high(startBarIndex);
           double currentLow = low(startBarIndex);
           if (currentHigh > rangeHighestHigh.price || currentLow < rangeLowestLow.price) {
               // Breakout potentially occurred on the *previous* bar (bar 1)
               isBreakoutDetected = true;
               // Print("Breakout detected on bar 1. High: ", currentHigh, " Low: ", currentLow,
               //      " vs Range High: ", rangeHighestHigh.price, " Low: ", rangeLowestLow.price);
           } else {
               // Still consolidating, update the end point of the range if needed?
               // For simplicity, we are not extending the range here, just waiting for the break.
               // Print("Still consolidating within range.");
           }
       }
   } // end if (!isBreakoutDetected)

   // If a breakout was detected on the *previous* bar (bar 1)
   if (isBreakoutDetected && breakoutBarNumber == -1) { // Check breakoutBarNumber to prevent re-triggering
       breakoutBarNumber = startBarIndex; // Mark the bar index of the breakout candle
       breakoutTimestamp = time(startBarIndex); // Time of the breakout candle
       lastImpulseHigh = rangeHighestHigh.price; // Store the consolidation range extremes
       lastImpulseLow = rangeLowestLow.price;
       Print("Breakout confirmed. Bar Index: ", breakoutBarNumber, " Time: ", TimeToString(breakoutTimestamp),
             " Consolidation High: ", lastImpulseHigh, " Low: ", lastImpulseLow);

       // Reset detection flags for the next cycle
       isBreakoutDetected = false; // Reset breakout flag
       rangeHighestHigh.price = 0; rangeHighestHigh.index = 0; // Clear the old range
       rangeLowestLow.price = 0;   rangeLowestLow.index = 0;
   }

   // --- Stage 2: Check for Impulsive Move and Create Order Block ---
   // --- This happens *after* the breakout and waiting period ---
   if (breakoutBarNumber > 0 && time(0) >= breakoutTimestamp + barsToWaitAfterBreakout * PeriodSeconds()) {
       // Calculate impulse threshold based on the *consolidation range size*
       double impulseRange = lastImpulseHigh - lastImpulseLow;
       if (impulseRange <= 0) { // Safety check for valid range
           Print("Invalid impulse range (<=0) after breakout. Resetting.");
           breakoutBarNumber = -1; // Reset state
           return;
       }
       double impulseThresholdPrice = impulseRange * impulseMultiplier; // Minimum move required

       isBullishImpulse = false;
       isBearishImpulse = false;

       // Check the bars *after* the breakout bar for impulse
       // Check from bar 1 up to 'barsToWaitAfterBreakout' bars ago
       for (int i = 1; i <= barsToWaitAfterBreakout; i++) {
           int checkIndex = breakoutBarNumber + i -1; // Index relative to current bar (0)
           if (checkIndex < 1 || checkIndex >= Bars(_Symbol, _Period)) continue; // Bounds check

           double closePrice = close(checkIndex);
           // Check for bullish impulse: close significantly above consolidation high
           if (closePrice > lastImpulseHigh && (closePrice - lastImpulseHigh) >= impulseThresholdPrice) {
               isBullishImpulse = true;
               Print("Impulsive upward move detected. Bar: ", checkIndex, " Close: ", closePrice,
                     " > Consolidation High: ", lastImpulseHigh, " + Threshold: ", impulseThresholdPrice);
               break;
           }
           // Check for bearish impulse: close significantly below consolidation low
           else if (closePrice < lastImpulseLow && (lastImpulseLow - closePrice) >= impulseThresholdPrice) {
               isBearishImpulse = true;
               Print("Impulsive downward move detected. Bar: ", checkIndex, " Close: ", closePrice,
                     " < Consolidation Low: ", lastImpulseLow, " - Threshold: ", impulseThresholdPrice);
               break;
           }
       }

       // Only create an OB if an impulsive move was detected
       if (isBullishImpulse || isBearishImpulse) {
           // Define OB boundaries based on the *consolidation range*
           double blockTopPrice = lastImpulseHigh;
           double blockBottomPrice = lastImpulseLow;

           // Define OB start time (time of the earliest bar in consolidation) and end time
           datetime blockStartTime = time(breakoutBarNumber + consolidationBars - 1); // Approx start of consolidation leading to breakout
           // Extend OB visualization into the future (e.g., 50 bars or adaptive)
           int futureBars = 50; // How many bars into the future to draw the OB rectangle
           datetime blockEndTime = time(0) + futureBars * PeriodSeconds();

           // Create unique name for OB object
           string orderBlockName = OB_Prefix + TimeToString(blockStartTime, TIME_DATE | TIME_MINUTES);
           color orderBlockColor = isBullishImpulse ? bullishOrderBlockColor : bearishOrderBlockColor;
           string orderBlockLabelText = isBullishImpulse ? "Bullish OB" : "Bearish OB";

           // Check if this OB already exists (to avoid duplicates)
           if (ObjectFind(0, orderBlockName) < 0) {
               // Create rectangle for the order block
               ObjectCreate(0, orderBlockName, OBJ_RECTANGLE, 0, blockStartTime, blockTopPrice, blockEndTime, blockBottomPrice);
               ObjectSetInteger(0, orderBlockName, OBJPROP_COLOR, orderBlockColor);
               ObjectSetInteger(0, orderBlockName, OBJPROP_STYLE, STYLE_SOLID);
               ObjectSetInteger(0, orderBlockName, OBJPROP_FILL, true); // Optional fill
               ObjectSetInteger(0, orderBlockName, OBJPROP_BACK, true); // Draw behind price
               ObjectSetString(0, orderBlockName, OBJPROP_TOOLTIP, orderBlockLabelText + "\nStart: " + TimeToString(blockStartTime));

               // Add text label inside the rectangle
               datetime labelTime = blockStartTime + (PeriodSeconds() * consolidationBars / 2); // Position label near start
               double labelPrice = (blockTopPrice + blockBottomPrice) / 2.0;
               string labelObjectName = orderBlockName + "_Label";
               ObjectCreate(0, labelObjectName, OBJ_TEXT, 0, labelTime, labelPrice);
               ObjectSetString(0, labelObjectName, OBJPROP_TEXT, orderBlockLabelText);
               ObjectSetInteger(0, labelObjectName, OBJPROP_COLOR, labelTextColor);
               ObjectSetInteger(0, labelObjectName, OBJPROP_FONTSIZE, dynamicFontSize);
               ObjectSetInteger(0, labelObjectName, OBJPROP_ANCHOR, ANCHOR_CENTER);
               ObjectSetInteger(0, labelObjectName, OBJPROP_BACK, false); // Label above rectangle

               ChartRedraw(0);

               // Store the order block details for later processing
               int newIndex = ArraySize(orderBlockNames);
               ArrayResize(orderBlockNames, newIndex + 1);
               ArrayResize(orderBlockEndTimes, newIndex + 1);
               ArrayResize(orderBlockTradedStatus, newIndex + 1); // Use renamed array

               orderBlockNames[newIndex] = orderBlockName;
               orderBlockEndTimes[newIndex] = blockEndTime; // Store the calculated visual end time
               orderBlockTradedStatus[newIndex] = false; // Initialize as not traded

               Print("Order Block created: ", orderBlockName, " - Type: ", orderBlockLabelText);
           } else {
                // Print("Order block ", orderBlockName, " already exists. Skipping creation.");
           }
       } else {
            Print("No impulsive movement detected after waiting period. No OB created.");
       }

       // Reset breakout tracking variables regardless of impulse outcome
       breakoutBarNumber = -1;
       breakoutTimestamp = 0;
       lastImpulseHigh = 0;
       lastImpulseLow = 0;
       isBullishImpulse = false;
       isBearishImpulse = false;
   } // end if (breakoutBarNumber > 0 && time check)

   // --- Stage 3: Process Existing Order Blocks for SMC Liquidity Grab Entry ---
   if (enableTrading) {
       ProcessOrderBlocksForSMCEntry();
   }

} // END OnTick (New Bar Logic)


//+------------------------------------------------------------------+
//| Process Existing Order Blocks for SMC Entry                      |
//+------------------------------------------------------------------+
void ProcessOrderBlocksForSMCEntry() {
   // Get current prices for potential entries
   double currentAskPrice = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   double currentBidPrice = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);

   // Get data of the last completed bar (index 1)
   double close1 = iClose(_Symbol, _Period, 1);
   double high1 = iHigh(_Symbol, _Period, 1);
   double low1 = iLow(_Symbol, _Period, 1);
   datetime time1 = iTime(_Symbol, _Period, 1);

   // Get current ATR value
   double currentATR = GetATR(1); // Use ATR from the last completed bar
   if (currentATR <= 0) {
       Print("Invalid ATR value (", currentATR, ") in ProcessOrderBlocks. Skipping entry checks.");
       return; // Cannot calculate liquidity zones without valid ATR
   }
   double pointValue = Point(); // Cache point value

   // Loop through tracked order blocks
   for (int j = ArraySize(orderBlockNames) - 1; j >= 0; j--) { // Loop backwards for safe removal (if needed later)
       // Check if OB object still exists on chart
       if (ObjectFind(0, orderBlockNames[j]) < 0) {
           // Object removed manually or by other means, clean up arrays (optional)
           // Print("OB object ", orderBlockNames[j], " not found. Consider removing from tracking.");
           // ArrayRemove(...); // Implement removal if strict tracking is needed
           continue;
       }

       // Check if already traded
       if (orderBlockTradedStatus[j]) {
           continue; // Skip OBs that have already resulted in a trade
       }

       // Check if visually expired (rectangle end time) - prevents checking very old OBs
       if (time(0) > orderBlockEndTimes[j]) {
            // Optional: Change color to gray or remove object/array entry for expired OBs
            // ObjectSetInteger(0, orderBlockNames[j], OBJPROP_COLOR, clrGray);
            // Print("OB ", orderBlockNames[j], " visually expired.");
            continue;
       }

       // Retrieve OB properties from the chart object
       double obHigh = ObjectGetDouble(0, orderBlockNames[j], OBJPROP_PRICE, 0);
       double obLow = ObjectGetDouble(0, orderBlockNames[j], OBJPROP_PRICE, 1);
       color obColor = (color)ObjectGetInteger(0, orderBlockNames[j], OBJPROP_COLOR);

       // Determine OB type (Bullish/Bearish) based on its current color
       bool isBullishOB = (obColor == bullishOrderBlockColor);
       bool isBearishOB = (obColor == bearishOrderBlockColor);

       // Skip if color doesn't match expected active OB colors
       if (!isBullishOB && !isBearishOB) {
           continue;
       }

       // Define Liquidity Zone
       double liqTop, liqBottom;
       double zoneSize = currentATR * ATR_Multiplier;
       if (isBullishOB) {
           liqTop = obLow;                // Top of liquidity zone is OB low
           liqBottom = obLow - zoneSize;  // Bottom extends below OB low
       } else { // Bearish OB
           liqBottom = obHigh;            // Bottom of liquidity zone is OB high
           liqTop = obHigh + zoneSize;    // Top extends above OB high
       }

       // Normalize liquidity zone boundaries
       liqTop = NormalizeDouble(liqTop, _Digits);
       liqBottom = NormalizeDouble(liqBottom, _Digits);

       // --- Check for Entry Signals based on the *previous* bar's action ---

       // Check Long Signal (Bullish OB)
       if (isBullishOB) {
           // Condition 1: Previous bar's low dipped into the liquidity zone below the OB
           bool liquidityGrabbed = (low1 < liqTop && low1 <= liqBottom); // Check if low went below or equal to the calculated bottom
           // Condition 2: Previous bar's close reversed back *inside* the OB range
           bool reversedIntoOB = (close1 >= obLow && close1 <= obHigh);

           if (liquidityGrabbed && reversedIntoOB) {
               Print("Long Signal Detected for OB: ", orderBlockNames[j]);
               Print(" -> Low1 (", low1, ") <= LiqBottom (", liqBottom, ")");
               Print(" -> Close1 (", close1, ") >= OB Low (", obLow, ") and <= OB High (", obHigh, ")");

               // Place Buy Trade
               double entryPrice = currentAskPrice; // Market Buy
               double stopLossPrice = NormalizeDouble(liqBottom - stopLossBufferPips * pointValue, _Digits);
               double takeProfitPrice = NormalizeDouble(entryPrice + (entryPrice - stopLossPrice) * takeProfitRR, _Digits);

               // Validate SL/TP levels (basic check against current price)
               if (stopLossPrice >= entryPrice) {
                  Print("Invalid SL for Buy order (SL >= Entry). SL=", stopLossPrice, " Entry=", entryPrice);
                  continue;
               }
               if (takeProfitPrice <= entryPrice) {
                  Print("Invalid TP for Buy order (TP <= Entry). TP=", takeProfitPrice, " Entry=", entryPrice);
                  continue;
               }

               if(obj_Trade.Buy(tradeLotSize, _Symbol, entryPrice, stopLossPrice, takeProfitPrice, "SMC Buy " + orderBlockNames[j])) {
                   Print("Buy Order Placed. Ticket: ", obj_Trade.ResultDeal());
                   orderBlockTradedStatus[j] = true; // Mark as traded
                   // Update visualization
                   ObjectSetInteger(0, orderBlockNames[j], OBJPROP_COLOR, tradedBullishColor);
                   string labelName = orderBlockNames[j] + "_Label";
                   if(ObjectFind(0, labelName) >= 0) ObjectSetString(0, labelName, OBJPROP_TEXT, "Traded Bullish");
                   ChartRedraw(0);
               } else {
                   Print("Error placing Buy order: ", obj_Trade.ResultRetcode(), " - ", obj_Trade.ResultComment());
               }
           }
       }
       // Check Short Signal (Bearish OB)
       else if (isBearishOB) {
           // Condition 1: Previous bar's high spiked into the liquidity zone above the OB
           bool liquidityGrabbed = (high1 > liqBottom && high1 >= liqTop); // Check if high went above or equal to the calculated top
           // Condition 2: Previous bar's close reversed back *inside* the OB range
           bool reversedIntoOB = (close1 <= obHigh && close1 >= obLow);

           if (liquidityGrabbed && reversedIntoOB) {
               Print("Short Signal Detected for OB: ", orderBlockNames[j]);
               Print(" -> High1 (", high1, ") >= LiqTop (", liqTop, ")");
               Print(" -> Close1 (", close1, ") <= OB High (", obHigh, ") and >= OB Low (", obLow, ")");

               // Place Sell Trade
               double entryPrice = currentBidPrice; // Market Sell
               double stopLossPrice = NormalizeDouble(liqTop + stopLossBufferPips * pointValue, _Digits);
               double takeProfitPrice = NormalizeDouble(entryPrice - (stopLossPrice - entryPrice) * takeProfitRR, _Digits);

                // Validate SL/TP levels (basic check against current price)
               if (stopLossPrice <= entryPrice) {
                  Print("Invalid SL for Sell order (SL <= Entry). SL=", stopLossPrice, " Entry=", entryPrice);
                  continue;
               }
               if (takeProfitPrice >= entryPrice) {
                  Print("Invalid TP for Sell order (TP >= Entry). TP=", takeProfitPrice, " Entry=", entryPrice);
                  continue;
               }

               if(obj_Trade.Sell(tradeLotSize, _Symbol, entryPrice, stopLossPrice, takeProfitPrice, "SMC Sell " + orderBlockNames[j])) {
                   Print("Sell Order Placed. Ticket: ", obj_Trade.ResultDeal());
                   orderBlockTradedStatus[j] = true; // Mark as traded
                   // Update visualization
                   ObjectSetInteger(0, orderBlockNames[j], OBJPROP_COLOR, tradedBearishColor);
                   string labelName = orderBlockNames[j] + "_Label";
                   if(ObjectFind(0, labelName) >= 0) ObjectSetString(0, labelName, OBJPROP_TEXT, "Traded Bearish");
                   ChartRedraw(0);
               } else {
                   Print("Error placing Sell order: ", obj_Trade.ResultRetcode(), " - ", obj_Trade.ResultComment());
               }
           }
       }
   } // end loop through order blocks
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
// --- (Trailing Stop Function remains the same as in original ob-allan) ---
void applyTrailingStop(double trailingPoints, CTrade &trade_object, int magicNo = 0) {
   //--- Prevent trailing stop if trailingPoints is zero or negative
   if (trailingPoints <= 0) return;

   //--- Calculate trailing stop levels based on current market prices
   double point = _Point;
   double buyStopLoss = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID) - trailingPoints * point, _Digits);
   double sellStopLoss = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK) + trailingPoints * point, _Digits);

   //--- Loop through all open positions
   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if (ticket > 0) {
         //--- Filter by symbol and magic number
         if (PositionGetString(POSITION_SYMBOL) == _Symbol &&
             (magicNo == 0 || PositionGetInteger(POSITION_MAGIC) == (ulong)magicNo)) { // Cast magicNo for safety

            double positionOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double positionSL = PositionGetDouble(POSITION_SL);
            double positionTP = PositionGetDouble(POSITION_TP); // TP needed for PositionModify
            ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

            //--- Adjust stop loss for buy positions
            if (positionType == POSITION_TYPE_BUY) {
               //--- Check if new SL is profitable and better than the current SL
               if (buyStopLoss > positionOpenPrice && (buyStopLoss > positionSL || positionSL == 0)) {
                  // Prevent setting SL beyond TP
                  if (positionTP > 0 && buyStopLoss >= positionTP) {
                      Print("Trailing stop for BUY ticket ", ticket, " skipped: New SL (", buyStopLoss, ") would exceed TP (", positionTP, ")");
                      continue;
                  }
                  if(trade_object.PositionModify(ticket, buyStopLoss, positionTP)) {
                     // Print("Trailing Stop updated for BUY ticket ", ticket, " to ", buyStopLoss);
                  } else {
                     Print("Error modifying trailing stop for BUY ticket ", ticket, ": ", trade_object.ResultRetcode(), " - ", trade_object.ResultComment());
                  }
               }
            }
            //--- Adjust stop loss for sell positions
            else if (positionType == POSITION_TYPE_SELL) {
               //--- Check if new SL is profitable and better than the current SL
               if (sellStopLoss < positionOpenPrice && (sellStopLoss < positionSL || positionSL == 0)) {
                   // Prevent setting SL beyond TP
                   if (positionTP > 0 && sellStopLoss <= positionTP) {
                       Print("Trailing stop for SELL ticket ", ticket, " skipped: New SL (", sellStopLoss, ") would exceed TP (", positionTP, ")");
                       continue;
                   }
                  if(trade_object.PositionModify(ticket, sellStopLoss, positionTP)) {
                     // Print("Trailing Stop updated for SELL ticket ", ticket, " to ", sellStopLoss);
                  } else {
                      Print("Error modifying trailing stop for SELL ticket ", ticket, ": ", trade_object.ResultRetcode(), " - ", trade_object.ResultComment());
                  }
               }
            }
         }
      }
   }
}
//+------------------------------------------------------------------+