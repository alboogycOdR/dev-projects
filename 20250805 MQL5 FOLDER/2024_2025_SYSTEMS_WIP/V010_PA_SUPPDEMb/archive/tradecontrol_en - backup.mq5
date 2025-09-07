//+------------------------------------------------------------------+
//|                                              TradeControl_en.mq5 |
//|                                             Copyright KlimMalgin |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "KlimMalgin"
#property link      ""
#property version   "1.00"


datetime start_date = 0;   // Date, from which we begin to read history

int OrdersPrev = 0;        // Number of orders at the time of previous OnTrade() call
int PositionsPrev = 0;     // Number of positions at the time of previous OnTrade() call
ulong LastOrderTicket = 0; // Ticket of the last processed order

int _GetLastError=0;       // Error code
long state=0;              // Order state

/*
 *
 * Structure that stores information about positions
 *
 */
struct _position
{

long     type,          // Position type
         magic;         // Magic number for position
datetime time;          // Time of position opening

double   volume,        // Position volume
         priceopen,     // Position price
         sl,            // Stop Loss level for opened position
         tp,            // Take Profit level for opened position
         pricecurrent,  // Symbol current price
         comission,     // Commission
         swap,          // Accumulated swap
         profit;        // Current profit

string   symbol,        // Symbol, by which the position has been opened
         comment;       // Comment to position
};

int _ExpertPositionsTotal = 0;

_position PositionList[],  // Array that stores info about position
      PrevPositionList[];


/*
 *
 * Structure that stores information about orders
 *
 */
struct _orders
{

datetime time_setup,       // Time of order placement
         time_expiration,  // Time of order expiration
         time_done;        // Time of order execution or cancellation
         
long     type,             // Order type
         state,            // Order state
         type_filling,     // Type of execution by remainder
         type_time,        // Order lifetime
         ticket;           // Order ticket
         
long     magic,            // Id of Expert Advisor, that placed an order 
                           // (intended to ensure that each Expert 
                           // must place it's own unique number)
                           
         position_id;      // Position id, that is placed on order, 
                           // when it is executed. Each executed order invokes a 
                           // deal, that opens new or changes existing 
                           // position. Id of that position is placed on 
                           // executed order in this moment.
                           
double volume_initial,     // Initial volume on order placement
       volume_current,     // Unfilled volume
       price_open,         // Price, specified in the order
       sl,                 // Stop Loss level
       tp,                 // Take Profit level
       price_current,      // Current price by order symbol
       price_stoplimit;    // Price of placing Limit order when StopLimit order is triggered
       
string symbol,             // Symbol, by which the order has been placed
       comment;            // Comment
                           
};

int _ExpertOrdersTotal = 0;

