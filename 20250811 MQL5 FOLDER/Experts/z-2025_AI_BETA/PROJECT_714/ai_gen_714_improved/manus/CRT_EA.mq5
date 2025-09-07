

#property copyright "Copyright 2025, Manus"
#property link      "https://www.manus.com"
#property version   "1.00"
#property strict

//--- Includes
#include <Trade/Trade.mqh>
#include <Indicators/Indicators.mqh>

//--- Global Objects
CTrade      m_trade;
CIndicators m_indicators;

//--- Enums for CRT Phase
enum ENUM_CRT_PHASE
  {
   CRT_ACCUMULATION,
   CRT_MANIPULATION,
   CRT_DISTRIBUTION,
   CRT_NONE
  };

//--- Enums for Entry Method
enum ENUM_ENTRY_METHOD
  {
   ENTRY_CONFIRMATION,
   ENTRY_AGGRESSIVE,
   ENTRY_THREE_CANDLE,
   ENTRY_NONE
  };

//--- Enum for Trading Sessions
enum ENUM_TRADE_SESSION
  {
   SESSION_SYDNEY,
   SESSION_TOKYO,
   SESSION_FRANKFURT,
   SESSION_LONDON,
   SESSION_NEW_YORK,
   SESSION_GLOBAL
  };

//--- Enums for Daily Bias
enum ENUM_DAILY_BIAS
  {
   BIAS_BULLISH,
   BIAS_BEARISH,
   BIAS_NONE
  };

//--- Enum for Operational Mode (moved outside of class)
enum ENUM_OPERATIONAL_MODE
  {
   MODE_AUTO_TRADING,    // Fully automated trading
   MODE_MANUAL_TRADING,  // Manual trading with alerts/dashboard
   MODE_HYBRID           // Combination of auto and manual
  };

//--- Constants for New York Session and 8 AM candle
#define NY_KILLZONE_START_HOUR_ET    9
#define NY_KILLZONE_START_MINUTE_ET  30
#define NY_KILLZONE_END_HOUR_ET      11
#define NY_KILLZONE_END_MINUTE_ET    0
#define NY_8AM_CANDLE_HOUR_ET        8
#define NY_8AM_CANDLE_MINUTE_ET      0

//--- Input parameters
input ENUM_OPERATIONAL_MODE InpOperationalMode = MODE_AUTO_TRADING; // Operational Mode
input double              InpRiskPercentage = 1.0;             // Risk Percentage per trade (e.g., 1.0 for 1%)
input double              InpMinRiskReward = 1.5;              // Minimum Risk-Reward Ratio
input int                 InpMaxTradesPerDay = 5;              // Maximum trades per day
input int                 InpMaxTradesPerSession = 2;          // Maximum trades per session
input double              InpMaxSpread = 2.0;                  // Maximum allowed spread in pips
input ENUM_TRADE_SESSION  InpTradingSession = SESSION_GLOBAL;  // Trading Session
input bool                InpEnableMondayFilter = false;       // Enable Monday Filter
input bool                InpEnableFridayFilter = false;       // Enable Friday Filter
input bool                InpEnableNewsFilter = false;         // Enable News Filter (requires manual implementation)
input color               InpDashboardThemeColor = clrLightGray; // Dashboard Theme Color
input int                 InpDashboardFontSize = 10;           // Dashboard Font Size
input bool                InpEnableVisualAlerts = true;        // Enable Visual Alerts
input bool                InpEnableAudioAlerts = false;        // Enable Audio Alerts
input string              InpAudioFile = "alert.wav";          // Audio Alert File
input bool                InpEnableEmailAlerts = false;        // Enable Email Alerts
input string              InpEmailSubject = "CRT EA Alert";    // Email Subject
input bool                InpEnablePushNotifications = false;  // Enable Push Notifications
input bool                InpAutoDetectDailyBias = true;       // Auto-detect Daily Bias
input ENUM_DAILY_BIAS     InpManualDailyBias = BIAS_NONE;      // Manual Daily Bias (if auto-detect is false)

//+------------------------------------------------------------------+
//| Helper Functions                                                 |
//+------------------------------------------------------------------+

//--- Get bar data for a specific symbol and timeframe
int GetBars(string symbol, ENUM_TIMEFRAMES timeframe, MqlRates &rates[])
  {
   return CopyRates(symbol, timeframe, 0, Bars(symbol, timeframe), rates);
  }

//--- Calculate candle range
double GetCandleRange(double open, double close, double high, double low)
  {
   return high - low;
  }

//--- Check if a candle is bullish
bool IsBullish(double open, double close)
  {
   return close > open;
  }

//--- Check if a candle is bearish
bool IsBearish(double open, double close)
  {
   return close < open;
  }

//--- Check if a candle is a doji (small body)
bool IsDoji(double open, double close, double high, double low, double tolerance = 0.1)
  {
   return MathAbs(close - open) < (high - low) * tolerance;
  }

//+------------------------------------------------------------------+
//| DrawHorizontalLine: Draws a horizontal line on the chart         |
//+------------------------------------------------------------------+
void DrawHorizontalLine(string name, double price, color clr, ENUM_LINE_STYLE style = STYLE_SOLID, int width = 1)
  {
   ObjectDelete(0, name); // Delete existing object with the same name
   ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
  }

//--- Global variables for CRT High and Low
double g_crt_high = 0.0;
double g_crt_low = 0.0;

//+------------------------------------------------------------------+
//| Advanced_Filters Class (missing class definition)               |
//+------------------------------------------------------------------+
class Advanced_Filters
  {
public:
   //--- Methods
   bool              CheckHighImpactNews();
   bool              CheckVolatilityFilter();
   bool              CheckSpreadFilter();
  };

//+------------------------------------------------------------------+
//| CheckHighImpactNews: Checks for high-impact news events          |
//+------------------------------------------------------------------+
bool Advanced_Filters::CheckHighImpactNews()
  {
   // Placeholder for news filter implementation
   // This would require integration with a news feed or calendar
   return true; // Allow trading for now
  }

//+------------------------------------------------------------------+
//| CheckVolatilityFilter: Checks market volatility conditions       |
//+------------------------------------------------------------------+
bool Advanced_Filters::CheckVolatilityFilter()
  {
   // Placeholder for volatility filter implementation
   return true; // Allow trading for now
  }

