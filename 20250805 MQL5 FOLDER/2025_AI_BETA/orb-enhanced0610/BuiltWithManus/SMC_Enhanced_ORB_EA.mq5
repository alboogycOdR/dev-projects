//+------------------------------------------------------------------+
//|                                       SMC_Enhanced_ORB_EA.mq5 |
//|                                                  Manus AI       |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Manus AI"
#property link      "https://www.manus.ai"
#property version   "1.00"
#property description "SMC Enhanced Open Range Breakout Expert Advisor"

#include <Trade\Trade.mqh>
CTrade         Trade;                // Global CTrade object

//--- Input parameters
input int      ORB_Timeframe_Minutes = 15; // Opening Range period in minutes
input int      ORB_Start_Hour        = 9;  // Market Open Hour (e.g., 9 for 9:00 AM)
input int      ORB_Start_Minute      = 30; // Market Open Minute (e.g., 30 for 9:30 AM)
input int      ORB_End_Hour          = 10; // Opening Range End Hour (e.g., 10 for 10:00 AM)
input int      ORB_End_Minute        = 0;  // Opening Range End Minute (e.g., 0 for 10:00 AM)
input double   RiskPerTrade          = 0.01; // Risk per trade as a percentage of balance
input int      MagicNumber           = 12345; // Unique Magic Number for trades

//--- Global variables
double         ORB_High = 0.0;
double         ORB_Low  = 0.0;
datetime       ORB_Calculated_Time = 0;
bool           trade_taken_today = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Check for valid ORB time settings
   if (ORB_Start_Hour < 0 || ORB_Start_Hour > 23 || ORB_End_Hour < 0 || ORB_End_Hour > 23 ||
       ORB_Start_Minute < 0 || ORB_Start_Minute > 59 || ORB_End_Minute < 0 || ORB_End_Minute > 59)
     {
      Print("ERROR: Invalid ORB time settings. Please check inputs.");
      return(INIT_PARAMETERS_INCORRECT);
     }

//--- Set the chart timeframe to the ORB timeframe for easier calculation (optional, but good practice)
//    This might not be necessary if you use iHigh/iLow with specific timeframes
//    ChartSetSymbolPeriod(0, ENUM_TIMEFRAMES(ORB_Timeframe_Minutes)); // This line is for chart manipulation, not for EA logic directly

//---
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   Print("SMC Enhanced ORB EA Deinitialized. Reason: ", reason);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- Get current time
   MqlDateTime current_time_struct;
   TimeCurrent(current_time_struct);
   datetime current_time = StructToTime(current_time_struct);

//--- Reset trade_taken_today flag at the start of a new day
   MqlDateTime cur_dt, orb_dt;
   TimeToStruct(current_time, cur_dt);
   TimeToStruct(ORB_Calculated_Time, orb_dt);
   if (cur_dt.year != orb_dt.year || cur_dt.mon != orb_dt.mon || cur_dt.day != orb_dt.day)
     {
      trade_taken_today = false;
      ORB_High = 0.0;
      ORB_Low = 0.0;
      ORB_Calculated_Time = 0;
      Print("New day started. Resetting trade status and ORB.");
     }

//--- Calculate ORB if not calculated for today
   MqlDateTime orb_end_time_struct;
   TimeCurrent(orb_end_time_struct);
   orb_end_time_struct.hour = ORB_End_Hour;
   orb_end_time_struct.min = ORB_End_Minute;
   orb_end_time_struct.sec = 0;
   datetime orb_end_time = StructToTime(orb_end_time_struct);

   if (ORB_Calculated_Time == 0 && current_time >= orb_end_time)
     {
      CalculateORB();
     }

//--- Execute trading logic after ORB is calculated and if no trade taken today
   if (ORB_Calculated_Time != 0 && !trade_taken_today)
     {
      ExecuteTradingLogic();
     }
  }

