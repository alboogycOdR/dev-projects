//+------------------------------------------------------------------+
//|                                           TradeNotifications.mq5 |
//|                                                No Copyright 2024 |
//|                                               mstrkidd@proton.me |
//+------------------------------------------------------------------+
#property copyright "No Copyright 2024"
#property link      "mstrkidd@proton.me"
#property version   "1.00"

#include <TradeNotifications.mqh>

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
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
//--- Send notifications for trades opening and closing
   SendPushNotification(true,true);

//--- Send notifications for trades opening, not closing
   SendPushNotification(true,false);
   
//--- Send notifications for trades closing, not opening
   SendPushNotification(false,true);
   
//--- Send notifications for neither opening or closing trades
   SendPushNotification(false,false);
  }
//+------------------------------------------------------------------+