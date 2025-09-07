//+------------------------------------------------------------------+
//|                                         RightWorkWithHistory.mq5 |
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
//--- variable, set to true only when trade history has changed
   bool TradeHistoryChanged=true;
//--- here we check change of trade history and set TradeHistoryChanged=true if it necessary
   TradeHistoryChanged=true; // put here the real code that checks the change in the history

//--- check is there any changes in trade history
   if(!TradeHistoryChanged) return;

//--- history has changed, so, it necesssary to load it into the cache
//--- get history up to current server time
   datetime end=TimeCurrent();
//--- starting from the date 3 days ago
   datetime start=end-3*PeriodSeconds(PERIOD_D1);
//--- get trade history of 3 last days
   HistorySelect(start,end);
//--- get the number of historical orders from the cache
   int history_orders=HistoryOrdersTotal();
//--- proceed all orders
   for(int i=0;i<history_orders;i++)
     {
      //--- get ticket of order in the history
      ulong ticket=HistoryOrderGetTicket(i);
      //--- get its properties
      //--- get other order properties by its ticket
      long order_magic     =HistoryOrderGetInteger(ticket,ORDER_MAGIC);
      datetime time_setup  =HistoryOrderGetInteger(ticket,ORDER_TIME_SETUP);
      datetime time_done   =HistoryOrderGetInteger(ticket,ORDER_TIME_DONE);
      long position_ID     =HistoryOrderGetInteger(ticket,ORDER_POSITION_ID);
      ENUM_ORDER_TYPE type =(ENUM_ORDER_TYPE)HistoryOrderGetInteger(ticket,ORDER_TYPE);
      double volume_initial=HistoryOrderGetDouble(ticket,ORDER_VOLUME_INITIAL);
      double price_open    =HistoryOrderGetDouble(ticket,ORDER_PRICE_OPEN);
      string order_comment =HistoryOrderGetString(ticket,ORDER_COMMENT);
      string order_symbol  =HistoryOrderGetString(ticket,ORDER_SYMBOL);
      PrintFormat("%d:  #%d %s to %s placed %s, executed %s at price %G and its posID=%d",
                  i,ticket,EnumToString(type),order_symbol,TimeToString(time_setup),
                  TimeToString(time_done),price_open,position_ID);
     }

//--- get number of deals into the cache
   int deals=HistoryDealsTotal();
//--- proceed all the deals
   for(int i=0;i<deals;i++)
     {
      //--- get deal ticket
      ulong ticket=HistoryDealGetTicket(i);
      //--- get properties of the deal
      //--- get other deal properties by its ticket
      long order_magic     =HistoryDealGetInteger(ticket,DEAL_MAGIC);
      datetime time        =HistoryDealGetInteger(ticket,DEAL_TIME);
      long position_ID     =HistoryDealGetInteger(ticket,DEAL_POSITION_ID);
      ENUM_ORDER_TYPE type =(ENUM_ORDER_TYPE)HistoryDealGetInteger(ticket,DEAL_TYPE);
      double volume        =HistoryDealGetDouble(ticket,DEAL_VOLUME);
      double price         =HistoryDealGetDouble(ticket,DEAL_PRICE);
      string order_comment =HistoryDealGetString(ticket,DEAL_COMMENT);
      string deal_symbol   =HistoryDealGetString(ticket,DEAL_SYMBOL);
      PrintFormat("%d: deal #%d %s volume %G at %s completed %s at price %G, and its posID=%d",
                  i, ticket, EnumToString(type),volume, deal_symbol, TimeToString(time),
                  price,position_ID);
     }
  }
//+------------------------------------------------------------------+
