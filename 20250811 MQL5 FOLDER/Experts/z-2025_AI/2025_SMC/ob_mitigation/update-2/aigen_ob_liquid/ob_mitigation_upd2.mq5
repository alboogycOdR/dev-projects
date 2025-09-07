//+------------------------------------------------------------------+
//| Expert Advisor: Mitigation Order Blocks Strategy                 |
//+------------------------------------------------------------------+

//idea from:https://www.mql5.com/en/job/235273
//https://x.com/i/grok?conversation=1908116504559616228

#include <Trade\Trade.mqh>  // Include Trade library for CTrade class
/*
   The core strategy revolves around identifying "Order Blocks" (OBs), which are zones representing potential supply or demand imbalances, often formed after a period of consolidation followed by a strong price move. The EA then looks for price to return to these blocks and show signs of rejection before entering a trade in the direction of the initial strong move, provided the higher timeframe market structure aligns.
   Here's a step-by-step breakdown of the conditions:
   Order Block Identification (IdentifyOrderBlock):
   The EA looks back ConsolidationPeriod bars (default 20) starting from startBar (which is ConsolidationPeriod + 1 bars ago on a new bar, or further back during initialization).
   It checks if the price range within this consolidation period is relatively small (less than 0.5 * ATR).
   It then checks the bar immediately after the consolidation (startBar - ConsolidationPeriod - 1).
   Bullish OB: If the closing price of the bar after consolidation is significantly higher than the consolidation high (by more than 1.5 * ATR), a Bullish Order Block is identified. The high and low of the consolidation range define the block zone.
   Bearish OB: If the closing price of the bar after consolidation is significantly lower than the consolidation low (by more than 1.5 * ATR), a Bearish Order Block is identified. The high and low of the consolidation range define the block zone.
   Identified OBs are stored, marked as not mitigated, and visualized.
   Mitigation and Entry Signal Check (CheckMitigation):
   On every new bar (OnNewBar calls CheckMitigation), the EA checks existing, non-mitigated OBs.
   Mitigation: An OB is marked as "mitigated" (invalidated) if the price closes fully beyond the opposite side of the block (below the low for bullish, above the high for bearish).
   Entry Signal: If the previous bar's high and low were within the OB's range, the EA checks for a specific candlestick rejection pattern:
   Bullish Rejection (IsBullishRejection): Checks if the previous bar had a long lower wick (low significantly below the body) and a small body near the top of the candle's range. If found within a bullish OB, hasEntrySignal is set to true, and entryLevel is set to the previous bar's high.
   Bearish Rejection (IsBearishRejection): Checks if the previous bar had a long upper wick (high significantly above the body) and a small body near the bottom of the candle's range. If found within a bearish OB, hasEntrySignal is set to true, and entryLevel is set to the previous bar's low.
   Trade Execution (ExecuteTrades called from OnTick):
   The EA continuously checks (on every tick) if tradingAllowed is true (i.e., the daily loss limit hasn't been hit).
   It iterates through all identified OBs.
   It only considers OBs that are not mitigated (!orderBlocks[i].mitigated) and have an entry signal (orderBlocks[i].hasEntrySignal).
   Market Structure Confirmation (ConfirmMarketStructure): Before placing a trade, it checks if the current price on the H4 timeframe aligns with the OB direction using a Simple Moving Average (SMA) with MAPeriod (default 20):
   For a Bullish OB, the current price must be above the H4 SMA.
   For a Bearish OB, the current price must be below the H4 SMA.
   Final Entry Trigger:
   Buy: If it's a Bullish OB, the market structure confirms bullish, and the current price is at or above the entryLevel (the high of the rejection candle).
   Sell: If it's a Bearish OB, the market structure confirms bearish, and the current price is at or below the entryLevel (the low of the rejection candle).
   Trade Placement (PlaceTrade): If all conditions are met, a trade is placed:
   Lot size is calculated based on RiskPercent and the distance from the entry price to the stop loss.
   Stop Loss (SL) is placed just beyond the OB (low - ATRMultiplier for buys, high + ATRMultiplier for sells).
   Take Profit (TP) is calculated based on the RRRatio (Risk-Reward Ratio).
   Once the trade is successfully placed, the corresponding OB is marked as mitigated to prevent further trades based on it.
   In summary:
   Buy Trade Conditions:
   A Bullish Order Block must be identified (consolidation followed by a strong up-move).
   The block must not be mitigated (price hasn't closed below its low).
   Price must retrace into the block, and a bullish rejection candle pattern must form within it.
   The current price must be above the H4 SMA (market structure confirmation).
   The current price must reach or exceed the high of the rejection candle (entryLevel).
   The daily loss limit must not have been reached (tradingAllowed is true).
   Sell Trade Conditions:
   A Bearish Order Block must be identified (consolidation followed by a strong down-move).
   The block must not be mitigated (price hasn't closed above its high).
   Price must retrace into the block, and a bearish rejection candle pattern must form within it.
   The current price must be below the H4 SMA (market structure confirmation).
   The current price must reach or fall below the low of the rejection candle (entryLevel).
   The daily loss limit must not have been reached (tradingAllowed is true).
*/
/*

   Strict Conditions Not Being Met: The conditions for identifying an Order Block (IdentifyOrderBlock) are quite specific:
   Consolidation: The price range during the ConsolidationPeriod must be less than half the Average True Range (0.5 * atr). If the market is volatile or the chosen ConsolidationPeriod is too long/short for the current timeframe, this condition might rarely be true.
   Strong Move: The move after consolidation must be greater than 1.5 times the ATR (1.5 * atr). This requires a significant, sharp move immediately following the tight range. Such moves might not occur frequently enough or meet this threshold.
   Action: Check the ATR values being calculated and compare them to the price ranges you visually observe. Consider adjusting ConsolidationPeriod, ATRPeriod, and the multipliers (0.5, 1.5) if they seem too restrictive for the symbol and timeframe you are using.
   Indicator Calculation Issues:
   The GetATR and GetMA functions rely on BarsCalculated to ensure indicator data is ready. While there are checks, sometimes data loading can be slow or incomplete, especially on startup or after history downloads.
   Action: Check the "Experts" tab in MetaTrader 5 when you load the EA onto a chart. Look for any error messages like "Error creating ATR indicator", "Error copying ATR data", "ATR indicator not calculated enough bars", or similar messages for the MA. These would indicate a problem getting the necessary indicator values.
   Rejection Signal Conditions:
   The IsBullishRejection and IsBearishRejection functions look for specific candle patterns (long wicks, small bodies at one end). These precise patterns might not form often, or price might not retrace exactly into the identified OB zone before such a candle forms.
   Action: Observe the candles forming when price interacts with visually identified potential OB zones. Do they match the criteria in the code? You might need to relax the rejection criteria (e.g., change 0.7 and 0.3 thresholds) or add alternative rejection patterns.
   Market Structure Filter (ConfirmMarketStructure):
   The requirement to be above/below the H4 SMA (GetMA on PERIOD_H4) acts as a strong filter. Even if an OB forms and a rejection occurs, if the H4 trend doesn't align at that exact moment, no trade will happen.
   Action: Add the same H4 SMA (e.g., 20-period SMA) to your H4 chart and compare it to the price action on your trading timeframe. Is this filter preventing valid setups according to the OB logic? You could temporarily disable this check in ExecuteTrades to see if signals then lead to trade attempts.
   Trade Execution Logic (ExecuteTrades, PlaceTrade):
   Entry Trigger: The condition currentPrice >= orderBlocks[i].entryLevel (for buys) or currentPrice <= orderBlocks[i].entryLevel (for sells) requires the price to touch or cross the exact high/low of the rejection candle. Spread or rapid price movement might cause this level to be skipped.
   Lot Size Calculation: It's possible the calculated lotSize is consistently below the minimum allowed volume (SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)), especially if the stop loss distance is very small or the RiskPercent is low. The PlaceTrade function would silently return in this case.
   Action: Add Print statements inside ExecuteTrades to see if the conditions (tradeCondition && ConfirmMarketStructure) are ever met. Add Print statements inside PlaceTrade before the if(lotSize < ...) check to see the calculated lotSize, stopLossDistance, riskAmount, etc. Check the "Experts" or "Journal" tabs for any trade-related errors (e.g., "invalid stops", "not enough money").
*/

