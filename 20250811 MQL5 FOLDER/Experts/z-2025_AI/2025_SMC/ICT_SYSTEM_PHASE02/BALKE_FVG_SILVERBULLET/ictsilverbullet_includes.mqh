//+------------------------------------------------------------------+
//|                                     ictsilverbullet_includes.mqh |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
 
 
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
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawLevels()
  {
  highD1=NULL;lowD1=NULL;highW1=NULL;lowW1=NULL;
  
 
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
int TimeDay(datetime time)
  {
   MqlDateTime tm;
   TimeToStruct(time,tm);
   return(tm.day);
  }