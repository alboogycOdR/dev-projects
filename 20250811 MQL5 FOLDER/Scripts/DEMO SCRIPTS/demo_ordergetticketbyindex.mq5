//+------------------------------------------------------------------+
//|                                   Demo_OrderGetTicketByIndex.mq5 |
//|                        Copyright 2010, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2010, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "1.00"
#property script_show_inputs

input long my_magic=555;
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//--- get total number of orders
   int orders=OrdersTotal();
//--- proceed all orders
   for(int i=0;i<orders;i++)
     {
      ResetLastError();
      //--- copy the order data (by its index) into the cache
      ulong ticket=OrderGetTicket(i);
      if(ticket!=0)// if the order has been successfully copied into the cache, proceed it
        {
         double price_open=OrderGetDouble(ORDER_PRICE_OPEN);
         datetime time_setup=OrderGetInteger(ORDER_TIME_SETUP);
         string symbol=OrderGetString(ORDER_SYMBOL);
         long magic_number=OrderGetInteger(ORDER_MAGIC);
         if(magic_number==my_magic)
           {
            //  processing of order with some ORDER_MAGIC
           }
         PrintFormat("Order #%d on %s has been placed %s, ORDER_MAGIC=%d",ticket,symbol,TimeToString(time_setup),magic_number);
        }
      else         // error in call of OrderGetTicket()
        {
         PrintFormat("Error in loading of order data into the cache. Error code: %d",GetLastError());
        }
     }
  }
//+------------------------------------------------------------------+
