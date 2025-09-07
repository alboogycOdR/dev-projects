//+------------------------------------------------------------------+
//|                                           TEST-START-ENGINES.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"


#ifdef __MQL5__
      #include <WinAPI\winapi.mqh>
      #define MT_WMCMD_EXPERTS   32851
#else
      #define HANDLE       int
      #define PVOID        int
      
      #import "user32.dll"
      HANDLE   GetAncestor(HANDLE hwnd, uint flags);
      int      PostMessageW(HANDLE hwnd, uint Msg, PVOID param, PVOID param);
      #import
      #define MT_WMCMD_EXPERTS   33020
#endif

#define WM_COMMAND 0x0111
#define GA_ROOT    2



//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   AlgoTradingStatus(false);
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void AlgoTradingStatus(bool Enable)
{
   bool Status = (bool) TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
   if((Enable && Status) || (!Enable && !Status))
      return;
   HANDLE
   hChart      = (HANDLE) ChartGetInteger(ChartID(), CHART_WINDOW_HANDLE),
   hMetaTrader = GetAncestor(hChart, GA_ROOT);
   PostMessageW(hMetaTrader, WM_COMMAND, MT_WMCMD_EXPERTS, 1);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
//---
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
//---
}
//+------------------------------------------------------------------+
