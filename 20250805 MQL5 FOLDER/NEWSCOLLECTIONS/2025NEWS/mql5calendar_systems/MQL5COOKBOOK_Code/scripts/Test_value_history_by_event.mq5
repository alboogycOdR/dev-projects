//+------------------------------------------------------------------+
//|                                  Test_value_history_by_event.mq5 |
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
//--- NFP
   CiCalendarInfo nfp_info;
   ulong nfp_id = 840030016;
   if(nfp_info.Init(NULL, WRONG_VALUE, nfp_id))
     {
      SiTimeSeries nfp_ts;
      if(nfp_info.ValueHistorySelectByEvent(nfp_ts, 0, ::TimeTradeServer()))
         nfp_ts.Print(0);
     }
  }
//+------------------------------------------------------------------+