//+------------------------------------------------------------------+
//| CheckSpreadFilter: Checks if spread is within acceptable limits  |
//+------------------------------------------------------------------+
bool Advanced_Filters::CheckSpreadFilter()
  {
   double spread = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) * SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double spread_pips = spread / (10 * SymbolInfoDouble(Symbol(), SYMBOL_POINT));
   
   return spread_pips <= InpMaxSpread;
  }

//+------------------------------------------------------------------+
//| CRT_Strategy Class                                               |
//+------------------------------------------------------------------+
class CRT_Strategy
  {
private:
   //--- Variables for CRT phase detection
   ENUM_TIMEFRAMES m_h4_timeframe;
   ENUM_TIMEFRAMES m_m15_timeframe;

public:
   //--- Constructor
                     CRT_Strategy()
     {
      m_h4_timeframe  = PERIOD_H4;
      m_m15_timeframe = PERIOD_M15;
     }

   //--- Methods
   ENUM_CRT_PHASE    DetectCRTPhase();
   void              GetCRTLevels(double &high, double &low, double &mid);
   bool              CheckMultiTimeframeAlignment();
  };

//+------------------------------------------------------------------+
//| DetectCRTPhase: Detects the current CRT phase                    |
//+------------------------------------------------------------------+
ENUM_CRT_PHASE CRT_Strategy::DetectCRTPhase()
  {
   MqlRates h4_rates[];
   MqlRates m15_rates[];

   // Get H4 and M15 bar data
   if (GetBars(Symbol(), m_h4_timeframe, h4_rates) < 3 || GetBars(Symbol(), m_m15_timeframe, m15_rates) < 3)
     {
      Print("Not enough bars for CRT phase detection.");
      return CRT_NONE;
     }

   // Simplified CRT phase detection logic (needs refinement based on detailed CRT rules)
   // This is a basic example and will need to be expanded significantly.

   // Example: Accumulation Phase (e.g., small range candles, indecision)
   if (GetCandleRange(h4_rates[1].open, h4_rates[1].close, h4_rates[1].high, h4_rates[1].low) < (h4_rates[0].high - h4_rates[0].low) * 0.3 &&
       IsDoji(h4_rates[1].open, h4_rates[1].close, h4_rates[1].high, h4_rates[1].low))
     {
      return CRT_ACCUMULATION;
     }

   // Example: Manipulation Phase (e.g., false breakout, wick extensions)
   if (h4_rates[1].low < h4_rates[2].low && h4_rates[1].close > h4_rates[2].low &&
       GetCandleRange(h4_rates[1].open, h4_rates[1].close, h4_rates[1].high, h4_rates[1].low) > (h4_rates[0].high - h4_rates[0].low) * 0.7)
     {
      return CRT_MANIPULATION;
     }

   // Example: Distribution Phase (e.g., large range candles, strong reversal)
   if (h4_rates[1].high > h4_rates[2].high && h4_rates[1].close < h4_rates[2].high &&
       IsBearish(h4_rates[1].open, h4_rates[1].close))
     {
      return CRT_DISTRIBUTION;
     }

   return CRT_NONE;
  }

//+------------------------------------------------------------------+
//| GetCRTLevels: Calculates and returns CRT range levels            |
//+------------------------------------------------------------------+
void CRT_Strategy::GetCRTLevels(double &high, double &low, double &mid)
  {
   MqlRates h4_rates[];
   if (GetBars(Symbol(), m_h4_timeframe, h4_rates) < 2)
     {
      Print("Not enough H4 bars for CRT level calculation.");
      high = 0.0;
      low  = 0.0;
      mid  = 0.0;
      return;
     }

   // Simplified CRT level calculation (needs refinement)
   // For now, let\"s use the previous H4 candle\"s high, low, and midpoint.
   high = h4_rates[1].high;
   low  = h4_rates[1].low;
   mid  = (h4_rates[1].high + h4_rates[1].low) / 2.0;
  }

//+------------------------------------------------------------------+
//| CheckMultiTimeframeAlignment: Verifies alignment across H4 and M15 |
//+------------------------------------------------------------------+
bool CRT_Strategy::CheckMultiTimeframeAlignment()
  {
   // This function will check if the CRT patterns identified on H4 are aligned
   // with price action or patterns on the M15 timeframe. This will require
   // more detailed CRT pattern definitions.
   // For now, a placeholder returning true.
   return true;
  }


//+------------------------------------------------------------------+
//| CRT_Core Class                                                   |
//+------------------------------------------------------------------+
class CRT_Core
  {
private:
   ENUM_DAILY_BIAS m_daily_bias;

public:
   //--- Constructor
                     CRT_Core()
     {
      m_daily_bias = BIAS_NONE;
     }

   //--- Methods
   void              DetermineDailyBias(bool auto_detect, ENUM_DAILY_BIAS manual_bias);
   void              IdentifyHTFKeyLevel();
   void              CaptureTimedRange(datetime ny_8am_close_time);
   bool              CheckEntryConditions();
  };

//+------------------------------------------------------------------+
//| DetermineDailyBias: Determines the daily bias (bullish/bearish)  |
//+------------------------------------------------------------------+
void CRT_Core::DetermineDailyBias(bool auto_detect, ENUM_DAILY_BIAS manual_bias)
  {
   if (auto_detect)
     {
      // Implement sophisticated daily bias detection logic here.
      // This could involve analyzing higher timeframe (e.g., Daily, H4) candle closes,
      // market structure, or other indicators.
      // For now, a simplified example:
      MqlRates daily_rates[];
      if (GetBars(Symbol(), PERIOD_D1, daily_rates) < 2)
        {
         Print("Not enough daily bars to determine bias.");
         m_daily_bias = BIAS_NONE;
         return;
        }

      if (IsBullish(daily_rates[1].open, daily_rates[1].close))
        {
         m_daily_bias = BIAS_BULLISH;
         Print("Daily Bias: Bullish");
        }
      else if (IsBearish(daily_rates[1].open, daily_rates[1].close))
        {
         m_daily_bias = BIAS_BEARISH;
         Print("Daily Bias: Bearish");
        }
      else
        {
         m_daily_bias = BIAS_NONE;
         Print("Daily Bias: Neutral");
        }
     }
   else
     {
      m_daily_bias = manual_bias;
      Print("Manual Daily Bias: ", EnumToString(m_daily_bias));
     }
  }

