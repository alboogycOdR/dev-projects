//+------------------------------------------------------------------+
//|                                      Test_enums_descriptions.mq5 |
//|                                           Copyright 2021, denkir |
//|                             https://www.mql5.com/en/users/denkir |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, denkir"
#property link      "https://www.mql5.com/en/users/denkir"
#property version   "1.00"
//--- include
#include "..\Include\CalendarInfo.mqh"
#include <Math\Stat\Uniform.mqh>
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
   {
   CiCalendarInfo calendar_info;
   ulong country_id = 826; // UK
   if(calendar_info.Init(NULL, country_id))
      {
      MqlCalendarEvent events[];
      if(calendar_info.EventsByCountryDescription(events))
         {
         ::MathSrand(77);
         int events_num =::ArraySize(events);
         int n = 10;
         MqlCalendarEvent events_selected[];
         ::ArrayResize(events_selected, n);
         for(int ev_idx = 0; ev_idx < n; ev_idx++)
            {
            int rand_val =::MathRand();
            int rand_idx = rand_val % events_num;
            events_selected[ev_idx] = events[rand_idx];
            }
         //--- 0) name
         ::Print("\n---== Name ==---");
         for(int ev_idx = 0; ev_idx < n; ev_idx++)
            {
            MqlCalendarEvent curr_event = events_selected[ev_idx];
            ::PrintFormat("   [%d] - %s", ev_idx + 1, curr_event.name);
            }
         //--- 1) type
         ::Print("\n---== Type ==---");
         for(int ev_idx = 0; ev_idx < n; ev_idx++)
            {
            MqlCalendarEvent curr_event = events_selected[ev_idx];
            ::PrintFormat("   [%d] - %s", ev_idx + 1,
                          calendar_info.EventTypeDescription(curr_event.type));
            }
         //--- 2) sector
         ::Print("\n---== Sector ==---");
         for(int ev_idx = 0; ev_idx < n; ev_idx++)
            {
            MqlCalendarEvent curr_event = events_selected[ev_idx];
            ::PrintFormat("   [%d] - %s", ev_idx + 1,
                          calendar_info.EventSectorDescription(curr_event.sector));
            }
         //--- 3) frequency
         ::Print("\n---== Frequency ==---");
         for(int ev_idx = 0; ev_idx < n; ev_idx++)
            {
            MqlCalendarEvent curr_event = events_selected[ev_idx];
            ::PrintFormat("   [%d] - %s", ev_idx + 1,
                          calendar_info.EventFrequencyDescription(curr_event.frequency));
            }
         //--- 3) time mode
         ::Print("\n---== Time mode ==---");
         for(int ev_idx = 0; ev_idx < n; ev_idx++)
            {
            MqlCalendarEvent curr_event = events_selected[ev_idx];
            ::PrintFormat("   [%d] - %s", ev_idx + 1,
                          calendar_info.EventTimeModeDescription(curr_event.time_mode));
            }
         //--- 4) unit
         ::Print("\n---== Unit ==---");
         for(int ev_idx = 0; ev_idx < n; ev_idx++)
            {
            MqlCalendarEvent curr_event = events_selected[ev_idx];
            ::PrintFormat("   [%d] - %s", ev_idx + 1,
                          calendar_info.EventUnitDescription(curr_event.unit));
            }
         //--- 5) importance
         ::Print("\n---== Importance ==---");
         for(int ev_idx = 0; ev_idx < n; ev_idx++)
            {
            MqlCalendarEvent curr_event = events_selected[ev_idx];
            ::PrintFormat("   [%d] - %s", ev_idx + 1,
                          calendar_info.EventImportanceDescription(curr_event.importance));
            }
         //--- 6) multiplier
         ::Print("\n---== Multiplier ==---");
         for(int ev_idx = 0; ev_idx < n; ev_idx++)
            {
            MqlCalendarEvent curr_event = events_selected[ev_idx];
            ::PrintFormat("   [%d] - %s", ev_idx + 1,
                          calendar_info.EventMultiplierDescription(curr_event.multiplier));
            }
         //--- 7) impact
         MqlCalendarValue values_by_event[];
         datetime start_dt, stop_dt;
         start_dt = D'01.01.2021';
         stop_dt = D'01.11.2021';
         ::Print("\n---== Impact ==---");
         for(int ev_idx = 0; ev_idx < n; ev_idx++)
            {
            MqlCalendarEvent curr_event = events_selected[ev_idx];
            CiCalendarInfo event_info;
            MqlCalendarValue ev_values[];
            if(event_info.Init(NULL, WRONG_VALUE, curr_event.id))
               if(event_info.ValueHistorySelectByEvent(ev_values, start_dt, stop_dt))
                  {
                  int ev_values_size =::ArraySize(ev_values);
                  ::PrintFormat("   [%d] - %s", ev_idx + 1,
                                calendar_info.ValueImpactDescription(ev_values[--ev_values_size].impact_type));
                  }
            }
         }
      }
   }
//+------------------------------------------------------------------+
