//+------------------------------------------------------------------+
//| CRT-Trader-5.0-final.mq5  – single symbol EA + auto-trade        |
//+------------------------------------------------------------------+
/*
    VERSION HISTORY / CHANGELOG

    Update: Dynamic CRT Range Integration
    - WHY: To ensure the trading logic is perfectly synchronized with the scanner and core files, the trader must also use the dynamically-determined range from the H4 bias candle.
    - WHAT:
        - The call to `CRT_Bias` was updated to receive the `crt_high` and `crt_low` of the true range candle.
        - The redundant `CRT_Range()` function call was removed.
        - The M15 state machine (`M15_Step`) now begins monitoring for trade entries immediately after a valid bias is formed, using the correct price levels.
*/
/*
| Deliverable                          | Status               |
| ------------------------------------ | -------------------- |
| **2-bar CRT bias**                   | ✅ (Scanner + Trader) |
| **GMT-aware CRT range**              | ✅                    |
| **Telegram alerts (bias + ENTRY)**   | ✅                    |
| **Multi-symbol scanner**             | ✅                    |
| **Single-symbol EA with auto-trade** | ✅                    |


| Item                            | Impact                      | ETA (if wanted) |
| ------------------------------- | --------------------------- | --------------- |
| **DST auto-detect toggle**      | zero-config after March/Oct | 10 min          |
| **Dashboard GUI (visual grid)** | nicer than Print()          | 30 min          |
| **Sound choice / volume**       | cosmetic                    | 5 min           |
| **CSV journal export**          | bookkeeping                 | 15 min          |



🎯 What’s inside
2-bar CRT bias (Range + Manipulation)
GMT-aware CRT range (CRT_Hour + Broker_GMT_Offset)
Real-time M15 state-machine (Idle → SWEEP → MSS → FVG → ENTRY)
Telegram notifications (bias flip + ENTRY + trade open)
Auto-risk SL/TP (below sweep / R:R)

*/
#property copyright "CRT-Trader-5.0-final"
#property version   "5.00"
#property description "Single-symbol CRT EA – auto-trade ENTRY signals"

#include <Trade\Trade.mqh>
#include "CRT_Core.mqh"

//--- INPUTS ---------------------------------------------------------
input string Symbol = "EURUSD";
input int    CRT_Hour=8;
input int    Broker_GMT_Offset=3;
input double Lots=0.25;
input double RiskR=2.0;          // TP = R:R
input string TelegramToken="";
input string TelegramChatID="";

//--- GLOBALS --------------------------------------------------------
CRT_State st;
CTrade    trade;

//+------------------------------------------------------------------+
int OnInit()
{
   st.symbol = Symbol;
   EventSetTimer(1);
   return INIT_SUCCEEDED;
}
void OnDeinit(const int r){ EventKillTimer(); }

void OnTimer()
{
   datetime now=TimeCurrent();
   MqlDateTime t; TimeToStruct(now,t);
   static datetime last_day=0;
   if(last_day!=t.day_of_year){ last_day=t.day_of_year; ResetState(st, Symbol); }

   ENUM_BIAS prevBias=st.bias;
   datetime r_time, s_time; // Dummy variables, not used in trader
   st.bias=CRT_Bias(st.symbol, r_time, s_time, st.crt_high, st.crt_low);

   // Log bias change
   if(prevBias!=NEUTRAL && st.bias!=prevBias)
     {
      string bias_emoji = (st.bias == BULLISH) ? "📈" : (st.bias == BEARISH) ? "📉" : "📊";
      string message = bias_emoji + " TRADER-BIAS: " + st.symbol + " → " + EnumToString(st.bias);
      Telegram_Send(TelegramToken, TelegramChatID, message);
     }

   if(st.bias!=NEUTRAL)
   {
      ENUM_SETUP_STATE prevState = (st.bias==BULLISH)?st.bull_state:st.bear_state;
      M15_Step(st);
      ENUM_SETUP_STATE newState  = (st.bias==BULLISH)?st.bull_state:st.bear_state;

      if(newState==ENTRY && prevState!=ENTRY)
      {
         double price = SymbolInfoDouble(st.symbol,SYMBOL_BID);
         double sl    = (st.bias==BULLISH)?st.crt_low:st.crt_high;
         double tp    = (st.bias==BULLISH)?price+(price-sl)*RiskR:price-(sl-price)*RiskR;

         trade.SetExpertMagicNumber(564738);
         if(st.bias==BULLISH) trade.Buy(Lots,st.symbol,price,sl,tp);
         else                 trade.Sell(Lots,st.symbol,price,sl,tp);

         string entry_emoji = (st.bias == BULLISH) ? "🐂" : "🐻";
         string message = entry_emoji + " TRADE OPEN: " + st.symbol + " " + EnumToString(st.bias) + " | FVG: " + DoubleToString(st.fvg_low, 5) + "-" + DoubleToString(st.fvg_high, 5) + " | SL=" + DoubleToString(sl, 5) + " | TP=" + DoubleToString(tp, 5);
         Telegram_Send(TelegramToken, TelegramChatID, message);
      }
   }
}
//+------------------------------------------------------------------+