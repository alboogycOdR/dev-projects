//+------------------------------------------------------------------+
//| CRT_Core.mqh – Final Enhanced Version                            |
//+------------------------------------------------------------------+
#property library
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
/*

Changes :

Entry confirmation logic
Repainting prevention (m15[1])
FVG time filtering
ATR-based SL/TP support*/

 //+------------------------------------------------------------------+
//| CRT_Core.mqh – Final Enhanced Version with Feature Toggles         |
//+------------------------------------------------------------------+
 

//--- FEATURE TOGGLES ------------------------------------------------
input bool Use_FVG_SizeValidation = true;      // Validate FVG size
input double MinFVGSizePips = 10.0;          // Minimum FVG size in pips
input bool Use_TimeBasedFiltering = true;      // Trade only during specific hours
input int  TradingStartHour = 8;              // 8 AM
input int  TradingEndHour = 20;              // 8 PM
input bool Use_ATR_SL = true;                // Use ATR-based SL instead of CRT levels
input int  ATRPeriod = 14;                   // ATR period
input double ATRMultiplier = 1.5;             // ATR multiplier for SL
input bool DebugEngulfing = true;             // Show engulfing pattern detection

//--- ENUMS & STRUCT ------------------------------------------------
enum ENUM_SETUP_STATE { IDLE, SWEEP, MSS, FVG, ENTRY };
enum ENUM_BIAS        { NEUTRAL, BULLISH, BEARISH };

struct CRT_State
{
   string            symbol;
   ENUM_BIAS         bias;
   datetime          bias_time;
   double            crt_high;
   double            crt_low;
   double            mss_level;
   datetime          mss_time;
   double            fvg_high;
   double            fvg_low;
   ENUM_SETUP_STATE  bull_state;
   ENUM_SETUP_STATE  bear_state;
};

//--- STATE HELPERS --------------------------------------------------
void ResetState(CRT_State &s, const string symbol_to_set)
{
   s.bias       = NEUTRAL;
   s.bias_time  = 0;
   s.crt_high   = 0.0;
   s.crt_low    = 0.0;
   s.mss_level  = 0.0;
   s.mss_time   = 0;
   s.fvg_high   = 0.0;
   s.fvg_low    = 0.0;
   s.bull_state = IDLE;
   s.bear_state = IDLE;
   s.symbol     = symbol_to_set;
}

//--- HELPER FUNCTIONS -----------------------------------------------
bool IsBullishEngulfing(MqlRates &rates[]) 
{
   bool result = (rates[1].open < rates[1].close && 
                  rates[0].open > rates[1].close && 
                  rates[0].close > rates[1].open);
   if(DebugEngulfing && result)
      Print("ENGULFING BULLISH DETECTED");
   return result;
}

bool IsBearishEngulfing(MqlRates &rates[]) 
{
   bool result = (rates[1].open > rates[1].close && 
                  rates[0].open < rates[1].close && 
                  rates[0].close < rates[1].open);
   if(DebugEngulfing && result)
      Print("ENGULFING BEARISH DETECTED");
   return result;
}

//--- CRT BIAS (with validation) ------------------------------------
ENUM_BIAS CRT_Bias(const string sym, datetime &range_time, datetime &sweep_time,
                   double &range_high, double &range_low)
{
   if(!SymbolSelect(sym, true)) return NEUTRAL;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(sym, PERIOD_H4, 1, 2, r) != 2) return NEUTRAL;

   range_time = r[1].time;
   sweep_time = r[0].time;
   range_high = r[1].high;
   range_low  = r[1].low;

   if(r[0].low < range_low && r[0].close >= range_low) return BULLISH;
   if(r[0].high > range_high && r[0].close <= range_high) return BEARISH;
   return NEUTRAL;
}

