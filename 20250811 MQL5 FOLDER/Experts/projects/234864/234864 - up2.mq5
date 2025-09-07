//+------------------------------------------------------------------+
//| Expert Advisor for MetaTrader 5                                   |
//| Monitors closed trades and places new pending orders             |
//| Fully MQL5 compatible, no MQL4 remnants                          |
//+------------------------------------------------------------------+

#include <Trade/Trade.mqh>

// Global variables
int magic_number = 12345;          // Unique magic number for orders placed by this EA
string log_file = "EA_Log.txt";    // Log file name for event recording
bool last_connected = true;         // Tracks previous connection state
datetime ExpiryDate = D'2025.03.30 00:00'; // Expiry date and time for the EA

// Global variables for testing
bool test_order_placed = false;    // Flag to ensure order is placed only once
bool dotesting=false;
datetime start_time;               // Time when EA was initialized

// Create a global structure to store position info
struct PositionInfo {
   ulong position_id;
   double tp;
   double sl;
   datetime time;
};

// Create an array to store position information
PositionInfo positions_info[100]; // Adjust size as needed
int positions_count = 0;

//+------------------------------------------------------------------+
//| Helper Functions                                                 |
//+------------------------------------------------------------------+

// Logs events to a file with timestamp
void LogEvent(string message)
  {
   int handle = FileOpen(log_file, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ | FILE_SHARE_WRITE);
   if(handle != INVALID_HANDLE)
     {
      FileSeek(handle, 0, SEEK_END);
      string time = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES);
      FileWrite(handle, time + " - " + message);
      FileClose(handle);
     }
  }

// Checks for existing pending orders with the same parameters
bool HasDuplicateOrder(string symbol, ENUM_ORDER_TYPE order_type, double price)
  {
   double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(OrderGetTicket(i)))
        {
         if(OrderGetString(ORDER_SYMBOL) == symbol &&
            OrderGetInteger(ORDER_TYPE) == order_type &&
            MathAbs(OrderGetDouble(ORDER_PRICE_OPEN) - price) < tick_size)
           {
            return true; // Duplicate found
           }
        }
     }
   return false; // No duplicate
  }

// Places a new pending order with the original parameters
void PlacePendingOrder(string symbol, ENUM_ORDER_TYPE order_type, double price, double lot_size, double tp, double sl)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS); // Get symbol's precision
   
   // Get the minimum stop level in points
   int stop_level = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double min_distance = stop_level * point;
   
   // Get current bid/ask prices
   double current_bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double current_ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   
   // Adjust price if it's too close to market price
   bool price_adjusted = false;
   double original_price = price;
   
   // First adjust the entry price based on stop level
   switch(order_type) {
      case ORDER_TYPE_BUY_LIMIT:
         if(current_ask - price < min_distance) {
            price = current_ask - min_distance;
            price_adjusted = true;
         }
         break;
      case ORDER_TYPE_BUY_STOP:
         if(price - current_ask < min_distance) {
            price = current_ask + min_distance;
            price_adjusted = true;
         }
         break;
      case ORDER_TYPE_SELL_LIMIT:
         if(price - current_bid < min_distance) {
            price = current_bid + min_distance;
            price_adjusted = true;
         }
         break;
      case ORDER_TYPE_SELL_STOP:
         if(current_bid - price < min_distance) {
            price = current_bid - min_distance;
            price_adjusted = true;
         }
         break;
   }
   
   // Now adjust SL and TP based on the order type and adjusted price
   double original_sl = sl;
   double original_tp = tp;
   bool sl_adjusted = false;
   bool tp_adjusted = false;
   
   switch(order_type) {
      case ORDER_TYPE_BUY_LIMIT:
      case ORDER_TYPE_BUY_STOP:
         // For buy orders: SL must be below price and TP must be above price
         if(price - sl < min_distance) {
            sl = price - min_distance;
            sl_adjusted = true;
         }
         if(tp - price < min_distance && tp != 0) {
            tp = price + min_distance;
            tp_adjusted = true;
         }
         break;
         
      case ORDER_TYPE_SELL_LIMIT:
      case ORDER_TYPE_SELL_STOP:
         // For sell orders: SL must be above price and TP must be below price
         if(sl - price < min_distance && sl != 0) {
            sl = price + min_distance;
            sl_adjusted = true;
         }
         if(price - tp < min_distance && tp != 0) {
            tp = price - min_distance;
            tp_adjusted = true;
         }
         break;
   }
   
   // Log adjustments
   if(price_adjusted) {
      LogEvent("Adjusted " + EnumToString(order_type) + " price from " + 
               DoubleToString(original_price, digits) + " to " + 
               DoubleToString(price, digits) + " due to stop level requirements");
   }
   
   if(sl_adjusted) {
      LogEvent("Adjusted SL from " + DoubleToString(original_sl, digits) + 
               " to " + DoubleToString(sl, digits) + " due to stop level requirements");
   }
   
   if(tp_adjusted) {
      LogEvent("Adjusted TP from " + DoubleToString(original_tp, digits) + 
               " to " + DoubleToString(tp, digits) + " due to stop level requirements");
   }
   
   // Place the order with the adjusted values
   MqlTradeRequest request = {};
   request.action = TRADE_ACTION_PENDING;
   request.symbol = symbol;
   request.volume = lot_size;
   request.type = order_type;
   request.price = price;
   request.tp = tp;              
   request.sl = sl;              
   request.magic = magic_number; 
   MqlTradeResult result = {0};
   
   if(OrderSend(request, result)) {
      LogEvent("Placed " + EnumToString(order_type) + " order for " + symbol + " at " + DoubleToString(price, digits));
   } else {
      LogEvent("Failed to place order: " + IntegerToString(result.retcode) + " - " + GetLastErrorDescription(result.retcode));
   }
}

