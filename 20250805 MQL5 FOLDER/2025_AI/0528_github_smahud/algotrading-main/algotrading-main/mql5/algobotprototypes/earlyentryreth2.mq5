//+------------------------------------------------------------------+
//|                                                       XAUUSD.mq5 |
//|                                    Copyright 2025, Shivam Shikhar |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Shivam Shikhar"
#property link      ""
#property version   "1.10"

//+------------------------------------------------------------------+
//| Includes and Declarations                                        |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

// Declare trade object
CTrade trade;

// Indicator handles
int ema9_handle_M15;
int vwap_handle_M15;      // Handle for custom VWAP indicator on M15
int ema9_handle_M10;
int vwap_handle_M10;      // Handle for custom VWAP indicator on M10
int ema50_handle_M15;
int ema200_handle_M15;
int atr_handle_M15;

// Global variables
datetime last_bar_time_M15 = 0;
datetime last_bar_time_M10 = 0;
const string SYMBOL = "ETHUSDm";
const ENUM_TIMEFRAMES TIMEFRAME_M15 = PERIOD_M15;
const ENUM_TIMEFRAMES TIMEFRAME_M10 = PERIOD_M10;

// Risk Management Variables
const double RISK_PERCENTAGE = 1.0;  // Risk per trade
const double MAX_RISK_PER_TRADE = 0.02;  // 2% max risk

