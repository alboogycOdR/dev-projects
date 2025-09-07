//+------------------------------------------------------------------+
//|                                          UpdatePendingOrders.mq5 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>

CTrade         Trade;                      // trading object
CSymbolInfo    m_symbol;                     // symbol info object

ulong                            m_slippage=30;                      // slippage
double                           m_adjusted_point;                   // point value adjusted for 3 or 5 points

double                           ExtUpStep=0.0;
input ushort                     InpUpGep          = 15;             // Gap for pending orders UP from the current price (in pips)
input ushort                     InpUpStep         = 30;             // Step between orders UP (in pips)
input ushort                     InpTakeProfit     = 2000;           // 20.  Take Profit (in pips)

double                           ExtUpGep=0.0;
input ushort                     InpStopLoss       = 20;             // Stop Loss (in pips)
double                           ExtStopLoss=0.0;
double                           ExtTakeProfit=0.0;


//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {

//--- tuning for 3 or 5 digits
   int digits_adjust=1;
   if(m_symbol.Digits()==3 || m_symbol.Digits()==5)
      digits_adjust=10;
   m_adjusted_point=_Point*digits_adjust;


   ExtUpGep       = m_adjusted_point * InpUpGep;
   ExtUpStep      = m_adjusted_point * InpUpStep;
   ExtStopLoss    = m_adjusted_point * InpStopLoss;
   ExtTakeProfit  = m_adjusted_point * InpTakeProfit;


//--- start work
   double start_price_ask= SymbolInfoDouble(Symbol(),SYMBOL_ASK);
   double start_price_bid= SymbolInfoDouble(Symbol(),SYMBOL_BID);


   int buy_stop_total=0;
   for(int i = OrdersTotal()-1; i >= 0; i--)
     {
      double price_ask     = start_price_ask+i*ExtUpStep;
      double sl         = price_ask - 100;//ExtStopLoss;
      double tp         = price_ask + 100;//ExtTakeProfit;
      double price_bid     = start_price_bid+i*ExtUpStep;
      //Print("price ask "+price_ask);


      Print("sl "+sl);
      Print("tp "+tp);

      ulong ticket = OrderGetTicket(i);

      if(!OrderSelect(ticket))
         continue;
      ulong magic = OrderGetInteger(ORDER_MAGIC);
      //if(magic != ExpertMagic())continue;
      string symbol = OrderGetString(ORDER_SYMBOL);
      if(symbol != _Symbol)
         continue;
         
         
      ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

      if(order_type == ORDER_TYPE_BUY_STOP)
        {
         buy_stop_total++;
         
         Trade.OrderModify(
            ticket
            , price_ask //PRICE
            , m_symbol.NormalizePrice(sl)   //SL
            , m_symbol.NormalizePrice(tp)      //TP
            , NULL
            ,NULL
            ,NULL);
        }
        
        
      Print("price ask "+price_ask);
      Print("m_symbol.NormalizePrice(sl) "+   m_symbol.NormalizePrice(sl));
      Print("m_symbol.NormalizePrice(tp) "+    m_symbol.NormalizePrice(tp));

      Comment("amount of pending orders is "+buy_stop_total);
     }

  }

//+------------------------------------------------------------------+