// Helper function to get error description
string GetLastErrorDescription(int error_code) {
   switch(error_code) {
      case 10008: return "Price invalid";
      case 10009: return "Stop Loss invalid";
      case 10010: return "Take Profit invalid";
      case 10016: return "Insufficient margin";
      case 10026: return "Stop levels too close";
      default: return "Error " + IntegerToString(error_code);
   }
}

//+------------------------------------------------------------------+
//| EA Event Handlers                                                |
//+------------------------------------------------------------------+

// Initialization function
int OnInit()
  {
   EventSetTimer(5); // Set timer to check connection every 5 seconds
   last_connected = TerminalInfoInteger(TERMINAL_CONNECTED); // Initial connection state
   start_time = TimeCurrent();    // Record the start time
   test_order_placed = false;     // Reset the flag
   positions_count = 0;           // Reset position tracking
   LogEvent("EA started");
   return(INIT_SUCCEEDED);
  }

// Deinitialization function
void OnDeinit(const int reason)
  {
   LogEvent("EA stopped");
   EventKillTimer(); // Stop the timer
  }

// Timer function to monitor connection status
void OnTimer()
  {
// Check if the EA has expired
   if(TimeCurrent() >= ExpiryDate)
     {
      Print("EA has expired. Please contact developer. ");
      ExpertRemove();
      return; // Stop further execution
     }
   if(dotesting)
     {
      // For testing: Place a one-time buy order after 30 minutes
      if(test_order_placed==true && TimeCurrent() >= start_time + 30*60)
        {
         // Get current symbol and price information
         string symbol = _Symbol;
         double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
         double lot_size = 0.1;  // 0.1 lot for testing
         // Set stop loss and take profit (50 pips each)
         double pip_value = SymbolInfoDouble(symbol, SYMBOL_POINT) *
                            (SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 3 ||
                             SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 5 ? 10 : 1);
         double sl = price - 20 * pip_value;  // 50 pips below entry
         double tp = price + 20 * pip_value;  // 50 pips above entry
         // Create and execute a market buy order
         MqlTradeRequest request = {};
         request.action = TRADE_ACTION_DEAL;
         request.symbol = symbol;
         request.volume = lot_size;
         request.type = ORDER_TYPE_BUY;
         request.price = price;
         request.tp = tp;
         request.sl = sl;
         request.magic = magic_number;
         request.comment = "Test buy order";
         MqlTradeResult result = {0};
         if(OrderSend(request, result))
           {
            LogEvent("TEST: Placed market BUY order for " + symbol + " at " + DoubleToString(price, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
            Print("TEST ORDER - Buy order placed: Price=", price, ", SL=", sl, ", TP=", tp);
            test_order_placed = true;  // Set flag to prevent duplicate test orders
           }
         else
           {
            LogEvent("TEST: Failed to place test order: " + IntegerToString(result.retcode));
           }
        }
     }
// Regular connection check logic
   bool connected = TerminalInfoInteger(TERMINAL_CONNECTED);
   if(connected != last_connected)
     {
      if(connected)
        {
         LogEvent("Reconnected to the server");
        }
      else
        {
         LogEvent("Disconnected from the server");
        }
      last_connected = connected;
     }
  }

// Trade transaction handler to detect position closures
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
  {
   // First update our position tracking before processing the transaction
   UpdatePositionsInfo();
   
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD && trans.deal_type == DEAL_ENTRY_OUT)
     {
      // Check if the position is fully closed
      bool position_exists = false;
      for(int i = 0; i < PositionsTotal(); i++)
        {
         string pos_symbol = PositionGetSymbol(i);
         if(PositionSelect(pos_symbol))
           {
            if(PositionGetInteger(POSITION_IDENTIFIER) == trans.position)
              {
               position_exists = true;
               break;
              }
           }
        }
      if(!position_exists)   // Position is fully closed
        {
         Print("Position is fully closed, ID: ", trans.position);
         
         // Get stored TP/SL values for the closed position
         double tp = GetStoredTP(trans.position);
         double sl = GetStoredSL(trans.position);
         
         Print("Retrieved from tracking - TP: ", tp, " SL: ", sl);
         
         // Only proceed with history selection if we need other details
         if(HistorySelectByPosition(trans.position))
           {
            for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
              {
               ulong deal_ticket = HistoryDealGetTicket(i);
               Print("deal_ticket: ", deal_ticket);
               if(HistoryDealGetInteger(deal_ticket, DEAL_ENTRY) == DEAL_ENTRY_IN && HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID) == trans.position)
                 {
                  // Found the opening deal - get everything EXCEPT TP/SL
                  string symbol = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
                  double open_price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
                  double lot_size = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
                  ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
                  
                  // Use the STORED TP/SL values instead of trying to get them from history
                  // If we didn't have stored values, fall back to the calculated method
                  if(tp == 0 || sl == 0) {
                     // Calculate default TP/SL if stored values aren't available
                     double pip_value = SymbolInfoDouble(symbol, SYMBOL_POINT) *
                                       (SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 3 || 
                                        SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 5 ? 10 : 1);
                     
                     if(deal_type == DEAL_TYPE_BUY) {
                        tp = open_price + 20 * pip_value;
                        sl = open_price - 20 * pip_value;
                     } else { // SELL
                        tp = open_price - 20 * pip_value;
                        sl = open_price + 20 * pip_value;
                     }
                  }
                  
                  // Determine order type based on current market price vs. entry price
                  double current_price = SymbolInfoDouble(symbol, SYMBOL_BID);
                  ENUM_ORDER_TYPE order_type;
                  
                  if(deal_type == DEAL_TYPE_BUY) {
                     if(current_price < open_price) {
                        order_type = ORDER_TYPE_BUY_STOP;
                     } else {
                        order_type = ORDER_TYPE_BUY_LIMIT;
                     }
                  } else if(deal_type == DEAL_TYPE_SELL) {
                     if(current_price > open_price) {
                        order_type = ORDER_TYPE_SELL_STOP;
                     } else {
                        order_type = ORDER_TYPE_SELL_LIMIT;
                     }
                  }
                  
                  // Place the pending order with the tracked TP and SL values
                  Print("Placing pending order - Symbol: ", symbol, ", Price: ", open_price, 
                        ", Lots: ", lot_size, ", TP: ", tp, ", SL: ", sl);
                  
                  if(!HasDuplicateOrder(symbol, order_type, open_price)) {
                     PlacePendingOrder(symbol, order_type, open_price, lot_size, tp, sl);
                  } else {
                     LogEvent("Duplicate order detected, not placing new order");
                  }
                  break; // Assume one opening deal per position for simplicity
                 }
              }
           }
        }
     }
  }

