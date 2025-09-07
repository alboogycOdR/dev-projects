//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots 2
#property indicator_label1 "High"
#property indicator_color1 clrGreen
#property indicator_style1 STYLE_SOLID
#property indicator_type1 DRAW_ARROW
#property indicator_label2 "Low"
#property indicator_color2 clrRed
#property indicator_style2 STYLE_SOLID
#property indicator_type2 DRAW_ARROW



input int Depth = 20;
double highs[], lows[];
int lastDirection = 0;
datetime lastTimeH = 0;
datetime lastTimeL = 0;
datetime PREVTimeH = 0;
datetime PREVTimeL = 0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
   SetIndexBuffer(0,highs, INDICATOR_DATA);
   SetIndexBuffer(1, lows, INDICATOR_DATA);
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT,-10);
   PlotIndexSetInteger(1, PLOT_ARROW_SHIFT,10);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0,"SMC");
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
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(close, true);
//----
   int limit = rates_total - prev_calculated;
   //Print("limit: " + limit);//100 038
   limit = MathMin(limit, rates_total - Depth * 2 - 1);
   //Print("limit2: " + limit);//99 997
//---
   for(int i = limit; i > 0; i --)
     {
      highs[i] = EMPTY_VALUE;
      lows[i] = EMPTY_VALUE;
      int index_last_high = iBarShift(_Symbol, PERIOD_CURRENT, lastTimeH);
      int index_last_low = iBarShift(_Symbol, PERIOD_CURRENT, lastTimeL);
      int index_prev_high = iBarShift(_Symbol, PERIOD_CURRENT, PREVTimeH);
      int index_prev_low = iBarShift(_Symbol, PERIOD_CURRENT, PREVTimeL);
      //Print("index_last_high: " + index_last_high);
      //Print("index_last_low: " + index_last_low);
      //Print("index_prev_high: " + index_prev_high);
      //Print("index_prev_low: " + index_prev_low);   
      //Print("lastTimeH: " + lastTimeH);
      //Print("lastTimeL: " + lastTimeL);
      //Print("PREVTimeH: " + PREVTimeH);
      //Print("PREVTimeL: " + PREVTimeL);
      //Print("__"+i);
       

      //
      if(index_last_high > 0 && index_last_low > 0 && index_prev_high > 0 && index_prev_low > 0)
        {
         if(high[index_last_high] > high[index_prev_high] && low[index_last_low] > low[index_prev_low])
           {
            if(close[i] > high[index_last_high])
              {
               string objName = "SMC BoS " + TimeToString(time[index_last_high]);
               if(ObjectFind(0,objName) < 0)
                 {
                  ObjectCreate(0,objName, OBJ_TREND, 0, time[index_last_high],high[index_last_high], time[i],high[index_last_high]);
                  ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);//InpLinesWidth);
                  ObjectSetInteger(0, objName, OBJPROP_COLOR, clrNavy);//clr);
                  ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
                 }
              }
           }
         if(high[index_last_high] < high[index_prev_high] && low[index_last_low] < low[index_prev_low])
           {
            if(close[i] < low[index_last_low])
              {
               string objName = "SMC BoS " + TimeToString(time[index_last_low]);
               if(ObjectFind(0,objName) < 0)
                 {
                  ObjectCreate(0,objName, OBJ_TREND, 0, time[index_last_low],low[index_last_low],time[i],low[index_last_low]);
                  ObjectSetInteger(0, objName, OBJPROP_WIDTH,1);// InpLinesWidth);
                  ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);//clr);
                  ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
                 }
              }
           }
         //=====


         //===
          if(i + Depth == ArrayMaximum(high,i, Depth * 2))
           {
            /*if(lastDirection > 0)
              {
               //Print("i: " + i);
               //Print("index_last_high: " + index_last_high);
               //Print("high_LAST HIGH: " + high[index_last_high]);
               //Print("HIGH I+DEPTH: " + high[i + Depth]);
               //Print("__");
               if(high[index_last_high] < high[i + Depth])
                  highs[index_last_high] = EMPTY_VALUE;//delete the last high if the current is higher
               else
                  continue;
              }
            highs[i + Depth] = high[i + Depth];
            lastDirection = 1;*/
            if(index_last_high == -1 || highs[index_last_high] != EMPTY_VALUE)
               PREVTimeH = lastTimeH;
            lastTimeH = time[i + Depth];
           }
         if(i + Depth == ArrayMinimum(low, i, Depth * 2))
           {
            /*if(lastDirection < 0)
              {
               //Print("i: " + i);
               //Print("index_last_low: " + index_last_low);
               //Print("low_LAST low: " + low[index_last_low]);
               //Print("low I+DEPTH: " + low[i + Depth]);
               //Print("__");

               //-----------

               if(low[index_last_low] > low[i + Depth])
                  lows[index_last_low] = EMPTY_VALUE;//delete the last low if the current is lower
               else
                  continue;
              }
            lows[i + Depth] = low[i + Depth];
            lastDirection = -1;*/
            if(index_last_low == -1 || lows[index_last_low] != EMPTY_VALUE)
               PREVTimeL = lastTimeL;
            lastTimeL = time[i + Depth];
           }
           
        }
     }//for loop
   return(rates_total);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
