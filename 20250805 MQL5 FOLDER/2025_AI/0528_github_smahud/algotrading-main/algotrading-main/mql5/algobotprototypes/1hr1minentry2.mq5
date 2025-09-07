//+------------------------------------------------------------------+
//|                                              EMAvwapDiffEntry.mq5 |
//|                                    Copyright 2025, Shivam Shikhar |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Shivam Shikhar"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| Includes and Declarations                                        |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

// Define the enum for max loss type BEFORE inputs
enum ENUM_MAX_LOSS_TYPE
{
   PERCENT = 0,   // Percentage of account balance
   FIXED = 1      // Fixed dollar amount
};

// Declare trade object
CTrade trade;

// Indicator handles
int ema9_handle_H1;
int vwap_handle_H1;      // Handle for custom VWAP indicator on H1

// Global variables
datetime last_bar_time_H1 = 0;
datetime last_bar_time_M1 = 0;   // Track last 1-min bar for difference printing
const double FIXED_LOT_SIZE = 0.40;
const string SYMBOL = "ETHUSDm";
const ENUM_TIMEFRAMES TIMEFRAME_H1 = PERIOD_H1;

// Variables to track signal states
int current_signal = 0;    // 0 = no signal, 1 = bullish (EMA above VWAP), -1 = bearish (EMA below VWAP)
int previous_trade_direction = 0; // 0 = no previous trade, 1 = last trade was buy, -1 = last trade was sell
bool allow_new_trade = true;     // Flag to control when new trades can be taken

// Position tracking variables
double entry_price = 0;          // Entry price for the current position
double initial_stop_loss = 0;    // Initial stop loss level
bool partial_booking_done = false; // Flag to track if partial booking has been done for current position

// Stop Loss Settings
input string StopLossSettings = "---Stop Loss Settings---";
input bool UseStopLossAtVWAP = true;                // Use VWAP level as Stop Loss
input bool DynamicStopLoss = true;                  // Update stop loss with VWAP
input double AdditionalSLBuffer = 0.0;              // Additional SL buffer in points

// Max Loss Settings
input string MaxLossSettings = "---Max Loss Settings---";
input bool UseMaxLossPerTrade = false;               // Enable max loss per trade
input ENUM_MAX_LOSS_TYPE MaxLossType = FIXED;       // Max loss calculation method
input double MaxLossValue = 5.0;                    // Max loss value (5 USD)

// Entry Settings
input string EntrySettings = "---Entry Settings---";
input double MIN_ENTRY_DISTANCE = 4.0;             // Minimum EMA-VWAP difference for entry

// Partial Booking Settings
input string PartialBookingSettings = "---Partial Booking Settings---";
input bool UsePartialBooking = true;                // Enable partial booking strategy
input double PartialBookingRRRatio = 1.5;           // Reward-to-Risk ratio to take partial profits
input double PartialBookingPercent = 50.0;          // Percentage of position to close (1-99)
input bool TrailRemainingPosition = true;           // Enable trailing stop for remaining position
input double TrailToPercent = 25.0;                 // Where to trail stop (% of profit achieved, 0 = breakeven)

