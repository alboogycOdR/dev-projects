//+------------------------------------------------------------------+
//|                                               RSI_BB_SAR_EA.mq5 |
//|                                            Copyright 2025       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Enumerations                                                     |
//+------------------------------------------------------------------+
enum POSITION_SIZING_TYPE
{
   FIXED_LOTS = 0,       // Fixed Lot Size
   RISK_PERCENTAGE = 1   // Risk Percentage of Balance
};

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
// General Settings
input string GeneralSettings = "---------- General Settings ----------";
input string SymbolToTrade = "ETHUSD";          // Trading Symbol
input ENUM_TIMEFRAMES TimeFrame = PERIOD_H1;    // Timeframe (default H1)

// RSI Settings
input string RSISettings = "---------- RSI Settings ----------";
input int RSI_Period = 14;                      // RSI Period
input double RSI_Oversold = 30.0;              // RSI Oversold Level
input double RSI_Overbought = 70.0;            // RSI Overbought Level

// Bollinger Bands Settings
input string BBSettings = "---------- Bollinger Bands Settings ----------";
input int BB_Period = 20;                       // BB Period
input double BB_Deviations = 2.0;              // BB Standard Deviations

// Parabolic SAR Settings
input string SARSettings = "---------- Parabolic SAR Settings ----------";
input double SAR_Step = 0.02;                  // SAR Step
input double SAR_Maximum = 0.2;                // SAR Maximum

// ATR Settings for Stop Loss
input string ATRSettings = "---------- ATR Settings ----------";
input int ATR_Period = 14;                      // ATR Period
input double SL_ATR_Multiplier = 1.5;          // Stop Loss ATR Multiplier

// Position Sizing Settings
input string PositionSettings = "---------- Position Sizing ----------";
input POSITION_SIZING_TYPE PositionSizingType = RISK_PERCENTAGE; // Position Sizing Method
input double FixedLotSize = 0.1;               // Fixed Lot Size
input double RiskPercentage = 1.0;             // Risk Percentage per Trade

// Optional Confirmation Settings
input string ConfirmationSettings = "---------- Optional Confirmations ----------";
input bool UsePatternConfirmation = false;      // Use Candlestick Pattern Confirmation
input bool TrailStopLoss = true;               // Enable Trailing Stop Loss
input double TrailATRMultiplier = 2.0;         // Trailing Stop ATR Multiplier

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CTrade trade;                                    // Trade object for executing trades

// Indicator handles
int RSI_Handle;                                  // RSI indicator handle
int BB_Handle;                                   // Bollinger Bands indicator handle
int SAR_Handle;                                  // Parabolic SAR indicator handle
int ATR_Handle;                                  // ATR indicator handle

