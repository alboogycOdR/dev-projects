//+------------------------------------------------------------------+
//|                                 Test_structures_descriptions.mq5 |
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
//--- 1) events by country
   CiCalendarInfo calendar_info;
   ulong country_id = 276; // Germany
   if(calendar_info.Init(NULL, country_id))
     {
      MqlCalendarEvent events[];
      if(calendar_info.EventsByCountryDescription(events))
        {
         Print("\n---== Events selected by country ==---");
         PrintFormat("   Country id: %I64u", country_id);
         PrintFormat("   Events number: %d", ::ArraySize(events));
        }
     }
   calendar_info.Deinit();
//--- 2) events by currency
   string country_currency = "EUR";
   if(calendar_info.Init(country_currency))
     {
      MqlCalendarEvent events[];
      if(calendar_info.EventsByCurrencyDescription(events))
        {
         Print("\n---== Events selected by currency ==---");
         PrintFormat("   Currency: %s", country_currency);
         PrintFormat("   Events number: %d", ::ArraySize(events));
        }
     }
  }
//+------------------------------------------------------------------+
