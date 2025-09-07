//+------------------------------------------------------------------+
//|                                                HELPERCLASSES.mqh |
//|                    Copyright 2021, nuburo trading solutions pty. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, nuburo trading solutions pty."
#property link      "https://www.mql5.com"
#property version   "1.00"


class HELPERCLASSES
  {
private:
                  double ExtUpChannel;
                  double ExtLowChannel;
                  double ExtChannelRange;
                  #define NO_VALUE      INT_MAX                      // invalid value of Signal/Trend
public:
                     HELPERCLASSES();
                    ~HELPERCLASSES();
                    virtual int IsRange(void);
                    virtual int TrendCalculate(void);
  };
 
HELPERCLASSES::HELPERCLASSES()
  {
                     ExtUpChannel   =0;
                   ExtLowChannel  =0;
                   ExtChannelRange=0;
  }
 
HELPERCLASSES::~HELPERCLASSES()
  {
  }
  
  

//+------------------------------------------------------------------+
//|  Returns true if the channel is narrow (indication of flat)      |
//+------------------------------------------------------------------+
int HELPERCLASSES::IsRange()
  {
//--- get the ATR value on the last completed bar
   double atr_buffer[];
   if(CopyBuffer(ExtATRHandle, 0, 1, 1, atr_buffer)==-1)
     {
      PrintFormat("%s: Failed CopyBuffer(ExtATRHandle,0,1,2,atr_buffer), code=%d", __FILE__, GetLastError());
      return(NO_VALUE);
     }
   double atr=atr_buffer[0];
   
   
//--- get the channel borders
   if(!ChannelBoundsCalculate(ExtUpChannel, ExtLowChannel))
      return(NO_VALUE);
      
   ExtChannelRange=ExtUpChannel-ExtLowChannel;
//--- compare the channel width with the ATR value
   if(ExtChannelRange<InpATRCoeff*atr)
      return(true);
      
//--- range not detected
   return(false);
  }
   
  //+------------------------------------------------------------------+
//| Returns 1 for UpTrend or -1 for DownTrend (0 = no trend)         |
//+------------------------------------------------------------------+
int HELPERCLASSES::TrendCalculate()
  {
//--- get the ATR value on the last completed bar
   double atr_buffer[];
   if(CopyBuffer(ExtATRHandle, 0, 1, 1, atr_buffer)==-1)
     {
      PrintFormat("%s: Failed CopyBuffer(ExtATRHandle,0,1,2,atr_buffer), code=%d", __FILE__, GetLastError());
      return(NO_VALUE);
     }
   double atr=atr_buffer[0];
   
   
//--- get the channel borders
   if(!ChannelBoundsCalculate(ExtUpChannel, ExtLowChannel))
      return(NO_VALUE);
      
   ExtChannelRange=ExtUpChannel-ExtLowChannel;
   
//--- compare the channel width with the ATR value
   if(ExtChannelRange<InpATRCoeff*atr)
      return(true);
      
//--- range not detected
   return(false);  
  
  
  
  
//--- first check if we are in the range
   int is_range=IsRange();
//--- if the value could not be calculated
   if(is_range==NO_VALUE)
     {
      //--- the failed to check, early exit with the "no value" response
      return(NO_VALUE);
     }
//--- if the price is in a narrow range, the trend should not be calculated
   if(is_range==true) // narrow range, return "flat" (range)
      return(0);
      
//--- get the ATR value on the last completed bar
   double atr_buffer[];
   if(CopyBuffer(ExtBBHandle, 0, 1, 1, atr_buffer)==-1)
     {
      PrintFormat("%s: Failed CopyBuffer(ExtATRHandle,0,1,2,atr_buffer), code=%d", __FILE__, GetLastError());
      return(NO_VALUE);
     }
     
//--- get the fast MA value on the last completed bar
   double fastma_buffer[];
   if(CopyBuffer(ExtFastMAHandle, 0, 1, 1, fastma_buffer)==-1)
     {
      PrintFormat("%s: Failed CopyBuffer(ExtFastMAHandle,0,1,2,fastma_buffer), code=%d", __FILE__, GetLastError());
      return(NO_VALUE);
     }
//--- get the slow MA value on the last completed bar
   double slowma_buffer[];
   if(CopyBuffer(ExtSlowMAHandle, 0, 1, 1, slowma_buffer)==-1)
     {
      PrintFormat("%s: Failed CopyBuffer(ExtSlowMAHandle,0,1,2,slowma_buffer), code=%d", __FILE__, GetLastError());
      return(NO_VALUE);
     }
     
//--- trend is not detected
   int trend=0;
//--- if the price is above the MA
   if(fastma_buffer[0]>slowma_buffer[0])
      trend=1;   // uptrend
//--- if the price is below the MA
   if(fastma_buffer[0]<slowma_buffer[0])
      trend=-1;  // downtrend
      
//--- return the trend direction
   return(trend);
  }
 