// Input Parameters


input group "Order Block Identification"
input int LookbackPeriod = 500;        // Lookback period for Order Block identification
input int ConsolidationPeriod = 20;    // Number of bars to check for consolidation
input int ATRPeriod = 14;              // ATR period for volatility measurement
input double ATRMultiplier = 1.5;      // ATR multiplier for stop loss adjustment

input group "Risk Management"
input double RRRatio = 1.0;            // Risk-reward ratio for take profit
input double RiskPercent = 1.0;        // Risk percentage per trade
input double MaxDailyLoss = 5.0;       // Maximum daily loss percentage

input group "Market Structure Filter"
input int MAPeriod = 20;               // Moving average period for market structure
input bool CheckConsolidationRange = false; // Enable/disable consolidation range check (vs 0.5*ATR)
input bool CheckStrongMoveATR = false;     // Enable/disable strong move check (vs 1.5*ATR)

// Global Variables
struct OrderBlock {
   double high;        // High of the Order Block zone
   double low;         // Low of the Order Block zone
   bool isBullish;     // True for bullish, false for bearish
   bool mitigated;     // True if fully mitigated or traded
   int barIndex;       // Bar index where identified
   bool hasEntrySignal;// True if rejection signal detected
   double entryLevel;  // Entry price level after rejection
};