//+------------------------------------------------------------------+
//| Initialization Function                                          |
//+------------------------------------------------------------------+
void OnInit()
{
   // Create EMA9 indicator handle for H1
   ema9_handle_H1 = iMA(SYMBOL, TIMEFRAME_H1, 9, 0, MODE_EMA, PRICE_CLOSE);
   if(ema9_handle_H1 == INVALID_HANDLE)
   {
      Print("Failed to create EMA9 handle for H1. EA will terminate.");
      ExpertRemove();
      return;
   }

   // Create handle for custom VWAP indicator for H1
   vwap_handle_H1 = iCustom(SYMBOL, TIMEFRAME_H1, "VWAP_UTC_Final");
   if(vwap_handle_H1 == INVALID_HANDLE)
   {
      Print("Failed to create VWAP handle for H1. EA will terminate.");
      ExpertRemove();
      return;
   }

   // Initialize signal state
   InitializeSignalState();

   trade.SetDeviationInPoints(10); // Allow 1 pip slippage
   Print("EA initialized successfully on ", SYMBOL, " (Pure difference-based entry)");
   
   // Log stop loss settings
   if (UseStopLossAtVWAP)
      Print("Using VWAP as Stop Loss reference. Dynamic SL: ", DynamicStopLoss ? "Enabled" : "Disabled", 
            ", Additional buffer: ", AdditionalSLBuffer, " points");
            
   // Log max loss settings
   if (UseMaxLossPerTrade)
      Print("Max Loss per Trade: ", MaxLossType == PERCENT ? "Percentage" : "Fixed", 
            ", Value: ", MaxLossValue, MaxLossType == PERCENT ? "%" : " USD");
   
   // Log entry settings
   Print("Entry based ONLY on EMA-VWAP difference. Minimum distance: ", MIN_ENTRY_DISTANCE,
         ". Strict one trade per crossover enforced.");
   
   // Log partial booking settings
   if(UsePartialBooking)
      Print("Partial booking enabled at RR ratio: ", PartialBookingRRRatio, 
            ", Booking percent: ", PartialBookingPercent, "%",
            ", Trail remaining position: ", TrailRemainingPosition ? "Yes" : "No",
            ", Trail to level: ", TrailToPercent, "% of profit");
         
   // Initialize 1-minute timer for difference tracking
   last_bar_time_M1 = iTime(SYMBOL, PERIOD_M1, 0);
   
   // Log debugging info for max loss calculation
   if(UseMaxLossPerTrade)
   {
      // Print contract specs for verification
      double tickSize = SymbolInfoDouble(SYMBOL, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(SYMBOL, SYMBOL_TRADE_TICK_VALUE);
      double point = SymbolInfoDouble(SYMBOL, SYMBOL_POINT);
      double contractSize = SymbolInfoDouble(SYMBOL, SYMBOL_TRADE_CONTRACT_SIZE);
      
      Print("Symbol specs - Tick Size: ", tickSize, ", Tick Value: ", tickValue, 
            ", Point: ", point, ", Contract Size: ", contractSize);
            
      // Calculate example max loss
      double examplePrice = SymbolInfoDouble(SYMBOL, SYMBOL_ASK);
      double buyStopLoss = CalculateMaxLossStopLevel(true, examplePrice);
      double sellStopLoss = CalculateMaxLossStopLevel(false, examplePrice);
      
      Print("Example Max Loss calculation at price ", examplePrice, 
            " - Buy SL: ", buyStopLoss, " (", MathAbs(examplePrice - buyStopLoss), " points), ",
            "Sell SL: ", sellStopLoss, " (", MathAbs(sellStopLoss - examplePrice), " points)");
   }
}

//+------------------------------------------------------------------+
//| Initialize signal state based on current market conditions       |
//+------------------------------------------------------------------+
void InitializeSignalState()
{
   // Get H1 indicator values
   double ema9_H1[];
   ArraySetAsSeries(ema9_H1, true);
   if(CopyBuffer(ema9_handle_H1, 0, 0, 1, ema9_H1) < 1)
   {
      Print("Failed to copy H1 EMA9 data for initialization");
      return;
   }

   double vwap_H1[];
   ArraySetAsSeries(vwap_H1, true);
   if(CopyBuffer(vwap_handle_H1, 0, 0, 1, vwap_H1) < 1)
   {
      Print("Failed to copy H1 VWAP data for initialization");
      return;
   }
   
   // Set initial signal state
   if(ema9_H1[0] > vwap_H1[0])
   {
      current_signal = 1;  // EMA above VWAP (bullish)
      Print("Initial signal state: Bullish (EMA above VWAP)");
   }
   else
   {
      current_signal = -1; // EMA below VWAP (bearish)
      Print("Initial signal state: Bearish (EMA below VWAP)");
   }
   
   // Check if position exists and set previous trade direction
   if(PositionSelect(SYMBOL))
   {
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
         previous_trade_direction = 1;
         Print("Existing Buy position detected.");
      }
      else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
      {
         previous_trade_direction = -1;
         Print("Existing Sell position detected.");
      }
      
      // Store position information for partial booking
      entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
      initial_stop_loss = PositionGetDouble(POSITION_SL);
      partial_booking_done = false; // Assume no partial booking done yet for existing positions
      
      allow_new_trade = false;
      Print("Position already exists. New trades blocked until signal change.");
   }
   else
   {
      previous_trade_direction = 0;
      allow_new_trade = true;
      Print("No position exists. Ready to take a trade.");
   }
}

