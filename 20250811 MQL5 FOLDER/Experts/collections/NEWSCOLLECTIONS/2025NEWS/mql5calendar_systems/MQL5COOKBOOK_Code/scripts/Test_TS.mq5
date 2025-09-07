//+------------------------------------------------------------------+
//|                                                      Test_TS.mq5 |
//|                                           Copyright 2021, denkir |
//|                             https://www.mql5.com/en/users/denkir |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, denkir"
#property link      "https://www.mql5.com/en/users/denkir"
#property version   "1.00"
//--- include
#include "..\Include\CalendarInfo.mqh"
#include <Graphics\Graphic.mqh>
#include <Tools\DateTime.mqh>
//---
double arrX[];
//+------------------------------------------------------------------+
//| Custom function for create values on X-axis                      |
//+------------------------------------------------------------------+
string TimeFormat(double x, void *cbdata)
  {
   string formatted_str = NULL;
   CDateTime s_dtime;
   if(::TimeToStruct((datetime)arrX[(int)x], s_dtime))
     {
      string month_name = s_dtime.MonthName();
      month_name =::StringSubstr(month_name, 0, 3);
      formatted_str =::StringFormat("%s-%d", month_name, s_dtime.year);
     }
   return formatted_str;
  }
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   ulong nfp_id = 840030016;
   MqlCalendarValue nfp_values[];
//--- boundaries of the interval
   datetime date_from = D'01.01.2016';
   datetime date_to = D'01.11.2021';
//--- get the array of values for nfp in a specified time range
   if(::CalendarValueHistoryByEvent(nfp_id, nfp_values, date_from, date_to))
     {
      int nfp_values_size = ::ArraySize(nfp_values);
      if(nfp_values_size > 0)
        {
         datetime timevals[];
         double datavals1[];
         double datavals2[];
         SiTimeSeries nfp_ts1, nfp_ts2;
         if(::ArrayResize(timevals, nfp_values_size) == nfp_values_size)
            if(::ArrayResize(datavals1, nfp_values_size) == nfp_values_size)
               if(::ArrayResize(datavals2, nfp_values_size) == nfp_values_size)
                 {
                  //--- prepare time and data values for the timeseries
                  for(int v_idx = 0; v_idx < nfp_values_size; v_idx++)
                    {
                     MqlCalendarValue curr_nfp_val = nfp_values[v_idx];
                     datetime curr_nfp_time = curr_nfp_val.period;
                     timevals[v_idx] = curr_nfp_time;
                     double curr_nfp_dataval = curr_nfp_val.GetActualValue();
                     datavals1[v_idx] = curr_nfp_dataval;
                     curr_nfp_dataval = curr_nfp_val.GetForecastValue();
                     datavals2[v_idx] = curr_nfp_dataval;
                    }
                  if(nfp_ts1.Init(timevals, datavals1, "US Nonfarm Payrolls, actual"))
                     if(nfp_ts2.Init(timevals, datavals2, "US Nonfarm Payrolls, forecast"))
                       {
                        nfp_ts1.Print(0);
                        SiTsObservation first_observation, last_observation;
                        first_observation = nfp_ts1[0];
                        last_observation = nfp_ts1[nfp_values_size - 1];
                        string time_str = ::TimeToString(first_observation.time, TIME_DATE);
                        string data_str = ::DoubleToString(first_observation.val, 0);
                        ::PrintFormat("\nFirst observation: %s, %s", time_str, data_str);
                        time_str = ::TimeToString(last_observation.time, TIME_DATE);
                        data_str = ::DoubleToString(last_observation.val, 0);
                        ::PrintFormat("Last observation: %s, %s", time_str, data_str);
                        //---
                        CGraphic graphic;
                        string gname = "NFP_Graphic";
                        if(graphic.Create(0, gname, 0, 20, 20, 750, 450))
                          {
                           graphic.Attach(0, gname);
                           int name_size = graphic.HistoryNameSize();
                           graphic.HistoryNameSize(15);
                           graphic.BackgroundMain("US Nonfarm Payrolls, 2016-2021");
                           graphic.BackgroundMainSize(18);
                           ::ArrayResize(arrX, nfp_values_size);
                           for(int t_idx = 0; t_idx < nfp_values_size; t_idx++)
                              arrX[t_idx] = (double)timevals[t_idx];
                           string curve_name = "actual";
                           CCurve *curve = graphic.CurveAdd(datavals1, CURVE_LINES, curve_name);
                           curve_name = "forecast";
                           curve = graphic.CurveAdd(datavals2, CURVE_LINES, curve_name);
                           //--- set the X-axis properties
                           CAxis *x_axis = graphic.XAxis();
                           x_axis.AutoScale(false);
                           x_axis.Type(AXIS_TYPE_CUSTOM);
                           x_axis.ValuesFunctionFormat(TimeFormat);
                           x_axis.DefaultStep(10.0);
                           //--- plot
                           graphic.CurvePlotAll();
                           graphic.Update();
                          }
                       }
                 }
        }
     }
   else
     {
      ::PrintFormat("Error! Failed to get values for event_id=%d", nfp_id);
      ::PrintFormat("Error code: %d", GetLastError());
     }
  }
//+------------------------------------------------------------------+
