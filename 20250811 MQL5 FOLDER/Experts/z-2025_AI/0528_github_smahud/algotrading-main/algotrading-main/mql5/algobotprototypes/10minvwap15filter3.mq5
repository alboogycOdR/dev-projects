//+------------------------------------------------------------------+
//|                                              10minentryvwap15.mq5 |
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
int ema9_handle_M10;
int vwap_handle_M10;      // Handle for custom VWAP indicator on M10

// Global variables
datetime last_bar_time_M15 = 0;
datetime last_bar_time_M10 = 0;
const double FIXED_LOT_SIZE = 0.20;
const string SYMBOL = "ETHUSDm";
const ENUM_TIMEFRAMES TIMEFRAME_M15 = PERIOD_M15;
const ENUM_TIMEFRAMES TIMEFRAME_M10 = PERIOD_M10;

// Variables to track crossover states
int last_crossover_m10 = 0;   // 0 = no crossover yet, 1 = bullish (EMA above VWAP), -1 = bearish (EMA below VWAP)
int last_crossover_m15 = 0;   // 0 = no crossover yet, 1 = bullish (EMA above VWAP), -1 = bearish (EMA below VWAP)

// Variables to track potential entry opportunities
bool m10_bullish_pending = false;  // Flag for pending bullish M10 entry
bool m10_bearish_pending = false;  // Flag for pending bearish M10 entry
bool m15_bullish_pending = false;  // Flag for pending bullish M15 entry
bool m15_bearish_pending = false;  // Flag for pending bearish M15 entry
int pending_bars_count = 0;        // Counter for bars since crossover

// Stop Loss Settings
input string StopLossSettings = "---Stop Loss Settings---";
input bool UseStopLossAtVWAP = true;                // Use VWAP level as Stop Loss
input bool DynamicStopLoss = true;                  // Update stop loss with VWAP
input double AdditionalSLBuffer = 0.0;              // Additional SL buffer in points

// Filter Settings
input string FilterSettings = "---Filter Settings---";
input double MIN_DISTANCE_M10 = 8.0;              // Minimum distance between EMA9 and VWAP for M10 (in price units)
input double MIN_DISTANCE_M15 = 8.0;              // Minimum distance between EMA9 and VWAP for M15 (in price units)
input int MAX_WAIT_BARS = 10;                       // Maximum bars to wait for distance confirmation (0 = check only first bar)

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

   // Create EMA9 indicator handle for M10
   ema9_handle_M10 = iMA(SYMBOL, TIMEFRAME_M10, 9, 0, MODE_EMA, PRICE_CLOSE);
   if(ema9_handle_M10 == INVALID_HANDLE)
   {
      Print("Failed to create EMA9 handle for M10. EA will terminate.");
      ExpertRemove();
      return;
   }

   // Create handle for custom VWAP indicator for M10
   vwap_handle_M10 = iCustom(SYMBOL, TIMEFRAME_M10, "VWAP_UTC_Final");
   if(vwap_handle_M10 == INVALID_HANDLE)
   {
      Print("Failed to create VWAP handle for M10. EA will terminate.");
      ExpertRemove();
      return;
   }

   // Initialize the crossover state based on current market conditions
   InitializeCrossoverStates();

   trade.SetDeviationInPoints(10); // Allow 1 pip slippage
   Print("EA initialized successfully on ", SYMBOL, " (M15 - Main, M10 - Entry)");
   
   // Log stop loss settings
   if (UseStopLossAtVWAP)
      Print("Using average of VWAP and EMA9 as Stop Loss reference. Dynamic SL: ", DynamicStopLoss ? "Enabled" : "Disabled", 
            ", Additional buffer: ", AdditionalSLBuffer, " points");
   
   // Log filter settings
   Print("Minimum EMA-VWAP distance filters: M10=", MIN_DISTANCE_M10, ", M15=", MIN_DISTANCE_M15, 
         " price units. Max wait bars: ", MAX_WAIT_BARS);
}

