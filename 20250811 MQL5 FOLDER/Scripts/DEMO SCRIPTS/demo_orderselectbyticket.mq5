//+------------------------------------------------------------------+
//|                                     Demo_OrderSelectByTicket.mq5 |
//|                        Copyright 2010, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2010, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "1.00"
#property script_show_inputs

input ulong ticket=2507773;
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//---
   bool selected=OrderSelect(ticket);
   if(selected)
     {
      double price_open=OrderGetDouble(ORDER_PRICE_OPEN);
      datetime time_setup=OrderGetInteger(ORDER_TIME_SETUP);
      string symbol=OrderGetString(ORDER_SYMBOL);
      PrintFormat("Order #%d on %s has been placed %s",ticket,symbol,TimeToString(time_setup));
     }
   else
     {
      PrintFormat("Error in select of order with ticket %d. Error %d",ticket, GetLastError());
     }
  }
//+------------------------------------------------------------------+
