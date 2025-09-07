//+------------------------------------------------------------------+
//|                      TrailingStopManager.mqh                     |
//|   SmartGuard EA v2.0 – Tier-4 ATR Trailing Stop with Control     |
//+------------------------------------------------------------------+
#property strict
#include "StrategyConfig.mqh"
#include <Trade\PositionInfo.mqh>  // ✅ Required for position methods

//--- Internal ATR handle
int atrHandleTrail = INVALID_HANDLE;

//--- Initialization
void InitTrailingIndicators()
{
   atrHandleTrail = iATR(_Symbol, ATRTimeframe, ATRPeriod);
   if (atrHandleTrail == INVALID_HANDLE)
      Print("❌ [Trailing] ATR handle init failed.");
   else
      Print("✅ [Trailing] ATR handle ready.");
}

void DeinitTrailingIndicators()
{
   if (atrHandleTrail != INVALID_HANDLE)
      IndicatorRelease(atrHandleTrail);
}

//--- Main trailing stop logic
void ManageTrailingStop()
{
   double atr = GetTrailingATR();
   if (atr <= 0.0)
   {
      Print("⚠️ [Trailing] ATR invalid. Skipping.");
      return;
   }

   CPositionInfo position;

   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if (!position.SelectByIndex(i)) continue;

      ulong ticket = position.Ticket();
      string comment = position.Comment();
      int type = (int)position.Type();
      double entryPrice = position.PriceOpen();
      double sl = position.StopLoss();   // ✅ FIXED
      double currentPrice = (type == POSITION_TYPE_BUY)
                          ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                          : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      // Only apply to Tier-4 runner
      if (StringFind(comment, "T4") < 0) continue;

      // Respect break-even TP toggle (disables trailing if BE TP is active)
      if (UseBreakEvenTP_T4)
      {
         PrintFormat("🔕 [Trailing] Skipping T4 trailing due to BE mode | Ticket %d", ticket);
         continue;
      }

      double profitPoints = (type == POSITION_TYPE_BUY)
                          ? (currentPrice - entryPrice) / _Point
                          : (entryPrice - currentPrice) / _Point;

      double startTrail = TrailingStartATRMultiplier * atr / _Point;
      double gapPoints  = TrailingGapATRMultiplier   * atr / _Point;

      if (profitPoints < startTrail)
      {
         PrintFormat("🕒 [Trailing] Not yet triggered | Profit: %.1f < Start: %.1f", profitPoints, startTrail);
         continue;
      }

      double newSL = (type == POSITION_TYPE_BUY)
                   ? currentPrice - gapPoints * _Point
                   : currentPrice + gapPoints * _Point;

      newSL = NormalizeDouble(newSL, _Digits);
      bool shouldUpdate = false;

      if (type == POSITION_TYPE_BUY && (sl == 0.0 || newSL > sl)) shouldUpdate = true;
      if (type == POSITION_TYPE_SELL && (sl == 0.0 || newSL < sl)) shouldUpdate = true;

      if (!shouldUpdate)
      {
         PrintFormat("🟡 [Trailing] No SL update needed | Current SL: %.5f | New SL: %.5f", sl, newSL);
         continue;
      }

      // Submit SL modification
      MqlTradeRequest req;
      MqlTradeResult  res;
      ZeroMemory(req); ZeroMemory(res);

      req.action   = TRADE_ACTION_SLTP;
      req.symbol   = _Symbol;
      req.position = ticket;
      req.sl       = newSL;
      req.tp       = position.TakeProfit();  // ✅ FIXED

      if (!OrderSend(req, res) || res.retcode != TRADE_RETCODE_DONE)
      {
         PrintFormat("❌ [Trailing] SL update failed | Ticket: %d | RetCode: %d", ticket, res.retcode);
         continue;
      }

      PrintFormat("🔁 [Trailing] SL updated | Ticket: %d | New SL: %.5f", ticket, newSL);
   }
}

//--- Fetch valid ATR value
double GetTrailingATR()
{
   double buffer[];
   if (atrHandleTrail == INVALID_HANDLE || CopyBuffer(atrHandleTrail, 0, 0, 1, buffer) != 1 || buffer[0] <= 0.0)
      return -1.0;
   return buffer[0];
}