OrderBlock orderBlocks[];
int blockCount = 0;
datetime lastBarTime = 0;
double startOfDayEquity = 0;
int lastDay = 0;
bool tradingAllowed = true;

// Indicator handles
int atrHandle = INVALID_HANDLE;
int maHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Get day of year from datetime                                    |
//+------------------------------------------------------------------+
int DayOfYear(datetime time) {
   MqlDateTime dt;
   TimeToStruct(time, dt);
   return dt.day_of_year;
}

//+------------------------------------------------------------------+
//| Get ATR value for a specific bar                                 |
//+------------------------------------------------------------------+
double GetATR(int period, int shift) {
   double atr[];
   
   // Make sure we have valid data available for the requested shift
   if(shift >= Bars(_Symbol, PERIOD_CURRENT)) {
      Print("Requested ATR shift is beyond available bars");
      return 0.0;
   }
   
   if(atrHandle == INVALID_HANDLE) {
      Print("ATR handle is invalid, recreating...");
      atrHandle = iATR(_Symbol, PERIOD_CURRENT, period);
      if(atrHandle == INVALID_HANDLE) {
         Print("Error creating ATR indicator: ", GetLastError());
         return 0.0;
      }
   }
   
   // Wait for the data to be calculated
   int tries = 0;
   while(tries < 10 && BarsCalculated(atrHandle) < shift + 1) {
      Sleep(100);
      tries++;
   }
   
   if(BarsCalculated(atrHandle) < shift + 1) {
      Print("ATR indicator not calculated enough bars: ", BarsCalculated(atrHandle), " needed: ", shift + 1);
      return 0.0;
   }
   
   // Copy the ATR data
   if(CopyBuffer(atrHandle, 0, shift, 1, atr) <= 0) {
      int error = GetLastError();
      Print("Error copying ATR data: ", error);
      
      // Reset handle if there's a serious error (not a temporary data issue)
      if(error != 4066 && error != 4099) {
         IndicatorRelease(atrHandle);
         atrHandle = INVALID_HANDLE;
      }
      return 0.0;
   }
   
   return atr[0];
}

