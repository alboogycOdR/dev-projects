//+------------------------------------------------------------------+
//|                                        iTestCftcNetPositions.mq5 |
//|                                           Copyright 2021, denkir |
//|                             https://www.mql5.com/en/users/denkir |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, denkir"
#property link      "https://www.mql5.com/en/users/denkir"
#property version   "1.00"
//--- props
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1 DRAW_LINE
#property indicator_color1 clrBlueViolet
#property indicator_width1 2
//--- include
#include "..\Include\CalendarInfo.mqh"
//+------------------------------------------------------------------+
//| CFTC Non-Commercial Net Positions                                |
//+------------------------------------------------------------------+
enum ENUM_NON_COM_NET_POSITIONS
  {
   NON_COM_NET_POSITIONS_COPPER = 0,      // Copper
   NON_COM_NET_POSITIONS_SILVER = 1,      // Silver
   NON_COM_NET_POSITIONS_GOLD = 2,        // Gold
   NON_COM_NET_POSITIONS_CRUDE_OIL = 3,   // Crude oil
   NON_COM_NET_POSITIONS_SP_500 = 4,      // S&P 500
   NON_COM_NET_POSITIONS_AlUMINIUM = 5,   // Aluminium
   NON_COM_NET_POSITIONS_CORN = 6,        // Corn
   NON_COM_NET_POSITIONS_NGAS = 7,        // Natural gas
   NON_COM_NET_POSITIONS_SOYBEANS = 8,    // Soybeans
   NON_COM_NET_POSITIONS_WHEAT = 9,       // Wheat
   NON_COM_NET_POSITIONS_NASDAQ_100 = 10, // Nasdaq 100
  };
//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input ENUM_NON_COM_NET_POSITIONS InpNetPositionsType =
   NON_COM_NET_POSITIONS_SP_500; // Net positions type
input bool InpTpLog = true;      // To log new events?
//+------------------------------------------------------------------+
//| Globals                                                          |
//+------------------------------------------------------------------+
double gBuffer[];               // indicator buffer
CiCalendarInfo *gPtrEventsInfo; // events by country
CiCalendarInfo *gPtrValuesInfo; // values by event id
datetime gLastValueDate;
double gLastValue;
ulong gChangeId;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   ::SetIndexBuffer(0, gBuffer, INDICATOR_DATA);
   ::PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
//--- globals
   if(::CheckPointer(gPtrEventsInfo) == POINTER_DYNAMIC)
      delete gPtrEventsInfo;
   if(::CheckPointer(gPtrValuesInfo) == POINTER_DYNAMIC)
      delete gPtrValuesInfo;
   gPtrEventsInfo = new CiCalendarInfo;
   if(!::CheckPointer(gPtrEventsInfo) == POINTER_DYNAMIC)
      return INIT_FAILED;
   gPtrValuesInfo = new CiCalendarInfo;
   if(!::CheckPointer(gPtrValuesInfo) == POINTER_DYNAMIC)
      return INIT_FAILED;
   gLastValueDate = 0;
   gLastValue = 0.;
   gChangeId = 0;
//---
   return INIT_SUCCEEDED;
  }
