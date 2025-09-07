//+------------------------------------------------------------------+
//|                                          True Strength Index.mq5 |
//|                        Copyright 2010, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "2010, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "3.00"
#property indicator_separate_window
#property indicator_buffers 7
#property indicator_plots   1
//https://www.mql5.com/en/articles/15


//#property indicator_applied_price PRICE_TYPICAL
//--- include averaging functions from the MovingAverages.mqh file
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
//--- bar, starting from which the indicator is drawn
   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,r+s-1);
   string shortname;
   StringConcatenate(shortname,"TSI(",r,",",s,")");
//--- set a label do display in DataWindow
   PlotIndexSetString(0,PLOT_LABEL,shortname);
//--- set empty undisplayed value for zeroth graphical plot
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,EMPTY_VALUE);   
//--- set a name to show in a separate sub-window or a pop-up help
   IndicatorSetString(INDICATOR_SHORTNAME,shortname);
//--- set accuracy of displaying the indicator values
   IndicatorSetInteger(INDICATOR_DIGITS,2);
//---
   return(0);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate (const int rates_total,    // size of the price[] array;
                 const int prev_calculated,// number of available bars;
                 // at the previous call;
                 const int begin,// from what index of the 
                 // price[] array true data start;
                 const double &price[]) // array, at which the indicator will be calculated;
  {
//--- flag for single output of price[] values
   static bool printed=false;
//--- if begin isn't zero, then there are some values that we shouldn't take into account
   if(begin>0 && !printed)
     {
      //--- let's output them
      Print("Data for calculation begin from index equal to ",begin,
            "   price[] array length =",rates_total);

      //--- let's show the values that we shouldn't take into account for calculation
      for(int i=0;i<=begin;i++)
        {
         Print("i =",i,"  value =",price[i]);
        }
      //--- set printed flag to confirm that we have already logged the values
      printed=true;
     }
//--- if the size of price[] is too small
   if(rates_total<r+s) return(0); // do not calculate or draw anything
//--- if it's the first call
   if(prev_calculated==0)
     {
      //--- initialize indicator buffers with EMPTY_VALUE
      ArrayInitialize(TSIBuffer,EMPTY_VALUE);
      ArrayInitialize(MTMBuffer,EMPTY_VALUE);
      ArrayInitialize(AbsMTMBuffer,EMPTY_VALUE);
      ArrayInitialize(EMA_MTMBuffer,EMPTY_VALUE);
      ArrayInitialize(EMA2_MTMBuffer,EMPTY_VALUE);
      ArrayInitialize(EMA_AbsMTMBuffer,EMPTY_VALUE);
      ArrayInitialize(EMA2_AbsMTMBuffer,EMPTY_VALUE);
      //--- set zero values for zero indexes
      MTMBuffer[0]=0.0;
      AbsMTMBuffer[0]=0.0;
     }

//--- calculate values of mtm and |mtm|
   int start;
   if(prev_calculated==0) start=begin+1;  // start filling out MTMBuffer[] and AbsMTMBuffer[] from the 1st index
   else start=prev_calculated-1;          // set start equal to the last index in the arrays
   for(int i=start;i<rates_total;i++)
     {
      MTMBuffer[i]=price[i]-price[i-1];
      AbsMTMBuffer[i]=fabs(MTMBuffer[i]);
     }

//--- calculate the first moving average on arrays
   ExponentialMAOnBuffer(rates_total,prev_calculated,
                         begin+1,// index, starting from which data for smoothing are available
                         r,      // period of the exponential average
                         MTMBuffer,       // buffer to calculate average
                         EMA_MTMBuffer);  // into this buffer locate value of the average
   ExponentialMAOnBuffer(rates_total,prev_calculated,
                         begin+1,r,AbsMTMBuffer,EMA_AbsMTMBuffer);

//--- calculate the second moving average on arrays
   ExponentialMAOnBuffer(rates_total,prev_calculated,
                         begin+r,s,EMA_MTMBuffer,EMA2_MTMBuffer);
   ExponentialMAOnBuffer(rates_total,prev_calculated,
                         begin+r,s,EMA_AbsMTMBuffer,EMA2_AbsMTMBuffer);

//--- now calculate the indicator values
   if(prev_calculated==0) start=begin+r+s-1; // set the starting index for input arrays
   else start=prev_calculated-1;             // set 'start' equal to the last index in the arrays
   for(int i=start;i<rates_total;i++)
     {
      TSIBuffer[i]=100*EMA2_MTMBuffer[i]/EMA2_AbsMTMBuffer[i];
     }
//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
