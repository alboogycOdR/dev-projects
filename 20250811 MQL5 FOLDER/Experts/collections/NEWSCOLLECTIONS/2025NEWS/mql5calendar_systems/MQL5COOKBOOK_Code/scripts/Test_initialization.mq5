//+------------------------------------------------------------------+
//|                                          Test_initialization.mq5 |
//|                                           Copyright 2021, denkir |
//|                             https://www.mql5.com/en/users/denkir |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, denkir"
#property link      "https://www.mql5.com/en/users/denkir"
#property version   "1.00"
//--- include
#include "..\Include\CalendarInfo.mqh"
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//--- TRUE
//--- 1) all currencies, all countries, all events
   CiCalendarInfo calendar_info1;
   bool is_init = calendar_info1.Init();
//--- 2) EUR, all countries, all events
   CiCalendarInfo calendar_info2;
   is_init = calendar_info2.Init("EUR");
//--- 3) EUR, Germany, all events
   CiCalendarInfo calendar_info3;
   is_init = calendar_info3.Init("EUR", 276);
//--- 4) EUR, Germany, HICP m/m
   CiCalendarInfo calendar_info4;
   is_init = calendar_info4.Init("EUR", 276, 276010022);
//--- FALSE
//--- 5) EUR, Germany, nonfarm-payrolls
   CiCalendarInfo calendar_info5;
   is_init = calendar_info5.Init("EUR", 276, 840030016);
//--- 6) EUR, US, nonfarm-payrolls
   CiCalendarInfo calendar_info6;
   is_init = calendar_info6.Init("EUR", 840, 840030016);
//--- 7) EUR, all countries, nonfarm-payrolls
   CiCalendarInfo calendar_info7;
   is_init = calendar_info7.Init("EUR", WRONG_VALUE, 840030016);
  }
//+------------------------------------------------------------------+
