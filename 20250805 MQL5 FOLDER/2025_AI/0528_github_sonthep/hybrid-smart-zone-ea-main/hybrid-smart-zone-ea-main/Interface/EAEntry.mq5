//+------------------------------------------------------------------+
//| Expert Advisor Entry Point - Interface Layer                     |
//+------------------------------------------------------------------+
#include "../Application/EAController.mqh"

input double   RiskPercent       = 1.5;
input int      MaxSpreadPoints   = 30;
input double   MaxDrawdown       = 8.0;
input double   EquityStopLoss    = 10.0;
input int      EMA_Period        = 200;
input int      ADX_Period        = 14;
input int      RSI_Period        = 14;
input int      BB_Period         = 20;
input double   BB_Deviation      = 2.0;
input int      ATR_Period        = 14;
input int      MACD_Fast         = 12;
input int      MACD_Slow         = 26;
input int      MACD_Signal       = 9;
input ENUM_TIMEFRAMES TF         = PERIOD_M15;

EAController controller(
   EMA_Period, ADX_Period, RSI_Period, BB_Period, BB_Deviation, ATR_Period,
   MACD_Fast, MACD_Slow, MACD_Signal, TF, RiskPercent
);

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   return(controller.OnInit());
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   controller.OnDeinit(reason);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   controller.OnTick();
  }
//+------------------------------------------------------------------+ 