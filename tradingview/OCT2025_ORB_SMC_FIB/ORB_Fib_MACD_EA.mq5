/*
+----------------------------------------------------------------------+
|                               ORB_Fib_MACD_EA.mq5                     |
|                   Copyright 2025, Manus AI.                           |
|                               https://manus.im/                          |
+----------------------------------------------------------------------+
*/

#property copyright "2025, Manus AI"
#property link      "https://manus.im/"
#property version   "1.00"
#property description "ORB + Fibonacci + MACD Trading Strategy Expert Advisor"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//--- EA Properties
input int      InpOpeningRangeMinutes = 30;    // Opening Range Duration (minutes)
input double   InpFibEntryStart       = 0.50;   // Fibonacci Entry Zone Start
input double   InpFibEntryEnd         = 0.618;  // Fibonacci Entry Zone End
input double   InpStopLossFibLevel    = 0.786;  // Stop Loss Fibonacci Level

// Take Profit Strategy Selection
enum ENUM_TP_METHOD
{
   TP_SESSION_HIGH_LOW,      // Session High/Low
   TP_FIXED_POINTS,          // Fixed Points
   TP_RISK_REWARD_RATIO,     // Risk-Reward Ratio
   TP_RANGE_MULTIPLE,        // Range Multiple
   TP_FIBONACCI_EXTENSIONS   // Fibonacci Extensions
};
input ENUM_TP_METHOD InpTPMethod = TP_SESSION_HIGH_LOW; // Take Profit Method
input double   InpTPFixedPoints       = 100.0;  // TP Fixed Points (Pips)
input double   InpTPRiskRewardRatio   = 2.0;    // TP Risk-Reward Ratio (e.g., 2 for 1:2)
input double   InpTPRangeMultiplier   = 1.0;    // TP Opening Range Multiplier
input double   InpTPFibExtensionLevel = 1.272;  // TP Fibonacci Extension Level

// Stop Loss Strategy Selection
enum ENUM_SL_METHOD
{
   SL_FIBONACCI_LEVEL,       // Fibonacci Level
   SL_FIXED_POINTS,          // Fixed Points
   SL_ATR_BASED              // ATR-Based
};
input ENUM_SL_METHOD InpSLMethod = SL_FIBONACCI_LEVEL; // Stop Loss Method
input double   InpSLFixedPoints       = 50.0;   // SL Fixed Points (Pips)
input double   InpSLAtrMultiplier     = 1.5;    // SL ATR Multiplier
input int      InpSLAtrLength         = 14;     // SL ATR Length
input int      InpEmaFastLength       = 9;      // Fast EMA Length
input int      InpEmaSlowLength       = 21;     // Slow EMA Length
input int      InpMacdFastLength      = 12;     // MACD Fast Length
input int      InpMacdSlowLength      = 26;     // MACD Slow Length
input int      InpMacdSignalSmoothing = 9;      // MACD Signal Smoothing
input string   InpSessionSpec         = "09:30-16:00"; // Trading Session (e.g., HH:MM-HH:MM)
input double   InpLots                = 0.01;   // Lot size for trading
input int      InpMagicNumber         = 12345;  // Magic number for trades
input int      InpSlippage            = 3;      // Slippage in points

//--- Global Objects
CTrade      trade;
CPositionInfo posInfo;
COrderInfo  orderInfo;

//--- Global Variables
// Opening Range
static datetime prevDay = 0;
static double   openingRangeHigh = 0.0;
static double   openingRangeLow = 0.0;
static bool     isOpeningRangeSet = false;

// Session High/Low for Fib
static double   sessionHigh = 0.0;
static double   sessionLow = 0.0;

// Breakout Flags
static bool     bullishBreakout = false;
static bool     bearishBreakout = false;

// Fibonacci Levels (calculated dynamically)
static double   fib0 = 0.0;
static double   fib236 = 0.0;
static double   fib382 = 0.0;
static double   fib50 = 0.0;
static double   fib618 = 0.0;
static double   fib786 = 0.0;
static double   fib100 = 0.0;

// Indicator Handles
int macd_handle;
int emaFast_handle;
int emaSlow_handle;
int atr_handle;

