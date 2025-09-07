//+------------------------------------------------------------------+
//|                               Demo_HistoryOrderSelectByIndex.mq5 |
//|                        Copyright 2010, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2010, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "1.00"
#property script_show_inputs

input long my_magic=999;
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
// --- time interval of the trade history needed
   datetime end=TimeCurrent();                 // current server time
   datetime start=end-PeriodSeconds(PERIOD_D1);// decrease 1 day
//--- request of trade history needed into the cache of MQL5 program
   HistorySelect(start,end);
//--- get total number of orders in history
   int history_orders=HistoryOrdersTotal();
//--- proceed all the orders
   for(int i=0;i<history_orders;i++)
     {
      //--- get order ticket by its index
      ulong order_ticket=HistoryOrderGetTicket(i);
      if(order_ticket>0) //  get historical order, let's proceed it
        {
         //--- done time
         datetime time_done=HistoryOrderGetInteger(order_ticket,ORDER_TIME_DONE);
         long order_magic=HistoryOrderGetInteger(order_ticket,ORDER_MAGIC);
         long pos_ID=HistoryOrderGetInteger(order_ticket,ORDER_POSITION_ID);
         if(order_magic==my_magic)
           {
           //  proceessing of order with ORDER_MAGIC
           }
         PrintFormat("Order #%d: ORDER_MAGIC=#%d, time_done %s, ORDER_POSITION_ID=%d",
                     order_ticket,order_magic,TimeToString(time_done),pos_ID);
        }
      else               // error in select of order from history
        {
         PrintFormat("Error in selecting of order with index %d. Error %d",
                     i,GetLastError());
        }
     }
  }
//+------------------------------------------------------------------+
