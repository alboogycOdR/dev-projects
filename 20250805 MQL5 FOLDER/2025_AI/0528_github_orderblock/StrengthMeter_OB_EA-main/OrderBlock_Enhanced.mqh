//+------------------------------------------------------------------+
//|                                         OrderBlock_Enhanced.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

//--- Enhanced Order Block Detection Library
//--- This library provides advanced order block detection with liquidity sweep validation

struct LiquiditySweep
{
   bool occurred;
   datetime time;
   double price;
   bool is_high_sweep;  // true for high sweep, false for low sweep
};

struct EnhancedOrderBlock
{
   double high;
   double low;
   double open;
   double close;
   datetime time;
   bool is_bullish;
   bool valid;
   bool after_liquidity_sweep;
   double strength_score;  // 0-100 rating
   int volume_confirmation;
};

class COrderBlockDetector
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int m_lookback_bars;
   double m_min_ob_size;
   
public:
   COrderBlockDetector(string symbol, ENUM_TIMEFRAMES timeframe, int lookback = 50, double min_size = 10.0);
   ~COrderBlockDetector();
   
   // Main detection methods
   EnhancedOrderBlock DetectOrderBlock();
   bool HasBreakOfStructure();
   LiquiditySweep DetectLiquiditySweep();
   
   // Validation methods
   bool ValidateOrderBlock(EnhancedOrderBlock &ob);
   double CalculateOBStrength(EnhancedOrderBlock &ob);
   bool IsSignificantCandle(int bar_index);
   
   // Liquidity methods
   bool IsLiquiditySweep(int bar_index);
   bool HasRecentLiquiditySweep(int lookback_period = 10);
   
   // Structure methods
   bool IsBOS(double current_price, bool is_bullish);
   bool IsValidPullback(int ob_bar, bool is_bullish);
   
   // Utility methods
   double GetATR(int period = 14);
   bool IsInsideBar(int bar_index);
   bool IsEngulfingPattern(int bar_index);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
