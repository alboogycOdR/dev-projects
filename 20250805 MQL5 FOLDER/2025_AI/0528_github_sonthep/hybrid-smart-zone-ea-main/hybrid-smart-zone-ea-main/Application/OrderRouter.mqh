//+------------------------------------------------------------------+
//| OrderRouter - Application Layer                                  |
//+------------------------------------------------------------------+
#include "../Domain/TradePlanExecutor.mqh"
#include <Trade\Trade.mqh>

class OrderRouter
  {
private:
   TradePlanExecutor m_tradePlanExecutor;
   CTrade m_trade;
public:
   OrderRouter() {}
   int CountOpenOrders(int direction)
     {
      int count = 0;
      for(int i=0; i<PositionsTotal(); i++)
        {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket))
           {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_TYPE) == direction)
               count++;
           }
        }
      return count;
     }
   void RouteOrder(int signal, double lot, double sl, double tp)
     {
      int direction = (signal == 1) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      if(CountOpenOrders(direction) > 0)
         return;
      bool result = false;
      if(signal == 1)
         result = m_trade.Buy(lot, _Symbol, 0, sl, tp);
      else if(signal == -1)
         result = m_trade.Sell(lot, _Symbol, 0, sl, tp);
      if(!result)
         Print("OrderSend failed: ", GetLastError());
      else
         Print("Order placed successfully!");
     }
   // Trailing Stop: move SL to new swing high/low if price moves in favor
   void TrailingStop(int swingLookback = 20)
     {
      for(int i=0; i<PositionsTotal(); i++)
        {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket))
           {
            string symbol = PositionGetString(POSITION_SYMBOL);
            int type = (int)PositionGetInteger(POSITION_TYPE);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double sl = PositionGetDouble(POSITION_SL);
            double newSL = sl;
            if(type == POSITION_TYPE_BUY)
              {
               // Move SL to latest swing low if higher than current SL
               double swingLow = iLow(symbol, PERIOD_CURRENT, 1);
               for(int j=2; j<=swingLookback; j++)
                  swingLow = MathMin(swingLow, iLow(symbol, PERIOD_CURRENT, j));
               if(swingLow > sl && swingLow < SymbolInfoDouble(symbol, SYMBOL_BID))
                  newSL = swingLow;
              }
            else if(type == POSITION_TYPE_SELL)
              {
               // Move SL to latest swing high if lower than current SL
               double swingHigh = iHigh(symbol, PERIOD_CURRENT, 1);
               for(int j=2; j<=swingLookback; j++)
                  swingHigh = MathMax(swingHigh, iHigh(symbol, PERIOD_CURRENT, j));
               if((sl == 0.0 || swingHigh < sl) && swingHigh > SymbolInfoDouble(symbol, SYMBOL_ASK))
                  newSL = swingHigh;
              }
            if(newSL != sl && newSL != 0.0)
              {
               m_trade.PositionModify(symbol, newSL, PositionGetDouble(POSITION_TP));
               Print("Trailing stop moved for ", symbol, " to ", newSL);
              }
           }
        }
     }
  }; 