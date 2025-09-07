//+------------------------------------------------------------------+
//|                                       ETH_Momentum_Breakout.mq5 |
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
int atr_handle;
int rsi_handle;
int stoch_handle;

// Global variables
datetime last_bar_time = 0;
datetime last_trade_time = 0;
const string SYMBOL = "ETHUSDm";
const ENUM_TIMEFRAMES TIMEFRAME = PERIOD_M15;

// Strategy parameters
input double FIXED_LOT_SIZE = 0.20;          // Fixed lot size
input int BREAKOUT_PERIOD = 20;              // Breakout period
input int ATR_PERIOD = 14;                   // ATR period for volatility measurement
input double SL_ATR_MULTIPLIER = 2.0;        // Stop loss in ATR
input double TP_ATR_MULTIPLIER = 3.0;        // Take profit in ATR
input int RSI_PERIOD = 14;                   // RSI period
input int RSI_OVERBOUGHT = 75;               // RSI overbought level
input int RSI_OVERSOLD = 25;                 // RSI oversold level
input int STOCH_K_PERIOD = 5;                // Stochastic K period
input int STOCH_D_PERIOD = 3;                // Stochastic D period
input int STOCH_SLOWING = 3;                 // Stochastic slowing
input int TRADES_PER_DAY = 2;                // Maximum trades per day
input int MIN_BARS_BETWEEN_TRADES = 10;      // Minimum bars between trades
input bool TRADE_ASIA_SESSION = false;       // Trade during Asian session (00:00-08:00)
input bool TRADE_EURO_SESSION = true;        // Trade during European session (08:00-16:00)
input bool TRADE_US_SESSION = true;          // Trade during US session (16:00-24:00)

