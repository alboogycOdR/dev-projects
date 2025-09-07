//+------------------------------------------------------------------+
//|                        EntryLogic.mqh                            |
//|  SmartGuard EA v2.0 — EMA Crossover + RSI Swing Signal Logic     |
//+------------------------------------------------------------------+
#property strict
#include "StrategyConfig.mqh"

//--- Indicator handles
int emaFastHandle = INVALID_HANDLE;
int emaSlowHandle = INVALID_HANDLE;
int rsiHandle     = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Initialize EMA(3/7) and RSI(5)                                   |
//+------------------------------------------------------------------+
void InitEntryLogicIndicators()
{
   emaFastHandle = iMA(_Symbol, Timeframe, EMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowHandle = iMA(_Symbol, Timeframe, EMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   rsiHandle     = iRSI(_Symbol, Timeframe, RSIPeriod, PRICE_CLOSE);

   if (emaFastHandle == INVALID_HANDLE || emaSlowHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE)
      Print("❌ [EntryLogic] Indicator init failed.");
   else
      Print("✅ [EntryLogic] EMA+RSI indicators ready.");
}

//+------------------------------------------------------------------+
//| Release handles                                                  |
//+------------------------------------------------------------------+
void DeinitEntryLogicIndicators()
{
   if (emaFastHandle != INVALID_HANDLE) IndicatorRelease(emaFastHandle);
   if (emaSlowHandle != INVALID_HANDLE) IndicatorRelease(emaSlowHandle);
   if (rsiHandle     != INVALID_HANDLE) IndicatorRelease(rsiHandle);
   Print("🧹 [EntryLogic] EMA+RSI indicators released.");
}

//+------------------------------------------------------------------+
//| Returns: 1 = BUY | -1 = SELL | 0 = NO SIGNAL                     |
//+------------------------------------------------------------------+
int CheckEntrySignal()
{
   double fastBuf[2], slowBuf[2], rsiBuf[1];

   if (CopyBuffer(emaFastHandle, 0, 0, 2, fastBuf) != 2 ||
       CopyBuffer(emaSlowHandle, 0, 0, 2, slowBuf) != 2 ||
       CopyBuffer(rsiHandle, 0, 0, 1, rsiBuf) != 1)
   {
      Print("⚠️ [EntryLogic] Buffer read failed.");
      return 0;
   }

   double emaFastPrev = fastBuf[1];
   double emaFastCurr = fastBuf[0];
   double emaSlowPrev = slowBuf[1];
   double emaSlowCurr = slowBuf[0];
   double rsi         = rsiBuf[0];

   if (emaFastCurr == EMPTY_VALUE || emaSlowCurr == EMPTY_VALUE || rsi == EMPTY_VALUE)
   {
      Print("⚠️ [EntryLogic] EMPTY_VALUE in buffers.");
      return 0;
   }

   // ✅ Buy: EMA(3) crosses above EMA(7) + RSI > 45
   if (emaFastPrev <= emaSlowPrev && emaFastCurr > emaSlowCurr && rsi > RSIThreshold)
   {
      Print("📈 [EntryLogic] BUY signal (EMA up cross + RSI > threshold)");
      return 1;
   }

   // ✅ Sell: EMA(3) crosses below EMA(7) + RSI < 55
   if (emaFastPrev >= emaSlowPrev && emaFastCurr < emaSlowCurr && rsi < (100 - RSIThreshold))
   {
      Print("📉 [EntryLogic] SELL signal (EMA down cross + RSI < threshold)");
      return -1;
   }

   return 0;
}
