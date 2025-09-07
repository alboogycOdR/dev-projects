//+------------------------------------------------------------------+
//|                                     CTripplerReversalPattern.mqh |
//|                                    Copyright 2017, Erwin Beckers |
//|                                      https://www.erwinbeckers.nl |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Erwin Beckers"
#property link      "https://www.erwinbeckers.nl"
#property strict

#include <Patterns\CBasePatternDetector.mqh>;

class CTrippleReversalPattern : public CBasePatternDetector
{
private:
   int _pipsMargin;
   
public:
   //+------------------------------------------------------------------+
   CTrippleReversalPattern(int pipsMargin)
   {
      _pipsMargin = pipsMargin;
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
     
     
      
      double points   = SymbolInfoDouble(symbol,SYMBOL_POINT);//MarketInfo(_symbol, MODE_POINT);
      long digits   = SymbolInfoInteger(symbol,SYMBOL_DIGITS);//  MarketInfo(_symbol, MODE_DIGITS);
      
      bool isUp1 = IsUp(bar);
      bool isUp2 = IsUp(bar+1);
      bool isUp3 = IsUp(bar+2);
      if (isUp1 == isUp2 && isUp2 != isUp3)
      {
         double mult = 1;
         if (digits ==3 || digits==5) mult = 10;
         double pips = _pipsMargin * mult * points;
         
         if (isUp3)
         {
            if ( iLow(_symbol, m_period, bar) < iLow(_symbol, m_period, bar+2) && iHigh(_symbol, m_period, bar+1) + pips > iHigh(_symbol, m_period, bar+2)) return true;
         }
         else
         {
            if ( iHigh(_symbol, m_period, bar)  > iHigh(_symbol, m_period, bar+2) && iLow(_symbol, m_period, bar) - pips < iLow(_symbol, m_period, bar+2)) return true;
         }
      }
      return false;
   }
   
   //+------------------------------------------------------------------+
   string PatternName()
   {
      return "Double Reversal";
   }
};

