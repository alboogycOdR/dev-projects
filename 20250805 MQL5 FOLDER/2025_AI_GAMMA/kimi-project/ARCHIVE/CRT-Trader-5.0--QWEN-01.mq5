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
#include "CRT_Core2.mqh"
 /*Changes :

Configurable timeframes
Entry confirmation
ATR-based SL/TP
Repainting prevention*/
  //+------------------------------------------------------------------+
//| CRT-Trader.mq5                                                 |
//+------------------------------------------------------------------+
#property strict
 

//--- INPUT PARAMETERS -----------------------------------------------
input ENUM_TIMEFRAMES H4_Timeframe = PERIOD_H4;
input ENUM_TIMEFRAMES M15_Timeframe = PERIOD_M15;
input int             FVG_CheckRange = 25;
input bool            Use_EntryConfirmation = true;
input double Lots = 0.1;
input double RiskR = 2.0;
input int    ATRPeriod = 14;
input double ATRMultiplier = 1.5;
  string TelegramToken = "7388905164:AAF9DeExI0Jb5qAzDV16mlAhYOyMwo4EqbA";
  string TelegramChatID = "880001908";

//--- GLOBALS ------------------------------------------------------
CRT_State st;
CTrade trade;
int atr_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
int OnInit()
{
   st.symbol = _Symbol;
   atr_handle = iATR(st.symbol, M15_Timeframe, ATRPeriod);
   if(atr_handle == INVALID_HANDLE)
   {
      Print("Failed to create ATR indicator handle. Error ", GetLastError());
      return INIT_FAILED;
   }
   EventSetTimer(60);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason) 
{ 
   IndicatorRelease(atr_handle);
   EventKillTimer(); 
}

//+------------------------------------------------------------------+
void OnTimer()
{
   datetime now = TimeCurrent();
   MqlDateTime t; TimeToStruct(now, t);
   static datetime last_day = 0;

   if(last_day != t.day_of_year)
   {
      last_day = t.day_of_year;
      ResetState(st, st.symbol);
   }

   datetime range_time, sweep_time;
   st.bias = CRT_Bias(st.symbol, range_time, sweep_time, st.crt_high, st.crt_low);

   if(st.bias != NEUTRAL)
   {
      M15_Step(st, H4_Timeframe, M15_Timeframe, FVG_CheckRange, Use_EntryConfirmation);

      if((st.bias == BULLISH && st.bull_state == ENTRY) || 
         (st.bias == BEARISH && st.bear_state == ENTRY))
      {
         double price = (st.bias == BULLISH) ? SymbolInfoDouble(st.symbol, SYMBOL_ASK) : SymbolInfoDouble(st.symbol, SYMBOL_BID);
         
         double atr_buffer[1];
         if(CopyBuffer(atr_handle, 0, 1, 1, atr_buffer) <= 0)
         {
            Print("Could not copy ATR buffer, error: ", GetLastError());
            return;
         }
         double atr = atr_buffer[0];

         double sl = (st.bias == BULLISH) ? price - atr * ATRMultiplier : price + atr * ATRMultiplier;
         double tp = (st.bias == BULLISH) ? price + atr * ATRMultiplier * RiskR : price - atr * ATRMultiplier * RiskR;

         trade.SetExpertMagicNumber(564738);
         if(st.bias == BULLISH)
            trade.Buy(Lots, st.symbol, price, sl, tp);
         else
            trade.Sell(Lots, st.symbol, price, sl, tp);

         string entry_emoji = (st.bias == BULLISH) ? "🐂" : "🐻";
         string message = entry_emoji + " TRADE OPEN: " + st.symbol + " " + 
                         EnumToString(st.bias) + " | FVG: " + 
                         DoubleToString(st.fvg_low, 5) + "-" + DoubleToString(st.fvg_high, 5) +
                         " | SL=" + DoubleToString(sl, 5) + " | TP=" + DoubleToString(tp, 5);
         Telegram_Send(TelegramToken, TelegramChatID, message);
      }
   }
}
//+------------------------------------------------------------------+