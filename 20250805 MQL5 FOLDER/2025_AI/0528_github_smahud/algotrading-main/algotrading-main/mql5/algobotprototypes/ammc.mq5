//+------------------------------------------------------------------+
//|                                            ETH_AMMC_Strategy.mq5 |
//|                                                       Created by |
//|                                        ETH Momentum & Convergence |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"

// Include necessary libraries
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Indicators\Trend.mqh>
#include <Indicators\Oscilators.mqh>

// Input parameters - Trading parameters
input double   LotSize = 0.1;              // Lot Size
input bool     EnableBuy = true;           // Enable Buy Signals
input bool     EnableSell = true;          // Enable Sell Signals
input int      MaxPositions = 1;           // Maximum Open Positions
input double   StopLossPercent = 1.5;      // Stop Loss (% of ATR)
input double   TakeProfitPercent = 3.0;    // Take Profit (% of ATR)
input bool     UseTrailingStop = true;     // Use Trailing Stop
input int      MagicNumber = 202503;       // Magic Number
input bool     CloseOnOppositeSignal = true; // Close on Opposite Signal
input int      CheckEveryXTicks = 10;      // Check signals every X ticks

// Input parameters - Timeframes
input ENUM_TIMEFRAMES StrategicTimeframe = PERIOD_D1;   // Strategic Timeframe (D1/W1)
input ENUM_TIMEFRAMES TacticalTimeframe = PERIOD_H4;    // Tactical Timeframe (H4)
input bool     ExecuteOnlyOnNewTacticalBar = true;      // Execute only on new tactical timeframe bar

// Input parameters - Technical indicators
input int      FastEMA = 21;               // Fast EMA Period
input int      MediumSMA = 50;             // Medium SMA Period
input int      SlowSMA = 200;              // Slow SMA Period
input int      RSI_Period = 14;            // RSI Period
input double   RSI_UpperLevel = 60;        // RSI Upper Level
input double   RSI_LowerLevel = 40;        // RSI Lower Level
input bool     UseMACD = true;             // Use MACD indicator
input int      MACD_FastEMA = 12;          // MACD Fast EMA Period
input int      MACD_SlowEMA = 26;          // MACD Slow EMA Period
input int      MACD_SignalPeriod = 9;      // MACD Signal Period
input int      ATR_Period = 14;            // ATR Period

// Input parameters - Ichimoku settings
input bool     UseIchimoku = true;         // Use Ichimoku Cloud indicator
input int      Tenkan_sen = 9;             // Ichimoku: Tenkan-sen period
input int      Kijun_sen = 26;             // Ichimoku: Kijun-sen period
input int      Senkou_Span_B = 52;         // Ichimoku: Senkou Span B period
input bool     UseDebugMode = true;        // Show detailed debug messages

// Global variables
CTrade         trade;                       // Trading object
CPositionInfo  positionInfo;                // Position information object

// Strategic timeframe indicators
int            strategicEMAHandle;          // Handle for Strategic EMA
int            strategicMediumSMAHandle;    // Handle for Strategic Medium SMA
int            strategicSlowSMAHandle;      // Handle for Strategic Slow SMA
int            strategicRSIHandle;          // Handle for Strategic RSI
double         strategicEMABuffer[];        // Buffer for Strategic EMA
double         strategicMediumSMABuffer[];  // Buffer for Strategic Medium SMA
double         strategicSlowSMABuffer[];    // Buffer for Strategic Slow SMA
double         strategicRSIBuffer[];        // Buffer for Strategic RSI

// Tactical timeframe indicators
int            tacticalEMAHandle;           // Handle for Tactical EMA
int            tacticalMediumSMAHandle;     // Handle for Tactical Medium SMA
int            tacticalSlowSMAHandle;       // Handle for Tactical Slow SMA
int            tacticalRSIHandle;           // Handle for Tactical RSI
int            macdHandle;                  // Handle for MACD indicator (Tactical)
int            ichimokuHandle;              // Handle for Ichimoku indicator (Tactical)
int            atrHandle;                   // Handle for ATR indicator (Tactical)
double         tacticalEMABuffer[];         // Buffer for Tactical EMA
double         tacticalMediumSMABuffer[];   // Buffer for Tactical Medium SMA
double         tacticalSlowSMABuffer[];     // Buffer for Tactical Slow SMA
double         tacticalRSIBuffer[];         // Buffer for Tactical RSI
double         macdMainBuffer[];            // Buffer for MACD Main values
double         macdSignalBuffer[];          // Buffer for MACD Signal values
double         macdHistBuffer[];            // Buffer for MACD Histogram values
double         atrBuffer[];                 // Buffer for ATR values
double         tenkanBuffer[];              // Buffer for Ichimoku Tenkan-sen
double         kijunBuffer[];               // Buffer for Ichimoku Kijun-sen
double         senkouABuffer[];             // Buffer for Ichimoku Senkou Span A
double         senkouBBuffer[];             // Buffer for Ichimoku Senkou Span B
double         chikouBuffer[];              // Buffer for Ichimoku Chikou Span

