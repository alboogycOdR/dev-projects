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
datetime lastTime = 0;


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
   int limit = rates_total - prev_calculated;
   limit = MathMin(limit, rates_total - Depth * 2 - 1);
   for(int i = limit; i > 0; i --)
     {
      highs[i] = EMPTY_VALUE;
      lows[i] = EMPTY_VALUE;
      if(i + Depth == ArrayMaximum(high,i, Depth * 2))
        {
         //optimize
         //check if this high is higher than the prev high
         if(lastDirection > 0)
           {
            int index = iBarShift(_Symbol,PERIOD_CURRENT,lastTime);
            if(high[index] < high[i + Depth])
               highs[index] = EMPTY_VALUE;//delete the last high if the current is higher
            else
               continue;
           }
         highs[i + Depth] = high[i + Depth];
         lastDirection = 1;
         lastTime = time[i + Depth];
        }
      if(i + Depth == ArrayMinimum(low, i, Depth * 2))
        {
         if(lastDirection < 0)
           {
            int index = iBarShift(_Symbol,PERIOD_CURRENT,lastTime);
            if(low[index] > low[i + Depth])
               lows[index] = EMPTY_VALUE;//delete the last low if the current is lower
            else
               continue;
           }
         lows[i + Depth] = low[i + Depth];
               lastDirection = -1;
         lastTime = time[i + Depth];
        }
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
