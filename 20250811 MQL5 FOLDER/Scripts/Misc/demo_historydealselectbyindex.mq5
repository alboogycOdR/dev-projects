//+------------------------------------------------------------------+
//|                                Demo_HistoryDealSelectByIndex.mq5 |
//|                        Copyright 2010, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2010, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "1.00"

input long my_magic=111;
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

   int returns=0;
   double profit=0;
   double loss=0;
//--- proceed all the deals from the history
   for(int i=0;i<deals;i++)
     {
      //--- get ticket of the deal by its index in the list
      ulong deal_ticket=HistoryDealGetTicket(i);
      if(deal_ticket>0) // deal has been selected, let's proceed it
        {
         string symbol=HistoryDealGetString(deal_ticket,DEAL_SYMBOL);
         datetime time=HistoryDealGetInteger(deal_ticket,DEAL_TIME);
         ulong order=HistoryDealGetInteger(deal_ticket,DEAL_ORDER);
         long order_magic=HistoryDealGetInteger(deal_ticket,DEAL_MAGIC);
         long pos_ID=HistoryDealGetInteger(deal_ticket,DEAL_POSITION_ID);
         ENUM_DEAL_ENTRY entry_type=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket,DEAL_ENTRY);

         //--- proceed deal with specified DEAL_MAGIC
         if(order_magic==my_magic)
           {
            //... processing of deal with some DEAL_MAGIC
           }

         //--- let's calculate losses and profits
         if(entry_type==DEAL_ENTRY_OUT)
           {
            //--- increase the number of deals
            returns++;
            //--- deal result
            double result=HistoryDealGetDouble(deal_ticket,DEAL_PROFIT);
            //--- add profit to profits
            if(result>0) profit+=result;
            //--- add loss to losses
            if(result<0) loss+=result;
           }
        }
      else // error in selecting of deal
        {
         PrintFormat("Error in select of deal with index %d. Error %d",
                     i,GetLastError());
        }
     }
   //--- print results
   PrintFormat("Total %d deals with financial results. Profit=%.2f , Loss= %.2f",
               returns,profit,loss);
  }
//+------------------------------------------------------------------+