//+------------------------------------------------------------------+
//| Initialize crossover states based on current market conditions   |
//+------------------------------------------------------------------+
void InitializeCrossoverStates()
{
   // Get M10 indicator values
   double ema9_M10[];
   ArraySetAsSeries(ema9_M10, true);
   if(CopyBuffer(ema9_handle_M10, 0, 0, 2, ema9_M10) < 2)
   {
      Print("Failed to copy M10 EMA9 data for initialization");
      return;
   }

   double vwap_M10[];
   ArraySetAsSeries(vwap_M10, true);
   if(CopyBuffer(vwap_handle_M10, 0, 0, 2, vwap_M10) < 2)
   {
      Print("Failed to copy M10 VWAP data for initialization");
      return;
   }
   
   // Set initial M10 crossover state
   if(ema9_M10[1] > vwap_M10[1])
      last_crossover_m10 = 1;  // EMA above VWAP (bullish)
   else
      last_crossover_m10 = -1; // EMA below VWAP (bearish)
      
   // Get M15 indicator values
   double ema9_M15[];
   ArraySetAsSeries(ema9_M15, true);
   if(CopyBuffer(ema9_handle_M15, 0, 0, 2, ema9_M15) < 2)
   {
      Print("Failed to copy M15 EMA9 data for initialization");
      return;
   }

   double vwap_M15[];
   ArraySetAsSeries(vwap_M15, true);
   if(CopyBuffer(vwap_handle_M15, 0, 0, 2, vwap_M15) < 2)
   {
      Print("Failed to copy M15 VWAP data for initialization");
      return;
   }
   
   // Set initial M15 crossover state
   if(ema9_M15[1] > vwap_M15[1])
      last_crossover_m15 = 1;  // EMA above VWAP (bullish)
   else
      last_crossover_m15 = -1; // EMA below VWAP (bearish)
      
   Print("Crossover states initialized: M10=", last_crossover_m10, ", M15=", last_crossover_m15);
}

