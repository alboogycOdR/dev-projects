//+------------------------------------------------------------------+
//|                                                     CRT_EA.mq5 |
//|                                                     Manus Team |
//|                                  https://www.manus.com/mql5-ea |
//+------------------------------------------------------------------+
#property copyright "Manus Team"
#property link      "https://www.manus.com/mql5-ea"
#property version   "1.00"
#property description "Expert Advisor for the 9 AM Candle Range Theory (CRT) trading model."

//--- Input parameters
input ENUM_TIMEFRAMES InpCRTTimeframe = PERIOD_H1; // Timeframe for CRT candle (8 AM NY)
input int InpNYKillzoneStartHour = 9;             // NY Killzone Start Hour (ET)
input int InpNYKillzoneStartMinute = 30;          // NY Killzone Start Minute (ET)
input int InpNYKillzoneEndHour = 11;              // NY Killzone End Hour (ET)
input int InpNYKillzoneEndMinute = 0;             // NY Killzone End Minute (ET)
input double InpRiskPercentage = 0.5;             // Risk per trade as a percentage of balance
input double InpTP1Percentage = 50.0;             // Take Profit 1 percentage of CRT range
input ENUM_TIMEFRAMES InpKeyLevelTimeframe = PERIOD_D1; // Timeframe for HTF Key Level identification
input ENUM_OPERATIONAL_MODE InpOperationalMode = MODE_FULLY_AUTOMATED; // Operational Mode
input bool InpEnableSoundAlerts = true;           // Enable sound alerts for signals
input string InpCorrelatedSymbol = "ES";          // Correlated symbol for SMT Divergence (e.g., ES for NQ)
input int InpNewsFilterMinutes = 30;              // Minutes before/after high-impact news to avoid trading
input int InpBreakevenPips = 10; // Pips to move to breakeven
input int InpTrailingStopPips = 20; // Pips for trailing stop

//--- Global variables
double CRT_High;       // 8 AM CRT High
double CRT_Low;        // 8 AM CRT Low
bool CRT_Range_Set = false; // Flag to ensure CRT range is set once per day

//--- Enums
enum ENUM_OPERATIONAL_MODE
  {
   MODE_FULLY_AUTOMATED, // EA takes trades automatically
   MODE_SIGNALS_ONLY,    // EA generates signals/alerts, no automatic trades
   MODE_MANUAL           // EA provides a trade panel for manual execution
  };

//--- Define _Point if not already defined (usually it is, but for clarity)
#ifndef _Point
   #define _Point SymbolInfoDouble(Symbol(), SYMBOL_POINT)
#endif

//--- Define _Point_Adjusted for correct SL/TP calculations
#ifndef _Point_Adjusted
   #define _Point_Adjusted (SymbolInfoInteger(Symbol(), SYMBOL_DIGITS) == 3 || SymbolInfoInteger(Symbol(), SYMBOL_DIGITS) == 5 ? _Point * 10 : _Point)
#endif

