//+------------------------------------------------------------------+
//|                                       ICT_SILVERBULLET_BALKE.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+


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

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Class CPoint                                                     |
//+------------------------------------------------------------------+
class CPoint
  {
private:
   double            price;
   datetime          time;
public:
                     CPoint();
                     CPoint(const double p, const datetime t);
                    ~CPoint() {};
   void              setPoint(const double p, const datetime t);
   bool              operator==(const CPoint &other) const;
   bool              operator!=(const CPoint &other) const;
   void              operator=(const CPoint &other);
   double            getPrice() const;
   datetime          getTime() const;
  };
//---
CPoint::CPoint(void)
  {
   price = 0;
   time = 0;
  }
//---
CPoint::CPoint(const double p, const datetime t)
  {
   price = p;
   time = t;
  }
//---
void CPoint::setPoint(const double p, const datetime t)
  {
   price = p;
   time = t;
  }
//---
bool CPoint::operator==(const CPoint &other) const
  {
   return price == other.price && time == other.time;
  }
//---
bool CPoint::operator!=(const CPoint &other) const
  {
   return !operator==(other);
  }
//---
void CPoint::operator=(const CPoint &other)
  {
   price = other.price;
   time = other.time;
  }
//---
double CPoint::getPrice(void) const
  {
   return(price);
  }