//+------------------------------------------------------------------+
//| Custom function to calculate the Opening Range Breakout (ORB)    |
//+------------------------------------------------------------------+
void CalculateORB()
  {
   datetime start_orb_time = D'';
   datetime end_orb_time = D'';
   
   // Construct the start and end time for the ORB period for the current day
   MqlDateTime start_orb_dt;
   TimeCurrent(start_orb_dt);
   start_orb_dt.hour = ORB_Start_Hour;
   start_orb_dt.min = ORB_Start_Minute;
   start_orb_dt.sec = 0;
   start_orb_time = StructToTime(start_orb_dt);
   
   MqlDateTime end_orb_dt;
   TimeCurrent(end_orb_dt);
   end_orb_dt.hour = ORB_End_Hour;
   end_orb_dt.min = ORB_End_Minute;
   end_orb_dt.sec = 0;
   end_orb_time = StructToTime(end_orb_dt);

   // This check is to ensure we don't try to calculate ORB for a future date,
   // though the OnTick logic should already prevent this.
   if (start_orb_time > TimeCurrent())
     {
      return;
     }

   // Get historical data for the ORB period
   MqlRates rates[];
   // Use M1 data for precise high/low of the range
   int count = CopyRates(_Symbol, PERIOD_M1, start_orb_time, end_orb_time, rates);

   if (count <= 0)
     {
      Print("ERROR: Could not get historical data for ORB calculation. Count: ", count);
      return;
     }

   ORB_High = 0.0;
   ORB_Low  = 999999.9; // Initialize with a very high value

   for (int i = 0; i < count; i++)
     {
      if (rates[i].high > ORB_High)
         ORB_High = rates[i].high;
      if (rates[i].low < ORB_Low)
         ORB_Low = rates[i].low;
     }

   ORB_Calculated_Time = TimeCurrent(); // Mark ORB as calculated for today
   if(ORB_High > 0 && ORB_Low < 999999.9)
     {
      PrintFormat("ORB Calculated for %s: High=%.5f, Low=%.5f", TimeToString(ORB_Calculated_Time), ORB_High, ORB_Low);
     }
   else
     {
      Print("ORB Calculation resulted in invalid range. High/Low not updated.");
     }
  }

