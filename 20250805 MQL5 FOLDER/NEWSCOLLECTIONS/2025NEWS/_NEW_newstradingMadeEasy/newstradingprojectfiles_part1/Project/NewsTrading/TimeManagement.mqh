//+------------------------------------------------------------------+
//|                                                      NewsTrading |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CTimeManagement
  {

private:

   MqlDateTime       today;//private variable
   MqlDateTime       timeFormat;//private variable

public:

   bool              DateIsInRange(datetime FirstTime,datetime SecondTime,datetime compareTime);//Checks if a date is within two other dates
   bool              DateIsInRange(datetime Start,datetime End,datetime CompareStart,datetime CompareEnd);//Check if two dates(Start&End) are within CompareStart & CompareEnd
   bool              DateisToday(datetime TimeRepresented);//Checks if a date is within the current day
   int               SecondsS(int multiple=1);//Returns seconds
   int               MinutesS(int multiple=1);//Returns Minutes in seconds
   int               HoursS(int multiple=1);//Returns Hours in seconds
   int               DaysS(int multiple=1);//Returns Days in seconds
   int               WeeksS(int multiple=1);//Returns Weeks in seconds
   int               MonthsS(int multiple=1);//Returns Months in seconds
   int               YearsS(int multiple=1);//Returns Years in seconds
   int               ReturnYear(datetime time);//Returns the Year for a specific date
   datetime          TimeMinusOffset(datetime standardtime,int timeoffset);//Will return a datetime type of a date with an subtraction offset in seconds
   datetime          TimePlusOffset(datetime standardtime,int timeoffset);//Will return a datetime type of a date with an addition offset in seconds
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CTimeManagement::DateIsInRange(datetime FirstTime,datetime SecondTime,datetime compareTime)
  {
   if(FirstTime<=compareTime&&SecondTime>compareTime)
     {
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CTimeManagement::DateIsInRange(datetime Start,datetime End,datetime CompareStart,datetime CompareEnd)
  {
   if(Start<=CompareStart&&CompareEnd<End)
     {
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CTimeManagement::DateisToday(datetime TimeRepresented)
  {
   MqlDateTime TiM;
   TimeToStruct(TimeRepresented,TiM);
   TimeCurrent(today);
   if(TiM.year==today.year&&TiM.mon==today.mon&&TiM.day==today.day)
     {
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CTimeManagement::SecondsS(int multiple=1)
  {
   return (1*multiple);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CTimeManagement::MinutesS(int multiple=1)
  {
   return (SecondsS(60)*multiple);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CTimeManagement::HoursS(int multiple=1)
  {
   return (MinutesS(60)*multiple);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CTimeManagement::DaysS(int multiple=1)
  {
   return (HoursS(24)*multiple);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CTimeManagement::WeeksS(int multiple=1)
  {
   return (DaysS(7)*multiple);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CTimeManagement::MonthsS(int multiple=1)
  {
   return (WeeksS(4)*multiple);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CTimeManagement::YearsS(int multiple=1)
  {
   return (MonthsS(12)*multiple);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CTimeManagement::ReturnYear(datetime time)
  {
   TimeToStruct(time,timeFormat);
   return timeFormat.year;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime CTimeManagement::TimeMinusOffset(datetime standardtime,int timeoffset)
  {
   standardtime-=timeoffset;
   return standardtime;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime CTimeManagement::TimePlusOffset(datetime standardtime,int timeoffset)
  {
   standardtime+=timeoffset;
   return standardtime;
  }
//+------------------------------------------------------------------+
