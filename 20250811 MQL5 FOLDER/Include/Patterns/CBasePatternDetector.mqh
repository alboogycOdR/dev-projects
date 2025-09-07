//+------------------------------------------------------------------+
//|                                         CBasePatternDetector.mqh |
//|                                    Copyright 2017, Erwin Beckers |
//|                                      https://www.erwinbeckers.nl |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Erwin Beckers"
#property link      "https://www.erwinbeckers.nl"
#property strict

#include <Patterns\IPatternDetector.mqh>;
class CBasePatternDetector : public IPatternDetector
{
protected:   
   int    _period;
   string _symbol;
   
   //+------------------------------------------------------------------+
   bool IsUp(int bar)
   {
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
     return iClose(_symbol, m_period, bar) >= iOpen(_symbol, m_period, bar);
   }
   
   //+------------------------------------------------------------------+
   double UpperWick(int bar)
   {
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
     double upperBody = MathMax(iClose(_symbol, m_period, bar), iOpen(_symbol, m_period, bar));
      return iHigh(_symbol, m_period, bar) - upperBody;
   }
   
   //+------------------------------------------------------------------+
   double LowerWick(int bar)
   {
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
     
     double lowerBody = MathMin(iClose(_symbol, m_period, bar), iOpen(_symbol, m_period, bar));
      return lowerBody - iLow(_symbol, m_period, bar);
   }
   
   //+------------------------------------------------------------------+
   double GetCandleRangeSize(int bar)
   {
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
     return MathAbs(iHigh(_symbol, m_period, bar) - iLow(_symbol, m_period, bar));
   }
   
   //+------------------------------------------------------------------+
   double GetCandleBodySize(int bar)
   {
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
     return MathAbs(iClose(_symbol, m_period, bar) - iOpen(_symbol, m_period, bar));
   }
   
   
   //+------------------------------------------------------------------+
   int SpaceLeft(int bar)
   {
     double lowerWick = LowerWick(bar);
     double upperWick = UpperWick(bar);
     int cnt=0;
     
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
     
     for (int i=1; i < 20;++i)
     {
        if (upperWick > lowerWick)
        {
          if (iHigh(_symbol, m_period, bar+i) < iHigh(_symbol, m_period, bar)) cnt++;
          else break;
        }
        else
        {
          if (iLow(_symbol, m_period, bar+i) > iLow(_symbol, m_period, bar)) cnt++;
          else break;
        }
     }
     
     return cnt;
   }
   
   //+------------------------------------------------------------------+
   bool IsLargeCandle(int bar)
   {
      double body = GetCandleBodySize(bar);
      
      double cnt     = 0;
      double barSize = 0;
      for (int i=1; i < 100;++i)
      {
         barSize += GetCandleBodySize(bar+i);
         cnt++;
      }
      double avgBarSize = barSize / cnt;
      return (body >= avgBarSize);
   }
   
public: 
   //+------------------------------------------------------------------+
   CBasePatternDetector()
   {
   }
   
   //+------------------------------------------------------------------+
   virtual bool IsValid(string symbol, int period, int bar)
   {
      _symbol = symbol;
      _period = period;
      return false;
   }
   
   //+------------------------------------------------------------------+
   virtual string PatternName()
   {
      return "";
   }
   
   //+------------------------------------------------------------------+
   virtual color PatternColor()
   {
      return Yellow;
   }
   
   //+------------------------------------------------------------------+
   virtual bool IsBackground()
   {
      return false;
   }
   
   //+------------------------------------------------------------------+
   virtual int BarCount()
   {
      return 1;
   }
};