//+------------------------------------------------------------------+
//| Checks for a bullish liquidity sweep below a certain price level.|
//+------------------------------------------------------------------+
bool HasBullishLiquiditySweep(double price_level, ENUM_TIMEFRAMES timeframe, int lookback_period)
  {
   MqlRates rates[];
   if(CopyRates(_Symbol, timeframe, 1, lookback_period, rates) < lookback_period)
     {
      Print("Error copying rates for Bullish Liquidity Sweep check.");
      return false;
     }

   for(int i = 0; i < lookback_period; i++)
     {
      // Check for a wick below the price_level with a close back above it
      if(rates[i].low < price_level && rates[i].close > price_level)
        {
         // Draw arrow up for bullish liquidity sweep
         string obj_name = StringFormat("BullSweep_%d", rates[i].time);
         if(!ObjectFind(0, obj_name))
           {
            ObjectCreate(0, obj_name, OBJ_ARROW_UP, 0, rates[i].time, rates[i].low);
            ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clrLime);
            ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 2);
           }
         return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Checks for a bearish liquidity sweep above a certain price level.|
//+------------------------------------------------------------------+
bool HasBearishLiquiditySweep(double price_level, ENUM_TIMEFRAMES timeframe, int lookback_period)
  {
   MqlRates rates[];
   if(CopyRates(_Symbol, timeframe, 1, lookback_period, rates) < lookback_period)
     {
      Print("Error copying rates for Bearish Liquidity Sweep check.");
      return false;
     }

   for(int i = 0; i < lookback_period; i++)
     {
      // Check for a wick above the price_level with a close back below it
      if(rates[i].high > price_level && rates[i].close < price_level)
        {
         // Draw arrow down for bearish liquidity sweep
         string obj_name = StringFormat("BearSweep_%d", rates[i].time);
         if(!ObjectFind(0, obj_name))
           {
            ObjectCreate(0, obj_name, OBJ_ARROW_DOWN, 0, rates[i].time, rates[i].high);
            ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 2);
           }
         return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Checks for a bullish order block.                                |
//+------------------------------------------------------------------+
bool IsBullishOrderBlock(int shift, ENUM_TIMEFRAMES timeframe, double &ob_high, double &ob_low)
  {
   MqlRates rates[];
   if(CopyRates(_Symbol, timeframe, shift, 3, rates) < 3)
     {
      Print("Error copying rates for Bullish Order Block check.");
      return false;
     }

   if(rates[1].close < rates[1].open && // bearish candle
      rates[0].close > rates[0].open && // bullish candle
      rates[0].close > rates[1].high)   // displacement/break of structure
     {
      ob_high = rates[1].high;
      ob_low = rates[1].low;
      // Draw rectangle for bullish order block
      string obj_name = StringFormat("BullOB_%d", rates[1].time);
      if(!ObjectFind(0, obj_name))
        {
         ObjectCreate(0, obj_name, OBJ_RECTANGLE, 0, rates[1].time, ob_high, rates[0].time, ob_low);
         ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clrLime);
         ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
         ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, obj_name, OBJPROP_STYLE, STYLE_DOT);
        }
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Checks for a bearish order block.                                |
//+------------------------------------------------------------------+
bool IsBearishOrderBlock(int shift, ENUM_TIMEFRAMES timeframe, double &ob_high, double &ob_low)
  {
   MqlRates rates[];
   if(CopyRates(_Symbol, timeframe, shift, 3, rates) < 3)
     {
      Print("Error copying rates for Bearish Order Block check.");
      return false;
     }

   if(rates[1].close > rates[1].open && // bullish candle
      rates[0].close < rates[0].open && // bearish candle
      rates[0].close < rates[1].low)    // displacement/break of structure
     {
      ob_high = rates[1].high;
      ob_low = rates[1].low;
      // Draw rectangle for bearish order block
      string obj_name = StringFormat("BearOB_%d", rates[1].time);
      if(!ObjectFind(0, obj_name))
        {
         ObjectCreate(0, obj_name, OBJ_RECTANGLE, 0, rates[1].time, ob_high, rates[0].time, ob_low);
         ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
         ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, obj_name, OBJPROP_STYLE, STYLE_DOT);
        }
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Checks for a bullish Fair Value Gap (FVG).                       |
//+------------------------------------------------------------------+
bool HasBullishFVG(int shift, ENUM_TIMEFRAMES timeframe, double &fvg_high, double &fvg_low)
  {
   MqlRates rates[];
   if(CopyRates(_Symbol, timeframe, shift, 3, rates) < 3)
     {
      Print("Error copying rates for Bullish FVG check.");
      return false;
     }

   if(rates[0].low > rates[2].high)
     {
      fvg_high = rates[0].low;
      fvg_low = rates[2].high;
      // Draw rectangle for bullish FVG
      string obj_name = StringFormat("BullFVG_%d", rates[2].time);
      if(!ObjectFind(0, obj_name))
        {
         ObjectCreate(0, obj_name, OBJ_RECTANGLE, 0, rates[2].time, fvg_high, rates[0].time, fvg_low);
         ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clrAqua);
         ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
         ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, obj_name, OBJPROP_STYLE, STYLE_SOLID);
        }
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Checks for a bearish Fair Value Gap (FVG).                       |
//+------------------------------------------------------------------+
bool HasBearishFVG(int shift, ENUM_TIMEFRAMES timeframe, double &fvg_high, double &fvg_low)
  {
   MqlRates rates[];
   if(CopyRates(_Symbol, timeframe, shift, 3, rates) < 3)
     {
      Print("Error copying rates for Bearish FVG check.");
      return false;
     }

   if(rates[0].high < rates[2].low)
     {
      fvg_high = rates[2].low;
      fvg_low = rates[0].high;
      // Draw rectangle for bearish FVG
      string obj_name = StringFormat("BearFVG_%d", rates[2].time);
      if(!ObjectFind(0, obj_name))
        {
         ObjectCreate(0, obj_name, OBJ_RECTANGLE, 0, rates[2].time, fvg_high, rates[0].time, fvg_low);
         ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clrOrange);
         ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
         ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, obj_name, OBJPROP_STYLE, STYLE_SOLID);
        }
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Custom function for trading logic                                |
//+------------------------------------------------------------------+
void ExecuteTradingLogic()
  {
   if (trade_taken_today) return; // Ensure only one trade per day

   // Get current price
   double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Get current candle data (for SMC checks)
   MqlRates current_rates[];
   if (CopyRates(_Symbol, _Period, 0, 2, current_rates) != 2) return; // Need current and previous candle
   
   double ob_high = 0.0, ob_low = 0.0, fvg_high = 0.0, fvg_low = 0.0;
   bool   smc_confirmation_long = false;
   bool   smc_confirmation_short = false;

   //--- Check for Bullish ORB Breakout
   if (current_ask > ORB_High) // Price breaks above ORB High
     {
      PrintFormat("Potential Bullish ORB Breakout detected. Current Ask: %.5f, ORB High: %.5f", current_ask, ORB_High);
      
      // SMC Confirmation for Long Trade
      // 1. Check for a recent bearish liquidity sweep below ORB_Low (optional but strong)
      bool liquidity_swept_bearish = HasBullishLiquiditySweep(ORB_Low, _Period, 10); // Look back 10 bars
      if (liquidity_swept_bearish) Print("  - Bullish Liquidity Sweep detected below ORB Low.");

      // 2. Check for a bullish Order Block near the breakout or on retest
      bool bullish_ob_found = IsBullishOrderBlock(1, _Period, ob_high, ob_low); // Check previous candle for OB
      if (bullish_ob_found) PrintFormat("  - Bullish Order Block found: High=%.5f, Low=%.5f", ob_high, ob_low);

      // 3. Check for a bullish FVG above current price (potential target)
      bool bullish_fvg_found = HasBullishFVG(0, _Period, fvg_high, fvg_low); // Check current candles for FVG
      if (bullish_fvg_found) PrintFormat("  - Bullish FVG found: High=%.5f, Low=%.5f", fvg_high, fvg_low);

      // Combine SMC confirmations (adjust logic based on desired strictness)
      if (bullish_ob_found && bullish_fvg_found && liquidity_swept_bearish) // Example: require all three
        {
         smc_confirmation_long = true;
         Print("  - All SMC confirmations met for LONG trade.");
        }
      else if (bullish_ob_found && bullish_fvg_found) // Example: require OB and FVG
        {
         smc_confirmation_long = true;
         Print("  - OB and FVG confirmations met for LONG trade.");
        }
     }

   //--- Check for Bearish ORB Breakout
   if (current_bid < ORB_Low) // Price breaks below ORB Low
     {
      PrintFormat("Potential Bearish ORB Breakout detected. Current Bid: %.5f, ORB Low: %.5f", current_bid, ORB_Low);

      // SMC Confirmation for Short Trade
      // 1. Check for a recent bullish liquidity sweep above ORB_High (optional but strong)
      bool liquidity_swept_bullish = HasBearishLiquiditySweep(ORB_High, _Period, 10); // Look back 10 bars
      if (liquidity_swept_bullish) Print("  - Bearish Liquidity Sweep detected above ORB High.");

      // 2. Check for a bearish Order Block near the breakout or on retest
      bool bearish_ob_found = IsBearishOrderBlock(1, _Period, ob_high, ob_low); // Check previous candle for OB
      if (bearish_ob_found) PrintFormat("  - Bearish Order Block found: High=%.5f, Low=%.5f", ob_high, ob_low);

      // 3. Check for a bearish FVG below current price (potential target)
      bool bearish_fvg_found = HasBearishFVG(0, _Period, fvg_high, fvg_low); // Check current candles for FVG
      if (bearish_fvg_found) PrintFormat("  - Bearish FVG found: High=%.5f, Low=%.5f", fvg_high, fvg_low);

      // Combine SMC confirmations (adjust logic based on desired strictness)
      if (bearish_ob_found && bearish_fvg_found && liquidity_swept_bullish) // Example: require all three
        {
         smc_confirmation_short = true;
         Print("  - All SMC confirmations met for SHORT trade.");
        }
      else if (bearish_ob_found && bearish_fvg_found) // Example: require OB and FVG
        {
         smc_confirmation_short = true;
         Print("  - OB and FVG confirmations met for SHORT trade.");
        }
     }

   //--- Execute Trade if SMC confirmed
   if (smc_confirmation_long)
     {
      // Define Stop Loss (e.g., below ORB Low or confirming OB Low)
      double stop_loss = NormalizeDouble(ob_low - 5 * _Point, _Digits); // Example: 5 points below OB Low
      if (ob_low == 0 || stop_loss >= current_ask) stop_loss = NormalizeDouble(ORB_Low - 5 * _Point, _Digits); // Fallback

      // Calculate lot size based on risk and actual stop loss
      double sl_pips = (current_ask - stop_loss) / _Point;
      double lot_size = 0.0;
      if(sl_pips > 0)
        {
         lot_size = NormalizeLot(AccountInfoDouble(ACCOUNT_BALANCE) * RiskPerTrade / (sl_pips * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE)));
        }
      if (lot_size <= 0) lot_size = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

      // Define Take Profit (e.g., at FVG High or 1:2 RR)
      double take_profit = 0.0;
      if(fvg_high > 0) take_profit = NormalizeDouble(fvg_high, _Digits); // Example: FVG High
      if (take_profit == 0 || take_profit <= current_ask) take_profit = NormalizeDouble(current_ask + (current_ask - stop_loss) * 2, _Digits); // Fallback 1:2 RR

      // Send Buy Order
      Trade.Buy(lot_size, _Symbol, current_ask, stop_loss, take_profit, "SMC_ORB_Long");
      trade_taken_today = true;
      PrintFormat("LONG Trade Executed: Lot=%.2f, SL=%.5f, TP=%.5f", lot_size, stop_loss, take_profit);
     }
   else if (smc_confirmation_short)
     {
      // Define Stop Loss (e.g., above ORB High or confirming OB High)
      double stop_loss = NormalizeDouble(ob_high + 5 * _Point, _Digits); // Example: 5 points above OB High
      if (ob_high == 0 || stop_loss <= current_bid) stop_loss = NormalizeDouble(ORB_High + 5 * _Point, _Digits); // Fallback

      // Calculate lot size based on risk and actual stop loss
      double sl_pips = (stop_loss - current_bid) / _Point;
      double lot_size = 0.0;
      if(sl_pips > 0)
        {
         lot_size = NormalizeLot(AccountInfoDouble(ACCOUNT_BALANCE) * RiskPerTrade / (sl_pips * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE)));
        }
      if (lot_size <= 0) lot_size = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

      // Define Take Profit (e.g., at FVG Low or 1:2 RR)
      double take_profit = 0.0;
      if(fvg_low > 0) take_profit = NormalizeDouble(fvg_low, _Digits); // Example: FVG Low
      if (take_profit == 0 || take_profit >= current_bid) take_profit = NormalizeDouble(current_bid - (stop_loss - current_bid) * 2, _Digits); // Fallback 1:2 RR

      // Send Sell Order
      Trade.Sell(lot_size, _Symbol, current_bid, stop_loss, take_profit, "SMC_ORB_Short");
      trade_taken_today = true;
      PrintFormat("SHORT Trade Executed: Lot=%.2f, SL=%.5f, TP=%.5f", lot_size, stop_loss, take_profit);
     }
  }

//+------------------------------------------------------------------+
//| Helper function to normalize lot size                            |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
  {
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lot = MathMax(min_lot, lot);
   lot = MathMin(max_lot, lot);
   lot = MathRound(lot / step_lot) * step_lot;
   return(lot);
  }

// //+------------------------------------------------------------------+
// //| Helper function to convert MqlDateTime to datetime               |
// //+------------------------------------------------------------------+
// datetime StructToTime(MqlDateTime& dt)
//   {
//    return(MqlDateTimeToTime(dt));
//   }



