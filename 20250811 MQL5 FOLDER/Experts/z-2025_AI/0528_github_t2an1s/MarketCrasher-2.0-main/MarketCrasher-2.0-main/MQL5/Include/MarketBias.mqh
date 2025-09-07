//+------------------------------------------------------------------+
//| Market Bias indicator include                                     |
//+------------------------------------------------------------------+

#ifndef __MARKET_BIAS_MQH__
#define __MARKET_BIAS_MQH__

// calculate market bias oscillator and detect changes
// returns oscillator value, sets flags for bullish/bearish change
static double MarketBiasOsc(
      ENUM_TIMEFRAMES biasTF,int haLen,int oscLen,
      bool &changedBull,bool &changedBear)
  {
   // Heikin Ashi smoothed values
   double openE=iMA(_Symbol,biasTF,haLen,0,MODE_EMA,PRICE_OPEN,0);
   double closeE=iMA(_Symbol,biasTF,haLen,0,MODE_EMA,PRICE_CLOSE,0);
   double bias=closeE-openE;
   double openEprev=iMA(_Symbol,biasTF,haLen,0,MODE_EMA,PRICE_OPEN,1);
   double closeEprev=iMA(_Symbol,biasTF,haLen,0,MODE_EMA,PRICE_CLOSE,1);
   double prevBias=closeEprev-openEprev;

   double osc=100*bias;
   double smooth=100*prevBias; // basic smoothing

   static int prevState=0; // -1 bear,1 bull
   int currState = (osc>smooth ? 1 : -1);
   changedBull=false;
   changedBear=false;
   if(prevState!=0)
     {
      changedBull = (prevState<0 && currState>0);
      changedBear = (prevState>0 && currState<0);
     }
   prevState=currState;
   return(osc);
  }

#endif //__MARKET_BIAS_MQH__

