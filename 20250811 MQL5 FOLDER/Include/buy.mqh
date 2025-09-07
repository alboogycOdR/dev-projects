//+------------------------------------------------------------------+
//|                                                     buyOrder.mq4 |
//|                                                       David_kdcp |
//|                                                  falavaspace.com |
//+------------------------------------------------------------------+
class Order{

//order_param sis a struct
public:
    Order(struct *params) {
      string symbol = params.symbol;                // symbol
      double market_entry = params.market_entry;    // price
      double stop_loss_pips = params.loss_pips;     // stop loss
      double take_profit_pips = params.profit_pips; // take profit
      string   comment=NULL;                        // comment
      int      magic=0;                             // magic number
      datetime expiration=0;                        // pending order expiration
    };
};

//+------------------------------------------------------------------+


class BuyOrder : public Order {

  private:
    double LOTS =1.0;     // volume a.k.a lots
    int    SLIPPAGE = 3;       // slippage
    color  ARROW_COLOR = Yellow;   // color

    double orderStoploss(double market_entry, double pips_loss){
      return market_entry - (pips_loss * Point)
    }

    double orderTakeProfit(double market_entry, double pips_in_profit){
      return market_entry + (pips_in_profit * Point)
    }

  protected:
    int execute(void) {
      return OrderSend(
        this.symbol,
        OP_BUY,
        this.lots,
        this.market_entry,
        OrderStoploss(this.price, this.stoploss)
        OrderTakeprofit(this.price, this.takeprofit)
        SLIPAGE,
        this.comment,
        this.experiration,
        ARROW_COLOR
      );
    }
};// BuyOrder

//+------------------------------------------------------------------+

// class BuyOrder : public Order {
//
//  private
//    double LOTS        = 1.0,     // volume a.k.a lots
//    int    SLIPPAGE    = 3,       // slippage
//    color  ARROW_COLOR = Yellow   // color
//
//   double orderStoploss(market_entry, pips_loss){
//      return market_entry - (pips_loss * Point)
//    }

//    double orderTakeProfit(market_entry, pips_in_profit){
//      return market_entry + (pips_in_profit * Point)
//    }

//  protected
//   int execute() {
//      OrderSend(
//        this.symbol,
//        OP_BUY,
//        this.lots,
//        this.market_entry,
//        OrderStoploss(this.price, this.stoploss)
//        OrderTakeprofit(this.price, this.takeprofit)
//        SLIPAGE,
//        this.comment,
//        this.experiration,
//        ARROW_COLOR
//      );
//    }
//}// BuyOrder

//+------------------------------------------------------------------+

