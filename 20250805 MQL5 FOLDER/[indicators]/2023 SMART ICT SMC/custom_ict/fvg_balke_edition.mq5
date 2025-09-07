//+------------------------------------------------------------------+
//|                                            fvg_balke_edition.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property indicator_chart_window

//optional part - can be removed
#property indicator_buffers 2
#property indicator_plots 2
#property indicator_label1 "FVG HIGH"
#property indicator_label2 "FVG LOW"
//--end optional part

#include <arrays/arrayobj.mqh>


//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+


input int FvgMinPoints = 10;
input int FvgMaxPoints = 200;

input int FvgMaxLength = 20;


enum ENUM_FVG_TYPE
  {
   FVG_UP,
   FVG_DN
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CFairValueGap: public CObject
  {
public:
   ENUM_FVG_TYPE     type;
   datetime          time;
   double            high;
   double            low;
   void              draw(datetime time2)
     {
      string objName = "fvg " + TimeToString(time);
      if(ObjectFind(0,objName) < 0)
        {
         ObjectCreate(0, objName, OBJ_RECTANGLE, 0, time,high, time2, low);
         ObjectSetInteger(0, objName, OBJPROP_FILL, true);
         ObjectSetInteger(0,objName,OBJPROP_COLOR, (type == FVG_UP ? clrLightBlue : clrOrange));
        }
      ObjectSetInteger(0,objName,OBJPROP_TIME,1,time2);
     }
  };


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CArrayObj gaps; //use this to store all the fair value gaps
double fvgHigh[],fvgLow[];


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0,fvgHigh,INDICATOR_DATA);
   SetIndexBuffer(1,fvgLow,INDICATOR_DATA);
   ArraySetAsSeries(fvgHigh,true);
   ArraySetAsSeries(fvgLow,true);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   int limit = rates_total - prev_calculated;
   
   if(limit > rates_total - 2)
      limit = rates_total - 3;
      
   for(int i = limit; i >= 1; i--)
     {
      //bool isFvgUp = high[i + 2] < low[i];
      //bool isFvgDn = low[i + 2] > high[i];
      bool isFvgUp = (
                        (low[i] - high[i + 2]) > FvgMinPoints * _Point// &&
                        //(low[i] - high[i + 2]) < FvgMaxPoints * _Point
                     );
      bool isFvgDn = (
                        (low[i + 2] - high[i]) > FvgMinPoints * _Point
                        //&&
                        //(low[i + 2 ] - high[i]) < FvgMaxPoints * _Point
                     );
      if(isFvgUp || isFvgDn)
        {
         CFairValueGap* fvg = new CFairValueGap();
         fvg.type = isFvgUp ? FVG_UP : FVG_DN;
         fvg.time = time[i];
         fvg.high = isFvgUp ? low[i] : low[i + 2];
         fvg.low = isFvgUp ? high[i + 2] : high[i];
         //fvg.draw(time[i] + PeriodSeconds(PERIOD_CURRENT) * FvgMaxLength);
         gaps.Add(fvg);
         fvgHigh[i + 1] = fvg.high;
         fvgLow[i + 1] = fvg.low;
        }
      for(int j = gaps.Total() - 1; j >= 0; j--)
        {
         CFairValueGap* fvg = gaps.At(j);
         if(time[i] > fvg.time + PeriodSeconds(PERIOD_CURRENT) * FvgMaxLength)
            gaps.Delete(j);
         else
            if(fvg.type == FVG_UP && low[i] <= fvg.low)
               gaps.Delete(j);
            else
               if(fvg.type == FVG_DN && high[i] >= fvg.high)
                  gaps.Delete(j);
               else
                  fvg.draw(time[i]);
        }
     }
   return(rates_total);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0,"fvg");
  }
//+------------------------------------------------------------------+
