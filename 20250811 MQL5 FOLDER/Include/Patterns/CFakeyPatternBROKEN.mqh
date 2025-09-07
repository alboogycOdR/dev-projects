//+------------------------------------------------------------------+
//|                                                CFakeyPattern.mqh |
//|                                    Copyright 2017, Erwin Beckers |
//|                                      https://www.erwinbeckers.nl |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Erwin Beckers"
#property link      "https://www.erwinbeckers.nl"
#property strict

#include <Patterns\CBasePatternDetector.mqh>;

class CFakeyPattern : public CBasePatternDetector
{
private: 
   
public:
   //+------------------------------------------------------------------+
   CFakeyPattern()
   {
   }

   //+------------------------------------------------------------------+
   bool IsValid(string symbol,int period, int bar)
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
     
     
      if (IsPinBar(bar+2)) return false;
      
      if (IsPinBar(bar+1)) return false;
      
      if (IsInsideBar(bar+1))
      {
         if (IsPinBar(bar))
         {
            bool isUp2 = IsUp(bar+2);
            bool isUp1 = IsUp(bar+1);
            bool isUp0 = IsUp(bar);
            
            if (isUp2 != isUp1 && isUp0 == isUp2)
            {      
               if (iLow(_symbol, m_period, bar) < iLow(_symbol, m_period, bar+2)) 
               {
                  if (iHigh(_symbol, m_period, bar) < iHigh(_symbol, m_period, bar+1))
                  {
                     return true;
                  }
               }
               else if (iHigh(_symbol, m_period, bar) > iHigh(_symbol, m_period, bar+2))
               {
                  if (iLow(_symbol, m_period, bar) > iLow(_symbol, m_period, bar+1))
                  {
                     return true;
                  }
               }
            }  
          }
      }
      return false;
   }
   
   //+------------------------------------------------------------------+
   string PatternName()
   {
      return "Fakey pattern";
   }
};

