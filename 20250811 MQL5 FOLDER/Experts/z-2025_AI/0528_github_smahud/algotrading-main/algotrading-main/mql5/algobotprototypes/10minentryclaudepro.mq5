//+------------------------------------------------------------------+
//|                                                 ImprovedETH.mq5 |
//|                                    Copyright 2025, Shivam Shikhar |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Shivam Shikhar"
#property link      ""
#property version   "2.00"

//+------------------------------------------------------------------+
//| Includes and Declarations                                        |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

// Declare trade object
CTrade trade;

// Indicator handles
int ema9_handle_M15;
int vwap_handle_M15;
int ema9_handle_M10;
int vwap_handle_M10;
int atr_handle_M15;       // ATR for dynamic SL/TP
int rsi_handle_M15;       // RSI for trend filter
int macd_handle_M15;      // MACD for additional confirmation

// Global variables
datetime last_bar_time_M15 = 0;
datetime last_bar_time_M10 = 0;
const double FIXED_LOT_SIZE = 0.20;
const string SYMBOL = "ETHUSDm";
const ENUM_TIMEFRAMES TIMEFRAME_M15 = PERIOD_M15;
const ENUM_TIMEFRAMES TIMEFRAME_M10 = PERIOD_M10;

// Strategy parameters (can be optimized)
input double TP_ATR_Multiplier = 2.0;    // Take Profit multiplier (based on ATR)
input double SL_ATR_Multiplier = 1.0;    // Stop Loss multiplier (based on ATR)
input int RSI_Period = 14;               // RSI period
input int RSI_Overbought = 70;           // RSI overbought level
input int RSI_Oversold = 30;             // RSI oversold level
input bool UseTimeFilter = true;         // Use time filter
input int StartHour = 1;                 // Trading start hour (0-23)
input int EndHour = 23;                  // Trading end hour (0-23)
input int MAFastPeriod = 12;             // MACD fast EMA period
input int MASlowPeriod = 26;             // MACD slow EMA period
input int MASignalPeriod = 9;            // MACD signal line period
input int MinimumConsolidation = 3;      // Minimum candles in consolidation before entry

//+------------------------------------------------------------------+
//| Initialization Function                                          |
//+------------------------------------------------------------------+
void OnInit()
{
   // Create indicator handles for M15
   ema9_handle_M15 = iMA(SYMBOL, TIMEFRAME_M15, 9, 0, MODE_EMA, PRICE_CLOSE);
   vwap_handle_M15 = iCustom(SYMBOL, TIMEFRAME_M15, "VWAP_UTC_Final");
   atr_handle_M15 = iATR(SYMBOL, TIMEFRAME_M15, 14);
   rsi_handle_M15 = iRSI(SYMBOL, TIMEFRAME_M15, RSI_Period, PRICE_CLOSE);
   macd_handle_M15 = iMACD(SYMBOL, TIMEFRAME_M15, MAFastPeriod, MASlowPeriod, MASignalPeriod, PRICE_CLOSE);
   
   // Create indicator handles for M10
   ema9_handle_M10 = iMA(SYMBOL, TIMEFRAME_M10, 9, 0, MODE_EMA, PRICE_CLOSE);
   vwap_handle_M10 = iCustom(SYMBOL, TIMEFRAME_M10, "VWAP_UTC_Final");
   
   // Check for valid handles
   if(ema9_handle_M15 == INVALID_HANDLE || vwap_handle_M15 == INVALID_HANDLE || 
      ema9_handle_M10 == INVALID_HANDLE || vwap_handle_M10 == INVALID_HANDLE ||
      atr_handle_M15 == INVALID_HANDLE || rsi_handle_M15 == INVALID_HANDLE ||
      macd_handle_M15 == INVALID_HANDLE)
   {
      Print("Failed to create indicator handles. EA will terminate.");
      ExpertRemove();
      return;
   }

   trade.SetDeviationInPoints(10);
   Print("Improved EA initialized on ", SYMBOL);
}

