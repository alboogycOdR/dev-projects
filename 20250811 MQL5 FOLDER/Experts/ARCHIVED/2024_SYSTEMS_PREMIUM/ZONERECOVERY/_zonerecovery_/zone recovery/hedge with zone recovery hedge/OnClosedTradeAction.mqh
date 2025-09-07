class OnClosedTradeAction : public AAction
{
public:
   virtual bool DoAction()
   {
      OrdersIterator orders;
      orders.WhenSymbol(PositionGetString(POSITION_SYMBOL));
      TradingCommands::DeleteOrders(orders);
      TradesIterator trades;
      trades.WhenSymbol(PositionGetString(POSITION_SYMBOL));
      TradingCommands::CloseTrades(trades);
      return true;
   }
};