//+------------------------------------------------------------------+
//| Get MA value for a specific bar                                  |
//+------------------------------------------------------------------+
double GetMA(int period, int shift, ENUM_MA_METHOD method, ENUM_APPLIED_PRICE price_type) {
   double ma[];
   
   if(maHandle == INVALID_HANDLE) {
      Print("MA handle is invalid, recreating...");
      maHandle = iMA(_Symbol, PERIOD_H4, period, 0, method, price_type);
      if(maHandle == INVALID_HANDLE) {
         Print("Error creating MA indicator: ", GetLastError());
         return 0.0;
      }
   }
   
   // Wait for the data to be calculated
   int tries = 0;
   while(tries < 10 && BarsCalculated(maHandle) < shift + 1) {
      Sleep(100);
      tries++;
   }
   
   if(BarsCalculated(maHandle) < shift + 1) {
      Print("MA indicator not calculated enough bars");
      return 0.0;
   }
   
   // Copy the MA data
   if(CopyBuffer(maHandle, 0, shift, 1, ma) <= 0) {
      int error = GetLastError();
      Print("Error copying MA data: ", error);
      
      // Reset handle if there's a serious error (not a temporary data issue)
      if(error != 4066 && error != 4099) {
         IndicatorRelease(maHandle);
         maHandle = INVALID_HANDLE;
      }
      return 0.0;
   }
   
   return ma[0];
}

//+------------------------------------------------------------------+
//| Expert Initialization Function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   // Resize the Order Blocks array
   ArrayResize(orderBlocks, 100);
   blockCount = 0;

   // Initialize daily equity tracking
   startOfDayEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   lastDay = DayOfYear(TimeCurrent());
   
   // Initialize indicators
   atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
   if(atrHandle == INVALID_HANDLE) {
      Print("Error creating ATR indicator: ", GetLastError());
      return INIT_FAILED;
   }
   
   maHandle = iMA(_Symbol, PERIOD_H4, MAPeriod, 0, MODE_SMA, PRICE_CLOSE);
   if(maHandle == INVALID_HANDLE) {
      Print("Error creating MA indicator: ", GetLastError());
      return INIT_FAILED;
   }

   // Draw initial Order Blocks
   IdentifyInitialOrderBlocks();

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert Tick Function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   // Check for new bar
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentBarTime != lastBarTime) {
      lastBarTime = currentBarTime;
      OnNewBar();
   }

   // Check daily loss limit
   CheckDailyLossLimit();

   // Execute trades based on current price
   if(tradingAllowed) {
      ExecuteTrades();
   }
}

//+------------------------------------------------------------------+
//| New Bar Event Handler                                            |
//+------------------------------------------------------------------+
void OnNewBar() {
   // Update Order Blocks
   IdentifyNewOrderBlocks();

   // Check for mitigation and rejection signals
   CheckMitigation();
}

//+------------------------------------------------------------------+
//| Identify Initial Order Blocks on Startup                         |
//+------------------------------------------------------------------+
void IdentifyInitialOrderBlocks() {
   for(int i = LookbackPeriod; i >= ConsolidationPeriod + 1; i--) {
      if(IdentifyOrderBlock(i)) {
         VisualizeOrderBlock(blockCount - 1);
      }
   }
}

//+------------------------------------------------------------------+
//| Identify New Order Blocks                                        |
//+------------------------------------------------------------------+
void IdentifyNewOrderBlocks() {
   if(IdentifyOrderBlock(ConsolidationPeriod + 1)) {
      VisualizeOrderBlock(blockCount - 1);
   }
}

