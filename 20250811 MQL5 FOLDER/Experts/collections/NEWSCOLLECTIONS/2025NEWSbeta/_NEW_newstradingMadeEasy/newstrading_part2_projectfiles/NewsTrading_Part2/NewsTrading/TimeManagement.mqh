//+------------------------------------------------------------------+
//|                                                      NewsTrading |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                            https://www.mql5.com/en/users/kaaiblo |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|TimeManagement class                                              |
//+------------------------------------------------------------------+
class CTimeManagement
  {

private:

   MqlDateTime       today;//private variable
   MqlDateTime       timeFormat;//private variable

public:

   //-- Checks if a date is within two other dates
   bool              DateIsInRange(datetime FirstTime,datetime SecondTime,datetime compareTime);
   //-- Check if two dates(Start&End) are within CompareStart & CompareEnd
   bool              DateIsInRange(datetime Start,datetime End,datetime CompareStart,datetime CompareEnd);
   bool              DateisToday(datetime TimeRepresented);//Checks if a date is within the current day
   int               SecondsS(int multiple=1);//Returns seconds
   int               MinutesS(int multiple=1);//Returns Minutes in seconds
   int               HoursS(int multiple=1);//Returns Hours in seconds
   int               DaysS(int multiple=1);//Returns Days in seconds
   int               WeeksS(int multiple=1);//Returns Weeks in seconds
   int               MonthsS(int multiple=1);//Returns Months in seconds
   int               YearsS(int multiple=1);//Returns Years in seconds
   int               ReturnYear(datetime time);//Returns the Year for a specific date
   int               ReturnMonth(datetime time);//Returns the Month for a specific date
   int               ReturnDay(datetime time);//Returns the Day for a specific date
   //-- Will return a datetime type of a date with an subtraction offset in seconds
   datetime          TimeMinusOffset(datetime standardtime,int timeoffset);
   //-- Will return a datetime type of a date with an addition offset in seconds
   datetime          TimePlusOffset(datetime standardtime,int timeoffset);
  };

//+------------------------------------------------------------------+
//|Checks if a date is within two other dates                        |
//+------------------------------------------------------------------+
bool CTimeManagement::DateIsInRange(datetime FirstTime,datetime SecondTime,datetime compareTime)
  {
   return(FirstTime<=compareTime&&SecondTime>compareTime);
  }

//+------------------------------------------------------------------+
//|Check if two dates(Start&End) are within CompareStart & CompareEnd|
//+------------------------------------------------------------------+
bool CTimeManagement::DateIsInRange(datetime Start,datetime End,datetime CompareStart,datetime CompareEnd)
  {
   return(Start<=CompareStart&&CompareEnd<End);
  }

//+------------------------------------------------------------------+
//|Checks if a date is within the current day                        |
//+------------------------------------------------------------------+
bool CTimeManagement::DateisToday(datetime TimeRepresented)
  {
   MqlDateTime TiM;
   TimeToStruct(TimeRepresented,TiM);
   TimeCurrent(today);
   return(TiM.year==today.year&&TiM.mon==today.mon&&TiM.day==today.day);
  }

//+------------------------------------------------------------------+
//|Returns seconds                                                   |
//+------------------------------------------------------------------+
int CTimeManagement::SecondsS(int multiple=1)
  {
   return (1*multiple);
  }

//+------------------------------------------------------------------+
//|Returns Minutes in seconds                                        |
//+------------------------------------------------------------------+
int CTimeManagement::MinutesS(int multiple=1)
  {
   return (SecondsS(60)*multiple);
  }

//+------------------------------------------------------------------+
//|Returns Hours in seconds                                          |
//+------------------------------------------------------------------+
int CTimeManagement::HoursS(int multiple=1)
  {
   return (MinutesS(60)*multiple);
  }

//+------------------------------------------------------------------+
//|Returns Days in seconds                                           |
//+------------------------------------------------------------------+
int CTimeManagement::DaysS(int multiple=1)
  {
   return (HoursS(24)*multiple);
  }

//+------------------------------------------------------------------+
//|Returns Weeks in seconds                                          |
//+------------------------------------------------------------------+
int CTimeManagement::WeeksS(int multiple=1)
  {
   return (DaysS(7)*multiple);
  }

//+------------------------------------------------------------------+
//|Returns Months in seconds                                         |
//+------------------------------------------------------------------+
int CTimeManagement::MonthsS(int multiple=1)
  {
   return (WeeksS(4)*multiple);
  }

//+------------------------------------------------------------------+
//|Returns Years in seconds                                          |
//+------------------------------------------------------------------+
int CTimeManagement::YearsS(int multiple=1)
  {
   return (MonthsS(12)*multiple);
  }

//+------------------------------------------------------------------+
//|Returns the Year for a specific date                              |
//+------------------------------------------------------------------+
int CTimeManagement::ReturnYear(datetime time)
  {
   TimeToStruct(time,timeFormat);
   return timeFormat.year;
  }

//+------------------------------------------------------------------+
//|Returns the Month for a specific date                             |
//+------------------------------------------------------------------+
int CTimeManagement::ReturnMonth(datetime time)
  {
   TimeToStruct(time,timeFormat);
   return timeFormat.mon;
  }

//+------------------------------------------------------------------+
//|Returns the Day for a specific date                               |
//+------------------------------------------------------------------+
int CTimeManagement::ReturnDay(datetime time)
  {
   TimeToStruct(time,timeFormat);
   return timeFormat.day;
  }

//+------------------------------------------------------------------+
//|Will return a datetime type of a date with an subtraction offset  |
//|in seconds                                                        |
//+------------------------------------------------------------------+
datetime CTimeManagement::TimeMinusOffset(datetime standardtime,int timeoffset)
  {
   standardtime-=timeoffset;
   return standardtime;
  }

//+------------------------------------------------------------------+
//|Will return a datetime type of a date with an addition offset     |
//|in seconds                                                        |
//+------------------------------------------------------------------+
datetime CTimeManagement::TimePlusOffset(datetime standardtime,int timeoffset)
  {
   standardtime+=timeoffset;
   return standardtime;
  }
//+------------------------------------------------------------------+