// State tracking
datetime last_bar_time;                          // Time of the last processed bar
bool position_open = false;                      // Flag for position tracking
double entry_price = 0.0;                        // Entry price for calculating trailing stop

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set trade object properties
   trade.SetDeviationInPoints(10);              // Allow 1 point slippage
   trade.SetAsyncMode(false);                   // Synchronous execution mode
   
   // Initialize indicator handles
   RSI_Handle = iRSI(SymbolToTrade, TimeFrame, RSI_Period, PRICE_CLOSE);
   if(RSI_Handle == INVALID_HANDLE)
   {
      Print("Error creating RSI indicator handle");
      return INIT_FAILED;
   }
   
   BB_Handle = iBands(SymbolToTrade, TimeFrame, BB_Period, 0, BB_Deviations, PRICE_CLOSE);
   if(BB_Handle == INVALID_HANDLE)
   {
      Print("Error creating Bollinger Bands indicator handle");
      return INIT_FAILED;
   }
   
   SAR_Handle = iSAR(SymbolToTrade, TimeFrame, SAR_Step, SAR_Maximum);
   if(SAR_Handle == INVALID_HANDLE)
   {
      Print("Error creating Parabolic SAR indicator handle");
      return INIT_FAILED;
   }
   
   ATR_Handle = iATR(SymbolToTrade, TimeFrame, ATR_Period);
   if(ATR_Handle == INVALID_HANDLE)
   {
      Print("Error creating ATR indicator handle");
      return INIT_FAILED;
   }
   
   // Initialize last bar time
   last_bar_time = iTime(SymbolToTrade, TimeFrame, 0);
   
   // Check for existing positions
   if(PositionSelect(SymbolToTrade))
   {
      position_open = true;
      entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
      Print("Existing position found. Starting monitoring...");
   }
   
   Print("RSI-BB-SAR EA initialized successfully for ", SymbolToTrade, " on ", EnumToString(TimeFrame), " timeframe");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   if(RSI_Handle != INVALID_HANDLE) IndicatorRelease(RSI_Handle);
   if(BB_Handle != INVALID_HANDLE) IndicatorRelease(BB_Handle);
   if(SAR_Handle != INVALID_HANDLE) IndicatorRelease(SAR_Handle);
   if(ATR_Handle != INVALID_HANDLE) IndicatorRelease(ATR_Handle);
   
   Print("RSI-BB-SAR EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new bar
   datetime current_bar_time = iTime(SymbolToTrade, TimeFrame, 0);
   if(current_bar_time == last_bar_time) 
   {
      // Only process on new bars
      
      // But still check for exit conditions on every tick for open positions
      if(position_open && PositionSelect(SymbolToTrade))
      {
         CheckExitCondition();
         
         // Update trailing stop if enabled
         if(TrailStopLoss)
         {
            UpdateTrailingStop();
         }
      }
      
      return;
   }
   
   // Update last bar time
   last_bar_time = current_bar_time;
   
   // Check if the indicators are ready
   if(!CheckIndicatorsReady())
   {
      Print("Indicators not ready yet. Waiting for enough data...");
      return;
   }
   
   // Get indicator values
   double rsi_values[], rsi_prev_values[];
   double bb_upper[], bb_lower[], bb_middle[];
   double sar_values[];
   double atr_values[];
   
   // Retrieve indicator values with error checking
   if(!GetIndicatorValues(rsi_values, rsi_prev_values, bb_upper, bb_lower, bb_middle, sar_values, atr_values))
   {
      Print("Failed to get indicator values. Skipping this tick.");
      return;
   }
   
   // Get price data
   MqlRates price_data[];
   if(CopyRates(SymbolToTrade, TimeFrame, 0, 2, price_data) < 2)
   {
      Print("Failed to copy price data. Skipping this tick.");
      return;
   }
   ArraySetAsSeries(price_data, true);
   
   // Check for entry conditions if no position is open
   if(!position_open)
   {
      CheckEntryCondition(rsi_values, rsi_prev_values, bb_upper, bb_lower, price_data, atr_values);
   }
   
   // Check for exit conditions if a position is open
   if(position_open && PositionSelect(SymbolToTrade))
   {
      CheckExitCondition();
   }
   else
   {
      // Reset position flag if no position exists
      position_open = false;
   }
}

