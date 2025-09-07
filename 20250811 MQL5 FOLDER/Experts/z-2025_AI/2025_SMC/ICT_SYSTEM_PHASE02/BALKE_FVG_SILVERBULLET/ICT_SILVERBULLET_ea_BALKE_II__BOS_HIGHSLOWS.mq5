//+------------------------------------------------------------------+
//|                                       ICT_SILVERBULLET_BALKE.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
/*

todo:


PDL sometimes not working





*/

/*
keywords
     ICT     SILVERBULLET     FVG

CREATED FROM YOUTUBE TUT
RENE BALKE

*/

/*
todo:

   redraw high and lows when entering a new day
   draw session lines
   draw vline on start and end of day



*/


/*comments and things to consider wrt the youtube channel  https://www.youtube.com/watch?v=jwtmlYZxD_o&t=755s

comment----
I think the logic is a bit off here, The FVG detection starts at the SB Session, not before. That could be the reason why the performance isnt so good.
Side note, i find out from manually trading ICT SB. the FVG after 30 into session is usually the correct one to enter trades
__ I'm planning to add Midnight Open price to determine the FVG type to look for trade rather than just taking the first FVG found.
Anyway keep up the good work. Solid channel

comment----
Rene, thank you for teaching fvg to me / us.
Backtesting your original EA shows some nice curves but not perfect enough for real money.
But the first step is done! Thank you very much.
This fvg - idea is based on pure price action. That is my absolute favorite.

I will try to add additional filter or a trailing ... So this result can be optimized withoud over optimization. I think.
Maybe yes, maybe not, but i will give it a try.

comment____
 As a suggestion i have seen a few youtube videos where it looks at finding pairs that have the week, day and 4 hour and 1 hour all trending the same. Then place a trade on the 15 minutes on a break of structure.



user:
ICT method is to take the trade once the candle sticks enter the Rectangle.
 Here the strategy takes trade whenever the rectangle identified,
 not when the price action enter the rectangle. I would love you to help me to find a way
  where I can change the code to make it trade when price enter the rectangle. Thanks
rene:  Hey, the EA should open a trade when the price enters the rectangle. So it should be as you described it. Or did I get you wrong?
user:  you got me correct Sir !



*/
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <trade/trade.mqh>

#include <ChartObjects/ChartObjectsLines.mqh>
CChartObjectTrend line;
#define HIGH 1
#define LOW 0

#include  "ictsilverbullet_includes_classes.mqh"
#include  "ictsilverbullet_includes.mqh"

//FIELDS
input double Lots = 0.1;
input double RiskPercent = 0.5;
input int MinTpPoints = 150;
input ENUM_TIMEFRAMES Timeframe = PERIOD_CURRENT;
input bool SHOW_TRADELEVELS = false; //Show tradelevels

input int MinFvgPoints = 50;
input int TimeStartHour = 10;//Start hour (24HR)
input int TimeEndHour = 19;//End hour (24HR)
//----
input string TrueDayStartTime = "00:00";
input string TrueDayEndTime = "23:59";
input int    NumberOfDays = 5;
double textprice, newtextprice,max_price, min_price;
input color TrueDayStartColor = clrGreen;
input color TrueDayEndColor = clrRed;
input ENUM_LINE_STYLE TrueDayLineStyle = STYLE_DASHDOTDOT;
double closeD1, openD1, highD1,lowD1;
double closeW1,highW1,lowW1;
input int            InpLinesWidth = 1;      // lines width
input color          InpSupColor = clrBlack;   // Support line color
input color          InpResColor = clrBlue;  // Resistance line color


//----
CTrade trade;
CFairValueGap* fvg;
CPoint pointLeftDailyHigh, pointRightDailyHigh,
       pointLeftDailyLow, pointRightDailyLow, nullPoint;
CPoint pointLeftWeeklyHigh, pointRightWeeklyHigh,
       pointLeftWeeklyLow, pointRightWeeklyLow;

