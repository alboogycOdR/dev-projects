//+------------------------------------------------------------------+
//|                                         AMMC_2025_Conceptual.mq5 |
//|                                                   shikhar shivam |
//|                                     @artificialintelligencefacts |
//+------------------------------------------------------------------+
#property copyright "shikhar shivam"
#property link      "@artificialintelligencefacts"
#property version   "1.03" // Version updated for debugged indicator data
#property description "Conceptual MQL5 structure for ETH Adaptive Momentum & Macro Convergence (AMMC-2025)"
#property description "Includes option for Fixed Lot Size or Risk-Based sizing."
#property description "IMPORTANT: Educational/Illustrative purposes ONLY. NOT FINANCIAL ADVICE."
#property description "Macro/Fundamental inputs are MANUAL proxies. Requires external analysis."
#property strict

#include <Trade\Trade.mqh> // Include standard trading library

//--- Enums
enum ENUM_POSITION_SIZING_MODE
  {
   RISK_PERCENT, // Calculate lot based on Risk % and ATR SL
   FIXED_LOT     // Use a fixed lot size input
  };

//--- Strategy Inputs
// --- Macro/Fundamental Compass (MANUAL INPUTS) ---
input bool InpIsMacroBullish     = true;  // MANUALLY SET: Is the overall Macro environment considered Risk-On/Bullish for ETH?
input bool InpIsFundamentalBullish = true;  // MANUALLY SET: Is ETH Ecosystem Health, Tech Milestones, Regulation (net effect) Bullish?

// --- Technical Indicator Parameters ---
// Moving Averages (Trend)
input int    InpMAPeriodFast    = 21;    // EMA Fast period (e.g., 21)
input int    InpMAPeriodMedium  = 50;    // SMA Medium period (e.g., 50)
input int    InpMAPeriodSlow    = 200;   // SMA Slow period (e.g., 200)
input ENUM_MA_METHOD InpMAFastMethod = MODE_EMA; // Method for Fast MA
input ENUM_MA_METHOD InpMAMediumMethod= MODE_SMA; // Method for Medium MA
input ENUM_MA_METHOD InpMASlowMethod  = MODE_SMA; // Method for Slow MA
input ENUM_APPLIED_PRICE InpMAPrice = PRICE_CLOSE; // Price to apply MAs

// Ichimoku Cloud (Trend)
input int    InpIchiTenkan      = 9;     // Ichimoku Tenkan-sen period
input int    InpIchiKijun       = 26;    // Ichimoku Kijun-sen period
input int    InpIchiSenkouB     = 52;    // Ichimoku Senkou Span B period

// Momentum Oscillators
input int    InpRSIPeriod       = 14;    // RSI Period
input double InpRSILevelUp      = 55.0;  // RSI level suggesting bullish momentum
input double InpRSILevelDown    = 45.0;  // RSI level suggesting bearish momentum
input int    InpMACDFastEMA     = 12;    // MACD Fast EMA period
input int    InpMACDSlowEMA     = 26;    // MACD Slow EMA period
input int    InpMACDSignalSMA   = 9;     // MACD Signal line period
input ENUM_APPLIED_PRICE InpOscillatorPrice = PRICE_CLOSE; // Price for RSI/MACD

// Volatility & Risk
input int    InpATRPeriod       = 14;    // ATR Period
input double InpATRStopMultiplier = 2.0; // ATR Multiplier for Stop Loss (e.g., 2.0 * ATR)

// --- Position Sizing Inputs ---
input ENUM_POSITION_SIZING_MODE InpPositionSizingMode = FIXED_LOT; // Position Sizing Mode
input double InpFixedLotSize    = 0.2; // Fixed Lot Size (if mode is FIXED_LOT)
input double InpRiskPercent     = 1.0;  // Risk percentage per trade (if mode is RISK_PERCENT)

// --- Other Trade Parameters ---
input double InpTakeProfitRR    = 3.0;  // Take Profit as Risk:Reward Ratio (0 = disabled) - Calculated based on SL distance
input ulong  InpMagicNumber     = 202501; // Unique Magic Number for this EA's trades

// --- Debug Parameters --- 
input bool   InpDebugMode       = true;  // Enable detailed debug messages
input bool   InpRelaxedCriteria = false; // Use relaxed trading criteria for testing

//--- Global Variables
CTrade trade;                      // Trading object
string expertName = "AMMC_2025";   // Expert Advisor name for comments
bool isIndicatorsInitialized = false; // Flag to track if indicators have sufficient data