//--- Buffer Arrays for Indicator Data
double macd_buffer[];
double signal_buffer[];
double hist_buffer[];
double emaFast_buffer[];
double emaSlow_buffer[];
double atr_buffer[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Initialize trade object
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetTypeFilling(ORDER_FILLING_FOK); // Fill or Kill for limit orders
   trade.SetDeviationInPoints(InpSlippage);

   //--- Check timeframe compatibility (e.g., M5)
   if (_Period != PERIOD_M5)
   {
      Print("EA requires M5 timeframe. Please switch to M5.");
      return INIT_FAILED;
   }

   //--- Get indicator handles
   macd_handle = iMACD(_Symbol, _Period, InpMacdFastLength, InpMacdSlowLength, InpMacdSignalSmoothing, PRICE_CLOSE);
   emaFast_handle = iMA(_Symbol, _Period, InpEmaFastLength, 0, MODE_EMA, PRICE_CLOSE);
   emaSlow_handle = iMA(_Symbol, _Period, InpEmaSlowLength, 0, MODE_EMA, PRICE_CLOSE);
atr_handle = iATR(_Symbol, _Period, InpSLAtrLength);
   
   if(macd_handle == INVALID_HANDLE || emaFast_handle == INVALID_HANDLE || emaSlow_handle == INVALID_HANDLE || atr_handle == INVALID_HANDLE)
   {
      Print("Error creating indicator handles");
      return INIT_FAILED;
   }
   
   //--- Set indicator buffer arrays as series
   SetIndexBuffer(0, macd_buffer, INDICATOR_DATA);
   SetIndexBuffer(1, signal_buffer, INDICATOR_DATA);
   SetIndexBuffer(2, hist_buffer, INDICATOR_DATA);
   SetIndexBuffer(0, emaFast_buffer, INDICATOR_DATA);
   SetIndexBuffer(0, emaSlow_buffer, INDICATOR_DATA);
SetIndexBuffer(0, atr_buffer, INDICATOR_DATA);

   //--- Other initialization checks
   //---
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Clean up indicator handles (not strictly necessary as MT5 handles it, but good practice)
   //IndicatorRelease(macd_handle);
   //IndicatorRelease(emaFast_handle);
   //IndicatorRelease(emaSlow_handle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check for new bar
   static datetime lastBarTime = 0;
   MqlRates rates[];
   if(CopyRates(_Symbol, _Period, 0, 1, rates) != 1) return; // Get current bar data
   datetime currentBarTime = rates[0].time;

   if (currentBarTime == lastBarTime) return; // Not a new bar
   lastBarTime = currentBarTime;

   //--- Get current price data (for the closed bar)
   if(CopyRates(_Symbol, _Period, 0, 2, rates) != 2) return; // Need at least 2 bars for calculations
   double current_close = rates[1].close;
   double current_high = rates[1].high;
   double current_low = rates[1].low;
   datetime current_time = rates[1].time;
   
   //--- Check for new day/session and reset variables
   ResetDailyVariables(current_time);

   //--- Calculate Opening Range
   CalculateOpeningRange(current_time, rates);
   
   //--- Update Session High/Low
   UpdateSessionHighLow(current_high, current_low);

   //--- Detect Breakouts
   DetectBreakouts(current_close);

   //--- Calculate Fibonacci Levels
   CalculateFibonacciLevels();

   //--- Get MACD and EMA values
   GetIndicatorValues();

   //--- Check Entry Conditions
   CheckEntryConditions();

   //--- Manage Trades (Stop Loss, Take Profit, Trend Weakness)
   ManageTrades();
}

//+------------------------------------------------------------------+
//| Helper functions                                                 |
//+------------------------------------------------------------------+
void ResetDailyVariables(datetime current_time)
{
   MqlDateTime dt;
   TimeToStruct(current_time, dt);
   
   if (dt.day != prevDay.day || dt.month != prevDay.month || dt.year != prevDay.year)
   {
      // New day detected
      prevDay = current_time;
      isOpeningRangeSet = false;
      openingRangeHigh = 0.0;
      openingRangeLow = 0.0;
      sessionHigh = rates[0].high; // Initialize with current bar's high
      sessionLow = rates[0].low;   // Initialize with current bar's low
      bullishBreakout = false;
      bearishBreakout = false;
      
      // Clear any pending orders from previous day if any
      for(int i=OrdersTotal()-1; i>=0; i--)
      {
         ulong ticket = orderInfo.GetTicket(i);
         if(orderInfo.Select(ticket) && orderInfo.GetMagic() == InpMagicNumber)
         {
            trade.OrderDelete(ticket);
         }
      }
   }
}

