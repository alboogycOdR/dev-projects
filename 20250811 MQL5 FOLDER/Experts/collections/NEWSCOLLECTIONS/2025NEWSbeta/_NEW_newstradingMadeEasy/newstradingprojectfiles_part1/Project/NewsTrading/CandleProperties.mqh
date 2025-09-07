//+------------------------------------------------------------------+
//|                                                      NewsTrading |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#include "TimeManagement.mqh"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CCandleProperties
  {
private:
   CTimeManagement   Time;

public:
   double            Open(int CandleIndex,ENUM_TIMEFRAMES Period=PERIOD_CURRENT,string SYMBOL=NULL);//Retrieve Candle OpenPrice
   double            Close(int CandleIndex,ENUM_TIMEFRAMES Period=PERIOD_CURRENT,string SYMBOL=NULL);//Retrieve Candle ClosePrice
   double            High(int CandleIndex,ENUM_TIMEFRAMES Period=PERIOD_CURRENT,string SYMBOL=NULL);//Retrieve Candle HighPrice
   double            Low(int CandleIndex,ENUM_TIMEFRAMES Period=PERIOD_CURRENT,string SYMBOL=NULL);//Retrieve Candle LowPrice
   bool              IsLargerThanPreviousAndNext(datetime CandleTime,int Offset,string SYMBOL);//Deteremine if one candle is larger than two others
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CCandleProperties::Open(int CandleIndex,ENUM_TIMEFRAMES Period=PERIOD_CURRENT,string SYMBOL=NULL)
  {
   return iOpen(((SYMBOL==NULL)?Symbol():SYMBOL),Period,CandleIndex);//return candle open price
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CCandleProperties::Close(int CandleIndex,ENUM_TIMEFRAMES Period=PERIOD_CURRENT,string SYMBOL=NULL)
  {
   return iClose(((SYMBOL==NULL)?Symbol():SYMBOL),Period,CandleIndex);//return candle close price
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CCandleProperties::High(int CandleIndex,ENUM_TIMEFRAMES Period=PERIOD_CURRENT,string SYMBOL=NULL)
  {
   return iHigh(((SYMBOL==NULL)?Symbol():SYMBOL),Period,CandleIndex);//return candle high price
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CCandleProperties::Low(int CandleIndex,ENUM_TIMEFRAMES Period=PERIOD_CURRENT,string SYMBOL=NULL)
  {
   return iLow(((SYMBOL==NULL)?Symbol():SYMBOL),Period,CandleIndex);//return candle low price
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CCandleProperties::IsLargerThanPreviousAndNext(datetime CandleTime,int Offset,string SYMBOL)
  {
   int CandleIndex = iBarShift(SYMBOL,PERIOD_M15,CandleTime);//Assign candle index of candletime
   int CandleIndexMinusOffset = iBarShift(SYMBOL,PERIOD_M15,Time.TimeMinusOffset(CandleTime,Offset));//Assign candle index of candletime minus time offset 
   int CandleIndexPlusOffset = iBarShift(SYMBOL,PERIOD_M15,Time.TimePlusOffset(CandleTime,Offset));//Assign candle index of candletime plus time offset
   double CandleHeight = High(CandleIndex,PERIOD_M15,SYMBOL)-Low(CandleIndex,PERIOD_M15,SYMBOL);//Assign height of M15 candletime in pips
   double CandleHeightMinusOffset = High(CandleIndexMinusOffset,PERIOD_M15,SYMBOL)-Low(CandleIndexMinusOffset,PERIOD_M15,SYMBOL);//Assign height of M15 candletime  minus offset in Pips
   double CandleHeightPlusOffset = High(CandleIndexPlusOffset,PERIOD_M15,SYMBOL)-Low(CandleIndexPlusOffset,PERIOD_M15,SYMBOL);//Assign height of M15 candletime plus offset in Pips
   //--Determine if candletime height is greater than candletime height minus offset and candletime height plus offset
   if(CandleHeight>CandleHeightMinusOffset&&CandleHeight>CandleHeightPlusOffset)
     {
      return true;//Candletime is likely when the news event occured
     }
   return false;//Candletime is unlikely when the real news data was released
  }
//+------------------------------------------------------------------+
