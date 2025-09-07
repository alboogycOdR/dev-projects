//+------------------------------------------------------------------+
//|                                           LongTailsScalperV1.mq5 |
//|                                      Copyright 2025, Anyim Ossi. |
//|                                          anyimossi.dev@gmail.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Anyim Ossi."
#property link      "anyimossi.dev@gmail.com"
#property version   "1.00"
#include <Trade\Trade.mqh>
CTrade trade;
//+------------------------------------------------------------------+

input bool           use_daily_session = false; // trade 24/7
input int            multiplier = 3;
input int            sequenceLength = 50;

bool                 is_end_session = false; // false if session is active(default)
datetime             session_start = StringToTime("08:30");
datetime             session_end = StringToTime("18:30");// test server time = real time +1

double               min_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
double               grid_size = 2.00, grid_spread = 0.40;
double               Sequence[];
ulong                last_saved_ticket = 0 ; // default
ENUM_POSITION_TYPE   last_saved_type = POSITION_TYPE_SELL; // default

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   build_sequence(multiplier, sequenceLength, Sequence);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   // Log stuff
   // profit or loss
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   // call daily sessions ☑️
    track_daily_session(is_end_session);
    
    if (use_daily_session && is_end_session && is_empty_chart())
        return;
        
    // manage mismanagement ☑️
    check_strategy_rules();

    // call new position ☑️
    check_new_position(last_saved_ticket, last_saved_type);
   
    // manage delay ☑️
    check_zero_position();
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| CMP - Sequence Builder                                           |
//+------------------------------------------------------------------+
// -
int build_sequence(int reward_multiplier, int sequence_length, double &progression_sequence[])
  {
   // Initialize variables
   double minimum_stake = min_volume;
   double minimum_profit = minimum_stake * 2;
   double current_stake = minimum_stake;


   // Compute the progression sequence
   for(int i = 0; i < sequence_length; i++)
     {
      double minimum_outcome = ArraySum(progression_sequence) + minimum_profit;
      while(current_stake * reward_multiplier < minimum_outcome)
        {
         current_stake += minimum_stake;
        }
      ArrayResize(progression_sequence, ArraySize(progression_sequence) + 1);
      progression_sequence[ArraySize(progression_sequence) - 1] = current_stake;
     }

   return(0);
  }
