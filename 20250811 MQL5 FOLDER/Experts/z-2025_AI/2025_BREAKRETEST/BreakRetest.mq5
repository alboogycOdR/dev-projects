#include <Trade\Trade.mqh>

//--- Inputs
input double lotSize = 0.1;                  // Lot size for trades
input int retestPips = 10;                   // Proximity in pips for retest detection
input int maxBarsForRetest = 10;             // Max bars to wait for a retest
input bool useVolumeConfirmation = true;     // Use volume confirmation for breakouts
input double volumeMultiplier = 1.5;         // Volume must be this times the average volume
input int volumePeriod = 20;                 // Period for average volume calculation
input bool useCandlestickConfirmation = true;// Use candlestick patterns for confirmation
input bool useEngulfingPattern = true;       // Use engulfing patterns for retest confirmation (configurable)
input bool singlePosition = true;            // Allow only one open position at a time (configurable)

//--- Global variables
double resistanceLevels[];
double supportLevels[];
struct BrokenLevel {
   double price;
   bool isResistance;
   int breakBarIndex;
};
BrokenLevel brokenLevels[];
CTrade trade;
int handleVolume;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   // Placeholder for dynamic levels (to be provided by your indicator)
   ArrayResize(supportLevels, 3);
   ArrayResize(resistanceLevels, 3);
   supportLevels[0] = 1.2000;  // Example levels
   supportLevels[1] = 1.1900;
   supportLevels[2] = 1.1800;
   resistanceLevels[0] = 1.2100;
   resistanceLevels[1] = 1.2200;
   resistanceLevels[2] = 1.2300;

   // Initialize volume handle
   if (useVolumeConfirmation) {
      handleVolume = iVolumes(_Symbol, Period(), VOLUME_TICK);
      if (handleVolume == INVALID_HANDLE) {
         Print("Failed to create volume handle");
         return INIT_FAILED;
      }
   }

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   if (useVolumeConfirmation && handleVolume != INVALID_HANDLE) IndicatorRelease(handleVolume);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, Period(), 0);
   if (currentBarTime != lastBarTime) {
      lastBarTime = currentBarTime;
      double closePrice = iClose(_Symbol, Period(), 1);
      double openPrice = iOpen(_Symbol, Period(), 1);
      double highPrice = iHigh(_Symbol, Period(), 1);
      double lowPrice = iLow(_Symbol, Period(), 1);

      // Check for resistance breaks
      for (int i = 0; i < ArraySize(resistanceLevels); i++) {
         double level = resistanceLevels[i];
         if (closePrice > level && iClose(_Symbol, Period(), 2) <= level) {
            if (ConfirmBreakout(true, highPrice, lowPrice, closePrice, openPrice)) {
               BrokenLevel bl;
               bl.price = level;
               bl.isResistance = true;
               bl.breakBarIndex = iBars(_Symbol, Period()) - 1;
               ArrayResize(brokenLevels, ArraySize(brokenLevels) + 1);
               brokenLevels[ArraySize(brokenLevels) - 1] = bl;
               Print("Resistance broken at: ", DoubleToString(level, _Digits));
            }
         }
      }

      // Check for support breaks
      for (int i = 0; i < ArraySize(supportLevels); i++) {
         double level = supportLevels[i];
         if (closePrice < level && iClose(_Symbol, Period(), 2) >= level) {
            if (ConfirmBreakout(false, highPrice, lowPrice, closePrice, openPrice)) {
               BrokenLevel bl;
               bl.price = level;
               bl.isResistance = false;
               bl.breakBarIndex = iBars(_Symbol, Period()) - 1;
               ArrayResize(brokenLevels, ArraySize(brokenLevels) + 1);
               brokenLevels[ArraySize(brokenLevels) - 1] = bl;
               Print("Support broken at: ", DoubleToString(level, _Digits));
            }
         }
      }

      // Check for retests
      CheckRetests();
   }
}

//+------------------------------------------------------------------+
//| Confirm breakout function                                        |
//+------------------------------------------------------------------+
bool ConfirmBreakout(bool isResistance, double high, double low, double close, double open) {
   bool volumeConfirmed = true;
   if (useVolumeConfirmation) {
      double volume[];
      ArraySetAsSeries(volume, true);
      CopyBuffer(handleVolume, 0, 1, volumePeriod + 1, volume);
      double currentVolume = volume[0];
      double sum = 0;
      for (int i = 1; i <= volumePeriod; i++) sum += volume[i];
      double avgVolume = sum / volumePeriod;
      volumeConfirmed = currentVolume > avgVolume * volumeMultiplier;
   }

   bool candleConfirmed = true;
   if (useCandlestickConfirmation) {
      if (isResistance) {
         candleConfirmed = (close > open && (close - open) > (high - low) * 0.5);
      } else {
         candleConfirmed = (close < open && (open - close) > (high - low) * 0.5);
      }
   }

   return volumeConfirmed && candleConfirmed;
}

