//+------------------------------------------------------------------+
//| CRT-Trader.mq5                                                 |
//+------------------------------------------------------------------+
#property strict
#include "crt_core3qwen.mqh"
#include <Trade\Trade.mqh>

//--- INPUT PARAMETERS ------------------------------------------------
input ENUM_TIMEFRAMES H4_Timeframe = PERIOD_H4;
input ENUM_TIMEFRAMES M15_Timeframe = PERIOD_M15;
input int             FVG_CheckRange = 25;
input double          Lots = 0.1;
input double          RiskR = 2.0;
input string          TelegramToken = "";
input string          TelegramChatID = "";

//--- GLOBALS -------------------------------------------------------
CRT_State st;
CTrade trade;
datetime last_day = 0;  // Fixed: Changed from int to datetime
string CurrentSymbol;    // Current chart symbol

//+------------------------------------------------------------------+
int OnInit()
{
   CurrentSymbol = Symbol();  // Get current chart symbol
   st.symbol = CurrentSymbol;
   EventSetTimer(60);
   Print("CRT-Trader initialized for: ", CurrentSymbol);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason) 
{ 
   EventKillTimer();
   ClearAllCRTVisualizations();
}

//+------------------------------------------------------------------+
void OnTimer()
{
   datetime now = TimeCurrent();
   MqlDateTime t; TimeToStruct(now, t);

   if(last_day != t.day_of_year)
   {
      last_day = t.day_of_year;
      ResetState(st, CurrentSymbol);
   }

   // Time-based filtering
   if(Use_TimeBasedFiltering)
   {
      int current_hour = t.hour;
      if(current_hour < TradingStartHour || current_hour > TradingEndHour)
      {
         string time_status = "Trading DISABLED | Current Hour: " + IntegerToString(current_hour) + 
                             " | Trading Hours: " + IntegerToString(TradingStartHour) + "-" + IntegerToString(TradingEndHour);
         Comment(time_status);
         return;
      }
      else
      {
         string time_status = "Trading ENABLED | Current Hour: " + IntegerToString(current_hour) + 
                             " | Trading Hours: " + IntegerToString(TradingStartHour) + "-" + IntegerToString(TradingEndHour);
         Comment(time_status);
      }
   }

   datetime range_time, sweep_time;
   double range_high, range_low;
   st.bias = CRT_Bias(st.symbol, range_time, sweep_time, range_high, range_low);
   st.crt_high = range_high;
   st.crt_low = range_low;

   M15_Step(st);
   
   // Draw all visualizations
   DrawSwingPoints(st);
   DrawCRTRange(st);
   DrawFVGZones(st);
   DrawStateIndicator(st);

   if(st.bias == BULLISH && st.bull_state == ENTRY)
   {
      double price = SymbolInfoDouble(CurrentSymbol, SYMBOL_BID);
      double sl, tp;
      
      // Use precise sweep level for SL
      if(st.sweep_level != 0.0 && st.sweep_level < st.crt_low)
         sl = st.sweep_level;
      else
         sl = st.crt_low;
      
      if(Use_ATR_SL)
      {
         double atr = iATR(CurrentSymbol, PERIOD_CURRENT, ATRPeriod);
         double atr_buffer[];
         ArraySetAsSeries(atr_buffer, true);
         if(CopyBuffer(atr, 0, 1, 1, atr_buffer) > 0)
         {
            sl = price - atr_buffer[0] * ATRMultiplier;
            tp = price + atr_buffer[0] * ATRMultiplier * RiskR;
         }
      }
      else
      {
         tp = price + (price - sl) * RiskR;
      }

      Print("Bullish Entry | Price: ", DoubleToString(price, _Digits), 
            " | SL: ", DoubleToString(sl, _Digits), 
            " | TP: ", DoubleToString(tp, _Digits));

      if(!PositionSelect(CurrentSymbol))
      {
         trade.Buy(Lots, CurrentSymbol, price, sl, tp);
         SendTradeAlert("BUY", price, sl, tp);
      }
   }
   else if(st.bias == BEARISH && st.bear_state == ENTRY)
   {
      double price = SymbolInfoDouble(CurrentSymbol, SYMBOL_ASK);
      double sl, tp;
      
      // Use precise sweep level for SL
      if(st.sweep_level != 0.0 && st.sweep_level > st.crt_high)
         sl = st.sweep_level;
      else
         sl = st.crt_high;
      
      if(Use_ATR_SL)
      {
         double atr = iATR(CurrentSymbol, PERIOD_CURRENT, ATRPeriod);
         double atr_buffer[];
         ArraySetAsSeries(atr_buffer, true);
         if(CopyBuffer(atr, 0, 1, 1, atr_buffer) > 0)
         {
            sl = price + atr_buffer[0] * ATRMultiplier;
            tp = price - atr_buffer[0] * ATRMultiplier * RiskR;
         }
      }
      else
      {
         tp = price - (sl - price) * RiskR;
      }

      Print("Bearish Entry | Price: ", DoubleToString(price, _Digits), 
            " | SL: ", DoubleToString(sl, _Digits), 
            " | TP: ", DoubleToString(tp, _Digits));

      if(!PositionSelect(CurrentSymbol))
      {
         trade.Sell(Lots, CurrentSymbol, price, sl, tp);
         SendTradeAlert("SELL", price, sl, tp);
      }
   }
}

//+------------------------------------------------------------------+
//| Send Telegram alert with emoji and trade details                   |
//+------------------------------------------------------------------+
void SendTradeAlert(string direction, double price, double sl, double tp)
{
   string entry_emoji = (direction == "BUY") ? "🐂" : "🐻";
   string message = entry_emoji + " CRT-TRADE: " + CurrentSymbol + " " + direction + " | " +
                   "Bias: " + EnumToString(st.bias) + " | " +
                   "Sweep: " + DoubleToString(st.sweep_level, _Digits) + " | " +
                   "FVG: " + DoubleToString(st.fvg_low, _Digits) + "-" + DoubleToString(st.fvg_high, _Digits) + " | " +
                   "SL: " + DoubleToString(sl, _Digits) + " | " +
                   "TP: " + DoubleToString(tp, _Digits);
   Telegram_Send(TelegramToken, TelegramChatID, message);
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Send Telegram message function                                    |
//+------------------------------------------------------------------+
void Telegram_Send(string token, string chat_id, string message)
{
   if(token == "" || chat_id == "") return;
   
   string url = "https://api.telegram.org/bot" + token + "/sendMessage";
   string data = "chat_id=" + chat_id + "&text=" + message;
   
   // In a real implementation, you would use WebRequest here
   // For now, just print the message
   Print("TELEGRAM: ", message);
}