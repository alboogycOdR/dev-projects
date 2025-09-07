#property copyright "Your Name"
#property link      "https://www.yourwebsite.com"
#property version   "1.00"
#include <Trade/Trade.mqh>

// Input Parameters
input int NYStartHourBrokerTime = 13;       // NY session start hour (broker time, e.g., 13:00 GMT)
input int NYEndHourBrokerTime = 22;         // NY session end hour (e.g., 22:00 GMT)
input int LookBackBars = 20;                // Bars to analyze for equal highs/lows
input double EqualLevelBinSize = 10;        // Bin size for equal levels (points)
input int MaxBarsForSweep = 3;              // Max bars for sweep confirmation
input int OrderBlockLookBack = 50;          // Bars to look back for order blocks
input double ConfluenceThreshold = 20;      // Confluence threshold (points)
input double StopLossBuffer = 10;           // Stop-loss buffer (points)
input double RiskRewardRatio = 2.0;         // Risk-reward ratio
input double LotSize = 0.1;                 // Fixed lot size
input int MagicNumber = 123456;             // Magic number for trades

CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   if (!IsNewBar(PERIOD_CURRENT)) return;   // Only trade on new bar
   if (!IsNYSession()) return;              // Restrict to NY session

   // Identify liquidity zones
   double equalLowLevel = FindEqualLowLevel(LookBackBars, EqualLevelBinSize);
   double equalHighLevel = FindEqualHighLevel(LookBackBars, EqualLevelBinSize);
   double orderBlockLow = FindOrderBlockLow(OrderBlockLookBack);
   double orderBlockHigh = FindOrderBlockHigh(OrderBlockLookBack);

   // Confluence checks
   bool bullishConfluence = equalLowLevel > 0 && orderBlockLow > 0 && 
                            MathAbs(equalLowLevel - orderBlockLow) < ConfluenceThreshold * _Point;
   bool bearishConfluence = equalHighLevel > 0 && orderBlockHigh > 0 && 
                            MathAbs(equalHighLevel - orderBlockHigh) < ConfluenceThreshold * _Point;

   // Price action confirmation
   bool bullishPin = IsPinBar(1) && iClose(_Symbol, PERIOD_CURRENT, 1) > iOpen(_Symbol, PERIOD_CURRENT, 1);
   bool bearishPin = IsPinBar(1) && iClose(_Symbol, PERIOD_CURRENT, 1) < iOpen(_Symbol, PERIOD_CURRENT, 1);

   // Bullish liquidity sweep trade
   if (bullishConfluence && IsBullishSweep(equalLowLevel, MaxBarsForSweep) && bullishPin)
   {
      double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = equalLowLevel - StopLossBuffer * _Point;
      double tp = entryPrice + RiskRewardRatio * (entryPrice - sl);
      trade.Buy(LotSize, _Symbol, entryPrice, sl, tp, "Bullish Liquidity Sweep");
   }

   // Bearish liquidity sweep trade
   if (bearishConfluence && IsBearishSweep(equalHighLevel, MaxBarsForSweep) && bearishPin)
   {
      double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = equalHighLevel + StopLossBuffer * _Point;
      double tp = entryPrice - RiskRewardRatio * (sl - entryPrice);
      trade.Sell(LotSize, _Symbol, entryPrice, sl, tp, "Bearish Liquidity Sweep");
   }
}

//+------------------------------------------------------------------+
//| Helper Functions                                                  |
//+------------------------------------------------------------------+
// Check if within NY session
bool IsNYSession()
{
   MqlDateTime timeStruct;
   TimeToStruct(TimeCurrent(), timeStruct);
   int hour = timeStruct.hour;
   return hour >= NYStartHourBrokerTime && hour < NYEndHourBrokerTime;
}