//+------------------------------------------------------------------+
//| Main Tick Function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check if we're in the allowed trading hours
   if(UseTimeFilter && !IsTradeAllowed())
      return;
      
   //--- M15 Bar Check ---
   datetime current_bar_time_M15 = iTime(SYMBOL, TIMEFRAME_M15, 0);
   if(current_bar_time_M15 > last_bar_time_M15)
   {
      last_bar_time_M15 = current_bar_time_M15;

      // Get M15 indicator values
      double ema9_M15[];
      double vwap_M15[];
      double atr_M15[];
      double rsi_M15[];
      double macd_M15[];
      double macd_signal_M15[];
      
      ArraySetAsSeries(ema9_M15, true);
      ArraySetAsSeries(vwap_M15, true);
      ArraySetAsSeries(atr_M15, true);
      ArraySetAsSeries(rsi_M15, true);
      ArraySetAsSeries(macd_M15, true);
      ArraySetAsSeries(macd_signal_M15, true);
      
      if(CopyBuffer(ema9_handle_M15, 0, 0, 5, ema9_M15) < 5 ||
         CopyBuffer(vwap_handle_M15, 0, 0, 5, vwap_M15) < 5 ||
         CopyBuffer(atr_handle_M15, 0, 0, 5, atr_M15) < 5 ||
         CopyBuffer(rsi_handle_M15, 0, 0, 5, rsi_M15) < 5 ||
         CopyBuffer(macd_handle_M15, 0, 0, 5, macd_M15) < 5 ||
         CopyBuffer(macd_handle_M15, 1, 0, 5, macd_signal_M15) < 5)
      {
         Print("Failed to copy M15 indicator data");
         return;
      }

      // Get previous M15 candle's close
      double close1_M15 = iClose(SYMBOL, TIMEFRAME_M15, 1);

      // Check and manage existing position (using M15 data for exit)
      if(PositionSelect(SYMBOL))
      {
         CheckTakeProfit(atr_M15[1]); // Dynamic TP based on ATR
         CheckExitCondition(close1_M15, ema9_M15[1], macd_M15, macd_signal_M15); // Enhanced exit
         CheckTrailingStop(atr_M15[1]); // Trailing stop based on ATR
      }
   }

   //--- M10 Bar Check for Entry ---
   datetime current_bar_time_M10 = iTime(SYMBOL, TIMEFRAME_M10, 0);
   if(current_bar_time_M10 > last_bar_time_M10)
   {
      last_bar_time_M10 = current_bar_time_M10;

      // Get M10 indicator values
      double ema9_M10[];
      double vwap_M10[];
      
      ArraySetAsSeries(ema9_M10, true);
      ArraySetAsSeries(vwap_M10, true);
      
      if(CopyBuffer(ema9_handle_M10, 0, 0, 10, ema9_M10) < 10 ||
         CopyBuffer(vwap_handle_M10, 0, 0, 10, vwap_M10) < 10)
      {
         Print("Failed to copy M10 indicator data");
         return;
      }

      // Get M15 data for entry filters
      double atr_M15[];
      double rsi_M15[];
      double macd_M15[];
      double macd_signal_M15[];
      
      ArraySetAsSeries(atr_M15, true);
      ArraySetAsSeries(rsi_M15, true);
      ArraySetAsSeries(macd_M15, true);
      ArraySetAsSeries(macd_signal_M15, true);
      
      if(CopyBuffer(atr_handle_M15, 0, 0, 5, atr_M15) < 5 ||
         CopyBuffer(rsi_handle_M15, 0, 0, 5, rsi_M15) < 5 ||
         CopyBuffer(macd_handle_M15, 0, 0, 5, macd_M15) < 5 ||
         CopyBuffer(macd_handle_M15, 1, 0, 5, macd_signal_M15) < 5)
      {
         Print("Failed to copy M15 filter data");
         return;
      }

      // Check Entry Conditions on M10 timeframe with additional filters
      if(!PositionSelect(SYMBOL)) // Check for no existing position before entry
      {
         CheckImprovedEntryConditions(ema9_M10, vwap_M10, atr_M15[1], rsi_M15[1], macd_M15, macd_signal_M15);
      }
   }
}