//+------------------------------------------------------------------+
//| Check if all indicators have enough data                         |
//+------------------------------------------------------------------+
bool CheckIndicatorsReady()
{
   // Check if enough RSI values are available
   double rsi_values[];
   if(CopyBuffer(RSI_Handle, 0, 0, RSI_Period, rsi_values) < RSI_Period)
   {
      return false;
   }
   
   // Check if enough BB values are available
   double bb_upper[];
   if(CopyBuffer(BB_Handle, 1, 0, BB_Period, bb_upper) < BB_Period)
   {
      return false;
   }
   
   // Check if enough SAR values are available
   double sar_values[];
   if(CopyBuffer(SAR_Handle, 0, 0, 5, sar_values) < 5)
   {
      return false;
   }
   
   // Check if enough ATR values are available
   double atr_values[];
   if(CopyBuffer(ATR_Handle, 0, 0, ATR_Period, atr_values) < ATR_Period)
   {
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Get all indicator values                                         |
//+------------------------------------------------------------------+
bool GetIndicatorValues(double &rsi_values[], double &rsi_prev_values[], 
                       double &bb_upper[], double &bb_lower[], double &bb_middle[],
                       double &sar_values[], double &atr_values[])
{
   // Get RSI values (current and previous bar)
   ArraySetAsSeries(rsi_values, true);
   if(CopyBuffer(RSI_Handle, 0, 0, 2, rsi_values) < 2)
   {
      Print("Failed to copy RSI values");
      return false;
   }
   
   // Get RSI values from one bar earlier (for detecting crosses)
   ArraySetAsSeries(rsi_prev_values, true);
   if(CopyBuffer(RSI_Handle, 0, 1, 2, rsi_prev_values) < 2)
   {
      Print("Failed to copy previous RSI values");
      return false;
   }
   
   // Get Bollinger Bands values
   ArraySetAsSeries(bb_upper, true);
   ArraySetAsSeries(bb_middle, true);
   ArraySetAsSeries(bb_lower, true);
   if(CopyBuffer(BB_Handle, 1, 0, 2, bb_upper) < 2)
   {
      Print("Failed to copy upper Bollinger Band values");
      return false;
   }
   if(CopyBuffer(BB_Handle, 0, 0, 2, bb_middle) < 2)
   {
      Print("Failed to copy middle Bollinger Band values");
      return false;
   }
   if(CopyBuffer(BB_Handle, 2, 0, 2, bb_lower) < 2)
   {
      Print("Failed to copy lower Bollinger Band values");
      return false;
   }
   
   // Get Parabolic SAR values
   ArraySetAsSeries(sar_values, true);
   if(CopyBuffer(SAR_Handle, 0, 0, 3, sar_values) < 3)
   {
      Print("Failed to copy SAR values");
      return false;
   }
   
   // Get ATR values
   ArraySetAsSeries(atr_values, true);
   if(CopyBuffer(ATR_Handle, 0, 0, 3, atr_values) < 3)
   {
      Print("Failed to copy ATR values");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check entry conditions                                           |
//+------------------------------------------------------------------+
void CheckEntryCondition(const double &rsi_values[], const double &rsi_prev_values[],
                        const double &bb_upper[], const double &bb_lower[],
                        const MqlRates &price_data[], const double &atr_values[])
{
   // Get current prices
   double current_close = price_data[0].close;
   double current_bid = SymbolInfoDouble(SymbolToTrade, SYMBOL_BID);
   double current_ask = SymbolInfoDouble(SymbolToTrade, SYMBOL_ASK);
   
   // Check for buy signal (RSI was above 30 and crossed below it + price below lower BB)
   bool buy_signal = false;
   if(rsi_values[0] < RSI_Oversold && rsi_prev_values[0] >= RSI_Oversold && current_close < bb_lower[0])
   {
      buy_signal = true;
      
      // Optional pattern confirmation
      if(UsePatternConfirmation && !IsBullishPattern(price_data))
      {
         buy_signal = false;
         Print("Buy signal canceled - no bullish pattern confirmation");
      }
   }
   
   // Check for sell signal (RSI was below 70 and crossed above it + price above upper BB)
   bool sell_signal = false;
   if(rsi_values[0] > RSI_Overbought && rsi_prev_values[0] <= RSI_Overbought && current_close > bb_upper[0])
   {
      sell_signal = true;
      
      // Optional pattern confirmation
      if(UsePatternConfirmation && !IsBearishPattern(price_data))
      {
         sell_signal = false;
         Print("Sell signal canceled - no bearish pattern confirmation");
      }
   }
   
   // Take trade if signal detected
   if(buy_signal)
   {
      // Calculate stop loss level based on ATR
      double stop_loss = current_ask - (atr_values[0] * SL_ATR_Multiplier);
      double risk = current_ask - stop_loss;
      
      // Calculate lot size
      double lot_size = CalculateLotSize(risk);
      
      // Execute buy order
      if(trade.Buy(lot_size, SymbolToTrade, current_ask, stop_loss, 0.0, "RSI-BB-SAR Buy"))
      {
         position_open = true;
         entry_price = current_ask;
         Print("BUY signal: RSI=", rsi_values[0], " crossed below ", RSI_Oversold, 
              ", Price=", current_close, " below lower BB=", bb_lower[0],
              ", SL=", stop_loss, ", ATR=", atr_values[0]);
      }
      else
      {
         Print("Failed to execute BUY order. Error: ", GetLastError());
      }
   }
   else if(sell_signal)
   {
      // Calculate stop loss level based on ATR
      double stop_loss = current_bid + (atr_values[0] * SL_ATR_Multiplier);
      double risk = stop_loss - current_bid;
      
      // Calculate lot size
      double lot_size = CalculateLotSize(risk);
      
      // Execute sell order
      if(trade.Sell(lot_size, SymbolToTrade, current_bid, stop_loss, 0.0, "RSI-BB-SAR Sell"))
      {
         position_open = true;
         entry_price = current_bid;
         Print("SELL signal: RSI=", rsi_values[0], " crossed above ", RSI_Overbought, 
              ", Price=", current_close, " above upper BB=", bb_upper[0],
              ", SL=", stop_loss, ", ATR=", atr_values[0]);
      }
      else
      {
         Print("Failed to execute SELL order. Error: ", GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| Check exit conditions                                            |
//+------------------------------------------------------------------+
void CheckExitCondition()
{
   // Make sure position exists
   if(!PositionSelect(SymbolToTrade)) return;
   
   // Get SAR values
   double sar_values[];
   ArraySetAsSeries(sar_values, true);
   if(CopyBuffer(SAR_Handle, 0, 0, 2, sar_values) < 2)
   {
      Print("Failed to copy SAR values for exit check");
      return;
   }
   
   // Get current price data
   double current_bid = SymbolInfoDouble(SymbolToTrade, SYMBOL_BID);
   double current_ask = SymbolInfoDouble(SymbolToTrade, SYMBOL_ASK);
   
   // Get position details
   ulong position_type = PositionGetInteger(POSITION_TYPE);
   
   // Check for exit signals based on Parabolic SAR
   if(position_type == POSITION_TYPE_BUY)
   {
      // Exit buy when SAR flips above price
      if(sar_values[0] > current_bid)
      {
         if(trade.PositionClose(SymbolToTrade))
         {
            Print("BUY position closed: SAR (", sar_values[0], ") flipped above price (", current_bid, ")");
            position_open = false;
         }
         else
         {
            Print("Failed to close BUY position. Error: ", GetLastError());
         }
      }
   }
   else if(position_type == POSITION_TYPE_SELL)
   {
      // Exit sell when SAR flips below price
      if(sar_values[0] < current_ask)
      {
         if(trade.PositionClose(SymbolToTrade))
         {
            Print("SELL position closed: SAR (", sar_values[0], ") flipped below price (", current_ask, ")");
            position_open = false;
         }
         else
         {
            Print("Failed to close SELL position. Error: ", GetLastError());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Update trailing stop for open positions                          |
//+------------------------------------------------------------------+
void UpdateTrailingStop()
{
   // Make sure position exists
   if(!PositionSelect(SymbolToTrade)) return;
   
   // Get ATR values
   double atr_values[];
   ArraySetAsSeries(atr_values, true);
   if(CopyBuffer(ATR_Handle, 0, 0, 1, atr_values) < 1)
   {
      Print("Failed to copy ATR values for trailing stop update");
      return;
   }
   
   // Get position details
   ulong position_type = PositionGetInteger(POSITION_TYPE);
   double position_sl = PositionGetDouble(POSITION_SL);
   double position_tp = PositionGetDouble(POSITION_TP);
   
   // Get current price
   double current_bid = SymbolInfoDouble(SymbolToTrade, SYMBOL_BID);
   double current_ask = SymbolInfoDouble(SymbolToTrade, SYMBOL_ASK);
   
   // Calculate ATR-based stop distance
   double atr_trail = atr_values[0] * TrailATRMultiplier;
   
   // Update trailing stop for buy positions
   if(position_type == POSITION_TYPE_BUY)
   {
      // Calculate new stop loss level
      double new_sl = current_bid - atr_trail;
      
      // Only move stop loss up
      if(new_sl > position_sl)
      {
         if(trade.PositionModify(SymbolToTrade, new_sl, position_tp))
         {
            Print("Trailing stop updated for BUY position: New SL=", new_sl);
         }
      }
   }
   // Update trailing stop for sell positions
   else if(position_type == POSITION_TYPE_SELL)
   {
      // Calculate new stop loss level
      double new_sl = current_ask + atr_trail;
      
      // Only move stop loss down
      if(new_sl < position_sl || position_sl == 0)
      {
         if(trade.PositionModify(SymbolToTrade, new_sl, position_tp))
         {
            Print("Trailing stop updated for SELL position: New SL=", new_sl);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk                            |
//+------------------------------------------------------------------+
double CalculateLotSize(double risk_in_price)
{
   double lot_size = FixedLotSize; // Default to fixed lot size
   
   // If using risk percentage
   if(PositionSizingType == RISK_PERCENTAGE)
   {
      double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double risk_amount = account_balance * (RiskPercentage / 100.0);
      
      // Calculate value per pip
      double tick_size = SymbolInfoDouble(SymbolToTrade, SYMBOL_TRADE_TICK_SIZE);
      double tick_value = SymbolInfoDouble(SymbolToTrade, SYMBOL_TRADE_TICK_VALUE);
      double contract_size = SymbolInfoDouble(SymbolToTrade, SYMBOL_TRADE_CONTRACT_SIZE);
      
      // Convert risk to lots
      if(tick_size > 0 && tick_value > 0)
      {
         double ticks_per_risk = risk_in_price / tick_size;
         double risk_per_lot = ticks_per_risk * tick_value;
         
         if(risk_per_lot > 0)
         {
            lot_size = NormalizeDouble(risk_amount / risk_per_lot, 2);
         }
      }
      
      // Enforce minimum and maximum lot sizes
      double min_lot = SymbolInfoDouble(SymbolToTrade, SYMBOL_VOLUME_MIN);
      double max_lot = SymbolInfoDouble(SymbolToTrade, SYMBOL_VOLUME_MAX);
      double lot_step = SymbolInfoDouble(SymbolToTrade, SYMBOL_VOLUME_STEP);
      
      // Ensure lot size is within allowed range
      lot_size = MathMax(min_lot, MathMin(max_lot, lot_size));
      
      // Round to the nearest lot step
      if(lot_step > 0)
      {
         lot_size = NormalizeDouble(MathRound(lot_size / lot_step) * lot_step, 2);
      }
   }
   
   return lot_size;
}

//+------------------------------------------------------------------+
//| Check for bullish candlestick patterns                           |
//+------------------------------------------------------------------+
bool IsBullishPattern(const MqlRates &price_data[])
{
   // Bullish Engulfing pattern
   if(price_data[1].close < price_data[1].open && // Previous candle was bearish
      price_data[0].open < price_data[1].close && // Current candle opens below previous close
      price_data[0].close > price_data[1].open)   // Current candle closes above previous open
   {
      return true;
   }
   
   // Hammer pattern (simplified check)
   double body_size = MathAbs(price_data[0].close - price_data[0].open);
   double lower_wick = MathMin(price_data[0].open, price_data[0].close) - price_data[0].low;
   double upper_wick = price_data[0].high - MathMax(price_data[0].open, price_data[0].close);
   
   if(price_data[0].close > price_data[0].open && // Bullish candle
      lower_wick > 2 * body_size &&               // Long lower wick (at least 2x body)
      upper_wick < 0.5 * body_size)               // Short or no upper wick
   {
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check for bearish candlestick patterns                           |
//+------------------------------------------------------------------+
bool IsBearishPattern(const MqlRates &price_data[])
{
   // Bearish Engulfing pattern
   if(price_data[1].close > price_data[1].open && // Previous candle was bullish
      price_data[0].open > price_data[1].close && // Current candle opens above previous close
      price_data[0].close < price_data[1].open)   // Current candle closes below previous open
   {
      return true;
   }
   
   // Shooting Star pattern (simplified check)
   double body_size = MathAbs(price_data[0].close - price_data[0].open);
   double lower_wick = MathMin(price_data[0].open, price_data[0].close) - price_data[0].low;
   double upper_wick = price_data[0].high - MathMax(price_data[0].open, price_data[0].close);
   
   if(price_data[0].close < price_data[0].open && // Bearish candle
      upper_wick > 2 * body_size &&               // Long upper wick (at least 2x body)
      lower_wick < 0.5 * body_size)               // Short or no lower wick
   {
      return true;
   }
   
   return false;
}