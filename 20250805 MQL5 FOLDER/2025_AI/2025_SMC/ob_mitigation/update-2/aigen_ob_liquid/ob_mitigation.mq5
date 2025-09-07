
//https://x.com/i/grok?conversation=1908116504559616228


//Below is a complete MQL5 Expert Advisor (EA) implementation based on the Mitigation Order Blocks Strategy, as per your requirements. 
//The EA identifies Order Blocks, validates mitigation events, confirms market structure, executes trades with proper risk management, and includes visualization
// for debugging. I'll structure it modularly for clarity and maintainability, with detailed comments explaining each section.
//mql5




//+------------------------------------------------------------------+
//| Expert Advisor: Mitigation Order Blocks Strategy                 |
//+------------------------------------------------------------------+

// Input Parameters
input int LookbackPeriod = 500;        // Lookback period for Order Block identification
input int ConsolidationPeriod = 20;    // Number of bars to check for consolidation
input int ATRPeriod = 14;              // ATR period for volatility measurement
input double ATRMultiplier = 1.5;      // ATR multiplier for stop loss adjustment
input double RRRatio = 2.0;            // Risk-reward ratio for take profit
input double RiskPercent = 1.0;        // Risk percentage per trade
input double MaxDailyLoss = 5.0;       // Maximum daily loss percentage
input int MAPeriod = 20;               // Moving average period for market structure

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

//+------------------------------------------------------------------+
//| Expert Initialization Function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   // Resize the Order Blocks array
   ArrayResize(orderBlocks, 100);
   blockCount = 0;

   // Initialize daily equity tracking
   startOfDayEquity = AccountEquity();
   lastDay = DayOfYear(TimeCurrent());

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
   double high = iHigh(_Symbol, PERIOD_CURRENT, startBar);
   double low = iLow(_Symbol, PERIOD_CURRENT, startBar);
   double atr = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod, startBar);

   // Check for consolidation
   for(int i = startBar; i > startBar - ConsolidationPeriod; i--) {
      double h = iHigh(_Symbol, PERIOD_CURRENT, i);
      double l = iLow(_Symbol, PERIOD_CURRENT, i);
      high = MathMax(high, h);
      low = MathMin(low, l);
      if(high - low > 0.5 * atr) return false; // Range too large
   }

   // Check for strong move after consolidation
   double nextClose = iClose(_Symbol, PERIOD_CURRENT, startBar - ConsolidationPeriod - 1);
   if(nextClose - high > 1.5 * atr) { // Bullish move
      if(blockCount >= ArraySize(orderBlocks)) ArrayResize(orderBlocks, blockCount + 100);
      orderBlocks[blockCount].high = high;
      orderBlocks[blockCount].low = low;
      orderBlocks[blockCount].isBullish = true;
      orderBlocks[blockCount].mitigated = false;
      orderBlocks[blockCount].barIndex = startBar;
      orderBlocks[blockCount].hasEntrySignal = false;
      orderBlocks[blockCount].entryLevel = 0;
      blockCount++;
      return true;
   }
   else if(low - nextClose > 1.5 * atr) { // Bearish move
      if(blockCount >= ArraySize(orderBlocks)) ArrayResize(orderBlocks, blockCount + 100);
      orderBlocks[blockCount].high = high;
      orderBlocks[blockCount].low = low;
      orderBlocks[blockCount].isBullish = false;
      orderBlocks[blockCount].mitigated = false;
      orderBlocks[blockCount].barIndex = startBar;
      orderBlocks[blockCount].hasEntrySignal = false;
      orderBlocks[blockCount].entryLevel = 0;
      blockCount++;
      return true;
   }
   return false;
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
         }
         else if(!orderBlocks[i].isBullish && IsBearishRejection(1)) {
            orderBlocks[i].hasEntrySignal = true;
            orderBlocks[i].entryLevel = low1;
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
   double h4SMA = iMA(_Symbol, PERIOD_H4, MAPeriod, 0, MODE_SMA, PRICE_CLOSE, 0);
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
         double atr = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod, 0);

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
   double riskAmount = AccountBalance() * RiskPercent / 100.0;
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
      startOfDayEquity = AccountEquity();
      lastDay = currentDay;
      tradingAllowed = true;
   }

   double currentEquity = AccountEquity();
   if(currentEquity < startOfDayEquity * (1 - MaxDailyLoss / 100.0)) {
      tradingAllowed = false;
   }
}