//+------------------------------------------------------------------+
//| Improved Entry Conditions                                        |
//+------------------------------------------------------------------+
void CheckImprovedEntryConditions(double &ema9_M10[], double &vwap_M10[], double atr_value, 
                                 double rsi_value, double &macd_main[], double &macd_signal[])
{
   int digits = (int)SymbolInfoInteger(SYMBOL, SYMBOL_DIGITS);
   double ask = SymbolInfoDouble(SYMBOL, SYMBOL_ASK);
   double bid = SymbolInfoDouble(SYMBOL, SYMBOL_BID);

   // Check for price consolidation before entry (reduces false signals)
   bool isConsolidating = IsConsolidating(MinimumConsolidation, TIMEFRAME_M10);
   if(!isConsolidating)
      return;

   // Buy condition with multiple filters
   if(ema9_M10[2] < vwap_M10[2] && ema9_M10[1] > vwap_M10[1] && // EMA-VWAP crossover
      rsi_value > 30 && rsi_value < 70 &&                      // RSI filter (avoid overbought/oversold)
      macd_main[1] > macd_signal[1] &&                         // MACD bullish
      IsBullishVolatility(TIMEFRAME_M15))                      // Volatility filter
   {
      double sl = NormalizeDouble(bid - atr_value * SL_ATR_Multiplier, digits);
      double tp = NormalizeDouble(ask + atr_value * TP_ATR_Multiplier, digits);
      
      if(trade.Buy(FIXED_LOT_SIZE, SYMBOL, 0.0, sl, tp))
      {
         Print("Buy trade opened with dynamic SL: ", sl, " and TP: ", tp);
      }
   }
   // Sell condition with multiple filters
   else if(ema9_M10[2] > vwap_M10[2] && ema9_M10[1] < vwap_M10[1] && // EMA-VWAP crossover
           rsi_value < 70 && rsi_value > 30 &&                      // RSI filter (avoid overbought/oversold)
           macd_main[1] < macd_signal[1] &&                         // MACD bearish
           IsBearishVolatility(TIMEFRAME_M15))                      // Volatility filter
   {
      double sl = NormalizeDouble(ask + atr_value * SL_ATR_Multiplier, digits);
      double tp = NormalizeDouble(bid - atr_value * TP_ATR_Multiplier, digits);
      
      if(trade.Sell(FIXED_LOT_SIZE, SYMBOL, 0.0, sl, tp))
      {
         Print("Sell trade opened with dynamic SL: ", sl, " and TP: ", tp);
      }
   }
}

//+------------------------------------------------------------------+
//| Check if price is consolidating (reduces false entries)          |
//+------------------------------------------------------------------+
bool IsConsolidating(int bars, ENUM_TIMEFRAMES timeframe)
{
   double high[], low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   if(CopyHigh(SYMBOL, timeframe, 0, bars+1, high) < bars+1 ||
      CopyLow(SYMBOL, timeframe, 0, bars+1, low) < bars+1)
      return false;
      
   // Find highest high and lowest low
   double highest = high[ArrayMaximum(high, 0, bars)];
   double lowest = low[ArrayMinimum(low, 0, bars)];
   
   // Calculate range as percentage of price
   double price = (highest + lowest) / 2;
   double range = (highest - lowest) / price * 100;
   
   // If range is less than 1%, consider it consolidation
   return range < 1.0;
}

//+------------------------------------------------------------------+
//| Volatility Filters                                               |
//+------------------------------------------------------------------+
bool IsBullishVolatility(ENUM_TIMEFRAMES timeframe)
{
   double atr[];
   ArraySetAsSeries(atr, true);
   
   if(CopyBuffer(atr_handle_M15, 0, 0, 5, atr) < 5)
      return false;
      
   // Check if ATR is increasing (more volatile markets)
   return atr[1] > atr[2] && atr[2] > atr[3];
}

bool IsBearishVolatility(ENUM_TIMEFRAMES timeframe)
{
   double atr[];
   ArraySetAsSeries(atr, true);
   
   if(CopyBuffer(atr_handle_M15, 0, 0, 5, atr) < 5)
      return false;
      
   // Check if ATR is increasing (more volatile markets)
   return atr[1] > atr[2] && atr[2] > atr[3];
}