//+------------------------------------------------------------------+
//| Initialization Function                                          |
//+------------------------------------------------------------------+
int OnInit()
{
   // Create EMA9 indicator handle for M15
   ema9_handle_M15 = iMA(SYMBOL, TIMEFRAME_M15, 9, 0, MODE_EMA, PRICE_CLOSE);
   if(ema9_handle_M15 == INVALID_HANDLE)
   {
      Print("Failed to create EMA9 handle for M15. EA will terminate.");
      return INIT_FAILED;
   }

   // Create handle for custom VWAP indicator for M15
   vwap_handle_M15 = iCustom(SYMBOL, TIMEFRAME_M15, "VWAP_UTC_Final");
   if(vwap_handle_M15 == INVALID_HANDLE)
   {
      Print("Failed to create VWAP handle for M15. EA will terminate.");
      return INIT_FAILED;
   }

   // Create EMA9 indicator handle for M10
   ema9_handle_M10 = iMA(SYMBOL, TIMEFRAME_M10, 9, 0, MODE_EMA, PRICE_CLOSE);
   if(ema9_handle_M10 == INVALID_HANDLE)
   {
      Print("Failed to create EMA9 handle for M10. EA will terminate.");
      return INIT_FAILED;
   }

   // Create handle for custom VWAP indicator for M10
   vwap_handle_M10 = iCustom(SYMBOL, TIMEFRAME_M10, "VWAP_UTC_Final");
   if(vwap_handle_M10 == INVALID_HANDLE)
   {
      Print("Failed to create VWAP handle for M10. EA will terminate.");
      return INIT_FAILED;
   }

   // Additional trend confirmation handles
   ema50_handle_M15 = iMA(SYMBOL, TIMEFRAME_M15, 50, 0, MODE_EMA, PRICE_CLOSE);
   ema200_handle_M15 = iMA(SYMBOL, TIMEFRAME_M15, 200, 0, MODE_EMA, PRICE_CLOSE);
   atr_handle_M15 = iATR(SYMBOL, TIMEFRAME_M15, 14);

   trade.SetDeviationInPoints(10); // Allow 1 pip slippage
   Print("EA initialized successfully on ", SYMBOL, " (M15 - Main, M10 - Entry)");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Main Tick Function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- M15 Bar Check ---
   datetime current_bar_time_M15 = iTime(SYMBOL, TIMEFRAME_M15, 0);
   if(current_bar_time_M15 > last_bar_time_M15)
   {
      last_bar_time_M15 = current_bar_time_M15;

      // Get M15 indicator values
      double ema9_M15[], vwap_M15[], ema50_M15[], ema200_M15[], atr_M15[];
      ArraySetAsSeries(ema9_M15, true);
      ArraySetAsSeries(vwap_M15, true);
      ArraySetAsSeries(ema50_M15, true);
      ArraySetAsSeries(ema200_M15, true);
      ArraySetAsSeries(atr_M15, true);

      if(CopyBuffer(ema9_handle_M15, 0, 0, 3, ema9_M15) < 3 ||
         CopyBuffer(vwap_handle_M15, 0, 0, 3, vwap_M15) < 3 ||
         CopyBuffer(ema50_handle_M15, 0, 0, 3, ema50_M15) < 3 ||
         CopyBuffer(ema200_handle_M15, 0, 0, 3, ema200_M15) < 3 ||
         CopyBuffer(atr_handle_M15, 0, 0, 3, atr_M15) < 3)
      {
         Print("Failed to copy M15 indicator data");
         return;
      }

      // Get previous M15 candle's close (for M15 exit)
      double close1_M15 = iClose(SYMBOL, TIMEFRAME_M15, 1);

      // Check and manage existing position (using M15 data for exit and better opportunity)
      if(PositionSelect(SYMBOL))
      {
         CheckExitCondition(close1_M15, ema9_M15[1], ema50_M15[1], ema200_M15[1]);
         CheckBetterOpportunity(ema9_M15, vwap_M15, ema50_M15, ema200_M15, atr_M15);
      }
   }

   //--- M10 Bar Check for Entry ---
   datetime current_bar_time_M10 = iTime(SYMBOL, TIMEFRAME_M10, 0);
   if(current_bar_time_M10 > last_bar_time_M10)
   {
      last_bar_time_M10 = current_bar_time_M10;

      // Get M10 indicator values
      double ema9_M10[], vwap_M10[], vwap_M15_for_SL[];
      ArraySetAsSeries(ema9_M10, true);
      ArraySetAsSeries(vwap_M10, true);
      ArraySetAsSeries(vwap_M15_for_SL, true);

      if(CopyBuffer(ema9_handle_M10, 0, 0, 3, ema9_M10) < 3 ||
         CopyBuffer(vwap_handle_M10, 0, 0, 3, vwap_M10) < 3 ||
         CopyBuffer(vwap_handle_M15, 0, 0, 3, vwap_M15_for_SL) < 3)
      {
         Print("Failed to copy M10 indicator data");
         return;
      }

      // Check Entry Conditions on M10 timeframe
      if(!PositionSelect(SYMBOL)) // Check for no existing position before entry
      {
         CheckEntryConditions_M10(ema9_M10, vwap_M10, vwap_M15_for_SL);
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Dynamic Position Size                                  |
//+------------------------------------------------------------------+
double CalculatePositionSize(double stop_loss_price)
{
   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double current_price = SymbolInfoDouble(SYMBOL, SYMBOL_LAST);
   double point = SymbolInfoDouble(SYMBOL, SYMBOL_POINT);
   
   // Calculate stop loss distance in points
   double stop_loss_distance = MathAbs(current_price - stop_loss_price) / point;
   
   // Risk calculation
   double risk_amount = account_balance * MathMin(RISK_PERCENTAGE, MAX_RISK_PER_TRADE) / 100;
   
   // Get tick value
   double tick_value = SymbolInfoDouble(SYMBOL, SYMBOL_TRADE_TICK_VALUE);
   
   // Calculate lot size
   double lot_size = risk_amount / (stop_loss_distance * tick_value);
   
   // Normalize lot size to broker's requirements
   double min_lot = SymbolInfoDouble(SYMBOL, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(SYMBOL, SYMBOL_VOLUME_MAX);
   
   return NormalizeDouble(MathMin(MathMax(lot_size, min_lot), max_lot), 2);
}

//+------------------------------------------------------------------+
//| Check Entry Conditions on M10 Timeframe                          |
//+------------------------------------------------------------------+
void CheckEntryConditions_M10(double &ema9_M10[], double &vwap_M10[], double &vwap_M15_for_SL[])
{
   int digits = (int)SymbolInfoInteger(SYMBOL, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(SYMBOL, SYMBOL_POINT);
   
   // Get current market price
   double current_price = SymbolInfoDouble(SYMBOL, SYMBOL_LAST);
   
   // Volatility and trend check
   double atr_value = iATR(SYMBOL, TIMEFRAME_M15, 14, 0);
   double volatility_threshold = 2.0 * point;

   // Buy condition
   if(ema9_M10[2] < vwap_M10[2] && ema9_M10[1] > vwap_M10[1] && 
      atr_value < volatility_threshold)
   {
      double sl = NormalizeDouble(vwap_M15_for_SL[1] - 3 * point, digits);
      double tp = NormalizeDouble(current_price + (current_price - sl) * 2, digits);
      
      double lot_size = CalculatePositionSize(sl);
      
      if(trade.Buy(lot_size, SYMBOL, 0.0, sl, tp))
      {
         Print("Buy trade opened - Lot Size: ", lot_size, " SL: ", sl, " TP: ", tp);
      }
   }
   // Sell condition
   else if(ema9_M10[2] > vwap_M10[2] && ema9_M10[1] < vwap_M10[1] && 
           atr_value < volatility_threshold)
   {
      double sl = NormalizeDouble(vwap_M15_for_SL[1] + 3 * point, digits);
      double tp = NormalizeDouble(current_price - (sl - current_price) * 2, digits);
      
      double lot_size = CalculatePositionSize(sl);
      
      if(trade.Sell(lot_size, SYMBOL, 0.0, sl, tp))
      {
         Print("Sell trade opened - Lot Size: ", lot_size, " SL: ", sl, " TP: ", tp);
      }
   }
}

//+------------------------------------------------------------------+
//| Enhanced Exit Strategy with Trailing Stop                        |
//+------------------------------------------------------------------+
void CheckExitCondition(double close1_M15, double ema9_prev_M15, double ema50_M15, double ema200_M15)
{
   if(PositionSelect(SYMBOL))
   {
      double current_price = SymbolInfoDouble(SYMBOL, SYMBOL_LAST);
      double point = SymbolInfoDouble(SYMBOL, SYMBOL_POINT);
      double sl = PositionGetDouble(POSITION_SL);
      long pos_type = PositionGetInteger(POSITION_TYPE);
      
      // Trailing stop and exit logic for Buy position
      if(pos_type == POSITION_TYPE_BUY)
      {
         // Trailing stop based on EMA
         double new_sl = current_price - (ema9_prev_M15 - current_price);
         if(new_sl > sl)
         {
            trade.PositionModify(SYMBOL, new_sl, PositionGetDouble(POSITION_TP));
         }
         
         // Exit conditions
         bool exit_condition = (close1_M15 < ema9_prev_M15) || 
                                (ema50_M15 < ema200_M15); // Trend reversal
         
         if(exit_condition)
         {
            trade.PositionClose(SYMBOL);
            Print("Buy position closed - Exit condition triggered");
         }
      }
      // Trailing stop and exit logic for Sell position
      else if(pos_type == POSITION_TYPE_SELL)
      {
         // Trailing stop based on EMA
         double new_sl = current_price + (current_price - ema9_prev_M15);
         if(new_sl < sl)
         {
            trade.PositionModify(SYMBOL, new_sl, PositionGetDouble(POSITION_TP));
         }
         
         // Exit conditions
         bool exit_condition = (close1_M15 > ema9_prev_M15) || 
                                (ema50_M15 > ema200_M15); // Trend reversal
         
         if(exit_condition)
         {
            trade.PositionClose(SYMBOL);
            Print("Sell position closed - Exit condition triggered");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Better Opportunity Check                                         |
//+------------------------------------------------------------------+
void CheckBetterOpportunity(double &ema9_M15[], double &vwap_M15[], 
                             double &ema50_M15[], double &ema200_M15[], 
                             double &atr_M15[])
{
   int digits = (int)SymbolInfoInteger(SYMBOL, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(SYMBOL, SYMBOL_POINT);
   double current_price = SymbolInfoDouble(SYMBOL, SYMBOL_LAST);

   if(PositionSelect(SYMBOL))
   {
      long pos_type = PositionGetInteger(POSITION_TYPE);
      double volatility_threshold = 2.0 * point;

      // Switch from sell to buy
      if(pos_type == POSITION_TYPE_SELL && 
         ema9_M15[2] < vwap_M15[2] && ema9_M15[1] > vwap_M15[1] && 
         atr_M15[1] < volatility_threshold && 
         ema50_M15[1] > ema200_M15[1])
      {
         trade.PositionClose(SYMBOL);
         double sl = NormalizeDouble(vwap_M15[1] - 3 * point, digits);
         double tp = NormalizeDouble(current_price + (current_price - sl) * 2, digits);
         double lot_size = CalculatePositionSize(sl);
         
         trade.Buy(lot_size, SYMBOL, 0.0, sl, tp);
         Print("sjks"}"Trading EA Continuation

         Print("Switched from Sell to Buy trade (M15 Opportunity)");
      }
      // Switch from buy to sell
      else if(pos_type == POSITION_TYPE_BUY && 
              ema9_M15[2] > vwap_M15[2] && ema9_M15[1] < vwap_M15[1] && 
              atr_M15[1] < volatility_threshold && 
              ema50_M15[1] < ema200_M15[1])
      {
         trade.PositionClose(SYMBOL);
         double sl = NormalizeDouble(vwap_M15[1] + 3 * point, digits);
         double tp = NormalizeDouble(current_price - (sl - current_price) * 2, digits);
         double lot_size = CalculatePositionSize(sl);
         
         trade.Sell(lot_size, SYMBOL, 0.0, sl, tp);
         Print("Switched from Buy to Sell trade (M15 Opportunity)");
      }
   }
}
