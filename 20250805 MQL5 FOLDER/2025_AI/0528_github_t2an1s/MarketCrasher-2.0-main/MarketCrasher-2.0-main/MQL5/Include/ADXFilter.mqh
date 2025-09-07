//+------------------------------------------------------------------+
//| ADX filter helper                                                |
//+------------------------------------------------------------------+

#ifndef __ADX_FILTER_MQH__
#define __ADX_FILTER_MQH__

// calculate if ADX trend is strong enough
static bool ADXTrendOk(
      int adxPeriod,bool useDynamic,double staticThr,int lookback,
      double multiplier,double minThr)
  {
   double adx=iADX(_Symbol,_Period,adxPeriod,PRICE_CLOSE,MODE_MAIN,0);
   double avg=0.0;
   for(int i=0;i<lookback;i++)
      avg+=iADX(_Symbol,_Period,adxPeriod,PRICE_CLOSE,MODE_MAIN,i);
   avg/=lookback;
   double dynamicThr=MathMax(minThr,avg*multiplier);
   double thr=useDynamic?dynamicThr:staticThr;
   return(adx>thr);
  }

#endif //__ADX_FILTER_MQH__