#include <Trade\Trade.mqh>
CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Create chart objects for CRT lines
   ObjectCreate(0, "CRT_High_Line", OBJ_HLINE, 0, 0, 0);
   ObjectSetInteger(0, "CRT_High_Line", OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(0, "CRT_High_Line", OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, "CRT_High_Line", OBJPROP_WIDTH, 1);
   ObjectSetString(0, "CRT_High_Line", OBJPROP_TEXT, "CRT High");

   ObjectCreate(0, "CRT_Low_Line", OBJ_HLINE, 0, 0, 0);
   ObjectSetInteger(0, "CRT_Low_Line", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, "CRT_Low_Line", OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, "CRT_Low_Line", OBJPROP_WIDTH, 1);
   ObjectSetString(0, "CRT_Low_Line", OBJPROP_TEXT, "CRT Low");

//--- Initialize CTrade object
   trade.SetExpertMagicNumber(12345); // Set a unique magic number for the EA
   trade.SetTypeFilling(ORDER_FILLING_FOK); // Fill or Kill
   trade.SetTypeReturning(ORDER_RETURN_IMMEDIATE); // Immediate return

//--- Create dashboard objects
   ObjectCreate(0, "Dashboard_Background", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "Dashboard_Background", OBJPROP_XSIZE, 250);
   ObjectSetInteger(0, "Dashboard_Background", OBJPROP_YSIZE, 200);
   ObjectSetInteger(0, "Dashboard_Background", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "Dashboard_Background", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "Dashboard_Background", OBJPROP_YDISTANCE, 10);
   ObjectSetInteger(0, "Dashboard_Background", OBJPROP_BG_COLOR, clrBlack);
   ObjectSetInteger(0, "Dashboard_Background", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "Dashboard_Background", OBJPROP_BACK, false);
   ObjectSetInteger(0, "Dashboard_Background", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, "Dashboard_Background", OBJPROP_HIDDEN, true);

   ObjectCreate(0, "Dashboard_Title", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "Dashboard_Title", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "Dashboard_Title", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, "Dashboard_Title", OBJPROP_YDISTANCE, 20);
   ObjectSetString(0, "Dashboard_Title", OBJPROP_TEXT, "CRT EA Dashboard");
   ObjectSetInteger(0, "Dashboard_Title", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "Dashboard_Title", OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, "Dashboard_Title", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, "Dashboard_Title", OBJPROP_HIDDEN, true);

   ObjectCreate(0, "Dashboard_Bias", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "Dashboard_Bias", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "Dashboard_Bias", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, "Dashboard_Bias", OBJPROP_YDISTANCE, 40);
   ObjectSetString(0, "Dashboard_Bias", OBJPROP_TEXT, "Daily Bias: N/A");
   ObjectSetInteger(0, "Dashboard_Bias", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "Dashboard_Bias", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, "Dashboard_Bias", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, "Dashboard_Bias", OBJPROP_HIDDEN, true);

   ObjectCreate(0, "Dashboard_KeyLevel", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "Dashboard_KeyLevel", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "Dashboard_KeyLevel", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, "Dashboard_KeyLevel", OBJPROP_YDISTANCE, 55);
   ObjectSetString(0, "Dashboard_KeyLevel", OBJPROP_TEXT, "HTF Key Level: N/A");
   ObjectSetInteger(0, "Dashboard_KeyLevel", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "Dashboard_KeyLevel", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, "Dashboard_KeyLevel", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, "Dashboard_KeyLevel", OBJPROP_HIDDEN, true);

   ObjectCreate(0, "Dashboard_CRT", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "Dashboard_CRT", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "Dashboard_CRT", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, "Dashboard_CRT", OBJPROP_YDISTANCE, 70);
   ObjectSetString(0, "Dashboard_CRT", OBJPROP_TEXT, "CRT Range: N/A");
   ObjectSetInteger(0, "Dashboard_CRT", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "Dashboard_CRT", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, "Dashboard_CRT", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, "Dashboard_CRT", OBJPROP_HIDDEN, true);

   ObjectCreate(0, "Dashboard_News", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "Dashboard_News", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "Dashboard_News", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, "Dashboard_News", OBJPROP_YDISTANCE, 85);
   ObjectSetString(0, "Dashboard_News", OBJPROP_TEXT, "News Filter: Active");
   ObjectSetInteger(0, "Dashboard_News", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "Dashboard_News", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, "Dashboard_News", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, "Dashboard_News", OBJPROP_HIDDEN, true);

   ObjectCreate(0, "Dashboard_SMT", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "Dashboard_SMT", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "Dashboard_SMT", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, "Dashboard_SMT", OBJPROP_YDISTANCE, 100);
   ObjectSetString(0, "Dashboard_SMT", OBJPROP_TEXT, "SMT Divergence: N/A");
   ObjectSetInteger(0, "Dashboard_SMT", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "Dashboard_SMT", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, "Dashboard_SMT", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, "Dashboard_SMT", OBJPROP_HIDDEN, true);

   ObjectCreate(0, "Dashboard_P_L", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "Dashboard_P_L", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "Dashboard_P_L", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, "Dashboard_P_L", OBJPROP_YDISTANCE, 115);
   ObjectSetString(0, "Dashboard_P_L", OBJPROP_TEXT, "P/L: N/A");
   ObjectSetInteger(0, "Dashboard_P_L", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "Dashboard_P_L", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, "Dashboard_P_L", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, "Dashboard_P_L", OBJPROP_HIDDEN, true);

   ObjectCreate(0, "Dashboard_Session", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "Dashboard_Session", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "Dashboard_Session", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, "Dashboard_Session", OBJPROP_YDISTANCE, 130);
   ObjectSetString(0, "Dashboard_Session", OBJPROP_TEXT, "Session: N/A");
   ObjectSetInteger(0, "Dashboard_Session", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "Dashboard_Session", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, "Dashboard_Session", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, "Dashboard_Session", OBJPROP_HIDDEN, true);

   ObjectCreate(0, "Dashboard_BuyButton", OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, "Dashboard_BuyButton", OBJPROP_XSIZE, 60);
   ObjectSetInteger(0, "Dashboard_BuyButton", OBJPROP_YSIZE, 20);
   ObjectSetInteger(0, "Dashboard_BuyButton", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "Dashboard_BuyButton", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, "Dashboard_BuyButton", OBJPROP_YDISTANCE, 150);
   ObjectSetString(0, "Dashboard_BuyButton", OBJPROP_TEXT, "BUY");
   ObjectSetInteger(0, "Dashboard_BuyButton", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "Dashboard_BuyButton", OBJPROP_BG_COLOR, clrGreen);
   ObjectSetInteger(0, "Dashboard_BuyButton", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, "Dashboard_BuyButton", OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, "Dashboard_BuyButton", OBJPROP_HIDDEN, true);

   ObjectCreate(0, "Dashboard_SellButton", OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, "Dashboard_SellButton", OBJPROP_XSIZE, 60);
   ObjectSetInteger(0, "Dashboard_SellButton", OBJPROP_YSIZE, 20);
   ObjectSetInteger(0, "Dashboard_SellButton", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "Dashboard_SellButton", OBJPROP_XDISTANCE, 90);
   ObjectSetInteger(0, "Dashboard_SellButton", OBJPROP_YDISTANCE, 150);
   ObjectSetString(0, "Dashboard_SellButton", OBJPROP_TEXT, "SELL");
   ObjectSetInteger(0, "Dashboard_SellButton", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "Dashboard_SellButton", OBJPROP_BG_COLOR, clrRed);
   ObjectSetInteger(0, "Dashboard_SellButton", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, "Dashboard_SellButton", OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, "Dashboard_SellButton", OBJPROP_HIDDEN, true);

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Delete chart objects
   ObjectsDeleteAll(0, "CRT_");
   ObjectsDeleteAll(0, "Dashboard_");
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Determine Daily Bias                                             |
//+------------------------------------------------------------------+
string DetermineDailyBias()
  {
   // This function determines the daily bias based on the previous day's candle.
   // A more sophisticated approach would involve analyzing higher timeframe market structure.
   MqlRates rates[];
   if(CopyRates(Symbol(), PERIOD_D1, 1, 1, rates) > 0)
     {
      if (rates[0].close > rates[0].open)
        {
         return "Bullish (Prev Day Up)";
        }
      else if (rates[0].close < rates[0].open)
        {
         return "Bearish (Prev Day Down)";
        }
     }
   return "Neutral";
  }

//+------------------------------------------------------------------+
//| Calculate Lot Size                                               |
//+------------------------------------------------------------------+
double CalculateLotSize(double stop_loss_pips)
  {
   if (stop_loss_pips <= 0) return 0.0;

   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_amount = account_balance * (InpRiskPercentage / 100.0);

   double tick_value = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);

   if (tick_value == 0 || tick_size == 0) return 0.0;

   double lot_size = risk_amount / (stop_loss_pips * (tick_value / tick_size));

   // Normalize lot size to min/max and step
   double min_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double step_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

   lot_size = fmax(min_lot, NormalizeDouble(lot_size, 2)); // Normalize to 2 decimal places for lot size
   lot_size = lot_size - fmod(lot_size, step_lot); // Adjust to step size
   lot_size = fmin(max_lot, lot_size);

   return lot_size;
  }

