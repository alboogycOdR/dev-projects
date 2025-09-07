//+------------------------------------------------------------------+
//|                                           InterrogateICustom.mq5 |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }

//+------------------------------------------------------------------+
int timeFrame        = 0;        // Time frame to use: 0=current
int trendPeriod      = 4;        // Period of calculation
int trendMethod      = 1;        // Averaging type: 1=EMA
int priceMode        = 0;        // Price to use: 0=Close
double triggerUp     =  0.07;    // Trigger up level
double triggerDown   = -0.07;    // Trigger down level
double smoothLength  = 5;        // Smoothing length
double smoothPhase   = 0;        // Smoothing phase
//string indicator     = "isaac_Boom_Crash A Thousand Volts Signal";

//string indicator     = "pudis/staralt";
//string indicator     = "pudis/rsitrendspace";
input string indicator     = "LuxAlgo/LuxAlgo - BuysideSellsideLiquidity";
//string indicator     = "pudis/trend1000";


input int TRIGGER = 1; // tRIGGER CANDLE
int handle;

input int TRIGGERCANDLE = 1;


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   handle = iCustom(Symbol(), PERIOD_CURRENT, indicator);
//,500,true,true,
//                        80,10);//, timeFrame, trendPeriod, trendMethod, priceMode, triggerUp, triggerDown, smoothLength, smoothPhase);
   if(handle == INVALID_HANDLE)
     {
      Print("invalid handle error ", GetLastError());
      return INIT_FAILED;
     }
   else
     {
      Print("loaded ");
      TesterHideIndicators(false);
     }
   return INIT_SUCCEEDED;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isNewBar()
  {
//--- memorize the time of opening of the last bar in the static variable
   static datetime last_time = 0;
//--- current time
   datetime lastbar_time = (datetime)SeriesInfoInteger(Symbol(), Period(), SERIES_LASTBAR_DATE);

//--- if it is the first call of the function
   if(last_time == 0)
     {
      //--- set the time and exit
      last_time = lastbar_time;
      return(false);
     }

//--- if the time differs
   if(last_time != lastbar_time)
     {
      //--- memorize the time and return true
      last_time = lastbar_time;
      return(true);
     }
//--- if we passed to this line, then the bar is not new; return false
   return(false);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
//if(!isNewBar())
//  return;

   double buffer0[];
   double buffer1[];
   double buyBUFFER[];
   double sellBUFFER[];


   ArraySetAsSeries(buffer0, true);
   ArraySetAsSeries(buffer1, true);
   ArraySetAsSeries(buyBUFFER, true);
   ArraySetAsSeries(sellBUFFER, true);
//ArraySetAsSeries(buffer0,true);


   int shift = 0;
   int amount = TRIGGER + 1;
   int index;


   /*


            0


   */

   if(CopyBuffer(handle, index = 0, 0, 2, sellBUFFER) != 2)
     {Print("error_index_0 : ", GetLastError()); }
   if(sellBUFFER[0]!=EMPTY_VALUE)
      Print("INDEX 0  :" + NormalizeDouble(sellBUFFER[0],Digits()));

   /*


            1


   */
   if(CopyBuffer(handle, index = 1, 0, 2, buyBUFFER) != 2)
     {Print("error_index_1 : ", GetLastError()); }
   if(buyBUFFER[0]!=EMPTY_VALUE)
      Print("INDEX 1" + NormalizeDouble(buyBUFFER[0],Digits()));

   /*


            2


   */      double buff3[];
   ArraySetAsSeries(buff3, true);
   if(CopyBuffer(handle, index = 2, 0, 2, buff3) != amount)
     {
      Print("CopyBuffer error 2  ", GetLastError());
     }
   double trendbuff3 = buff3[0]; // current value of buffer 2 : TrendBuffer
   if(trendbuff3!=EMPTY_VALUE)
      Print("INDEX 2:" + trendbuff3);
   /*


            3


   */
   double buff4[];
   ArraySetAsSeries(buff4, true);
   if(CopyBuffer(handle, index = 3, 0, 2, buff4) != amount)
     {
      Print("CopyBuffer error 3  ", GetLastError());
     }
   double valbuff4 = buff4[0]; // current value of buffer 2 : TrendBuffer
   if(valbuff4!=EMPTY_VALUE)
      Print("INDEX 3:" + valbuff4);


   /*


            4


   */


   double buff5[];
   ArraySetAsSeries(buff5, true);
   if(CopyBuffer(handle, index = 4, 0, 2, buff5) != amount)
     {
      Print("CopyBuffer error 2  ", GetLastError());
     }
   double trendbuff5 = buff5[0];
   if(trendbuff5!=EMPTY_VALUE)
      Print("INDEX 4:" + trendbuff5);



   /*


            5


   */
   double buff6[];
   ArraySetAsSeries(buff6, true);
   if(CopyBuffer(handle, index = 5, 0, 2, buff6) != amount)
     {
      Print("CopyBuffer error 3  ", GetLastError());
     }
   double valbuff6 = buff6[1];
   if(valbuff6 != EMPTY_VALUE)
      Print("buff6 :" + valbuff6);

   double buff7[];
   ArraySetAsSeries(buff7, true);
   if(CopyBuffer(handle, index = 6, 0, 2, buff7) != amount)
     {
      Print("CopyBuffer error 2  ", GetLastError());
     }
   double trendbuff6 = buff7[1];
   if(trendbuff6 != EMPTY_VALUE)
      Print("buff7 :" + trendbuff6);

   double buff8[];
   ArraySetAsSeries(buff8, true);
   if(CopyBuffer(handle, index = 7, 0, 2, buff8) != amount)
     {
      Print("CopyBuffer error 3  ", GetLastError());
     }
   double valbuff8 = buff8[TRIGGER];
   if(valbuff8 != EMPTY_VALUE)
      Print("buff7 :" + valbuff8);

   double buff9[];
   ArraySetAsSeries(buff9, true);
   if(CopyBuffer(handle, index = 8, 0, amount, buff9) != amount)
     {
      Print("CopyBuffer error 3  ", GetLastError());
     }
   double valbuff9 = buff9[TRIGGER];
   if(valbuff8 != EMPTY_VALUE)
      Print("buff9 :" + valbuff9);





   Print("========================");
   if(isNewBar())
      Print("========================");

 

  }

//+------------------------------------------------------------------+
