//+------------------------------------------------------------------+
//| Pivot helper functions                                           |
//+------------------------------------------------------------------+
#ifndef __PIVOT_MQH
#define __PIVOT_MQH

#include <Trade/Trade.mqh>

// Check if a bar at shift is a pivot high
inline bool IsPivotHigh(int shift,int left,int right)
  {
   if(shift>=Bars(_Symbol,_Period)-right-1) return(false);
   double price=High[shift];
   for(int i=1;i<=left;i++)
      if(High[shift+i]>price)
         return(false);
   for(int i=1;i<=right;i++)
      if(High[shift-i]>=price)
         return(false);
   return(true);
  }

// Check if a bar at shift is a pivot low
inline bool IsPivotLow(int shift,int left,int right)
  {
   if(shift>=Bars(_Symbol,_Period)-right-1) return(false);
   double price=Low[shift];
   for(int i=1;i<=left;i++)
      if(Low[shift+i]<price)
         return(false);
   for(int i=1;i<=right;i++)
      if(Low[shift-i]<=price)
         return(false);
   return(true);
  }

// Find deepest pivot low below current close within lookback bars
inline double FindDeepestPivotLowBelowClose(int lookback,int left,int right)
  {
   double best=DBL_MAX;
   for(int shift=right; shift<=lookback+right && shift<Bars(_Symbol,_Period); shift++)
     {
      if(IsPivotLow(shift,left,right))
        {
         double val=Low[shift];
         if(val<Close[0] && val<best)
            best=val;
        }
     }
   return(best==DBL_MAX?EMPTY_VALUE:best);
  }

// Find highest pivot high above current close within lookback bars
inline double FindHighestPivotHighAboveClose(int lookback,int left,int right)
  {
   double best=-DBL_MAX;
   for(int shift=right; shift<=lookback+right && shift<Bars(_Symbol,_Period); shift++)
     {
      if(IsPivotHigh(shift,left,right))
        {
         double val=High[shift];
         if(val>Close[0] && val>best)
            best=val;
        }
     }
   return(best==-DBL_MAX?EMPTY_VALUE:best);
  }

// Helper for drawing zigzag lines
class PivotZigZag
  {
private:
   int     counter;
   datetime last_time;
   double  last_price;
   bool    draw;
public:
   void Init(bool enable)
     {
      counter=0;
      last_time=0;
      last_price=0;
      draw=enable;
     }
   void Enable(bool enable){draw=enable;}
   void AddPoint(datetime time,double price)
     {
      if(!draw) return;
      if(last_time!=0)
        {
         string name="zz_"+IntegerToString(counter++);
         ObjectCreate(0,name,OBJ_TREND,0,last_time,last_price,time,price);
         ObjectSetInteger(0,name,OBJPROP_COLOR,clrOrange);
        }
      last_time=time;
      last_price=price;
     }
  };

#endif //__PIVOT_MQH
//+------------------------------------------------------------------+
