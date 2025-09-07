//+------------------------------------------------------------------+
//|                                                       XAUUSD.mq5 |
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
int ema9_handle;
int vwap_handle;  // Handle for custom VWAP indicator

// Global variables
datetime last_bar_time = 0;
const double FIXED_LOT_SIZE = 0.20;
const string SYMBOL = "ETHUSDm";
const ENUM_TIMEFRAMES TIMEFRAME = PERIOD_M15;

// Variables to track crossover state
bool crossover_detected = false;
bool crossover_is_buy = false;  // true for buy crossover, false for sell crossover
const double MIN_DISTANCE = 4.5; // Minimum absolute distance required between EMA and VWAP after crossover (in price units, not points)

//+------------------------------------------------------------------+
//| Initialization Function                                          |
//+------------------------------------------------------------------+
void OnInit()
{
   // Create EMA9 indicator handle
   ema9_handle = iMA(SYMBOL, TIMEFRAME, 9, 0, MODE_EMA, PRICE_CLOSE);
   if(ema9_handle == INVALID_HANDLE)
   {
      Print("Failed to create EMA9 handle. EA will terminate.");
      ExpertRemove();
      return;
   }
   
   // Create handle for custom VWAP indicator
   vwap_handle = iCustom(SYMBOL, TIMEFRAME, "VWAP_UTC_Final");
   if(vwap_handle == INVALID_HANDLE)
   {
      Print("Failed to create VWAP handle. EA will terminate.");
      ExpertRemove();
      return;
   }
   
   trade.SetDeviationInPoints(10); // Allow 1 pip slippage
   Print("EA initialized successfully on ", SYMBOL, " (M15)");
}

//+------------------------------------------------------------------+
//| Main Tick Function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new bar
   datetime current_bar_time = iTime(SYMBOL, TIMEFRAME, 0);
   if(current_bar_time <= last_bar_time)
      return;
   last_bar_time = current_bar_time;
   
   // Get indicator values
   double ema9[];
   ArraySetAsSeries(ema9, true);
   if(CopyBuffer(ema9_handle, 0, 0, 3, ema9) < 3)
   {
      Print("Failed to copy EMA9 data");
      return;
   }
   
   double vwap[];
   ArraySetAsSeries(vwap, true);
   if(CopyBuffer(vwap_handle, 0, 0, 3, vwap) < 3)
   {
      Print("Failed to copy VWAP data");
      return;
   }
   
   // Get previous candle's close
   double close1 = iClose(SYMBOL, TIMEFRAME, 1);
   
   // Check and manage existing position
   if(PositionSelect(SYMBOL))
   {
      CheckExitCondition(close1, ema9[1]);
      CheckBetterOpportunity(ema9, vwap);
   }
   else
   {
      // First detect crossovers
      DetectCrossovers(ema9, vwap);
      
      // Then check if we should enter based on the distance filter
      if(crossover_detected)
      {
         CheckDistanceAndEnter(ema9, vwap);
      }
   }
}

//+------------------------------------------------------------------+
//| Detect Crossovers                                                |
//+------------------------------------------------------------------+
void DetectCrossovers(double &ema9[], double &vwap[])
{
   // Buy condition: EMA9 crosses above VWAP
   if(ema9[2] < vwap[2] && ema9[1] > vwap[1])
   {
      crossover_detected = true;
      crossover_is_buy = true;
      Print("Buy crossover detected, waiting for ", MIN_DISTANCE, " distance");
   }
   // Sell condition: EMA9 crosses below VWAP
   else if(ema9[2] > vwap[2] && ema9[1] < vwap[1])
   {
      crossover_detected = true;
      crossover_is_buy = false;
      Print("Sell crossover detected, waiting for ", MIN_DISTANCE, " distance");
   }
}