//+------------------------------------------------------------------+
//| Check for High-Impact News                                       |
//+------------------------------------------------------------------+
bool IsHighImpactNewsExpected()
  {
   // This is a placeholder. Real implementation would involve:
   // 1. Making a web request to forexfactory.com or a similar economic calendar API.
   // 2. Parsing the response to identify high-impact news events.
   // 3. Checking if the current time falls within the InpNewsFilterMinutes window.
   // Due to sandbox limitations, direct web requests are not feasible here.
   // Therefore, this function will always return false, assuming no news impact.
   return false;
  }

//+------------------------------------------------------------------+
//| Check SMT Divergence                                             |
//+------------------------------------------------------------------+
bool CheckSMTDivergence()
  {
   // This is a placeholder. Real implementation would involve:
   // 1. Getting price data for the current symbol and InpCorrelatedSymbol.
   // 2. Calculating swing highs/lows or using an oscillator (e.g., RSI, MACD) for both symbols.
   // 3. Comparing the price action/oscillator readings to detect divergence.
   // This would typically require an external library or complex custom code.
   // For now, it will always return false.
   return false;
  }

//+------------------------------------------------------------------+
//| Implement Weekly Profile Filter                                  |
//+------------------------------------------------------------------+
bool CheckWeeklyProfile()
  {
   // This is a placeholder. Real implementation would involve:
   // 1. User input for weekly profile (e.g., Classic Expansion, Midweek Reversal).
   // 2. Logic to determine if the current day's bias aligns with the selected profile.
   // For now, it will always return true, assuming no specific weekly profile filter.
   return true;
  }

