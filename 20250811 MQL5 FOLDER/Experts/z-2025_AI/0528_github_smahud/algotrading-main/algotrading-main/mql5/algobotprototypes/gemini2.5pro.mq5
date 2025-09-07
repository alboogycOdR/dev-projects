//+------------------------------------------------------------------+
//|                                         AMMC_2025_Conceptual.mq5 |
//|                                                   shikhar shivam |
//|                                     @artificialintelligencefacts |
//+------------------------------------------------------------------+
#property copyright "shikhar shivam"
#property link      "@artificialintelligencefacts"
#property version   "1.01" // Version updated for corrections
#property description "Conceptual MQL5 structure for ETH Adaptive Momentum & Macro Convergence (AMMC-2025)"
#property description "IMPORTANT: Educational/Illustrative purposes ONLY. NOT FINANCIAL ADVICE."
#property description "Macro/Fundamental inputs are MANUAL proxies. Requires external analysis."
#property strict

#include <Trade\Trade.mqh> // Include standard trading library

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
input double InpRiskPercent     = 1.0;   // Risk percentage per trade (e.g., 1.0 = 1%)
input double InpTakeProfitRR    = 3.0;   // Take Profit as Risk:Reward Ratio (0 = disabled)
input ulong  InpMagicNumber     = 202501; // Unique Magic Number for this EA's trades