//+------------------------------------------------------------------+
//| Calculate maximum loss stop level                                |
//+------------------------------------------------------------------+
double CalculateMaxLossStopLevel(bool isBuy, double entryPrice)
{
   if (!UseMaxLossPerTrade)
      return 0.0; // Max loss not enabled
      
   double maxLossAmount = 0.0;
   double stopLevel = 0.0;
   int digits = (int)SymbolInfoInteger(SYMBOL, SYMBOL_DIGITS);
   
   // Calculate max loss in account currency
   if (MaxLossType == PERCENT)
   {
      double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      maxLossAmount = accountBalance * MaxLossValue / 100.0;
   }
   else // FIXED
   {
      maxLossAmount = MaxLossValue;
   }
   
   // Direct approach using point value calculation
   double point = SymbolInfoDouble(SYMBOL, SYMBOL_POINT);
   double lotStep = SymbolInfoDouble(SYMBOL, SYMBOL_VOLUME_STEP);
   double tickSize = SymbolInfoDouble(SYMBOL, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(SYMBOL, SYMBOL_TRADE_TICK_VALUE);
   
   // Normalize for ETHUSDm specifics
   if(tickValue <= 0 || tickSize <= 0)
   {
      // Default values for ETHUSDm if symbol info fails
      Print("Warning: Tick Value or Size invalid, using defaults");
      tickValue = 0.1;  // Approximate value for ETHUSDm
      tickSize = point; // Assume tick size is point
   }
   
   // Calculate price distance for $5 max loss (simplified)
   double priceDistance = 0;
   
   // Get a more accurate calculation based on direct price-per-pip
   double valuePerPoint = (tickValue / tickSize) * point * FIXED_LOT_SIZE;
   
   if(valuePerPoint > 0)
   {
      // Calculate how many points equal $5
      priceDistance = maxLossAmount / valuePerPoint;
      Print("Max loss ", maxLossAmount, "$ = ", priceDistance, " points (value per point: ", valuePerPoint, ")");
   }
   else
   {
      // Fallback calculation if above fails
      priceDistance = 15; // Safe default for ETHUSDm that should be ~$5 risk
      Print("Warning: Using fallback distance for max loss: ", priceDistance, " points");
   }
   
   // Calculate the stop level based on position direction
   if(isBuy)
   {
      stopLevel = NormalizeDouble(entryPrice - (priceDistance * point), digits);
   }
   else // Sell
   {
      stopLevel = NormalizeDouble(entryPrice + (priceDistance * point), digits);
   }
   
   return stopLevel;
}

//+------------------------------------------------------------------+
//| Main Tick Function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- H1 Bar Check for Dynamic SL Updates and Exit Check ---
   datetime current_bar_time_H1 = iTime(SYMBOL, TIMEFRAME_H1, 0);
   if(current_bar_time_H1 > last_bar_time_H1)
   {
      last_bar_time_H1 = current_bar_time_H1;

      // Get H1 indicator values
      double ema9_H1[];
      ArraySetAsSeries(ema9_H1, true);
      if(CopyBuffer(ema9_handle_H1, 0, 0, 2, ema9_H1) < 2)
      {
         Print("Failed to copy H1 EMA9 data");
         return;
      }

      double vwap_H1[];
      ArraySetAsSeries(vwap_H1, true);
      if(CopyBuffer(vwap_handle_H1, 0, 0, 2, vwap_H1) < 2)
      {
         Print("Failed to copy H1 VWAP data");
         return;
      }

      // Get previous H1 candle's close (for H1 exit)
      double close1_H1 = iClose(SYMBOL, TIMEFRAME_H1, 1);

      // Check exit condition if we have a position
      if(PositionSelect(SYMBOL))
      {
         CheckExitCondition(close1_H1, ema9_H1[1]);
      }
      
      // Update dynamic SL if enabled and a position exists
      if(PositionSelect(SYMBOL) && DynamicStopLoss && UseStopLossAtVWAP)
      {
         UpdateDynamicStopLoss(vwap_H1[1]);
      }
   }
   
   //--- Check for partial booking opportunity on every tick
   if(UsePartialBooking && PositionSelect(SYMBOL) && !partial_booking_done)
   {
      CheckPartialBookingOpportunity();
   }
   
   //--- 1-Minute Check for EMA-VWAP Difference Logging and Entry ---
   datetime current_bar_time_M1 = iTime(SYMBOL, PERIOD_M1, 0);
   if(current_bar_time_M1 > last_bar_time_M1)
   {
      last_bar_time_M1 = current_bar_time_M1;
      
      // Get current H1 indicator values
      double ema9_H1[];
      ArraySetAsSeries(ema9_H1, true);
      if(CopyBuffer(ema9_handle_H1, 0, 0, 2, ema9_H1) < 2) // Get 2 values for crossover detection
      {
         Print("Failed to copy H1 EMA9 data for difference calculation");
         return;
      }

      double vwap_H1[];
      ArraySetAsSeries(vwap_H1, true);
      if(CopyBuffer(vwap_handle_H1, 0, 0, 2, vwap_H1) < 2) // Get 2 values for crossover detection
      {
         Print("Failed to copy H1 VWAP data for difference calculation");
         return;
      }
      
      // Calculate the current difference
      double ema_vwap_diff = ema9_H1[0] - vwap_H1[0];
      double abs_diff = MathAbs(ema_vwap_diff);
      string direction = ema_vwap_diff > 0 ? "above" : "below";
      
      // Print the difference
      Print("EMA-VWAP Difference (H1): ", DoubleToString(ema_vwap_diff, 2), 
            " (EMA is ", direction, " VWAP by ", DoubleToString(abs_diff, 2), " points)");
      
      // Calculate previous difference to detect crossovers
      double prev_ema_vwap_diff = ema9_H1[1] - vwap_H1[1];
      
      // Determine new signal direction based on current EMA-VWAP difference
      int new_signal = (ema_vwap_diff > 0) ? 1 : -1;
      
      // Check if signal direction has changed (crossover detected)
      if(new_signal != current_signal)
      {
         string old_signal_str = (current_signal == 1) ? "Bullish" : "Bearish";
         string new_signal_str = (new_signal == 1) ? "Bullish" : "Bearish";
         
         Print("Crossover detected! Signal changed from ", old_signal_str, " to ", new_signal_str,
               ". Previous diff: ", DoubleToString(prev_ema_vwap_diff, 2),
               ", Current diff: ", DoubleToString(ema_vwap_diff, 2));
         
         current_signal = new_signal;
         allow_new_trade = true; // Reset flag to allow a new trade
         
         // Reset previous trade direction when no position exists
         if(!PositionSelect(SYMBOL))
         {
            previous_trade_direction = 0; // Reset previous trade direction
            Print("No active position - previous trade direction reset.");
         }
         
         Print("New trade allowed for this signal direction.");
      }
      
      // Check for entry based on EMA-VWAP difference with strict one-trade-per-crossover rule
      if(!PositionSelect(SYMBOL))
      {
         if(allow_new_trade)
         {
            // If the current signal direction is the same as the previous trade direction,
            // we need to block additional trades in the same direction
            if(current_signal == previous_trade_direction)
            {
               Print("Blocking additional trade in same direction (", 
                     (current_signal == 1 ? "Buy" : "Sell"), 
                     "). Wait for crossover.");
               allow_new_trade = false;
            }
            else
            {
               // Check if difference meets minimum threshold for entry
               if(abs_diff >= MIN_ENTRY_DISTANCE)
               {
                  int digits = (int)SymbolInfoInteger(SYMBOL, SYMBOL_DIGITS);
                  double point = SymbolInfoDouble(SYMBOL, SYMBOL_POINT);
                  double buffer = AdditionalSLBuffer * point;
                  double vwap_sl = 0;
                  double max_loss_sl = 0;
                  double final_sl = 0;
                  
                  // For bullish signal (EMA above VWAP)
                  if(current_signal == 1)
                  {
                     // Calculate entry price for buy position
                     double buy_price = SymbolInfoDouble(SYMBOL, SYMBOL_ASK);
                     
                     // Calculate VWAP-based stop loss
                     if(UseStopLossAtVWAP)
                        vwap_sl = NormalizeDouble(vwap_H1[0] - buffer, digits);
                     else
                        vwap_sl = NormalizeDouble(vwap_H1[0] - 3 * point, digits);
                     
                     // Calculate max loss stop level if enabled
                     if(UseMaxLossPerTrade)
                     {
                        max_loss_sl = CalculateMaxLossStopLevel(true, buy_price);
                        
                        // Log max loss stop level
                        Print("Max loss stop calculated: ", max_loss_sl, 
                              " (", MaxLossType == PERCENT ? MaxLossValue : MaxLossValue, 
                              MaxLossType == PERCENT ? "% of balance" : " USD", ")");
                              
                        // Check if max_loss_sl is valid
                        if(max_loss_sl <= 0 || max_loss_sl >= buy_price)
                        {
                           Print("Warning: Invalid max loss stop level. Using VWAP stop instead.");
                           max_loss_sl = 0; // Invalidate it
                        }
                     }
                     
                     // Use the higher (tighter) of the two stop levels for buy positions
                     if(UseMaxLossPerTrade && max_loss_sl > 0 && max_loss_sl > vwap_sl)
                     {
                        final_sl = max_loss_sl;
                        Print("Using max loss stop level (higher than VWAP stop)");
                     }
                     else
                     {
                        final_sl = vwap_sl;
                        Print("Using VWAP-based stop level");
                     }
                     
                     // Verify the SL is valid (not too close to current price)
                     double min_stop = buy_price - (SymbolInfoInteger(SYMBOL, SYMBOL_TRADE_STOPS_LEVEL) * point);
                     if(final_sl > min_stop)
                     {
                        Print("Warning: Stop loss too close to current price. Adjusting to minimum allowed distance.");
                        final_sl = min_stop;
                     }
                     
                     if(trade.Buy(FIXED_LOT_SIZE, SYMBOL, 0.0, final_sl, 0.0))
                     {
                        Print("Buy trade opened with SL: ", final_sl, ". Distance: ", abs_diff, " units");
                        previous_trade_direction = 1;
                        allow_new_trade = false; // Disable new trades until next crossover
                        
                        // Store entry data for partial booking
                        entry_price = buy_price;
                        initial_stop_loss = final_sl;
                        partial_booking_done = false;
                     }
                     else
                     {
                        Print("Failed to open Buy trade. Error: ", GetLastError(), 
                              ". Buy price: ", buy_price, ", SL: ", final_sl);
                     }
                  }
                  // For bearish signal (EMA below VWAP)
                  else if(current_signal == -1)
                  {
                     // Calculate entry price for sell position
                     double sell_price = SymbolInfoDouble(SYMBOL, SYMBOL_BID);
                     
                     // Calculate VWAP-based stop loss
                     if(UseStopLossAtVWAP)
                        vwap_sl = NormalizeDouble(vwap_H1[0] + buffer, digits);
                     else
                        vwap_sl = NormalizeDouble(vwap_H1[0] + 3 * point, digits);
                     
                     // Calculate max loss stop level if enabled
                     if(UseMaxLossPerTrade)
                     {
                        max_loss_sl = CalculateMaxLossStopLevel(false, sell_price);
                        
                        // Log max loss stop level
                        Print("Max loss stop calculated: ", max_loss_sl, 
                              " (", MaxLossType == PERCENT ? MaxLossValue : MaxLossValue, 
                              MaxLossType == PERCENT ? "% of balance" : " USD", ")");
                              
                        // Check if max_loss_sl is valid
                        if(max_loss_sl <= 0 || max_loss_sl <= sell_price)
                        {
                           Print("Warning: Invalid max loss stop level. Using VWAP stop instead.");
                           max_loss_sl = 0; // Invalidate it
                        }
                     }
                     
                     // Use the lower (tighter) of the two stop levels for sell positions
                     if(UseMaxLossPerTrade && max_loss_sl > 0 && max_loss_sl < vwap_sl)
                     {
                        final_sl = max_loss_sl;
                        Print("Using max loss stop level (lower than VWAP stop)");
                     }
                     else
                     {
                        final_sl = vwap_sl;
                        Print("Using VWAP-based stop level");
                     }
                     
                     // Verify the SL is valid (not too close to current price)
                     double min_stop = sell_price + (SymbolInfoInteger(SYMBOL, SYMBOL_TRADE_STOPS_LEVEL) * point);
                     if(final_sl < min_stop)
                     {
                        Print("Warning: Stop loss too close to current price. Adjusting to minimum allowed distance.");
                        final_sl = min_stop;
                     }
                     
                     if(trade.Sell(FIXED_LOT_SIZE, SYMBOL, 0.0, final_sl, 0.0))
                     {
                        Print("Sell trade opened with SL: ", final_sl, ". Distance: ", abs_diff, " units");
                        previous_trade_direction = -1;
                        allow_new_trade = false; // Disable new trades until next crossover
                        
                        // Store entry data for partial booking
                        entry_price = sell_price;
                        initial_stop_loss = final_sl;
                        partial_booking_done = false;
                     }
                     else
                     {
                        Print("Failed to open Sell trade. Error: ", GetLastError(), 
                              ". Sell price: ", sell_price, ", SL: ", final_sl);
                     }
                  }
               }
               else
               {
                  Print("EMA-VWAP difference (", abs_diff, ") is below the entry threshold (", MIN_ENTRY_DISTANCE, ")");
               }
            }
         }
         else
         {
            Print("No position, but new trade blocked until crossover. Current signal: ", 
                 (current_signal == 1 ? "Bullish" : "Bearish"), 
                 ", Previous trade: ", 
                 (previous_trade_direction == 1 ? "Buy" : (previous_trade_direction == -1 ? "Sell" : "None")));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check for partial booking opportunity                           |
//+------------------------------------------------------------------+
void CheckPartialBookingOpportunity()
{
   // Make sure we have a position
   if(!PositionSelect(SYMBOL) || partial_booking_done) return;
   
   // Get current position details
   long position_type = PositionGetInteger(POSITION_TYPE);
   double current_price = (position_type == POSITION_TYPE_BUY) ? 
                           SymbolInfoDouble(SYMBOL, SYMBOL_BID) : 
                           SymbolInfoDouble(SYMBOL, SYMBOL_ASK);
   double position_volume = PositionGetDouble(POSITION_VOLUME);
   double risk_amount = MathAbs(entry_price - initial_stop_loss);
   double current_reward = 0;
   
   // Calculate current reward based on position type
   if(position_type == POSITION_TYPE_BUY)
   {
      current_reward = current_price - entry_price;
   }
   else // POSITION_TYPE_SELL
   {
      current_reward = entry_price - current_price;
   }
   
   // Calculate current reward-to-risk ratio
   double current_rr_ratio = (risk_amount != 0) ? (current_reward / risk_amount) : 0;
   
   // Check if we've reached the partial booking threshold
   if(current_rr_ratio >= PartialBookingRRRatio)
   {
      // Calculate volume to close
      double volume_to_close = NormalizeDouble(position_volume * (PartialBookingPercent / 100.0), 2);
      
      // Ensure minimum volume
      double min_volume = SymbolInfoDouble(SYMBOL, SYMBOL_VOLUME_MIN);
      if(volume_to_close < min_volume) volume_to_close = min_volume;
      
      // Make sure we don't try to close more than we have
      if(volume_to_close > position_volume) volume_to_close = position_volume;
      
      // Close partial position
      if(trade.PositionClosePartial(SYMBOL, volume_to_close))
      {
         Print("Partial booking executed: Closed ", volume_to_close, " lots (", PartialBookingPercent, 
               "%) at RR ratio: ", current_rr_ratio);
         
         // Trailing stop for remaining position if enabled
         if(TrailRemainingPosition && PositionSelect(SYMBOL))
         {
            // Adjust stop loss to breakeven or partial profit level
            double new_sl = 0;
            int digits = (int)SymbolInfoInteger(SYMBOL, SYMBOL_DIGITS);
            
            if(position_type == POSITION_TYPE_BUY)
            {
               // Calculate new stop loss
               if(TrailToPercent <= 0)
                  new_sl = NormalizeDouble(entry_price, digits); // Breakeven
               else
                  new_sl = NormalizeDouble(entry_price + (current_reward * TrailToPercent / 100.0), digits);
               
               // Only move stop loss up for buy positions
               if(new_sl > initial_stop_loss)
               {
                  if(trade.PositionModify(SYMBOL, new_sl, PositionGetDouble(POSITION_TP)))
                     Print("Trailing stop moved to: ", new_sl, " (", TrailToPercent, "% of profit secured)");
                  else
                     Print("Failed to update trailing stop. Error: ", GetLastError());
               }
            }
            else // POSITION_TYPE_SELL
            {
               // Calculate new stop loss
               if(TrailToPercent <= 0)
                  new_sl = NormalizeDouble(entry_price, digits); // Breakeven
               else
                  new_sl = NormalizeDouble(entry_price - (current_reward * TrailToPercent / 100.0), digits);
               
               // Only move stop loss down for sell positions
               if(new_sl < initial_stop_loss)
               {
                  if(trade.PositionModify(SYMBOL, new_sl, PositionGetDouble(POSITION_TP)))
                     Print("Trailing stop moved to: ", new_sl, " (", TrailToPercent, "% of profit secured)");
                  else
                     Print("Failed to update trailing stop. Error: ", GetLastError());
               }
            }
         }
         
         partial_booking_done = true;
      }
      else
      {
         Print("Failed to execute partial booking. Error: ", GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| Update Dynamic Stop Loss based on VWAP                          |
//+------------------------------------------------------------------+
void UpdateDynamicStopLoss(double current_vwap)
{
   if(!PositionSelect(SYMBOL)) return;
   
   int digits = (int)SymbolInfoInteger(SYMBOL, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(SYMBOL, SYMBOL_POINT);
   double buffer = AdditionalSLBuffer * point;
   
   long position_type = PositionGetInteger(POSITION_TYPE);
   double current_sl = PositionGetDouble(POSITION_SL);
   double new_vwap_sl = 0;
   double final_sl = 0;
   
   // Calculate new stop loss based on position type and VWAP
   if(position_type == POSITION_TYPE_BUY)
   {
      new_vwap_sl = NormalizeDouble(current_vwap - buffer, digits);
      
      // Check if max loss stop level is still relevant (for position open for some time)
      double max_loss_sl = 0;
      if(UseMaxLossPerTrade)
      {
         max_loss_sl = CalculateMaxLossStopLevel(true, entry_price);
         
         // Validate the max loss SL
         if(max_loss_sl <= 0 || max_loss_sl >= entry_price)
         {
            Print("Warning: Invalid max loss stop level during update. Ignoring.");
            max_loss_sl = 0;
         }
      }
      
      // Select the tighter of the two stops
      if(UseMaxLossPerTrade && max_loss_sl > 0 && max_loss_sl > new_vwap_sl)
      {
         final_sl = max_loss_sl;
      }
      else
      {
         final_sl = new_vwap_sl;
      }
      
      // Only move SL up (safer) for buy positions
      if(final_sl > current_sl && current_sl > 0)
      {
         // Verify SL is not too close to current price
         double current_price = SymbolInfoDouble(SYMBOL, SYMBOL_BID);
         double min_stop_level = current_price - (SymbolInfoInteger(SYMBOL, SYMBOL_TRADE_STOPS_LEVEL) * point);
         
         if(final_sl > min_stop_level)
         {
            Print("Warning: Dynamic SL too close to current price. Using minimum allowed distance.");
            final_sl = min_stop_level;
         }
         
         if(trade.PositionModify(SYMBOL, final_sl, PositionGetDouble(POSITION_TP)))
            Print("Dynamic SL updated for Buy position: ", final_sl, 
                  (final_sl == max_loss_sl) ? " (max loss limit)" : " (based on VWAP)");
         else
            Print("Failed to update dynamic SL. Error: ", GetLastError());
      }
   }
   else if(position_type == POSITION_TYPE_SELL)
   {
      new_vwap_sl = NormalizeDouble(current_vwap + buffer, digits);
      
      // Check if max loss stop level is still relevant
      double max_loss_sl = 0;
      if(UseMaxLossPerTrade)
      {
         max_loss_sl = CalculateMaxLossStopLevel(false, entry_price);
         
         // Validate the max loss SL
         if(max_loss_sl <= 0 || max_loss_sl <= entry_price)
         {
            Print("Warning: Invalid max loss stop level during update. Ignoring.");
            max_loss_sl = 0;
         }
      }
      
      // Select the tighter of the two stops
      if(UseMaxLossPerTrade && max_loss_sl > 0 && max_loss_sl < new_vwap_sl)
      {
         final_sl = max_loss_sl;
      }
      else
      {
         final_sl = new_vwap_sl;
      }
      
      // Only move SL down (safer) for sell positions
      if((final_sl < current_sl || current_sl == 0) && final_sl > 0)
      {
         // Verify SL is not too close to current price
         double current_price = SymbolInfoDouble(SYMBOL, SYMBOL_ASK);
         double min_stop_level = current_price + (SymbolInfoInteger(SYMBOL, SYMBOL_TRADE_STOPS_LEVEL) * point);
         
         if(final_sl < min_stop_level)
         {
            Print("Warning: Dynamic SL too close to current price. Using minimum allowed distance.");
            final_sl = min_stop_level;
         }
         
         if(trade.PositionModify(SYMBOL, final_sl, PositionGetDouble(POSITION_TP)))
            Print("Dynamic SL updated for Sell position: ", final_sl, 
                  (final_sl == max_loss_sl) ? " (max loss limit)" : " (based on VWAP)");
         else
            Print("Failed to update dynamic SL. Error: ", GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| Check Exit Condition                                             |
//+------------------------------------------------------------------+
void CheckExitCondition(double close1_H1, double ema9_prev_H1)
{
   if(!PositionSelect(SYMBOL)) return;
   
   // Store the position type before closing (for reference in logging)
   long position_type = PositionGetInteger(POSITION_TYPE);
   
   if(position_type == POSITION_TYPE_BUY)
   {
      if(close1_H1 < ema9_prev_H1)
      {
         if(trade.PositionClose(SYMBOL))
         {
            Print("Buy position closed (H1 Exit) - previous H1 candle closed below H1 EMA9");
            // Modified to set allow_new_trade to true when position is closed
            allow_new_trade = true; // Changed from false to true
            Print("Trade closed. New trades will be allowed after next crossover.");
         }
         else
            Print("Failed to close Buy position. Error: ", GetLastError());
      }
   }
   else if(position_type == POSITION_TYPE_SELL)
   {
      if(close1_H1 > ema9_prev_H1)
      {
         if(trade.PositionClose(SYMBOL))
         {
            Print("Sell position closed (H1 Exit) - previous H1 candle closed above H1 EMA9");
            // Modified to set allow_new_trade to true when position is closed
            allow_new_trade = true; // Changed from false to true
            Print("Trade closed. New trades will be allowed after next crossover.");
         }
         else
            Print("Failed to close Sell position. Error: ", GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| Deinitialization Function                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(ema9_handle_H1 != INVALID_HANDLE)
      IndicatorRelease(ema9_handle_H1);
   if(vwap_handle_H1 != INVALID_HANDLE)
      IndicatorRelease(vwap_handle_H1);
   Print("EA deinitialized. Reason: ", reason);
}