//+------------------------------------------------------------------+
//| Identify an Order Block at a Given Starting Bar                  |
//+------------------------------------------------------------------+
bool IdentifyOrderBlock(int startBar) {
   // Initial check for enough bars
   if (startBar - ConsolidationPeriod - 1 < 0) {
      Print("IdentifyOrderBlock: Not enough bars available for startBar ", startBar);
      return false;
   }
   
   double high = iHigh(_Symbol, PERIOD_CURRENT, startBar);
   double low = iLow(_Symbol, PERIOD_CURRENT, startBar);
   double atr = GetATR(ATRPeriod, startBar);
   
   // Handle potential ATR error
   if (atr <= 0 && (CheckConsolidationRange || CheckStrongMoveATR)) {
      Print("IdentifyOrderBlock: Invalid ATR value (", atr, ") at bar ", startBar, ". Skipping block identification.");
      return false;
   }

   // Calculate consolidation range
   for(int i = startBar - 1; i > startBar - ConsolidationPeriod; i--) { // Corrected loop to exclude startBar itself initially
      if (i < 0) break; // Prevent negative index
      double h = iHigh(_Symbol, PERIOD_CURRENT, i);
      double l = iLow(_Symbol, PERIOD_CURRENT, i);
      high = MathMax(high, h);
      low = MathMin(low, l);
   }
   
   // Optional: Check for consolidation range vs ATR
   if (CheckConsolidationRange) {
      if (high - low > 0.5 * atr) {
         // Print("IdentifyOrderBlock: Consolidation range ", high-low, " too large vs 0.5*ATR ", 0.5*atr, " at startBar ", startBar); // Optional debug print
         return false; // Range too large
      }
   }

   // Check for strong move after consolidation
   double nextClose = iClose(_Symbol, PERIOD_CURRENT, startBar - ConsolidationPeriod - 1);
   bool isBullishMove = false;
   bool isBearishMove = false;

   if (CheckStrongMoveATR) {
      // Check using ATR multiplier
      isBullishMove = (nextClose - high > 1.5 * atr);
      isBearishMove = (low - nextClose > 1.5 * atr);
      // if (!isBullishMove && !isBearishMove) Print("IdentifyOrderBlock: Move not strong enough vs 1.5*ATR at startBar ", startBar); // Optional debug print
   } else {
      // Check simply if close is beyond the range (without ATR)
      isBullishMove = (nextClose > high);
      isBearishMove = (nextClose < low);
      // if (!isBullishMove && !isBearishMove) Print("IdentifyOrderBlock: Move not beyond consolidation range at startBar ", startBar); // Optional debug print
   }

   if (isBullishMove) { // Bullish move identified
      if(blockCount >= ArraySize(orderBlocks)) ArrayResize(orderBlocks, blockCount + 100);
      orderBlocks[blockCount].high = high;
      orderBlocks[blockCount].low = low;
      orderBlocks[blockCount].isBullish = true;
      orderBlocks[blockCount].mitigated = false;
      orderBlocks[blockCount].barIndex = startBar; // Store the start of the consolidation
      orderBlocks[blockCount].hasEntrySignal = false;
      orderBlocks[blockCount].entryLevel = 0;
      blockCount++;
      Print("IdentifyOrderBlock: Bullish OB identified starting at bar ", startBar, ". High: ", high, ", Low: ", low); // Added Print
      return true;
   }
   else if (isBearishMove) { // Bearish move identified
      if(blockCount >= ArraySize(orderBlocks)) ArrayResize(orderBlocks, blockCount + 100);
      orderBlocks[blockCount].high = high;
      orderBlocks[blockCount].low = low;
      orderBlocks[blockCount].isBullish = false;
      orderBlocks[blockCount].mitigated = false;
      orderBlocks[blockCount].barIndex = startBar; // Store the start of the consolidation
      orderBlocks[blockCount].hasEntrySignal = false;
      orderBlocks[blockCount].entryLevel = 0;
      blockCount++;
      Print("IdentifyOrderBlock: Bearish OB identified starting at bar ", startBar, ". High: ", high, ", Low: ", low); // Added Print
      return true;
   }
   
   return false; // No qualifying move found
}