//--- Global Variables
CTrade trade;                      // Trading object
string expertName = "AMMC_2025";   // Expert Advisor name for comments

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
      Print(expertName, ": Error copying indicator data.");
      return;
     }

   //--- Get current price relative to H4 timeframe (using close of previous H4 bar for consistency)
   MqlRates ratesH4[];
   if(CopyRates(_Symbol, PERIOD_H4, 1, 1, ratesH4) <= 0) { Print("Could not get H4 rates"); return; }
   double priceH4_Close = ratesH4[0].close;


   //--- Check if a position managed by this EA is already open for this symbol --- // <<< CORRECTION APPLIED HERE
   bool positionOpen = false;
   if(PositionSelect(_Symbol)) // Try to select *any* position on the current symbol
     {
      // If selection succeeded, check if the magic number matches our EA's magic number
      if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
        {
         positionOpen = true; // A position managed by this EA exists
        }
     }
   // --- Get position type if open ---
   long positionType = -1; // -1: none, 0: buy, 1: sell
   if(positionOpen)
     {
      positionType = PositionGetInteger(POSITION_TYPE);
     }
   // --- END CORRECTION ---

   //--- ============================ STRATEGY LOGIC ============================
   //--- === Pillar 1: Macro-Fundamental Compass (Manual Inputs) ===
   // Checked before entry and potentially for exit override

   //--- === Pillar 2 & 3: Technical Momentum & Volatility/Risk ===

   //--- Define Bullish/Bearish Conditions based on indicators ---
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
   // Basic check if H4 momentum aligns with intended direction
   bool isH4_RSI_Bullish = valRSI_H4[1] > 50.0; // Simple check above 50
   bool isH4_RSI_Bearish = valRSI_H4[1] < 50.0; // Simple check below 50
   bool isH4_MACD_Bullish = valMACDMain_H4[1] > valMACDSignal_H4[1]; // MACD crossed up recently or is above signal
   bool isH4_MACD_Bearish = valMACDMain_H4[1] < valMACDSignal_H4[1]; // MACD crossed down recently or is below signal
   bool isH4_MomentumBullish = isH4_RSI_Bullish && isH4_MACD_Bullish;
   bool isH4_MomentumBearish = isH4_RSI_Bearish && isH4_MACD_Bearish;
   // Add check for pullback: e.g., price recently touched hMA_Fast_H4? (More complex, omitted for structure)
   // Add check for reversal pattern: Hammer, Engulfing etc.? (Requires pattern recognition logic, omitted)

   //--- ATR for Stop Loss calculation (on H4)
   double atrValueH4 = valATR_H4[1]; // Use previous bar's ATR


   //--- ============================ EXECUTION LOGIC ============================

   //--- Exit Logic ---
   if(positionOpen)
     {
      bool closeSignal = false;
      string closeReason = "";

      if(positionType == POSITION_TYPE_BUY) // Check exit for Long position
      {
         // 1. Trend Reversal (D1)
         if(isD1_StrongDowntrend || priceH4_Close < valMA_Medium_D1[1]) // Example: Strong D1 reversal or broke medium MA
         { closeSignal = true; closeReason = "D1 Trend Reversal Signal"; }
         // 2. Momentum Weakness (D1/H4)
         else if(isD1_MomentumBearish || isH4_MomentumBearish) // D1 or H4 momentum turns bearish
         { closeSignal = true; closeReason = "D1/H4 Momentum Weakness"; }
         // 3. Fundamental/Macro Shift (Manual Override)
         else if(!InpIsMacroBullish || !InpIsFundamentalBullish)
         { closeSignal = true; closeReason = "Manual Macro/Fundamental Shift to Bearish"; }
         // Stop Loss / Take Profit are handled by broker orders, but trailing stop could be added here
      }
      else if(positionType == POSITION_TYPE_SELL) // Check exit for Short position
      {
          // 1. Trend Reversal (D1)
         if(isD1_StrongUptrend || priceH4_Close > valMA_Medium_D1[1]) // Example: Strong D1 reversal or broke medium MA
         { closeSignal = true; closeReason = "D1 Trend Reversal Signal"; }
         // 2. Momentum Weakness (D1/H4)
         else if(isD1_MomentumBullish || isH4_MomentumBullish) // D1 or H4 momentum turns bullish
         { closeSignal = true; closeReason = "D1/H4 Momentum Weakness"; }
         // 3. Fundamental/Macro Shift (Manual Override)
         else if(InpIsMacroBullish || InpIsFundamentalBullish) // If manual inputs turn bullish
         { closeSignal = true; closeReason = "Manual Macro/Fundamental Shift to Bullish"; }
         // Stop Loss / Take Profit are handled by broker orders, trailing stop could be added here
      }

      // Execute Close Order if signal triggered
      if(closeSignal)
        {
         Print(expertName, ": Closing position on ", _Symbol, ". Reason: ", closeReason);
         trade.PositionClose(_Symbol); // Close the position by symbol (will close the one selected earlier if magic matched)
        }
     }

   //--- Entry Logic ---
   // Check only if no position is currently open
   if(!positionOpen)
     {
      // --- Bullish Entry Conditions (Convergence) ---
      bool enterLong =
         InpIsMacroBullish           && // Pillar 1: Macro OK (Manual)
         InpIsFundamentalBullish     && // Pillar 1: Fundamentals OK (Manual)
         isW1_Uptrend                && // Pillar 2: Weekly context bullish
         isD1_StrongUptrend          && // Pillar 2: Daily trend strongly bullish (MA + Ichi)
         isD1_MomentumBullish        && // Pillar 2: Daily momentum confirms
         isH4_MomentumBullish;          // Pillar 2: H4 tactical momentum aligns (Simplified - needs refinement)
         // Add H4 pullback condition check here if developed


      // --- Bearish Entry Conditions (Convergence) ---
      bool enterShort =
         !InpIsMacroBullish          && // Pillar 1: Macro OK (Manual) - Needs to be ! for Short
         !InpIsFundamentalBullish    && // Pillar 1: Fundamentals OK (Manual) - Needs to be ! for Short
         !isW1_Uptrend               && // Pillar 2: Weekly context bearish (Simplified)
         isD1_StrongDowntrend        && // Pillar 2: Daily trend strongly bearish
         isD1_MomentumBearish        && // Pillar 2: Daily momentum confirms
         isH4_MomentumBearish;          // Pillar 2: H4 tactical momentum aligns (Simplified)
         // Add H4 pullback condition check here if developed

      // --- Execute Entry Order ---
      if(enterLong)
        {
         double stopLossPrice = bid - InpATRStopMultiplier * atrValueH4; // SL below entry based on ATR
         double takeProfitPrice = 0;
         if(InpTakeProfitRR > 0)
            takeProfitPrice = bid + InpTakeProfitRR * (bid - stopLossPrice); // TP based on Risk:Reward

         double lotSize = CalculateLotSize(bid - stopLossPrice); // Calculate position size based on risk

         if(lotSize > 0)
         {
            Print(expertName, ": Bullish Entry Signal on ", _Symbol);
            Print("   Macro Bullish: ", InpIsMacroBullish, ", Fundamental Bullish: ", InpIsFundamentalBullish);
            Print("   W1 Trend: Up, D1 Trend: Strong Up, D1 Mom: Bullish, H4 Mom: Bullish");
            Print("   Attempting BUY: Lots=", DoubleToString(lotSize, 2), ", SL=", DoubleToString(stopLossPrice, _Digits), ", TP=", (takeProfitPrice > 0 ? DoubleToString(takeProfitPrice, _Digits) : "None"));
            trade.Buy(lotSize, _Symbol, bid, stopLossPrice, takeProfitPrice, "AMMC-2025 Long Entry");
         } else {
             Print(expertName, ": Calculated Lot Size is zero or negative for Long. No trade.");
         }
        }
      else if(enterShort)
        {
         double stopLossPrice = ask + InpATRStopMultiplier * atrValueH4; // SL above entry based on ATR
         double takeProfitPrice = 0;
         if(InpTakeProfitRR > 0)
            takeProfitPrice = ask - InpTakeProfitRR * (stopLossPrice - ask); // TP based on Risk:Reward

         double lotSize = CalculateLotSize(stopLossPrice - ask); // Calculate position size based on risk

          if(lotSize > 0)
          {
             Print(expertName, ": Bearish Entry Signal on ", _Symbol);
             Print("   Macro Bullish: ", InpIsMacroBullish, ", Fundamental Bullish: ", InpIsFundamentalBullish); // Note these might be false for short
             Print("   W1 Trend: Down, D1 Trend: Strong Down, D1 Mom: Bearish, H4 Mom: Bearish");
             Print("   Attempting SELL: Lots=", DoubleToString(lotSize, 2), ", SL=", DoubleToString(stopLossPrice, _Digits), ", TP=", (takeProfitPrice > 0 ? DoubleToString(takeProfitPrice, _Digits) : "None"));
             trade.Sell(lotSize, _Symbol, ask, stopLossPrice, takeProfitPrice, "AMMC-2025 Short Entry");
          } else {
              Print(expertName, ": Calculated Lot Size is zero or negative for Short. No trade.");
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
   // Copy requires at least 3 bars of data for comparisons [0]=current(incomplete), [1]=previous, [2]=prior
   int dataToCopy = 3;

   // Weekly
   if(CopyBuffer(hMA_Slow_W1, 0, 0, dataToCopy, valMA_Slow_W1) < dataToCopy) return(false);
   // Daily
   if(CopyBuffer(hMA_Fast_D1, 0, 0, dataToCopy, valMA_Fast_D1) < dataToCopy) return(false);
   if(CopyBuffer(hMA_Medium_D1, 0, 0, dataToCopy, valMA_Medium_D1) < dataToCopy) return(false);
   if(CopyBuffer(hMA_Slow_D1, 0, 0, dataToCopy, valMA_Slow_D1) < dataToCopy) return(false);
   // --- Ichimoku Correction Applied Here ---
   if(CopyBuffer(hIchi_D1, 0, 0, dataToCopy, valIchiTenkan_D1) < dataToCopy) return(false); // 0 = Tenkan-sen
   if(CopyBuffer(hIchi_D1, 1, 0, dataToCopy, valIchiKijun_D1) < dataToCopy) return(false); // 1 = Kijun-sen
   if(CopyBuffer(hIchi_D1, 2, 0, dataToCopy, valIchiSpanA_D1) < dataToCopy) return(false); // 2 = Senkou Span A
   if(CopyBuffer(hIchi_D1, 3, 0, dataToCopy, valIchiSpanB_D1) < dataToCopy) return(false); // 3 = Senkou Span B
   // --- End Ichimoku Correction ---
   if(CopyBuffer(hRSI_D1, 0, 0, dataToCopy, valRSI_D1) < dataToCopy) return(false);
   if(CopyBuffer(hMACD_D1, 0, 0, dataToCopy, valMACDMain_D1) < dataToCopy) return(false); // Main line
   if(CopyBuffer(hMACD_D1, 1, 0, dataToCopy, valMACDSignal_D1) < dataToCopy) return(false); // Signal line
   // 4-Hour
   if(CopyBuffer(hMA_Fast_H4, 0, 0, dataToCopy, valMA_Fast_H4) < dataToCopy) return(false);
   if(CopyBuffer(hRSI_H4, 0, 0, dataToCopy, valRSI_H4) < dataToCopy) return(false);
   if(CopyBuffer(hMACD_H4, 0, 0, dataToCopy, valMACDMain_H4) < dataToCopy) return(false); // Main line
   if(CopyBuffer(hMACD_H4, 1, 0, dataToCopy, valMACDSignal_H4) < dataToCopy) return(false); // Signal line
   if(CopyBuffer(hATR_H4, 0, 0, dataToCopy, valATR_H4) < dataToCopy) return(false);

   return(true);
  }
//+------------------------------------------------------------------+
//| Helper function to calculate position size based on risk         |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLossDistance) // stopLossDistance in price units (e.g., price_entry - price_sl)
  {
   if(stopLossDistance <= 0) {
      Print(expertName, ": Stop loss distance is zero or negative (", DoubleToString(stopLossDistance, _Digits), "). Cannot calculate lot size.");
      return(0.0);
   }

   double accountBalance = AccountInfoDouble(ACCOUNT_EQUITY); // Use Equity for risk calculation
   if(accountBalance <= 0) {
        Print(expertName, ": Account Balance/Equity is zero or negative. Cannot calculate lot size.");
        return(0.0);
   }
   double riskAmount = accountBalance * (InpRiskPercent / 100.0);
   if(riskAmount <= 0) {
        Print(expertName, ": Calculated Risk Amount is zero or negative. Check Risk Percent input.");
        return(0.0);
   }

   // Use SYMBOL_TRADE_TICK_VALUE_LOSS for sell stops, SYMBOL_TRADE_TICK_VALUE_PROFIT for buy stops if needed for high precision,
   // but SYMBOL_TRADE_TICK_VALUE is often sufficient for crypto/forex. Check broker specifics.
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

    if(tickValue <= 0 || tickSize <= 0) {
        Print(expertName, ": Error getting symbol tick value/size for lot calculation. TickValue=", tickValue, ", TickSize=", tickSize);
        return(0.0);
    }

   // Calculate value per full point movement for 1 lot
   double valuePerPointPerLot = tickValue / tickSize; // Simplified: Value per point for 1 lot
    if (valuePerPointPerLot <= 0) {
         Print(expertName, ": Error calculating value per point per lot. TickValue=", tickValue, ", TickSize=", tickSize);
         return(0.0);
     }

   // Calculate risk per lot based on stop distance in price
   double riskPerLot = stopLossDistance * valuePerPointPerLot;
    if(riskPerLot <= 0) {
        Print(expertName, ": Error calculating risk per lot (SL distance might be too small or symbol info issue). SL Dist=", stopLossDistance, ", ValuePerPointPerLot=", valuePerPointPerLot);
        return(0.0);
    }


   // Calculate desired lot size
   double desiredLots = riskAmount / riskPerLot;

   //--- Normalize lot size according to broker limitations
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLots = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLots = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if(lotStep <=0 || minLots <= 0 || maxLots <= 0) {
        Print(expertName, ": Error getting symbol volume constraints (Step/Min/Max).");
        return(0.0); // Cannot normalize if constraints are invalid
   }


   desiredLots = MathFloor(desiredLots / lotStep) * lotStep; // Adjust down to nearest lot step

   // Check against min/max lot size
   if(desiredLots < minLots)
     {
      Print(expertName, ": Calculated lot size (", DoubleToString(desiredLots, 8), ") is below minimum (", DoubleToString(minLots, 8), "). Risk percent might be too low or SL too tight for minimum volume.");
      // Consider options: return 0.0 (safer), or return minLots if you ALWAYS want a position regardless of slightly higher risk %
      return(0.0);
     }
   if(desiredLots > maxLots)
     {
      desiredLots = maxLots;
      Print(expertName, ": Calculated lot size exceeds maximum. Using max lots: ", DoubleToString(maxLots, 8));
     }

    // Final check for validity
   if (desiredLots <= 0) {
       Print(expertName, ": Final calculated lot size is zero or negative after normalization.");
       return 0.0;
   }

   return(desiredLots);
  }
//+------------------------------------------------------------------+