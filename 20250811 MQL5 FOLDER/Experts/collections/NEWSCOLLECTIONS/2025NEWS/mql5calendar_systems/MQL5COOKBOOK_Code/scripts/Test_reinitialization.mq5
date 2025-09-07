//+------------------------------------------------------------------+
//|                                        Test_reinitialization.mq5 |
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
//--- ERROR
   CiCalendarInfo calendar_info1;
   bool is_init = calendar_info1.Init("EUR");
   is_init = calendar_info1.Init("USD");
//--- OK
   CiCalendarInfo calendar_info2;
   is_init = calendar_info2.Init("EUR");
   calendar_info2.Deinit();
   is_init = calendar_info2.Init("USD");
   }
//+------------------------------------------------------------------+
