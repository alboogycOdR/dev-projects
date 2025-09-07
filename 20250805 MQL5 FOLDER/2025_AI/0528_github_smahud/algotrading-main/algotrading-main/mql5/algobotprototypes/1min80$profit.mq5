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

// Declare trade object
CTrade trade;

// Indicator handles
int ema9_handle_M15;
int vwap_handle_M15;      // Handle for custom VWAP indicator on M15

// Global variables
datetime last_bar_time_M15 = 0;
datetime last_bar_time_M1 = 0;   // Track last 1-min bar for difference printing
const double FIXED_LOT_SIZE = 0.20;
const string SYMBOL = "ETHUSDm";
const ENUM_TIMEFRAMES TIMEFRAME_M15 = PERIOD_M15;

// Variables to track signal states
int current_signal = 0;    // 0 = no signal, 1 = bullish (EMA above VWAP), -1 = bearish (EMA below VWAP)
int previous_trade_direction = 0; // 0 = no previous trade, 1 = last trade was buy, -1 = last trade was sell
bool allow_new_trade = true;     // Flag to control when new trades can be taken

// Stop Loss Settings
input string StopLossSettings = "---Stop Loss Settings---";
input bool UseStopLossAtVWAP = true;                // Use VWAP level as Stop Loss
input bool DynamicStopLoss = true;                  // Update stop loss with VWAP
input double AdditionalSLBuffer = 0.0;              // Additional SL buffer in points

// Entry Settings
input string EntrySettings = "---Entry Settings---";
input double MIN_ENTRY_DISTANCE = 2.0;             // Minimum EMA-VWAP difference for entry

