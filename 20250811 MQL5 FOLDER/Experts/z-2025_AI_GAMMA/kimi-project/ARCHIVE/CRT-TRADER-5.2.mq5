//+------------------------------------------------------------------+
//| CRT-Trader.mq5                                                 |
//+------------------------------------------------------------------+
#property strict
#include "CRT_Core2.mqh"
#include <Trade\Trade.mqh>

//--- INPUT PARAMETERS ------------------------------------------------
input string Symbol = "EURUSD";
input double Lots = 0.1;
input double RiskR = 2.0;
input bool Use_FVG_SizeValidation = true;
input double MinFVGSizePips = 10.0;
input bool Use_TimeBasedFiltering = true;
input int  TradingStartHour = 8;
input int  TradingEndHour = 20;
input bool Use_ATR_SL = true;
input int  ATRPeriod = 14;
input double ATRMultiplier = 1.5;
input bool Use_EntryConfirmation = true;
input string TelegramToken = "";
input string TelegramChatID = "";

//--- GLOBALS -------------------------------------------------------
CRT_State st;
CTrade trade;

//+------------------------------------------------------------------+
int OnInit()
{
   st.symbol = Symbol;
   EventSetTimer(60);
   Print("CRT-Trader initialized for: ", Symbol);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnTimer()
{
   datetime now = TimeCurrent();
   MqlDateTime t;
   TimeToStruct(now, t);

   if(last_day != t.day_of_year)
   {
      last_day = t.day_of_year;
      ResetState(st, Symbol);
   }

   datetime range_time, sweep_time;
   double range_high, range_low;
   st.bias = CRT_Bias(st.symbol, range_time, sweep_time, range_high, range_low);
   st.crt_high = range_high;
   st.crt_low = range_low;

   // Time-based filtering
   if(Use_TimeBasedFiltering)
   {
      int current_hour = t.hour;
      if(current_hour < TradingStartHour || current_hour > TradingEndHour)
      {
         Print("Trading disabled outside time filter | Current Hour: ", current_hour);
         return;
      }
   }

   M15_Step(st);

   if(st.bias == BULLISH && st.bull_state == ENTRY)
   {
      if(Use_ATR_SL)
      {
         double atr = iATR(NULL, 0, ATRPeriod, 1);
         st.crt_low = SymbolInfoDouble(st.symbol, SYMBOL_BID) - atr * ATRMultiplier;
         st.crt_high = SymbolInfoDouble(st.symbol, SYMBOL_BID) + atr * ATRMultiplier;
      }

      double price = SymbolInfoDouble(Symbol, SYMBOL_BID);
      double sl = st.crt_low;
      double tp = price + (price - sl) * RiskR;

      Print("Bullish Entry | Price: ", DoubleToString(price, _Digits), 
            " | SL: ", DoubleToString(sl, _Digits), 
            " | TP: ", DoubleToString(tp, _Digits));

      if(!PositionSelect(Symbol))
      {
         trade.Buy(Lots, Symbol, price, sl, tp);
         SendTradeAlert("BUY", price, sl, tp);
      }
   }
   else if(st.bias == BEARISH && st.bear_state == ENTRY)
   {
      if(Use_ATR_SL)
      {
         double atr = iATR(NULL, 0, ATRPeriod, 1);
         st.crt_high = SymbolInfoDouble(st.symbol, SYMBOL_ASK) + atr * ATRMultiplier;
         st.crt_low = SymbolInfoDouble(st.symbol, SYMBOL_ASK) - atr * ATRMultiplier;
      }

      double price = SymbolInfoDouble(Symbol, SYMBOL_ASK);
      double sl = st.crt_high;
      double tp = price - (sl - price) * RiskR;

      Print("Bearish Entry | Price: ", DoubleToString(price, _Digits), 
            " | SL: ", DoubleToString(sl, _Digits), 
            " | TP: ", DoubleToString(tp, _Digits));

      if(!PositionSelect(Symbol))
      {
         trade.Sell(Lots, Symbol, price, sl, tp);
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
   string message = entry_emoji + " CRT-TRADE: " + Symbol + " " + direction + " | " +
                   "Bias: " + EnumToString(st.bias) + " | " +
                   "FVG: " + DoubleToString(st.fvg_low, _Digits) + "-" + DoubleToString(st.fvg_high, _Digits) + " | " +
                   "CRT: " + DoubleToString(st.crt_low, _Digits) + "-" + DoubleToString(st.crt_high, _Digits) + " | " +
                   "SL: " + DoubleToString(sl, _Digits) + " | " +
                   "TP: " + DoubleToString(tp, _Digits);
   Telegram_Send(TelegramToken, TelegramChatID, message);
}
//+------------------------------------------------------------------+