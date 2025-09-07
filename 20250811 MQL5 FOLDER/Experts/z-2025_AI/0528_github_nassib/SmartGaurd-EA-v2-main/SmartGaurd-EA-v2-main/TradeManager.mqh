//+------------------------------------------------------------------+
//|                       TradeManager.mqh                           |
//| SmartGuard EA v2.0 – Tiered Execution + Dynamic TP/SL + Logging |
//+------------------------------------------------------------------+
#property strict
#include "StrategyConfig.mqh"

//--- ATR handle
int atrHandleTrade = INVALID_HANDLE;


//+------------------------------------------------------------------+
//| Init / Deinit ATR indicator                                      |
//+------------------------------------------------------------------+
void InitTradeIndicators()
{
   atrHandleTrade = iATR(_Symbol, ATRTimeframe, ATRPeriod);
   if (atrHandleTrade == INVALID_HANDLE)
      Print("❌ [TradeManager] ATR handle init failed.");
   else
      Print("✅ [TradeManager] ATR handle ready.");
}

void DeinitTradeIndicators()
{
   if (atrHandleTrade != INVALID_HANDLE)
      IndicatorRelease(atrHandleTrade);
}

//+------------------------------------------------------------------+
//| Entry: Execute 4-tiered trades                                   |
//+------------------------------------------------------------------+
void ExecuteTieredTrades(int direction, double lotSize)
{
   double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   entry = NormalizeDouble(entry, _Digits);

   double atr = GetValidATR();
   double lotPerTier = NormalizeDouble(lotSize / 4.0, 2);

   PrintFormat("📌 [TradeManager] Entry: %.5f | ATR: %.5f", entry, atr);

   for (int i = 0; i < 4; i++)
   {
      double tp = 0.0, sl = 0.0;
      string tierLabel = StringFormat("T%d", i + 1);
      string comment = StringFormat("SmartGuard v2.0 [%s] %s", (direction > 0 ? "BUY" : "SELL"), tierLabel);

      double rr = 1.0;
      if (i == 0) rr = TP1_MULT;
      else if (i == 1) rr = TP2_MULT;
      else if (i == 2) rr = TP3_MULT;
      else rr = ATRMultiplierTP_T4;

      double stopSize = (atr > 0.0) ? atr * ATRMultiplierSL : 100 * _Point;

      if (direction > 0)
      {
         tp = entry + rr * atr;
         sl = (i == 3 && UseBreakEvenTP_T4) ? entry : entry - stopSize;
      }
      else
      {
         tp = entry - rr * atr;
         sl = (i == 3 && UseBreakEvenTP_T4) ? entry : entry + stopSize;
      }

      tp = NormalizeDouble(tp, _Digits);
      sl = NormalizeDouble(sl, _Digits);

      // ✅ Send trade
      bool sent = SendOrder(direction, lotPerTier, entry, sl, tp, comment);
      if (sent)
         PrintFormat("✅ [TradeManager] Tier %d SENT | TP: %.5f | SL: %.5f", i + 1, tp, sl);
   }
}

//+------------------------------------------------------------------+
//| Get ATR or fallback                                              |
//+------------------------------------------------------------------+
double GetValidATR()
{
   double buffer[];
   if (atrHandleTrade == INVALID_HANDLE || CopyBuffer(atrHandleTrade, 0, 0, 1, buffer) != 1 || buffer[0] <= 0.0)
   {
      Print("⚠️ [TradeManager] Invalid ATR buffer.");
      return -1.0;
   }
   return buffer[0];
}

//+------------------------------------------------------------------+
//| Execute order                                                    |
//+------------------------------------------------------------------+
bool SendOrder(int direction, double lot, double price, double sl, double tp, string comment)
{
   MqlTradeRequest request;
   MqlTradeResult  result;
   ZeroMemory(request); ZeroMemory(result);

   request.action   = TRADE_ACTION_DEAL;
   request.symbol   = _Symbol;
   request.volume   = lot;
   request.type     = (direction > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   request.price    = NormalizeDouble(price, _Digits);
   request.sl       = NormalizeDouble(sl, _Digits);
   request.tp       = NormalizeDouble(tp, _Digits);
   request.deviation = MaxSlippage;
   request.magic     = MagicNumber;
   request.comment   = comment;

   if (!OrderSend(request, result))
   {
      PrintFormat("❌ [TradeManager] OrderSend failed | Error: %d", GetLastError());
      return false;
   }

   if (result.retcode != TRADE_RETCODE_DONE)
   {
      PrintFormat("❌ [TradeManager] REJECTED | Code: %d | Msg: %s", result.retcode, result.comment);
      return false;
   }

   PrintFormat("📥 [TradeManager] Order Confirmed | Ticket: %d", result.order);
   return true;
}
