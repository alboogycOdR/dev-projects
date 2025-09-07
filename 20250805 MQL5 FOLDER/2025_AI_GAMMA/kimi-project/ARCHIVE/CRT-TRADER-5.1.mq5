//+------------------------------------------------------------------+
//| CRT-Trader-5.0-final.mq5  – single symbol EA + auto-trade        |
//+------------------------------------------------------------------+
#property copyright "CRT-Trader-5.0-final"
#property version   "5.00"
#property description "Single-symbol CRT EA – auto-trade ENTRY signals"
#include <Trade\Trade.mqh>
#include "CRT_Core2.mqh"

//--- INPUTS ---------------------------------------------------------
input string Symbol = "EURUSD";            // Trading symbol
input double Lots = 0.1;                   // Trade lot size
input double RiskR = 2.0;                  // Risk:Reward ratio
input int    FVG_CheckRange = 25;          // Lookback for FVG detection
input bool   Use_EntryConfirmation = true; // Require candle confirmation
input string TelegramToken = "";           // Telegram Bot Token
input string TelegramChatID = "";          // Telegram Chat ID

//--- GLOBALS --------------------------------------------------------
CRT_State st;
CTrade    trade;
datetime  last_day = 0;
bool      debug_state = true; // Toggle for detailed state logging

//+------------------------------------------------------------------+
int OnInit()
{
   st.symbol = Symbol;
   EventSetTimer(60); // 1-minute timer
   Print("CRT-Trader initialized for: ", Symbol);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int r)
{
   EventKillTimer();
   Print("CRT-Trader deinitialized");
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
      Print("CRT-Trader: State reset for new day");
   }

   //--- Validate symbol selection ------------------------------------
   if(!SymbolSelect(Symbol, true))
   {
      Print("Error: Symbol ", Symbol, " not selectable");
      return;
   }

   //--- Detect bias ------------------------------------------------
   datetime range_time, sweep_time;
   double range_high, range_low;
   st.bias = CRT_Bias(st.symbol, range_time, sweep_time, range_high, range_low);
   st.crt_high = range_high;
   st.crt_low = range_low;

   if(debug_state)
      Print("Bias Check | Symbol: ", Symbol, " | Bias: ", EnumToString(st.bias));

   //--- Progress state machine ---------------------------------------
   ENUM_SETUP_STATE prev_bull = st.bull_state;
   ENUM_SETUP_STATE prev_bear = st.bear_state;

   M15_Step(st, PERIOD_H4, PERIOD_M15, FVG_CheckRange, Use_EntryConfirmation);

   if(debug_state)
   {
      if(st.bias == BULLISH)
         Print("Bullish State | ", EnumToString(st.bull_state));
      else if(st.bias == BEARISH)
         Print("Bearish State | ", EnumToString(st.bear_state));
   }

   //--- Trade execution logic ----------------------------------------
   if(st.bias == BULLISH && st.bull_state == ENTRY)
   {
      double price = SymbolInfoDouble(Symbol, SYMBOL_BID);
      double sl = st.crt_low;
      double tp = price + (price - sl) * RiskR;
      Print("Bullish Entry | Price: ", DoubleToString(price, _Digits), 
            " | SL: ", DoubleToString(sl, _Digits), 
            " | TP: ", DoubleToString(tp, _Digits));

      if(!PositionSelect(Symbol))
      {
         trade.Buy(Lots, Symbol, price, sl, tp);
         SendTradeAlert("BUY");
      }
   }
   else if(st.bias == BEARISH && st.bear_state == ENTRY)
   {
      double price = SymbolInfoDouble(Symbol, SYMBOL_ASK);
      double sl = st.crt_high;
      double tp = price - (sl - price) * RiskR;
      Print("Bearish Entry | Price: ", DoubleToString(price, _Digits), 
            " | SL: ", DoubleToString(sl, _Digits), 
            " | TP: ", DoubleToString(tp, _Digits));

      if(!PositionSelect(Symbol))
      {
         trade.Sell(Lots, Symbol, price, sl, tp);
         SendTradeAlert("SELL");
      }
   }
   else
   {
      if(debug_state)
         Print("No trade condition met | Bias: ", EnumToString(st.bias), 
               " | BullState: ", EnumToString(st.bull_state), 
               " | BearState: ", EnumToString(st.bear_state));
   }
}

//+------------------------------------------------------------------+
//| Send Telegram alert with emoji and trade details                   |
//+------------------------------------------------------------------+
void SendTradeAlert(string direction)
{
   string entry_emoji = (direction == "BUY") ? "🐂" : "🐻";
   string message = entry_emoji + " CRT-TRADE: " + Symbol + " " + direction + " | " +
                   "Bias: " + EnumToString(st.bias) + " | " +
                   "FVG: " + DoubleToString(st.fvg_low, _Digits) + "-" + DoubleToString(st.fvg_high, _Digits) + " | " +
                   "CRT: " + DoubleToString(st.crt_low, _Digits) + "-" + DoubleToString(st.crt_high, _Digits) + " | " +
                   "SL: " + DoubleToString(st.bias == BULLISH ? st.crt_low : st.crt_high, _Digits) + " | " +
                   "TP: " + DoubleToString(st.bias == BULLISH ? st.crt_low + (st.crt_high - st.crt_low) * RiskR : st.crt_high - (st.crt_high - st.crt_low) * RiskR, _Digits);
   Telegram_Send(TelegramToken, TelegramChatID, message);
}
//+------------------------------------------------------------------+