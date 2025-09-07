//+------------------------------------------------------------------+
//|                                                CLOSEMYORDERS.mq5 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#define                                  ID_OWN_MAG_NUM 9999999         // ALWAYS:  use MagicNumber of the expert, to avoid MIX
#define EXPERT_MAGIC 123456   // MagicNumber of the expert

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+

void deletePendingOrder( )
  {
//--- declare and initialize the trade request and result of trade request
   MqlTradeRequest request= {};
   MqlTradeResult  result= {};
   int total=OrdersTotal(); // total number of placed pending orders
//--- iterate over all placed pending orders
   for(int i=total-1; i>=0; i--)
     {
      ulong  order_ticket=OrderGetTicket(i);                   // order ticket
      ulong  exmagic=OrderGetInteger(ORDER_MAGIC);
      string order_symbol=OrderGetString(ORDER_SYMBOL);              // MagicNumber of the order
      //--- if the MagicNumber matches
     
         //--- zeroing the request and result values
         ZeroMemory(request);
         ZeroMemory(result);
         //--- setting the operation parameters
         request.action=TRADE_ACTION_REMOVE;                   // type of trade operation
         request.order = order_ticket;                         // order ticket
         //--- send the request
         if(!OrderSend(request,result))
            PrintFormat("deletePOrderSend error %d",GetLastError());  // if unable to send the request, output the error code
         //--- information about the operation
         PrintFormat("deletePretcode=%u  deal=%I64u  order=%I64u",result.retcode,result.deal,result.order);
         
     }
  }
void OnStart()
  {
  
  deletePendingOrder();
  
  
// .DEF + .INIT the trade request and result of trade request
   MqlTradeRequest request;MqlTradeResult  result;int             
   total = PositionsTotal();                                        // .GET  number of open positions
   for(int i = total - 1; i >= 0; i--)                                  // .ITER  over all open positions
     {
      //        .GET  params of the order:
      ulong  position_ticket  = PositionGetTicket(i);                                       //  - ticket of the position
      string position_symbol  = PositionGetString(POSITION_SYMBOL);                         //  - symbol
      int    digits           = (int) SymbolInfoInteger(position_symbol,
                                SYMBOL_DIGITS
                                                       );                                 //  - number of decimal places
      ulong  magic            = PositionGetInteger(POSITION_MAGIC);                         //  - MagicNumber of the position
      double volume           = PositionGetDouble(POSITION_VOLUME);                         //  - volume of the position
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);     //  - type of the position
      ZeroMemory(request);                                    //     .CLR data
      ZeroMemory(result);                                     //     .CLR data
      //     .SET:
      request.action    = TRADE_ACTION_DEAL;                  //          - type of trade operation
      request.position  = position_ticket;                    //          - ticket of the position
      request.symbol    = position_symbol;                    //          - symbol
      request.volume    = volume;                             //          - volume of the position
      request.deviation = 5;                                  //          - allowed deviation from the price
      request.magic     = EXPERT_MAGIC;                       //          - MagicNumber of the position

      if(type == POSITION_TYPE_BUY)
        {
         request.price = SymbolInfoDouble(position_symbol, SYMBOL_BID);
         request.type  = ORDER_TYPE_SELL;
        }
      else
        {
         request.price = SymbolInfoDouble(position_symbol, SYMBOL_ASK);
         request.type  = ORDER_TYPE_BUY;
        }
      if(!OrderSend(request,result))
         PrintFormat("INF:  OrderSend(Tkt[#%I64d], ... ) call ret'd error %d", position_ticket,GetLastError());
     }
  }















//+------------------------------------------------------------------+
