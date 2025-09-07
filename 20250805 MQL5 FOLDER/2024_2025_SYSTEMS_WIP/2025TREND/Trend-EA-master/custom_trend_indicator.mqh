//+------------------------------------------------------------------+
//|                                       custom_trend_indicator.mqh |
//|                        Copyright 2019, MetaQuotes Software Corp. |
//|                                               drenjanind@mail.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019, MetaQuotes Software Corp."
#property link      "drenjanind@mail.ru"
#property version   "1.00"
#property indicator_chart_window

#property indicator_buffers 2
#property indicator_plots   2

#property indicator_type1 DRAW_ARROW
#property indicator_type2 DRAW_ARROW

#property indicator_color1 clrGreen
#property indicator_color2 clrRed

double buff_up[];
double buff_down[];

int ArrowShift = -30;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, buff_up, INDICATOR_DATA);
   SetIndexBuffer(1, buff_down, INDICATOR_DATA);
   
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   
   PlotIndexSetInteger(0, PLOT_ARROW, 71);
   PlotIndexSetInteger(1, PLOT_ARROW, 72);
   
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, ArrowShift);
   PlotIndexSetInteger(1, PLOT_ARROW_SHIFT, -ArrowShift);
   
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   return(INIT_SUCCEEDED);
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

   int i, limit;
   
   if (rates_total < 5)
   return(0);
   
   if (prev_calculated < 7){
      limit =2;
      ArrayInitialize(buff_down, EMPTY_VALUE);
      ArrayInitialize(buff_up, EMPTY_VALUE);}
   else limit = rates_total - 5;
   
   for (i = limit; i < rates_total - 3; i++){
         if (close[i] > close[i+2] && close[i] > close[i+3] && close[i] >= close[i-1] && close[i] >+ close[i-2])
            buff_up[i] = close[i];
         else buff_up[i]= EMPTY_VALUE;

   if (close[i] < close[i+2] && close[i] < close[i+3] && close[i] <= close[i-1] && close[i] <= close[i-2])
         buff_down[i] = close[i];
   else buff_down[i]= EMPTY_VALUE;
   }
   return(rates_total);
}
//+------------------------------------------------------------------+