//+------------------------------------------------------------------+
//| IdentifyHTFKeyLevel: Identifies nearest significant HTF PD Array |
//+------------------------------------------------------------------+
void CRT_Core::IdentifyHTFKeyLevel()
  {
   // This function needs to identify and display the nearest significant
   // H4 or Daily PD Array (Orderblock, Fair Value Gap, Breaker Block, or Liquidity Void)
   // in the direction of the expected manipulation.
   // This is a complex task and will require detailed implementation for each PD Array type.

   Print("Identifying Higher Timeframe Key Level...");

   MqlRates h4_rates[];
   if (GetBars(Symbol(), PERIOD_H4, h4_rates) < 3)
     {
      Print("Not enough H4 bars to identify HTF Key Level.");
      return;
     }

   // --- Basic Fair Value Gap (FVG) Detection (Bullish Example) ---
   // A bullish FVG is formed when the low of candle[1] is higher than the high of candle[3]
   // The FVG range is between the high of candle[1] and the low of candle[3]
   // (Assuming h4_rates[0] is current, h4_rates[1] is previous, h4_rates[2] is two candles ago)

   // Check for Bullish FVG
   if (h4_rates[2].low > h4_rates[0].high) // Check if there\"s a gap between candle[2] low and candle[0] high
     {
      double fvg_top = h4_rates[2].low;
      double fvg_bottom = h4_rates[0].high;

      // Ensure it\"s a valid gap (top > bottom)
      if (fvg_top > fvg_bottom)
        {
         Print("Detected Bullish H4 FVG: ", fvg_bottom, " - ", fvg_top);
         // TODO: Draw FVG on chart (e.g., using OBJ_RECTANGLE)
        }
     }

   // --- Basic Fair Value Gap (FVG) Detection (Bearish Example) ---
   // A bearish FVG is formed when the high of candle[1] is lower than the low of candle[3]
   // The FVG range is between the low of candle[1] and the high of candle[3]

   // Check for Bearish FVG
   if (h4_rates[2].high < h4_rates[0].low) // Check if there\"s a gap between candle[2] high and candle[0] low
     {
      double fvg_top = h4_rates[0].low;
      double fvg_bottom = h4_rates[2].high;

      // Ensure it\"s a valid gap (top > bottom)
      if (fvg_top > fvg_bottom)
        {
         Print("Detected Bearish H4 FVG: ", fvg_bottom, " - ", fvg_top);
         // TODO: Draw FVG on chart (e.g., using OBJ_RECTANGLE)
        }
     }

   // TODO: Implement logic for Orderblock, Breaker Block, Liquidity Void
  }

//+------------------------------------------------------------------+
//| CaptureTimedRange: Captures the High and Low of the 8 AM NY ET   |
//|                    1-Hour candle and draws them on the chart     |
//+------------------------------------------------------------------+
void CRT_Core::CaptureTimedRange(datetime ny_8am_close_time)
  {
   // Convert NY 8 AM ET to GMT
   // Assuming NY ET is GMT-4 during DST and GMT-5 during standard time.
   // This needs to be dynamic based on current date to check for DST.
   // For simplicity, let\"s assume a fixed offset for now. A more robust solution
   // would involve checking daylight saving rules.
   int ny_et_gmt_offset = -4; // Example: GMT-4 for New York ET (during DST)

   // Convert 8 AM NY ET to GMT time
   datetime eight_am_ny_et_gmt = ny_8am_close_time - ny_et_gmt_offset * 3600;

   // Convert GMT time to broker server time
   // We need the broker\"s GMT offset, which should be determined by Session_Manager::AdjustGMT()
   int broker_gmt_offset = g_session_manager.m_gmt_offset; // Assuming this is populated
   datetime eight_am_broker_time = eight_am_ny_et_gmt + broker_gmt_offset * 3600;

   MqlRates h1_rates[];
   // Get the 1-Hour candle data for the 8 AM NY ET candle (which closes at 9 AM NY ET)
   // We need to find the candle that *closes* at eight_am_broker_time.

   if (GetBars(Symbol(), PERIOD_H1, h1_rates) < 2)
     {
      Print("Not enough H1 bars to capture timed range.");
      return;
     }

   // Find the 8 AM NY ET candle (which closes at 9 AM NY ET)
   // Iterate through H1 candles to find the one that closed at the target time.
   // This is a simplified approach. A more accurate way would be to calculate the bar index.
   datetime target_candle_open_time = eight_am_broker_time - 3600; // 1 hour before close

   int target_bar_index = -1;
   for (int i = 0; i < ArraySize(h1_rates); i++)
     {
      if (h1_rates[i].time == target_candle_open_time)
        {
         target_bar_index = i;
         break;
        }
     }

   if (target_bar_index != -1)
     {
      double crt_high = h1_rates[target_bar_index].high;
      double crt_low  = h1_rates[target_bar_index].low;

      Print("8 AM NY ET H1 Candle High: ", crt_high, ", Low: ", crt_low);

      // Draw these lines on the chart
      DrawHorizontalLine("CRT_High_Line", crt_high, clrBlue, STYLE_DOT, 2);
      DrawHorizontalLine("CRT_Low_Line", crt_low, clrRed, STYLE_DOT, 2);
      // Store these values globally
      g_crt_high = crt_high;
      g_crt_low  = crt_low;
     }
   else
     {
      Print("Could not find the 8 AM NY ET H1 candle.");
     }
  }

//+------------------------------------------------------------------+
//| CheckEntryConditions: Checks for entry conditions based on bias  |
//+------------------------------------------------------------------+
bool CRT_Core::CheckEntryConditions()
  {
   // This function will orchestrate the checking of entry conditions
   // based on the determined daily bias and other factors.
   // For now, a placeholder.
   Print("Checking Entry Conditions...");

   // Example: If bullish bias, check for buy entry conditions
   if (m_daily_bias == BIAS_BULLISH)
     {
      // Check for Confirmation Entry (Order Block / CSD Model)
      if (g_entry_methods.CheckConfirmationEntry())
        {
         Print("Confirmation Buy Entry detected!");
         return true;
        }
      // Check for Aggressive Entry (Turtle Soup Model)
      if (g_entry_methods.CheckAggressiveEntry())
        {
         Print("Aggressive Buy Entry detected!");
         return true;
        }
      // Check for 3-Candle Pattern Entry
      if (g_entry_methods.CheckThreeCandleEntry())
        {
         Print("3-Candle Buy Entry detected!");
         return true;
        }
     }
   // Example: If bearish bias, check for sell entry conditions
   else if (m_daily_bias == BIAS_BEARISH)
     {
      // Check for Confirmation Entry (Order Block / CSD Model)
      if (g_entry_methods.CheckConfirmationEntry())
        {
         Print("Confirmation Sell Entry detected!");
         return true;
        }
      // Check for Aggressive Entry (Turtle Soup Model)
      if (g_entry_methods.CheckAggressiveEntry())
        {
         Print("Aggressive Sell Entry detected!");
         return true;
        }
      // Check for 3-Candle Pattern Entry
      if (g_entry_methods.CheckThreeCandleEntry())
        {
         Print("3-Candle Sell Entry detected!");
         return true;
        }
     }

   return false;
  }


