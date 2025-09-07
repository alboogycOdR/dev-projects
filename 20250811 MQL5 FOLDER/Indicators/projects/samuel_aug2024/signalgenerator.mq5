//+------------------------------------------------------------------+
//|                                              signalgenerator.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade/Trade.mqh>

input group "Trading Inputs"
input double Lots = 0.1;
input double TpDist = 0.001;
input double SlDist = 0.005;

input group "Indicator Inputs"
input ENUM_TIMEFRAMES StochTimeframe = PERIOD_H1;
input int StochK = 60;
input int StochD = 1;
input int StochSlowing = 1;
input double StochUpperLevel = 90;
input double StochLowerLevel = 10;

input bool IsMaFilterActive = true;
input ENUM_TIMEFRAMES MaTimeframe = PERIOD_CURRENT;
input int MaPeriod = 10; 
input ENUM_MA_METHOD MaMethod = MODE_EMA;

int handleStoch;
int handleMa;

int totalBars;

CTrade trade;
#define rsiInstances 2
double workRsi[][rsiInstances*3];
#define _price  0
#define _change 1
#define _changa 2


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   handleStoch = iStochastic(_Symbol,StochTimeframe,StochK,StochD,StochSlowing,MODE_SMA,STO_LOWHIGH);
   handleMa = iMA(_Symbol,MaTimeframe,MaPeriod,0,MaMethod,handleStoch);

   ChartIndicatorAdd(0,1,handleStoch);
   //ChartIndicatorAdd(0,1,handleMa);
   return(INIT_SUCCEEDED);
 
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   int bars = iBars(_Symbol,StochTimeframe);
   if(totalBars != bars){
      totalBars = bars;

      double stoch[];
      CopyBuffer(handleStoch,MAIN_LINE,1,2,stoch);
      
      double ma[];
      CopyBuffer(handleMa,MAIN_LINE,1,1,ma);
      
      double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID); 
      double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK); 
   
   //stoch[0] > StochUpperLevel
   Print("moving avg level:  "+NormalizeDouble(ma[0],Digits()));
   