//--- M15 STATE STEP (with all enhancements) -------------------------
void M15_Step(CRT_State &s)
{
   if(s.bias != BULLISH && s.bias != BEARISH) return;

   MqlRates m15[];
   ArraySetAsSeries(m15, true);
   if(CopyRates(s.symbol, PERIOD_M15, 0, 25, m15) < 3) return;

   double pip_size = SymbolInfoDouble(s.symbol, SYMBOL_POINT) * 10; // 1 pip size
   double fvg_size = (s.bias == BULLISH) ? (s.fvg_low - s.fvg_high)/pip_size : (s.fvg_high - s.fvg_low)/pip_size;

   if(s.bias == BULLISH)
   {
      switch(s.bull_state)
      {
         case IDLE:
            if(m15[1].low < s.crt_low)
            {
               s.mss_level = m15[1].low;
               s.mss_time = m15[1].time;
               s.bull_state = SWEEP;
               Print(s.symbol, " | BULL | IDLE→SWEEP | MSS: ", s.mss_level);
            }
            break;

         case SWEEP:
            if(m15[1].high > s.mss_level)
               s.bull_state = MSS;
            break;

         case MSS:
            for(int i=2; i<ArraySize(m15); i++)
            {
               if(m15[i-2].high < m15[i].low && 
                  m15[i-1].low > m15[i-2].high && 
                  m15[i-1].high > m15[i].low &&
                  m15[i].time > s.mss_time)
               {
                  if(Use_FVG_SizeValidation)
                  {
                     double detected_fvg_size = (m15[i].low - m15[i-2].high)/pip_size;
                     if(detected_fvg_size < MinFVGSizePips) 
                     {
                        Print(s.symbol, " | BULL | FVG TOO SMALL: ", detected_fvg_size, " pips (min: ", MinFVGSizePips, ")");
                        continue;
                     }
                  }

                  s.fvg_high = m15[i-2].high;
                  s.fvg_low  = m15[i].low;
                  s.bull_state = FVG;
                  Print(s.symbol, " | BULL | MSS→FVG | FVG: ", s.fvg_low, "-", s.fvg_high, 
                        " | Size: ", fvg_size, " pips");
                  break;
               }
            }
            break;

         case FVG:
            if(m15[1].low < s.fvg_high)
            {
               if(!Use_EntryConfirmation || IsBullishEngulfing(m15))
               {
                  s.bull_state = ENTRY;
                  Print(s.symbol, " | BULL | FVG→ENTRY | FVG: ", s.fvg_low, "-", s.fvg_high);
               }
            }
            break;
      }
   }
   else // BEARISH
   {
      switch(s.bear_state)
      {
         case IDLE:
            if(m15[1].high > s.crt_high)
            {
               s.mss_level = m15[1].high;
               s.mss_time = m15[1].time;
               s.bear_state = SWEEP;
               Print(s.symbol, " | BEAR | IDLE→SWEEP | MSS: ", s.mss_level);
            }
            break;

         case SWEEP:
            if(m15[1].low < s.mss_level)
               s.bear_state = MSS;
            break;

         case MSS:
            for(int i=2; i<ArraySize(m15); i++)
            {
               if(m15[i-2].low > m15[i].high &&
                  m15[i-1].high < m15[i-2].low &&
                  m15[i-1].low < m15[i].high &&
                  m15[i].time > s.mss_time)
               {
                  if(Use_FVG_SizeValidation)
                  {
                     double detected_fvg_size = (m15[i-2].low - m15[i].high)/pip_size;
                     if(detected_fvg_size < MinFVGSizePips) 
                     {
                        Print(s.symbol, " | BEAR | FVG TOO SMALL: ", detected_fvg_size, " pips (min: ", MinFVGSizePips, ")");
                        continue;
                     }
                  }

                  s.fvg_high = m15[i].high;
                  s.fvg_low  = m15[i-2].low;
                  s.bear_state = FVG;
                  Print(s.symbol, " | BEAR | MSS→FVG | FVG: ", s.fvg_low, "-", s.fvg_high, 
                        " | Size: ", fvg_size, " pips");
                  break;
               }
            }
            break;

         case FVG:
            if(m15[1].high > s.fvg_low)
            {
               if(!Use_EntryConfirmation || IsBearishEngulfing(m15))
               {
                  s.bear_state = ENTRY;
                  Print(s.symbol, " | BEAR | FVG→ENTRY | FVG: ", s.fvg_low, "-", s.fvg_high);
               }
            }
            break;
      }
   }
}
//+------------------------------------------------------------------+