//+------------------------------------------------------------------+
//| Enhanced Exit Condition                                          |
//+------------------------------------------------------------------+
void CheckExitCondition(double close1_M15, double ema9_prev_M15, double &macd_main[], double &macd_signal[])
{
   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
   {
      // Exit buy if one of these conditions is met
      if(close1_M15 < ema9_prev_M15 || // Original condition
         macd_main[1] < macd_signal[1]) // MACD bearish signal
      {
         trade.PositionClose(SYMBOL);
         Print("Buy position closed - enhanced exit conditions met");
      }
   }
   else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
   {
      // Exit sell if one of these conditions is met
      if(close1_M15 > ema9_prev_M15 || // Original condition
         macd_main[1] > macd_signal[1]) // MACD bullish signal
      {
         trade.PositionClose(SYMBOL);
         Print("Sell position closed - enhanced exit conditions met");
      }
   }
}

//+------------------------------------------------------------------+
//| Check Take Profit                                                |
//+------------------------------------------------------------------+
void CheckTakeProfit(double atr_value)
{
   if(!PositionSelect(SYMBOL))
      return;
      
   double currentProfit = PositionGetDouble(POSITION_PROFIT);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                        SymbolInfoDouble(SYMBOL, SYMBOL_BID) : SymbolInfoDouble(SYMBOL, SYMBOL_ASK);
   
   // Calculate profit in terms of ATR
   double priceDiff = MathAbs(currentPrice - openPrice);
   double profitInATR = priceDiff / atr_value;
   
   // If profit is substantial (more than TP_ATR_Multiplier), close position
   if(profitInATR >= TP_ATR_Multiplier && currentProfit > 0)
   {
      trade.PositionClose(SYMBOL);
      Print("Position closed at dynamic take profit level. Profit in ATR: ", profitInATR);
   }
}

//+------------------------------------------------------------------+
//| Trailing Stop based on ATR                                       |
//+------------------------------------------------------------------+
void CheckTrailingStop(double atr_value)
{
   if(!PositionSelect(SYMBOL))
      return;
      
   double currentSL = PositionGetDouble(POSITION_SL);
   int digits = (int)SymbolInfoInteger(SYMBOL, SYMBOL_DIGITS);
   
   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
   {
      double newSL = NormalizeDouble(SymbolInfoDouble(SYMBOL, SYMBOL_BID) - atr_value * SL_ATR_Multiplier, digits);
      
      // Only move stop loss up
      if(newSL > currentSL)
      {
         trade.PositionModify(SYMBOL, newSL, PositionGetDouble(POSITION_TP));
         Print("Buy trailing stop moved to: ", newSL);
      }
   }
   else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
   {
      double newSL = NormalizeDouble(SymbolInfoDouble(SYMBOL, SYMBOL_ASK) + atr_value * SL_ATR_Multiplier, digits);
      
      // Only move stop loss down
      if(newSL < currentSL || currentSL == 0)
      {
         trade.PositionModify(SYMBOL, newSL, PositionGetDouble(POSITION_TP));
         Print("Sell trailing stop moved to: ", newSL);
      }
   }
}

//+------------------------------------------------------------------+
//| Check if trading is allowed based on time                        |
//+------------------------------------------------------------------+
bool IsTradeAllowed()
{
   datetime serverTime = TimeCurrent();
   MqlDateTime timeStruct;
   TimeToStruct(serverTime, timeStruct);
   
   int hour = timeStruct.hour;
   
   // Allow trading only during specified hours
   return (hour >= StartHour && hour <= EndHour);
}

//+------------------------------------------------------------------+
//| Deinitialization Function                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(ema9_handle_M15 != INVALID_HANDLE)
      IndicatorRelease(ema9_handle_M15);
   if(vwap_handle_M15 != INVALID_HANDLE)
      IndicatorRelease(vwap_handle_M15);
   if(ema9_handle_M10 != INVALID_HANDLE)
      IndicatorRelease(ema9_handle_M10);
   if(vwap_handle_M10 != INVALID_HANDLE)
      IndicatorRelease(vwap_handle_M10);
   if(atr_handle_M15 != INVALID_HANDLE)
      IndicatorRelease(atr_handle_M15);
   if(rsi_handle_M15 != INVALID_HANDLE)
      IndicatorRelease(rsi_handle_M15);
   if(macd_handle_M15 != INVALID_HANDLE)
      IndicatorRelease(macd_handle_M15);
      
   Print("EA deinitialized. Reason: ", reason);
}