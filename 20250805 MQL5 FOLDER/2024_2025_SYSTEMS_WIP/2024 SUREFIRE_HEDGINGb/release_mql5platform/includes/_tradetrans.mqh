

#include "_tradetranshelper.mqh"
class CExtTransaction : public CTradeTransaction {
protected:
//--- trade transactions
   virtual void      TradeTransactionOrderPlaced(ulong order)
   {
      if(OrderGetInteger(ORDER_MAGIC) == EAMAGIC) {
         PrintFormat("Pending order is placed. (order %I64u)", order);
      }
   }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   virtual void      TradeTransactionOrderModified(ulong order)
   {
      if(OrderGetInteger(ORDER_MAGIC) == EAMAGIC) {
         PrintFormat("Pending order is modified. (order %I64u)", order);
      }
   }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   virtual void      TradeTransactionOrderDeleted(ulong order)
   {
      PrintFormat("Pending order is deleted. (order %I64u)", order);
   }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   virtual void      TradeTransactionOrderExpired(ulong order)
   {
      PrintFormat("Pending order is expired. (order %I64u)", order);
   }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   virtual void      TradeTransactionOrderTriggered(ulong order)
   {
      //PrintFormat("Pending order is triggered. (order %I64u)", order);
      if(OrderSelect(order)) {
         ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP) {
            string order_type_str = (order_type == ORDER_TYPE_BUY_STOP) ? "BUY STOP" : "SELL STOP";
            PrintFormat("STOP order triggered. (order %I64u, type: %s)", order, order_type_str);
            // Add your specific logic for STOP orders here
            // For example:
            if(order_type == ORDER_TYPE_BUY_STOP) {
               // Logic for triggered BUY STOP order
            }
            else { // SELL STOP
               // Logic for triggered SELL STOP order
            }
         }
         else {
            // Optional: handle other order types or ignore them
            PrintFormat("Non-STOP order triggered. (order %I64u, type: %s)", order, EnumToString(order_type));
         }
      }
      else {
         Print("Failed to select order for details");
      }
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   virtual void      TradeTransactionPositionOpened(ulong position, ulong deal)
   {
      if(HistoryDealGetInteger(deal, DEAL_MAGIC) == EAMAGIC) {
         PrintFormat("Position is opened. (position %I64u, deal %I64u)", position, deal);
      }
   }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   virtual void      TradeTransactionPositionStopTake(ulong position, ulong deal)
   {
      if(HistoryDealGetInteger(deal, DEAL_MAGIC) == EAMAGIC) {
         PrintFormat("Position is closed on sl or tp. (position %I64u, deal %I64u)", position, deal);
      }
   }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   virtual void      TradeTransactionPositionClosed(ulong position, ulong deal)
   {
      if(HistoryDealGetInteger(deal, DEAL_MAGIC) == EAMAGIC) {
         PrintFormat("Position is closed. (position %I64u, deal %I64u)", position, deal);
      }
   }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   virtual void      TradeTransactionPositionCloseBy(ulong position, ulong deal)
   {
      if(HistoryDealGetInteger(deal, DEAL_MAGIC) == EAMAGIC) {
         PrintFormat("Position is closed by opposite position. (position %I64u, deal %I64u)", position, deal);
      }
   }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   virtual void      TradeTransactionPositionModified(ulong position)
   {
      PrintFormat("Position is modified. (position %I64u)", position);
   }
};

//+------------------------------------------------------------------+
//| Global transaction object                                        |
//+------------------------------------------------------------------+
CExtTransaction ExtTransaction;
void ReturnStoppifiedSLTP(int positiontype,double &tpinternal,double &slinternal)
{
   double Ask=SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double Bid=SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double coeff=(double)InpFreezeCoefficient;
   double stop_level=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL) * Point();
   if(stop_level==0.0) {
      if(InpFreezeCoefficient>0)
         stop_level=(Ask-Bid)*coeff;
   }
   double stops=stop_level;
//sell
   if(positiontype==1) {
      double sl=Bid+STP;
      if(sl>0.0)
         if(sl-Ask  < stops)
            sl = Ask+stops;
      double tp=Bid-TKP;
      if(tp>0.0)
         if(Bid-tp<stops)
            tp=Bid-stops;
      tpinternal=tp;
      slinternal=sl;
      return;
   }
//buy
   if(positiontype==2) {
      double sl=Ask-STP;
      if(sl>0.0)
         if(Bid-sl<stops)
            sl=Bid-stops;
      double tp=Ask+TKP;
      if(tp>0.0)
         if(tp-Ask<stops)
            tp=Ask+stops;
      tpinternal=tp;
      slinternal=sl;
      return;
   }
}

//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
//---
   ExtTransaction.OnTradeTransaction(trans,request,result);
}