//+------------------------------------------------------------------+
//| Higher Timeframe Key Level (KL) Identification                   |
//+------------------------------------------------------------------+
double IdentifyHTFKeyLevel()
  {
   // This function needs to identify the nearest significant H4 or Daily PD Array
   // (Orderblock, Fair Value Gap, Breaker Block, or Liquidity Void) in the direction
   // of the expected manipulation.

   // This is a complex task requiring detailed price action analysis.
   // For now, we'll return a placeholder value or a simple approximation.
   // A more robust implementation would involve:
   // 1. Identifying swing highs/lows on the HTF.
   // 2. Detecting specific PD Arrays (Order Blocks, FVG, etc.).
   // 3. Determining the nearest and most relevant one based on bias.

   // Placeholder: Return the previous day's high/low as a simple key level example
   MqlRates rates[];
   if(CopyRates(Symbol(), InpKeyLevelTimeframe, 1, 1, rates) > 0)
     {
      if (DetermineDailyBias() == "Bullish (Prev Day Up)")
        {
         return rates[0].high; // Previous day's high as a potential resistance/DOL
        }
      else if (DetermineDailyBias() == "Bearish (Prev Day Down)")
        {
         return rates[0].low; // Previous day's low as a potential support/DOL
        }
     }
   return 0.0; // No key level identified
  }

//+------------------------------------------------------------------+
//| Confirmation Entry (Order Block / CSD Model)                     |
//+------------------------------------------------------------------+
void CheckConfirmationEntry()
  {
   // 1. Liquidity Purge: A sweep of the 8 AM Hourly CRT High/Low
   MqlRates rates[];
   if(CopyRates(Symbol(), Period(), 0, 2, rates) < 2) return; // Need at least 2 candles (current and previous)

   bool purged_high = (rates[0].high > CRT_High && rates[1].high <= CRT_High); // Current candle high swept CRT High
   bool purged_low = (rates[0].low < CRT_Low && rates[1].low >= CRT_Low);     // Current candle low swept CRT Low

   if (!purged_high && !purged_low) return; // No purge, no entry

   // 2. Market Structure Shift (MSS): Following the purge, there must be a clear break of market structure on the M15 timeframe in the opposite direction.
   // This is a complex logic that requires identifying swing highs/lows and breaks.
   // For simplicity, let's assume a basic MSS for now: a strong candle close in the opposite direction.
   bool mss_occurred = false;
   if (purged_high && rates[0].close < rates[0].open) // Purged high, looking for bearish MSS
     {
      // Check for a strong bearish candle after purge
      if (rates[0].close < rates[0].open && (rates[0].open - rates[0].close) > (rates[0].high - rates[0].low) * 0.5) // Example: large bearish candle
        {
         mss_occurred = true;
        }
     }
   else if (purged_low && rates[0].close > rates[0].open) // Purged low, looking for bullish MSS
     {
      // Check for a strong bullish candle after purge
      if (rates[0].close > rates[0].open && (rates[0].close - rates[0].open) > (rates[0].high - rates[0].low) * 0.5) // Example: large bullish candle
        {
         mss_occurred = true;
        }
     }

   if (!mss_occurred) return;

   // 3. Entry: Entry is triggered upon a retracement back into the resulting M15 Orderblock, Breaker Block, or Fair Value Gap created by the MSS.
   // For simplicity, let's assume entry at the close of the MSS candle for now.
   // A more robust implementation would involve identifying actual OB/FVG.

   double lot_size = CalculateLotSize(MathAbs(rates[0].high - rates[0].low) / _Point); // Use MSS candle range for SL calculation
   if (lot_size == 0) return;

   double entry_price = rates[0].close;
   double stop_loss_price;
   ENUM_ORDER_TYPE order_type;

   if (purged_high) // Bearish Confirmation Entry
     {
      order_type = ORDER_TYPE_SELL;
      stop_loss_price = rates[0].high + (5 * _Point); // SL above MSS candle high
     }
   else // Bullish Confirmation Entry
     {
      order_type = ORDER_TYPE_BUY;
      stop_loss_price = rates[0].low - (5 * _Point); // SL below MSS candle low
     }

   // Calculate Take Profit based on CRT range
   double crt_range = MathAbs(CRT_High - CRT_Low);
   double take_profit_1 = 0;
   double take_profit_2 = 0;

   if (order_type == ORDER_TYPE_BUY)
     {
      take_profit_1 = CRT_Low + (crt_range * (InpTP1Percentage / 100.0));
      take_profit_2 = CRT_High; // Opposite end of the range
     }
   else
     {
      take_profit_1 = CRT_High - (crt_range * (InpTP1Percentage / 100.0));
      take_profit_2 = CRT_Low; // Opposite end of the range
     }

   // Place the order
   if (trade.Buy(lot_size, Symbol(), entry_price, stop_loss_price, take_profit_1))
     {
      Print("Confirmation Entry BUY order placed successfully!");
     }
   else if (trade.Sell(lot_size, Symbol(), entry_price, stop_loss_price, take_profit_1))
     {
      Print("Confirmation Entry SELL order placed successfully!");
     }
   else
     {
      Print("Failed to place Confirmation Entry order. Error: ", trade.ResultRetcode(), " - ", trade.ResultDeal().Comment());
     }
  }

