//+------------------------------------------------------------------+
//|                                              10minentryvwap15.mq5 |
//|                                    Copyright 2025, Shivam Shikhar |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Shivam Shikhar"
#property link      ""
#property version   "1.00"

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

// Global variables
datetime last_bar_time_M15 = 0;
datetime last_bar_time_M10 = 0;
const double FIXED_LOT_SIZE = 0.20;
const string SYMBOL = "ETHUSDm";
const ENUM_TIMEFRAMES TIMEFRAME_M15 = PERIOD_M15;
const ENUM_TIMEFRAMES TIMEFRAME_M10 = PERIOD_M10;

// Variables to track crossover states
int last_crossover_m10 = 0;   // 0 = no crossover yet, 1 = bullish (EMA above VWAP), -1 = bearish (EMA below VWAP)
int last_crossover_m15 = 0;   // 0 = no crossover yet, 1 = bullish (EMA above VWAP), -1 = bearish (EMA below VWAP)

//+------------------------------------------------------------------+
//| Initialization Function                                          |
//+------------------------------------------------------------------+
void OnInit()
{
   // Create EMA9 indicator handle for M15
   ema9_handle_M15 = iMA(SYMBOL, TIMEFRAME_M15, 9, 0, MODE_EMA, PRICE_CLOSE);
   if(ema9_handle_M15 == INVALID_HANDLE)
   {
      Print("Failed to create EMA9 handle for M15. EA will terminate.");
      ExpertRemove();
      return;
   }

   // Create handle for custom VWAP indicator for M15
   vwap_handle_M15 = iCustom(SYMBOL, TIMEFRAME_M15, "VWAP_UTC_Final");
   if(vwap_handle_M15 == INVALID_HANDLE)
   {
      Print("Failed to create VWAP handle for M15. EA will terminate.");
      ExpertRemove();
      return;
   }

   // Create EMA9 indicator handle for M10
   ema9_handle_M10 = iMA(SYMBOL, TIMEFRAME_M10, 9, 0, MODE_EMA, PRICE_CLOSE);
   if(ema9_handle_M10 == INVALID_HANDLE)
   {
      Print("Failed to create EMA9 handle for M10. EA will terminate.");
      ExpertRemove();
      return;
   }

   // Create handle for custom VWAP indicator for M10
   vwap_handle_M10 = iCustom(SYMBOL, TIMEFRAME_M10, "VWAP_UTC_Final");
   if(vwap_handle_M10 == INVALID_HANDLE)
   {
      Print("Failed to create VWAP handle for M10. EA will terminate.");
      ExpertRemove();
      return;
   }

   // Initialize the crossover state based on current market conditions
   InitializeCrossoverStates();

   trade.SetDeviationInPoints(10); // Allow 1 pip slippage
   Print("EA initialized successfully on ", SYMBOL, " (M15 - Main, M10 - Entry)");
}

