//+------------------------------------------------------------------+

//| Synergy score calculation                                        |
//+------------------------------------------------------------------+
#ifndef __SYNERGY_MQH__
#define __SYNERGY_MQH__

#include <Indicators/Indicators.mqh>

// Structure to hold settings
struct SynergySettings
  {
   bool   useSynergy;
   double rsiWeight;
   double trendWeight;
   double macdSlopeWeight;
   bool   useTF5m;
   bool   useTF15m;
   bool   useTF1h;
   double weight5m;
   double weight15m;
   double weight1h;
  };

// Get indicator value helper
inline double GetIndicatorValue(int handle,int buffer)
  {
   double value[];
   if(CopyBuffer(handle,buffer,0,1,value)<=0)
      return(0.0);
   return(value[0]);
  }

// Calculate synergy score across multiple timeframes
inline double CalcSynergyScore(const SynergySettings &s)
  {
   double score=0.0;

   //--- helper lambda
   auto add=[&score](bool above,bool below,double factor,double timeFactor)
     {
      if(above) score+=factor*timeFactor;
      else if(below) score-=factor*timeFactor;
     };

   if(s.useTF5m)
     {
      int rsi=iRSI(_Symbol,PERIOD_M5,14,PRICE_CLOSE);
      int ema1=iMA(_Symbol,PERIOD_M5,10,0,MODE_EMA,PRICE_CLOSE);
      int ema2=iMA(_Symbol,PERIOD_M5,100,0,MODE_EMA,PRICE_CLOSE);
      int macd=iMACD(_Symbol,PERIOD_M5,12,26,9,PRICE_CLOSE);
      double rsiVal=GetIndicatorValue(rsi,0);
      double ma1Val=GetIndicatorValue(ema1,0);
      double ma2Val=GetIndicatorValue(ema2,0);
      double macdVal=GetIndicatorValue(macd,0);
      double macdPrev=GetIndicatorValue(macd,1);
      add(rsiVal>50.0,rsiVal<50.0,s.rsiWeight,s.weight5m);
      add(ma1Val>ma2Val,ma1Val<ma2Val,s.trendWeight,s.weight5m);
      add(macdVal>macdPrev,macdVal<macdPrev,s.macdSlopeWeight,s.weight5m);
      IndicatorRelease(rsi);
      IndicatorRelease(ema1);
      IndicatorRelease(ema2);
      IndicatorRelease(macd);
     }

   if(s.useTF15m)
     {
      int rsi=iRSI(_Symbol,PERIOD_M15,14,PRICE_CLOSE);
      int ema1=iMA(_Symbol,PERIOD_M15,50,0,MODE_EMA,PRICE_CLOSE);
      int ema2=iMA(_Symbol,PERIOD_M15,200,0,MODE_EMA,PRICE_CLOSE);
      int macd=iMACD(_Symbol,PERIOD_M15,12,26,9,PRICE_CLOSE);
      double rsiVal=GetIndicatorValue(rsi,0);
      double ma1Val=GetIndicatorValue(ema1,0);
      double ma2Val=GetIndicatorValue(ema2,0);
      double macdVal=GetIndicatorValue(macd,0);
      double macdPrev=GetIndicatorValue(macd,1);
      add(rsiVal>50.0,rsiVal<50.0,s.rsiWeight,s.weight15m);
      add(ma1Val>ma2Val,ma1Val<ma2Val,s.trendWeight,s.weight15m);
      add(macdVal>macdPrev,macdVal<macdPrev,s.macdSlopeWeight,s.weight15m);
      IndicatorRelease(rsi);
      IndicatorRelease(ema1);
      IndicatorRelease(ema2);
      IndicatorRelease(macd);
     }

   if(s.useTF1h)
     {
      int rsi=iRSI(_Symbol,PERIOD_H1,14,PRICE_CLOSE);
      int ema1=iMA(_Symbol,PERIOD_H1,50,0,MODE_EMA,PRICE_CLOSE);
      int ema2=iMA(_Symbol,PERIOD_H1,200,0,MODE_EMA,PRICE_CLOSE);
      int macd=iMACD(_Symbol,PERIOD_H1,12,26,9,PRICE_CLOSE);
      double rsiVal=GetIndicatorValue(rsi,0);
      double ma1Val=GetIndicatorValue(ema1,0);
      double ma2Val=GetIndicatorValue(ema2,0);
      double macdVal=GetIndicatorValue(macd,0);
      double macdPrev=GetIndicatorValue(macd,1);
      add(rsiVal>50.0,rsiVal<50.0,s.rsiWeight,s.weight1h);
      add(ma1Val>ma2Val,ma1Val<ma2Val,s.trendWeight,s.weight1h);
      add(macdVal>macdPrev,macdVal<macdPrev,s.macdSlopeWeight,s.weight1h);
      IndicatorRelease(rsi);
      IndicatorRelease(ema1);
      IndicatorRelease(ema2);
      IndicatorRelease(macd);
     }

   return(score);
  }


#endif // __SYNERGY_MQH__