// Check for new bar
bool IsNewBar(ENUM_TIMEFRAMES timeframe)
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, timeframe, 0);
   if (currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

// Find equal high level
double FindEqualHighLevel(int lookBackBars, double binSizePoints)
{
   double binSize = binSizePoints * _Point;
   double minHigh = iHigh(_Symbol, PERIOD_CURRENT, iLowest(_Symbol, PERIOD_CURRENT, MODE_HIGH, lookBackBars, 0));
   double maxHigh = iHigh(_Symbol, PERIOD_CURRENT, iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, lookBackBars, 0));
   if (minHigh == maxHigh) return minHigh;

   int bins = (int)MathCeil((maxHigh - minHigh) / binSize);
   int count[];
   ArrayResize(count, bins);
   ArrayInitialize(count, 0);

   for (int i = 0; i < lookBackBars; i++)
   {
      double high = iHigh(_Symbol, PERIOD_CURRENT, i);
      int binIndex = (int)MathFloor((high - minHigh) / binSize);
      if (binIndex >= 0 && binIndex < bins) count[binIndex]++;
   }

   int maxCount = 0;
   double equalHighLevel = 0;
   for (int j = 0; j < bins; j++)
   {
      if (count[j] > maxCount)
      {
         maxCount = count[j];
         equalHighLevel = minHigh + j * binSize + binSize / 2;
      }
   }
   return (maxCount >= 2) ? equalHighLevel : 0;
}

// Find equal low level
double FindEqualLowLevel(int lookBackBars, double binSizePoints)
{
   double binSize = binSizePoints * _Point;
   double minLow = iLow(_Symbol, PERIOD_CURRENT, iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, lookBackBars, 0));
   double maxLow = iLow(_Symbol, PERIOD_CURRENT, iHighest(_Symbol, PERIOD_CURRENT, MODE_LOW, lookBackBars, 0));
   if (minLow == maxLow) return minLow;

   int bins = (int)MathCeil((maxLow - minLow) / binSize);
   int count[];
   ArrayResize(count, bins);
   ArrayInitialize(count, 0);

   for (int i = 0; i < lookBackBars; i++)
   {
      double low = iLow(_Symbol, PERIOD_CURRENT, i);
      int binIndex = (int)MathFloor((low - minLow) / binSize);
      if (binIndex >= 0 && binIndex < bins) count[binIndex]++;
   }

   int maxCount = 0;
   double equalLowLevel = 0;
   for (int j = 0; j < bins; j++)
   {
      if (count[j] > maxCount)
      {
         maxCount = count[j];
         equalLowLevel = minLow + j * binSize + binSize / 2;
      }
   }
   return (maxCount >= 2) ? equalLowLevel : 0;
}

// Find order block high
double FindOrderBlockHigh(int lookBackBars)
{
   return iHigh(_Symbol, PERIOD_CURRENT, iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, lookBackBars, 0));
}

// Find order block low
double FindOrderBlockLow(int lookBackBars)
{
   return iLow(_Symbol, PERIOD_CURRENT, iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, lookBackBars, 0));
}

// Check for bullish liquidity sweep
bool IsBullishSweep(double equalLowLevel, int maxBars)
{
   if (equalLowLevel == 0) return false;
   bool breached = false;
   for (int i = 1; i <= maxBars; i++)
   {
      if (iLow(_Symbol, PERIOD_CURRENT, i) < equalLowLevel)
      {
         breached = true;
         break;
      }
   }
   return breached && iClose(_Symbol, PERIOD_CURRENT, 0) > equalLowLevel;
}

// Check for bearish liquidity sweep
bool IsBearishSweep(double equalHighLevel, int maxBars)
{
   if (equalHighLevel == 0) return false;
   bool breached = false;
   for (int i = 1; i <= maxBars; i++)
   {
      if (iHigh(_Symbol, PERIOD_CURRENT, i) > equalHighLevel)
      {
         breached = true;
         break;
      }
   }
   return breached && iClose(_Symbol, PERIOD_CURRENT, 0) < equalHighLevel;
}

// Check for pin bar
bool IsPinBar(int shift)
{
   double body = MathAbs(iOpen(_Symbol, PERIOD_CURRENT, shift) - iClose(_Symbol, PERIOD_CURRENT, shift));
   double upperWick = iHigh(_Symbol, PERIOD_CURRENT, shift) - MathMax(iOpen(_Symbol, PERIOD_CURRENT, shift), iClose(_Symbol, PERIOD_CURRENT, shift));
   double lowerWick = MathMin(iOpen(_Symbol, PERIOD_CURRENT, shift), iClose(_Symbol, PERIOD_CURRENT, shift)) - iLow(_Symbol, PERIOD_CURRENT, shift);
   if (body == 0) return false;
   double wickToBodyRatio = MathMax(upperWick, lowerWick) / body;
   return wickToBodyRatio > 2.0;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Cleanup if needed
}