//+------------------------------------------------------------------+
//| Initialization Function                                          |
//+------------------------------------------------------------------+
void OnInit()
{
   // Create EMA9 indicator handle for M15
   ema9_handle_M15 = iMA(SYMBOL, TIMEFRAME_M15, 9, 0, MODE_EMA, PRICE_CLOSE);
   if(ema9_handle_M15 == INVALID_HANDLE)
   {
      Print("Failed to create EMA9 handle for M15. EA will terminate.");
      ExpertRemove();
      return;
   }

   // Create handle for custom VWAP indicator for M15
   vwap_handle_M15 = iCustom(SYMBOL, TIMEFRAME_M15, "VWAP_UTC_Final");
   if(vwap_handle_M15 == INVALID_HANDLE)
   {
      Print("Failed to create VWAP handle for M15. EA will terminate.");
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
   
   // Log entry settings
   Print("Entry based ONLY on EMA-VWAP difference. Minimum distance: ", MIN_ENTRY_DISTANCE,
         ". Strict one trade per crossover enforced.");
         
   // Initialize 1-minute timer for difference tracking
   last_bar_time_M1 = iTime(SYMBOL, PERIOD_M1, 0);
}

//+------------------------------------------------------------------+
//| Initialize signal state based on current market conditions       |
//+------------------------------------------------------------------+
void InitializeSignalState()
{
   // Get M15 indicator values
   double ema9_M15[];
   ArraySetAsSeries(ema9_M15, true);
   if(CopyBuffer(ema9_handle_M15, 0, 0, 1, ema9_M15) < 1)
   {
      Print("Failed to copy M15 EMA9 data for initialization");
      return;
   }

   double vwap_M15[];
   ArraySetAsSeries(vwap_M15, true);
   if(CopyBuffer(vwap_handle_M15, 0, 0, 1, vwap_M15) < 1)
   {
      Print("Failed to copy M15 VWAP data for initialization");
      return;
   }
   
   // Set initial signal state
   if(ema9_M15[0] > vwap_M15[0])
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
//| Main Tick Function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- M15 Bar Check for Dynamic SL Updates and Exit Check ---
   datetime current_bar_time_M15 = iTime(SYMBOL, TIMEFRAME_M15, 0);
   if(current_bar_time_M15 > last_bar_time_M15)
   {
      last_bar_time_M15 = current_bar_time_M15;

      // Get M15 indicator values
      double ema9_M15[];
      ArraySetAsSeries(ema9_M15, true);
      if(CopyBuffer(ema9_handle_M15, 0, 0, 2, ema9_M15) < 2)
      {
         Print("Failed to copy M15 EMA9 data");
         return;
      }

      double vwap_M15[];
      ArraySetAsSeries(vwap_M15, true);
      if(CopyBuffer(vwap_handle_M15, 0, 0, 2, vwap_M15) < 2)
      {
         Print("Failed to copy M15 VWAP data");
         return;
      }

      // Get previous M15 candle's close (for M15 exit)
      double close1_M15 = iClose(SYMBOL, TIMEFRAME_M15, 1);

      // Check exit condition if we have a position
      if(PositionSelect(SYMBOL))
      {
         CheckExitCondition(close1_M15, ema9_M15[1]);
      }
      
      // Update dynamic SL if enabled and a position exists
      if(PositionSelect(SYMBOL) && DynamicStopLoss && UseStopLossAtVWAP)
      {
         UpdateDynamicStopLoss(vwap_M15[1]);
      }
   }
   
   //--- 1-Minute Check for EMA-VWAP Difference Logging and Entry ---
   datetime current_bar_time_M1 = iTime(SYMBOL, PERIOD_M1, 0);
   if(current_bar_time_M1 > last_bar_time_M1)
   {
      last_bar_time_M1 = current_bar_time_M1;
      
      // Get current M15 indicator values
      double ema9_M15[];
      ArraySetAsSeries(ema9_M15, true);
      if(CopyBuffer(ema9_handle_M15, 0, 0, 2, ema9_M15) < 2) // Get 2 values for crossover detection
      {
         Print("Failed to copy M15 EMA9 data for difference calculation");
         return;
      }

      double vwap_M15[];
      ArraySetAsSeries(vwap_M15, true);
      if(CopyBuffer(vwap_handle_M15, 0, 0, 2, vwap_M15) < 2) // Get 2 values for crossover detection
      {
         Print("Failed to copy M15 VWAP data for difference calculation");
         return;
      }
      
      // Calculate the current difference
      double ema_vwap_diff = ema9_M15[0] - vwap_M15[0];
      double abs_diff = MathAbs(ema_vwap_diff);
      string direction = ema_vwap_diff > 0 ? "above" : "below";
      
      // Print the difference
      Print("EMA-VWAP Difference (M15): ", DoubleToString(ema_vwap_diff, 2), 
            " (EMA is ", direction, " VWAP by ", DoubleToString(abs_diff, 2), " points)");
      
      // Calculate previous difference to detect crossovers
      double prev_ema_vwap_diff = ema9_M15[1] - vwap_M15[1];
      
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
                  double sl = 0;
                  
                  // For bullish signal (EMA above VWAP)
                  if(current_signal == 1)
                  {
                     if(UseStopLossAtVWAP)
                        sl = NormalizeDouble(vwap_M15[0] - buffer, digits); // SL from M15 VWAP with buffer
                     else
                        sl = NormalizeDouble(vwap_M15[0] - 3 * point, digits); // Original SL rule
                        
                     if(trade.Buy(FIXED_LOT_SIZE, SYMBOL, 0.0, sl, 0.0))
                     {
                        Print("Buy trade opened based on EMA-VWAP difference with SL: ", sl, ". Distance: ", abs_diff, " units");
                        previous_trade_direction = 1;
                        allow_new_trade = false; // Disable new trades until next crossover
                     }
                  }
                  // For bearish signal (EMA below VWAP)
                  else if(current_signal == -1)
                  {
                     if(UseStopLossAtVWAP)
                        sl = NormalizeDouble(vwap_M15[0] + buffer, digits); // SL from M15 VWAP with buffer
                     else
                        sl = NormalizeDouble(vwap_M15[0] + 3 * point, digits); // Original SL rule
                        
                     if(trade.Sell(FIXED_LOT_SIZE, SYMBOL, 0.0, sl, 0.0))
                     {
                        Print("Sell trade opened based on EMA-VWAP difference with SL: ", sl, ". Distance: ", abs_diff, " units");
                        previous_trade_direction = -1;
                        allow_new_trade = false; // Disable new trades until next crossover
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
   double new_sl = 0;
   
   // Calculate new stop loss based on position type and VWAP
   if(position_type == POSITION_TYPE_BUY)
   {
      new_sl = NormalizeDouble(current_vwap - buffer, digits);
      
      // Only move SL up (safer) for buy positions
      if(new_sl > current_sl || current_sl == 0)
      {
         if(trade.PositionModify(SYMBOL, new_sl, PositionGetDouble(POSITION_TP)))
            Print("Dynamic SL updated for Buy position: ", new_sl, " (based on VWAP)");
         else
            Print("Failed to update dynamic SL. Error: ", GetLastError());
      }
   }
   else if(position_type == POSITION_TYPE_SELL)
   {
      new_sl = NormalizeDouble(current_vwap + buffer, digits);
      
      // Only move SL down (safer) for sell positions
      if(new_sl < current_sl || current_sl == 0)
      {
         if(trade.PositionModify(SYMBOL, new_sl, PositionGetDouble(POSITION_TP)))
            Print("Dynamic SL updated for Sell position: ", new_sl, " (based on VWAP)");
         else
            Print("Failed to update dynamic SL. Error: ", GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| Check Exit Condition                                             |
//+------------------------------------------------------------------+
void CheckExitCondition(double close1_M15, double ema9_prev_M15)
{
   if(!PositionSelect(SYMBOL)) return;
   
   // Store the position type before closing (for reference in logging)
   long position_type = PositionGetInteger(POSITION_TYPE);
   
   if(position_type == POSITION_TYPE_BUY)
   {
      if(close1_M15 < ema9_prev_M15)
      {
         if(trade.PositionClose(SYMBOL))
         {
            Print("Buy position closed (M15 Exit) - previous M15 candle closed below M15 EMA9");
            // Don't allow a new trade in the same direction until crossover
            // previous_trade_direction is already set
            allow_new_trade = false;
            Print("Trade closed. New trade in same direction blocked until crossover.");
         }
         else
            Print("Failed to close Buy position. Error: ", GetLastError());
      }
   }
   else if(position_type == POSITION_TYPE_SELL)
   {
      if(close1_M15 > ema9_prev_M15)
      {
         if(trade.PositionClose(SYMBOL))
         {
            Print("Sell position closed (M15 Exit) - previous M15 candle closed above M15 EMA9");
            // Don't allow a new trade in the same direction until crossover
            // previous_trade_direction is already set
            allow_new_trade = false;
            Print("Trade closed. New trade in same direction blocked until crossover.");
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
   if(ema9_handle_M15 != INVALID_HANDLE)
      IndicatorRelease(ema9_handle_M15);
   if(vwap_handle_M15 != INVALID_HANDLE)
      IndicatorRelease(vwap_handle_M15);
   Print("EA deinitialized. Reason: ", reason);
}