// In OnTick() or another regularly called function, update the position info
void UpdatePositionsInfo() {
   for(int i = 0; i < PositionsTotal(); i++) {
      string symbol = PositionGetSymbol(i);
      if(PositionSelect(symbol)) {
         ulong position_id = PositionGetInteger(POSITION_IDENTIFIER);
         double tp = PositionGetDouble(POSITION_TP);
         double sl = PositionGetDouble(POSITION_SL);
         
         // Check if position is already tracked
         bool found = false;
         for(int j = 0; j < positions_count; j++) {
            if(positions_info[j].position_id == position_id) {
               // Update existing info
               positions_info[j].tp = tp;
               positions_info[j].sl = sl;
               positions_info[j].time = TimeCurrent();
               found = true;
               break;
            }
         }
         
         // Add new position
         if(!found && positions_count < 100) {
            positions_info[positions_count].position_id = position_id;
            positions_info[positions_count].tp = tp;
            positions_info[positions_count].sl = sl;
            positions_info[positions_count].time = TimeCurrent();
            positions_count++;
         }
      }
   }
}

// Then in OnTradeTransaction(), find the stored TP/SL
double GetStoredTP(ulong position_id) {
   for(int i = 0; i < positions_count; i++) {
      if(positions_info[i].position_id == position_id) {
         return positions_info[i].tp;
      }
   }
   return 0; // Default if not found
}

double GetStoredSL(ulong position_id) {
   for(int i = 0; i < positions_count; i++) {
      if(positions_info[i].position_id == position_id) {
         return positions_info[i].sl;
      }
   }
   return 0; // Default if not found
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