//+------------------------------------------------------------------+
//| Initialization Function                                          |
//+------------------------------------------------------------------+
void OnInit()
{
   // Create indicator handles
   atr_handle = iATR(SYMBOL, TIMEFRAME, ATR_PERIOD);
   rsi_handle = iRSI(SYMBOL, TIMEFRAME, RSI_PERIOD, PRICE_CLOSE);
   stoch_handle = iStochastic(SYMBOL, TIMEFRAME, STOCH_K_PERIOD, STOCH_D_PERIOD, STOCH_SLOWING, MODE_SMA, STO_LOWHIGH);
   
   // Check for valid handles
   if(atr_handle == INVALID_HANDLE || rsi_handle == INVALID_HANDLE || stoch_handle == INVALID_HANDLE)
   {
      Print("Failed to create indicator handles. EA will terminate.");
      ExpertRemove();
      return;
   }

   trade.SetDeviationInPoints(10);
   Print("ETH Momentum Breakout EA initialized on ", SYMBOL);
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
   
   // Check trading session
   if(!IsAllowedTradingSession())
      return;
      
   // Check maximum trades per day
   if(CountTradesToday() >= TRADES_PER_DAY)
      return;
      
   // Check minimum bars between trades
   if(current_bar_time - last_trade_time < MIN_BARS_BETWEEN_TRADES * PeriodSeconds(TIMEFRAME))
      return;

   // Manage existing positions
   if(PositionSelect(SYMBOL))
   {
      ManagePosition();
      return; // Skip entry logic if position exists
   }
   
   // Get indicator values
   double atr[], rsi[], stoch_main[], stoch_signal[];
   
   // Set arrays as series
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(stoch_main, true);
   ArraySetAsSeries(stoch_signal, true);
   
   // Copy indicator data
   if(CopyBuffer(atr_handle, 0, 0, 3, atr) <= 0 ||
      CopyBuffer(rsi_handle, 0, 0, 3, rsi) <= 0 ||
      CopyBuffer(stoch_handle, 0, 0, 3, stoch_main) <= 0 ||
      CopyBuffer(stoch_handle, 1, 0, 3, stoch_signal) <= 0)
   {
      Print("Failed to copy indicator data");
      return;
   }
   
   // Get price data
   double close[], high[], low[], open[];
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(open, true);
   
   if(CopyClose(SYMBOL, TIMEFRAME, 0, BREAKOUT_PERIOD + 2, close) <= 0 ||
      CopyHigh(SYMBOL, TIMEFRAME, 0, BREAKOUT_PERIOD + 2, high) <= 0 ||
      CopyLow(SYMBOL, TIMEFRAME, 0, BREAKOUT_PERIOD + 2, low) <= 0 ||
      CopyOpen(SYMBOL, TIMEFRAME, 0, BREAKOUT_PERIOD + 2, open) <= 0)
   {
      Print("Failed to copy price data");
      return;
   }
   
   // Calculate breakout levels
   double upper_level = FindHighestHigh(high, BREAKOUT_PERIOD, 1);
   double lower_level = FindLowestLow(low, BREAKOUT_PERIOD, 1);
   
   // Calculate current range as percentage of price
   double current_range = (upper_level - lower_level) / close[1] * 100;
   
   // Current price and previous candle data
   double current_price = close[1];
   double current_high = high[1];
   double current_low = low[1];
   double current_open = open[1];
   
   // Strong momentum candle check
   bool strong_bullish = (close[1] > open[1]) && ((close[1] - open[1]) > 0.7 * (high[1] - low[1]));
   bool strong_bearish = (close[1] < open[1]) && ((open[1] - close[1]) > 0.7 * (high[1] - low[1]));
   
   // Volatility check - make sure ATR is significant
   bool sufficient_volatility = atr[1] > atr[2] * 1.2;
   
   // BUY SIGNAL - Bullish breakout with momentum
   if(current_high > upper_level && strong_bullish && sufficient_volatility)
   {
      // RSI filter - not overbought
      if(rsi[1] < RSI_OVERBOUGHT)
      {
         // Stochastic filter - K line above D line and rising
         if(stoch_main[1] > stoch_signal[1] && stoch_main[1] > stoch_main[2])
         {
            ExecuteBuyOrder(atr[1]);
            last_trade_time = current_bar_time;
         }
      }
   }
   
   // SELL SIGNAL - Bearish breakout with momentum
   else if(current_low < lower_level && strong_bearish && sufficient_volatility)
   {
      // RSI filter - not oversold
      if(rsi[1] > RSI_OVERSOLD)
      {
         // Stochastic filter - K line below D line and falling
         if(stoch_main[1] < stoch_signal[1] && stoch_main[1] < stoch_main[2])
         {
            ExecuteSellOrder(atr[1]);
            last_trade_time = current_bar_time;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Execute Buy Order                                                |
//+------------------------------------------------------------------+
void ExecuteBuyOrder(double atr_value)
{
   double entry_price = SymbolInfoDouble(SYMBOL, SYMBOL_ASK);
   int digits = (int)SymbolInfoInteger(SYMBOL, SYMBOL_DIGITS);
   
   double stop_loss = NormalizeDouble(entry_price - atr_value * SL_ATR_MULTIPLIER, digits);
   double take_profit = NormalizeDouble(entry_price + atr_value * TP_ATR_MULTIPLIER, digits);
   
   // Execute buy order
   if(trade.Buy(FIXED_LOT_SIZE, SYMBOL, 0.0, stop_loss, take_profit))
   {
      Print("Buy order executed at ", entry_price, " with SL: ", stop_loss, " TP: ", take_profit);
   }
}

//+------------------------------------------------------------------+
//| Execute Sell Order                                               |
//+------------------------------------------------------------------+
void ExecuteSellOrder(double atr_value)
{
   double entry_price = SymbolInfoDouble(SYMBOL, SYMBOL_BID);
   int digits = (int)SymbolInfoInteger(SYMBOL, SYMBOL_DIGITS);
   
   double stop_loss = NormalizeDouble(entry_price + atr_value * SL_ATR_MULTIPLIER, digits);
   double take_profit = NormalizeDouble(entry_price - atr_value * TP_ATR_MULTIPLIER, digits);
   
   // Execute sell order
   if(trade.Sell(FIXED_LOT_SIZE, SYMBOL, 0.0, stop_loss, take_profit))
   {
      Print("Sell order executed at ", entry_price, " with SL: ", stop_loss, " TP: ", take_profit);
   }
}

//+------------------------------------------------------------------+
//| Manage existing position                                         |
//+------------------------------------------------------------------+
void ManagePosition()
{
   // We're using fixed SL/TP, no additional management required
   // Position will be closed at SL or TP
}

//+------------------------------------------------------------------+
//| Find highest high in a specified period                          |
//+------------------------------------------------------------------+
double FindHighestHigh(double &high[], int period, int start_pos)
{
   double highest = high[start_pos];
   
   for(int i = start_pos + 1; i <= start_pos + period; i++)
   {
      if(i < ArraySize(high) && high[i] > highest)
         highest = high[i];
   }
   
   return highest;
}

//+------------------------------------------------------------------+
//| Find lowest low in a specified period                            |
//+------------------------------------------------------------------+
double FindLowestLow(double &low[], int period, int start_pos)
{
   double lowest = low[start_pos];
   
   for(int i = start_pos + 1; i <= start_pos + period; i++)
   {
      if(i < ArraySize(low) && low[i] < lowest)
         lowest = low[i];
   }
   
   return lowest;
}

//+------------------------------------------------------------------+
//| Check if current time is within allowed trading sessions         |
//+------------------------------------------------------------------+
bool IsAllowedTradingSession()
{
   datetime server_time = TimeCurrent();
   MqlDateTime time_struct;
   TimeToStruct(server_time, time_struct);
   
   int current_hour = time_struct.hour;
   
   // Asia session: 00:00 - 08:00
   if(current_hour >= 0 && current_hour < 8)
      return TRADE_ASIA_SESSION;
      
   // European session: 08:00 - 16:00
   if(current_hour >= 8 && current_hour < 16)
      return TRADE_EURO_SESSION;
      
   // US session: 16:00 - 24:00
   if(current_hour >= 16 && current_hour < 24)
      return TRADE_US_SESSION;
      
   return false;
}

//+------------------------------------------------------------------+
//| Count trades opened today                                        |
//+------------------------------------------------------------------+
int CountTradesToday()
{
   datetime start_of_day = GetStartOfDay();
   int count = 0;
   
   // Get history trades
   ulong ticket = 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      if((ticket = HistoryDealGetTicket(i)) > 0)
      {
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) == SYMBOL && 
            HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_IN &&
            HistoryDealGetInteger(ticket, DEAL_TIME) >= start_of_day)
         {
            count++;
         }
      }
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Get start of current day in server time                          |
//+------------------------------------------------------------------+
datetime GetStartOfDay()
{
   datetime server_time = TimeCurrent();
   MqlDateTime time_struct;
   
   TimeToStruct(server_time, time_struct);
   time_struct.hour = 0;
   time_struct.min = 0;
   time_struct.sec = 0;
   
   return StructToTime(time_struct);
}

//+------------------------------------------------------------------+
//| Deinitialization Function                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   if(atr_handle != INVALID_HANDLE)
      IndicatorRelease(atr_handle);
   if(rsi_handle != INVALID_HANDLE)
      IndicatorRelease(rsi_handle);
   if(stoch_handle != INVALID_HANDLE)
      IndicatorRelease(stoch_handle);
      
   Print("ETH Momentum Breakout EA deinitialized. Reason: ", reason);
}