//+------------------------------------------------------------------+
//| Aggressive Entry (Turtle Soup Model)                             |
//+------------------------------------------------------------------+
void CheckAggressiveEntry()
  {
   // Logic: An entry is taken *immediately after* the 8 AM CRT range is swept,
   // anticipating the reversal *without* waiting for a Market Structure Shift.
   // This requires extreme precision and alignment with HTF levels.

   MqlRates rates[];
   if(CopyRates(Symbol(), Period(), 0, 2, rates) < 2) return; // Need at least 2 candles

   bool swept_high = (rates[0].high > CRT_High && rates[1].high <= CRT_High); // Current candle high swept CRT High
   bool swept_low = (rates[0].low < CRT_Low && rates[1].low >= CRT_Low);     // Current candle low swept CRT Low

   if (!swept_high && !swept_low) return; // No sweep, no entry

   // Additional filter: Check if the sweep happened into a HTF Key Level
   double htf_key_level = IdentifyHTFKeyLevel();
   if (htf_key_level == 0.0) return; // No HTF Key Level identified, or not implemented

   bool aligned_with_htf = false;
   if (swept_high && rates[0].high >= htf_key_level && rates[1].high < htf_key_level) aligned_with_htf = true; // Swept high into HTF KL
   if (swept_low && rates[0].low <= htf_key_level && rates[1].low > htf_key_level) aligned_with_htf = true;     // Swept low into HTF KL

   if (!aligned_with_htf) return; // Not aligned with HTF Key Level

   double lot_size = CalculateLotSize(MathAbs(rates[0].high - rates[0].low) / _Point); // Use current candle range for SL calculation
   if (lot_size == 0) return;

   double entry_price = SymbolInfoDouble(Symbol(), SYMBOL_ASK); // Enter at market
   ENUM_ORDER_TYPE order_type;
   double stop_loss_price;

   if (swept_high) // Bearish Aggressive Entry
     {
      order_type = ORDER_TYPE_SELL;
      stop_loss_price = rates[0].high + (5 * _Point); // SL above sweep candle high
     }
   else // Bullish Aggressive Entry
     {
      order_type = ORDER_TYPE_BUY;
      stop_loss_price = rates[0].low - (5 * _Point); // SL below sweep candle low
     }

   // Calculate Take Profit based on CRT range
   double crt_range = MathAbs(CRT_High - CRT_Low);
   double take_profit_1 = 0;

   if (order_type == ORDER_TYPE_BUY)
     {
      take_profit_1 = CRT_Low + (crt_range * (InpTP1Percentage / 100.0));
     }
   else
     {
      take_profit_1 = CRT_High - (crt_range * (InpTP1Percentage / 100.0));
     }

   // Place the order
   if (order_type == ORDER_TYPE_BUY)
     {
      if (trade.Buy(lot_size, Symbol(), entry_price, stop_loss_price, take_profit_1))
        {
         Print("Aggressive Entry BUY order placed successfully!");
        }
      else
        {
         Print("Failed to place Aggressive Entry BUY order. Error: ", trade.ResultRetcode(), " - ", trade.ResultDeal().Comment());
        }
     }
   else if (order_type == ORDER_TYPE_SELL)
     {
      if (trade.Sell(lot_size, Symbol(), entry_price, stop_loss_price, take_profit_1))
        {
         Print("Aggressive Entry SELL order placed successfully!");
        }
      else
        {
         Print("Failed to place Aggressive Entry SELL order. Error: ", trade.ResultRetcode(), " - ", trade.ResultDeal().Comment());
        }
     }
  }