double         currentATR;                  // Current ATR value
datetime       lastTacticalBarTime;         // Last tactical timeframe bar time
datetime       lastChartBarTime;            // Last chart bar time
int            tickCounter = 0;             // Tick counter for optimization
bool           ichimokuAvailable = false;   // Flag to track if Ichimoku is available
bool           macdAvailable = false;       // Flag to track if MACD is available
int            warmupBars = 0;              // Number of bars to warm up indicators

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize trade object
   trade.SetExpertMagicNumber(MagicNumber);
   
   // Initialize STRATEGIC timeframe indicators
   strategicEMAHandle = iMA(_Symbol, StrategicTimeframe, FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   strategicMediumSMAHandle = iMA(_Symbol, StrategicTimeframe, MediumSMA, 0, MODE_SMA, PRICE_CLOSE);
   strategicSlowSMAHandle = iMA(_Symbol, StrategicTimeframe, SlowSMA, 0, MODE_SMA, PRICE_CLOSE);
   strategicRSIHandle = iRSI(_Symbol, StrategicTimeframe, RSI_Period, PRICE_CLOSE);
   
   // Initialize TACTICAL timeframe indicators
   tacticalEMAHandle = iMA(_Symbol, TacticalTimeframe, FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   tacticalMediumSMAHandle = iMA(_Symbol, TacticalTimeframe, MediumSMA, 0, MODE_SMA, PRICE_CLOSE);
   tacticalSlowSMAHandle = iMA(_Symbol, TacticalTimeframe, SlowSMA, 0, MODE_SMA, PRICE_CLOSE);
   tacticalRSIHandle = iRSI(_Symbol, TacticalTimeframe, RSI_Period, PRICE_CLOSE);
   
   // ATR for risk management (using tactical timeframe)
   atrHandle = iATR(_Symbol, TacticalTimeframe, ATR_Period);
   
   // Initialize MACD if enabled (using tactical timeframe)
   if(UseMACD) {
      macdHandle = iMACD(_Symbol, TacticalTimeframe, MACD_FastEMA, MACD_SlowEMA, MACD_SignalPeriod, PRICE_CLOSE);
   }
   
   // Initialize Ichimoku with user-defined parameters (using tactical timeframe)
   if(UseIchimoku) {
      ichimokuHandle = iIchimoku(_Symbol, TacticalTimeframe, 
                               Tenkan_sen,     // Tenkan-sen (conversion line)
                               Kijun_sen,      // Kijun-sen (base line)
                               Senkou_Span_B); // Senkou Span B period
   }
   
   // Check essential strategic indicators
   if(strategicEMAHandle == INVALID_HANDLE || 
      strategicMediumSMAHandle == INVALID_HANDLE || 
      strategicSlowSMAHandle == INVALID_HANDLE || 
      strategicRSIHandle == INVALID_HANDLE)
   {
      Print("Failed to create one or more strategic timeframe indicators");
      return(INIT_FAILED);
   }
   
   // Check essential tactical indicators
   if(tacticalEMAHandle == INVALID_HANDLE || 
      tacticalMediumSMAHandle == INVALID_HANDLE || 
      tacticalSlowSMAHandle == INVALID_HANDLE || 
      tacticalRSIHandle == INVALID_HANDLE || 
      atrHandle == INVALID_HANDLE)
   {
      Print("Failed to create one or more tactical timeframe indicators");
      return(INIT_FAILED);
   }
   
   // Check MACD if enabled
   if(UseMACD && macdHandle == INVALID_HANDLE)
   {
      Print("Warning: Failed to create MACD indicator. Strategy will run without MACD signals.");
   }
   
   // Check Ichimoku if enabled
   if(UseIchimoku && ichimokuHandle == INVALID_HANDLE)
   {
      Print("Warning: Failed to create Ichimoku indicator. Strategy will run without Ichimoku signals.");
   }
   
   // Set up buffer series
   // Strategic timeframe buffers
   ArraySetAsSeries(strategicEMABuffer, true);
   ArraySetAsSeries(strategicMediumSMABuffer, true);
   ArraySetAsSeries(strategicSlowSMABuffer, true);
   ArraySetAsSeries(strategicRSIBuffer, true);
   
   // Tactical timeframe buffers
   ArraySetAsSeries(tacticalEMABuffer, true);
   ArraySetAsSeries(tacticalMediumSMABuffer, true);
   ArraySetAsSeries(tacticalSlowSMABuffer, true);
   ArraySetAsSeries(tacticalRSIBuffer, true);
   ArraySetAsSeries(macdMainBuffer, true);
   ArraySetAsSeries(macdSignalBuffer, true);
   ArraySetAsSeries(macdHistBuffer, true);
   ArraySetAsSeries(atrBuffer, true);
   ArraySetAsSeries(tenkanBuffer, true);
   ArraySetAsSeries(kijunBuffer, true);
   ArraySetAsSeries(senkouABuffer, true);
   ArraySetAsSeries(senkouBBuffer, true);
   ArraySetAsSeries(chikouBuffer, true);
   
   // Calculate required warmup bars (using the highest of all timeframes)
   warmupBars = MathMax(SlowSMA, Senkou_Span_B);
   warmupBars = MathMax(warmupBars, MACD_SlowEMA + MACD_SignalPeriod);
   
   // Initialize last bar times
   lastTacticalBarTime = 0;
   lastChartBarTime = 0;
   
   if(UseDebugMode) {
      Print("ETH AMMC Strategy initialized - Strategic TF: ", EnumToString(StrategicTimeframe),
            ", Tactical TF: ", EnumToString(TacticalTimeframe));
      Print("Required warmup bars: ", warmupBars);
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release Strategic timeframe indicator handles
   if(strategicEMAHandle != INVALID_HANDLE)
      IndicatorRelease(strategicEMAHandle);
      
   if(strategicMediumSMAHandle != INVALID_HANDLE)
      IndicatorRelease(strategicMediumSMAHandle);
      
   if(strategicSlowSMAHandle != INVALID_HANDLE)
      IndicatorRelease(strategicSlowSMAHandle);
      
   if(strategicRSIHandle != INVALID_HANDLE)
      IndicatorRelease(strategicRSIHandle);
   
   // Release Tactical timeframe indicator handles
   if(tacticalEMAHandle != INVALID_HANDLE)
      IndicatorRelease(tacticalEMAHandle);
      
   if(tacticalMediumSMAHandle != INVALID_HANDLE)
      IndicatorRelease(tacticalMediumSMAHandle);
      
   if(tacticalSlowSMAHandle != INVALID_HANDLE)
      IndicatorRelease(tacticalSlowSMAHandle);
      
   if(tacticalRSIHandle != INVALID_HANDLE)
      IndicatorRelease(tacticalRSIHandle);
      
   if(macdHandle != INVALID_HANDLE)
      IndicatorRelease(macdHandle);
      
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
      
   if(ichimokuHandle != INVALID_HANDLE)
      IndicatorRelease(ichimokuHandle);
      
   Print("ETH AMMC Strategy deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check if market is open
   if(!IsMarketOpen())
      return;
   
   // Get current bar counts
   int strategicBars = Bars(_Symbol, StrategicTimeframe);
   int tacticalBars = Bars(_Symbol, TacticalTimeframe);
   
   // Skip trading during warmup period
   if(strategicBars < warmupBars || tacticalBars < warmupBars) {
      if(UseDebugMode && (strategicBars % 100 == 0 || tacticalBars % 100 == 0)) {
         Print("Warming up indicators: Strategic bars=", strategicBars, 
               ", Tactical bars=", tacticalBars, 
               ", Required=", warmupBars);
      }
      return;
   }
   
   // Check if we have a new tactical timeframe bar (H4)
   datetime currentTacticalTime = iTime(_Symbol, TacticalTimeframe, 0);
   bool isNewTacticalBar = (currentTacticalTime != lastTacticalBarTime);
   
   // If ExecuteOnlyOnNewTacticalBar is enabled, only process on new tactical bars
   if(ExecuteOnlyOnNewTacticalBar && !isNewTacticalBar) {
      // If not a new tactical bar, only check trailing stops
      if(UseTrailingStop) {
         if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) > 0) {
            currentATR = atrBuffer[0];
            ManageTrailingStop();
         }
      }
      return;
   }
   
   // Update tactical bar time
   if(isNewTacticalBar) {
      lastTacticalBarTime = currentTacticalTime;
      if(UseDebugMode) Print("New tactical bar detected at ", TimeToString(currentTacticalTime));
   }
   
   // Update all indicators
   if(!UpdateIndicators()) {
      if(UseDebugMode) Print("Failed to update indicators, skipping this tick");
      return;
   }
   
   // Process signals for trading
   bool hasBuySignal = CheckBuySignal();
   bool hasSellSignal = CheckSellSignal();
   
   // Count current positions
   int totalPositions = CountPositions();
   
   // Handle opposite signals if configured
   if(CloseOnOppositeSignal) {
      if(hasBuySignal && IsPositionOpen(POSITION_TYPE_SELL)) {
         if(UseDebugMode) Print("Closing SELL positions due to BUY signal");
         CloseAllPositions(POSITION_TYPE_SELL);
      }
      
      if(hasSellSignal && IsPositionOpen(POSITION_TYPE_BUY)) {
         if(UseDebugMode) Print("Closing BUY positions due to SELL signal");
         CloseAllPositions(POSITION_TYPE_BUY);
      }
   }
   
   // Update trailing stops
   if(UseTrailingStop && currentATR > 0) {
      ManageTrailingStop();
   }
   
   // Open new positions if allowed
   if(totalPositions < MaxPositions) {
      // Open buy position if signal confirmed
      if(EnableBuy && hasBuySignal && !IsPositionOpen(POSITION_TYPE_BUY) && currentATR > 0) {
         if(UseDebugMode) Print("Opening BUY position based on multi-timeframe signal");
         OpenBuyPosition();
      }
      
      // Open sell position if signal confirmed
      if(EnableSell && hasSellSignal && !IsPositionOpen(POSITION_TYPE_SELL) && currentATR > 0) {
         if(UseDebugMode) Print("Opening SELL position based on multi-timeframe signal");
         OpenSellPosition();
      }
   }
}

//+------------------------------------------------------------------+
//| Update indicator data                                            |
//+------------------------------------------------------------------+
bool UpdateIndicators()
{
   bool success = true;
   int copied = 0;
   
   // Update Strategic Timeframe Indicators
   copied = CopyBuffer(strategicEMAHandle, 0, 0, 3, strategicEMABuffer);
   if(copied <= 0 && UseDebugMode) {
      Print("Error copying Strategic EMA buffer: ", GetLastError());
      success = false;
   }
   
   copied = CopyBuffer(strategicMediumSMAHandle, 0, 0, 3, strategicMediumSMABuffer);
   if(copied <= 0 && UseDebugMode) {
      Print("Error copying Strategic Medium SMA buffer: ", GetLastError());
      success = false;
   }
   
   copied = CopyBuffer(strategicSlowSMAHandle, 0, 0, 3, strategicSlowSMABuffer);
   if(copied <= 0 && UseDebugMode) {
      Print("Error copying Strategic Slow SMA buffer: ", GetLastError());
      success = false;
   }
   
   copied = CopyBuffer(strategicRSIHandle, 0, 0, 3, strategicRSIBuffer);
   if(copied <= 0 && UseDebugMode) {
      Print("Error copying Strategic RSI buffer: ", GetLastError());
      success = false;
   }
   
   // Update Tactical Timeframe Indicators
   copied = CopyBuffer(tacticalEMAHandle, 0, 0, 3, tacticalEMABuffer);
   if(copied <= 0 && UseDebugMode) {
      Print("Error copying Tactical EMA buffer: ", GetLastError());
      success = false;
   }
   
   copied = CopyBuffer(tacticalMediumSMAHandle, 0, 0, 3, tacticalMediumSMABuffer);
   if(copied <= 0 && UseDebugMode) {
      Print("Error copying Tactical Medium SMA buffer: ", GetLastError());
      success = false;
   }
   
   copied = CopyBuffer(tacticalSlowSMAHandle, 0, 0, 3, tacticalSlowSMABuffer);
   if(copied <= 0 && UseDebugMode) {
      Print("Error copying Tactical Slow SMA buffer: ", GetLastError());
      success = false;
   }
   
   copied = CopyBuffer(tacticalRSIHandle, 0, 0, 3, tacticalRSIBuffer);
   if(copied <= 0 && UseDebugMode) {
      Print("Error copying Tactical RSI buffer: ", GetLastError());
      success = false;
   }
   
   // ATR for position sizing and risk management
   copied = CopyBuffer(atrHandle, 0, 0, 1, atrBuffer);
   if(copied <= 0) {
      if(UseDebugMode) Print("Error copying ATR buffer: ", GetLastError());
      success = false;
   } else {
      currentATR = atrBuffer[0];
   }
   
   // MACD buffers (only if MACD is enabled)
   if(UseMACD) {
      macdAvailable = true; // Assume available until proven otherwise
      
      copied = CopyBuffer(macdHandle, 0, 0, 3, macdMainBuffer);
      if(copied <= 0) {
         if(UseDebugMode) Print("Error copying MACD Main buffer: ", GetLastError());
         macdAvailable = false;
      }
      
      copied = CopyBuffer(macdHandle, 1, 0, 3, macdSignalBuffer);
      if(copied <= 0) {
         if(UseDebugMode) Print("Error copying MACD Signal buffer: ", GetLastError());
         macdAvailable = false;
      }
      
      copied = CopyBuffer(macdHandle, 2, 0, 3, macdHistBuffer);
      if(copied <= 0) {
         if(UseDebugMode) Print("Error copying MACD Histogram buffer: ", GetLastError());
         macdAvailable = false;
      }
   }
   
   // Only copy Ichimoku buffers if we're using Ichimoku and it's available
   if(UseIchimoku) {
      ichimokuAvailable = true; // Assume available until proven otherwise
      
      // Ichimoku buffers
      copied = CopyBuffer(ichimokuHandle, 0, 0, 3, tenkanBuffer);
      if(copied <= 0) {
         if(UseDebugMode) Print("Error copying Tenkan buffer: ", GetLastError());
         ichimokuAvailable = false;
      }
      
      copied = CopyBuffer(ichimokuHandle, 1, 0, 3, kijunBuffer);
      if(copied <= 0) {
         if(UseDebugMode) Print("Error copying Kijun buffer: ", GetLastError());
         ichimokuAvailable = false;
      }
      
      copied = CopyBuffer(ichimokuHandle, 2, 0, 3, senkouABuffer);
      if(copied <= 0) {
         if(UseDebugMode) Print("Error copying Senkou A buffer: ", GetLastError());
         ichimokuAvailable = false;
      }
      
      copied = CopyBuffer(ichimokuHandle, 3, 0, 3, senkouBBuffer);
      if(copied <= 0) {
         if(UseDebugMode) Print("Error copying Senkou B buffer: ", GetLastError());
         ichimokuAvailable = false;
      }
      
      copied = CopyBuffer(ichimokuHandle, 4, 0, 3, chikouBuffer);
      if(copied <= 0) {
         if(UseDebugMode) Print("Error copying Chikou buffer: ", GetLastError());
         ichimokuAvailable = false;
      }
   }
   
   // If not enough data is available, it could be because we're at market open
   // or because there's a problem with indicators. Let's report but still try to continue.
   if(!success && UseDebugMode) {
      Print("Warning: Some indicators failed to update. Will try again on next tick.");
   }
   
   return success;
}

//+------------------------------------------------------------------+
//| Check for buy signal using hierarchical approach                 |
//+------------------------------------------------------------------+
bool CheckBuySignal()
{
   // 1. Check Strategic Timeframe first (Weekly/Daily)
   bool strategicTrendOK = CheckStrategicBuyTrend();
   
   if(!strategicTrendOK) {
      if(UseDebugMode) Print("Buy signal rejected: Strategic trend conditions not met");
      return false; // Don't proceed if strategic trend is not favorable
   }
   
   // 2. Check Tactical Timeframe for entry signals
   bool tacticalEntryOK = CheckTacticalBuyEntry();
   
   if(!tacticalEntryOK) {
      if(UseDebugMode) Print("Buy signal rejected: Tactical entry conditions not met");
      return false; // Don't proceed if tactical entry conditions aren't met
   }
   
   // Both strategic trend and tactical entry conditions are favorable
   if(UseDebugMode) Print("Buy signal confirmed: Strategic trend and tactical entry aligned");
   return true;
}

//+------------------------------------------------------------------+
//| Check Strategic Timeframe for favorable buying trend             |
//+------------------------------------------------------------------+
bool CheckStrategicBuyTrend()
{
   // Get current close price on strategic timeframe
   double strategicClose = iClose(_Symbol, StrategicTimeframe, 0);
   bool result = false;
   
   // Track how many conditions we check and how many pass
   int conditionsChecked = 0;
   int conditionsPassed = 0;
   
   // Check 1: Trend alignment - Price > EMA > Medium SMA > Slow SMA
   if(ArraySize(strategicEMABuffer) > 0 && 
      ArraySize(strategicMediumSMABuffer) > 0 && 
      ArraySize(strategicSlowSMABuffer) > 0) {
      
      conditionsChecked++;
      bool trendAligned = (strategicClose > strategicEMABuffer[0] && 
                          strategicEMABuffer[0] > strategicMediumSMABuffer[0] && 
                          strategicMediumSMABuffer[0] > strategicSlowSMABuffer[0]);
      
      if(trendAligned) conditionsPassed++;
      
      if(UseDebugMode) Print("Strategic Buy Trend - Alignment check: ", trendAligned);
   }
   
   // Check 2: RSI momentum - RSI > 50 (bullish momentum)
   if(ArraySize(strategicRSIBuffer) > 0) {
      conditionsChecked++;
      bool rsiMomentum = (strategicRSIBuffer[0] > 50);
      
      if(rsiMomentum) conditionsPassed++;
      
      if(UseDebugMode) Print("Strategic Buy Trend - RSI check: ", rsiMomentum, 
                            " (", strategicRSIBuffer[0], " > 50)");
   }
   
   // We need all checked conditions to pass for strategic trend to be confirmed
   result = (conditionsPassed == conditionsChecked && conditionsChecked > 0);
   
   if(UseDebugMode) {
      Print("Strategic Buy Trend Check: ", result, " (", conditionsPassed, "/", conditionsChecked, ")");
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Check Tactical Timeframe for favorable buying entry              |
//+------------------------------------------------------------------+
bool CheckTacticalBuyEntry()
{
   // Get current close price on tactical timeframe
   double tacticalClose = iClose(_Symbol, TacticalTimeframe, 0);
   
   // Track how many conditions are checked and passed
   int conditionsChecked = 0;
   int conditionsPassed = 0;
   
   // 1. Tactical trend alignment - price above key MAs
   if(ArraySize(tacticalEMABuffer) > 0 && ArraySize(tacticalMediumSMABuffer) > 0) {
      conditionsChecked++;
      bool tacticalTrend = (tacticalClose > tacticalEMABuffer[0] && 
                           tacticalEMABuffer[0] > tacticalMediumSMABuffer[0]);
      
      if(tacticalTrend) conditionsPassed++;
      
      if(UseDebugMode) Print("Tactical Buy Entry - MA Trend check: ", tacticalTrend);
   }
   
   // 2. RSI momentum - not oversold and ideally in bullish territory
   if(ArraySize(tacticalRSIBuffer) > 0) {
      conditionsChecked++;
      bool rsiCondition = (tacticalRSIBuffer[0] > RSI_LowerLevel && tacticalRSIBuffer[0] < 80);
      
      if(rsiCondition) conditionsPassed++;
      
      if(UseDebugMode) Print("Tactical Buy Entry - RSI check: ", rsiCondition, 
                           " (", tacticalRSIBuffer[0], " > ", RSI_LowerLevel, ")");
   }
   
   // 3. Ichimoku Cloud Confirmation (if available)
   if(UseIchimoku && ichimokuAvailable && 
      ArraySize(tenkanBuffer) > 0 && ArraySize(kijunBuffer) > 0 &&
      ArraySize(senkouABuffer) > 0 && ArraySize(senkouBBuffer) > 0) {
      
      conditionsChecked++;
      bool ichimokuCondition = (tacticalClose > senkouABuffer[0] && 
                              tacticalClose > senkouBBuffer[0] && 
                              tenkanBuffer[0] > kijunBuffer[0]);
      
      if(ichimokuCondition) conditionsPassed++;
      
      if(UseDebugMode) Print("Tactical Buy Entry - Ichimoku check: ", ichimokuCondition);
   }
   
   // 4. MACD Confirmation (if available)
   if(UseMACD && macdAvailable && 
      ArraySize(macdMainBuffer) > 0 && ArraySize(macdSignalBuffer) > 0 && ArraySize(macdHistBuffer) > 1) {
      
      conditionsChecked++;
      bool macdCondition = (macdMainBuffer[0] > macdSignalBuffer[0] || 
                           (macdMainBuffer[0] < 0 && macdHistBuffer[0] > macdHistBuffer[1])); // Bullish crossover or improving momentum
      
      if(macdCondition) conditionsPassed++;
      
      if(UseDebugMode) Print("Tactical Buy Entry - MACD check: ", macdCondition);
   }
   
   // Need at least 2 conditions to pass, or 60% if we have more than 3 conditions
   int requiredConfirmations = (conditionsChecked >= 3) ? 
                               MathMax(2, (int)MathFloor(conditionsChecked * 0.6)) : 
                               conditionsChecked; // If we have less than 3, require all
   
   bool result = (conditionsPassed >= requiredConfirmations && conditionsChecked > 0);
   
   if(UseDebugMode) {
      Print("Tactical Buy Entry Check: ", result, " (", conditionsPassed, "/", 
            conditionsChecked, ", needed ", requiredConfirmations, ")");
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Check for sell signal using hierarchical approach                |
//+------------------------------------------------------------------+
bool CheckSellSignal()
{
   // 1. Check Strategic Timeframe first (Weekly/Daily)
   bool strategicTrendOK = CheckStrategicSellTrend();
   
   if(!strategicTrendOK) {
      if(UseDebugMode) Print("Sell signal rejected: Strategic trend conditions not met");
      return false; // Don't proceed if strategic trend is not favorable
   }
   
   // 2. Check Tactical Timeframe for entry signals
   bool tacticalEntryOK = CheckTacticalSellEntry();
   
   if(!tacticalEntryOK) {
      if(UseDebugMode) Print("Sell signal rejected: Tactical entry conditions not met");
      return false; // Don't proceed if tactical entry conditions aren't met
   }
   
   // Both strategic trend and tactical entry conditions are favorable
   if(UseDebugMode) Print("Sell signal confirmed: Strategic trend and tactical entry aligned");
   return true;
}

//+------------------------------------------------------------------+
//| Check Strategic Timeframe for favorable selling trend            |
//+------------------------------------------------------------------+
bool CheckStrategicSellTrend()
{
   // Get current close price on strategic timeframe
   double strategicClose = iClose(_Symbol, StrategicTimeframe, 0);
   bool result = false;
   
   // Track how many conditions we check and how many pass
   int conditionsChecked = 0;
   int conditionsPassed = 0;
   
   // Check 1: Trend alignment - Price < EMA < Medium SMA < Slow SMA
   if(ArraySize(strategicEMABuffer) > 0 && 
      ArraySize(strategicMediumSMABuffer) > 0 && 
      ArraySize(strategicSlowSMABuffer) > 0) {
      
      conditionsChecked++;
      bool trendAligned = (strategicClose < strategicEMABuffer[0] && 
                          strategicEMABuffer[0] < strategicMediumSMABuffer[0] && 
                          strategicMediumSMABuffer[0] < strategicSlowSMABuffer[0]);
      
      if(trendAligned) conditionsPassed++;
      
      if(UseDebugMode) Print("Strategic Sell Trend - Alignment check: ", trendAligned);
   }
   
   // Check 2: RSI momentum - RSI < 50 (bearish momentum)
   if(ArraySize(strategicRSIBuffer) > 0) {
      conditionsChecked++;
      bool rsiMomentum = (strategicRSIBuffer[0] < 50);
      
      if(rsiMomentum) conditionsPassed++;
      
      if(UseDebugMode) Print("Strategic Sell Trend - RSI check: ", rsiMomentum, 
                            " (", strategicRSIBuffer[0], " < 50)");
   }
   
   // We need all checked conditions to pass for strategic trend to be confirmed
   result = (conditionsPassed == conditionsChecked && conditionsChecked > 0);
   
   if(UseDebugMode) {
      Print("Strategic Sell Trend Check: ", result, " (", conditionsPassed, "/", conditionsChecked, ")");
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Check Tactical Timeframe for favorable selling entry             |
//+------------------------------------------------------------------+
bool CheckTacticalSellEntry()
{
   // Get current close price on tactical timeframe
   double tacticalClose = iClose(_Symbol, TacticalTimeframe, 0);
   
   // Track how many conditions are checked and passed
   int conditionsChecked = 0;
   int conditionsPassed = 0;
   
   // 1. Tactical trend alignment - price below key MAs
   if(ArraySize(tacticalEMABuffer) > 0 && ArraySize(tacticalMediumSMABuffer) > 0) {
      conditionsChecked++;
      bool tacticalTrend = (tacticalClose < tacticalEMABuffer[0] && 
                           tacticalEMABuffer[0] < tacticalMediumSMABuffer[0]);
      
      if(tacticalTrend) conditionsPassed++;
      
      if(UseDebugMode) Print("Tactical Sell Entry - MA Trend check: ", tacticalTrend);
   }
   
   // 2. RSI momentum - not overbought and ideally in bearish territory
   if(ArraySize(tacticalRSIBuffer) > 0) {
      conditionsChecked++;
      bool rsiCondition = (tacticalRSIBuffer[0] < RSI_UpperLevel && tacticalRSIBuffer[0] > 20);
      
      if(rsiCondition) conditionsPassed++;
      
      if(UseDebugMode) Print("Tactical Sell Entry - RSI check: ", rsiCondition, 
                           " (", tacticalRSIBuffer[0], " < ", RSI_UpperLevel, ")");
   }
   
   // 3. Ichimoku Cloud Confirmation (if available)
   if(UseIchimoku && ichimokuAvailable && 
      ArraySize(tenkanBuffer) > 0 && ArraySize(kijunBuffer) > 0 &&
      ArraySize(senkouABuffer) > 0 && ArraySize(senkouBBuffer) > 0) {
      
      conditionsChecked++;
      bool ichimokuCondition = (tacticalClose < senkouABuffer[0] && 
                              tacticalClose < senkouBBuffer[0] && 
                              tenkanBuffer[0] < kijunBuffer[0]);
      
      if(ichimokuCondition) conditionsPassed++;
      
      if(UseDebugMode) Print("Tactical Sell Entry - Ichimoku check: ", ichimokuCondition);
   }
   
   // 4. MACD Confirmation (if available)
   if(UseMACD && macdAvailable && 
      ArraySize(macdMainBuffer) > 0 && ArraySize(macdSignalBuffer) > 0 && ArraySize(macdHistBuffer) > 1) {
      
      conditionsChecked++;
      bool macdCondition = (macdMainBuffer[0] < macdSignalBuffer[0] || 
                           (macdMainBuffer[0] > 0 && macdHistBuffer[0] < macdHistBuffer[1])); // Bearish crossover or weakening momentum
      
      if(macdCondition) conditionsPassed++;
      
      if(UseDebugMode) Print("Tactical Sell Entry - MACD check: ", macdCondition);
   }
   
   // Need at least 2 conditions to pass, or 60% if we have more than 3 conditions
   int requiredConfirmations = (conditionsChecked >= 3) ? 
                               MathMax(2, (int)MathFloor(conditionsChecked * 0.6)) : 
                               conditionsChecked; // If we have less than 3, require all
   
   bool result = (conditionsPassed >= requiredConfirmations && conditionsChecked > 0);
   
   if(UseDebugMode) {
      Print("Tactical Sell Entry Check: ", result, " (", conditionsPassed, "/", 
            conditionsChecked, ", needed ", requiredConfirmations, ")");
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Open a buy position                                             |
//+------------------------------------------------------------------+
void OpenBuyPosition()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double stopLoss = 0;
   double takeProfit = 0;
   
   // Calculate stop loss and take profit based on ATR
   if(StopLossPercent > 0)
      stopLoss = NormalizeDouble(ask - (currentATR * StopLossPercent), _Digits);
      
   if(TakeProfitPercent > 0)
      takeProfit = NormalizeDouble(ask + (currentATR * TakeProfitPercent), _Digits);
      
   // Open buy position
   if(!trade.Buy(
      LotSize,
      _Symbol,
      ask,
      stopLoss,
      takeProfit,
      "ETH AMMC Buy Signal"
   ))
   {
      Print("Error opening buy position: ", GetLastError());
   }
   else
   {
      Print("Buy position opened at price ", ask, 
            ", SL: ", stopLoss, 
            ", TP: ", takeProfit);
   }
}

//+------------------------------------------------------------------+
//| Open a sell position                                            |
//+------------------------------------------------------------------+
void OpenSellPosition()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double stopLoss = 0;
   double takeProfit = 0;
   
   // Calculate stop loss and take profit based on ATR
   if(StopLossPercent > 0)
      stopLoss = NormalizeDouble(bid + (currentATR * StopLossPercent), _Digits);
      
   if(TakeProfitPercent > 0)
      takeProfit = NormalizeDouble(bid - (currentATR * TakeProfitPercent), _Digits);
      
   // Open sell position
   if(!trade.Sell(
      LotSize,
      _Symbol,
      bid,
      stopLoss,
      takeProfit,
      "ETH AMMC Sell Signal"
   ))
   {
      Print("Error opening sell position: ", GetLastError());
   }
   else
   {
      Print("Sell position opened at price ", bid, 
            ", SL: ", stopLoss, 
            ", TP: ", takeProfit);
   }
}

//+------------------------------------------------------------------+
//| Count open positions                                            |
//+------------------------------------------------------------------+
int CountPositions()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket != 0 && PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
         PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Check if a specific position type is open                        |
//+------------------------------------------------------------------+
bool IsPositionOpen(ENUM_POSITION_TYPE posType)
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket != 0 && PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
         PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_TYPE) == posType)
      {
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Close all positions of a specific type                          |
//+------------------------------------------------------------------+
void CloseAllPositions(ENUM_POSITION_TYPE posType)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket != 0 && PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
         PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_TYPE) == posType)
      {
         trade.PositionClose(ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Manage trailing stops for open positions                        |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
         PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double currentStopLoss = PositionGetDouble(POSITION_SL);
         double positionOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         
         // For buy positions - moving stop loss up
         if(posType == POSITION_TYPE_BUY)
         {
            // Calculate new stop loss based on ATR
            double atrBasedStop = NormalizeDouble(currentPrice - (currentATR * StopLossPercent), _Digits);
            
            // Only modify if new stop loss is higher than the current one
            if(atrBasedStop > currentStopLoss + 10*_Point)
            {
               trade.PositionModify(
                  ticket,
                  atrBasedStop,
                  PositionGetDouble(POSITION_TP)
               );
            }
         }
         // For sell positions - moving stop loss down
         else if(posType == POSITION_TYPE_SELL)
         {
            // Calculate new stop loss based on ATR
            double atrBasedStop = NormalizeDouble(currentPrice + (currentATR * StopLossPercent), _Digits);
            
            // Only modify if new stop loss is lower than the current one or current stop loss is zero
            if(currentStopLoss == 0 || atrBasedStop < currentStopLoss - 10*_Point)
            {
               trade.PositionModify(
                  ticket,
                  atrBasedStop,
                  PositionGetDouble(POSITION_TP)
               );
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check if the market is open                                     |
//+------------------------------------------------------------------+
bool IsMarketOpen()
{
   // For cryptocurrencies, market is generally always open, but we'll 
   // leave this function in place for future customization
   return true;
}
//+------------------------------------------------------------------+