//---
datetime CPoint::getTime(void) const
  {
   return(time);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CFairValueGap : public CObject
  {
public:
   int               direction; //up or dn
   datetime          time;
   double            high;
   double            low;
   void              draw(datetime timeStart, datetime timeEnd)
     {
      string objFvg = "SB FVG " + TimeToString(time);
      ObjectCreate(0,objFvg,OBJ_RECTANGLE,0,time, low, timeStart,high);
      ObjectSetInteger(0,objFvg,OBJPROP_FILL, true);
      ObjectSetInteger(0,objFvg, OBJPROP_COLOR, clrLightGray);
      string objTrade = "SB Trade " + TimeToString(time);
      ObjectCreate(0,objTrade,OBJ_RECTANGLE, 0, timeStart, low, timeEnd,high);
      ObjectSetInteger(0,objTrade,OBJPROP_FILL,true);
      ObjectSetInteger(0, objTrade, OBJPROP_COLOR, clrGray);
     }
   void              drawTradeLevels(double tp, double sl, datetime timeStart, datetime timeEnd)
     {
      string objTp = "SB TP " + TimeToString(time);
      ObjectCreate(0,objTp,OBJ_RECTANGLE,0, timeStart, (direction > 0 ? high : low), timeEnd, tp);
      ObjectSetInteger(0,objTp,OBJPROP_FILL, true);
      ObjectSetInteger(0,objTp,OBJPROP_COLOR, clrLightGreen);
      string objsl = "SB SL " + TimeToString(time);
      ObjectCreate(0,objsl,OBJ_RECTANGLE,0, timeStart, (direction > 0 ? high : low), timeEnd, sl);
      ObjectSetInteger(0,objsl, OBJPROP_FILL, true);
      ObjectSetInteger(0,objsl, OBJPROP_COLOR, clrOrange);
     }
  };


//FIELDS
input double Lots = 0.1;
input double RiskPercent = 0.5;
input int MinTpPoints = 150;
input ENUM_TIMEFRAMES Timeframe = PERIOD_CURRENT;
input bool SHOW_TRADELEVELS = false; //Show tradelevels

input int MinFvgPoints = 50;
input int TimeStartHour = 18;
input int TimeEndHour = 19;
//----
input string TrueDayStartTime = "00:00";
input string TrueDayEndTime = "23:59";
input int    NumberOfDays = 5;
double textprice, newtextprice,max_price, min_price;
input color TrueDayStartColor = clrGreen;
input color TrueDayEndColor = clrRed;
input ENUM_LINE_STYLE TrueDayLineStyle = STYLE_DASHDOTDOT;
double closeD1;
double openD1;
double highD1;
double lowD1;
//----
double closeW1;
double highW1;
double lowW1;
input int            InpLinesWidth = 1;      // lines width
input color          InpSupColor = clrBlack;   // Support line color
input color          InpResColor = clrBlue;  // Resistance line color
//OBJECTS
CTrade trade;
CFairValueGap* fvg;
CPoint pointLeftDailyHigh, pointRightDailyHigh,
       pointLeftDailyLow, pointRightDailyLow, nullPoint;

CPoint pointLeftWeeklyHigh, pointRightWeeklyHigh,
       pointLeftWeeklyLow, pointRightWeeklyLow;

input datetime StartTime = D'2023.11.24 00:00';
input datetime EndTime = D'2023.11.24 17:00';

//ALERTING
datetime LastHighAlert = D'1970.01.01';
datetime LastLowAlert = D'1970.01.01';
input bool EnableNativeAlerts = false;
input bool EnableEmailAlerts = false;
input bool EnablePushAlerts = false;
input int N = 20;



//input datetime StartTime = D'00:00';
//input datetime EndTime = D'17:00';
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int TimeDay(datetime time)
  {
   MqlDateTime tm;
   TimeToStruct(time,tm);
   return(tm.day);
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
void DrawLevels()
  {
  highD1=NULL;lowD1=NULL;highW1=NULL;lowW1=NULL;
  
  // closeD1 = iClose(_Symbol,PERIOD_D1,1);
   //openD1 = iOpen(_Symbol,PERIOD_D1,1);
   highD1 = iHigh(_Symbol,PERIOD_D1,1);
   lowD1 = iLow(_Symbol,PERIOD_D1,1);
//---weekly stats
   MqlRates PriceDataTableWeekly[];
   CopyRates(_Symbol,PERIOD_W1,0,2,PriceDataTableWeekly);
   highW1 = PriceDataTableWeekly[1].high;
   lowW1 = PriceDataTableWeekly[1].low;
   //closeW1 = PriceDataTableWeekly[1].close;
//====
   MqlDateTime structTimehighlow;
   TimeCurrent(structTimehighlow);
   structTimehighlow.min = 0;
   structTimehighlow.sec = 0;
   structTimehighlow.hour = 0;
   structTimehighlow.min = 0;
   datetime timeStart = StructToTime(structTimehighlow);
   structTimehighlow.hour = 23;
   structTimehighlow.min = 59;
   datetime timeEnd = StructToTime(structTimehighlow);
//---
   pointLeftDailyHigh.setPoint(highD1, timeStart);
   pointRightDailyHigh.setPoint(highD1, timeEnd);
   pointLeftDailyLow.setPoint(lowD1, timeStart);
   pointRightDailyLow.setPoint(lowD1, timeEnd);
   drawLine("PDH", pointLeftDailyHigh, pointRightDailyHigh, clrDarkBlue);
   drawLine("PDL", pointLeftDailyLow, pointRightDailyLow, clrDarkBlue);
//==
   pointLeftWeeklyHigh.setPoint(highW1, timeStart);
   pointRightWeeklyHigh.setPoint(highW1, timeEnd);
   pointLeftWeeklyLow.setPoint(lowW1, timeStart);
   pointRightWeeklyLow.setPoint(lowW1, timeEnd);
   drawLine("PWH", pointLeftWeeklyHigh, pointRightWeeklyHigh, clrGreen);
   drawLine("PWL", pointLeftWeeklyLow, pointRightWeeklyLow, clrGreen);
//====

   datetime date_time = TimeCurrent();
   DrawTrueDay(date_time, "TrueDay", NumberOfDays, TrueDayStartTime, TrueDayEndTime, TrueDayStartColor, TrueDayEndColor, TrueDayLineStyle);


  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   DrawLevels();
   return(INIT_SUCCEEDED);
  }


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
bool isNewBar()
  {
//Print("NEW BAR CHECK ROUTINE");
//--- memorize the time of opening of the last bar in the static variable
   static datetime last_time = 0;
//--- current time
   datetime lastbar_time = (datetime)SeriesInfoInteger(Symbol(),Period(),SERIES_LASTBAR_DATE);
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
   if(IsNewDay())
     {
      ObjectsDeleteAll(0, 0, OBJ_TREND);
      ObjectsDeleteAll(0,"PDL");ObjectsDeleteAll(0,"PDL");
      ObjectsDeleteAll(0,"PWL");ObjectsDeleteAll(0,"PWH");
      DrawLevels();
     }
   if(!isNewBar())
     {
      return;
     }
   static int lastDay = 0;
//----
   MqlDateTime structTime;
   TimeCurrent(structTime);
   structTime.min = 0;
   structTime.sec = 0;
//----
   structTime.hour = TimeStartHour;
   datetime timeStart = StructToTime(structTime);
   structTime.hour = TimeEndHour;
   datetime timeEnd = StructToTime(structTime);
//Print("time on the tradeserver: " + TimeTradeServer());
//Print("time on the local: " + TimeLocal());
//Print("time gmt: " + TimeGMT());
//Print(" gmt offset: " + TimeGMTOffset());
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
         double tp = iLow(_Symbol, Timeframe, iLowest(_Symbol, Timeframe, MODE_LOW,iBarShift(_Symbol, Timeframe, fvg. time)));
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
     }
  }//end void ontick
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double calcLots(double slDist)
  {
   double risk = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent / 100;
   double ticksize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickvalue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(ticksize == 0)
      return -1;
   double moneyPerLot = slDist / ticksize * tickvalue;
   if(moneyPerLot == 0)
      return -1;
   double lots = NormalizeDouble(risk / moneyPerLot, 2);
   return lots;
  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Draw trend line function                                         |
//+------------------------------------------------------------------+
void drawLine(string name, CPoint &right, CPoint &left, color clr)
  {
//---
   ObjectDelete(0, name);
//---
   ObjectCreate(0, name, OBJ_TREND, 0, right.getTime(), right.getPrice(), left.getTime(), left.getPrice());
   ObjectSetInteger(0, name, OBJPROP_WIDTH, InpLinesWidth);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
//---
  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------------+
//| DrawTrueDay: Draws Custom period Seperators that show true day         |
//+------------------------------------------------------------------------+
bool DrawTrueDay(
   datetime date_time,
   string obj_name,
   int days_look_back,
   string startTime,
   string endTime,
   color startColor,
   color endColor,
   ENUM_LINE_STYLE truedayLineStyle
)
  {
   for(int i = 0; i < days_look_back; i++)
     {
      string name = obj_name + string(i);
      datetime time_start  = StringToTime(TimeToString(date_time, TIME_DATE) + " " + startTime);
      datetime time_end  = StringToTime(TimeToString(date_time, TIME_DATE) + " " + endTime);
      textprice = GetChartHighPrice();
      // TrueDay Start
      int _day = TimeDayOfWeek(date_time);
      if(_day > 0 && _day < 6)
        {
         ResetLastError();
         if(!drawVLine(0, name + "Start", "TrueDaySart", time_start, textprice, truedayLineStyle, startColor))
           {
            Print(__FUNCTION__,
                  ": Failed to draw line",GetLastError());
            return(false);
           }
         // TrueDay End
         ResetLastError();
         if(!drawVLine(0, name + "End", "TrueDayEnd", time_end, textprice, truedayLineStyle, endColor))
           {
            Print(__FUNCTION__,
                  ": Failed to draw line",GetLastError());
            return(false);
           }
        }
      date_time = decDateTradeDay(date_time);
      MqlDateTime times;
      TimeToStruct(date_time, times);
      while(times.day_of_week > 5)
        {
         date_time = decDateTradeDay(date_time);
         TimeToStruct(date_time, times);
        }
     }
   return(true);
  }


//+------------------------------------------------------------------+
datetime decDateTradeDay(datetime date_time)
  {
   MqlDateTime times;
   TimeToStruct(date_time, times);
   int time_years  = times.year;
   int time_months = times.mon;
   int time_days   = times.day;
   int time_hours  = times.hour;
   int time_mins   = times.min;
   time_days--;
   if(time_days == 0)
     {
      time_months--;
      if(!time_months)
        {
         time_years--;
         time_months = 12;
        }
      if(time_months == 1 || time_months == 3 || time_months == 5 || time_months == 7 || time_months == 8 || time_months == 10 || time_months == 12)
         time_days = 31;
      if(time_months == 2)
         if(!MathMod(time_years, 4))
            time_days = 29;
         else
            time_days = 28;
      if(time_months == 4 || time_months == 6 || time_months == 9 || time_months == 11)
         time_days = 30;
     }
   string text;
   StringConcatenate(text, time_years, ".", time_months, ".", time_days, " ", time_hours, ":", time_mins);
   return(StringToTime(text));
  }
//+------------------------------------------------------------------+
double GetChartHighPrice()
  {
   max_price = ChartGetDouble(0,CHART_PRICE_MAX);
   min_price = ChartGetDouble(0,CHART_PRICE_MIN);
   return(max_price - ((max_price - min_price) * (0 / ChartHeightInPixelsGet(0, 0))));
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int TimeDayOfWeek(datetime date)
  {
   MqlDateTime tm;
   TimeToStruct(date,tm);
   return(tm.day_of_week);
  }



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool drawVLine(int obj_id, string obj_name, string obj_description, datetime obj_time, double obj_price, ENUM_LINE_STYLE line_style, color obj_clr)
  {
//--
   ResetLastError();
   if(!ObjectDelete(obj_id, obj_name))
     {
      Print(__FUNCTION__,
            ": Failed to delete old object ",GetLastError());
      return(false);
     }
//--
   ResetLastError();
   if(!line.Create(obj_id, obj_name, 0, obj_time, Point(), obj_time, obj_price))
     {
      Print(__FUNCTION__,
            ": Failed to create line object ",GetLastError());
      return(false);
     }
   line.Color(obj_clr);
   line.Description(obj_description);
   line.SetInteger(OBJPROP_STYLE, line_style);
   line.SetString(OBJPROP_TEXT, obj_description);
   return(true);
  }
//+-----------

//+------------------------------------------------------------------+
//| Issues alerts and remembers the last sent alert time.            |
//+------------------------------------------------------------------+
void SendAlert(int direction, double price, datetime time)
  {
   string alert = "Local ";
   string subject;
   if(direction == HIGH)
     {
      alert = alert + "high";
      subject = "High broken @ " + Symbol() + " - " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)Period()), 7);
      LastHighAlert = time;
     }
   else
      if(direction == LOW)
        {
         alert = alert + "low";
         subject = "Low broken @ " + Symbol() + " - " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)Period()), 7);
         LastLowAlert = time;
        }
   alert = alert + " broken at " + DoubleToString(price, _Digits) + ".";
   if(EnableNativeAlerts)
      Alert(alert);
   if(EnableEmailAlerts)
      SendMail(subject, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) + " " + alert);
   if(EnablePushAlerts)
      SendNotification(subject + " @ " + DoubleToString(price, _Digits));
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int ChartHeightInPixelsGet(const long chart_ID = 0,const int sub_window = 0)
  {
   long result = -1;
   ResetLastError();
   if(!ChartGetInteger(chart_ID,CHART_HEIGHT_IN_PIXELS,sub_window,result))
     {
      Print(__FUNCTION__ + ", Error Code = ",GetLastError());
     }
   if((int)result == 0)
      result = -1;
   return((int)result);
  }
//+------------------------------------------------------------------+