//+------------------------------------------------------------------+
//| Check retests function                                           |
//+------------------------------------------------------------------+
void CheckRetests() {
   for (int i = ArraySize(brokenLevels) - 1; i >= 0; i--) {
      BrokenLevel bl = brokenLevels[i];
      int barsSinceBreak = iBars(_Symbol, Period()) - 1 - bl.breakBarIndex;
      if (barsSinceBreak > maxBarsForRetest) {
         ArrayRemove(brokenLevels, i, 1);
         continue;
      }

      double low = iLow(_Symbol, Period(), 1);
      double high = iHigh(_Symbol, Period(), 1);
      double open = iOpen(_Symbol, Period(), 1);
      double close = iClose(_Symbol, Period(), 1);
      double pipRange = retestPips * _Point;

      if (bl.isResistance) {
         // Broken resistance, now support: bullish retest
         if (low >= bl.price - pipRange && low <= bl.price + pipRange && close > open) {
            if (ConfirmRetest(true, close, open, high, low)) {
               if (singlePosition && PositionSelect(_Symbol)) continue;
               double sl = NormalizeDouble(low - 10 * _Point, _Digits);
               double tp = NormalizeDouble(bl.price + 50 * _Point, _Digits); // Example TP
               trade.Buy(lotSize, _Symbol, 0, sl, tp);
               Print("Buy executed after resistance retest at: ", DoubleToString(bl.price, _Digits));
               ArrayRemove(brokenLevels, i, 1);
            }
         }
      } else {
         // Broken support, now resistance: bearish retest
         if (high >= bl.price - pipRange && high <= bl.price + pipRange && close < open) {
            if (ConfirmRetest(false, close, open, high, low)) {
               if (singlePosition && PositionSelect(_Symbol)) continue;
               double sl = NormalizeDouble(high + 10 * _Point, _Digits);
               double tp = NormalizeDouble(bl.price - 50 * _Point, _Digits); // Example TP
               trade.Sell(lotSize, _Symbol, 0, sl, tp);
               Print("Sell executed after support retest at: ", DoubleToString(bl.price, _Digits));
               ArrayRemove(brokenLevels, i, 1);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Confirm retest function                                          |
//+------------------------------------------------------------------+
bool ConfirmRetest(bool isBuy, double close, double open, double high, double low) {
   bool candleConfirmed = true;
   if (useCandlestickConfirmation) {
      if (isBuy) {
         bool hammer = (close > open && (open - low) > (close - open) * 2);
         bool engulfing = useEngulfingPattern && IsBullishEngulfing(1);
         candleConfirmed = hammer || engulfing;
      } else {
         bool shootingStar = (close < open && (high - open) > (open - close) * 2);
         bool engulfing = useEngulfingPattern && IsBearishEngulfing(1);
         candleConfirmed = shootingStar || engulfing;
      }
   }
   return candleConfirmed;
}

//+------------------------------------------------------------------+
//| Bullish engulfing pattern detection                              |
//+------------------------------------------------------------------+
bool IsBullishEngulfing(int shift) {
   double prevOpen = iOpen(_Symbol, Period(), shift + 1);
   double prevClose = iClose(_Symbol, Period(), shift + 1);
   double currOpen = iOpen(_Symbol, Period(), shift);
   double currClose = iClose(_Symbol, Period(), shift);
   return prevClose < prevOpen && currClose > currOpen && currClose > prevOpen && currOpen < prevClose;
}

//+------------------------------------------------------------------+
//| Bearish engulfing pattern detection                              |
//+------------------------------------------------------------------+
bool IsBearishEngulfing(int shift) {
   double prevOpen = iOpen(_Symbol, Period(), shift + 1);
   double prevClose = iClose(_Symbol, Period(), shift + 1);
   double currOpen = iOpen(_Symbol, Period(), shift);
   double currClose = iClose(_Symbol, Period(), shift);
   return prevClose > prevOpen && currClose < currOpen && currClose < prevOpen && currOpen > prevClose;
}

//+------------------------------------------------------------------+
//| Array remove function                                            |
//+------------------------------------------------------------------+
void ArrayRemove(BrokenLevel &arr[], int index, int count) {
   int size = ArraySize(arr);
   if (index < 0 || index + count > size) return;
   for (int i = index; i < size - count; i++) {
      arr[i] = arr[i + count];
   }
   ArrayResize(arr, size - count);
}