//--- Indicator Handles (declared globally)
// Weekly Handles
int hMA_Slow_W1;
// Daily Handles
int hMA_Fast_D1, hMA_Medium_D1, hMA_Slow_D1;
int hIchi_D1;
int hRSI_D1;
int hMACD_D1;
// 4-Hour Handles
int hMA_Fast_H4; // For tactical entries/exits
int hRSI_H4;
int hMACD_H4;
int hATR_H4;     // ATR usually calculated on entry/risk timeframe

//--- Indicator Buffers (arrays to hold data)
// Weekly
double valMA_Slow_W1[];
// Daily
double valMA_Fast_D1[], valMA_Medium_D1[], valMA_Slow_D1[];
double valIchiTenkan_D1[], valIchiKijun_D1[], valIchiSpanA_D1[], valIchiSpanB_D1[];
double valRSI_D1[];
double valMACDMain_D1[], valMACDSignal_D1[];
// 4-Hour
double valMA_Fast_H4[];
double valRSI_H4[];
double valMACDMain_H4[], valMACDSignal_H4[];
double valATR_H4[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- Validate Inputs (Basic Check)
   if(InpPositionSizingMode == FIXED_LOT && InpFixedLotSize <= 0)
   {
       Print(expertName, ": Error - Fixed Lot Size mode selected, but InpFixedLotSize is not positive.");
       return(INIT_FAILED);
   }
    if(InpPositionSizingMode == RISK_PERCENT && InpRiskPercent <= 0)
   {
       Print(expertName, ": Error - Risk Percent mode selected, but InpRiskPercent is not positive.");
       return(INIT_FAILED);
   }

   // Set initial size for indicator arrays
   ArrayResize(valMA_Slow_W1, 10);
   ArrayResize(valMA_Fast_D1, 10); ArrayResize(valMA_Medium_D1, 10); ArrayResize(valMA_Slow_D1, 10);
   ArrayResize(valIchiTenkan_D1, 10); ArrayResize(valIchiKijun_D1, 10); 
   ArrayResize(valIchiSpanA_D1, 10); ArrayResize(valIchiSpanB_D1, 10);
   ArrayResize(valRSI_D1, 10);
   ArrayResize(valMACDMain_D1, 10); ArrayResize(valMACDSignal_D1, 10);
   ArrayResize(valMA_Fast_H4, 10);
   ArrayResize(valRSI_H4, 10);
   ArrayResize(valMACDMain_H4, 10); ArrayResize(valMACDSignal_H4, 10);
   ArrayResize(valATR_H4, 10);

   //--- Initialize Indicator Handles
   // Weekly (Use 0 for current symbol, PERIOD_W1 for weekly)
   hMA_Slow_W1 = iMA(_Symbol, PERIOD_W1, InpMAPeriodSlow, 0, InpMASlowMethod, InpMAPrice);
   if(hMA_Slow_W1 == INVALID_HANDLE) { Print(expertName, ": Error creating W1 Slow MA indicator handle - ", GetLastError()); return(INIT_FAILED); }

   // Daily
   hMA_Fast_D1 = iMA(_Symbol, PERIOD_D1, InpMAPeriodFast, 0, InpMAFastMethod, InpMAPrice);
   if(hMA_Fast_D1 == INVALID_HANDLE) { Print(expertName, ": Error creating D1 Fast MA indicator handle - ", GetLastError()); return(INIT_FAILED); }
   hMA_Medium_D1 = iMA(_Symbol, PERIOD_D1, InpMAPeriodMedium, 0, InpMAMediumMethod, InpMAPrice);
   if(hMA_Medium_D1 == INVALID_HANDLE) { Print(expertName, ": Error creating D1 Medium MA indicator handle - ", GetLastError()); return(INIT_FAILED); }
   hMA_Slow_D1 = iMA(_Symbol, PERIOD_D1, InpMAPeriodSlow, 0, InpMASlowMethod, InpMAPrice);
   if(hMA_Slow_D1 == INVALID_HANDLE) { Print(expertName, ": Error creating D1 Slow MA indicator handle - ", GetLastError()); return(INIT_FAILED); }

   hIchi_D1 = iIchimoku(_Symbol, PERIOD_D1, InpIchiTenkan, InpIchiKijun, InpIchiSenkouB);
   if(hIchi_D1 == INVALID_HANDLE) { Print(expertName, ": Error creating D1 Ichimoku indicator handle - ", GetLastError()); return(INIT_FAILED); }

   hRSI_D1 = iRSI(_Symbol, PERIOD_D1, InpRSIPeriod, InpOscillatorPrice);
   if(hRSI_D1 == INVALID_HANDLE) { Print(expertName, ": Error creating D1 RSI indicator handle - ", GetLastError()); return(INIT_FAILED); }

   hMACD_D1 = iMACD(_Symbol, PERIOD_D1, InpMACDFastEMA, InpMACDSlowEMA, InpMACDSignalSMA, InpOscillatorPrice);
   if(hMACD_D1 == INVALID_HANDLE) { Print(expertName, ": Error creating D1 MACD indicator handle - ", GetLastError()); return(INIT_FAILED); }

   // 4-Hour
   hMA_Fast_H4 = iMA(_Symbol, PERIOD_H4, InpMAPeriodFast, 0, InpMAFastMethod, InpMAPrice); // Tactical MA
    if(hMA_Fast_H4 == INVALID_HANDLE) { Print(expertName, ": Error creating H4 Fast MA indicator handle - ", GetLastError()); return(INIT_FAILED); }

   hRSI_H4 = iRSI(_Symbol, PERIOD_H4, InpRSIPeriod, InpOscillatorPrice);
   if(hRSI_H4 == INVALID_HANDLE) { Print(expertName, ": Error creating H4 RSI indicator handle - ", GetLastError()); return(INIT_FAILED); }

   hMACD_H4 = iMACD(_Symbol, PERIOD_H4, InpMACDFastEMA, InpMACDSlowEMA, InpMACDSignalSMA, InpOscillatorPrice);
   if(hMACD_H4 == INVALID_HANDLE) { Print(expertName, ": Error creating H4 MACD indicator handle - ", GetLastError()); return(INIT_FAILED); }

   hATR_H4 = iATR(_Symbol, PERIOD_H4, InpATRPeriod);
   if(hATR_H4 == INVALID_HANDLE) { Print(expertName, ": Error creating H4 ATR indicator handle - ", GetLastError()); return(INIT_FAILED); }

   //--- Set Buffer Array Directions (Newest data at index 0)
   ArraySetAsSeries(valMA_Slow_W1, true);
   ArraySetAsSeries(valMA_Fast_D1, true); ArraySetAsSeries(valMA_Medium_D1, true); ArraySetAsSeries(valMA_Slow_D1, true);
   ArraySetAsSeries(valIchiTenkan_D1, true); ArraySetAsSeries(valIchiKijun_D1, true); ArraySetAsSeries(valIchiSpanA_D1, true); ArraySetAsSeries(valIchiSpanB_D1, true);
   ArraySetAsSeries(valRSI_D1, true);
   ArraySetAsSeries(valMACDMain_D1, true); ArraySetAsSeries(valMACDSignal_D1, true);
   ArraySetAsSeries(valMA_Fast_H4, true);
   ArraySetAsSeries(valRSI_H4, true);
   ArraySetAsSeries(valMACDMain_H4, true); ArraySetAsSeries(valMACDSignal_H4, true);
   ArraySetAsSeries(valATR_H4, true);

   //--- Initialize Trade object
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(20); // Slippage tolerance - adjust as needed
   trade.SetTypeFillingBySymbol(_Symbol);

   Print(expertName, " initialized successfully on ", _Symbol);
   Print("Position Sizing Mode: ", EnumToString(InpPositionSizingMode));
   Print("Debug Mode: ", (InpDebugMode ? "Enabled" : "Disabled"));
   Print("Relaxed Criteria: ", (InpRelaxedCriteria ? "Enabled" : "Disabled"));
   Print("REMINDER: Macro/Fundamental inputs are MANUAL and require user analysis!");
   //---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   //--- Release indicator handles
   IndicatorRelease(hMA_Slow_W1);
   IndicatorRelease(hMA_Fast_D1); IndicatorRelease(hMA_Medium_D1); IndicatorRelease(hMA_Slow_D1);
   IndicatorRelease(hIchi_D1);
   IndicatorRelease(hRSI_D1);
   IndicatorRelease(hMACD_D1);
   IndicatorRelease(hMA_Fast_H4);
   IndicatorRelease(hRSI_H4);
   IndicatorRelease(hMACD_H4);
   IndicatorRelease(hATR_H4);

   Print(expertName, " deinitialized. Reason code: ", reason);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   //--- Check if a new H4 bar has opened to avoid over-trading
   static datetime lastBarTimeH4 = 0;
   datetime currentBarTimeH4 = (datetime)SeriesInfoInteger(_Symbol, PERIOD_H4, SERIES_LASTBAR_DATE);
   if(currentBarTimeH4 == lastBarTimeH4)
     {
      return; // Not a new H4 bar yet
     }
   lastBarTimeH4 = currentBarTimeH4;

   //--- Get latest price data
   MqlTick latest_tick;
   if(!SymbolInfoTick(_Symbol, latest_tick)) { Print("Could not get latest tick for ", _Symbol); return; }
   double ask = latest_tick.ask;
   double bid = latest_tick.bid;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT); // Point size

   //--- Get latest indicator values (need 2-3 bars for comparisons)
   if(!CopyIndicatorData())
     {
      if(InpDebugMode) Print(expertName, ": Error copying indicator data. Waiting for indicators to initialize...");
      return;
     }
   
   // If we've reached this point, indicators are properly loaded
   if(!isIndicatorsInitialized) {
       isIndicatorsInitialized = true;
       Print(expertName, ": All indicators successfully initialized and data available");
   }

   //--- Get current price relative to H4 timeframe (using close of previous H4 bar for consistency)
   MqlRates ratesH4[];
   if(CopyRates(_Symbol, PERIOD_H4, 1, 1, ratesH4) <= 0) { Print("Could not get H4 rates"); return; }
   double priceH4_Close = ratesH4[0].close;


   //--- Check if a position managed by this EA is already open for this symbol
   bool positionOpen = false;
   if(PositionSelect(_Symbol)) // Try to select *any* position on the current symbol
     {
      if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
        { positionOpen = true; }
     }
   long positionType = -1; // -1: none, 0: buy, 1: sell
   if(positionOpen)
     { positionType = PositionGetInteger(POSITION_TYPE); }


   //--- ============================ STRATEGY LOGIC ============================
   //--- === Pillar 1: Macro-Fundamental Compass (Manual Inputs) ===
   // --- Define Bullish/Bearish Conditions based on indicators ---
   // --- W1 Trend Context (Simplified) ---
   bool isW1_Uptrend = (valMA_Slow_W1[1] > 0 && priceH4_Close > valMA_Slow_W1[1]); // Price above Slow MA on W1 (using previous bar's value)

   // --- D1 Trend Conditions ---
   bool isD1_MA_Uptrend = priceH4_Close > valMA_Fast_D1[1] && valMA_Fast_D1[1] > valMA_Medium_D1[1] && valMA_Medium_D1[1] > valMA_Slow_D1[1];
   bool isD1_MA_Downtrend = priceH4_Close < valMA_Fast_D1[1] && valMA_Fast_D1[1] < valMA_Medium_D1[1] && valMA_Medium_D1[1] < valMA_Slow_D1[1];
   bool isD1_Ichi_Uptrend = priceH4_Close > valIchiSpanA_D1[1] && priceH4_Close > valIchiSpanB_D1[1] && valIchiTenkan_D1[1] > valIchiKijun_D1[1];
   bool isD1_Ichi_Downtrend = priceH4_Close < valIchiSpanA_D1[1] && priceH4_Close < valIchiSpanB_D1[1] && valIchiTenkan_D1[1] < valIchiKijun_D1[1];
   bool isD1_StrongUptrend = isD1_MA_Uptrend && isD1_Ichi_Uptrend; // Example Convergence
   bool isD1_StrongDowntrend = isD1_MA_Downtrend && isD1_Ichi_Downtrend; // Example Convergence

   // --- D1 Momentum Conditions ---
   bool isD1_RSI_Bullish = valRSI_D1[1] > InpRSILevelUp;
   bool isD1_RSI_Bearish = valRSI_D1[1] < InpRSILevelDown;
   bool isD1_MACD_Bullish = valMACDMain_D1[1] > valMACDSignal_D1[1] && valMACDMain_D1[1] > 0; // MACD above signal and zero line
   bool isD1_MACD_Bearish = valMACDMain_D1[1] < valMACDSignal_D1[1] && valMACDMain_D1[1] < 0; // MACD below signal and zero line
   bool isD1_MomentumBullish = isD1_RSI_Bullish && isD1_MACD_Bullish;
   bool isD1_MomentumBearish = isD1_RSI_Bearish && isD1_MACD_Bearish;

   // --- H4 Tactical Conditions (Simplified - check alignment) ---
   bool isH4_RSI_Bullish = valRSI_H4[1] > 50.0; // Simple check above 50
   bool isH4_RSI_Bearish = valRSI_H4[1] < 50.0; // Simple check below 50
   bool isH4_MACD_Bullish = valMACDMain_H4[1] > valMACDSignal_H4[1]; // MACD crossed up recently or is above signal
   bool isH4_MACD_Bearish = valMACDMain_H4[1] < valMACDSignal_H4[1]; // MACD crossed down recently or is below signal
   bool isH4_MomentumBullish = isH4_RSI_Bullish && isH4_MACD_Bullish;
   bool isH4_MomentumBearish = isH4_RSI_Bearish && isH4_MACD_Bearish;

   //--- ATR for Stop Loss calculation (on H4)
   double atrValueH4 = valATR_H4[1]; // Use previous bar's ATR

   // Print debug information if enabled
   if(InpDebugMode) {
       Print("===== Strategy Conditions =====");
       Print("W1 Uptrend: ", isW1_Uptrend, " (Price: ", priceH4_Close, ", W1 Slow MA: ", valMA_Slow_W1[1], ")");
       Print("D1 MA Uptrend: ", isD1_MA_Uptrend, " | D1 MA Downtrend: ", isD1_MA_Downtrend);
       Print("D1 Ichi Uptrend: ", isD1_Ichi_Uptrend, " | D1 Ichi Downtrend: ", isD1_Ichi_Downtrend);
       Print("D1 Strong Uptrend: ", isD1_StrongUptrend, " | D1 Strong Downtrend: ", isD1_StrongDowntrend);
       Print("D1 RSI: ", valRSI_D1[1], " | Bullish? ", isD1_RSI_Bullish, " | Bearish? ", isD1_RSI_Bearish);
       Print("D1 MACD Main: ", valMACDMain_D1[1], " | Signal: ", valMACDSignal_D1[1], " | Bullish? ", isD1_MACD_Bullish, " | Bearish? ", isD1_MACD_Bearish);
       Print("H4 RSI: ", valRSI_H4[1], " | Bullish? ", isH4_RSI_Bullish, " | Bearish? ", isH4_RSI_Bearish);
       Print("H4 MACD: Bullish? ", isH4_MACD_Bullish, " | Bearish? ", isH4_MACD_Bearish);
       Print("ATR Value (H4): ", atrValueH4);
   }

   //--- ============================ EXECUTION LOGIC ============================

   //--- Exit Logic ---
   if(positionOpen)
     {
      bool closeSignal = false;
      string closeReason = "";

      if(positionType == POSITION_TYPE_BUY) // Check exit for Long position
      {
         if(isD1_StrongDowntrend || priceH4_Close < valMA_Medium_D1[1]) { closeSignal = true; closeReason = "D1 Trend Reversal Signal"; }
         else if(isD1_MomentumBearish || isH4_MomentumBearish) { closeSignal = true; closeReason = "D1/H4 Momentum Weakness"; }
         else if(!InpIsMacroBullish || !InpIsFundamentalBullish) { closeSignal = true; closeReason = "Manual Macro/Fundamental Shift to Bearish"; }
      }
      else if(positionType == POSITION_TYPE_SELL) // Check exit for Short position
      {
         if(isD1_StrongUptrend || priceH4_Close > valMA_Medium_D1[1]) { closeSignal = true; closeReason = "D1 Trend Reversal Signal"; }
         else if(isD1_MomentumBullish || isH4_MomentumBullish) { closeSignal = true; closeReason = "D1/H4 Momentum Weakness"; }
         else if(InpIsMacroBullish || InpIsFundamentalBullish) { closeSignal = true; closeReason = "Manual Macro/Fundamental Shift to Bullish"; }
      }

      if(closeSignal)
        {
         Print(expertName, ": Closing position on ", _Symbol, ". Reason: ", closeReason);
         trade.PositionClose(_Symbol);
        }
     }

   //--- Entry Logic ---
   if(!positionOpen)
     {
      // --- Bullish Entry Conditions ---
      bool enterLongRelaxed = InpIsMacroBullish && isD1_MA_Uptrend && (isD1_RSI_Bullish || isH4_RSI_Bullish);
      bool enterLongStrict = InpIsMacroBullish && InpIsFundamentalBullish && isW1_Uptrend && isD1_StrongUptrend && isD1_MomentumBullish && isH4_MomentumBullish;
      
      bool enterLong = InpRelaxedCriteria ? enterLongRelaxed : enterLongStrict;

      // --- Bearish Entry Conditions ---
      bool enterShortRelaxed = !InpIsMacroBullish && isD1_MA_Downtrend && (isD1_RSI_Bearish || isH4_RSI_Bearish);
      bool enterShortStrict = !InpIsMacroBullish && !InpIsFundamentalBullish && !isW1_Uptrend && isD1_StrongDowntrend && isD1_MomentumBearish && isH4_MomentumBearish;
      
      bool enterShort = InpRelaxedCriteria ? enterShortRelaxed : enterShortStrict;

      if(InpDebugMode) {
          Print("Entry Signals: Long=", enterLong, " | Short=", enterShort);
          Print("Relaxed Criteria: ", InpRelaxedCriteria ? "ON" : "OFF");
      }

      double lotSize = 0.0;
      double stopLossPrice = 0.0;
      double takeProfitPrice = 0.0;
      double stopLossDistance = 0.0; // Distance in price units for TP calc

      // --- Determine Lot Size and SL/TP based on mode ---
      if(enterLong)
        {
         // Calculate SL first (always needed)
         stopLossPrice = bid - InpATRStopMultiplier * atrValueH4;
         stopLossDistance = bid - stopLossPrice; // SL distance is positive for long

         // Determine Lot Size
         if(InpPositionSizingMode == RISK_PERCENT)
         {
             lotSize = CalculateLotSize(stopLossDistance); // Calculate based on risk
         }
         else // FIXED_LOT mode
         {
             lotSize = InpFixedLotSize; // Use fixed lot size
             // Optional: Normalize fixed lot size (good practice)
             double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
             double minLots = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
             lotSize = MathMax(minLots, MathFloor(lotSize / lotStep) * lotStep);
         }

         // Calculate TP (based on SL distance, regardless of lot size mode)
         if(InpTakeProfitRR > 0 && stopLossDistance > 0)
         {
             takeProfitPrice = bid + InpTakeProfitRR * stopLossDistance;
         }

         // --- Execute Entry Order ---
         if(lotSize > 0)
         {
            Print(expertName, ": Bullish Entry Signal on ", _Symbol, " (Sizing: ", EnumToString(InpPositionSizingMode), ")");
            Print("   Attempting BUY: Lots=", DoubleToString(lotSize, 2), ", SL=", DoubleToString(stopLossPrice, _Digits), ", TP=", (takeProfitPrice > 0 ? DoubleToString(takeProfitPrice, _Digits) : "None"));
            trade.Buy(lotSize, _Symbol, bid, stopLossPrice, takeProfitPrice, "AMMC-2025 Long Entry");
         } else {
             Print(expertName, ": Calculated/Fixed Lot Size is zero or negative for Long. No trade.");
         }
        }
      else if(enterShort)
        {
          // Calculate SL first (always needed)
         stopLossPrice = ask + InpATRStopMultiplier * atrValueH4;
         stopLossDistance = stopLossPrice - ask; // SL distance is positive for short

         // Determine Lot Size
         if(InpPositionSizingMode == RISK_PERCENT)
         {
             lotSize = CalculateLotSize(stopLossDistance); // Calculate based on risk
         }
         else // FIXED_LOT mode
         {
             lotSize = InpFixedLotSize; // Use fixed lot size
             // Optional: Normalize fixed lot size (good practice)
             double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
             double minLots = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
             lotSize = MathMax(minLots, MathFloor(lotSize / lotStep) * lotStep);
         }

         // Calculate TP (based on SL distance, regardless of lot size mode)
         if(InpTakeProfitRR > 0 && stopLossDistance > 0)
         {
             takeProfitPrice = ask - InpTakeProfitRR * stopLossDistance;
         }

         // --- Execute Entry Order ---
          if(lotSize > 0)
          {
             Print(expertName, ": Bearish Entry Signal on ", _Symbol, " (Sizing: ", EnumToString(InpPositionSizingMode), ")");
             Print("   Attempting SELL: Lots=", DoubleToString(lotSize, 2), ", SL=", DoubleToString(stopLossPrice, _Digits), ", TP=", (takeProfitPrice > 0 ? DoubleToString(takeProfitPrice, _Digits) : "None"));
             trade.Sell(lotSize, _Symbol, ask, stopLossPrice, takeProfitPrice, "AMMC-2025 Short Entry");
          } else {
              Print(expertName, ": Calculated/Fixed Lot Size is zero or negative for Short. No trade.");
          }
        }
     } // End if(!positionOpen)

   //--- ======================== END STRATEGY LOGIC ==========================
  }
