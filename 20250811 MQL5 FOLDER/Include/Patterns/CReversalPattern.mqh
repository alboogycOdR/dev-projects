//+------------------------------------------------------------------+
//|                                             CReversalPattern.mqh |
//|                                    Copyright 2017, Erwin Beckers |
//|                                      https://www.erwinbeckers.nl |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Erwin Beckers"
#property link      "https://www.erwinbeckers.nl"
#property strict

#include <Patterns\CBasePatternDetector.mqh>;

class CReversalPattern : public CBasePatternDetector
{
private: 
   string _patternName;
   
public:
   //+------------------------------------------------------------------+
   CReversalPattern()
   {
   }

   //+------------------------------------------------------------------+
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
     
     
      if (IsUp(bar) && !IsUp(bar+1))
      {
         double bodySize = MathAbs(iOpen(_symbol, m_period, bar+1) - iClose(_symbol, m_period, bar+1));
         double half = iClose(_symbol, m_period, bar+1) + bodySize * 0.5;
         
         if (iClose(_symbol, m_period, bar) > half)
         {
            if (iLow(_symbol, m_period, bar) < iLow(_symbol, m_period, bar+1))
            {
               _patternName = "Bullish Reversal candle";
               return true;
            }
         }
      }
      else if (!IsUp(bar) && IsUp(bar+1))
      {
         double bodySize = MathAbs(iOpen(_symbol, m_period, bar+1) - iClose(_symbol, m_period, bar+1));
         double half     = iClose(_symbol, m_period, bar+1) - bodySize * 0.5;
         
         if (iClose(_symbol, m_period, bar) < half)
         {
            if (iHigh(_symbol, m_period, bar) > iHigh(_symbol, m_period, bar+1))
            {
               _patternName = "Bearish Reversal candle";
               return true;
            }
         }
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

