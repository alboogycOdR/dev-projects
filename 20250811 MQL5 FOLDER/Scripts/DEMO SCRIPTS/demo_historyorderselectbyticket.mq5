//+------------------------------------------------------------------+
//|                              Demo_HistoryOrderSelectByTicket.mq5 |
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
// --- time interval of the trade history needed
   datetime end=TimeCurrent();                 // current server time
   datetime start=end-PeriodSeconds(PERIOD_D1);// decrease 1 day
//--- request of trade history needed into the cache of MQL5 program
   HistorySelect(start,end);
//---  get total number of orders in history
   int history_orders=HistoryOrdersTotal();
//--- get ticket of the order with last index in the list
   ulong order_ticket=HistoryOrderGetTicket(history_orders-1);
   if(order_ticket>0) // order has been selected, let's proceed it
     {
      //--- order state
      ENUM_ORDER_STATE state=(ENUM_ORDER_STATE)HistoryOrderGetInteger(order_ticket,ORDER_STATE);
      long order_magic=HistoryOrderGetInteger(order_ticket,ORDER_MAGIC);
      long pos_ID=HistoryOrderGetInteger(order_ticket,ORDER_POSITION_ID);
      PrintFormat("Order #%d: ORDER_MAGIC=#%d, ORDER_STATE=%d, ORDER_POSITION_ID=%d",
                  order_ticket,order_magic,EnumToString(state),pos_ID);

     }
   else              // error in order selection
     {
      PrintFormat("Total %d orders in the history, error in select of order"+
                  " with index %d. Error %d",history_orders,history_orders-1,GetLastError());
     }
  }
//+------------------------------------------------------------------+