//      if(stoch[1] < StochUpperLevel && stoch[0] > StochUpperLevel){
//         if(!IsMaFilterActive || bid < ma[0]){
//            trade.Sell(Lots,_Symbol,bid,bid+SlDist,bid-TpDist);
//         }
//         
//         
//         
//      }else if(stoch[1] > StochLowerLevel && stoch[0] < StochLowerLevel){
//         if(!IsMaFilterActive || bid > ma[0]){
//            trade.Buy(Lots,_Symbol,ask,ask-SlDist,ask+TpDist);
//         }
//      }
   }
   
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------
//#property copyright   "mladen"
//#property link        "mladenfx@gmail.com"
//#property description "RSI with RSI"
////+------------------------------------------------------------------
//#property indicator_chart_window
//#property indicator_buffers 6
//#property indicator_plots   4
//#property indicator_label1  "Signal up"
//#property indicator_type1   DRAW_ARROW
//#property indicator_color1  clrDeepSkyBlue
//#property indicator_width1  2
//#property indicator_label2  "Signal up 2"
//#property indicator_type2   DRAW_ARROW
//#property indicator_color2  clrDeepSkyBlue
//#property indicator_width2  2
//#property indicator_label3  "Signal down"
//#property indicator_type3   DRAW_ARROW
//#property indicator_color3  clrSandyBrown
//#property indicator_width3  2
//#property indicator_label4  "Signal down 2"
//#property indicator_type4   DRAW_ARROW
//#property indicator_color4  clrSandyBrown
//#property indicator_width4  2
//
////--- input parameters
//input int                inpRsiPeriodShort  =  5;          // RSI short period
//input int                inpRsiPeriodLong   = 17;          // RSI long period
//input double             inpRsiLevelUp      = 60;          // RSI level up
//input double             inpRsiLevelDown    = 40;          // RSI level down
//input int                inpMaPeriodShort   = 10;          // Short MA period 
//input int                inpMaPeriodLong    = 40;          // Long MA period 
//input ENUM_APPLIED_PRICE inpPrice           = PRICE_CLOSE; // Price 
////--- buffers declarations
//double arru1[],arru2[],arrd1[],arrd2[],trend1[],trend2[];
////+------------------------------------------------------------------+
////| Custom indicator initialization function                         |
////+------------------------------------------------------------------+
//int OnInit()
//  {
////--- indicator buffers mapping
//   SetIndexBuffer(0,arru1,INDICATOR_DATA); PlotIndexSetInteger(0,PLOT_ARROW,159);
//   SetIndexBuffer(1,arru2,INDICATOR_DATA); PlotIndexSetInteger(1,PLOT_ARROW,251);
//   SetIndexBuffer(2,arrd1,INDICATOR_DATA); PlotIndexSetInteger(2,PLOT_ARROW,159);
//   SetIndexBuffer(3,arrd2,INDICATOR_DATA); PlotIndexSetInteger(3,PLOT_ARROW,251);
//   SetIndexBuffer(4,trend1,INDICATOR_CALCULATIONS);
//   SetIndexBuffer(5,trend2,INDICATOR_CALCULATIONS);
////---
//   return (INIT_SUCCEEDED);
//  }
////+------------------------------------------------------------------+
////| Custom indicator de-initialization function                      |
////+------------------------------------------------------------------+
//void OnDeinit(const int reason)
//  {
//  }
////+------------------------------------------------------------------+
////| Custom indicator iteration function                              |
////+------------------------------------------------------------------+
//int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],
//                const double &open[],
//                const double &high[],
//                const double &low[],
//                const double &close[],
//                const long &tick_volume[],
//                const long &volume[],
//                const int &spread[])
//  {
//   if(Bars(_Symbol,_Period)<rates_total) return(prev_calculated);
//   int i=(int)MathMax(prev_calculated-1,1); for(; i<rates_total && !_StopFlag; i++)
//     {
//      double range    = 0; for (int k=0; k<10 && (i-k-1)>=0; k++) range += MathMax(high[i-k],close[i-k-1])-MathMin(low[i-k],close[i-k-1]); range /=10;
//      double price    = getPrice(inpPrice,open,close,high,low,i,rates_total);
//      double rsiShort = iRsi(price,inpRsiPeriodShort,i,rates_total,0);
//      double rsiLong  = iRsi(price,inpRsiPeriodLong,i,rates_total,1);
//      double maShort  = iSma(price,inpMaPeriodShort,i,rates_total,0);
//      double maLong   = iSma(price,inpMaPeriodLong,i,rates_total,1);
//      
//      //
//      //
//      //
//      //
//      //
//      
//         trend1[i] = (rsiShort>inpRsiLevelUp) ? 1 : (rsiShort<inpRsiLevelDown) ? -1 : (i>0) ? trend1[i-1] : 0; 
//         trend2[i] = (rsiLong >inpRsiLevelUp) ? 1 : (rsiLong <inpRsiLevelDown) ? -1 : (i>0) ? trend2[i-1] : 0; 
//
//      //
//      //
//      //
//      //
//      //
//      
//         arru1[i] = (i>0) ? (trend1[i]!=trend1[i-1] && trend1[i]== 1 && price > maShort && trend2[i] == -1) ? low[i] -range     : EMPTY_VALUE : EMPTY_VALUE;
//         arru2[i] = (i>0) ? (trend2[i]!=trend2[i-1] && trend2[i]== 1 && price > maLong)                     ? low[i] -range*2.0 : EMPTY_VALUE : EMPTY_VALUE;
//         arrd1[i] = (i>0) ? (trend1[i]!=trend1[i-1] && trend1[i]==-1 && price < maShort && trend2[i] ==  1) ? high[i]+range     : EMPTY_VALUE : EMPTY_VALUE;
//         arrd2[i] = (i>0) ? (trend2[i]!=trend2[i-1] && trend2[i]==-1 && price < maLong)                     ? high[i]+range*2.0 : EMPTY_VALUE : EMPTY_VALUE;
//     }
//   return (i);
//  }
////+------------------------------------------------------------------+
////| Custom functions                                                 |
////+------------------------------------------------------------------+
//
//
//double iRsi(double price,double period,int r,int bars,int instanceNo=0)
//  {
//   if(ArrayRange(workRsi,0)!=bars) ArrayResize(workRsi,bars);
//   int z=instanceNo*3;
//   workRsi[r][z+_price]=price;
//   double alpha=1.0/MathMax(period,1);
//   if(r<period)
//     {
//      int k; double sum=0; for(k=0; k<period && (r-k-1)>=0; k++) sum+=MathAbs(workRsi[r-k][z+_price]-workRsi[r-k-1][z+_price]);
//      workRsi[r][z+_change] = (workRsi[r][z+_price]-workRsi[0][z+_price])/MathMax(k,1);
//      workRsi[r][z+_changa] =                                         sum/MathMax(k,1);
//     }
//   else
//     {
//      double change=workRsi[r][z+_price]-workRsi[r-1][z+_price];
//      workRsi[r][z+_change] = workRsi[r-1][z+_change] + alpha*(        change  - workRsi[r-1][z+_change]);
//      workRsi[r][z+_changa] = workRsi[r-1][z+_changa] + alpha*(MathAbs(change) - workRsi[r-1][z+_changa]);
//     }
//   return(50.0*(workRsi[r][z+_change]/MathMax(workRsi[r][z+_changa],DBL_MIN)+1));
//  }
//
//double workSma[][2];
//double iSma(double price, int period, int r, int _bars, int instanceNo=0)
//{
//   if (ArrayRange(workSma,0)!= _bars) ArrayResize(workSma,_bars);
//
//   workSma[r][instanceNo+0] = price;
//   double avg = price; int k=1;  for(; k<period && (r-k)>=0; k++) avg += workSma[r-k][instanceNo+0];  
//   return(avg/(double)k);
//}
////
////---
////
//double getPrice(ENUM_APPLIED_PRICE tprice,const double &open[],const double &close[],const double &high[],const double &low[],int i,int _bars)
//  {
//   switch(tprice)
//     {
//      case PRICE_CLOSE:     return(close[i]);
//      case PRICE_OPEN:      return(open[i]);
//      case PRICE_HIGH:      return(high[i]);
//      case PRICE_LOW:       return(low[i]);
//      case PRICE_MEDIAN:    return((high[i]+low[i])/2.0);
//      case PRICE_TYPICAL:   return((high[i]+low[i]+close[i])/3.0);
//      case PRICE_WEIGHTED:  return((high[i]+low[i]+close[i]+close[i])/4.0);
//     }
//   return(0);
//  }
////+------------------------------------------------------------------+
