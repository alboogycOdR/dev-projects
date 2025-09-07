//+------------------------------------------------------------------+
//|                                               TEST_INDICATOR.mq5 |
//|                                  Copyright 2021, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#resource "\\Indicators\\gann_hi_lo_activator_ssl.ex5"

int HiLoHandle =INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   HiLoHandle = iCustom(_Symbol, PERIOD_CURRENT, "::Indicators\\gann_hi_lo_activator_ssl", 4);
   if(HiLoHandle == INVALID_HANDLE)
     {
      Print("Error creating HiLo indicator");
      return false;
     }
//---
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
   double hiloBuffer[];
   if(isNewBar())
     {
      if(CopyBuffer(HiLoHandle,0,0,1,hiloBuffer)!=1)
        {
         Print("CopyBuffer from HiLo failed, no data  BUFFER [0]");
         return ;
        }
      else
        {
         Print("BUFFER [0] "+hiloBuffer[0]);
        }

      if(CopyBuffer(HiLoHandle,1,0,1,hiloBuffer)!=1)
        {
         Print("CopyBuffer from HiLo failed, no data  BUFFER [1]");
         return ;
        }
      else
        {
         Print("BUFFER [1] "+hiloBuffer[0]);
        }

      if(CopyBuffer(HiLoHandle,2,0,1,hiloBuffer)!=1)
        {
         Print("CopyBuffer from HiLo failed, no data  BUFFER [2]");
         return ;
        }
      else
        {
         Print("BUFFER [2] "+hiloBuffer[0]);
        }

      if(CopyBuffer(HiLoHandle,3,0,1,hiloBuffer)!=1)
        {
         Print("CopyBuffer from HiLo failed, no data  BUFFER [3]");
         return ;
        }
      else
        {
         Print("BUFFER [3] "+hiloBuffer[0]);
        }

      if(CopyBuffer(HiLoHandle,4,0,1,hiloBuffer)!=1)
        {
         Print("CopyBuffer from HiLo failed, no data  BUFFER [4]");
         return ;
        }
      else
        {
         Print("BUFFER [4] "+hiloBuffer[0]);
        }


     }
  }
//+------------------------------------------------------------------+
bool isNewBar()
  {
//Print("NEW BAR CHECK ROUTINE");
//--- memorize the time of opening of the last bar in the static variable
   static datetime last_time=0;
//--- current time
   datetime lastbar_time=(datetime)SeriesInfoInteger(Symbol(),Period(),SERIES_LASTBAR_DATE);

//--- if it is the first call of the function
   if(last_time==0)
     {
      //--- set the time and exit
      last_time=lastbar_time;
      return(false);
     }

//--- if the time differs
   if(last_time!=lastbar_time)
     {
      //--- memorize the time and return true
      last_time=lastbar_time;
      return(true);
     }
//--- if we passed to this line, then the bar is not new; return false
   return(false);
  }
//+------------------------------------------------------------------+