_orders OrderList[],       // Arrays that store info about orders
        PrevOrderList[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
start_date = 0;

OrdersPrev = OrdersTotal();
PositionsPrev = PositionsTotal();

GetPosition(PrevPositionList);
GetOrders(PrevOrderList);
//---
   return(0);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| OnTrade function                                                 |
//+------------------------------------------------------------------+
void OnTrade()
  {
//---
GetPosition(PositionList);
GetOrders(OrderList);
datetime dc = TimeCurrent();
HistorySelect(start_date,dc);


Alert("The Trade event occurred");

if (OrdersPrev < OrdersTotal())
{
   OrderGetTicket(OrdersTotal()-1);// Select the last order to work with
   _GetLastError=GetLastError();
   Print("Error #",_GetLastError);ResetLastError();
   //--
   if (OrderGetInteger(ORDER_STATE) == ORDER_STATE_STARTED)
   {
      Alert(OrderGetTicket(OrdersTotal()-1),"Order has arrived for processing");
      LastOrderTicket = OrderGetTicket(OrdersTotal()-1);    // Saving the order ticket for further work
   }
   
   
   state = OrderGetInteger(ORDER_STATE);
   if (state == ORDER_STATE_PLACED)
   {
      switch(OrderGetInteger(ORDER_TYPE))
      {
         case 2:
            Alert("Pending order Buy Limit #", OrderGetTicket(OrdersTotal()-1)," accepted!");
         break;
         
         case 3:
            Alert("Pending order Sell Limit #", OrderGetTicket(OrdersTotal()-1)," accepted!");
         break;
         
         case 4:
            Alert("Pending order Buy Stop #", OrderGetTicket(OrdersTotal()-1)," accepted!");
         break;
         
         case 5:
            Alert("Pending order Sell Stop #", OrderGetTicket(OrdersTotal()-1)," accepted!");
         break;
         
         case 6:
            Alert("Pending order Buy Stop Limit #", OrderGetTicket(OrdersTotal()-1)," accepted!");
         break;
                 
         case 7:
            Alert("Pending order Sell Stop Limit #", OrderGetTicket(OrdersTotal()-1)," accepted!");
         break;         
      }
      
   }
   
   
   
}
else if(OrdersPrev > OrdersTotal())
{
   state = HistoryOrderGetInteger(LastOrderTicket,ORDER_STATE);

   // If order is not found, generate an error
   _GetLastError=GetLastError();
   if (_GetLastError != 0){Alert("Error #",_GetLastError," Order ",LastOrderTicket," is not found!");LastOrderTicket = 0;}
   Print("Error #",_GetLastError," state: ",state);ResetLastError();


   // If order is fully executed
   if (state == ORDER_STATE_FILLED)
   {
      // Then analyze the last deal
      // --
      Alert(LastOrderTicket, "Order executed, going to deal");
      switch(HistoryDealGetInteger(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_ENTRY))
      {
         
         // Entering the market
         case DEAL_ENTRY_IN:
         Alert(HistoryDealGetInteger(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_ORDER), 
         " order invoked deal #",HistoryDealGetTicket(HistoryDealsTotal()-1));
         
            switch(HistoryDealGetInteger(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_TYPE))
            {
               case 0:
               // If volumes of position and deal are equal, then position has just been opened
                  if (PositionSelect(HistoryDealGetString(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_SYMBOL)) 
                  && (PositionGetDouble(POSITION_VOLUME) == HistoryDealGetDouble(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_VOLUME)))
                  {
                     Alert("Buy position has been opened on pair ", 
                           HistoryDealGetString(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_SYMBOL)); 
                  }
                  else
               // If volumes of position and deal are not equal, then position has been incremented
                  if (PositionSelect(HistoryDealGetString(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_SYMBOL)) 
                  && (PositionGetDouble(POSITION_VOLUME) > HistoryDealGetDouble(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_VOLUME)))
                  {
                     Alert("Buy position has incremented on pair ", 
                           HistoryDealGetString(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_SYMBOL)); 
                  }
               break;
               
               case 1:
               // If volumes of position and deal are equal, then position has just been opened
                  if (PositionSelect(HistoryDealGetString(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_SYMBOL)) 
                  && (PositionGetDouble(POSITION_VOLUME) == HistoryDealGetDouble(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_VOLUME)))
                  {
                     Alert("Sell position has been opened on pair ", 
                           HistoryDealGetString(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_SYMBOL)); 
                  }
                  else
               // If volumes of position and deal are not equal, then position has been incremented
                  if (PositionSelect(HistoryDealGetString(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_SYMBOL)) 
                  && (PositionGetDouble(POSITION_VOLUME) > HistoryDealGetDouble(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_VOLUME)))
                  {
                     Alert("Sell position has incremented on pair ", 
                           HistoryDealGetString(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_SYMBOL)); 
                  }
                  
               break;
               
               default:
                  Alert("Unprocessed code of type: ",
                        HistoryDealGetInteger(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_TYPE));
               break;
            }
         break;
         
         // Выход из рынка
         case DEAL_ENTRY_OUT:
         Alert(HistoryDealGetInteger(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_ORDER), 
         " order invoked deal #",HistoryDealGetTicket(HistoryDealsTotal()-1));
         
            switch(HistoryDealGetInteger(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_TYPE))
            {
               case 0:
               // If position, we tried to close, is still present, then we have closed only part of it
                  if (PositionSelect(HistoryDealGetString(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_SYMBOL)) == true)
                  {
                     Alert("Part of Sell position has been closed on pair ", 
                           HistoryDealGetString(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_SYMBOL),
                           " with profit = ",
                           HistoryDealGetDouble(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_PROFIT));
                  }
                  else
               // If position is not found, then it is fully closed
                  if (PositionSelect(HistoryDealGetString(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_SYMBOL)) == false)
                  {
                     Alert("Sell position has been closed on pair ",
                           HistoryDealGetString(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_SYMBOL),
                           " with profit = ",
                           HistoryDealGetDouble(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_PROFIT));
                  }
               break;
               
               case 1:
               // If position, we tried to close, is still present, then we have closed only part of it
                  if (PositionSelect(HistoryDealGetString(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_SYMBOL)) == true)
                  {
                     Alert("Part of Buy position has been closed on pair ", 
                           HistoryDealGetString(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_SYMBOL),
                           " with profit = ",
                           HistoryDealGetDouble(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_PROFIT));
                  }
                  else
               // If position is not found, then it is fully closed
                  if (PositionSelect(HistoryDealGetString(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_SYMBOL)) == false)
                  {
                     Alert("Buy position has been closed on pair ",
                           HistoryDealGetString(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_SYMBOL),
                           " with profit = ",
                           HistoryDealGetDouble(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_PROFIT));
                  }
                  
               break;
               
               default:
                  Alert("Unprocessed code of type: ",
                        HistoryDealGetInteger(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_TYPE));
               break;
            }
         break;
         
         // Reverse
         case DEAL_ENTRY_INOUT:
         Alert(HistoryDealGetInteger(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_ORDER), 
         " order invoked deal #",HistoryDealGetTicket(HistoryDealsTotal()-1));
         
            switch(HistoryDealGetInteger(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_TYPE))
            {
               case 0:
                  Alert("Sell is reversed to Buy on pair ",
                        HistoryDealGetString(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_SYMBOL),
                        " resulting profit = ",
                        HistoryDealGetDouble(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_PROFIT)); 
               break;
               
               case 1:
                  Alert("Buy is reversed to Sell on pair ",
                        HistoryDealGetString(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_SYMBOL),
                        " resulting profit = ",
                        HistoryDealGetDouble(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_PROFIT)); 
               break;
               
               default:
                  Alert("Unprocessed code of type: ",
                        HistoryDealGetInteger(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_TYPE));
               break;
            }
         break;
         
         // Indicates the state record
         case DEAL_ENTRY_STATE:
            Alert("Indicates the state record. Unprocessed code of direction: ", 
            HistoryDealGetInteger(HistoryDealGetTicket(HistoryDealsTotal()-1),DEAL_TYPE));
         break;
      }
      // --
   }
   
}


if ((PositionsPrev == PositionsTotal()) && (OrdersPrev == OrdersTotal()))
{
   string _alerts = "";
   bool modify = false;
   
   for (int i=0;i<_ExpertPositionsTotal;i++)
   {
      if (PrevPositionList[i].sl != PositionList[i].sl)
      {
         _alerts += "On pair "+PositionList[i].symbol+" Stop Loss changed from "+ PrevPositionList[i].sl +" to "+ PositionList[i].sl +"\n";
         modify = true;
      }
      if (PrevPositionList[i].tp != PositionList[i].tp)
      {
         _alerts += "On pair "+PositionList[i].symbol+" Take Profit changed from "+ PrevPositionList[i].tp +" to "+ PositionList[i].tp +"\n";
         modify = true;
      }
      
   }
   
   for (int i = 0;i<_ExpertOrdersTotal;i++)
   {
      if (PrevOrderList[i].sl != OrderList[i].sl)
      {
         _alerts += "Order "+OrderList[i].ticket+" has changed Stop Loss from "+ PrevOrderList[i].sl +" to "+ OrderList[i].sl +"\n";
         modify = true;
      }
      if (PrevOrderList[i].tp != OrderList[i].tp)
      {
         _alerts += "Order "+OrderList[i].ticket+" has changed Take Profit from "+ PrevOrderList[i].tp +" to "+ OrderList[i].tp +"\n";
         modify = true;
      }
   }
   
   if (modify == true)
   {
      Alert(_alerts);
      modify = false;
   }
}


GetPosition(PrevPositionList);
GetOrders(PrevOrderList);
OrdersPrev = OrdersTotal();
PositionsPrev = PositionsTotal();

//---
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   
  }
//+------------------------------------------------------------------+



void GetPosition(_position &Array[])
  {
   int _GetLastError=0,_PositionsTotal=PositionsTotal();

   int temp_value=(int)MathMax(_PositionsTotal,1);
   ArrayResize(Array, temp_value);

   _ExpertPositionsTotal=0;
   for(int z=_PositionsTotal-1; z>=0; z--)
     {
      if(!PositionSelect(PositionGetSymbol(z)))
        {
         _GetLastError=GetLastError();
         Print("OrderSelect() - Error #",_GetLastError);
         continue;
        }
      else
        {
            // If the position is found, then put its info to the array
            Array[z].type         = PositionGetInteger(POSITION_TYPE);
            Array[z].time         = PositionGetInteger(POSITION_TIME);
            Array[z].magic        = PositionGetInteger(POSITION_MAGIC);
            Array[z].volume       = PositionGetDouble(POSITION_VOLUME);
            Array[z].priceopen    = PositionGetDouble(POSITION_PRICE_OPEN);
            Array[z].sl           = PositionGetDouble(POSITION_SL);
            Array[z].tp           = PositionGetDouble(POSITION_TP);
            Array[z].pricecurrent = PositionGetDouble(POSITION_PRICE_CURRENT);
            Array[z].comission    = PositionGetDouble(POSITION_COMMISSION);
            Array[z].swap         = PositionGetDouble(POSITION_SWAP);
            Array[z].profit       = PositionGetDouble(POSITION_PROFIT);
            Array[z].symbol       = PositionGetString(POSITION_SYMBOL);
            Array[z].comment      = PositionGetString(POSITION_COMMENT);
        _ExpertPositionsTotal++;
        }
     }

   temp_value=(int)MathMax(_ExpertPositionsTotal,1);
   ArrayResize(Array,temp_value);
  }
//+------------------------------------------------------------------+



//+------------------------------------------------------------------+
//| Function GetOrders()                                             |
//+------------------------------------------------------------------+
void GetOrders(_orders &OrdersList[])
  {
   
   int _GetLastError=0,_OrdersTotal=OrdersTotal();

   int temp_value=(int)MathMax(_OrdersTotal,1);
   ArrayResize(OrdersList,temp_value);

   _ExpertOrdersTotal=0;
   for(int z=_OrdersTotal-1; z>=0; z--)
     {
      if(!OrderGetTicket(z))
        {
         _GetLastError=GetLastError();
         Print("GetOrders() - Error #",_GetLastError);
         continue;
        }
      else
        {
        OrdersList[z].ticket          = OrderGetTicket(z);
        OrdersList[z].time_setup      = OrderGetInteger(ORDER_TIME_SETUP);
        OrdersList[z].time_expiration = OrderGetInteger(ORDER_TIME_EXPIRATION);
        OrdersList[z].time_done       = OrderGetInteger(ORDER_TIME_DONE);
        OrdersList[z].type            = OrderGetInteger(ORDER_TYPE);
        
        OrdersList[z].state           = OrderGetInteger(ORDER_STATE);
        OrdersList[z].type_filling    = OrderGetInteger(ORDER_TYPE_FILLING);
        OrdersList[z].type_time       = OrderGetInteger(ORDER_TYPE_TIME);
        OrdersList[z].magic           = OrderGetInteger(ORDER_MAGIC);
        OrdersList[z].position_id     = OrderGetInteger(ORDER_POSITION_ID);
        
        OrdersList[z].volume_initial  = OrderGetDouble(ORDER_VOLUME_INITIAL);
        OrdersList[z].volume_current  = OrderGetDouble(ORDER_VOLUME_CURRENT);
        OrdersList[z].price_open      = OrderGetDouble(ORDER_PRICE_OPEN);
        OrdersList[z].sl              = OrderGetDouble(ORDER_SL);
        OrdersList[z].tp              = OrderGetDouble(ORDER_TP);
        OrdersList[z].price_current   = OrderGetDouble(ORDER_PRICE_CURRENT);
        OrdersList[z].price_stoplimit = OrderGetDouble(ORDER_PRICE_STOPLIMIT);
        
        OrdersList[z].symbol          = OrderGetString(ORDER_SYMBOL);
        OrdersList[z].comment         = OrderGetString(ORDER_COMMENT);
        
        _ExpertOrdersTotal++;
        }
     }

   temp_value=(int)MathMax(_ExpertOrdersTotal,1);
   ArrayResize(OrdersList,temp_value);

  }
//+------------------------------------------------------------------+