//+------------------------------------------------------------------+
//| Helper function to copy indicator data                           |
//+------------------------------------------------------------------+
bool CopyIndicatorData()
  {
   int dataToCopy = 3;
   
   // Use a more robust approach to copy indicator data
   
   // Weekly indicators - may not have enough data initially
   int copied = CopyBuffer(hMA_Slow_W1, 0, 0, dataToCopy, valMA_Slow_W1);
   if(copied < dataToCopy) {
      if(InpDebugMode) Print("Failed to copy Weekly Slow MA: copied ", copied, " of ", dataToCopy, " bars. Error ", GetLastError());
      return false;
   }
   
   // Daily indicators
   copied = CopyBuffer(hMA_Fast_D1, 0, 0, dataToCopy, valMA_Fast_D1);
   if(copied < dataToCopy) {
      if(InpDebugMode) Print("Failed to copy D1 Fast MA: copied ", copied, " of ", dataToCopy, " bars. Error ", GetLastError());
      return false;
   }
   
   copied = CopyBuffer(hMA_Medium_D1, 0, 0, dataToCopy, valMA_Medium_D1);
   if(copied < dataToCopy) {
      if(InpDebugMode) Print("Failed to copy D1 Medium MA: copied ", copied, " of ", dataToCopy, " bars. Error ", GetLastError());
      return false;
   }
   
   copied = CopyBuffer(hMA_Slow_D1, 0, 0, dataToCopy, valMA_Slow_D1);
   if(copied < dataToCopy) {
      if(InpDebugMode) Print("Failed to copy D1 Slow MA: copied ", copied, " of ", dataToCopy, " bars. Error ", GetLastError());
      return false;
   }
   
   copied = CopyBuffer(hIchi_D1, 0, 0, dataToCopy, valIchiTenkan_D1);
   if(copied < dataToCopy) {
      if(InpDebugMode) Print("Failed to copy D1 Ichimoku Tenkan: copied ", copied, " of ", dataToCopy, " bars. Error ", GetLastError());
      return false;
   }
   
   copied = CopyBuffer(hIchi_D1, 1, 0, dataToCopy, valIchiKijun_D1);
   if(copied < dataToCopy) {
      if(InpDebugMode) Print("Failed to copy D1 Ichimoku Kijun: copied ", copied, " of ", dataToCopy, " bars. Error ", GetLastError());
      return false;
   }
   
   copied = CopyBuffer(hIchi_D1, 2, 0, dataToCopy, valIchiSpanA_D1);
   if(copied < dataToCopy) {
      if(InpDebugMode) Print("Failed to copy D1 Ichimoku Span A: copied ", copied, " of ", dataToCopy, " bars. Error ", GetLastError());
      return false;
   }
   
   copied = CopyBuffer(hIchi_D1, 3, 0, dataToCopy, valIchiSpanB_D1);
   if(copied < dataToCopy) {
      if(InpDebugMode) Print("Failed to copy D1 Ichimoku Span B: copied ", copied, " of ", dataToCopy, " bars. Error ", GetLastError());
      return false;
   }
   
   copied = CopyBuffer(hRSI_D1, 0, 0, dataToCopy, valRSI_D1);
   if(copied < dataToCopy) {
      if(InpDebugMode) Print("Failed to copy D1 RSI: copied ", copied, " of ", dataToCopy, " bars. Error ", GetLastError());
      return false;
   }
   
   copied = CopyBuffer(hMACD_D1, 0, 0, dataToCopy, valMACDMain_D1);
   if(copied < dataToCopy) {
      if(InpDebugMode) Print("Failed to copy D1 MACD Main: copied ", copied, " of ", dataToCopy, " bars. Error ", GetLastError());
      return false;
   }
   
   copied = CopyBuffer(hMACD_D1, 1, 0, dataToCopy, valMACDSignal_D1);
   if(copied < dataToCopy) {
      if(InpDebugMode) Print("Failed to copy D1 MACD Signal: copied ", copied, " of ", dataToCopy, " bars. Error ", GetLastError());
      return false;
   }
   
   // 4-Hour indicators
   copied = CopyBuffer(hMA_Fast_H4, 0, 0, dataToCopy, valMA_Fast_H4);
   if(copied < dataToCopy) {
      if(InpDebugMode) Print("Failed to copy H4 Fast MA: copied ", copied, " of ", dataToCopy, " bars. Error ", GetLastError());
      return false;
   }
   
   copied = CopyBuffer(hRSI_H4, 0, 0, dataToCopy, valRSI_H4);
   if(copied < dataToCopy) {
      if(InpDebugMode) Print("Failed to copy H4 RSI: copied ", copied, " of ", dataToCopy, " bars. Error ", GetLastError());
      return false;
   }
   
   copied = CopyBuffer(hMACD_H4, 0, 0, dataToCopy, valMACDMain_H4);
   if(copied < dataToCopy) {
      if(InpDebugMode) Print("Failed to copy H4 MACD Main: copied ", copied, " of ", dataToCopy, " bars. Error ", GetLastError());
      return false;
   }
   
   copied = CopyBuffer(hMACD_H4, 1, 0, dataToCopy, valMACDSignal_H4);
   if(copied < dataToCopy) {
      if(InpDebugMode) Print("Failed to copy H4 MACD Signal: copied ", copied, " of ", dataToCopy, " bars. Error ", GetLastError());
      return false;
   }
   
   copied = CopyBuffer(hATR_H4, 0, 0, dataToCopy, valATR_H4);
   if(copied < dataToCopy) {
      if(InpDebugMode) Print("Failed to copy H4 ATR: copied ", copied, " of ", dataToCopy, " bars. Error ", GetLastError());
      return false;
   }
   
   return true;
  }
