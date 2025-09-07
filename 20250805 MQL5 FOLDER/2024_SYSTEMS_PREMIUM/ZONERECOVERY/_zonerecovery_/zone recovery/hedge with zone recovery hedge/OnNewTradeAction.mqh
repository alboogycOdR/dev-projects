class OnNewTradeAction : public AAction
{
   double original_rate;
   double opposite_rate;
   double buy_stop;
   double sell_stop;
public:
   OnNewTradeAction()
   {
      original_rate = 0;
      opposite_rate = 0;
   }

   virtual bool DoAction()
   {
      string symbol = PositionGetString(POSITION_SYMBOL);
      TradingCalculator calc(symbol);
      InstrumentInfo instrument(symbol);
      double openRate = PositionGetDouble(POSITION_PRICE_OPEN);
      ENUM_POSITION_TYPE side = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if (original_rate == 0)
      {
         original_rate = openRate;
         if (side == POSITION_TYPE_BUY)
         {
            opposite_rate = original_rate - area * instrument.GetPipSize();
            buy_stop = opposite_rate - tp * instrument.GetPipSize();
            sell_stop = original_rate + tp * instrument.GetPipSize();
         }
         else
         {
            opposite_rate = original_rate + area * instrument.GetPipSize();
            sell_stop = opposite_rate + tp * instrument.GetPipSize();
            buy_stop = original_rate - tp * instrument.GetPipSize();
         }
      }
      double rate = MathAbs(openRate - original_rate) < MathAbs(openRate - opposite_rate) ? opposite_rate : original_rate;
      TradesIterator trades;
      trades.WhenSymbol(symbol);
      double total_profit = area;
      while (trades.Next())
      {
         int mult = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == side ? -1 : 1;
         double open = PositionGetDouble(POSITION_PRICE_OPEN);
         double stop = side == POSITION_TYPE_BUY ? buy_stop : sell_stop;
         double pl = side == POSITION_TYPE_BUY ? (open - stop) : (stop - open);
         total_profit += (pl * PositionGetDouble(POSITION_VOLUME) * mult) / instrument.GetPipSize();
      }
      double order_amount = MathMax(instrument.GetMinVolume(), calc.NormilizeLots(-total_profit / tp * last_amount));
      last_amount = last_amount * amount_multiplicator;

      double takeProfit = calc.CalculateTakeProfit(side != POSITION_TYPE_BUY, tp, StopLimitPips, order_amount, rate);
      OrderBuilder order;
      string error;
      ulong ticket = order.SetSide(side == POSITION_TYPE_BUY ? SellSide : BuySide)
         .SetInstrument(symbol)
         .SetRate(rate)
         .SetAmount(order_amount)
         .SetMagicNumber(magic_number)
         .SetLimit(takeProfit)
         .Execute(error);
      if (ticket == 0)
      {
         Print(error);
      }
      return true;
   }
};