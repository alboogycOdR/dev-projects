//+------------------------------------------------------------------+
//|                                              CheckRangeDelay.mq5 |
//|                                      Copyright 2025, Anyim Ossi. |
//|                                          anyimossi.dev@gmail.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Anyim Ossi."
#property link      "anyimossi.dev@gmail.com"
#property version   "1.00"
#include <Trade\Trade.mqh>
CTrade trade;
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
double grid_size = 2.00;
double grid_spread = 0.40;
ENUM_POSITION_TYPE last_saved_type = POSITION_TYPE_SELL;
bool is_end_session = false; // false if session is active(default)
bool use_daily_session = false; // trade 24/7 if false

void OnStart()
  {
//---
   check_zero_position();
   //+------------------------------------------------------------------+
void OnTest()
  {
    // // Test Recovery Node
   // Test structures 
   // Test node values
   // Test on invalid reference ticket.
   // Test on open position.
   // Test on buy stop
   // Test on already existing node
   // Test failed execution, on invalid price/stop limits

   // // Test Continuation Node
   //
   
  }
  }
//+------------------------------------------------------------------+

void check_zero_position()
{
    // reason1: a position just closed within trading time leaving a delay
    // reason2: outside trading time
    // reason3: fatal error, unforeseen event, log status

    if (PositionSelect(_Symbol)) return;

    if (use_daily_session) post_session_clean_up();

    check_range_delay();
}

void check_range_delay(const GridBase &base, CTrade &trader)
{
    int orders_total = OrdersTotal();
    if (PositionSelect(_Symbol) || orders_total == 0) return;

    if (orders_total>2)
    {
        Print(__FUNCTION__, "- WARNING. ", orders_total," nodes found on the chart.");
        Print("Unable to replace grid nodes");
        return;
    }
    
    // grid shifts on a short position
    if (base.type == POSITION_TYPE_BUY) return;
    
    // Variables to store order prices and tickets
    double price1 = 0.0, price2 = 0.0;
    ulong buy_stop_ticket = 0, sell_stop_ticket = 0;

    // handle grid shift during trading session
    if (orders_total == 2) // Continuation stop is present
    {
        // get pending orders details
        for (int i = orders_total - 1; i >= 0; i--)
        {
            ulong order_ticket = OrderGetTicket(i);
            if (order_ticket == 0) continue;
            if (OrderGetString(ORDER_SYMBOL) != _Symbol) continue;

            ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            double price = OrderGetDouble(ORDER_PRICE_OPEN);

            // Store order prices
            if (price1 == 0.0)
                price1 = price;
            else
                price2 = price;

            // Store tickets based on order type
            if (order_type == ORDER_TYPE_BUY_STOP)
            {
                buy_stop_ticket = order_ticket;
            }
            else if (order_type == ORDER_TYPE_SELL_STOP)
            {
                sell_stop_ticket = order_ticket; // not relevant
            }
            
        }
        
        double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double distance = MathAbs(price1 - price2);
        if (distance <= (grid_size + grid_spread * 2)) return;// Range delay is already set
        
        double half_distance = (price1 + price2) / 2.0;
        // If the price is closer to the higher ticket
        if (current_price > half_distance)
        {
            // Delete the continuation sell stop order
            //delete_non_recovery_orders();
            Print(__FUNCTION__, " - Replacing sell stop: ", sell_stop_ticket," with recovery sell stop");

            // Check if the buy stop ticket is valid
            if (buy_stop_ticket != 0) 
            {
               //place_recovery_stop(buy_stop_ticket);
               PlaceRecoveryNode(ulong reference_ticket, const Grid &grid, const GridBase *base=NULL)
            }               
            else
            {
                Print(__FUNCTION__, " - Buy stop ticket not found. Unable to place replacement stop");
            }
        }
    }
    // handle grid shift outside trading session
    else if (orders_total == 1)
    {
        ulong stop_ticket = 0;
        // Attempt to get the Long recovery node
        for (int i = orders_total - 1; i >= 0; i--)
        {
            ulong order_ticket = OrderGetTicket(i);
            if (order_ticket != 0)
            {
                if (OrderGetString(ORDER_SYMBOL) != _Symbol)
                    continue;

                ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
                if (order_type == ORDER_TYPE_BUY_STOP)
                {
                    stop_ticket = order_ticket;
                    break;
                }
            }
        }

        // If no buy stop ticket is found, return
        if (stop_ticket == 0) return;

        PlaceRecoveryNode(stop_ticket, grid);
    }
}