//+------------------------------------------------------------------+
//| Helper function to calculate position size based on risk %       |
//| (Only used if InpPositionSizingMode == RISK_PERCENT)           |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLossDistance) // stopLossDistance in price units (e.g., abs(price_entry - price_sl))
  {
   // --- This function is now ONLY called if RISK_PERCENT mode is active ---
   if(InpPositionSizingMode != RISK_PERCENT)
     {
      Print(expertName, " Error: CalculateLotSize called when mode is not RISK_PERCENT.");
      return(0.0); // Should not happen if logic in OnTick is correct
     }

   if(stopLossDistance <= 0) {
      Print(expertName, ": Stop loss distance is zero or negative (", DoubleToString(stopLossDistance, _Digits), "). Cannot calculate risk-based lot size.");
      return(0.0);
   }
   if(InpRiskPercent <= 0) {
      Print(expertName, ": Risk Percent (", DoubleToString(InpRiskPercent,2), ") is zero or negative. Cannot calculate risk-based lot size.");
      return(0.0);
   }

   double accountBalance = AccountInfoDouble(ACCOUNT_EQUITY);
   if(accountBalance <= 0) {
        Print(expertName, ": Account Balance/Equity is zero or negative. Cannot calculate lot size.");
        return(0.0);
   }
   double riskAmount = accountBalance * (InpRiskPercent / 100.0);
   if(riskAmount <= 0) {
        Print(expertName, ": Calculated Risk Amount is zero or negative.");
        return(0.0);
   }

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

    if(tickValue <= 0 || tickSize <= 0) {
        Print(expertName, ": Error getting symbol tick value/size for lot calculation. TickValue=", tickValue, ", TickSize=", tickSize);
        return(0.0);
    }

   double valuePerPointPerLot = tickValue / tickSize;
    if (valuePerPointPerLot <= 0) {
         Print(expertName, ": Error calculating value per point per lot. TickValue=", tickValue, ", TickSize=", tickSize);
         return(0.0);
     }

   double riskPerLot = stopLossDistance * valuePerPointPerLot;
    if(riskPerLot <= 0) {
        Print(expertName, ": Error calculating risk per lot. SL Dist=", stopLossDistance, ", ValuePerPointPerLot=", valuePerPointPerLot);
        return(0.0);
    }

   double desiredLots = riskAmount / riskPerLot;

   //--- Normalize lot size according to broker limitations
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLots = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLots = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if(lotStep <=0 || minLots <= 0 || maxLots <= 0) {
        Print(expertName, ": Error getting symbol volume constraints (Step/Min/Max).");
        return(0.0);
   }

   desiredLots = MathFloor(desiredLots / lotStep) * lotStep; // Adjust down to nearest lot step

   // Check against min/max lot size
   if(desiredLots < minLots)
     {
      Print(expertName, ": Calculated risk-based lot size (", DoubleToString(desiredLots, 8), ") is below minimum (", DoubleToString(minLots, 8), "). Risk percent might be too low or SL too tight.");
      return(0.0);
     }
   if(desiredLots > maxLots)
     {
      desiredLots = maxLots;
      Print(expertName, ": Calculated risk-based lot size exceeds maximum. Using max lots: ", DoubleToString(maxLots, 8));
     }

   if (desiredLots <= 0) {
       Print(expertName, ": Final risk-based calculated lot size is zero or negative after normalization.");
       return 0.0;
   }

   return(desiredLots);
  }
//+------------------------------------------------------------------+