//+------------------------------------------------------------------+
//|                                                  BreakOutBox.mq5 |
//|                        Copyright 2013, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2013, PH"
#property link      "https://login.mql5.com/en/users/Candles"
#property version   "1.00"
#property description "A simple indicator that draws rectangles"
#property description "around areas of ranging market i.e. when"
#property description "market makes no significant move up or down"
#property description "during a certain time period. User can define"
#property description "ranging market by specifying box height and"
#property description "box length. BoxHeight=minimum price range(in points)"
#property description "BoxLength=minimum time required for market to be"
#property description "rangin. For example to quickly see how often price"
#property description "moves less than 30 points in 10 or more bars set"
#property description "BoxHeight=30 and BoxLength=10."
#property indicator_chart_window

input int BoxHeight=30,BoxLength=10;

bool break_out_box=false,break_out_up=false,break_out_down=false;
datetime box_start,box_end;
double highest,lowest,range,box_high,box_low;
int range_time,bars=Bars(_Symbol,_Period);
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping

//---
   return(0);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
//---
   highest=high[0];
   lowest=low[0];
   for(int i=1;i<rates_total;i++)
     {
      if(high[i]>highest)highest=high[i];
      if(low[i]<lowest)lowest=low[i];
      range=highest-lowest;
      range_time++;
      if(range<BoxHeight*_Point*10 && range_time>=BoxLength)
        {
         break_out_box=true;
         box_high=highest;
         box_low=lowest;
         box_start=time[MathAbs(i-range_time)];
        }
      else if(range>BoxHeight*_Point*10 && range_time>=BoxLength && break_out_box==true && box_high<highest)
        {
         break_out_up=true;
         break_out_down=false;
         break_out_box=false;
         box_end=time[i-1];
         ObjectCreate(0,"Box "+i,OBJ_RECTANGLE,0,box_start,box_high,box_end,box_low);
         range=0;
         range_time=0;
        }
      else if(range>BoxHeight*_Point*10 && range_time>=BoxLength && break_out_box==true && box_low>lowest)
        {
         break_out_down=true;
         break_out_up=false;
         break_out_box=false;
         box_end=time[i-1];
         ObjectCreate(0,"Box "+i,OBJ_RECTANGLE,0,box_start,box_high,box_end,box_low);
         range=0;
         range_time=0;
        }
      else if(range>BoxHeight*_Point*10 && range_time<=BoxLength)
        {
         range=0;
         range_time=0;
         highest=high[i];
         lowest=low[i];
        }
     }
//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0,-1,OBJ_RECTANGLE);
  }
//+------------------------------------------------------------------+