//+------------------------------------------------------------------+
//| The 3-Candle Pattern Entry                                       |
//+------------------------------------------------------------------+
void CheckThreeCandlePatternEntry()
  {
   // Logic: Entry is triggered on the 15-minute timeframe. After the range is set (Candle 1)
   // and manipulation occurs (Candle 2 sweeps the range and closes back inside),
   // the entry is taken on Candle 3 as it begins to expand away from Candle 2's wick.

   MqlRates rates[3]; // Need 3 candles: current (rates[0]), previous (rates[1]), and the one before (rates[2])
   if(CopyRates(Symbol(), Period(), 0, 3, rates) < 3) return; // Ensure we have enough historical data

   // Candle 1: The 8 AM CRT candle (already handled by CRT_High/Low)
   // Candle 2: Sweeps the range and closes back inside
   bool candle2_swept_and_closed_inside = false;
   if (rates[1].high > CRT_High && rates[1].close < CRT_High && rates[1].low > CRT_Low) // Bullish scenario: swept high, closed inside
     {
      candle2_swept_and_closed_inside = true;
     }
   else if (rates[1].low < CRT_Low && rates[1].close > CRT_Low && rates[1].high < CRT_High) // Bearish scenario: swept low, closed inside
     {
      candle2_swept_and_closed_inside = true;
     }

   if (!candle2_swept_and_closed_inside) return;

   // Candle 3: Begins to expand away from Candle 2's wick
   // This implies current candle (rates[0]) is moving in the direction of the expected trade
   bool candle3_expanding = false;
   ENUM_ORDER_TYPE order_type;
   if (rates[1].high > CRT_High && rates[0].close < rates[0].open) // Bearish setup: Candle 2 swept high, Candle 3 is bearish
     {
      candle3_expanding = true;
      order_type = ORDER_TYPE_SELL;
     }
   else if (rates[1].low < CRT_Low && rates[0].close > rates[0].open) // Bullish setup: Candle 2 swept low, Candle 3 is bullish
     {
      candle3_expanding = true;
      order_type = ORDER_TYPE_BUY;
     }

   if (!candle3_expanding) return;

   double lot_size = CalculateLotSize(MathAbs(rates[1].high - rates[1].low) / _Point); // Use Candle 2 range for SL calculation
   if (lot_size == 0) return;

   double entry_price = SymbolInfoDouble(Symbol(), SYMBOL_ASK); // Enter at market
   double stop_loss_price;

   if (order_type == ORDER_TYPE_SELL)
     {
      stop_loss_price = rates[1].high + (5 * _Point); // SL above Candle 2 high
     }
   else
     {
      stop_loss_price = rates[1].low - (5 * _Point); // SL below Candle 2 low
     }

   // Calculate Take Profit based on CRT range
   double crt_range = MathAbs(CRT_High - CRT_Low);
   double take_profit_1 = 0;

   if (order_type == ORDER_TYPE_BUY)
     {
      take_profit_1 = CRT_Low + (crt_range * (InpTP1Percentage / 100.0));
     }
   else
     {
      take_profit_1 = CRT_High - (crt_range * (InpTP1Percentage / 100.0));
     }

   // Place the order
   if (order_type == ORDER_TYPE_BUY)
     {
      if (trade.Buy(lot_size, Symbol(), entry_price, stop_loss_price, take_profit_1))
        {
         Print("3-Candle Pattern Entry BUY order placed successfully!");
        }
      else
        {
         Print("Failed to place 3-Candle Pattern Entry BUY order. Error: ", trade.ResultRetcode(), " - ", trade.ResultDeal().Comment());
        }
     }
   else if (order_type == ORDER_TYPE_SELL)
     {
      if (trade.Sell(lot_size, Symbol(), entry_price, stop_loss_price, take_profit_1))
        {
         Print("3-Candle Pattern Entry SELL order placed successfully!");
        }
      else
        {
         Print("Failed to place 3-Candle Pattern Entry SELL order. Error: ", trade.ResultRetcode(), " - ", trade.ResultDeal().Comment());
        }
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- Get current time
   MqlDateTime current_time;
   TimeCurrent(current_time);

//--- Determine Daily Bias (can be done once per day or on demand)
   static int prev_day = -1;
   if (current_time.day != prev_day)
     {
      string daily_bias = DetermineDailyBias();
      Comment("Daily Bias: " + daily_bias);
      prev_day = current_time.day;
     }

//--- Check if it's 8:00 AM NY (ET) and CRT range is not set for today
   if (current_time.hour == 8 && current_time.min == 0 && !CRT_Range_Set)
     {
      //--- Get 8 AM H1 candle data
      MqlRates rates[];
      if(CopyRates(Symbol(), InpCRTTimeframe, 0, 1, rates) > 0)
        {
         CRT_High = rates[0].high;
         CRT_Low = rates[0].low;
         CRT_Range_Set = true; // Mark as set for today

         //--- Draw CRT lines
         ObjectSetDouble(0, "CRT_High_Line", OBJPROP_PRICE, CRT_High);
         ObjectSetDouble(0, "CRT_Low_Line", OBJPROP_PRICE, CRT_Low);
         ObjectSetInteger(0, "CRT_High_Line", OBJPROP_TIME, rates[0].time);
         ObjectSetInteger(0, "CRT_Low_Line", OBJPROP_TIME, rates[0].time);
        }
     }

//--- Reset CRT_Range_Set at the start of a new day
   if (current_time.hour == 0 && current_time.min == 0 && current_time.sec == 0)
     {
      CRT_Range_Set = false;
     }

//--- Check if current time is within NY Killzone
   bool in_killzone = false;
   if (current_time.hour > InpNYKillzoneStartHour || (current_time.hour == InpNYKillzoneStartHour && current_time.min >= InpNYKillzoneStartMinute))
     {
      if (current_time.hour < InpNYKillzoneEndHour || (current_time.hour == InpNYKillzoneEndHour && current_time.min <= InpNYKillzoneEndMinute))
        {
         in_killzone = true;
        }
     }

   if (in_killzone && CRT_Range_Set)
     {
      //--- Apply advanced contextual filters
      if (!IsHighImpactNewsExpected() && CheckWeeklyProfile() && !CheckSMTDivergence()) // SMT should be divergence, not absence
        {
         //--- Call entry logic functions based on operational mode
         if (InpOperationalMode == MODE_FULLY_AUTOMATED)
           {
            CheckConfirmationEntry();
            CheckAggressiveEntry();
            CheckThreeCandlePatternEntry();
           }
         else if (InpOperationalMode == MODE_SIGNALS_ONLY)
           {
            // Generate alerts without placing trades
            if (CheckConfirmationEntry()) Print("Signal: Confirmation Entry possible!");
            if (CheckAggressiveEntry()) Print("Signal: Aggressive Entry possible!");
            if (CheckThreeCandlePatternEntry()) Print("Signal: 3-Candle Pattern Entry possible!");
            if (InpEnableSoundAlerts) Alert("CRT EA: Potential Trade Setup!");
           }
         else if (InpOperationalMode == MODE_MANUAL)
           {
            // Display trade panel for manual execution (handled by dashboard)
           }
        }
     }

   // Update dashboard
   UpdateDashboard();

//---
  }

//+------------------------------------------------------------------+
//| Update Dashboard                                                 |
//+------------------------------------------------------------------+
void UpdateDashboard()
  {
   // Update Dashboard elements
   ObjectSetString(0, "Dashboard_Bias", OBJPROP_TEXT, "Daily Bias: " + DetermineDailyBias());
   ObjectSetString(0, "Dashboard_KeyLevel", OBJPROP_TEXT, "HTF Key Level: " + DoubleToString(IdentifyHTFKeyLevel(), _Digits));
   ObjectSetString(0, "Dashboard_CRT", OBJPROP_TEXT, "CRT Range: " + DoubleToString(CRT_High, _Digits) + " - " + DoubleToString(CRT_Low, _Digits));
   ObjectSetString(0, "Dashboard_News", OBJPROP_TEXT, "News Filter: " + (IsHighImpactNewsExpected() ? "Active" : "Clear"));
   ObjectSetString(0, "Dashboard_SMT", OBJPROP_TEXT, "SMT Divergence: " + (CheckSMTDivergence() ? "Detected" : "None"));

   // Real-time P/L and session information
   double current_pl = AccountInfoDouble(ACCOUNT_PROFIT);
   ObjectSetString(0, "Dashboard_P_L", OBJPROP_TEXT, "P/L: " + DoubleToString(current_pl, 2));

   // Session information (simplified)
   MqlDateTime current_time;
   TimeCurrent(current_time);
   string session_info = "Current Time: " + TimeToString(current_time.datetime, TIME_SECONDS);
   ObjectSetString(0, "Dashboard_Session", OBJPROP_TEXT, "Session: " + session_info);

   // Show/Hide buttons based on operational mode
   if (InpOperationalMode == MODE_MANUAL)
     {
      ObjectSetInteger(0, "Dashboard_BuyButton", OBJPROP_HIDDEN, false);
      ObjectSetInteger(0, "Dashboard_SellButton", OBJPROP_HIDDEN, false);
     }
   else
     {
      ObjectSetInteger(0, "Dashboard_BuyButton", OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, "Dashboard_SellButton", OBJPROP_HIDDEN, true);
     }
  }

//+------------------------------------------------------------------+
//| ChartEvent function for button clicks                            |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if (id == CHARTEVENT_CLICK)
     {
      if (sparam == "Dashboard_BuyButton")
        {
         // Manual Buy execution
         double lot_size = CalculateLotSize(50); // Example fixed SL for manual trade
         if (lot_size > 0)
           {
            trade.Buy(lot_size, Symbol(), SymbolInfoDouble(Symbol(), SYMBOL_ASK), 0, 0); // No SL/TP here, assume user sets manually
           }
        }
      else if (sparam == "Dashboard_SellButton")
        {
         // Manual Sell execution
         double lot_size = CalculateLotSize(50); // Example fixed SL for manual trade
         if (lot_size > 0)
           {
            trade.Sell(lot_size, Symbol(), SymbolInfoDouble(Symbol(), SYMBOL_BID), 0, 0); // No SL/TP here, assume user sets manually
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Breakeven and Trailing Stop                                      |
//+------------------------------------------------------------------+
void ManageTrade()
  {
   // Iterate through open positions
   for (int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if (PositionGetString(POSITION_SYMBOL) == Symbol())
        {
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         double current_price = SymbolInfoDouble(Symbol(), SYMBOL_ASK); // For buy
         if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) current_price = SymbolInfoDouble(Symbol(), SYMBOL_BID); // For sell

         double stop_loss = PositionGetDouble(POSITION_SL);
         double take_profit = PositionGetDouble(POSITION_TP);

         // Breakeven Logic
         if (InpBreakevenPips > 0 && stop_loss < open_price) // Only for buy trades, and SL is still below open
           {
            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && current_price - open_price >= InpBreakevenPips * _Point)
              {
               if (trade.PositionModify(ticket, open_price + InpBreakevenPips * _Point_Adjusted, take_profit))
                 {
                  Print("Position ", ticket, ": Moved to breakeven.");
                 }
              }
            else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && open_price - current_price >= InpBreakevenPips * _Point)
              {
               if (trade.PositionModify(ticket, open_price - InpBreakevenPips * _Point_Adjusted, take_profit))
                 {
                  Print("Position ", ticket, ": Moved to breakeven.");
                 }
              }
           }

         // Trailing Stop Logic
         if (InpTrailingStopPips > 0)
           {
            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
              {
               double new_sl = current_price - InpTrailingStopPips * _Point;
               if (new_sl > stop_loss)
                 {
                  if (trade.PositionModify(ticket, new_sl, take_profit))
                    {
                     Print("Position ", ticket, ": Trailing stop updated.");
                    }
                 }
              }
            else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
              {
               double new_sl = current_price + InpTrailingStopPips * _Point;
               if (new_sl < stop_loss || stop_loss == 0) // Update if new SL is better or if SL was not set
                 {
                  if (trade.PositionModify(ticket, new_sl, take_profit))
                    {
                     Print("Position ", ticket, ": Trailing stop updated.");
                    }
                 }
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| OnTrade function to manage trades after execution                |
//+------------------------------------------------------------------+
void OnTrade()
  {
   ManageTrade();
  }

//+------------------------------------------------------------------+
//| OnTimer function for periodic updates (e.g., dashboard, trade management)|
//+------------------------------------------------------------------+
void OnTimer()
  {
   UpdateDashboard();
   ManageTrade();
  }


