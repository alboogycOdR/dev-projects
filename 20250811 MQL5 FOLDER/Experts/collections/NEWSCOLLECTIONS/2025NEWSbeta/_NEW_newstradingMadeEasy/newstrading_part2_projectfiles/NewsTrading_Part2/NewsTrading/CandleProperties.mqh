//+------------------------------------------------------------------+
//|                                                      NewsTrading |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                            https://www.mql5.com/en/users/kaaiblo |
//+------------------------------------------------------------------+
#include "TimeManagement.mqh"
#include "ChartProperties.mqh"
//+------------------------------------------------------------------+
//|CandleProperties class                                            |
//+------------------------------------------------------------------+
class CCandleProperties : public CChartProperties
  {
private:
   CTimeManagement   Time;

public:
   double            Open(int CandleIndex,ENUM_TIMEFRAMES Period=PERIOD_CURRENT,string SYMBOL=NULL);//Retrieve Candle Open-Price
   double            Close(int CandleIndex,ENUM_TIMEFRAMES Period=PERIOD_CURRENT,string SYMBOL=NULL);//Retrieve Candle Close-Price
   double            High(int CandleIndex,ENUM_TIMEFRAMES Period=PERIOD_CURRENT,string SYMBOL=NULL);//Retrieve Candle High-Price
   double            Low(int CandleIndex,ENUM_TIMEFRAMES Period=PERIOD_CURRENT,string SYMBOL=NULL);//Retrieve Candle Low-Price
   bool              IsLargerThanPreviousAndNext(datetime CandleTime,int Offset,string SYMBOL);//Determine if one candle is larger than two others
  };

//+------------------------------------------------------------------+
//|Retrieve Candle Open-Price                                        |
//+------------------------------------------------------------------+
double CCandleProperties::Open(int CandleIndex,ENUM_TIMEFRAMES Period=PERIOD_CURRENT,string SYMBOL=NULL)
  {
   return (SetSymbolName(SYMBOL))?iOpen(GetSymbolName(),Period,CandleIndex):0;//return candle open price
  }

//+------------------------------------------------------------------+
//|Retrieve Candle Close-Price                                       |
//+------------------------------------------------------------------+
double CCandleProperties::Close(int CandleIndex,ENUM_TIMEFRAMES Period=PERIOD_CURRENT,string SYMBOL=NULL)
  {
   return (SetSymbolName(SYMBOL))?iClose(GetSymbolName(),Period,CandleIndex):0;//return candle close price
  }

//+------------------------------------------------------------------+
//|Retrieve Candle High-Price                                        |
//+------------------------------------------------------------------+
double CCandleProperties::High(int CandleIndex,ENUM_TIMEFRAMES Period=PERIOD_CURRENT,string SYMBOL=NULL)
  {
   return (SetSymbolName(SYMBOL))?iHigh(GetSymbolName(),Period,CandleIndex):0;//return candle high price
  }

//+------------------------------------------------------------------+
//|Retrieve Candle Low-Price                                         |
//+------------------------------------------------------------------+
double CCandleProperties::Low(int CandleIndex,ENUM_TIMEFRAMES Period=PERIOD_CURRENT,string SYMBOL=NULL)
  {
   return (SetSymbolName(SYMBOL))?iLow(GetSymbolName(),Period,CandleIndex):0;//return candle low price
  }

//+------------------------------------------------------------------+
//|Determine if one candle is larger than two others                |
//+------------------------------------------------------------------+
bool CCandleProperties::IsLargerThanPreviousAndNext(datetime CandleTime,int Offset,string SYMBOL)
  {
   int CandleIndex = iBarShift(SYMBOL,PERIOD_M15,CandleTime);//Assign candle index of candletime
//--Assign candle index of candletime minus time offset
   int CandleIndexMinusOffset = iBarShift(SYMBOL,PERIOD_M15,Time.TimeMinusOffset(CandleTime,Offset));
//--Assign candle index of candletime plus time offset
   int CandleIndexPlusOffset = iBarShift(SYMBOL,PERIOD_M15,Time.TimePlusOffset(CandleTime,Offset));
//--Assign height of M15 candletime in pips
   double CandleHeight = High(CandleIndex,PERIOD_M15,SYMBOL)-Low(CandleIndex,PERIOD_M15,SYMBOL);
//--Assign height of M15 candletime  minus offset in Pips
   double CandleHeightMinusOffset = High(CandleIndexMinusOffset,PERIOD_M15,SYMBOL)-Low(CandleIndexMinusOffset,PERIOD_M15,SYMBOL);
//--Assign height of M15 candletime plus offset in Pips
   double CandleHeightPlusOffset = High(CandleIndexPlusOffset,PERIOD_M15,SYMBOL)-Low(CandleIndexPlusOffset,PERIOD_M15,SYMBOL);
//--Determine if candletime height is greater than candletime height minus offset and candletime height plus offset
   if(CandleHeight>CandleHeightMinusOffset&&CandleHeight>CandleHeightPlusOffset)
     {
      return true;//Candletime is likely when the news event occured
     }
   return false;//Candletime is unlikely when the real news data was released
  }
//+------------------------------------------------------------------+