//+------------------------------------------------------------------+
// Helper function to sum the elements of an array
double ArraySum(double &array[])
  {
   double sum = 0;
   for(int i = 0; i < ArraySize(array); i++)
     {
      sum += array[i];
     }
   return sum;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| CMP - Core                                                       |
//+------------------------------------------------------------------+
// -
void track_daily_session(bool &end_session)
{ 
     if (!is_within_trading_time(session_start, session_end)) // outside trading time
     {
         // End a daily session
         end_session = true;
         Print("Ending daily session: Outside trading time.");
         
         // delete continuation orders
         delete_non_recovery_orders();
         
         return;
     }
    else // within trading time
    {
      // Start a daily session
        end_session = false;
        
        if (OrdersTotal() > 0 || PositionSelect(_Symbol))
        {
            //Progression cycle ongoing: Proceeding to manage cycle.
            return;
        }
        else
        {
           Print("Starting daily session within trading time.");
           double order_volume = Sequence[0];
           double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

           bool placed = trade.Sell(order_volume, _Symbol, price, 0, 0, "short position");
           if (placed)
           {
              ulong order_ticket = trade.ResultOrder(); // Get the ticket number of the placed order
              Print("Started new cycle with short position opened at market price: ", price);
              set_exits(order_ticket,grid_size,multiplier);
           }
           else
           {
               Print("Failed to start new cycle with short position at market price.", price);
           }
         }  
    }
}
//+------------------------------------------------------------------+
// -
void check_new_position(ulong &last_saved, ENUM_POSITION_TYPE &last_type)
{
    // assumes there's one position open on the chart
    if (PositionSelect(_Symbol))
    {
        //get open positions ticket
        ulong open_ticket = PositionGetInteger(POSITION_TICKET);
        
        if (last_saved != open_ticket) // New position open on chart
        {
            long ticket_type = PositionGetInteger(POSITION_TYPE);
            Print("New position opened, proceeding to manage.");
            
            set_exits(open_ticket,grid_size,multiplier);
            
            delete_all_pending_orders();
            
            // call recovery.
            place_recovery_stop(open_ticket);
            
            // call continuation.
            place_continuation_stop(open_ticket);
            
            //update stored ticket to open ticket
            last_saved = open_ticket;
            last_type = (ENUM_POSITION_TYPE)ticket_type;
         }   
    }
}
//+------------------------------------------------------------------+
// Helper function to 
bool is_within_trading_time(datetime start_time, datetime end_time)
{
    if (!use_daily_session) return true;// always trading time if we dont use daily sessions
    
    if (start_time>end_time)
    {
      datetime temp = start_time;
      start_time = end_time;
      end_time = temp; 
    }
    datetime current_time = TimeCurrent();
    
    return (current_time >= start_time && current_time <= end_time);
}
//+------------------------------------------------------------------+
// Helper function to 
void delete_non_recovery_orders()
{
  /*
  Deletes any order whose comment does not contain 'recovery'
  */  
    // Loop through all open orders
    for (int i = OrdersTotal() - 1; i >= 0; --i)
    {
        ulong order_ticket = OrderGetTicket(i);
        if (order_ticket != 0)
        {
            string comment = OrderGetString(ORDER_COMMENT);
            
            // Check if the comment does not contain "recovery"
            if (StringFind(comment, "recovery") == -1)
            {
                
                bool deleted = trade.OrderDelete(order_ticket);
                if (deleted)
                {
                    Print("Deleted order with ticket: ", order_ticket, " and comment: ", comment);
                }
                else
                {
                    Print("Failed to delete order with ticket: ", order_ticket, " and comment: ", comment);
                }
            }
        }
    }
}
//+------------------------------------------------------------------+
// Helper function to 
void delete_all_pending_orders()
{
    // Loop through all open orders
    for (int i = OrdersTotal() - 1; i >= 0; --i)
    {
        ulong order_ticket = OrderGetTicket(i);
        if (order_ticket != 0)
        {
            bool deleted = trade.OrderDelete(order_ticket);
            if (deleted)
            {
                Print("Deleted order with ticket: ", order_ticket, " and comment: ", OrderGetString(ORDER_COMMENT));
            }
            else
            {
                Print("Failed to delete order with ticket: ", order_ticket, " and comment: ", OrderGetString(ORDER_COMMENT));
            }
        }
    }
}
//+------------------------------------------------------------------+
// Helper function to 
bool is_empty_chart()
{
  if (!PositionSelect(_Symbol) && OrdersTotal()==0) return true;
  return false;
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| CMP - Strategy Management                                        |
//+------------------------------------------------------------------+
// ALL THE CODE THAT ENSURES STRATEGY GUIDELINES ARE ADHERED

void check_strategy_rules()
{  
    check_core_rules();
    check_risk_rules();
    check_forgotten_order();
    
    // consider unseen edge cases
}
//+------------------------------------------------------------------+
// -
void check_core_rules()
{
    // Check if there is more than one position
    if (PositionsTotal() > 1)
    {
        Print(__FUNCTION__, " - Fatal error: More than one position open. Removing expert");
        ExpertRemove(); // Close the bot
        return;
    }

    // Check if there are more than two orders
    if (OrdersTotal() > 2)
    {
        Print(__FUNCTION__, " - Fatal error: More than two orders open. Removing expert");
        ExpertRemove(); // Close the bot
        return;
    }

    // check if orders are misplaced and properly spread relative to open position

}
//+------------------------------------------------------------------+
// -
void check_risk_rules()
{
    // check that sequence is init accurate to account balance XXX: ToDo

    // Loop through all open positions
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        string symbol=PositionGetSymbol(i);
        if(symbol!="")
        {
            double tp = PositionGetDouble(POSITION_TP);
            double sl = PositionGetDouble(POSITION_SL);
            double volume = PositionGetDouble(POSITION_VOLUME);

            // Check if TP and SL are set
            if (tp == 0 || sl == 0)
            {
                Print(__FUNCTION__, " - Warning: TP/SL not set for position with ticket: ", PositionGetInteger(POSITION_TICKET));
            }

            // Check that the volume matches one of the values in the Sequence array
            bool volume_ok = false;
            for (int j = 0; j < ArraySize(Sequence); j++)
            {
                if (volume == Sequence[j])
                {
                    volume_ok = true;
                    break;
                }
            }

            if (!volume_ok)
            {
                Print(__FUNCTION__, " - Warning: Volume for position with ticket: ", PositionGetInteger(POSITION_TICKET), " does not match any value in the Progression sequence array.");
            }
        }
    }
}
//+------------------------------------------------------------------+
// -
void check_forgotten_order()
{
    // Ensure that the session has ended and there are no open positions
    if (is_end_session == false || PositionSelect(_Symbol)) return;
    
    // Check if there is only one pending order
    if (OrdersTotal() == 1)
    {   
        ulong order_ticket = OrderGetTicket(0);
        if (order_ticket != 0)
        {
            double order_price = OrderGetDouble(ORDER_PRICE_OPEN);
            ulong order_ticket = OrderGetInteger(ORDER_TICKET);
            string order_comment = OrderGetString(ORDER_COMMENT);

            // Get the current market price
            double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

            // Calculate the distance relative to grid_size and grid_spread
            double threshold = grid_size + grid_spread * 2;
            double distance = MathAbs(current_price - order_price);

            // If the price is far from the order
            if (distance > threshold)
            {
                {
                Print(__FUNCTION__, " - Warning: Found 1 forgotten order: ",order_ticket,"with comment: ",order_comment);
                }
            }
        }
    }
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| CMP - Delay Management                                           |
//+------------------------------------------------------------------+
// -
void check_zero_position()
{
    // reason1: a position just closed within trading time leaving a delay
    // reason2: outside trading time
    // reason3: fatal error, unforeseen event, log status

    if (PositionSelect(_Symbol)) return;

    if (use_daily_session) post_session_clean_up();

    check_range_delay();
}
//+------------------------------------------------------------------+
// -
void check_range_delay()
{
    int orders_total = OrdersTotal();

    // If there is an open position or no pending orders, return (not a delay)
    if (PositionSelect(_Symbol) || orders_total == 0) return;
    
    // If the last position was a buy, return (not a range delay)
    if (last_saved_type == POSITION_TYPE_BUY) return;
    
    // Variables to store order prices and tickets
    double price1 = 0.0, price2 = 0.0;
    ulong buy_stop_ticket = 0, sell_stop_ticket = 0;

    if (orders_total == 2) // Continuation stop is present
    {
        // get pending orders details
        for (int i = orders_total - 1; i >= 0; i--)
        {
            ulong order_ticket = OrderGetTicket(i);
            if (order_ticket != 0)
            {
                if (OrderGetString(ORDER_SYMBOL) != _Symbol)
                    continue;

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
        }
        
        double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double distance = MathAbs(price1 - price2);
        double half_distance = (price1 + price2) / 2.0;
        // If the distance is less than or equal to grid_size plus twice the range spread, return
        if (distance <= (grid_size + grid_spread * 2)) return;// Range delay is already set

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
            }               
            else
            {
                Print(__FUNCTION__, " - Buy stop ticket not found. Unable to place replacement stop");
            }
        }
    }
    else if (orders_total == 1) // Outside trading session
    {
        post_session_clean_up();

        // Attempt to get the buy stop's ticket
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
                    buy_stop_ticket = order_ticket;
                    break;
                }
            }
        }

        // If no buy stop ticket is found, return
        if (buy_stop_ticket == 0) return;
        
        place_recovery_stop(buy_stop_ticket);
    }
    else // Mismanagement error
    {
        Print(__FUNCTION__, " - FATAL. Unseen. ", orders_total," orders exist.");
        //check_strategy_rules();
        check_core_rules();
    }
}
//+------------------------------------------------------------------+
// Helper function to
void post_session_clean_up()
{
    // Ensure that the session has ended and there are no open positions
    if (is_end_session == false || PositionSelect(_Symbol)) return;
    
    // Check if there is only one pending order
    if (OrdersTotal() == 1)
    {   
        ulong order_ticket = OrderGetTicket(0);
        if (order_ticket != 0)
        {
            double order_price = OrderGetDouble(ORDER_PRICE_OPEN);
            ulong order_ticket = OrderGetInteger(ORDER_TICKET);
            string order_comment = OrderGetString(ORDER_COMMENT);

            // Get the current market price
            double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

            // Calculate the distance relative to grid_size and grid_spread
            double threshold = grid_size + grid_spread * 2;
            double distance = MathAbs(current_price - order_price);

            // If the price is far from the order
            if (distance > threshold)
            {
                bool deleted = trade.OrderDelete(order_ticket);
                if (deleted)
                {
                    Print(__FUNCTION__, " - Deleted order with ticket: ", order_ticket, " and comment: ", order_comment, " as forgotten order cleanup ");
                }
                else
                {
                    Print(__FUNCTION__, " - Failed to delete order with ticket: ", order_ticket, " and comment: ", order_comment, " as forgotten order cleanup ");
                }
            }
        }
    }
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| CMP - Grid Stops                                                 |
//+------------------------------------------------------------------+
// -
void set_exits(ulong reference_ticket, double stop_size, int target_multiplier)
{
    if (PositionSelectByTicket(reference_ticket))
    {
        double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
        long position_type = PositionGetInteger(POSITION_TYPE);
        
        double target = stop_size*target_multiplier;
        double risk = stop_size;
        double take_profit = (position_type == POSITION_TYPE_BUY) ? open_price + target : open_price - target;
        double stop_loss = (position_type == POSITION_TYPE_BUY) ? open_price - risk : open_price + risk;
        
        // Modify the position with the new TP and SL values
        bool modified = trade.PositionModify(reference_ticket, stop_loss, take_profit);
        if (modified)
        {
            Print(__FUNCTION__, " - Take profit and stop loss set for ticket: ", reference_ticket, " TP: ", take_profit, " SL: ", stop_loss);
        }
        else
        {
            Print(__FUNCTION__, " - Failed to set take profit and stop loss for ticket: ", reference_ticket);
        }
    }
    else
    {
        Print(__FUNCTION__, " - Reference position not open or invalid ticket: ", reference_ticket);
    }
}
//+------------------------------------------------------------------+
// -
void place_continuation_stop(ulong reference_ticket)
{
    
    if (is_end_session) return;

    if (PositionSelectByTicket(reference_ticket))
    {
        // Get ticket details
        long ticket_type = PositionGetInteger(POSITION_TYPE);
        double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
        double take_profit = PositionGetDouble(POSITION_TP);

        // Check if there is a take profit set for the reference position
        if (take_profit == 0)
        {
            Print(__FUNCTION__, " - Failed to place continuation stop order. No take profit set for reference ticket: ", reference_ticket);
            return;
        }

        // Get lot size as the first term of the progression sequence
        double order_volume = Sequence[0];
        ENUM_ORDER_TYPE order_type = (ticket_type == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP;
        double order_price = (ticket_type == POSITION_TYPE_BUY) ? take_profit+grid_spread : take_profit;
         
        // Check if an order already exists at the calculated price
        ulong ticket_exists = order_exists_at_price(_Symbol, order_type, order_price);
        if (ticket_exists!=0)
        {
            Print(__FUNCTION__, " - Continuation stop order already exists at the calculated price for reference ticket: ",
                  reference_ticket, ", order ticket: ", ticket_exists);
            return;
        }

        // Place a stop order similar to the open position’s type
        string comment = "continuation " + EnumToString(order_type);
        bool placed = trade.OrderOpen(_Symbol, order_type, order_volume, 0.0, order_price, 0, 0, ORDER_TIME_GTC, 0, comment);
        if (placed)
        {
            ulong order_ticket = trade.ResultOrder(); // Get the ticket number of the placed order
            Print(__FUNCTION__, " - Continuation stop order placed on reference ticket: ", reference_ticket, ", order ticket: ", order_ticket, ", comment: ", comment);
        }
        else
        {
            Print(__FUNCTION__, " - Failed to place continuation stop order");
        }

    }
    else
    {
        Print(__FUNCTION__, " - Reference position not open");
    } // Fatal error
}
//+------------------------------------------------------------------+
// -
void place_recovery_stop(ulong reference_ticket)
{
    ENUM_ORDER_TYPE order_type=0;
    double order_price=0;
    double order_volume=0;
    
    if (PositionSelectByTicket(reference_ticket))
    {
        // Get ticket details
        long ticket_type = PositionGetInteger(POSITION_TYPE);
        double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
        double stop_loss = PositionGetDouble(POSITION_SL);
        double open_volume = PositionGetDouble(POSITION_VOLUME);

        // Check if there is a take profit set for the reference position
        if (stop_loss == 0)
        {
            Print(__FUNCTION__, " - Failed to place recovery stop order. No stop loss set for reference ticket: ", reference_ticket);
            return;
        }

        // Set order details
        int open_volume_index = get_volume_index(open_volume,Sequence); 
        order_volume = Sequence[open_volume_index+1];
        order_type = (ticket_type == POSITION_TYPE_SELL) ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP;
        order_price = (ticket_type == POSITION_TYPE_SELL) ? stop_loss+grid_spread : stop_loss;     
    }
    else if (OrderSelect(reference_ticket)) // order must be a recovery buy stop
    {       
        // Get ticket details
        long ticket_type = OrderGetInteger(ORDER_TYPE);
        double open_price = OrderGetDouble(ORDER_PRICE_OPEN);
        double open_volume = OrderGetDouble(ORDER_VOLUME_CURRENT);
        string comment = OrderGetString(ORDER_COMMENT);
        
        // Check if the reference order is a recovery buy stop
        if (ticket_type != ORDER_TYPE_BUY_STOP || (StringFind(comment, "recovery") == -1))
        {
            Print(__FUNCTION__, " - Failed to place replacement recovery sell stop order. Reference order: ", reference_ticket, " is not a recovery buy stop");
            return;
        }
        
        // Set order details 
        order_volume = open_volume;
        order_type = ORDER_TYPE_SELL_STOP;
        order_price = open_price - grid_size; 
    }
    else // Fatal error
    {
      Print(__FUNCTION__, " - FATAL. Recovery order can only be placed on open position or buy stop");
      return;
    } 

    // Check if an order already exists at the calculated price
     ulong ticket_exists = order_exists_at_price(_Symbol, order_type, order_price);
     if (ticket_exists!=0)
     {
         Print(__FUNCTION__, " - Recovery stop order already exists at the calculated price for reference ticket: ",
               reference_ticket, ", order ticket: ", ticket_exists);
         return;
     }

     // Place a stop order opposite to the open/pending position’s type
     string comment = "recovery " + EnumToString(order_type);
     bool placed = trade.OrderOpen(_Symbol, order_type, order_volume, 0.0, order_price, 0, 0, ORDER_TIME_GTC, 0, comment);
     if (placed)
     {
         ulong order_ticket = trade.ResultOrder(); // Get the ticket number of the placed order
         Print(__FUNCTION__, " - Recovery stop order placed on reference ticket: ", reference_ticket, ", order ticket: ", order_ticket, ", comment: ", comment);
     }
     else
     {
         Print(__FUNCTION__, " - Failed to place recovery stop order");// Potential invalid price, need to handle
     }
}
//+------------------------------------------------------------------+
// Helper function to
ulong order_exists_at_price(const string symbol, ENUM_ORDER_TYPE order_type, double order_price)
{
    for (int i = OrdersTotal() - 1; i >= 0; --i)
      {
        ulong order_ticket = OrderGetTicket(i);
        if (order_ticket!=0)
            {
            if (OrderGetString(ORDER_SYMBOL) == symbol 
               && OrderGetInteger(ORDER_TYPE) == order_type 
               && OrderGetDouble(ORDER_PRICE_OPEN) == order_price)
               {
                return order_ticket;
               }
            }
      }
    return 0;
}
//+------------------------------------------------------------------+
// Helper function to
int get_volume_index(double volume,const double &sequence[])
{
   for (int i=0;i<ArraySize(sequence);i++)
   {
      if (volume==sequence[i]) return i;
   }
   return -1;
}