void CalculateOpeningRange(datetime current_time, const MqlRates &rates[])
{
   if (isOpeningRangeSet) return;

   MqlDateTime dt;
   TimeToStruct(current_time, dt);
   
   int currentBarMinute = dt.hour * 60 + dt.min;
   
   int sessionStartHour = StringToInteger(StringSubstr(InpSessionSpec, 0, 2));
   int sessionStartMinute = StringToInteger(StringSubstr(InpSessionSpec, 3, 2));
   int orEndHour = StringToInteger(StringSubstr(InpSessionSpec, 6, 2));
   int orEndMinute = StringToInteger(StringSubstr(InpSessionSpec, 9, 2));

   int sessionStartTotalMinutes = sessionStartHour * 60 + sessionStartMinute;
   int orEndTotalMinutes = sessionStartTotalMinutes + InpOpeningRangeMinutes;

   if (currentBarMinute >= sessionStartTotalMinutes && currentBarMinute < orEndTotalMinutes)
   {
      // If within the opening range period, update high/low
      if (openingRangeHigh == 0.0 || rates[1].high > openingRangeHigh) openingRangeHigh = rates[1].high;
      if (openingRangeLow == 0.0 || rates[1].low < openingRangeLow) openingRangeLow = rates[1].low;
   }
   else if (currentBarMinute >= orEndTotalMinutes && !isOpeningRangeSet)
   {
      // After the opening range period, set the final ORB values
      isOpeningRangeSet = true;
      if (openingRangeHigh == 0.0) // Fallback if no bars were captured (shouldn't happen on M5)
      {
         openingRangeHigh = rates[1].high; // Use current bar's high as fallback
         openingRangeLow = rates[1].low;  // Use current bar's low as fallback
      }
      Print("ORB Set: High=", openingRangeHigh, ", Low=", openingRangeLow);
   }
}

void UpdateSessionHighLow(double high_val, double low_val)
{
   if (high_val > sessionHigh) sessionHigh = high_val;
   if (low_val < sessionLow) sessionLow = low_val;
}

void DetectBreakouts(double current_close)
{
   if (!isOpeningRangeSet) return;
   
   if (!bullishBreakout && current_close > openingRangeHigh)
   {
      bullishBreakout = true;
      Print("Bullish Breakout Detected!");
   }
   if (!bearishBreakout && current_close < openingRangeLow)
   {
      bearishBreakout = true;
      Print("Bearish Breakout Detected!");
   }
}

void CalculateFibonacciLevels()
{
   if (!isOpeningRangeSet || (!bullishBreakout && !bearishBreakout)) return;

   double range = sessionHigh - sessionLow;
   if (range == 0) return; // Avoid division by zero

   if (bullishBreakout)
   {
      // For long setup, Fibs are drawn from sessionLow to sessionHigh
      fib0 = sessionLow;
      fib236 = sessionLow + range * 0.236;
      fib382 = sessionLow + range * 0.382;
      fib50 = sessionLow + range * 0.5;
      fib618 = sessionLow + range * 0.618;
      fib786 = sessionLow + range * 0.786;
      fib100 = sessionHigh;
   }
   else if (bearishBreakout)
   {
      // For short setup, Fibs are drawn from sessionHigh to sessionLow
      fib0 = sessionHigh;
      fib236 = sessionHigh - range * 0.236;
      fib382 = sessionHigh - range * 0.382;
      fib50 = sessionHigh - range * 0.5;
      fib618 = sessionHigh - range * 0.618;
      fib786 = sessionHigh - range * 0.786;
      fib100 = sessionLow;
   }
}

