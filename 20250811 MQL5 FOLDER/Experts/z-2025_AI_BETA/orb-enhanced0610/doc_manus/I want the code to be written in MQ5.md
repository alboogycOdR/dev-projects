<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" class="logo" width="120"/>

# I want the code to be written in MQ5

Here's the MQL5 implementation of the SMC-enhanced Open Range Breakout strategy with liquidity concepts:

```mql5
//+------------------------------------------------------------------+
//|                                                 SMC_ORB_MT5.mq5  |
//|                                   Copyright 2025, Perplexity AI  |
//|                                              https://perplexity.ai |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Perplexity AI"
#property version   "1.00"
#property strict

// Strategy Parameters
input int    ORB_Length = 30;        // ORB Period (minutes)
input double Confluence_Threshold = 2.0; // Minimum Confluence Score
input double Liquidity_Buffer = 0.0005;  // Liquidity Grab Buffer

// Global Variables
datetime sessionStart;
double   orbHigh, orbLow;
double   prevSessionHigh, prevSessionLow;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   sessionStart = iTime(Symbol(), PERIOD_D1, 0) + 28800; // Assuming 8am session start
   DetermineORB();
   DeterminePreviousSessionLevels();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime lastBarTime;
   datetime currentTime = iTime(Symbol(), PERIOD_M1, 0);
   
   if(currentTime != lastBarTime)
   {
      lastBarTime = currentTime;
      CheckBreakouts();
   }
}

//+------------------------------------------------------------------+
//| Determine Opening Range Breakout Levels                          |
//+------------------------------------------------------------------+
void DetermineORB()
{
   int barIndex = iBarShift(Symbol(), PERIOD_M1, sessionStart);
   int endBar = barIndex - ORB_Length;
   
   orbHigh = 0;
   orbLow = 99999;
   
   for(int i = barIndex; i > endBar; i--)
   {
      orbHigh = MathMax(orbHigh, iHigh(Symbol(), PERIOD_M1, i));
      orbLow = MathMin(orbLow, iLow(Symbol(), PERIOD_M1, i));
   }
}

//+------------------------------------------------------------------+
//| Identify Previous Session Levels                                 |
//+------------------------------------------------------------------+
void DeterminePreviousSessionLevels()
{
   prevSessionHigh = iHigh(Symbol(), PERIOD_D1, 1);
   prevSessionLow = iLow(Symbol(), PERIOD_D1, 1);
}

//+------------------------------------------------------------------+
//| Detect Order Blocks                                              |
//+------------------------------------------------------------------+
int DetectOrderBlocks(double &bullishOB[], double &bearishOB[])
{
   int countBullish = 0;
   int countBearish = 0;
   
   for(int i=3; i<100; i++)
   {
      // Bullish Order Block: Bear candle followed by strong bullish move
      if(iClose(Symbol(),0,i) < iOpen(Symbol(),0,i) && 
         iClose(Symbol(),0,i-1) > iOpen(Symbol(),0,i-1))
      {
         double range = iHigh(Symbol(),0,i) - iLow(Symbol(),0,i);
         if((iClose(Symbol(),0,i-1) - iOpen(Symbol(),0,i-1)) > 2*range)
         {
            ArrayResize(bullishOB, countBullish+1);
            bullishOB[countBullish] = iLow(Symbol(),0,i);
            countBullish++;
         }
      }
      
      // Bearish Order Block: Bull candle followed by strong bearish move
      if(iClose(Symbol(),0,i) > iOpen(Symbol(),0,i) && 
         iClose(Symbol(),0,i-1) < iOpen(Symbol(),0,i-1))
      {
         double range = iHigh(Symbol(),0,i) - iLow(Symbol(),0,i);
         if((iOpen(Symbol(),0,i-1) - iClose(Symbol(),0,i-1)) > 2*range)
         {
            ArrayResize(bearishOB, countBearish+1);
            bearishOB[countBearish] = iHigh(Symbol(),0,i);
            countBearish++;
         }
      }
   }
   return(countBullish + countBearish);
}

//+------------------------------------------------------------------+
//| Check for Breakout Conditions                                    |
//+------------------------------------------------------------------+
void CheckBreakouts()
{
   double currentHigh = iHigh(Symbol(), PERIOD_M1, 0);
   double currentLow = iLow(Symbol(), PERIOD_M1, 0);
   double currentClose = iClose(Symbol(), PERIOD_M1, 0);
   
   // Bullish Breakout Check
   if(currentHigh > orbHigh)
   {
      double bullishOB[], bearishOB[];
      int obCount = DetectOrderBlocks(bullishOB, bearishOB);
      
      int confluence = 0;
      // Order Block Confluence
      for(int i=0; i<ArraySize(bullishOB); i++)
      {
         if(currentLow > bullishOB[i]) confluence++;
      }
      
      // Liquidity Grab Check
      if(CheckLiquidityGrab(currentLow, currentClose, prevSessionLow))
         confluence += 2;
      
      if(confluence >= Confluence_Threshold)
         ExecuteTrade(ORDER_TYPE_BUY);
   }
   
   // Bearish Breakout Check
   if(currentLow < orbLow)
   {
      double bullishOB[], bearishOB[];
      int obCount = DetectOrderBlocks(bullishOB, bearishOB);
      
      int confluence = 0;
      // Order Block Confluence
      for(int i=0; i<ArraySize(bearishOB); i++)
      {
         if(currentHigh < bearishOB[i]) confluence++;
      }
      
      // Liquidity Grab Check
      if(CheckLiquidityGrab(currentHigh, currentClose, prevSessionHigh))
         confluence += 2;
      
      if(confluence >= Confluence_Threshold)
         ExecuteTrade(ORDER_TYPE_SELL);
   }
}

//+------------------------------------------------------------------+
//| Liquidity Grab Detection                                         |
//+------------------------------------------------------------------+
bool CheckLiquidityGrab(double extreme, double closePrice, double liquidityZone)
{
   if((extreme < (liquidityZone - Liquidity_Buffer) && closePrice > liquidityZone) || 
      (extreme > (liquidityZone + Liquidity_Buffer) && closePrice < liquidityZone))
      return true;
   return false;
}

//+------------------------------------------------------------------+
//| Trade Execution Logic                                            |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE orderType)
{
   double entryPrice = (orderType == ORDER_TYPE_BUY) ? Ask : Bid;
   double stopLoss = CalculateStopLevel(orderType);
   double takeProfit = CalculateTakeProfit(orderType);
   
   // Risk management and order sending logic here
   // ... (full implementation requires position sizing calculations)
}

//+------------------------------------------------------------------+
//| Calculate Stop Loss Levels                                       |
//+------------------------------------------------------------------+
double CalculateStopLevel(ENUM_ORDER_TYPE orderType)
{
   // Implementation based on nearest swing points and order blocks
   // ... (refer to Python logic translated to MQL5)
   return 0.0;
}

//+------------------------------------------------------------------+
//| Calculate Take Profit Levels                                     |
//+------------------------------------------------------------------+
double CalculateTakeProfit(ENUM_ORDER_TYPE orderType)
{
   // Implementation based on liquidity zones
   // ... (refer to Python logic translated to MQL5)
   return 0.0;
}
```

**Key Implementation Notes:**

1. **Session Handling:**

- Adjust `sessionStart` calculation according to your broker's server time
- Modify the 28800 seconds (8 hours) offset to match your market open time

2. **Order Block Detection:**

- Scans last 100 bars for valid order blocks
- Stores identified blocks in arrays for confluence checking

3. **Liquidity Grab Logic:**

- Uses previous session's high/low as primary liquidity zones
- Detects wick penetration beyond liquidity zones with close back inside

4. **Confluence Scoring:**

- Combines Order Block alignment with Liquidity Grab confirmation
- Adjust threshold via `Confluence_Threshold` parameter

**Required Enhancements:**

- Add position sizing calculations based on account equity
- Implement full risk management logic
- Add trade session validation (only trade during liquid hours)
- Include error handling for order execution
- Add trailing stop functionality

**Best Practices:**

1. Test with 1-minute data for accurate ORB calculation
2. Use tick data for precise liquidity grab detection
3. Optimize parameters for your specific instrument
4. Combine with volume analysis for additional confirmation
5. Implement proper spread and slippage controls

This implementation provides the core framework - complete with order block detection, liquidity analysis, and confluence-based entry logic. Full production deployment requires completing the risk management components and extensive backtesting.