//+------------------------------------------------------------------+
//| Entry_Methods Class                                              |
//+------------------------------------------------------------------+
class Entry_Methods
  {
public:
   //--- Methods
   bool              CheckConfirmationEntry();
   bool              CheckAggressiveEntry();
   bool              CheckThreeCandleEntry();
  };

//+------------------------------------------------------------------+
//| CheckConfirmationEntry: Implements Confirmation Entry logic      |
//+------------------------------------------------------------------+
bool Entry_Methods::CheckConfirmationEntry()
  {
   // This is the primary entry model. It must follow a strict three-part sequence:
   // 1. Liquidity Purge: A sweep of the 8 AM Hourly CRT High/Low must occur,
   //    ideally into the pre-identified HTF Key Level from Step 2.
   // 2. Market Structure Shift (MSS): Following the purge, there must be a clear
   //    break of market structure on the M15 timeframe in the opposite direction.
   // 3. Entry: Entry is triggered upon a retracement back into the resulting
   //    M15 Orderblock, Breaker Block, or Fair Value Gap created by the MSS.

   // Placeholder for now. This will be a complex implementation.
   Print("Checking Confirmation Entry conditions...");

   // Example: Check for sweep of CRT High/Low
   MqlRates m15_rates[];
   if (GetBars(Symbol(), PERIOD_M15, m15_rates) < 2)
     {
      return false;
     }

   bool liquidity_purged = false;
   // Check for sweep of CRT High (for potential sell setup)
   if (g_crt_high != 0.0 && m15_rates[0].high > g_crt_high && m15_rates[0].close < g_crt_high)
     {
      Print("Liquidity purged above CRT High.");
      liquidity_purged = true;
     }
   // Check for sweep of CRT Low (for potential buy setup)
   else if (g_crt_low != 0.0 && m15_rates[0].low < g_crt_low && m15_rates[0].close > g_crt_low)
     {
      Print("Liquidity purged below CRT Low.");
      liquidity_purged = true;
     }

   if (!liquidity_purged)
     {
      return false;
     }

   // TODO: Implement Market Structure Shift (MSS) detection on M15
   // TODO: Implement retracement into M15 Orderblock, Breaker Block, or Fair Value Gap

   return false; // Default return
  }

//+------------------------------------------------------------------+
//| CheckAggressiveEntry: Implements Aggressive Entry (Turtle Soup)  |
//+------------------------------------------------------------------+
bool Entry_Methods::CheckAggressiveEntry()
  {
   // This entry model is based on the Turtle Soup pattern, where price
   // sweeps a previous high/low and immediately reverses.

   Print("Checking Aggressive Entry conditions (Turtle Soup)...");

   MqlRates rates[];
   if (GetBars(Symbol(), Period(), rates) < 5)
     {
      Print("Not enough bars for Aggressive Entry.");
      return false;
     }

   // Turtle Soup Buy: Price makes a new 4-period low, then closes above the previous 4-period low.
   // Turtle Soup Sell: Price makes a new 4-period high, then closes below the previous 4-period high.

   // Simplified logic for demonstration:
   // Check for a false breakout below a recent low (for buy setup)
   if (rates[1].low < iLowest(Symbol(), Period(), MODE_LOW, 4, 2) && rates[0].close > rates[1].low)
     {
      return true; // Potential Buy signal
     }

   // Check for a false breakout above a recent high (for sell setup)
   if (rates[1].high > iHighest(Symbol(), Period(), MODE_HIGH, 4, 2) && rates[0].close < rates[1].high)
     {
      return true; // Potential Sell signal
     }

   return false;
  }

//+------------------------------------------------------------------+
//| CheckThreeCandleEntry: Implements 3-Candle Pattern Entry logic   |
//+------------------------------------------------------------------+
bool Entry_Methods::CheckThreeCandleEntry()
  {
   Print("Checking 3-Candle Pattern Entry conditions...");

   MqlRates rates[];
   if (GetBars(Symbol(), Period(), rates) < 3)
     {
      Print("Not enough bars for 3-Candle Pattern Entry.");
      return false;
     }

   // Buy setup: three consecutive bullish candles
   if (IsBullish(rates[2].open, rates[2].close) &&
       IsBullish(rates[1].open, rates[1].close) &&
       IsBullish(rates[0].open, rates[0].close))
     {
      return true;
     }

   // Sell setup: three consecutive bearish candles
   if (IsBearish(rates[2].open, rates[2].close) &&
       IsBearish(rates[1].open, rates[1].close) &&
       IsBearish(rates[0].open, rates[0].close))
     {
      return true;
     }

   return false;
  }


//+------------------------------------------------------------------+
//| Risk_Management Class                                            |
//+------------------------------------------------------------------+
class Risk_Management
  {
public:
   //--- Methods
   double            CalculatePositionSize(double stop_loss_pips);
   void              SetStopLossTakeProfit(double &sl_price, double &tp_price, double entry_price, ENUM_ORDER_TYPE order_type, double crt_high, double crt_low);
   bool              CheckTradeLimits();
   bool              PerformMarginCheck(double lot_size);
   void              Breakeven(long ticket, double breakeven_pips);
   void              TrailingStop(long ticket, double trailing_pips);
  };

//+------------------------------------------------------------------+
//| CalculatePositionSize: Calculates position size based on risk %  |
//+------------------------------------------------------------------+
double Risk_Management::CalculatePositionSize(double stop_loss_pips)
  {
   if (stop_loss_pips <= 0) return 0.0;

   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_amount = account_balance * (InpRiskPercentage / 100.0);

   double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double tick_value = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);

   // Convert stop loss from pips to points
   double stop_loss_points = stop_loss_pips * _Point / tick_size;

   if (stop_loss_points == 0) return 0.0;

   // Calculate lot size
   double lot_size = risk_amount / (stop_loss_points * tick_value);

   // Normalize lot size to contract size and step
   double min_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

   lot_size = NormalizeDouble(lot_size, 2); // Normalize to 2 decimal places for lot size

   // Adjust lot size to be a multiple of lot_step and within min/max limits
   lot_size = fmax(min_lot, floor(lot_size / lot_step) * lot_step);
   lot_size = fmin(max_lot, lot_size);

   return lot_size;
  }

