#property copyright "Copyright 2025, VWAP Strategy"
#property version   "1.12"

#include <Trade\Trade.mqh>

CTrade trade;

// Indicator handles
int ema9_handle;
int ema50_handle;
int vwap_handle;  // Custom VWAP indicator

// Global variables
datetime last_bar_time = 0;
const string SYMBOL = "ETHUSDm";
const ENUM_TIMEFRAMES TIMEFRAME = PERIOD_M15;

// Strategy parameters
input double RISK_PERCENTAGE = 1.0;  // Risk per trade
input int LOOKBACK_PERIODS = 3;      // Number of periods to check

//+------------------------------------------------------------------+
//| Initialization Function                                          |
//+------------------------------------------------------------------+
int OnInit()
{
   // Create indicator handles
   ema9_handle = iMA(SYMBOL, TIMEFRAME, 9, 0, MODE_EMA, PRICE_CLOSE);
   ema50_handle = iMA(SYMBOL, TIMEFRAME, 50, 0, MODE_EMA, PRICE_CLOSE);
   vwap_handle = iCustom(SYMBOL, TIMEFRAME, "VWAP_UTC_Final");
   
   // Validate handles
   if(ema9_handle == INVALID_HANDLE || 
      ema50_handle == INVALID_HANDLE || 
      vwap_handle == INVALID_HANDLE)
   {
      Print("Failed to create indicator handles. EA will terminate.");
      return(INIT_FAILED);
   }
   
   trade.SetDeviationInPoints(20); // Slippage tolerance
   Print("EA initialized successfully on ", SYMBOL, " (M15)");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Calculate Position Size                                          |
//+------------------------------------------------------------------+
double CalculatePositionSize(double stop_loss_price)
{
   double account_balance = 100.0;  // Fixed for backtesting
   double current_price = iClose(SYMBOL, TIMEFRAME, 1);
   double risk_amount = account_balance * (RISK_PERCENTAGE / 100);
   double point = SymbolInfoDouble(SYMBOL, SYMBOL_POINT);
   
   double risk_per_share = MathAbs(current_price - stop_loss_price);
   double position_size = NormalizeDouble(risk_amount / risk_per_share, 2);
   
   return MathMax(position_size, 0.01);  // Minimum lot size
}

//+------------------------------------------------------------------+
//| Check Buy Conditions                                             |
//+------------------------------------------------------------------+
bool CheckBuyConditions(double &ema9[], double &ema50[], double &vwap[])
{
   // EMA9 above EMA50 (trend confirmation)
   bool trend_condition = ema9[1] > ema50[1];
   
   // EMA9 crossing above VWAP
   bool vwap_cross = ema9[2] <= vwap[2] && ema9[1] > vwap[1];
   
   return trend_condition && vwap_cross;
}

//+------------------------------------------------------------------+
//| Check Sell Conditions                                            |
//+------------------------------------------------------------------+
bool CheckSellConditions(double &ema9[], double &ema50[], double &vwap[])
{
   // EMA9 below EMA50 (trend confirmation)
   bool trend_condition = ema9[1] < ema50[1];
   
   // EMA9 crossing below VWAP
   bool vwap_cross = ema9[2] >= vwap[2] && ema9[1] < vwap[1];
   
   return trend_condition && vwap_cross;
}

//+------------------------------------------------------------------+
//| Main Trading Logic                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new bar
   datetime current_bar_time = iTime(SYMBOL, TIMEFRAME, 0);
   if(current_bar_time <= last_bar_time)
      return;
   last_bar_time = current_bar_time;
   
   // Prepare buffers
   double ema9[], ema50[], vwap[];
   ArraySetAsSeries(ema9, true);
   ArraySetAsSeries(ema50, true);
   ArraySetAsSeries(vwap, true);
   
   // Copy indicator data
   if(CopyBuffer(ema9_handle, 0, 0, 3, ema9) < 3 ||
      CopyBuffer(ema50_handle, 0, 0, 3, ema50) < 3 ||
      CopyBuffer(vwap_handle, 0, 0, 3, vwap) < 3)
   {
      Print("Failed to copy indicator data");
      return;
   }
   
   // Manage existing position
   if(PositionSelect(SYMBOL))
   {
      ManagePosition(ema9, ema50, vwap);
      return;
   }
   
   // Entry Conditions
   if(CheckBuyConditions(ema9, ema50, vwap))
   {
      // Use VWAP as dynamic stop loss
      double stop_loss = vwap[1];
      double position_size = CalculatePositionSize(stop_loss);
      
      if(trade.Buy(position_size, SYMBOL, 0.0, stop_loss, 0.0))
      {
         Print("Buy trade opened at VWAP");
      }
   }
   else if(CheckSellConditions(ema9, ema50, vwap))
   {
      // Use VWAP as dynamic stop loss
      double stop_loss = vwap[1];
      double position_size = CalculatePositionSize(stop_loss);
      
      if(trade.Sell(position_size, SYMBOL, 0.0, stop_loss, 0.0))
      {
         Print("Sell trade opened at VWAP");
      }
   }
}

//+------------------------------------------------------------------+
//| Position Management                                              |
//+------------------------------------------------------------------+
void ManagePosition(double &ema9[], double &ema50[], double &vwap[])
{
   // Exit conditions based on trend and VWAP
   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
   {
      // Close if EMA9 drops below EMA50 or below VWAP
      if(ema9[1] < ema50[1] || ema9[1] < vwap[1])
      {
         trade.PositionClose(SYMBOL);
         Print("Buy position closed - trend reversal");
      }
   }
   else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
   {
      // Close if EMA9 rises above EMA50 or above VWAP
      if(ema9[1] > ema50[1] || ema9[1] > vwap[1])
      {
         trade.PositionClose(SYMBOL);
         Print("Sell position closed - trend reversal");
      }
   }
}

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   IndicatorRelease(ema9_handle);
   IndicatorRelease(ema50_handle);
   IndicatorRelease(vwap_handle);
   
   Print("EA deinitialized. Reason: ", reason);
}