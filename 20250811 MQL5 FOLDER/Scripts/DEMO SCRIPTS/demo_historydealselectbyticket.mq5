//+------------------------------------------------------------------+
//|                               Demo_HistoryDealSelectByTicket.mq5 |
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
//--- get total number of deals in the history
   int deals=HistoryDealsTotal();
//--- get ticket of the deal with the last index in the list
   ulong deal_ticket=HistoryDealGetTicket(deals-1);
   if(deal_ticket>0) // deal has been selected, let's proceed ot
     {
      //--- ticket of the order, opened the deal
      ulong order=HistoryDealGetInteger(deal_ticket,DEAL_ORDER);
      long order_magic=HistoryDealGetInteger(deal_ticket,DEAL_MAGIC);
      long pos_ID=HistoryDealGetInteger(deal_ticket,DEAL_POSITION_ID);
      PrintFormat("Deal #%d opened by order #%d with ORDER_MAGIC=%d was in position",
                  deals-1,order,order_magic,pos_ID);

     }
   else              // error in selecting of the deal
     {
      PrintFormat("Total number of deals %d, error in selection of the deal"+
                  " with index %d. Error %d",deals,deals-1,GetLastError());
     }
  }
//+------------------------------------------------------------------+
