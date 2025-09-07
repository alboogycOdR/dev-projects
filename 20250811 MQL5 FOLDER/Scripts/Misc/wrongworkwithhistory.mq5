//+------------------------------------------------------------------+
//|                                         WrongWorkWithHistory.mq5 |
//|                        Copyright 2010, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2010, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//---
   datetime start=0;            // starting date
   datetime end=TimeCurrent();  // finish date (current server time)
//--- load all the trade history into the cache
   HistorySelect(start,end);
//--- get total orders in history
   int history_orders=HistoryOrdersTotal();
//--- proceed all history orders
   for(int i=0;i<history_orders;i++)
     {
     //  proceed each order from history
     }   
    
    ...
         
//--- get total number of deals in the history
   int deals=HistoryDealsTotal();
//--- proceed all deals
   for(int i=0;i<deals;i++)
     {
     //  proceed each deal from the history
     }     
  }
//+------------------------------------------------------------------+