//+------------------------------------------------------------------+
//| Main Tick Function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- M15 Bar Check ---
   datetime current_bar_time_M15 = iTime(SYMBOL, TIMEFRAME_M15, 0);
   if(current_bar_time_M15 > last_bar_time_M15)
   {
      last_bar_time_M15 = current_bar_time_M15;

      // Get M15 indicator values
      double ema9_M15[];
      ArraySetAsSeries(ema9_M15, true);
      if(CopyBuffer(ema9_handle_M15, 0, 0, 3, ema9_M15) < 3)
      {
         Print("Failed to copy M15 EMA9 data");
         return;
      }

      double vwap_M15[];
      ArraySetAsSeries(vwap_M15, true);
      if(CopyBuffer(vwap_handle_M15, 0, 0, 3, vwap_M15) < 3)
      {
         Print("Failed to copy M15 VWAP data");
         return;
      }

      // Get previous M15 candle's close (for M15 exit)
      double close1_M15 = iClose(SYMBOL, TIMEFRAME_M15, 1);

      // Check and manage existing position (using M15 data for exit and better opportunity)
      if(PositionSelect(SYMBOL))
      {
         CheckExitCondition(close1_M15, ema9_M15[1]); // M15 Exit
         
         // Only check for better opportunity if we still have a position
         if(PositionSelect(SYMBOL))
            CheckBetterOpportunity(ema9_M15, vwap_M15);   // M15 Better Opportunity
      }
      
      // Update M15 crossover state and check for pending entries
      if(ema9_M15[2] < vwap_M15[2] && ema9_M15[1] > vwap_M15[1]) // Bullish crossover
      {
         if(last_crossover_m15 != 1)
         {
            last_crossover_m15 = 1;
            Print("New M15 Bullish crossover detected");
            
            // If we want to wait for confirmation, set pending flag
            if(MAX_WAIT_BARS > 0 && !PositionSelect(SYMBOL))
            {
               m15_bullish_pending = true;
               m15_bearish_pending = false;
               pending_bars_count = 0;
               Print("M15 Bullish signal pending distance confirmation. Will check for ", MAX_WAIT_BARS, " bars");
            }
         }
      }
      else if(ema9_M15[2] > vwap_M15[2] && ema9_M15[1] < vwap_M15[1]) // Bearish crossover
      {
         if(last_crossover_m15 != -1)
         {
            last_crossover_m15 = -1;
            Print("New M15 Bearish crossover detected");
            
            // If we want to wait for confirmation, set pending flag
            if(MAX_WAIT_BARS > 0 && !PositionSelect(SYMBOL))
            {
               m15_bearish_pending = true;
               m15_bullish_pending = false;
               pending_bars_count = 0;
               Print("M15 Bearish signal pending distance confirmation. Will check for ", MAX_WAIT_BARS, " bars");
            }
         }
      }
      
      // Check for pending M15 signals that need distance confirmation
      if((m15_bullish_pending || m15_bearish_pending) && !PositionSelect(SYMBOL))
      {
         double ema_vwap_diff = MathAbs(ema9_M15[1] - vwap_M15[1]);
         
         // If we have a bullish pending signal
         if(m15_bullish_pending && ema_vwap_diff >= MIN_DISTANCE_M15)
         {
            // We have distance confirmation in M15
            Print("M15 Bullish distance confirmed: ", ema_vwap_diff, " >= ", MIN_DISTANCE_M15);
            
            // We won't directly enter here, just clear the pending flags
            m15_bullish_pending = false;
            m15_bearish_pending = false;
            
            // The actual trade entry will be handled by CheckBetterOpportunity
            // on the next call, which is appropriate because we need position data
         }
         // If we have a bearish pending signal
         else if(m15_bearish_pending && ema_vwap_diff >= MIN_DISTANCE_M15)
         {
            // We have distance confirmation in M15
            Print("M15 Bearish distance confirmed: ", ema_vwap_diff, " >= ", MIN_DISTANCE_M15);
            
            // We won't directly enter here, just clear the pending flags
            m15_bullish_pending = false;
            m15_bearish_pending = false;
            
            // The actual trade entry will be handled by CheckBetterOpportunity
            // on the next call, which is appropriate because we need position data
         }
         else
         {
            // Increment counter and check if we've waited too long
            pending_bars_count++;
            if(pending_bars_count >= MAX_WAIT_BARS)
            {
               if(m15_bullish_pending)
                  Print("M15 Bullish signal expired - distance not reached within ", MAX_WAIT_BARS, " bars. Last: ", ema_vwap_diff);
               else
                  Print("M15 Bearish signal expired - distance not reached within ", MAX_WAIT_BARS, " bars. Last: ", ema_vwap_diff);
               
               m15_bullish_pending = false;
               m15_bearish_pending = false;
            }
            else
            {
               Print("Waiting for M15 distance confirmation. Current: ", ema_vwap_diff, ", Bar ", pending_bars_count, " of ", MAX_WAIT_BARS);
            }
         }
      }
   }

   //--- M10 Bar Check for Entry and Dynamic SL Update ---
   datetime current_bar_time_M10 = iTime(SYMBOL, TIMEFRAME_M10, 0);
   if(current_bar_time_M10 > last_bar_time_M10)
   {
      last_bar_time_M10 = current_bar_time_M10;

      // Get M10 indicator values
      double ema9_M10[];
      ArraySetAsSeries(ema9_M10, true);
      if(CopyBuffer(ema9_handle_M10, 0, 0, 3, ema9_M10) < 3)
      {
         Print("Failed to copy M10 EMA9 data");
         return;
      }

      double vwap_M10[];
      ArraySetAsSeries(vwap_M10, true);
      if(CopyBuffer(vwap_handle_M10, 0, 0, 3, vwap_M10) < 3)
      {
         Print("Failed to copy M10 VWAP data");
         return;
      }

      // Get M15 VWAP for SL calculation (as requested - rest 15min candle sl)
      double vwap_M15_for_SL[];
      ArraySetAsSeries(vwap_M15_for_SL, true);
      if(CopyBuffer(vwap_handle_M15, 0, 0, 3, vwap_M15_for_SL) < 3)
      {
         Print("Failed to copy M15 VWAP data for SL");
         return;
      }
      
      // Get M15 EMA9 for SL calculation
      double ema9_M15_for_SL[];
      ArraySetAsSeries(ema9_M15_for_SL, true);
      if(CopyBuffer(ema9_handle_M15, 0, 0, 3, ema9_M15_for_SL) < 3)
      {
         Print("Failed to copy M15 EMA9 data for SL");
         return;
      }

      // Update dynamic SL if enabled and a position exists
      if(PositionSelect(SYMBOL) && DynamicStopLoss && UseStopLossAtVWAP)
      {
         UpdateDynamicStopLoss(vwap_M10[1], ema9_M10[1]);
      }
      
      // Update M10 crossover state
      bool new_crossover = false;
      
      if(ema9_M10[2] < vwap_M10[2] && ema9_M10[1] > vwap_M10[1]) // Bullish crossover
      {
         if(last_crossover_m10 != 1)
         {
            last_crossover_m10 = 1;
            new_crossover = true;
            Print("New M10 Bullish crossover detected");
            
            // If we want to wait for confirmation, set pending flag
            if(MAX_WAIT_BARS > 0 && !PositionSelect(SYMBOL))
            {
               m10_bullish_pending = true;
               m10_bearish_pending = false;
               pending_bars_count = 0;
               Print("M10 Bullish signal pending distance confirmation. Will check for ", MAX_WAIT_BARS, " bars");
            }
         }
      }
      else if(ema9_M10[2] > vwap_M10[2] && ema9_M10[1] < vwap_M10[1]) // Bearish crossover
      {
         if(last_crossover_m10 != -1)
         {
            last_crossover_m10 = -1;
            new_crossover = true;
            Print("New M10 Bearish crossover detected");
            
            // If we want to wait for confirmation, set pending flag
            if(MAX_WAIT_BARS > 0 && !PositionSelect(SYMBOL))
            {
               m10_bearish_pending = true;
               m10_bullish_pending = false;
               pending_bars_count = 0;
               Print("M10 Bearish signal pending distance confirmation. Will check for ", MAX_WAIT_BARS, " bars");
            }
         }
      }
      
      // If new crossover and we want immediate check (MAX_WAIT_BARS = 0)
      if(new_crossover && MAX_WAIT_BARS == 0 && !PositionSelect(SYMBOL))
      {
         CheckEntryConditions_M10(ema9_M10, vwap_M10, vwap_M15_for_SL, ema9_M15_for_SL);
      }
      // Otherwise check for pending signals that need distance confirmation
      else if((m10_bullish_pending || m10_bearish_pending) && !PositionSelect(SYMBOL))
      {
         double ema_vwap_diff = MathAbs(ema9_M10[1] - vwap_M10[1]);
         
         // If we have a bullish pending signal
         if(m10_bullish_pending && ema_vwap_diff >= MIN_DISTANCE_M10)
         {
            // We have distance confirmation
            Print("M10 Bullish distance confirmed: ", ema_vwap_diff, " >= ", MIN_DISTANCE_M10);
            m10_bullish_pending = false;
            m10_bearish_pending = false;
            
            // Place the trade
            double sl = 0;
            int digits = (int)SymbolInfoInteger(SYMBOL, SYMBOL_DIGITS);
            double point = SymbolInfoDouble(SYMBOL, SYMBOL_POINT);
            double buffer = AdditionalSLBuffer * point;
            
            // Calculate average of VWAP and EMA9 for SL
            double average_level = (vwap_M15_for_SL[1] + ema9_M15_for_SL[1]) / 2.0;
            
            if(UseStopLossAtVWAP)
               sl = NormalizeDouble(average_level - buffer, digits); // SL from average with buffer
            else
               sl = NormalizeDouble(vwap_M15_for_SL[1] - 3 * point, digits); // Original SL rule
               
            if(trade.Buy(FIXED_LOT_SIZE, SYMBOL, 0.0, sl, 0.0))
            {
               Print("Buy trade opened (M10 Entry with distance confirmation) with SL: ", sl, " (based on avg of M15 VWAP and EMA9). Distance: ", ema_vwap_diff, " units");
            }
         }
         // If we have a bearish pending signal
         else if(m10_bearish_pending && ema_vwap_diff >= MIN_DISTANCE_M10)
         {
            // We have distance confirmation
            Print("M10 Bearish distance confirmed: ", ema_vwap_diff, " >= ", MIN_DISTANCE_M10);
            m10_bullish_pending = false;
            m10_bearish_pending = false;
            
            // Place the trade
            double sl = 0;
            int digits = (int)SymbolInfoInteger(SYMBOL, SYMBOL_DIGITS);
            double point = SymbolInfoDouble(SYMBOL, SYMBOL_POINT);
            double buffer = AdditionalSLBuffer * point;
            
            // Calculate average of VWAP and EMA9 for SL
            double average_level = (vwap_M15_for_SL[1] + ema9_M15_for_SL[1]) / 2.0;
            
            if(UseStopLossAtVWAP)
               sl = NormalizeDouble(average_level + buffer, digits); // SL from average with buffer
            else
               sl = NormalizeDouble(vwap_M15_for_SL[1] + 3 * point, digits); // Original SL rule
               
            if(trade.Sell(FIXED_LOT_SIZE, SYMBOL, 0.0, sl, 0.0))
            {
               Print("Sell trade opened (M10 Entry with distance confirmation) with SL: ", sl, " (based on avg of M15 VWAP and EMA9). Distance: ", ema_vwap_diff, " units");
            }
         }
         else
         {
            // Increment counter and check if we've waited too long
            pending_bars_count++;
            if(pending_bars_count >= MAX_WAIT_BARS)
            {
               if(m10_bullish_pending)
                  Print("M10 Bullish signal expired - distance not reached within ", MAX_WAIT_BARS, " bars. Last: ", ema_vwap_diff);
               else
                  Print("M10 Bearish signal expired - distance not reached within ", MAX_WAIT_BARS, " bars. Last: ", ema_vwap_diff);
               
               m10_bullish_pending = false;
               m10_bearish_pending = false;
            }
            else
            {
               Print("Waiting for M10 distance confirmation. Current: ", ema_vwap_diff, ", Bar ", pending_bars_count, " of ", MAX_WAIT_BARS);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Update Dynamic Stop Loss based on average of VWAP and EMA9       |
//+------------------------------------------------------------------+
void UpdateDynamicStopLoss(double current_vwap, double current_ema9)
{
   if(!PositionSelect(SYMBOL)) return;
   
   int digits = (int)SymbolInfoInteger(SYMBOL, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(SYMBOL, SYMBOL_POINT);
   double buffer = AdditionalSLBuffer * point;
   
   // Calculate average of VWAP and EMA9
   double average_level = (current_vwap + current_ema9) / 2.0;
   
   long position_type = PositionGetInteger(POSITION_TYPE);
   double current_sl = PositionGetDouble(POSITION_SL);
   double new_sl = 0;
   
   // Calculate new stop loss based on position type and average level
   if(position_type == POSITION_TYPE_BUY)
   {
      new_sl = NormalizeDouble(average_level - buffer, digits);
      
      // Only move SL up (safer) for buy positions
      if(new_sl > current_sl || current_sl == 0)
      {
         if(trade.PositionModify(SYMBOL, new_sl, PositionGetDouble(POSITION_TP)))
            Print("Dynamic SL updated for Buy position: ", new_sl, " (based on average of VWAP and EMA9)");
         else
            Print("Failed to update dynamic SL. Error: ", GetLastError());
      }
   }
   else if(position_type == POSITION_TYPE_SELL)
   {
      new_sl = NormalizeDouble(average_level + buffer, digits);
      
      // Only move SL down (safer) for sell positions
      if(new_sl < current_sl || current_sl == 0)
      {
         if(trade.PositionModify(SYMBOL, new_sl, PositionGetDouble(POSITION_TP)))
            Print("Dynamic SL updated for Sell position: ", new_sl, " (based on average of VWAP and EMA9)");
         else
            Print("Failed to update dynamic SL. Error: ", GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| Check Entry Conditions on M10 Timeframe                          |
//+------------------------------------------------------------------+
void CheckEntryConditions_M10(double &ema9_M10[], double &vwap_M10[], double &vwap_M15_for_SL[], double &ema9_M15_for_SL[])
{
   int digits = (int)SymbolInfoInteger(SYMBOL, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(SYMBOL, SYMBOL_POINT);
   double buffer = AdditionalSLBuffer * point;

   // Calculate the distance between EMA9 and VWAP
   double ema_vwap_diff = MathAbs(ema9_M10[1] - vwap_M10[1]);

   // Buy condition: M10 EMA9 crosses above M10 VWAP
   if(last_crossover_m10 == 1 && ema9_M10[1] > vwap_M10[1])
   {
      // Check if the distance is enough
      if(ema_vwap_diff >= MIN_DISTANCE_M10)
      {
         double sl = 0;
         
         // Calculate average of VWAP and EMA9 for SL
         double average_level = (vwap_M15_for_SL[1] + ema9_M15_for_SL[1]) / 2.0;
         
         if(UseStopLossAtVWAP)
            sl = NormalizeDouble(average_level - buffer, digits); // SL from average with buffer
         else
            sl = NormalizeDouble(vwap_M15_for_SL[1] - 3 * point, digits); // Original SL rule
            
         if(trade.Buy(FIXED_LOT_SIZE, SYMBOL, 0.0, sl, 0.0))
         {
            Print("Buy trade opened (M10 Entry) with SL: ", sl, " (based on avg of M15 VWAP and EMA9). Distance: ", ema_vwap_diff, " units");
         }
      }
      else
      {
         Print("Buy signal confirmed but distance insufficient: ", ema_vwap_diff, " < ", MIN_DISTANCE_M10, " units. Will check for ", MAX_WAIT_BARS, " bars");
      }
   }
   // Sell condition: M10 EMA9 crosses below M10 VWAP
   else if(last_crossover_m10 == -1 && ema9_M10[1] < vwap_M10[1])
   {
      // Check if the distance is enough
      if(ema_vwap_diff >= MIN_DISTANCE_M10)
      {
         double sl = 0;
         
         // Calculate average of VWAP and EMA9 for SL
         double average_level = (vwap_M15_for_SL[1] + ema9_M15_for_SL[1]) / 2.0;
         
         if(UseStopLossAtVWAP)
            sl = NormalizeDouble(average_level + buffer, digits); // SL from average with buffer
         else
            sl = NormalizeDouble(vwap_M15_for_SL[1] + 3 * point, digits); // Original SL rule
            
         if(trade.Sell(FIXED_LOT_SIZE, SYMBOL, 0.0, sl, 0.0))
         {
            Print("Sell trade opened (M10 Entry) with SL: ", sl, " (based on avg of M15 VWAP and EMA9). Distance: ", ema_vwap_diff, " units");
         }
      }
      else
      {
         Print("Sell signal confirmed but distance insufficient: ", ema_vwap_diff, " < ", MIN_DISTANCE_M10, " units. Will check for ", MAX_WAIT_BARS, " bars");
      }
   }
}

//+------------------------------------------------------------------+
//| Check Exit Condition                                             |
//+------------------------------------------------------------------+
void CheckExitCondition(double close1_M15, double ema9_prev_M15)
{
   if(!PositionSelect(SYMBOL)) return;
   
   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
   {
      if(close1_M15 < ema9_prev_M15)
      {
         if(trade.PositionClose(SYMBOL))
            Print("Buy position closed (M15 Exit) - previous M15 candle closed below M15 EMA9");
         else
            Print("Failed to close Buy position. Error: ", GetLastError());
      }
   }
   else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
   {
      if(close1_M15 > ema9_prev_M15)
      {
         if(trade.PositionClose(SYMBOL))
            Print("Sell position closed (M15 Exit) - previous M15 candle closed above M15 EMA9");
         else
            Print("Failed to close Sell position. Error: ", GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| Check for Better Opportunity                                     |
//+------------------------------------------------------------------+
void CheckBetterOpportunity(double &ema9_M15[], double &vwap_M15[])
{
   int digits = (int)SymbolInfoInteger(SYMBOL, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(SYMBOL, SYMBOL_POINT);
   double buffer = AdditionalSLBuffer * point;

   // Calculate the distance between EMA9 and VWAP
   double ema_vwap_diff = MathAbs(ema9_M15[1] - vwap_M15[1]);

   if(PositionSelect(SYMBOL))
   {
      long pos_type = PositionGetInteger(POSITION_TYPE);
      // Switch from sell to buy (M15 Condition)
      if(pos_type == POSITION_TYPE_SELL && last_crossover_m15 == 1 && ema9_M15[1] > vwap_M15[1])
      {
         // Check if the distance is enough
         if(ema_vwap_diff >= MIN_DISTANCE_M15)
         {
            if(trade.PositionClose(SYMBOL))
            {
               double sl = 0;
               // Calculate average of VWAP and EMA9 for SL
               double average_level = (vwap_M15[1] + ema9_M15[1]) / 2.0;
               
               if(UseStopLossAtVWAP)
                  sl = NormalizeDouble(average_level - buffer, digits);
               else
                  sl = NormalizeDouble(vwap_M15[1] - 3 * point, digits);
                  
               if(trade.Buy(FIXED_LOT_SIZE, SYMBOL, 0.0, sl, 0.0))
                  Print("Switched from Sell to Buy trade (M15 Opportunity). Distance: ", ema_vwap_diff, " units");
               else
                  Print("Failed to open Buy position after closing Sell. Error: ", GetLastError());
            }
            else
            {
               Print("Failed to close Sell position for better opportunity. Error: ", GetLastError());
            }
         }
         else if(!m15_bullish_pending && MAX_WAIT_BARS > 0)
         {
            // Not enough distance yet, but remember to check on future bars
            m15_bullish_pending = true;
            m15_bearish_pending = false;
            pending_bars_count = 0;
            Print("Better opportunity (Buy) detected but distance insufficient: ", ema_vwap_diff, " < ", MIN_DISTANCE_M15, " units. Will wait for confirmation.");
         }
      }
      // Switch from buy to sell (M15 Condition)
      else if(pos_type == POSITION_TYPE_BUY && last_crossover_m15 == -1 && ema9_M15[1] < vwap_M15[1])
      {
         // Check if the distance is enough
         if(ema_vwap_diff >= MIN_DISTANCE_M15)
         {
            if(trade.PositionClose(SYMBOL))
            {
               double sl = 0;
               // Calculate average of VWAP and EMA9 for SL
               double average_level = (vwap_M15[1] + ema9_M15[1]) / 2.0;
               
               if(UseStopLossAtVWAP)
                  sl = NormalizeDouble(average_level + buffer, digits);
               else
                  sl = NormalizeDouble(vwap_M15[1] + 3 * point, digits);
                  
               if(trade.Sell(FIXED_LOT_SIZE, SYMBOL, 0.0, sl, 0.0))
                  Print("Switched from Buy to Sell trade (M15 Opportunity). Distance: ", ema_vwap_diff, " units");
               else
                  Print("Failed to open Sell position after closing Buy. Error: ", GetLastError());
            }
            else
            {
               Print("Failed to close Buy position for better opportunity. Error: ", GetLastError());
            }
         }
         else if(!m15_bearish_pending && MAX_WAIT_BARS > 0)
         {
            // Not enough distance yet, but remember to check on future bars
            m15_bearish_pending = true;
            m15_bullish_pending = false;
            pending_bars_count = 0;
            Print("Better opportunity (Sell) detected but distance insufficient: ", ema_vwap_diff, " < ", MIN_DISTANCE_M15, " units. Will wait for confirmation.");
         }
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
   if(ema9_handle_M10 != INVALID_HANDLE)
      IndicatorRelease(ema9_handle_M10);
   if(vwap_handle_M10 != INVALID_HANDLE)
      IndicatorRelease(vwap_handle_M10);
   Print("EA deinitialized. Reason: ", reason);
}