//+------------------------------------------------------------------+
//| Visualize Order Block on Chart                                   |
//+------------------------------------------------------------------+
void VisualizeOrderBlock(int index) {
   string name = "OB_" + IntegerToString(orderBlocks[index].barIndex);
   ObjectCreate(0, name, OBJ_RECTANGLE, 0,
                iTime(_Symbol, PERIOD_CURRENT, orderBlocks[index].barIndex),
                orderBlocks[index].high,
                iTime(_Symbol, PERIOD_CURRENT, orderBlocks[index].barIndex - ConsolidationPeriod),
                orderBlocks[index].low);
   ObjectSetInteger(0, name, OBJPROP_COLOR, orderBlocks[index].isBullish ? clrLightGreen : clrLightPink);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
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
   // Clean up chart objects
   for(int i = 0; i < blockCount; i++) {
      string name = "OB_" + IntegerToString(orderBlocks[i].barIndex);
      ObjectDelete(0, name);
   }
}
//Explanation of the EA
//Input Parameters
//LookbackPeriod: Number of bars to scan for initial Order Blocks.
//ConsolidationPeriod: Bars to check for a tight consolidation range.
//ATRPeriod and ATRMultiplier: Used for volatility-based stop loss adjustment.
//RRRatio: Risk-reward ratio for take profit.
//RiskPercent: Percentage of account balance to risk per trade.
//MaxDailyLoss: Daily loss limit to stop trading.
//MAPeriod: Moving average period for market structure confirmation.
//Order Block Identification
//IdentifyOrderBlock: Scans for consolidation (range < 0.5 * ATR) followed by a strong move (> 1.5 * ATR). Adds new Order Blocks to the orderBlocks array with properties like high, low, and type.
//Mitigation Validation
//CheckMitigation: Checks if the previous bar closed beyond an Order Block (full mitigation) or was within it with a rejection signal (partial mitigation). Rejection is detected using IsBullishRejection or IsBearishRejection, which look for candles with long wicks and small bodies.
//Market Structure Confirmation
//ConfirmMarketStructure: Uses a 20-period SMA on the H4 timeframe to ensure trades align with the broader trend (price above SMA for bullish, below for bearish).
//Trade Execution
//ExecuteTrades: Monitors the current price against entry levels set after rejection signals. If the price breaks the entry level and the market structure aligns, it places a trade with calculated stop loss (beyond Order Block adjusted by ATR) and take profit (based on RRRatio).
//Risk Management
//PlaceTrade: Calculates lot size to risk a fixed percentage of the account balance, considering stop loss distance and tick value. Uses the CTrade class for trade execution.
//Daily Loss Limit
//CheckDailyLossLimit: Tracks equity at the start of each day and stops trading if the loss exceeds the specified percentage.
//Visualization
//VisualizeOrderBlock: Draws rectangles on the chart for each Order Block (green for bullish, pink for bearish), turning gray when mitigated.
//Usage Instructions
//Compile the EA in MetaEditor and attach it to a chart (e.g., H1 timeframe recommended).
//Adjust Inputs: Modify the input parameters based on your preferences or testing results.
//Monitor: Check the chart for visualized Order Blocks and the Experts tab for trade logs.
//This EA fulfills the requirements of the Mitigation Order Blocks Strategy with a robust, modular design. You can further optimize it by adjusting parameters, adding filters (e.g., liquidity sweeps), or implementing additional features like trailing stops based on your trading needs.