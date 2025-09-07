//+------------------------------------------------------------------+
//|                                            SymbolInfoSession.mq5 |
//|                        Copyright 2010, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2010, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//|  Display information about quotation sessions                    |
//+------------------------------------------------------------------+
void PrintInfoForQuoteSessions(string symbol,ENUM_DAY_OF_WEEK day)
  {
//--- Start and end of a session
   datetime start,finish;
   uint session_index=0;
   bool session_exist=true;

//--- get over all sessions of the current day
   while(session_exist)
     {
      //--- check if there is a quotation session with the number of session_index
      session_exist=SymbolInfoSessionQuote(symbol,day,session_index,start,finish);

      //--- if such session exists
      if(session_exist)
        {
         //--- display day of week, session number, start and end time
         Print(DayToString(day),": session index=",session_index,"  start=",
               TimeToString(start,TIME_MINUTES),"    finish=",TimeToString(finish-1,TIME_MINUTES|TIME_SECONDS));
        }
      //--- increase the counter of sessions
      session_index++;
     }
  }
//+------------------------------------------------------------------+
//|  Display information about trade sessions                        |
//+------------------------------------------------------------------+
void PrintInfoForTradeSessions(string symbol,ENUM_DAY_OF_WEEK day)
  {
//--- Start and end of a session
   datetime start,finish;
   uint session_index=0;
   bool session_exist=true;

//--- get over all sessions of the current day
   while(session_exist)
     {
      //--- check if there is a trade session with the number session_index
      session_exist=SymbolInfoSessionTrade(symbol,day,session_index,start,finish);

      //--- if such session exists
      if(session_exist)
        {
         //--- display day of week, session number, start and end time
         Print(DayToString(day)
         ,": session index=",session_index
         ,"  start=",TimeToString(start,TIME_MINUTES),
          "    finish=",TimeToString(finish-1,TIME_MINUTES|TIME_SECONDS));
        }
      //--- increase the counter of sessions
      session_index++;
     }
  }
//+------------------------------------------------------------------+
//| Get the string representation of the day of week                 |
//+------------------------------------------------------------------+
string DayToString(ENUM_DAY_OF_WEEK day)
  {
   switch(day)
     {
      case SUNDAY:    return "Sunday";
      case MONDAY:    return "Monday";
      case TUESDAY:   return "Tuesday";
      case WEDNESDAY: return "Wednesday";
      case THURSDAY:  return "Thursday";
      case FRIDAY:    return "Friday";
      case SATURDAY:  return "Saturday";
      default:        return "Unknown day of week";
     }
   return "";
  }
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//--- the array where the days of week are stored
   ENUM_DAY_OF_WEEK days[]=
   {
    SUNDAY,
    MONDAY,
    TUESDAY,
    WEDNESDAY,
    THURSDAY,
    FRIDAY,
    SATURDAY
    };

   int size=ArraySize(days);

//---
   Print("Quotation sessions");
//--- go over all the days of week
   for(int d=0;d<size;d++)
     {
      PrintInfoForQuoteSessions(Symbol(),days[d]);
     }

//---
   Print("Trade sessions");
//--- go over all the days of week
   for(int d=0;d<size;d++)
     {
      PrintInfoForTradeSessions(Symbol(),days[d]);
     }
  }
//+------------------------------------------------------------------+