//+------------------------------------------------------------------+
//| SetStopLossTakeProfit: Sets SL/TP based on CRT levels and R:R    |
//+------------------------------------------------------------------+
void Risk_Management::SetStopLossTakeProfit(double &sl_price, double &tp_price, double entry_price, ENUM_ORDER_TYPE order_type, double crt_high, double crt_low)
  {
   double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);

   if (order_type == ORDER_TYPE_BUY)
     {
      // For Buy: SL below CRT Low, TP based on R:R from SL
      sl_price = crt_low;
      double stop_loss_pips = (entry_price - sl_price) / point;
      tp_price = entry_price + (stop_loss_pips * InpMinRiskReward * point);
     }
   else if (order_type == ORDER_TYPE_SELL)
     {
      // For Sell: SL above CRT High, TP based on R:R from SL
      sl_price = crt_high;
      double stop_loss_pips = (sl_price - entry_price) / point;
      tp_price = entry_price - (stop_loss_pips * InpMinRiskReward * point);
     }
   else
     {
      sl_price = 0.0;
      tp_price = 0.0;
     }
  }

//+------------------------------------------------------------------+
//| CheckTradeLimits: Checks if daily/session trade limits are met   |
//+------------------------------------------------------------------+
bool Risk_Management::CheckTradeLimits()
  {
   // This function would check the number of trades taken today/this session
   // against the InpMaxTradesPerDay and InpMaxTradesPerSession inputs.
   // For now, a placeholder.
   return true;
  }

//+------------------------------------------------------------------+
//| PerformMarginCheck: Checks if there is sufficient margin         |
//+------------------------------------------------------------------+
bool Risk_Management::PerformMarginCheck(double lot_size)
  {
   // This function would check if there is enough free margin to open a trade
   // with the given lot size.
   // For now, a placeholder.
   return true;
  }


//+------------------------------------------------------------------+
//| Session_Manager Class                                            |
//+------------------------------------------------------------------+
class Session_Manager
  {
public:
   int               m_gmt_offset; // To store the broker's GMT offset

public:
   //--- Constructor
                     Session_Manager()
     {
      m_gmt_offset = 0; // Initialize
     }

   //--- Methods
   void              AdjustGMT();
   bool              IsTradingSessionActive(ENUM_TRADE_SESSION session);
  };

//+------------------------------------------------------------------+
//| AdjustGMT: Adjusts for broker's GMT offset                       |
//+------------------------------------------------------------------+
void Session_Manager::AdjustGMT()
  {
   // This function determines the broker's GMT offset.
   // It's crucial for accurate session timing.
   m_gmt_offset = (int) (TimeCurrent() - TimeGMT()) / 3600;
   Print("Broker GMT Offset: ", m_gmt_offset);
  }

//+------------------------------------------------------------------+
//| IsTradingSessionActive: Checks if a trading session is active    |
//+------------------------------------------------------------------+
bool Session_Manager::IsTradingSessionActive(ENUM_TRADE_SESSION session)
  {
   datetime current_time = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(current_time, dt);
   int hour = dt.hour;
   int minute = dt.min;

   switch (session)
     {
      case SESSION_SYDNEY:
         // Example: Sydney session (22:00 - 07:00 GMT+10, adjust to broker time)
         // This needs to be dynamic based on broker's GMT offset and DST.
         return true; // Placeholder
      case SESSION_TOKYO:
         // Example: Tokyo session (00:00 - 09:00 GMT+9, adjust to broker time)
         return true; // Placeholder
      case SESSION_FRANKFURT:
         // Example: Frankfurt session (07:00 - 16:00 GMT+1, adjust to broker time)
         return true; // Placeholder
      case SESSION_LONDON:
         // Example: London session (08:00 - 17:00 GMT+1, adjust to broker time)
         return true; // Placeholder
      case SESSION_NEW_YORK:
        {
         // Example: New York session (13:00 - 22:00 GMT-4, adjust to broker time)
         // For the 9 AM CRT model, we are specifically interested in the NY Killzone
         // which is 9:30 AM to 11:00 AM NY ET.
         // Convert NY ET to broker time using m_gmt_offset.
         int ny_killzone_start_hour_broker = NY_KILLZONE_START_HOUR_ET - m_gmt_offset;
         int ny_killzone_start_minute_broker = NY_KILLZONE_START_MINUTE_ET;
         int ny_killzone_end_hour_broker = NY_KILLZONE_END_HOUR_ET - m_gmt_offset;
         int ny_killzone_end_minute_broker = NY_KILLZONE_END_MINUTE_ET;

         // Adjust for hour wrap-around
         if (ny_killzone_start_hour_broker >= 24) ny_killzone_start_hour_broker -= 24;
         if (ny_killzone_start_hour_broker < 0) ny_killzone_start_hour_broker += 24;
         if (ny_killzone_end_hour_broker >= 24) ny_killzone_end_hour_broker -= 24;
         if (ny_killzone_end_hour_broker < 0) ny_killzone_end_hour_broker += 24;

         if (hour >= ny_killzone_start_hour_broker && hour <= ny_killzone_end_hour_broker)
           {
            if (hour == ny_killzone_start_hour_broker && minute < ny_killzone_start_minute_broker) return false;
            if (hour == ny_killzone_end_hour_broker && minute > ny_killzone_end_minute_broker) return false;
            return true;
           }
         return false;
        }
      case SESSION_GLOBAL:
         return true; // Always active
     }
   return false;
  }


//+------------------------------------------------------------------+
//| Filter_System Class                                              |
//+------------------------------------------------------------------+
class Filter_System
  {
public:
   //--- Methods
   bool              ApplyTechnicalFilters();
   bool              ApplySessionFilters();
  };

//+------------------------------------------------------------------+
//| ApplyTechnicalFilters: Applies technical analysis filters        |
//+------------------------------------------------------------------+
bool Filter_System::ApplyTechnicalFilters()
  {
   // This function would apply various technical filters (e.g., moving averages,
   // RSI, stochastic, etc.) to confirm trade signals or avoid bad market conditions.
   // For now, a placeholder.
   return true;
  }