void GetIndicatorValues()
{
   // Copy MACD values
   if(CopyBuffer(macd_handle, 0, 0, 2, macd_buffer) < 2) return;
   if(CopyBuffer(macd_handle, 1, 0, 2, signal_buffer) < 2) return;
   if(CopyBuffer(macd_handle, 2, 0, 2, hist_buffer) < 2) return;

   // Copy EMA values
   if(CopyBuffer(emaFast_handle, 0, 0, 1, emaFast_buffer) < 1) return;
   if(CopyBuffer(emaSlow_handle, 0, 0, 1, emaSlow_buffer) < 1) return;

   // Copy ATR values
   if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) < 1) return;
}

double CalculateStopLoss(bool isLong, double entryPrice)
{
   double sl = 0.0;
   if (InpSLMethod == SL_FIBONACCI_LEVEL)
   {
      sl = fib786;
   }
   else if (InpSLMethod == SL_FIXED_POINTS)
   {
      sl = isLong ? entryPrice - InpSLFixedPoints * _Point : entryPrice + InpSLFixedPoints * _Point;
   }
   else if (InpSLMethod == SL_ATR_BASED)
   {
      if (ArraySize(atr_buffer) < 1) return 0.0; // Not enough ATR data
      sl = isLong ? entryPrice - atr_buffer[0] * InpSLAtrMultiplier : entryPrice + atr_buffer[0] * InpSLAtrMultiplier;
   }
   return NormalizeDouble(sl, _Digits);
}

double CalculateTakeProfit(bool isLong, double entryPrice, double stopLossPrice)
{
   double tp = 0.0;
   if (InpTPMethod == TP_SESSION_HIGH_LOW)
   {
      tp = isLong ? sessionHigh : sessionLow;
   }
   else if (InpTPMethod == TP_FIXED_POINTS)
   {
      tp = isLong ? entryPrice + InpTPFixedPoints * _Point : entryPrice - InpTPFixedPoints * _Point;
   }
   else if (InpTPMethod == TP_RISK_REWARD_RATIO)
   {
      double risk = MathAbs(entryPrice - stopLossPrice);
      tp = isLong ? entryPrice + risk * InpTPRiskRewardRatio : entryPrice - risk * InpTPRiskRewardRatio;
   }
   else if (InpTPMethod == TP_RANGE_MULTIPLE)
   {
      double orSize = openingRangeHigh - openingRangeLow;
      tp = isLong ? entryPrice + orSize * InpTPRangeMultiplier : entryPrice - orSize * InpTPRangeMultiplier;
   }
   else if (InpTPMethod == TP_FIBONACCI_EXTENSIONS)
   {
      double range = sessionHigh - sessionLow;
      if (isLong)
      {
         tp = sessionHigh + range * (InpTPFibExtensionLevel - 1); // Fib Extensions are usually from 100% onwards
      }
      else
      {
         tp = sessionLow - range * (InpTPFibExtensionLevel - 1);
      }
   }
   return NormalizeDouble(tp, _Digits);
}

bool CheckMacdConfirmation(bool is_bullish)
{
   // Ensure we have enough data for comparison
   if (ArraySize(macd_buffer) < 1 || ArraySize(signal_buffer) < 1 || ArraySize(hist_buffer) < 2) return false; // Need current and previous hist for curling

   if (is_bullish)
   {
      // MACD line > signal line AND MACD histogram is increasing (hist[0] > hist[1])
      return (macd_buffer[0] > signal_buffer[0] && hist_buffer[0] > hist_buffer[1]);
   }
   else // is_bearish
   {
      // MACD line < signal line AND MACD histogram is decreasing (hist[0] < hist[1])
      return (macd_buffer[0] < signal_buffer[0] && hist_buffer[0] < hist_buffer[1]);
   }
}

