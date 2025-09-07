//+------------------------------------------------------------------+
//|                                       CDoubleReversalPattern.mqh |
//|                                    Copyright 2017, Erwin Beckers |
//|                                      https://www.erwinbeckers.nl |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Erwin Beckers"
#property link      "https://www.erwinbeckers.nl"
#property strict

#include <Patterns\CBasePatternDetector.mqh>;

class CDoubleReversalPattern : public CBasePatternDetector
{
private:
   int    _pipsMargin;
   int    _previousCandleCount;
   int    _bodySizePercentage;
   string _patternName;
   
public:
   //+------------------------------------------------------------------+
   CDoubleReversalPattern(int previousCandleCount=5, int bodySizePercentage=70) 
   {
      _previousCandleCount = previousCandleCount;
      _bodySizePercentage = bodySizePercentage;
   }

   //+------------------------------------------------------------------+
   // engulfing : 
   //  - bar is opposite from previous bar
   //  - range is greater then range of previous candles
   //  - range is greater then the range of the previous 5 candles
   //  - body is 70% or higher of the range
   //
   bool IsValid(string symbol, int period, int bar)
   {
      _symbol = symbol;
      _period = period;
      
      ENUM_TIMEFRAMES   m_period;
      switch(_period)
     {
      case 0: m_period=PERIOD_CURRENT;
      case 1: m_period=PERIOD_M1;
      case 5: m_period=PERIOD_M5;
      case 15: m_period=PERIOD_M15;
      case 30: m_period=PERIOD_M30;
      case 60: m_period=PERIOD_H1;
      case 240: m_period=PERIOD_H4;
      case 1440: m_period=PERIOD_D1;
      case 10080: m_period=PERIOD_W1;
      case 43200: m_period=PERIOD_MN1;
      
      case 2: m_period=PERIOD_M2;
      case 3: m_period=PERIOD_M3;
      case 4: m_period=PERIOD_M4;      
      case 6: m_period=PERIOD_M6;
      case 10: m_period=PERIOD_M10;
      case 12: m_period=PERIOD_M12;
      case 16385: m_period=PERIOD_H1;
      case 16386: m_period=PERIOD_H2;
      case 16387: m_period=PERIOD_H3;
      case 16388: m_period=PERIOD_H4;
      case 16390: m_period=PERIOD_H6;
      case 16392: m_period=PERIOD_H8;
      case 16396: m_period=PERIOD_H12;
      case 16408: m_period=PERIOD_D1;
      case 32769: m_period=PERIOD_W1;
      case 49153: m_period=PERIOD_MN1;      
      default: m_period=PERIOD_CURRENT;
     }
     
      bool isUp1 = IsUp(bar);
      bool isUp2 = IsUp(bar+1);
      if (isUp1 == isUp2) return false;
      
      // check if bar has the highest range of the previous x bars
      double maxRange=0;
      double candleRange = GetCandleRangeSize(bar);
      for (int i=0; i < _previousCandleCount; ++i)
      {
         maxRange = MathMax(maxRange, GetCandleRangeSize(bar + 1 + i) );
      }
      if (candleRange < maxRange) return false;
      
      // check body size
      double bodySize = GetCandleBodySize(bar);
      double percentage = (bodySize / candleRange) * 100.0;
      if (percentage < _bodySizePercentage) return false;
    
     
      
      
      if (isUp2)
      {
         _patternName = "Bearish double reversal";
         if ( iLow (_symbol, m_period, bar) < iLow (_symbol, m_period, bar+1) && 
              iHigh(_symbol, m_period, bar) > iHigh(_symbol, m_period, bar+1) ) return true;
      }
      else
      {
         _patternName = "Bullish double reversal";
         if ( iHigh(_symbol, m_period, bar) > iHigh(_symbol, m_period, bar+1) && 
              iLow (_symbol, m_period, bar) < iLow (_symbol, m_period, bar+1) ) return true;
      }
      return false;
   }
   
   //+------------------------------------------------------------------+
   string PatternName()
   {
      return _patternName;
   }
   
   //+------------------------------------------------------------------+
   int BarCount()
   {
      return 2;
   }
};

