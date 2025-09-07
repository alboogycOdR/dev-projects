//+------------------------------------------------------------------+
//|                                                     SRFilter.mqh |
//|                                    Copyright 2017, Erwin Beckers |
//|                                      https://www.erwinbeckers.nl |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Erwin Beckers"
#property link      "https://www.erwinbeckers.nl"
#property strict


#include <Patterns\CBasePatternDetector.mqh>;

class CSRFilter : public CBasePatternDetector
{
private:
   double _pips;
   
public:
   //+------------------------------------------------------------------+
   CSRFilter(int pips)
   {
      _pips = pips;
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
     
     
      
      // chart objects only work for current chart
      if (Symbol() != _symbol) return true;
      
     double points   = SymbolInfoDouble(symbol,SYMBOL_POINT);//MarketInfo(_symbol, MODE_POINT);
      long digits   = SymbolInfoInteger(symbol,SYMBOL_DIGITS);//  MarketInfo(_symbol, MODE_DIGITS);

      
      double mult = 1;
      if (digits ==3 || digits==5) mult = 10;
      double pips = _pips * mult * points;
      
      for (int i=0;i < ObjectsTotal(0, 0, -1); i++)
      {
         string name  = ObjectName(0, i); 
         
         
         if (ObjectGetInteger(0,name,OBJPROP_TYPE)==OBJ_HLINE )  //new      
         //if (ObjectType(name) == OBJ_HLINE)
         {
            double srPrice = ObjectGetDouble(0, name, OBJPROP_PRICE,0); 
            
            if (iLow(_symbol, m_period, bar) - pips <= srPrice)
            {
              if (iHigh(_symbol, m_period, bar) + pips  >= srPrice) return true;
            }
            if (iHigh(_symbol, m_period, bar) + pips >= srPrice)
            {
              if (iLow(_symbol, m_period, bar) - pips  <= srPrice) return true;
            }
         }
         else if (ObjectGetInteger(0,name,OBJPROP_TYPE)==OBJ_TREND )  //new 
         //else if (ObjectType(name) == OBJ_TREND)
         {
            //datetime time1  = (datetime)ObjectGet(name, OBJPROP_TIME1); 
            //datetime time2  = (datetime)ObjectGet(name, OBJPROP_TIME2); 
            //    REPLACED WITH 
            datetime time1=(int)ObjectGetInteger(0,name,OBJPROP_TIME,0);
            datetime time2=(int)ObjectGetInteger(0,name,OBJPROP_TIME,1);
            
            if (time1 > time2)
            {
               datetime dum = time1;
               time1 = time2;
               time2 = dum;
            }
            if (iTime(_symbol, m_period, bar) > time1 && iTime(_symbol, m_period, bar) <= time2)
            {
               //double priceAtTrendline = ObjectGetValueByShift(name, bar);
               double priceAtTrendline =ObjectGetValueByTime(0,name,bar); // NEW   SUSPECT
               
               if (iLow(_symbol, m_period, bar) < priceAtTrendline && iHigh(_symbol, m_period, bar) >= priceAtTrendline)
               {  
                  return true;
               }
            }
         } 
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   string PatternName()
   {
      return "SR Cross";
   }
};

