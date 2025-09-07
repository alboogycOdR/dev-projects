//+------------------------------------------------------------------+
//|                                          True Strength Index.mq5 |
//|                        Copyright 2009, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "2009, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "2.00"
#property indicator_separate_window
#property indicator_buffers 7
#property indicator_plots   1
//#property indicator_applied_price PRICE_TYPICAL
//--- подключим функции усреднения из файла MovingAverages.mqh
#include <MovingAverages.mqh>
//---- plot TSI
#property indicator_label1  "TSI"
#property indicator_type1   DRAW_LINE
#property indicator_color1  Blue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
//--- input parameters
input int      r=25;
input int      s=13;
//--- indicator buffers
double         TSIBuffer[];
double         MTMBuffer[];
double         AbsMTMBuffer[];
double         EMA_MTMBuffer[];
double         EMA2_MTMBuffer[];
double         EMA_AbsMTMBuffer[];
double         EMA2_AbsMTMBuffer[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,TSIBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,MTMBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(2,AbsMTMBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(3,EMA_MTMBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(4,EMA2_MTMBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(5,EMA_AbsMTMBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(6,EMA2_AbsMTMBuffer,INDICATOR_CALCULATIONS);
//--- с какого бара начнет отрисовываться индикатор
   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,r+s-1);
   string shortname;
   StringConcatenate(shortname,"TSI(",r,",",s,")");
//--- установим метку для отображения в DataWindow
   PlotIndexSetString(0,PLOT_LABEL,shortname);   
//--- установим имя для показа в отдельном подокне и во всплывающей подсказке
   IndicatorSetString(INDICATOR_SHORTNAME,shortname);
//--- укажем точность отображения значений индикатора
   IndicatorSetInteger(INDICATOR_DIGITS,2);
//---
   return(0);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate (const int rates_total,    // размер массива price[];
                 const int prev_calculated,// количество доступных баров ;
                 // на предыдущем вызове;
                 const int begin,// с какого индекса в массиве 
                 // price[] начинаются достоверные данные;
                 const double &price[]) // массив, по которому и будет считаться индикатор;
  {
//--- если размер массива price[] слишком мал
  if(rates_total<r+s) return(0); // ничего не считаем и ничего не рисуем на графике
//--- если это первый вызов 
   if(prev_calculated==0)
     {
      //--- для нулевых индексов установим нулевые значения
      MTMBuffer[0]=0.0;
      AbsMTMBuffer[0]=0.0;
     }

//--- рассчитать значения mtm и |mtm|
   int start;
   if(prev_calculated==0) start=1;  // начнем заполнять MTMBuffer[] и AbsMTMBuffer[]  с 1-го индекса 
   else start=prev_calculated-1;    // установим start равным последнему индексу в массивах 
   for(int i=start;i<rates_total;i++)
     {
      MTMBuffer[i]=price[i]-price[i-1];
      AbsMTMBuffer[i]=fabs(MTMBuffer[i]);
     }

//--- рассчитаем первую скользящую среднюю на массивах
   ExponentialMAOnBuffer(rates_total,prev_calculated,
                         1,     // с какого индекса есть значения в массиве для сглаживания 
                         r,     // период экспроненциальной средней
                         MTMBuffer,       // буфер для взятия средней
                         EMA_MTMBuffer);  // в этот буфер помещаем значения средней
   ExponentialMAOnBuffer(rates_total,prev_calculated,
                         1,r,AbsMTMBuffer,EMA_AbsMTMBuffer);

//--- рассчитаем вторую скользящую среднюю на массивах
   ExponentialMAOnBuffer(rates_total,prev_calculated,
                         r,s,EMA_MTMBuffer,EMA2_MTMBuffer);
   ExponentialMAOnBuffer(rates_total,prev_calculated,
                         r,s,EMA_AbsMTMBuffer,EMA2_AbsMTMBuffer);

//--- теперь вычислим значения индикатора
   if(prev_calculated==0) start=r+s-1; // установим начальный индекс для входных массивов
   else start=prev_calculated-1;    // установим start равным последнему индексу в массивах 
   for(int i=start;i<rates_total;i++)
     {
      TSIBuffer[i]=100*EMA2_MTMBuffer[i]/EMA2_AbsMTMBuffer[i];
     }
//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
