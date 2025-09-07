//+------------------------------------------------------------------+
//|                        FilterStack.mqh                           |
//| SmartGuard EA v2.0 – Spread, Session & Volatility Filter Stack  |
//+------------------------------------------------------------------+
#property strict
#include "StrategyConfig.mqh"

//--- Internal
int atrHandle = INVALID_HANDLE;
input bool DebugFilters = true;

//+------------------------------------------------------------------+
//| Initialize ATR handle                                            |
//+------------------------------------------------------------------+
void InitFilterIndicators()
{
   atrHandle = iATR(_Symbol, ATRTimeframe, ATRPeriod);
   if (atrHandle == INVALID_HANDLE)
      Print("❌ [FilterStack] ATR init failed.");
   else
      Print("✅ [FilterStack] ATR indicator ready.");
}

//+------------------------------------------------------------------+
//| Cleanup                                                          |
//+------------------------------------------------------------------+
void DeinitFilterIndicators()
{
   if (atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
   Print("🧹 [FilterStack] ATR handle released.");
}

//+------------------------------------------------------------------+
//| Run full filter stack                                            |
//+------------------------------------------------------------------+
bool FiltersPass()
{
   if (!SpreadFilter())
   {
      if (DebugFilters) Print("⛔ [FilterStack] Spread block.");
      return false;
   }

   if (UseSessionFilter && !SessionFilter())
   {
      if (DebugFilters) Print("⛔ [FilterStack] Session block.");
      return false;
   }

   if (UseVolatilityCheck && !VolatilityFilter())
   {
      if (DebugFilters) Print("⛔ [FilterStack] Volatility block.");
      return false;
   }

   if (DebugFilters) Print("✅ [FilterStack] All filters passed.");
   return true;
}

//+------------------------------------------------------------------+
//| Spread Filter                                                    |
//+------------------------------------------------------------------+
bool SpreadFilter()
{
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if (tickSize <= 0.0) tickSize = _Point;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spreadPts = (ask - bid) / tickSize;

   if (spreadPts > MaxAllowedSpread)
   {
      if (DebugFilters)
         PrintFormat("🚫 [Filter] Spread too high: %.1f > Max %.1f", spreadPts, MaxAllowedSpread);
      return false;
   }

   if (DebugFilters)
      PrintFormat("✅ [Filter] Spread OK: %.1f ≤ %.1f", spreadPts, MaxAllowedSpread);
   return true;
}

//+------------------------------------------------------------------+
//| Session Time Filter                                              |
//+------------------------------------------------------------------+
bool SessionFilter()
{
   MqlDateTime now;
   TimeCurrent(now);
   int currMinutes = now.hour * 60 + now.min;
   int sessionStart = SessionStartHour * 60;
   int sessionEnd = SessionEndHour * 60;

   if (currMinutes < sessionStart || currMinutes >= sessionEnd)
   {
      if (DebugFilters)
         PrintFormat("⏰ [Filter] Out of session: Now %02d:%02d | Allowed: %02d:00–%02d:00",
                     now.hour, now.min, SessionStartHour, SessionEndHour);
      return false;
   }

   if (DebugFilters)
      PrintFormat("✅ [Filter] Time OK: %02d:%02d", now.hour, now.min);
   return true;
}

//+------------------------------------------------------------------+
//| ATR Volatility Filter                                            |
//+------------------------------------------------------------------+
bool VolatilityFilter()
{
   if (atrHandle == INVALID_HANDLE)
   {
      if (DebugFilters) Print("❌ [Filter] ATR handle invalid.");
      return false;
   }

   double atrBuf[];
   if (CopyBuffer(atrHandle, 0, 0, 1, atrBuf) != 1 || atrBuf[0] <= 0.0)
   {
      if (DebugFilters)
         PrintFormat("⚠️ [Filter] ATR read failed or empty. Val = %.5f", atrBuf[0]);
      return false;
   }

   if (atrBuf[0] < MinATR)
   {
      if (DebugFilters)
         PrintFormat("📉 [Filter] ATR %.5f < Min %.5f – Low volatility", atrBuf[0], MinATR);
      return false;
   }

   if (DebugFilters)
      PrintFormat("✅ [Filter] ATR OK: %.5f ≥ %.5f", atrBuf[0], MinATR);
   return true;
}
