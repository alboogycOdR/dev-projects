//+------------------------------------------------------------------+
//| HybridSmartZoneStrategy - Domain Layer                          |
//+------------------------------------------------------------------+
#include "ISignalStrategy.mqh"

class HybridSmartZoneStrategy : public ISignalStrategy
  {
private:
   int EMA_Period, ADX_Period, RSI_Period, BB_Period, ATR_Period, MACD_Fast, MACD_Slow, MACD_Signal;
   double BB_Deviation;
   ENUM_TIMEFRAMES TF;
   int adx_handle, ema_handle, macd_handle, rsi_handle, bb_handle;
public:
   HybridSmartZoneStrategy(
      int ema, int adx, int rsi, int bb, double bbdev, int atr, int macdf, int macds, int macdsig, ENUM_TIMEFRAMES tf)
      : EMA_Period(ema), ADX_Period(adx), RSI_Period(rsi), BB_Period(bb), BB_Deviation(bbdev),
        ATR_Period(atr), MACD_Fast(macdf), MACD_Slow(macds), MACD_Signal(macdsig), TF(tf)
   {
      adx_handle  = iADX(_Symbol, TF, ADX_Period);
      ema_handle  = iMA(_Symbol, TF, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
      macd_handle = iMACD(_Symbol, TF, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
      rsi_handle  = iRSI(_Symbol, TF, RSI_Period, PRICE_CLOSE);
      bb_handle   = iBands(_Symbol, TF, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
   }

   int GenerateSignal() override
     {
      double adx_buffer[1], ema_buffer[1], macd_main[1], macd_signal[1], rsi_buffer[1], bb_upper[1], bb_middle[1], bb_lower[1];
      if(CopyBuffer(adx_handle, 0, 0, 1, adx_buffer) != 1) return 0;
      if(CopyBuffer(ema_handle, 0, 0, 1, ema_buffer) != 1) return 0;
      if(CopyBuffer(macd_handle, 0, 0, 1, macd_main) != 1) return 0;
      if(CopyBuffer(macd_handle, 1, 0, 1, macd_signal) != 1) return 0;
      if(CopyBuffer(rsi_handle, 0, 0, 1, rsi_buffer) != 1) return 0;
      if(CopyBuffer(bb_handle, 0, 0, 1, bb_upper) != 1) return 0;
      if(CopyBuffer(bb_handle, 1, 0, 1, bb_middle) != 1) return 0;
      if(CopyBuffer(bb_handle, 2, 0, 1, bb_lower) != 1) return 0;

      double adx = adx_buffer[0];
      double ema200 = ema_buffer[0];
      double macdMain = macd_main[0];
      double macdSignal = macd_signal[0];
      double rsi = rsi_buffer[0];
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      Print("adx=",adx," ema200=",ema200," macdMain=",macdMain," macdSignal=",macdSignal," rsi=",rsi," price=",price);

      // Trend Mode
      if(adx > 20)
        {
         if(price > ema200 && macdMain > macdSignal)
            return 1; // Buy
         else if(price < ema200 && macdMain < macdSignal)
            return -1; // Sell
        }
      // Sideway Mode
      else
        {
         if(rsi < 30 && price <= bb_lower[0])
            return 1; // Buy
         else if(rsi > 70 && price >= bb_upper[0])
            return -1; // Sell
        }
      return 0; // No trade
     }
   string Name() override { return "Hybrid Smart Zone"; }
  }; 