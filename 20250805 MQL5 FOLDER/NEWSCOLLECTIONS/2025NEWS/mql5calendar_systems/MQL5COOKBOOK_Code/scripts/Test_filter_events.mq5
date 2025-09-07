//+------------------------------------------------------------------+
//|                                           Test_filter_events.mq5 |
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
   CiCalendarInfo event_calendar_info;
   if(event_calendar_info.Init("EUR"))
     {
      //--- 1) get events by name (CArrayString)
      CArrayString events_arr;
      string ev_name = "Unemployment";
      if(event_calendar_info.GetEventsByName(events_arr, ev_name))
        {
         int events_num = events_arr.Total();
         if(events_num > 0)
           {
            ::Print("\n---== CArrayString list ==---");
            ::PrintFormat("   Events list consists of %d events.", events_num);
            ::PrintFormat("   First event: %s", events_arr.At(0));
            ::PrintFormat("   Last event: %s", events_arr.At(events_num - 1));
           }
        }
      //--- 2) get events by name (MqlCalendarEvent)
      MqlCalendarEvent events[];
      if(event_calendar_info.GetEventsByName(events, ev_name))
        {
         int events_num = ::ArraySize(events);
         if(events_num > 0)
           {
            ::Print("\n---== MqlCalendarEvent array ==---");
            ::PrintFormat("   Events array consists of %d events.", events_num);
            ::PrintFormat("   First event: %s", events[0].name);
            ::PrintFormat("   Last event: %s", events[events_num - 1].name);
           }
        }
      //--- 3) filter events
      MqlCalendarEvent filtered_events[];
      int indices[2];
      indices[0] = 0;
      string events_str[2];
      events_str[0] = "First";
      events_str[1] = "Last";
      ulong filter = 0;
      filter |= FILTER_BY_IMPORTANCE_HIGH;
      if(event_calendar_info.FilterEvents(filtered_events, events, filter))
        {
         int f_events_num = ::ArraySize(filtered_events);
         ::Print("\n---== Filtered events array ==---");
         ::Print("   Filtered by: importance high");
         ::PrintFormat("   Events array consists of %d events.", ::ArraySize(filtered_events));
         if(f_events_num > 0)
           {
            indices[1] = f_events_num - 1;
            for(int ind = 0; ind <::ArraySize(indices); ind++)
              {
               MqlCalendarEvent curr_event = filtered_events[indices[ind]];
               ::PrintFormat("   \n%s event:", events_str[ind]);
               event_calendar_info.PrintEventDescription(curr_event);
              }
           }
         ::ArrayFree(filtered_events);
         filter ^= FILTER_BY_IMPORTANCE_HIGH;
        }
      filter |= FILTER_BY_IMPORTANCE_MODERATE;
      if(event_calendar_info.FilterEvents(filtered_events, events, filter))
        {
         int f_events_num = ::ArraySize(filtered_events);
         ::Print("\n---== Filtered events array ==---");
         ::Print("   Filtered by: importance medium");
         ::PrintFormat("   Events array consists of %d events.", ::ArraySize(filtered_events));
         if(f_events_num > 0)
           {
            indices[1] = f_events_num - 1;
            for(int ind = 0; ind <::ArraySize(indices); ind++)
              {
               MqlCalendarEvent curr_event = filtered_events[indices[ind]];
               ::PrintFormat("   \n%s event:", events_str[ind]);
               event_calendar_info.PrintEventDescription(curr_event);
              }
           }
         ::ArrayFree(filtered_events);
         filter ^= FILTER_BY_IMPORTANCE_MODERATE;
        }
      filter |= FILTER_BY_IMPORTANCE_LOW;
      if(event_calendar_info.FilterEvents(filtered_events, events, filter))
        {
         int f_events_num = ::ArraySize(filtered_events);
         ::Print("\n---== Filtered events array ==---");
         ::Print("   Filtered by: importance low");
         ::PrintFormat("   Events array consists of %d events.", ::ArraySize(filtered_events));
         if(f_events_num > 0)
           {
            indices[1] = f_events_num - 1;
            for(int ind = 0; ind <::ArraySize(indices); ind++)
              {
               MqlCalendarEvent curr_event = filtered_events[indices[ind]];
               ::PrintFormat("   \n%s event:", events_str[ind]);
               event_calendar_info.PrintEventDescription(curr_event);
              }
           }
         ::ArrayFree(filtered_events);
         filter ^= FILTER_BY_IMPORTANCE_LOW;
        }
      filter |= FILTER_BY_IMPORTANCE_NONE;
      if(event_calendar_info.FilterEvents(filtered_events, events, filter))
        {
         int f_events_num = ::ArraySize(filtered_events);
         ::Print("\n---== Filtered events array ==---");
         ::Print("   Filtered by: importance none");
         ::PrintFormat("   Events array consists of %d events.", ::ArraySize(filtered_events));
         if(f_events_num > 0)
           {
            indices[1] = f_events_num - 1;
            for(int ind = 0; ind <::ArraySize(indices); ind++)
              {
               MqlCalendarEvent curr_event = filtered_events[indices[ind]];
               ::PrintFormat("   \n%s event:", events_str[ind]);
               event_calendar_info.PrintEventDescription(curr_event);
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
