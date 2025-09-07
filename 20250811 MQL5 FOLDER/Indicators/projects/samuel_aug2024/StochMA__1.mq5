//+------------------------------------------------------------------+
//|                                                      StochMA.mq5 |
//|                                  Copyright 2021, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <MovingAverages.mqh>


#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   3
//--- plot Sell
#property indicator_label1  "Sell"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
//--- plot Buy
#property indicator_label2  "Buy"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrLimeGreen
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#property indicator_label3  "MA"
  #property indicator_type3   DRAW_LINE
  #property indicator_color3  clrGreen
  #property indicator_style3  STYLE_SOLID
  #property indicator_width3  1
  
//--- input parameters
input string                                   Stochastic;
input   int                 Kperiod            =60;
input   int                 Dperiod            =5;
input   int                 Slowing            =3;
input ENUM_MA_METHOD        StochMAMethod      =MODE_SMA;
input ENUM_STO_PRICE        PriceField         =0;

input   double              stohOverbought     =80;
input   double              stohOversold       =20;

input string                                   MovingAverage;
input int                   MA1Period          =10;
input int                   Mashift            =0;
input ENUM_MA_METHOD        MAMethod           =MODE_SMA;
input ENUM_APPLIED_PRICE    MAPrice            =PRICE_CLOSE;

//--- indicator buffers
double         SellBuffer[];
double         BuyBuffer[];
//---- declaration of the integer variables for the start of data calculation
int min_rates_total;
//----variable for storing the handle of the iSTOCHASTIC indicator
int Stochastic_Handle;
//----variable for storing the handle of the iMA indicator
int Ma1_Handle;
//----we will keep the number of values in the Stochastic Oscillator and the Moving Average
int bars_calculated=0;
//+----------------------------------------------+
//|  Declaration of constants                    |
//+----------------------------------------------+
#define RESET 0 // the constant for getting the command for the indicator recalculation back to the terminal
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
input int    InpMaPeriod = 9;   // SMA period for OBV
double ExtMAbuffer[];
int OnInit()
  {
//---- initialization of variables of the start of data calculation
   min_rates_total=((Kperiod+Dperiod+Slowing)*(MA1Period));

//--- indicator buffers mapping
   SetIndexBuffer(0,SellBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,BuyBuffer,INDICATOR_DATA);
   SetIndexBuffer(2,ExtMAbuffer,INDICATOR_DATA);
   
   
   
//--- setting a code from the Wingdings charset as the property of PLOT_ARROW
   PlotIndexSetInteger(0,PLOT_ARROW,233);
   PlotIndexSetInteger(1,PLOT_ARROW,234);
//--- set the vertical shift of arrows in pixels
   PlotIndexSetInteger(0,PLOT_ARROW_SHIFT,5);
   PlotIndexSetInteger(1,PLOT_ARROW_SHIFT,5);
//---- indexing elements in the buffer as time series
   ArraySetAsSeries(BuyBuffer,true);
   ArraySetAsSeries(SellBuffer,true);
   ArraySetAsSeries(ExtMAbuffer,true);
   
//---- Setting the format of accuracy of displaying the indicator
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
//--- create handle of the indicator iSTOCHASTIC
   Stochastic_Handle=iStochastic(Symbol(),Period(),Kperiod,Dperiod,Slowing,StochMAMethod,PriceField);
   if(Stochastic_Handle==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code
      PrintFormat("Failed to create handle of the iSTOCHASTIC indicator for the symbol %s/%s, error code %d",
                  Symbol(),
                  EnumToString(Period()),
                  GetLastError());
      //--- the indicator is stopped early
      return(INIT_FAILED);
     }
   ChartIndicatorAdd(0,1,Stochastic_Handle);
//--- create handle of the indicator iMA
   Ma1_Handle=iMA(Symbol(),Period(),MA1Period,Mashift,MAMethod,MAPrice);
   if(Ma1_Handle==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code
      PrintFormat("Failed to create handle of the iMA indicator for the symbol %s/%s, error code %d",
                  Symbol(),
                  EnumToString(Period()),
                  GetLastError());
      //--- the indicator is stopped early
      return(INIT_FAILED);
     }
   //ChartIndicatorAdd(0,1,Ma1_Handle);
//---- name for the data window and the label for sub-windows
   string short_name="StochMA";
   IndicatorSetString(INDICATOR_SHORTNAME,short_name);
//---
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
//---- checking the number of bars to be enough for calculation
   if(BarsCalculated(Stochastic_Handle)<rates_total
      || BarsCalculated(Ma1_Handle)<rates_total
      || rates_total<min_rates_total)
      return(RESET);
//---- declaration of local variables
   int to_copy,limit,bar;
   double range,Ma1[],stochastic[];
//---- indexing elements in arrays as timeseries
   ArraySetAsSeries(stochastic,true);
   ArraySetAsSeries(Ma1,true);
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
//---- calculations of the necessary amount of data to be copied and
//the starting number limit for the bar recalculation loop
   if(prev_calculated>rates_total || prev_calculated<=0)// checking for the first start of the indicator calculation
     {
      limit=rates_total-min_rates_total-1; // starting index for the calculation of all bars
     }
   else
     {
      limit=rates_total-prev_calculated; // starting index for the calculation of new bars
     }

   to_copy=limit+1;
//---- copy newly appeared data into the arrays
   if(CopyBuffer(Ma1_Handle,0,0,to_copy,Ma1)<=0)
      return(RESET);

   to_copy++;
//--- copy newly appeared data in the array
   if(CopyBuffer(Stochastic_Handle,0,0,to_copy,stochastic)<=0)
      return(RESET);


//--- calculate Signal
   SimpleMAOnBuffer(rates_total
   ,prev_calculated
      ,Kperiod
      ,InpMaPeriod //PERIOD
      ,stochastic//SOURCE BUFFER
      ,ExtMAbuffer//DEST BUFFER
      );





//---- main indicator calculation loop
   for(bar=limit; bar>=0 && !IsStopped(); bar--)
     {
      BuyBuffer[bar]=0.0;
      SellBuffer[bar]=0.0;

      range=0.0;
      for(int kkk=bar+9; kkk<=bar; kkk--)
         range+=MathAbs(high[kkk]-low[kkk]);
      range*=0.2/10.0;

      if(stochastic[bar]<stohOversold  && ExtMAbuffer[bar]<stohOversold && stochastic[bar]>ExtMAbuffer[bar])
         BuyBuffer[bar] = low[bar] - range;
      if(stochastic[bar]>stohOverbought && ExtMAbuffer[bar]>stohOverbought && stochastic[bar]<ExtMAbuffer[bar])
         SellBuffer[bar] = high[bar] + range;
     }
//---

//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
