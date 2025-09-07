//+------------------------------------------------------------------+
//|                                       CloseBasketOfPositions.mq5 |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade/Trade.mqh>
CTrade trade;
ulong trade_ticket;
#include <Trade\PositionInfo.mqh>

#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\OrderInfo.mqh>
 
CPositionInfo  m_position;                   // trade position object
CTrade         m_trade;                      // trading object
CSymbolInfo    m_symbol;                     // symbol info object
CAccountInfo   m_account;                    // account info wrapper
COrderInfo     m_order;                      // pending orders object


input int             InpMaxTrades = 10;         // Max number of trades
input double          InpTradeGap = 0.005;       // Minimum gap between trades
input ENUM_ORDER_TYPE InpType = ORDER_TYPE_BUY;  // Order type;
input double          InpMinProfit = 1.00;       // Profit in base currency
input int             InpMagicNumber = 1111;     // Magic number
input string          InpTradeComment = __FILE__; // Trade comment
input double          InpVolume = 0.01;          // Volume per order


//define a structure to use to store the total profit, count and trailing price
struct STradeSum
  {
   int               count;
   double            profit;
   double            trailPrice;
  };



CTrade   Trade;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   Trade.SetExpertMagicNumber(InpMagicNumber);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   STradeSum  sum;
   GetSum(sum);

   if(sum.profit>InpMinProfit)    // target reached
     {
      CloseAll();
     }
   else
      if(sum.count==0)     // no trades
        {
         OpenTrade();
        }
      else
         if(sum.count<InpMaxTrades)
           {
            if(InpType==ORDER_TYPE_BUY
               && SymbolInfoDouble(Symbol(), SYMBOL_ASK)<=(sum.trailPrice-InpTradeGap)
              )     // Far enough below
              {
               OpenTrade();
              }
            else
               if(InpType==ORDER_TYPE_SELL
                  && SymbolInfoDouble(Symbol(), SYMBOL_BID)>=(sum.trailPrice+InpTradeGap)
                 )     // Far enough above
                 {
                  OpenTrade();
                 }
           }
  }
//+------------------------------------------------------------------+


//mt4
void  OpenTrade()
  {
   double   price = (InpType==ORDER_TYPE_BUY) ?
                    SymbolInfoDouble(Symbol(), SYMBOL_ASK) :
                    SymbolInfoDouble(Symbol(), SYMBOL_BID);
   //OrderSend(Symbol(), InpType, InpVolume, price, 0, 0, 0, InpTradeComment, InpMagicNumber);

//mt5
   Trade.PositionOpen(Symbol(), InpType, InpVolume, price, 0, 0, InpTradeComment);

  }


//mt4
//void  CloseAll()
//  {
//   int   count    =  OrdersTotal();
//   for(int i = count-1; i>=0; i--)
//     {
//      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
//        {
//         if(OrderSymbol()==Symbol()
//            && OrderMagicNumber()==InpMagicNumber
//            && OrderType()==InpType
//           )
//           {
//            OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), 0);
//           }
//        }
//     }
//  }
void CloseAll() {

   for ( int i = PositionsTotal() - 1; i >= 0; i-- ) {
      ulong ticket = PositionGetTicket( i );
      if ( !PositionSelectByTicket( ticket ) ) continue;
      if ( m_position.Symbol() != Symbol() || m_position.Magic() != InpMagicNumber ) continue;
      if ( !Trade.PositionClose( ticket ) ) {
         PrintFormat( "Failed to close position %i", ticket );
      }
   }

   for ( int i = OrdersTotal() - 1; i >= 0; i-- ) {
      ulong ticket = OrderGetTicket( i );
      if ( !OrderSelect( ticket ) ) continue;
      if ( m_order.Symbol() != Symbol() || m_order.Magic() != InpMagicNumber ) continue;
      if ( !Trade.OrderDelete( ticket ) ) {
         PrintFormat( "Failed to delete order %i", ticket );
      }
   }
}
 

//mt4
//void  GetSum(STradeSum &sum)
//  {
//   sum.count      =  0;
//   sum.profit     =  0.0;
//   sum.trailPrice =  0.0;
//
//   int   count    =  OrdersTotal();
//   for(int i = count-1; i>=0; i--)
//     {
//      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
//        {
//         if(OrderSymbol()==Symbol()
//            && OrderMagicNumber()==InpMagicNumber
//            && OrderType()==InpType
//           )
//           {
//            sum.count++;
//            sum.profit  += OrderProfit()+OrderSwap()+OrderCommission();
//            if(InpType==ORDER_TYPE_BUY)
//              {
//               if(sum.trailPrice==0 || OrderOpenPrice()<sum.trailPrice)
//                 {
//                  sum.trailPrice =  OrderOpenPrice();
//                 }
//              }
//            else
//               if(InpType==ORDER_TYPE_SELL)
//                 {
//                  if(sum.trailPrice==0 || OrderOpenPrice()>sum.trailPrice)
//                    {
//                     sum.trailPrice =  OrderOpenPrice();
//                    }
//                 }
//           }
//        }
//     }
//
//   return;
//
//  }


//mt5
void  GetSum(STradeSum &sum)
  {
   sum.count      =  0;
   sum.profit     =  0.0;
   sum.trailPrice =  0.0;

   int      count    =  PositionsTotal();
   for(int i = count-1; i>=0; i--)
     {
      ulong ticket   =  PositionGetTicket(i);
      if(ticket>0)
        {
         if(PositionGetString(POSITION_SYMBOL)==Symbol()
            && PositionGetInteger(POSITION_MAGIC)==InpMagicNumber
            && PositionGetInteger(POSITION_TYPE)==InpType)
           {
            sum.count++;
            sum.profit  += PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
            if(InpType==ORDER_TYPE_BUY)
              {
               if(sum.trailPrice==0 || PositionGetDouble(POSITION_PRICE_OPEN)<sum.trailPrice)
                 {
                  sum.trailPrice =  PositionGetDouble(POSITION_PRICE_OPEN);
                 }
              }
            else
               if(InpType==ORDER_TYPE_SELL)
                 {
                  if(sum.trailPrice==0 || PositionGetDouble(POSITION_PRICE_OPEN)>sum.trailPrice)
                    {
                     sum.trailPrice =  PositionGetDouble(POSITION_PRICE_OPEN);
                    }
                 }
           }
        }
     }

   return;

  }

//+------------------------------------------------------------------+