//+------------------------------------------------------------------+
//| Initialize crossover states based on current market conditions   |
//+------------------------------------------------------------------+
void InitializeCrossoverStates()
{
   // Get M10 indicator values
   double ema9_M10[];
   ArraySetAsSeries(ema9_M10, true);
   if(CopyBuffer(ema9_handle_M10, 0, 0, 2, ema9_M10) < 2)
   {
      Print("Failed to copy M10 EMA9 data for initialization");
      return;
   }

   double vwap_M10[];
   ArraySetAsSeries(vwap_M10, true);
   if(CopyBuffer(vwap_handle_M10, 0, 0, 2, vwap_M10) < 2)
   {
      Print("Failed to copy M10 VWAP data for initialization");
      return;
   }
   
   // Set initial M10 crossover state
   if(ema9_M10[1] > vwap_M10[1])
      last_crossover_m10 = 1;  // EMA above VWAP (bullish)
   else
      last_crossover_m10 = -1; // EMA below VWAP (bearish)
      
   // Get M15 indicator values
   double ema9_M15[];
   ArraySetAsSeries(ema9_M15, true);
   if(CopyBuffer(ema9_handle_M15, 0, 0, 2, ema9_M15) < 2)
   {
      Print("Failed to copy M15 EMA9 data for initialization");
      return;
   }

   double vwap_M15[];
   ArraySetAsSeries(vwap_M15, true);
   if(CopyBuffer(vwap_handle_M15, 0, 0, 2, vwap_M15) < 2)
   {
      Print("Failed to copy M15 VWAP data for initialization");
      return;
   }
   
   // Set initial M15 crossover state
   if(ema9_M15[1] > vwap_M15[1])
      last_crossover_m15 = 1;  // EMA above VWAP (bullish)
   else
      last_crossover_m15 = -1; // EMA below VWAP (bearish)
      
   Print("Crossover states initialized: M10=", last_crossover_m10, ", M15=", last_crossover_m15);
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
      double ema9_M15[];
      ArraySetAsSeries(ema9_M15, true);
      if(CopyBuffer(ema9_handle_M15, 0, 0, 3, ema9_M15) < 3)
      {
         Print("Failed to copy M15 EMA9 data");
         return;
      }

      double vwap_M15[];
      ArraySetAsSeries(vwap_M15, true);
      if(CopyBuffer(vwap_handle_M15, 0, 0, 3, vwap_M15) < 3)
      {
         Print("Failed to copy M15 VWAP data");
         return;
      }

      // Get previous M15 candle's close (for M15 exit)
      double close1_M15 = iClose(SYMBOL, TIMEFRAME_M15, 1);

      // Check and manage existing position (using M15 data for exit and better opportunity)
      if(PositionSelect(SYMBOL))
      {
         CheckExitCondition(close1_M15, ema9_M15[1]); // M15 Exit
         CheckBetterOpportunity(ema9_M15, vwap_M15);   // M15 Better Opportunity
      }
      
      // Update M15 crossover state
      if(ema9_M15[2] < vwap_M15[2] && ema9_M15[1] > vwap_M15[1]) // Bullish crossover
      {
         if(last_crossover_m15 != 1)
         {
            last_crossover_m15 = 1;
            Print("New M15 Bullish crossover detected");
         }
      }
      else if(ema9_M15[2] > vwap_M15[2] && ema9_M15[1] < vwap_M15[1]) // Bearish crossover
      {
         if(last_crossover_m15 != -1)
         {
            last_crossover_m15 = -1;
            Print("New M15 Bearish crossover detected");
         }
      }
   }

   //--- M10 Bar Check for Entry ---
   datetime current_bar_time_M10 = iTime(SYMBOL, TIMEFRAME_M10, 0);
   if(current_bar_time_M10 > last_bar_time_M10)
   {
      last_bar_time_M10 = current_bar_time_M10;

      // Get M10 indicator values
      double ema9_M10[];
      ArraySetAsSeries(ema9_M10, true);
      if(CopyBuffer(ema9_handle_M10, 0, 0, 3, ema9_M10) < 3)
      {
         Print("Failed to copy M10 EMA9 data");
         return;
      }

      double vwap_M10[];
      ArraySetAsSeries(vwap_M10, true);
      if(CopyBuffer(vwap_handle_M10, 0, 0, 3, vwap_M10) < 3)
      {
         Print("Failed to copy M10 VWAP data");
         return;
      }

      // Get M15 VWAP for SL calculation (as requested - rest 15min candle sl)
      double vwap_M15_for_SL[];
      ArraySetAsSeries(vwap_M15_for_SL, true);
      if(CopyBuffer(vwap_handle_M15, 0, 0, 3, vwap_M15_for_SL) < 3)
      {
         Print("Failed to copy M15 VWAP data for SL");
         return;
      }

      // Check Entry Conditions on M10 timeframe
      if(!PositionSelect(SYMBOL)) // Check for no existing position before entry
      {
         CheckEntryConditions_M10(ema9_M10, vwap_M10, vwap_M15_for_SL); // Pass M15 VWAP for SL
      }
      
      // Update M10 crossover state (do this even if we don't enter a trade)
      if(ema9_M10[2] < vwap_M10[2] && ema9_M10[1] > vwap_M10[1]) // Bullish crossover
      {
         if(last_crossover_m10 != 1)
         {
            last_crossover_m10 = 1;
            Print("New M10 Bullish crossover detected");
         }
      }
      else if(ema9_M10[2] > vwap_M10[2] && ema9_M10[1] < vwap_M10[1]) // Bearish crossover
      {
         if(last_crossover_m10 != -1)
         {
            last_crossover_m10 = -1;
            Print("New M10 Bearish crossover detected");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check Entry Conditions on M10 Timeframe                             |
//+------------------------------------------------------------------+
void CheckEntryConditions_M10(double &ema9_M10[], double &vwap_M10[], double &vwap_M15_for_SL[])
{
   int digits = (int)SymbolInfoInteger(SYMBOL, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(SYMBOL, SYMBOL_POINT);

   // Buy condition: M10 EMA9 crosses above M10 VWAP
   if(ema9_M10[2] < vwap_M10[2] && ema9_M10[1] > vwap_M10[1])
   {
      // Check if this is a new crossover (one-trade-per-crossover rule)
      if(last_crossover_m10 != 1)
      {
         double sl = NormalizeDouble(vwap_M15_for_SL[1] - 3 * point, digits); // SL from M15 VWAP
         if(trade.Buy(FIXED_LOT_SIZE, SYMBOL, 0.0, sl, 0.0))
         {
            Print("Buy trade opened (M10 Entry) with SL: ", sl, " (based on M15 VWAP)");
            last_crossover_m10 = 1; // Update crossover state
         }
      }
      else
      {
         Print("Skipping Buy entry - already entered this crossover");
      }
   }
   // Sell condition: M10 EMA9 crosses below M10 VWAP
   else if(ema9_M10[2] > vwap_M10[2] && ema9_M10[1] < vwap_M10[1])
   {
      // Check if this is a new crossover (one-trade-per-crossover rule)
      if(last_crossover_m10 != -1)
      {
         double sl = NormalizeDouble(vwap_M15_for_SL[1] + 3 * point, digits); // SL from M15 VWAP
         if(trade.Sell(FIXED_LOT_SIZE, SYMBOL, 0.0, sl, 0.0))
         {
            Print("Sell trade opened (M10 Entry) with SL: ", sl, " (based on M15 VWAP)");
            last_crossover_m10 = -1; // Update crossover state
         }
      }
      else
      {
         Print("Skipping Sell entry - already entered this crossover");
      }
   }
}

//+------------------------------------------------------------------+
//| Check Exit Condition                                             |
//+------------------------------------------------------------------+
void CheckExitCondition(double close1_M15, double ema9_prev_M15)
{
   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
   {
      if(close1_M15 < ema9_prev_M15)
      {
         trade.PositionClose(SYMBOL);
         Print("Buy position closed (M15 Exit) - previous M15 candle closed below M15 EMA9");
      }
   }
   else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
   {
      if(close1_M15 > ema9_prev_M15)
      {
         trade.PositionClose(SYMBOL);
         Print("Sell position closed (M15 Exit) - previous M15 candle closed above M15 EMA9");
      }
   }
}

//+------------------------------------------------------------------+
//| Check for Better Opportunity                                     |
//+------------------------------------------------------------------+
void CheckBetterOpportunity(double &ema9_M15[], double &vwap_M15[])
{
   int digits = (int)SymbolInfoInteger(SYMBOL, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(SYMBOL, SYMBOL_POINT);

   if(PositionSelect(SYMBOL))
   {
      long pos_type = PositionGetInteger(POSITION_TYPE);
      // Switch from sell to buy (M15 Condition)
      if(pos_type == POSITION_TYPE_SELL && ema9_M15[2] < vwap_M15[2] && ema9_M15[1] > vwap_M15[1])
      {
         // Check if this is a new crossover (one-trade-per-crossover rule)
         if(last_crossover_m15 != 1)
         {
            trade.PositionClose(SYMBOL);
            double sl = NormalizeDouble(vwap_M15[1] - 3 * point, digits);
            trade.Buy(FIXED_LOT_SIZE, SYMBOL, 0.0, sl, 0.0);
            Print("Switched from Sell to Buy trade (M15 Opportunity)");
            last_crossover_m15 = 1; // Update crossover state
         }
      }
      // Switch from buy to sell (M15 Condition)
      else if(pos_type == POSITION_TYPE_BUY && ema9_M15[2] > vwap_M15[2] && ema9_M15[1] < vwap_M15[1])
      {
         // Check if this is a new crossover (one-trade-per-crossover rule)
         if(last_crossover_m15 != -1)
         {
            trade.PositionClose(SYMBOL);
            double sl = NormalizeDouble(vwap_M15[1] + 3 * point, digits);
            trade.Sell(FIXED_LOT_SIZE, SYMBOL, 0.0, sl, 0.0);
            Print("Switched from Buy to Sell trade (M15 Opportunity)");
            last_crossover_m15 = -1; // Update crossover state
         }
      }
   }
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
   Print("EA deinitialized. Reason: ", reason);
}