COrderBlockDetector::COrderBlockDetector(string symbol, ENUM_TIMEFRAMES timeframe, int lookback = 50, double min_size = 10.0)
{
   m_symbol = symbol;
   m_timeframe = timeframe;
   m_lookback_bars = lookback;
   m_min_ob_size = min_size;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
COrderBlockDetector::~COrderBlockDetector()
{
}

//+------------------------------------------------------------------+
//| Main order block detection                                       |
//+------------------------------------------------------------------+
EnhancedOrderBlock COrderBlockDetector::DetectOrderBlock()
{
   EnhancedOrderBlock ob;
   ob.valid = false;
   ob.strength_score = 0;
   ob.after_liquidity_sweep = false;
   
   // First check if we have a Break of Structure
   if(!HasBreakOfStructure())
      return ob;
   
   // Check for recent liquidity sweep
   LiquiditySweep sweep = DetectLiquiditySweep();
   
   // Look for order blocks
   for(int i = 1; i < m_lookback_bars; i++)
   {
      if(!IsSignificantCandle(i))
         continue;
      
      double high = iHigh(m_symbol, m_timeframe, i);
      double low = iLow(m_symbol, m_timeframe, i);
      double open = iOpen(m_symbol, m_timeframe, i);
      double close = iClose(m_symbol, m_timeframe, i);
      
      // Check candle size
      double candle_size = MathAbs(high - low) / SymbolInfoDouble(m_symbol, SYMBOL_POINT) / 10;
      if(candle_size < m_min_ob_size)
         continue;
      
      bool is_bullish = close > open;
      
      // Validate pullback after this candle
      if(!IsValidPullback(i, is_bullish))
         continue;
      
      // Create order block
      ob.high = high;
      ob.low = low;
      ob.open = open;
      ob.close = close;
      ob.time = iTime(m_symbol, m_timeframe, i);
      ob.is_bullish = is_bullish;
      ob.valid = true;
      ob.after_liquidity_sweep = sweep.occurred;
      
      // Calculate strength score
      ob.strength_score = CalculateOBStrength(ob);
      
      // Prefer order blocks after liquidity sweeps
      if(sweep.occurred && 
         MathAbs((double)(ob.time - sweep.time)) < 3600 * 4) // Within 4 hours
      {
         ob.strength_score += 20; // Bonus for liquidity sweep
      }
      
      // Validate the order block
      if(ValidateOrderBlock(ob))
         return ob;
   }
   
   return ob;
}

//+------------------------------------------------------------------+
//| Check for Break of Structure                                     |
//+------------------------------------------------------------------+
bool COrderBlockDetector::HasBreakOfStructure()
{
   double recent_high = 0;
   double recent_low = DBL_MAX;
   
   // Find recent swing high and low
   for(int i = 1; i <= 20; i++)
   {
      double high = iHigh(m_symbol, m_timeframe, i);
      double low = iLow(m_symbol, m_timeframe, i);
      
      if(high > recent_high) recent_high = high;
      if(low < recent_low) recent_low = low;
   }
   
   double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   double atr = GetATR();
   
   // BOS occurs when price breaks recent high/low by significant amount
   bool bullish_bos = current_price > recent_high + atr * 0.5;
   bool bearish_bos = current_price < recent_low - atr * 0.5;
   
   return (bullish_bos || bearish_bos);
}

//+------------------------------------------------------------------+
//| Detect liquidity sweep                                           |
//+------------------------------------------------------------------+
LiquiditySweep COrderBlockDetector::DetectLiquiditySweep()
{
   LiquiditySweep sweep;
   sweep.occurred = false;
   
   double atr = GetATR();
   
   for(int i = 1; i <= 20; i++)
   {
      double high = iHigh(m_symbol, m_timeframe, i);
      double low = iLow(m_symbol, m_timeframe, i);
      double close = iClose(m_symbol, m_timeframe, i);
      
      // Look for wicks that sweep liquidity
      double upper_wick = high - MathMax(iOpen(m_symbol, m_timeframe, i), close);
      double lower_wick = MathMin(iOpen(m_symbol, m_timeframe, i), close) - low;
      
      // Significant wick indicates liquidity sweep
      if(upper_wick > atr * 0.7)
      {
         // Check if it swept previous highs
         bool swept_highs = false;
         for(int j = i + 1; j <= i + 10; j++)
         {
            if(high > iHigh(m_symbol, m_timeframe, j))
            {
               swept_highs = true;
               break;
            }
         }
         
         if(swept_highs)
         {
            sweep.occurred = true;
            sweep.time = iTime(m_symbol, m_timeframe, i);
            sweep.price = high;
            sweep.is_high_sweep = true;
            return sweep;
         }
      }
      
      if(lower_wick > atr * 0.7)
      {
         // Check if it swept previous lows
         bool swept_lows = false;
         for(int j = i + 1; j <= i + 10; j++)
         {
            if(low < iLow(m_symbol, m_timeframe, j))
            {
               swept_lows = true;
               break;
            }
         }
         
         if(swept_lows)
         {
            sweep.occurred = true;
            sweep.time = iTime(m_symbol, m_timeframe, i);
            sweep.price = low;
            sweep.is_high_sweep = false;
            return sweep;
         }
      }
   }
   
   return sweep;
}

//+------------------------------------------------------------------+
//| Validate order block                                             |
//+------------------------------------------------------------------+
bool COrderBlockDetector::ValidateOrderBlock(EnhancedOrderBlock &ob)
{
   // Minimum strength score required
   if(ob.strength_score < 30)
      return false;
   
   // Check if order block is too old
   datetime current_time = TimeCurrent();
   if(current_time - ob.time > 86400 * 7) // Older than 1 week
      return false;
   
   // Check if order block has been violated too many times
   int violation_count = 0;
   datetime ob_time = ob.time;
   
   for(int i = 0; i < 100; i++)
   {
      datetime bar_time = iTime(m_symbol, m_timeframe, i);
      if(bar_time <= ob_time)
         break;
      
      double high = iHigh(m_symbol, m_timeframe, i);
      double low = iLow(m_symbol, m_timeframe, i);
      
      // Check for violations
      if(ob.is_bullish)
      {
         if(low < ob.low)
            violation_count++;
      }
      else
      {
         if(high > ob.high)
            violation_count++;
      }
   }
   
   // Too many violations make the OB invalid
   if(violation_count > 3)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate order block strength                                   |
//+------------------------------------------------------------------+
double COrderBlockDetector::CalculateOBStrength(EnhancedOrderBlock &ob)
{
   double strength = 0;
   
   // Base strength from candle size
   double candle_size = MathAbs(ob.high - ob.low);
   double atr = GetATR();
   
   if(candle_size > atr * 1.5)
      strength += 30;
   else if(candle_size > atr)
      strength += 20;
   else
      strength += 10;
   
   // Body to wick ratio
   double body_size = MathAbs(ob.close - ob.open);
   double body_ratio = body_size / candle_size;
   
   if(body_ratio > 0.7)
      strength += 20; // Strong body
   else if(body_ratio > 0.5)
      strength += 10;
   
   // Volume confirmation (if available)
   long volume = iVolume(m_symbol, m_timeframe, 0);
   if(volume > 0)
   {
      // Compare with average volume
      double avg_volume = 0;
      for(int i = 1; i <= 10; i++)
      {
         avg_volume += iVolume(m_symbol, m_timeframe, i);
      }
      avg_volume /= 10;
      
      if(volume > avg_volume * 1.5)
         strength += 15;
   }
   
   // Time of day bonus (during active sessions)
   MqlDateTime dt;
   TimeToStruct(ob.time, dt);
   
   // London/NY session overlap (13:00-17:00 GMT)
   if(dt.hour >= 13 && dt.hour <= 17)
      strength += 10;
   
   return MathMin(strength, 100); // Cap at 100
}

//+------------------------------------------------------------------+
//| Check if candle is significant                                   |
//+------------------------------------------------------------------+
bool COrderBlockDetector::IsSignificantCandle(int bar_index)
{
   double high = iHigh(m_symbol, m_timeframe, bar_index);
   double low = iLow(m_symbol, m_timeframe, bar_index);
   double atr = GetATR();
   
   double candle_size = high - low;
   
   // Must be larger than average
   return (candle_size > atr * 0.8);
}

//+------------------------------------------------------------------+
//| Check for valid pullback                                         |
//+------------------------------------------------------------------+
bool COrderBlockDetector::IsValidPullback(int ob_bar, bool is_bullish)
{
   double ob_high = iHigh(m_symbol, m_timeframe, ob_bar);
   double ob_low = iLow(m_symbol, m_timeframe, ob_bar);
   
   // Check if price has returned to this level
   for(int i = 0; i < ob_bar; i++)
   {
      double high = iHigh(m_symbol, m_timeframe, i);
      double low = iLow(m_symbol, m_timeframe, i);
      
      if(is_bullish)
      {
         // For bullish OB, price should have pulled back to the range
         if(low <= ob_high && high >= ob_low)
            return true;
      }
      else
      {
         // For bearish OB, price should have pulled back to the range
         if(low <= ob_high && high >= ob_low)
            return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get Average True Range                                           |
//+------------------------------------------------------------------+
double COrderBlockDetector::GetATR(int period = 14)
{
   double atr_values[];
   ArrayResize(atr_values, period);
   
   for(int i = 0; i < period; i++)
   {
      double high = iHigh(m_symbol, m_timeframe, i + 1);
      double low = iLow(m_symbol, m_timeframe, i + 1);
      double prev_close = iClose(m_symbol, m_timeframe, i + 2);
      
      double tr1 = high - low;
      double tr2 = MathAbs(high - prev_close);
      double tr3 = MathAbs(low - prev_close);
      
      atr_values[i] = MathMax(tr1, MathMax(tr2, tr3));
   }
   
   double sum = 0;
   for(int i = 0; i < period; i++)
   {
      sum += atr_values[i];
   }
   
   return sum / period;
}

//+------------------------------------------------------------------+
//| Check if current bar is inside previous bar                     |
//+------------------------------------------------------------------+
bool COrderBlockDetector::IsInsideBar(int bar_index)
{
   if(bar_index >= Bars(m_symbol, m_timeframe) - 1)
      return false;
   
   double current_high = iHigh(m_symbol, m_timeframe, bar_index);
   double current_low = iLow(m_symbol, m_timeframe, bar_index);
   double prev_high = iHigh(m_symbol, m_timeframe, bar_index + 1);
   double prev_low = iLow(m_symbol, m_timeframe, bar_index + 1);
   
   return (current_high <= prev_high && current_low >= prev_low);
}

//+------------------------------------------------------------------+
//| Check for engulfing pattern                                      |
//+------------------------------------------------------------------+
bool COrderBlockDetector::IsEngulfingPattern(int bar_index)
{
   if(bar_index >= Bars(m_symbol, m_timeframe) - 1)
      return false;
   
   double current_open = iOpen(m_symbol, m_timeframe, bar_index);
   double current_close = iClose(m_symbol, m_timeframe, bar_index);
   double prev_open = iOpen(m_symbol, m_timeframe, bar_index + 1);
   double prev_close = iClose(m_symbol, m_timeframe, bar_index + 1);
   
   // Bullish engulfing
   if(current_close > current_open && prev_close < prev_open)
   {
      return (current_open < prev_close && current_close > prev_open);
   }
   
   // Bearish engulfing
   if(current_close < current_open && prev_close > prev_open)
   {
      return (current_open > prev_close && current_close < prev_open);
   }
   
   return false;
} 