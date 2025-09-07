//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#include "_tradetranshelper.mqh"

// Define a function pointer type for our callback
typedef void (*OnStopLossHitCallback)(int magicNumber);

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CExtTransaction : public CTradeTransaction
  {
protected:
   // Add a callback member
   OnStopLossHitCallback m_onStopLossHitCallback;

public:
   // Constructor - initialize callback to NULL
                     CExtTransaction() : m_onStopLossHitCallback(NULL) {}

   // Method to set the callback function
   void              SetStopLossCallback(OnStopLossHitCallback callback)
     {
      m_onStopLossHitCallback = callback;
     }

protected:
   //--- trade transactions
   virtual void      TradeTransactionOrderPlaced(ulong order)
     {
      //if(OrderGetInteger(ORDER_MAGIC) == EAMAGIC) {
      //   PrintFormat("Pending order is placed. (order %I64u)", order);
      //}
      if(OrderGetInteger(ORDER_MAGIC) == InpMagicMain)
        {
         PrintFormat("Pending order is placed. (order %I64u)", order);
        }
      if(OrderGetInteger(ORDER_MAGIC) == InpMagicRecovery)
        {
         PrintFormat("Pending order (recovery)is placed. (order %I64u)", order);
        }
     }
   //+------------------------------------------------------------------+
   //|                                                                  |
   //+------------------------------------------------------------------+
   virtual void      TradeTransactionOrderModified(ulong order)
     {
      //if(OrderGetInteger(ORDER_MAGIC) == EAMAGIC) {
      //   PrintFormat("Pending order is modified. (order %I64u)", order);
      //}
      if(OrderGetInteger(ORDER_MAGIC) == InpMagicMain)
        {
         if(InpEnableDebug) PrintFormat("Pending order (main) is modified. (order %I64u)", order);
        }
      if(OrderGetInteger(ORDER_MAGIC) == InpMagicRecovery)
        {
         if(InpEnableDebug) PrintFormat("Pending order (recovery) is modified. (order %I64u)", order);
        }
     }
   //+------------------------------------------------------------------+
   //|                                                                  |
   //+------------------------------------------------------------------+
   virtual void      TradeTransactionOrderDeleted(ulong order)
     {
      if(InpEnableDebug) PrintFormat("Pending order is deleted. (order %I64u)", order);
     }
   //+------------------------------------------------------------------+
   //|                                                                  |
   //+------------------------------------------------------------------+
   virtual void      TradeTransactionOrderExpired(ulong order)
     {
      if(InpEnableDebug) PrintFormat("Pending order is expired. (order %I64u)", order);
     }
   //+------------------------------------------------------------------+
   //|                                                                  |
   //+------------------------------------------------------------------+
   virtual void      TradeTransactionOrderTriggered(ulong order)
     {
      if(OrderSelect(order))
        {
         ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP)
           {
            string order_type_str = (order_type == ORDER_TYPE_BUY_STOP) ? "BUY STOP" : "SELL STOP";
            if(InpEnableDebug) PrintFormat("STOP order triggered. (order %I64u, type: %s)", order, order_type_str);
            // Add your specific logic for STOP orders here
            // For example:
            if(order_type == ORDER_TYPE_BUY_STOP)
              {
               // Logic for triggered BUY STOP order
              }
            else   // SELL STOP
              {
               // Logic for triggered SELL STOP order
              }
           }
         else
           {
            // Optional: handle other order types or ignore them
            if(InpEnableDebug) PrintFormat("Non-STOP order triggered. (order %I64u, type: %s)", order, EnumToString(order_type));
           }
        }
      else
        {
         if(InpEnableDebug) Print("Failed to select order for details");
        }
     }

   //+------------------------------------------------------------------+
   //|                                                                  |
   //+------------------------------------------------------------------+
   virtual void      TradeTransactionPositionOpened(ulong position, ulong deal)
     {
      //if(HistoryDealGetInteger(deal, DEAL_MAGIC) == EAMAGIC) {
      //   PrintFormat("Position is opened. (position %I64u, deal %I64u)", position, deal);
      //}
      if(HistoryDealGetInteger(deal, DEAL_MAGIC) == InpMagicMain)
        {
         if(InpEnableDebug) PrintFormat("Position (main) is opened. (position %I64u, deal %I64u)", position, deal);
        }
      if(HistoryDealGetInteger(deal, DEAL_MAGIC) == InpMagicRecovery)
        {
         if(InpEnableDebug) PrintFormat("Position (recovery) is opened. (position %I64u, deal %I64u)", position, deal);
        }
     }
   //+------------------------------------------------------------------+
   //|                                                                  |
   //+------------------------------------------------------------------+
   virtual void      TradeTransactionPositionStopTake(ulong position, ulong deal)
     {
 
      ENUM_DEAL_REASON closeReason = (ENUM_DEAL_REASON)HistoryDealGetInteger(deal, DEAL_REASON);
      int magic = (int)HistoryDealGetInteger(deal, DEAL_MAGIC);
      if(magic == InpMagicMain)
        {
         if(closeReason == DEAL_REASON_SL)
           {
 
            if(InpEnableDebug) PrintFormat("Position (main) hit STOP LOSS. (position %I64u, deal %I64u)", position, deal);
 
            if(m_onStopLossHitCallback != NULL)
              {
               if(InpEnableDebug) PrintFormat("Executing stop loss callback for main position");
               m_onStopLossHitCallback(magic);
              }
           }
         else
            if(closeReason == DEAL_REASON_TP)
              {
 
               if(InpEnableDebug) PrintFormat("Position (main) hit TAKE PROFIT. (position %I64u, deal %I64u)", position, deal);
              }
            else
              {
               if(InpEnableDebug) PrintFormat("Position (main) closed on sl or tp. (position %I64u, deal %I64u)", position, deal);
              }
        }
      if(magic == InpMagicRecovery)
        {
         if(closeReason == DEAL_REASON_SL)
           {
            if(InpEnableDebug) PrintFormat("Position (recovery) hit STOP LOSS. (position %I64u, deal %I64u)", position, deal);
 
           }
         else
            if(closeReason == DEAL_REASON_TP)
              {
               if(InpEnableDebug) PrintFormat("Position (recovery) hit TAKE PROFIT. (position %I64u, deal %I64u)", position, deal);
              }
            else
              {
              if(InpEnableDebug)  PrintFormat("Position (recovery) closed on sl or tp. (position %I64u, deal %I64u)", position, deal);
              }
        }
     }
   //+------------------------------------------------------------------+
   //|                                                                  |
   //+------------------------------------------------------------------+
   virtual void      TradeTransactionPositionClosed(ulong position, ulong deal)
     {
      //if(HistoryDealGetInteger(deal, DEAL_MAGIC) == EAMAGIC) {
      //   PrintFormat("Position is closed. (position %I64u, deal %I64u)", position, deal);
      //}
      if(HistoryDealGetInteger(deal, DEAL_MAGIC) == InpMagicMain)
        {
         if(InpEnableDebug) PrintFormat("Position (main) is closed. (position %I64u, deal %I64u)", position, deal);
        }
      if(HistoryDealGetInteger(deal, DEAL_MAGIC) == InpMagicRecovery)
        {
         if(InpEnableDebug) PrintFormat("Position (recovery) is closed. (position %I64u, deal %I64u)", position, deal);
        }
     }
   //+------------------------------------------------------------------+
   //|                                                                  |
   //+------------------------------------------------------------------+
   virtual void      TradeTransactionPositionCloseBy(ulong position, ulong deal)
     {
      //if(HistoryDealGetInteger(deal, DEAL_MAGIC) == EAMAGIC) {
      //   PrintFormat("Position is closed by opposite position. (position %I64u, deal %I64u)", position, deal);
      //}
      if(HistoryDealGetInteger(deal, DEAL_MAGIC) == InpMagicMain)
        {
         if(InpEnableDebug) PrintFormat("Position (main) is closed by opposite position. (position %I64u, deal %I64u)", position, deal);
        }
      if(HistoryDealGetInteger(deal, DEAL_MAGIC) == InpMagicRecovery)
        {
         if(InpEnableDebug) PrintFormat("Position (recovery) is closed by opposite position. (position %I64u, deal %I64u)", position, deal);
        }
     }
   //+------------------------------------------------------------------+
   //|                                                                  |
   //+------------------------------------------------------------------+
   virtual void      TradeTransactionPositionModified(ulong position)
     {
      if(InpEnableDebug) PrintFormat("Position is modified. (position %I64u)", position);
     }
  };

//+------------------------------------------------------------------+
//| Global transaction object                                        |
//+------------------------------------------------------------------+
CExtTransaction ExtTransaction;


//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {


   // Track profit for closed trades
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD) {
      if(HistoryDealSelect(trans.deal)) {
         long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
         long magic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);

         if(entry == DEAL_ENTRY_OUT && (magic == InpMagicRecovery || magic == InpMagicMain)) { // Filter by magic numbers
            double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
            datetime time = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);

            // Update total realized profit
            totalRealizedProfit += profit;

            // Shift the lastFiveTrades array to make room for the new trade
            for(int i = 0; i < 4; i++) {
               lastFiveTrades[i] = lastFiveTrades[i + 1];
            }

            // Add the new trade at the end (most recent)
            lastFiveTrades[4].profit = profit;
            lastFiveTrades[4].time = time;
         }
      }
   }
   
   ExtTransaction.OnTradeTransaction(trans,request,result);
  }
//+------------------------------------------------------------------+