//+------------------------------------------------------------------+
//| ApplySessionFilters: Applies session-based filters               |
//+------------------------------------------------------------------+
bool Filter_System::ApplySessionFilters()
  {
   // This function would apply filters based on trading sessions, news events,
   // or other time-based criteria.
   if (!g_session_manager.IsTradingSessionActive(InpTradingSession))
     {
      Print("Trading session is not active.");
      return false;
     }

   // Check for Monday/Friday filters
   MqlDateTime dt_current;
   TimeToStruct(TimeCurrent(), dt_current);
   if (InpEnableMondayFilter && dt_current.day_of_week == 1) // 1 = Monday
     {
      Print("Monday filter active. No trades on Monday.");
      return false;
     }
   if (InpEnableFridayFilter && dt_current.day_of_week == 5) // 5 = Friday
     {
      Print("Friday filter active. No trades on Friday.");
      return false;
     }

   // Check for high-impact news
   if (!g_advanced_filters.CheckHighImpactNews())
     {
      Print("High-impact news detected. No trades.");
      return false;
     }

   return true;
  }


//+------------------------------------------------------------------+
//| Operational_Modes Class                                          |
//+------------------------------------------------------------------+
class Operational_Modes
  {
private:
   ENUM_OPERATIONAL_MODE m_current_mode;

public:
   //--- Constructor
                     Operational_Modes()
     {
      m_current_mode = MODE_AUTO_TRADING; // Default mode
     }

   //--- Methods
   void              SetAutoTradingMode();
   void              SetManualTradingMode();
   void              SetHybridMode();
   ENUM_OPERATIONAL_MODE GetCurrentMode() { return m_current_mode; }
  };

//+------------------------------------------------------------------+
//| SetAutoTradingMode: Sets the EA to fully automated trading mode  |
//+------------------------------------------------------------------+
void Operational_Modes::SetAutoTradingMode()
  {
   m_current_mode = MODE_AUTO_TRADING;
   Print("Operational Mode set to: Auto Trading");
  }

//+------------------------------------------------------------------+
//| SetManualTradingMode: Sets the EA to manual trading mode         |
//+------------------------------------------------------------------+
void Operational_Modes::SetManualTradingMode()
  {
   m_current_mode = MODE_MANUAL_TRADING;
   Print("Operational Mode set to: Manual Trading");
  }

//+------------------------------------------------------------------+
//| SetHybridMode: Sets the EA to hybrid trading mode                |
//+------------------------------------------------------------------+
void Operational_Modes::SetHybridMode()
  {
   m_current_mode = MODE_HYBRID;
   Print("Operational Mode set to: Hybrid Trading");
  }


//+------------------------------------------------------------------+
//| Dashboard_Manager Class                                          |
//+------------------------------------------------------------------+
class Dashboard_Manager
  {
private:
   string            m_dashboard_name;

public:
   //--- Constructor
                     Dashboard_Manager()
     {
      m_dashboard_name = "CRT_EA_Dashboard";
     }

   //--- Methods
   void              CreateDashboard();
   void              DeleteDashboard();
   void              UpdateDashboard(ENUM_CRT_PHASE current_crt_phase, double win_rate, double profit_loss, int trades_count, double risk_exposure);
   void              DisplayCRTViz(ENUM_CRT_PHASE current_crt_phase);
   void              DisplayStats(double win_rate, double profit_loss, int trades_count, double risk_exposure);
   void              DisplaySignals(string signal_text, color signal_color);
   void              ApplyCustomization();
  };

