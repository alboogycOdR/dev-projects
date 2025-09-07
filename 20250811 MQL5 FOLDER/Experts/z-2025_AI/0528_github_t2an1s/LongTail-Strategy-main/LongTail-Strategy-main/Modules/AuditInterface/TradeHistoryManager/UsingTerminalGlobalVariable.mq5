
// Save last position type
void OnTradeTransaction(const MqlTradeTransaction& trans,const MqlTradeRequest& request,const MqlTradeResult& result) // an MQL event handler
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      ulong  deal_ticket = trans.deal;

      MqlDeal deal;
      if(HistoryDealGet(deal_ticket, deal))
      {
         ENUM_DEAL_ENTRY deal_entry = (ENUM_DEAL_ENTRY)deal.entry;
         ENUM_DEAL_TYPE  deal_type  = (ENUM_DEAL_TYPE)deal.type;

         if(deal_entry == DEAL_ENTRY_IN)
         {
            // A new position was opened
            ENUM_POSITION_TYPE pos_type = (deal_type == DEAL_TYPE_BUY || deal_type == DEAL_TYPE_BUY_LIMIT || deal_type == DEAL_TYPE_BUY_STOP) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;

            // Save the position type to a Global Variable
            GlobalVariableSet("LastPositionType", (double)pos_type);
         }
      }
   }
}

// Retrieve Last Position Type
bool WasLastPositionLong()
{
   if(GlobalVariableCheck("LastPositionType"))
   {
      double pos_type_value = GlobalVariableGet("LastPositionType");
      return ((ENUM_POSITION_TYPE)((int)pos_type_value) == POSITION_TYPE_BUY);
   }
   else
   {
      // No position type recorded
      return false;
   }
}