//+------------------------------------------------------------------+
//| Check Distance Between EMA and VWAP and Enter Trade              |
//+------------------------------------------------------------------+
void CheckDistanceAndEnter(double &ema9[], double &vwap[])
{
   int digits = (int)SymbolInfoInteger(SYMBOL, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(SYMBOL, SYMBOL_POINT);
   
   // Calculate difference between EMA and VWAP (absolute price difference, not in points)
   double difference = MathAbs(ema9[1] - vwap[1]);
   
   // For buy condition (EMA above VWAP)
   if(crossover_is_buy)
   {
      // First check if the crossover is still valid
      if(ema9[1] <= vwap[1])
      {
         // Crossover is no longer valid
         crossover_detected = false;
         Print("Buy crossover invalidated - EMA crossed back below VWAP");
         return;
      }
      
      // Check if difference is greater than MIN_DISTANCE (using absolute price difference)
      if(difference > MIN_DISTANCE)
      {
         double sl = NormalizeDouble(vwap[1] - 3 * point, digits);
         if(trade.Buy(FIXED_LOT_SIZE, SYMBOL, 0.0, sl, 0.0))
         {
            Print("Buy trade opened with SL: ", sl, " after distance condition met (difference = ", difference, " | required = ", MIN_DISTANCE, ")");
            crossover_detected = false;  // Reset the crossover flag
         }
      }
      else
      {
         Print("Waiting for buy distance: current = ", difference, ", required = ", MIN_DISTANCE);
      }
   }
   // For sell condition (EMA below VWAP)
   else
   {
      // First check if the crossover is still valid
      if(ema9[1] >= vwap[1])
      {
         // Crossover is no longer valid
         crossover_detected = false;
         Print("Sell crossover invalidated - EMA crossed back above VWAP");
         return;
      }
      
      // Check if difference is greater than MIN_DISTANCE (using absolute price difference)
      if(difference > MIN_DISTANCE)
      {
         double sl = NormalizeDouble(vwap[1] + 3 * point, digits);
         if(trade.Sell(FIXED_LOT_SIZE, SYMBOL, 0.0, sl, 0.0))
         {
            Print("Sell trade opened with SL: ", sl, " after distance condition met (difference = ", difference, " | required = ", MIN_DISTANCE, ")");
            crossover_detected = false;  // Reset the crossover flag
         }
      }
      else
      {
         Print("Waiting for sell distance: current = ", difference, ", required = ", MIN_DISTANCE);
      }
   }
}

//+------------------------------------------------------------------+
//| Check Exit Condition                                             |
//+------------------------------------------------------------------+
void CheckExitCondition(double close1, double ema9_prev)
{
   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
   {
      if(close1 < ema9_prev)
      {
         trade.PositionClose(SYMBOL);
         Print("Buy position closed - previous candle closed below EMA9");
      }
   }
   else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
   {
      if(close1 > ema9_prev)
      {
         trade.PositionClose(SYMBOL);
         Print("Sell position closed - previous candle closed above EMA9");
      }
   }
}

//+------------------------------------------------------------------+
//| Check for Better Opportunity                                     |
//+------------------------------------------------------------------+
void CheckBetterOpportunity(double &ema9[], double &vwap[])
{
   int digits = (int)SymbolInfoInteger(SYMBOL, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(SYMBOL, SYMBOL_POINT);
   
   if(PositionSelect(SYMBOL))
   {
      long pos_type = PositionGetInteger(POSITION_TYPE);
      // Switch from sell to buy
      if(pos_type == POSITION_TYPE_SELL && ema9[2] < vwap[2] && ema9[1] > vwap[1])
      {
         // When we detect a crossover while in a position, we still want to respect the MIN_DISTANCE filter
         // So we close the current position and set the crossover detection flags
         trade.PositionClose(SYMBOL);
         Print("Closed Sell position due to Buy crossover");
         crossover_detected = true;
         crossover_is_buy = true;
      }
      // Switch from buy to sell
      else if(pos_type == POSITION_TYPE_BUY && ema9[2] > vwap[2] && ema9[1] < vwap[1])
      {
         // When we detect a crossover while in a position, we still want to respect the MIN_DISTANCE filter
         // So we close the current position and set the crossover detection flags
         trade.PositionClose(SYMBOL);
         Print("Closed Buy position due to Sell crossover");
         crossover_detected = true;
         crossover_is_buy = false;
      }
   }
}

//+------------------------------------------------------------------+
//| Deinitialization Function                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(ema9_handle != INVALID_HANDLE)
      IndicatorRelease(ema9_handle);
   if(vwap_handle != INVALID_HANDLE)
      IndicatorRelease(vwap_handle);
   Print("EA deinitialized. Reason: ", reason);
}