void CheckEntryConditions()
{
   if (!isOpeningRangeSet || (!bullishBreakout && !bearishBreakout)) return; // No ORB or no breakout yet
   if (posInfo.IsOpened()) return; // Already in a trade
   
   MqlRates rates[];
   if(CopyRates(_Symbol, _Period, 0, 2, rates) != 2) return;
   double current_high = rates[1].high;
   double current_low = rates[1].low;

   if (bullishBreakout && CheckMacdConfirmation(true))
   {
      // Check if price retraces into the 50-61.8% Fib zone for a long entry
      // The low of the current bar must be below or equal to fib50, and high must be above or equal to fib618
      if (current_low <= fib50 && current_high >= fib618)
      {
         double entryPrice = fib618; // Enter at 61.8% Fib level
         double stopLossPrice = CalculateStopLoss(true, entryPrice);
         double takeProfitPrice = CalculateTakeProfit(true, entryPrice, stopLossPrice);
         
         if (PlaceLimitOrder(ORDER_TYPE_BUY_LIMIT, entryPrice, stopLossPrice, takeProfitPrice))
         {
            Print("Placed BUY LIMIT order at ", entryPrice);
         }
      }
   }
   else if (bearishBreakout && CheckMacdConfirmation(false))
   {
      // Check if price retraces into the 50-61.8% Fib zone for a short entry
      // The high of the current bar must be above or equal to fib50, and low must be below or equal to fib618
      if (current_high >= fib50 && current_low <= fib618)
      {
         double entryPrice = fib618; // Enter at 61.8% Fib level
         double stopLossPrice = CalculateStopLoss(false, entryPrice);
         double takeProfitPrice = CalculateTakeProfit(false, entryPrice, stopLossPrice);

         if (PlaceLimitOrder(ORDER_TYPE_SELL_LIMIT, entryPrice, stopLossPrice, takeProfitPrice))
         {
            Print("Placed SELL LIMIT order at ", entryPrice);
         }
      }
   }
}

bool PlaceLimitOrder(ENUM_ORDER_TYPE type, double price, double stop_loss, double take_profit)
{
   // Normalize prices to account for symbol's digits
   price = NormalizeDouble(price, _Digits);
   stop_loss = NormalizeDouble(stop_loss, _Digits);
   take_profit = NormalizeDouble(take_profit, _Digits);
   
   // Check if a pending order already exists for this strategy
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      ulong ticket = orderInfo.GetTicket(i);
      if(orderInfo.Select(ticket) && orderInfo.GetMagic() == InpMagicNumber && orderInfo.GetSymbol() == _Symbol)
      {
         if(orderInfo.GetOrderType() == type && orderInfo.GetPriceOpen() == price)
         {
            Print("Pending order already exists at ", price);
            return false; // Avoid placing duplicate orders
         }
      }
   }

   if (type == ORDER_TYPE_BUY_LIMIT)
   {
      return trade.BuyLimit(InpLots, price, stop_loss, take_profit, "ORB+Fib+MACD Buy Limit");
   }
   else if (type == ORDER_TYPE_SELL_LIMIT)
   {
      return trade.SellLimit(InpLots, price, stop_loss, take_profit, "ORB+Fib+MACD Sell Limit");
   }
   return false;
}

void ManageTrades()
{
   if (!posInfo.SelectByMagic(_Symbol, InpMagicNumber)) return; // No open position for this EA

   // Get current position details
   long position_ticket = posInfo.GetTicket();
   ENUM_POSITION_TYPE position_type = posInfo.GetPositionType();
   double current_sl = posInfo.GetStopLoss();
   double current_tp = posInfo.GetTakeProfit();

   double new_sl = 0.0;
   double new_tp = 0.0;

   if (position_type == POSITION_TYPE_BUY)
   {
      new_sl = CalculateStopLoss(true, posInfo.GetPriceOpen());
      new_tp = CalculateTakeProfit(true, posInfo.GetPriceOpen(), new_sl);
   }
   else if (position_type == POSITION_TYPE_SELL)
   {
      new_sl = CalculateStopLoss(false, posInfo.GetPriceOpen());
      new_tp = CalculateTakeProfit(false, posInfo.GetPriceOpen(), new_sl);
   }
   
   // Only modify if SL/TP are different or not set
   if (current_sl != new_sl || current_tp != new_tp)
   {
      trade.PositionModify(position_ticket, new_sl, new_tp);
      Print("Modified position ", position_ticket, ": SL=", new_sl, ", TP=", new_tp);
   }
}