//+------------------------------------------------------------------+
//| CreateDashboard: Creates the visual dashboard on the chart       |
//+------------------------------------------------------------------+
void Dashboard_Manager::CreateDashboard()
  {
   // This function will create graphical objects on the chart to form the dashboard.
   // This is a complex task involving many graphical objects.
   // For now, a placeholder.
   Print("Creating Dashboard...");
   // TODO: Implement actual dashboard creation using graphical objects.

   // Example: Create a button for Hybrid mode (Confirm Trade)
   ObjectCreate(0, "ConfirmTradeButton", OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, "ConfirmTradeButton", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "ConfirmTradeButton", OBJPROP_YDISTANCE, 100);
   ObjectSetInteger(0, "ConfirmTradeButton", OBJPROP_XSIZE, 100);
   ObjectSetInteger(0, "ConfirmTradeButton", OBJPROP_YSIZE, 20);
   ObjectSetString(0, "ConfirmTradeButton", OBJPROP_TEXT, "Confirm Trade");
   ObjectSetInteger(0, "ConfirmTradeButton", OBJPROP_COLOR, clrGreen);
   ObjectSetInteger(0, "ConfirmTradeButton", OBJPROP_BGCOLOR, clrDarkGreen);
   ObjectSetInteger(0, "ConfirmTradeButton", OBJPROP_BORDER_COLOR, clrDarkGreen);
   ObjectSetInteger(0, "ConfirmTradeButton", OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, "ConfirmTradeButton", OBJPROP_ZORDER, 0);
   ObjectSetInteger(0, "ConfirmTradeButton", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "ConfirmTradeButton", OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, "ConfirmTradeButton", OBJPROP_FONTSIZE, InpDashboardFontSize);
   ObjectSetString(0, "ConfirmTradeButton", OBJPROP_FONT, "Arial");

   // Initially hide the button, show only in Hybrid mode
   ObjectSetInteger(0, "ConfirmTradeButton", OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
//| DeleteDashboard: Deletes the visual dashboard from the chart     |
//+------------------------------------------------------------------+
void Dashboard_Manager::DeleteDashboard()
  {
   // This function will delete all graphical objects related to the dashboard.
   Print("Deleting Dashboard...");
   ObjectsDeleteAll(0, -1, -1);
   ObjectDelete(0, "ConfirmTradeButton");
  }

//+------------------------------------------------------------------+
//| UpdateDashboard: Updates the information displayed on the dashboard |
//+------------------------------------------------------------------+
void Dashboard_Manager::UpdateDashboard(ENUM_CRT_PHASE current_crt_phase, double win_rate, double profit_loss, int trades_count, double risk_exposure)
  {
   // This function will update the text and visual elements of the dashboard.
   Print("Updating Dashboard...");
   DisplayCRTViz(current_crt_phase);
   DisplayStats(win_rate, profit_loss, trades_count, risk_exposure);

   // Update button visibility based on operational mode
   if (g_operational_modes.GetCurrentMode() == MODE_HYBRID)
     {
      ObjectSetInteger(0, "ConfirmTradeButton", OBJPROP_HIDDEN, false);
     }
   else
     {
      ObjectSetInteger(0, "ConfirmTradeButton", OBJPROP_HIDDEN, true);
     }
   // TODO: Update other dashboard elements as needed.
  }

//+------------------------------------------------------------------+
//| DisplayCRTViz: Displays the current CRT phase visually           |
//+------------------------------------------------------------------+
void Dashboard_Manager::DisplayCRTViz(ENUM_CRT_PHASE current_crt_phase)
  {
   string phase_text = "CRT Phase: ";
   color phase_color = clrWhite;

   switch (current_crt_phase)
     {
      case CRT_ACCUMULATION:
         phase_text += "Accumulation";
         phase_color = clrLightBlue;
         break;
      case CRT_MANIPULATION:
         phase_text += "Manipulation";
         phase_color = clrOrange;
         break;
      case CRT_DISTRIBUTION:
         phase_text += "Distribution";
         phase_color = clrLightCoral;
         break;
      case CRT_NONE:
         phase_text += "N/A";
         phase_color = clrGray;
         break;
     }
   Print(phase_text);
   // TODO: Display this text on the dashboard using a text object.
  }

//+------------------------------------------------------------------+
//| DisplayStats: Displays trading statistics on the dashboard       |
//+------------------------------------------------------------------+
void Dashboard_Manager::DisplayStats(double win_rate, double profit_loss, int trades_count, double risk_exposure)
  {
   Print("Win Rate: ", DoubleToString(win_rate, 2), "%");
   Print("P/L: ", DoubleToString(profit_loss, 2));
   Print("Trades: ", trades_count);
   Print("Risk Exposure: ", DoubleToString(risk_exposure, 2), "%");
   // TODO: Display these stats on the dashboard using text objects.
  }

//+------------------------------------------------------------------+
//| DisplaySignals: Displays trade signals on the dashboard          |
//+------------------------------------------------------------------+
void Dashboard_Manager::DisplaySignals(string signal_text, color signal_color)
  {
   Print("Signal: ", signal_text);
   // TODO: Display this signal text on the dashboard using a text object.
  }

//+------------------------------------------------------------------+
//| ApplyCustomization: Applies user-defined dashboard customization |
//+------------------------------------------------------------------+
void Dashboard_Manager::ApplyCustomization()
  {
   Print("Applying Dashboard Customization...");
   // TODO: Apply InpDashboardThemeColor and InpDashboardFontSize to dashboard objects.
  }


//+------------------------------------------------------------------+
//| Notification_System Class                                        |
//+------------------------------------------------------------------+
class Notification_System
  {
public:
   //--- Methods
   void              SendVisualAlert(string message);
   void              PlayAudioAlert(string file_name);
   void              SendEmailNotification(string subject, string message);
   void              SendPushNotification(string message);
  };

//+------------------------------------------------------------------+
//| SendVisualAlert: Displays a visual alert on the chart            |
//+------------------------------------------------------------------+
void Notification_System::SendVisualAlert(string message)
  {
   Print("Visual Alert: ", message);
   // TODO: Implement visual alert (e.g., pop-up window, text on chart).
  }

//+------------------------------------------------------------------+
//| PlayAudioAlert: Plays an audio alert                             |
//+------------------------------------------------------------------+
void Notification_System::PlayAudioAlert(string file_name)
  {
   Print("Playing Audio Alert: ", file_name);
   //PlaySound(file_name);
  }

//+------------------------------------------------------------------+
//| SendEmailNotification: Sends an email notification               |
//+------------------------------------------------------------------+
void Notification_System::SendEmailNotification(string subject, string message)
  {
   Print("Sending Email: ", subject, " - ", message);
   //SendMail(subject, message);
  }

//+------------------------------------------------------------------+
//| SendPushNotification: Sends a push notification                  |
//+------------------------------------------------------------------+
void Notification_System::SendPushNotification(string message)
  {
   Print("Sending Push Notification: ", message);
   //SendNotification(message);
  }


//--- Expert Advisor global variables and instances
CRT_Strategy      g_crt_strategy;
Entry_Methods     g_entry_methods;
Risk_Management   g_risk_management;
Session_Manager   g_session_manager;
Filter_System     g_filter_system;
Operational_Modes g_operational_modes;
Dashboard_Manager g_dashboard_manager;
Notification_System g_notification_system;
CRT_Core          g_crt_core;
Advanced_Filters  g_advanced_filters;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- Initialize trade object
   m_trade.SetExpertMagicNumber(12345);

   //--- Adjust GMT offset
   g_session_manager.AdjustGMT();

   //--- Set operational mode based on input
   switch (InpOperationalMode)
     {
      case MODE_AUTO_TRADING:
         g_operational_modes.SetAutoTradingMode();
         break;
      case MODE_MANUAL_TRADING:
         g_operational_modes.SetManualTradingMode();
         break;
      case MODE_HYBRID:
         g_operational_modes.SetHybridMode();
         break;
     }

   //--- Create and customize dashboard
   g_dashboard_manager.CreateDashboard();
   g_dashboard_manager.ApplyCustomization();

   //--- Set initial daily bias
   g_crt_core.DetermineDailyBias(InpAutoDetectDailyBias, InpManualDailyBias);

   //--- Set up trade event handling
   // EventSetMillisecondTimer(1000); // Example: Check every second

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   //--- Delete dashboard objects
   g_dashboard_manager.DeleteDashboard();
   //--- Remove timer
   // EventKillTimer();
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- Get latest market data
   MqlTick tick;
   if (!SymbolInfoTick(Symbol(), tick))
     {
      Print("Error getting tick data.");
      return;
     }

//--- Hierarchical Trade Framing Protocol Execution
   // Step 1: Higher Timeframe Bias & Draw on Liquidity (DOL)
   g_crt_core.DetermineDailyBias(InpAutoDetectDailyBias, InpManualDailyBias);

   // Step 2: Higher Timeframe Key Level (KL) Identification
   g_crt_core.IdentifyHTFKeyLevel();

   // Step 3: The Timed Range (8 AM NY ET 1-Hour candle CRT High/Low)
   // Check if it's time to capture the 8 AM NY ET candle close
   datetime current_time_gmt = TimeGMT();
   MqlDateTime dt_gmt;
   TimeToStruct(current_time_gmt, dt_gmt);
   int hour_gmt = dt_gmt.hour;
   int minute_gmt = dt_gmt.min;

   // Convert NY 8 AM ET (which closes at 9 AM NY ET) to GMT
   // Assuming NY ET is GMT-4 during DST and GMT-5 during standard time.
   // This needs to be dynamic based on current date to check for DST.
   // For simplicity, let's assume a fixed offset for now.
   int ny_et_gmt_offset = -4; // Example: GMT-4 for New York ET (during DST)
   int ny_8am_et_close_hour_gmt = NY_8AM_CANDLE_HOUR_ET - ny_et_gmt_offset; // 8 - (-4) = 12 GMT
   int ny_8am_et_close_minute_gmt = NY_8AM_CANDLE_MINUTE_ET;

   // Adjust for hour wrap-around if needed
   if (ny_8am_et_close_hour_gmt >= 24) ny_8am_et_close_hour_gmt -= 24;
   if (ny_8am_et_close_hour_gmt < 0) ny_8am_et_close_hour_gmt += 24;

   // Check if current time is the 8 AM NY ET candle close time (9 AM NY ET)
   if (hour_gmt == ny_8am_et_close_hour_gmt && minute_gmt == ny_8am_et_close_minute_gmt)
     {
      // Only capture once per day
      static datetime last_capture_time = 0;
      MqlDateTime dt_last;
      TimeToStruct(last_capture_time, dt_last);
      if (dt_gmt.day != dt_last.day)
        {
         g_crt_core.CaptureTimedRange(current_time_gmt); // Pass current GMT time as reference
         last_capture_time = current_time_gmt;
        }
     }

   //--- Apply filters (moved after hierarchical steps)
   if (!g_filter_system.ApplyTechnicalFilters() || !g_filter_system.ApplySessionFilters())
     {
      // If filters fail, do not proceed with trade execution
      g_dashboard_manager.DisplaySignals("Filters Failed", clrRed);
      return;
     }

   //--- Check operational mode
   ENUM_OPERATIONAL_MODE current_mode = g_operational_modes.GetCurrentMode();

   if (current_mode == MODE_AUTO_TRADING || current_mode == MODE_HYBRID)
     {
      // Auto-Trading or Hybrid mode: Check for entry signals and execute trades
      if (g_crt_core.CheckEntryConditions())
        {
         // Placeholder for trade execution logic
         // This would involve calculating lot size, SL/TP, and sending trade requests.
         // For now, just print a message.
         Print("Signal detected. Current CRT Phase: ", EnumToString(g_crt_strategy.DetectCRTPhase()));

         // Example: Open a buy trade (simplified)
         double lot_size = g_risk_management.CalculatePositionSize(50); // Example SL of 50 pips
         if (lot_size > 0 && g_risk_management.CheckTradeLimits() && g_risk_management.PerformMarginCheck(lot_size))
           {
            double sl_price, tp_price;
            double crt_high, crt_low, crt_mid;
            g_crt_strategy.GetCRTLevels(crt_high, crt_low, crt_mid);
            g_risk_management.SetStopLossTakeProfit(sl_price, tp_price, tick.ask, ORDER_TYPE_BUY, crt_high, crt_low);
            // m_trade.Buy(lot_size, Symbol(), tick.ask, sl_price, tp_price, "CRT EA Buy");
            Print("Attempting to open BUY trade. Lot: ", lot_size, ", SL: ", sl_price, ", TP: ", tp_price);
            g_dashboard_manager.DisplaySignals("BUY Signal!", clrGreen);

            // Increment trade counts (simplified, should be done after successful trade)
            // daily_trade_count++;
            // session_trade_count++;
           }
         else
           {
            g_dashboard_manager.DisplaySignals("Trade Blocked", clrRed);
           }
        }
     }

   if (current_mode == MODE_MANUAL_TRADING || current_mode == MODE_HYBRID)
     {
      // Manual Trading or Hybrid mode: Display visual notifications
      // This would involve drawing buttons or displaying prompts for user interaction.
      g_dashboard_manager.DisplaySignals("Manual Mode Active", clrBlue);
     }

//--- Update dashboard
   // Placeholder values for win_rate, profit_loss, trades_count, risk_exposure
   // These would be calculated from trade history and account info.
   g_dashboard_manager.UpdateDashboard(g_crt_strategy.DetectCRTPhase(), 0.0, 0.0, 0, 0.0);

//--- Send alerts and notifications
   if (InpEnableVisualAlerts)
     {
      // g_notification_system.SendVisualAlert("New CRT Signal!");
     }
   if (InpEnableAudioAlerts)
     {
      // g_notification_system.PlayAudioAlert(InpAudioFile);
     }
   if (InpEnableEmailAlerts)
     {
      // g_notification_system.SendEmailNotification(InpEmailSubject, "New CRT Signal Detected!");
     }
   if (InpEnablePushNotifications)
     {
      // g_notification_system.SendPushNotification("New CRT Signal!");
     }
  }




//+------------------------------------------------------------------+
//| Breakeven: Moves Stop Loss to breakeven                          |
//+------------------------------------------------------------------+
void Risk_Management::Breakeven(long ticket, double breakeven_pips)
  {
   // This function will move the stop loss of an open trade to breakeven
   // (entry price + a few pips for spread/commission).
   // Needs to retrieve trade details and modify the stop loss.
   Print("Applying Breakeven for trade: ", ticket);
   // TODO: Implement breakeven logic.
  }

//+------------------------------------------------------------------+
//| TrailingStop: Implements a trailing stop loss                    |
//+------------------------------------------------------------------+
void Risk_Management::TrailingStop(long ticket, double trailing_pips)
  {
   // This function will implement a trailing stop loss for an open trade.
   // Needs to continuously monitor price and adjust stop loss.
   Print("Applying Trailing Stop for trade: ", ticket);
   // TODO: Implement trailing stop logic.
  }






//+------------------------------------------------------------------+
//| OnChartEvent: Handles chart events for interactive dashboard     |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if (id == CHARTEVENT_CLICK)
     {
      if (sparam == "ConfirmTradeButton")
        {
         Print("Confirm Trade button clicked!");
         // TODO: Implement logic to confirm trade execution in Hybrid mode
         // This would involve checking entry conditions again and then sending the trade.
        }
     }
  }