//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(::CheckPointer(gPtrEventsInfo) == POINTER_DYNAMIC)
      delete gPtrEventsInfo;
   if(::CheckPointer(gPtrValuesInfo) == POINTER_DYNAMIC)
      delete gPtrValuesInfo;
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
//--- first call
   if(prev_calculated == 0)
     {
      //--- initialize buffer
      ::ArrayInitialize(gBuffer, EMPTY_VALUE);
      //--- 1) collect all events by country
      ulong country_id = 840; // US
      if(gPtrEventsInfo.Init(NULL, country_id))
        {
         MqlCalendarEvent events[];
         if(gPtrEventsInfo.EventsByCountryDescription(events, false))
           {
            string event_code_substr = GetEventCodeSubstring();
            if(event_code_substr != NULL)
               for(int ev_idx = 0; ev_idx <::ArraySize(events); ev_idx++)
                 {
                  MqlCalendarEvent curr_event = events[ev_idx];
                  if(::StringFind(curr_event.event_code, event_code_substr) > -1)
                    {
                     //--- 2) collect all values by event id
                     if(gPtrValuesInfo.Init(NULL, WRONG_VALUE, curr_event.id))
                       {
                        SiTimeSeries net_positions_ts;
                        if(gPtrValuesInfo.ValueHistorySelectByEvent(net_positions_ts, 0))
                          {
                           string net_positions_name;
                           SiTsObservation ts_observations[];
                           if(net_positions_ts.GetSeries(ts_observations, net_positions_name))
                             {
                              //--- consider only past observations
                              int new_size = 0;
                              for(int obs_idx =::ArraySize(ts_observations) - 1; obs_idx >= 0; obs_idx--)
                                {
                                 if(ts_observations[obs_idx].val != EMPTY_VALUE)
                                    break;
                                 new_size = obs_idx;
                                }
                              if(new_size > 0)
                                 ::ArrayResize(ts_observations, new_size);
                              //--- find the starting date
                              datetime start_dtime, ts_start_dtime;
                              start_dtime = time[0];
                              ts_start_dtime = ts_observations[0].time;
                              if(ts_start_dtime > start_dtime)
                                 start_dtime = ts_start_dtime;
                              ::IndicatorSetString(INDICATOR_SHORTNAME, net_positions_name);
                              ::IndicatorSetInteger(INDICATOR_DIGITS, 1);
                              //---
                              int start_bar_idx =::iBarShift(_Symbol, _Period, ts_start_dtime);
                              if(start_bar_idx > -1)
                                {
                                 start_bar_idx = rates_total - start_bar_idx;
                                 uint observations_cnt = 0;
                                 SiTsObservation curr_observation = ts_observations[observations_cnt];
                                 uint ts_size = ::ArraySize(ts_observations);
                                 for(int bar = start_bar_idx; bar < rates_total; bar++)
                                   {
                                    if((observations_cnt + 1) < ts_size)
                                      {
                                       SiTsObservation next_observation =
                                          ts_observations[observations_cnt + 1];
                                       if(time[bar] >= next_observation.time)
                                         {
                                          curr_observation = next_observation;
                                          gLastValueDate = curr_observation.time;
                                          gLastValue = curr_observation.val;
                                          observations_cnt++;
                                         }
                                      }
                                    gBuffer[bar] = curr_observation.val;
                                   }
                                 //--- just to get a change id
                                 MqlCalendarValue values[];
                                 gPtrValuesInfo.ValueLastSelectByEvent(gChangeId, values);
                                }
                             }
                          }
                       }
                     break;
                    }
                 }
           }
        }
     }
//---
   else
     {
      MqlCalendarValue values[];
      if(gPtrValuesInfo.ValueLastSelectByEvent(gChangeId, values) > 0)
         if(values[0].time > gLastValueDate)
           {
            gLastValueDate = values[0].time;
            gLastValue = values[0].GetActualValue();
            //--- to log
            if(InpTpLog)
              {
               ::Print("\n---== New event value ==---");
               ::PrintFormat("   Time: %s", ::TimeToString(gLastValueDate));
               datetime server_time =::TimeTradeServer();
               ::PrintFormat("   Release time: %s", ::TimeToString(server_time));
               ::PrintFormat("   Actual value: %0.1f", gLastValue);
              }
           }
      //--- if a new bar
      if(rates_total > prev_calculated)
         for(int bar = prev_calculated; bar < rates_total; bar++)
            gBuffer[bar] = gLastValue;
     }
//--- return value of prev_calculated for next call
   return rates_total;
  }
//+------------------------------------------------------------------+
//| Get event id by positions type                                   |
//+------------------------------------------------------------------+
string GetEventCodeSubstring(void)
  {
   string event_code_substr = NULL;
   switch(InpNetPositionsType)
     {
      case NON_COM_NET_POSITIONS_COPPER:
        {
         event_code_substr = "copper";
         break;
        }
      case NON_COM_NET_POSITIONS_SILVER:
        {
         event_code_substr = "silver";
         break;
        }
      case NON_COM_NET_POSITIONS_GOLD:
        {
         event_code_substr = "gold";
         break;
        }
      case NON_COM_NET_POSITIONS_CRUDE_OIL:
        {
         event_code_substr = "crude-oil";
         break;
        }
      case NON_COM_NET_POSITIONS_SP_500:
        {
         event_code_substr = "sp-500";
         break;
        }
      case NON_COM_NET_POSITIONS_AlUMINIUM:
        {
         event_code_substr = "aluminium";
         break;
        }
      case NON_COM_NET_POSITIONS_CORN:
        {
         event_code_substr = "corn";
         break;
        }
      case NON_COM_NET_POSITIONS_NGAS:
        {
         event_code_substr = "natural-gas";
         break;
        }
      case NON_COM_NET_POSITIONS_SOYBEANS:
        {
         event_code_substr = "soybeans";
         break;
        }
      case NON_COM_NET_POSITIONS_WHEAT:
        {
         event_code_substr = "wheat";
         break;
        }
      case NON_COM_NET_POSITIONS_NASDAQ_100:
        {
         event_code_substr = "nasdaq-100";
         break;
        }
     }
   return event_code_substr;
  }
//+------------------------------------------------------------------+