//+------------------------------------------------------------------+
//| Check Mitigation and Rejection Signals                           |
//+------------------------------------------------------------------+
void CheckMitigation() {
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);

   for(int i = 0; i < blockCount; i++) {
      if(orderBlocks[i].mitigated) continue;

      // Check for full mitigation
      if((orderBlocks[i].isBullish && close1 < orderBlocks[i].low) ||
         (!orderBlocks[i].isBullish && close1 > orderBlocks[i].high)) {
         orderBlocks[i].mitigated = true;
         UpdateVisualization(i);
         Print("Order Block at bar ", orderBlocks[i].barIndex, (orderBlocks[i].isBullish ? " (Bullish)" : " (Bearish)"), " Mitigated.");
         continue;
      }

      // Check if previous bar was within the Order Block
      double high1 = iHigh(_Symbol, PERIOD_CURRENT, 1);
      double low1 = iLow(_Symbol, PERIOD_CURRENT, 1);
      if(high1 <= orderBlocks[i].high && low1 >= orderBlocks[i].low) {
         // Check for rejection signal
         if(orderBlocks[i].isBullish && IsBullishRejection(1)) {
            orderBlocks[i].hasEntrySignal = true;
            orderBlocks[i].entryLevel = high1;
            Print("Bullish Rejection Signal detected in OB at bar ", orderBlocks[i].barIndex, ". Entry Level set to: ", high1);
         }
         else if(!orderBlocks[i].isBullish && IsBearishRejection(1)) {
            orderBlocks[i].hasEntrySignal = true;
            orderBlocks[i].entryLevel = low1;
            Print("Bearish Rejection Signal detected in OB at bar ", orderBlocks[i].barIndex, ". Entry Level set to: ", low1);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Bullish Rejection Signal Detection                               |
//+------------------------------------------------------------------+
bool IsBullishRejection(int index) {
   double high = iHigh(_Symbol, PERIOD_CURRENT, index);
   double low = iLow(_Symbol, PERIOD_CURRENT, index);
   double open = iOpen(_Symbol, PERIOD_CURRENT, index);
   double close = iClose(_Symbol, PERIOD_CURRENT, index);
   double range = high - low;
   if(range == 0) return false;

   double bodyLow = MathMin(open, close);
   return (bodyLow > low + 0.7 * range) && (MathMax(open, close) - bodyLow < 0.3 * range);
}

//+------------------------------------------------------------------+
//| Bearish Rejection Signal Detection                               |
//+------------------------------------------------------------------+
bool IsBearishRejection(int index) {
   double high = iHigh(_Symbol, PERIOD_CURRENT, index);
   double low = iLow(_Symbol, PERIOD_CURRENT, index);
   double open = iOpen(_Symbol, PERIOD_CURRENT, index);
   double close = iClose(_Symbol, PERIOD_CURRENT, index);
   double range = high - low;
   if(range == 0) return false;

   double bodyHigh = MathMax(open, close);
   return (bodyHigh < high - 0.7 * range) && (bodyHigh - MathMin(open, close) < 0.3 * range);
}

//+------------------------------------------------------------------+
//| Confirm Market Structure on Higher Timeframe                     |
//+------------------------------------------------------------------+
bool ConfirmMarketStructure(bool isBullish) {
   double h4SMA = GetMA(MAPeriod, 0, MODE_SMA, PRICE_CLOSE);
   double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
   return (isBullish && currentPrice > h4SMA) || (!isBullish && currentPrice < h4SMA);
}

//+------------------------------------------------------------------+
//| Execute Trades                                                   |
//+------------------------------------------------------------------+
void ExecuteTrades() {
   double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);

   for(int i = 0; i < blockCount; i++) {
      if(!orderBlocks[i].hasEntrySignal || orderBlocks[i].mitigated) continue;

      bool tradeCondition = (orderBlocks[i].isBullish && currentPrice >= orderBlocks[i].entryLevel) ||
                            (!orderBlocks[i].isBullish && currentPrice <= orderBlocks[i].entryLevel);

      if(tradeCondition && ConfirmMarketStructure(orderBlocks[i].isBullish)) {
         double entry = currentPrice;
         double sl, tp;
         double atr = GetATR(ATRPeriod, 0);

         if(orderBlocks[i].isBullish) {
            sl = orderBlocks[i].low - atr * ATRMultiplier;
            tp = entry + (entry - sl) * RRRatio;
            PlaceTrade(ORDER_TYPE_BUY, entry, sl, tp, i);
         }
         else {
            sl = orderBlocks[i].high + atr * ATRMultiplier;
            tp = entry - (sl - entry) * RRRatio;
            PlaceTrade(ORDER_TYPE_SELL, entry, sl, tp, i);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Place Trade with Risk Management                                 |
//+------------------------------------------------------------------+
void PlaceTrade(ENUM_ORDER_TYPE type, double entry, double sl, double tp, int blockIndex) {
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double stopLossDistance = MathAbs(entry - sl);
   double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent / 100.0;
   double riskPerLot = (stopLossDistance / tickSize) * tickValue;
   double lotSize = NormalizeDouble(riskAmount / riskPerLot, 2);

   if(lotSize < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) return;

   CTrade trade;
   if(type == ORDER_TYPE_BUY) {
      if(trade.Buy(lotSize, _Symbol, entry, sl, tp, "Bullish OB Trade")) {
         orderBlocks[blockIndex].mitigated = true;
         orderBlocks[blockIndex].hasEntrySignal = false;
         UpdateVisualization(blockIndex);
      }
   }
   else {
      if(trade.Sell(lotSize, _Symbol, entry, sl, tp, "Bearish OB Trade")) {
         orderBlocks[blockIndex].mitigated = true;
         orderBlocks[blockIndex].hasEntrySignal = false;
         UpdateVisualization(blockIndex);
      }
   }
}

//+------------------------------------------------------------------+
//| Check Daily Loss Limit                                           |
//+------------------------------------------------------------------+
void CheckDailyLossLimit() {
   datetime currentTime = TimeCurrent();
   int currentDay = DayOfYear(currentTime);

   if(currentDay != lastDay) {
      startOfDayEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      lastDay = currentDay;
      tradingAllowed = true;
   }

   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(currentEquity < startOfDayEquity * (1 - MaxDailyLoss / 100.0)) {
      tradingAllowed = false;
   }
}

//+------------------------------------------------------------------+
//| Visualize Order Block on Chart                                   |
//+------------------------------------------------------------------+
void VisualizeOrderBlock(int index) {
   string name = "OB_" + IntegerToString(orderBlocks[index].barIndex);
   datetime timeStart = iTime(_Symbol, PERIOD_CURRENT, orderBlocks[index].barIndex);
   datetime timeEnd = iTime(_Symbol, PERIOD_CURRENT, MathMax(0, orderBlocks[index].barIndex - ConsolidationPeriod)); // Ensure index isn't negative

   ObjectCreate(0, name, OBJ_RECTANGLE, 0, timeStart, orderBlocks[index].high, timeEnd, orderBlocks[index].low);
   ObjectSetInteger(0, name, OBJPROP_COLOR, orderBlocks[index].isBullish ? clrLightGreen : clrLightPink);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true); // Draw behind price
   ObjectSetString(0, name, OBJPROP_TOOLTIP, (orderBlocks[index].isBullish ? "Bullish OB" : "Bearish OB") + "\nStart Bar: " + IntegerToString(orderBlocks[index].barIndex));
}

//+------------------------------------------------------------------+
//| Update Visualization When Mitigated                              |
//+------------------------------------------------------------------+
void UpdateVisualization(int index) {
   string name = "OB_" + IntegerToString(orderBlocks[index].barIndex);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrGray);
}

//+------------------------------------------------------------------+
//| Expert Deinitialization Function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   // Release indicator handles
   if(atrHandle != INVALID_HANDLE) {
      IndicatorRelease(atrHandle);
      atrHandle = INVALID_HANDLE;
   }
   
   if(maHandle != INVALID_HANDLE) {
      IndicatorRelease(maHandle);
      maHandle = INVALID_HANDLE;
   }
   
   // Clean up chart objects
   for(int i = 0; i < blockCount; i++) {
      string name = "OB_" + IntegerToString(orderBlocks[i].barIndex);
      ObjectDelete(0, name);
   }
}