//input datetime StartTime = D'2023.11.24 00:00';
//input datetime EndTime = D'2023.11.24 17:00';
//input datetime StartTime = D'00:00';
//input datetime EndTime = D'17:00';
//ALERTING
datetime LastHighAlert = D'1970.01.01',LastLowAlert = D'1970.01.01';
input bool EnableNativeAlerts = false;
input bool EnableEmailAlerts = false;
input bool EnablePushAlerts = false;
input int N = 20;


//-------highs , lows,   berak of structure fields
input int Depth = 20;
int lookbackcandles = Depth * 2 - 1;
//---
double   highs[], lows[];
double   High[],Low[], Close[];
datetime TimeArray[];
int      lastDirection = 0;
datetime lastTimeH = 0;
datetime lastTimeL = 0;
datetime PREVTimeH = 0;
datetime PREVTimeL = 0;

bool BOS_ENABLED=true;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {



   DrawLevels();
   ArraySetAsSeries(High,true);
   ArraySetAsSeries(Low,true);
   ArraySetAsSeries(TimeArray,true);
   ArraySetAsSeries(Close,true);

   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsNewDay()
  {
   static datetime lastCheckedTime = 0;
   datetime currentTime = TimeCurrent();
   if(TimeDay(currentTime) != TimeDay(lastCheckedTime))
     {
      lastCheckedTime = currentTime;
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0,"SB");
   ObjectsDeleteAll(0, 0, OBJ_TREND);
   for(int i = 0; i < NumberOfDays; i++)
     {
      ObjectDelete(0, "TrueDay" + string(i));
      ObjectDelete(0, "TrueDay" + string(i) + "Start");
      ObjectDelete(0, "TrueDay" + string(i) + "End");
     }
   ChartRedraw(0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(IsNewDay())
     {
      ObjectsDeleteAll(0, 0, OBJ_TREND);
      ObjectsDeleteAll(0,"PDL");
      ObjectsDeleteAll(0,"PDH");
      ObjectsDeleteAll(0,"PWL");
      ObjectsDeleteAll(0,"PWH");
      DrawLevels();
     }
   if(!isNewBar())
     {
      return;
     }
   if(BOS_ENABLED)
     {
      CopyHigh(Symbol(),PERIOD_CURRENT,0,5000,High);//lookbackcandles
      CopyLow(Symbol(),PERIOD_CURRENT,0,5000,Low);//lookbackcandles
      CopyClose(Symbol(),PERIOD_CURRENT,0,5000,Close);//lookbackcandles
      int copied = CopyTime(Symbol(),PERIOD_CURRENT,0,5000,TimeArray);//lookbackcandles


      //todo improve
      // 2023-12-12
      // 17:00
      for(int i = 1; i < 101; i++)
        {
         //highs[i] = EMPTY_VALUE;
         //lows[i] = EMPTY_VALUE;
         int index_last_high = iBarShift(_Symbol, PERIOD_CURRENT, lastTimeH);
         int index_last_low = iBarShift(_Symbol, PERIOD_CURRENT, lastTimeL);
         int index_prev_high = iBarShift(_Symbol, PERIOD_CURRENT, PREVTimeH);
         int index_prev_low = iBarShift(_Symbol, PERIOD_CURRENT, PREVTimeL);


         if(index_last_high > 0 && index_last_low > 0 && index_prev_high > 0 && index_prev_low > 0)
           {
            if(High[index_last_high] > High[index_prev_high] && Low[index_last_low] > Low[index_prev_low])
              {
               if(Close[i] > High[index_last_high])
                 {
                  string objName = "SMC BoS " + TimeToString(TimeArray[index_last_high]);
                  if(ObjectFind(0,objName) < 0)
                    {
                     ObjectCreate(0,objName, OBJ_TREND, 0, TimeArray[index_last_high],High[index_last_high], TimeArray[i],High[index_last_high]);
                     ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);//InpLinesWidth);
                     ObjectSetInteger(0, objName, OBJPROP_COLOR, clrNavy);//clr);
                     ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
                    }
                 }
              }
            if(High[index_last_high] < High[index_prev_high] && Low[index_last_low] < Low[index_prev_low])
              {
               if(Close[i] < Low[index_last_low])
                 {
                  string objName = "SMC BoS " + TimeToString(TimeArray[index_last_low]);
                  if(ObjectFind(0,objName) < 0)
                    {
                     ObjectCreate(0,objName, OBJ_TREND, 0, TimeArray[index_last_low],Low[index_last_low],TimeArray[i],Low[index_last_low]);
                     ObjectSetInteger(0, objName, OBJPROP_WIDTH,1);// InpLinesWidth);
                     ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);//clr);
                     ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
                    }
                 }
              }
           }//end if
         //find time of last high or time of last low

         if(i - Depth == ArrayMaximum(High,i, Depth * 2))
           {
            if(lastDirection > 0)
              {
               //int index = iBarShift(_Symbol,PERIOD_CURRENT,lastTimeH);
               Print("i: " + i);
               Print("index_last_high: " + index_last_high);
               Print("high_LAST HIGH: " + High[index_last_high]);
               Print("HIGH I+DEPTH: " + High[i - Depth]);
               Print("__");
               if(High[index_last_high] < High[i - Depth])
                  highs[index_last_high] = EMPTY_VALUE;//delete the last high if the current is higher
               else
                  continue;
              }
            highs[i - Depth] = High[i - Depth];
            lastDirection = 1;
            if(index_last_high == -1 || highs[index_last_high] != EMPTY_VALUE)
               PREVTimeH = lastTimeH;
            lastTimeH = TimeArray[i - Depth];
           }
         if(i - Depth == ArrayMinimum(Low, i, Depth * 2))
           {
            if(lastDirection < 0)
              {
               Print("i: " + i);
               Print("index_last_low: " + index_last_low);
               //int index = iBarShift(_Symbol,PERIOD_CURRENT,lastTimeL);
               Print("low_LAST low: " + Low[index_last_low]);
               Print("low I+DEPTH: " + Low[i + Depth]);
               Print("__");
               if(Low[index_last_low] > Low[i - Depth])
                  lows[index_last_low] = EMPTY_VALUE;//delete the last low if the current is lower
               else
                  continue;
              }
            lows[i - Depth] = Low[i - Depth];
            lastDirection = -1;
            if(index_last_low == -1 || lows[index_last_low] != EMPTY_VALUE)
               PREVTimeL = lastTimeL;
            lastTimeL = TimeArray[i - Depth];
           }


         //Print("index_last_low: " + index_last_low);
         //Print("index_last_high: " + index_last_high);
         //Print("index_prev_high: " + index_prev_high);
         //Print("index_prev_low: " + index_prev_low);
        }//end for loop
     }

   static int lastDay = 0;
//----
   MqlDateTime structTime;
   TimeCurrent(structTime);
   structTime.min = 0;
   structTime.sec = 0;
   structTime.hour = TimeStartHour;
   datetime timeStart = StructToTime(structTime);
   structTime.hour = TimeEndHour;
   datetime timeEnd = StructToTime(structTime);
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(bid >= highD1 /*&& (LastHighAlert != Time[rates_total - 1]))*/)
     {
      SendAlert(HIGH, highD1, TimeCurrent());
      //Print(__FUNCTION__," > Price hit the previous day high ... ");
     }
   if(bid <= lowD1 /*&& (LastLowAlert != Time[rates_total - 1])*/)
     {
      SendAlert(LOW, lowD1, TimeCurrent());
      //Print(__FUNCTION__," > Price hit the previous day low ... ");
      //Print("=====");
     }
//-----------------------------
   if(TimeCurrent() >= timeStart && TimeCurrent() < timeEnd)
     {
      if(lastDay != structTime.day_of_year)
        {
         delete fvg;
         for(int i = 1; i < 100; i++)
           {
            /*
            todo
            add booleans for fvg up and fvg down

            */
            //fvgUP
            if(iLow(_Symbol, Timeframe, i) - iHigh(_Symbol, Timeframe, i + 2) > MinFvgPoints * _Point)
              {
               fvg = new CFairValueGap();
               fvg.direction = 1;
               fvg.time = iTime(_Symbol, Timeframe, i + 1);
               fvg.high = iLow(_Symbol, Timeframe, i);
               fvg.low = iHigh(_Symbol, Timeframe, i + 2);
               if(iLow(_Symbol, Timeframe, iLowest(_Symbol, Timeframe, MODE_LOW,i + 1)) <= fvg.low)
                 {
                  delete fvg;
                  break; //continue;
                 }
               fvg.draw(timeStart, timeEnd);
               lastDay = structTime.day_of_year;
               break;
              }
            //fvgDOWN
            if(iLow(_Symbol, Timeframe, i + 2) - iHigh(_Symbol, Timeframe, i) > MinFvgPoints * _Point) //fvg dwn
              {
               fvg = new CFairValueGap();
               fvg.direction = -1;
               fvg.time = iTime(_Symbol, Timeframe, i + 1);
               fvg.high = iLow(_Symbol, Timeframe,i + 2);
               fvg.low = iHigh(_Symbol, Timeframe,i);
               if(iHigh(_Symbol, Timeframe, iHighest(_Symbol, Timeframe, MODE_HIGH,i + 1)) >= fvg.high)
                 {
                  delete fvg;
                  break; //continue;
                 }
               fvg.draw(timeStart, timeEnd);
               lastDay = structTime.day_of_year;
               break;
              }
           }
        }
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      //==========================
      //BULLISH FAIRVALUEGAP
      if(CheckPointer(fvg) != POINTER_INVALID && fvg.direction > 0 && ask < fvg.high)
        {
         double entry = ask;
         double tp = iHigh(_Symbol, Timeframe, iHighest(_Symbol, Timeframe, MODE_HIGH,iBarShift(_Symbol, Timeframe, fvg.time)));
         double sl = iLow(_Symbol, Timeframe, iLowest(_Symbol, Timeframe, MODE_LOW, 5, iBarShift(_Symbol, Timeframe, fvg.time)));
         double lots = Lots;
         if(Lots == 0)
            lots = calcLots(entry - sl);
         //TRADE LEVELS
         if(SHOW_TRADELEVELS)
            fvg.drawTradeLevels(tp, sl, timeStart, timeEnd);
         if(tp - entry > MinTpPoints * _Point)
           {
            if(trade.Buy(lots,_Symbol, entry,sl, tp))
              {
               Print(__FUNCTION__," > Buy signal ... ");
              }
           }
         delete fvg;
        }
      //==========================
      //BEARISH FAIRVALUEGAP
      if(CheckPointer(fvg) != POINTER_INVALID && fvg.direction < 0 && bid > fvg.low)
        {
         double entry = bid;
         double tp = iLow(_Symbol, Timeframe, iLowest(_Symbol, Timeframe, MODE_LOW,iBarShift(_Symbol, Timeframe, fvg.time)));
         double sl = iHigh(_Symbol, Timeframe, iHighest(_Symbol, Timeframe,MODE_HIGH, 5, iBarShift(_Symbol, Timeframe, fvg.time)));
         double lots = Lots;
         if(Lots == 0)
            lots = calcLots(sl - entry);
         if(SHOW_TRADELEVELS)
            fvg.drawTradeLevels(tp, sl, timeStart, timeEnd);
         if(entry - tp > MinTpPoints * _Point)
           {
            if(trade.Sell(lots,_Symbol,entry,sl, tp))
              {
               Print(__FUNCTION__," > Sell signal ... ");
              }
           }
         delete fvg;
        }
      //end bearish fvg
     }//if(TimeCurrent() >= timeStart && TimeCurrent() < timeEnd)
  }//end void ontick
