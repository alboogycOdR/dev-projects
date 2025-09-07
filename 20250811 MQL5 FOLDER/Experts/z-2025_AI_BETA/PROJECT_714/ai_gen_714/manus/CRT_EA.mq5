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

//--- Enums for CRT Phase, Entry Method, and Trading Sessions
enum ENUM_CRT_PHASE
  {
   CRT_ACCUMULATION,
   CRT_MANIPULATION,
   CRT_DISTRIBUTION,
   CRT_NONE
  };

enum ENUM_ENTRY_METHOD
  {
   ENTRY_TURTLE_SOUP,
   ENTRY_ORDER_BLOCK,
   ENTRY_THIRD_CANDLE,
   ENTRY_AUTO_BEST,
   ENTRY_NONE
  };

enum ENUM_TRADE_SESSION
  {
   SESSION_SYDNEY,
   SESSION_TOKYO,
   SESSION_FRANKFURT,
   SESSION_LONDON,
   SESSION_NEW_YORK,
   SESSION_GLOBAL
  };

enum ENUM_OPERATIONAL_MODE
  {
   MODE_AUTO_TRADING,
   MODE_MANUAL_TRADING,
   MODE_HYBRID
  };

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
//| Entry_Methods Class                                              |
//+------------------------------------------------------------------+
class Entry_Methods
  {
public:
   //--- Methods
   bool              CheckTurtleSoupEntry();
   bool              CheckOrderBlockEntry();
   bool              CheckThirdCandleEntry();
   ENUM_ENTRY_METHOD SelectAutoBestEntry();
  };

//+------------------------------------------------------------------+
//| Expert Advisor global variables and instances                    |
//+------------------------------------------------------------------+
CRT_Strategy  g_crt_strategy;
Entry_Methods g_entry_methods;

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
   // For now, let's use the previous H4 candle's high, low, and midpoint.
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
//| CheckTurtleSoupEntry: Logic for Turtle Soup entry                |
//+------------------------------------------------------------------+
bool Entry_Methods::CheckTurtleSoupEntry()
  {
   MqlRates rates[];
   if (GetBars(Symbol(), Period(), rates) < 5)
     {
      Print("Not enough bars for Turtle Soup entry.");
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
//| CheckOrderBlockEntry: Logic for Order Block/CSD entry            |
//+------------------------------------------------------------------+
bool Entry_Methods::CheckOrderBlockEntry()
  {
   MqlRates rates[];
   if (GetBars(Symbol(), Period(), rates) < 5)
     {
      Print("Not enough bars for Order Block entry.");
      return false;
     }

   // Simplified Order Block/Change of State Demand/Supply entry logic.
   // This will involve identifying specific candle patterns that signify
   // institutional order blocks or a change of state in demand/supply.
   // Placeholder for now.

   // Example: Basic bullish order block (last bearish candle before a strong bullish move)
   if (IsBearish(rates[2].open, rates[2].close) && IsBullish(rates[1].open, rates[1].close) && rates[1].close > rates[2].high)
     {
      return true; // Potential Buy signal based on a simple order block concept
     }

   // Example: Basic bearish order block (last bullish candle before a strong bearish move)
   if (IsBullish(rates[2].open, rates[2].close) && IsBearish(rates[1].open, rates[1].close) && rates[1].close < rates[2].low)
     {
      return true; // Potential Sell signal based on a simple order block concept
     }

   return false;
  }




//+------------------------------------------------------------------+
//| CheckThirdCandleEntry: Logic for Third Candle entry              |
//+------------------------------------------------------------------+
bool Entry_Methods::CheckThirdCandleEntry()
  {
   MqlRates rates[];
   if (GetBars(Symbol(), Period(), rates) < 3)
     {
      Print("Not enough bars for Third Candle entry.");
      return false;
     }

   // Third Candle Entry: A simple 3-candle confirmation pattern.
   // For a buy: two consecutive bullish candles, and the third candle also closes bullish.
   // For a sell: two consecutive bearish candles, and the third candle also closes bearish.

   // Buy setup
   if (IsBullish(rates[2].open, rates[2].close) && IsBullish(rates[1].open, rates[1].close) && IsBullish(rates[0].open, rates[0].close))
     {
      return true;
     }

   // Sell setup
   if (IsBearish(rates[2].open, rates[2].close) && IsBearish(rates[1].open, rates[1].close) && IsBearish(rates[0].open, rates[0].close))
     {
      return true;
     }

   return false;
  }




//+------------------------------------------------------------------+
//| SelectAutoBestEntry: Determines the optimal entry method         |
//+------------------------------------------------------------------+
ENUM_ENTRY_METHOD Entry_Methods::SelectAutoBestEntry()
  {
   // This function will implement the logic to automatically select the optimal
   // entry approach based on market conditions. This is a complex task and
   // would typically involve advanced market analysis, possibly machine learning.
   // For now, a simplified priority-based selection is implemented.

   if (CheckTurtleSoupEntry())
     {
      return ENTRY_TURTLE_SOUP;
     }
   if (CheckOrderBlockEntry())
     {
      return ENTRY_ORDER_BLOCK;
     }
   if (CheckThirdCandleEntry())
     {
      return ENTRY_THIRD_CANDLE;
     }

   return ENTRY_NONE;
  }




//+------------------------------------------------------------------+
//| Risk_Management Class                                            |
//+------------------------------------------------------------------+
class Risk_Management
  {
private:
   double            m_risk_percentage;
   double            m_min_risk_reward;
   int               m_max_trades_per_day;
   int               m_max_trades_per_session;
   double            m_max_spread;

public:
   //--- Constructor
                     Risk_Management()
     {
      m_risk_percentage        = 0.01; // Default 1%
      m_min_risk_reward        = 1.5;  // Default 1:1.5
      m_max_trades_per_day     = 5;    // Default 5 trades
      m_max_trades_per_session = 2;    // Default 2 trades
      m_max_spread             = 20;   // Default 20 points (2 pips for 5-digit)
     }

   //--- Methods
   double            CalculatePositionSize(double stop_loss_pips);
   void              SetStopLossTakeProfit(double &sl, double &tp, double entry_price, ENUM_ORDER_TYPE order_type, double crt_high, double crt_low);
   bool              CheckTradeLimits();
   bool              PerformMarginCheck(double lot_size);

   //--- Setters for parameters
   void              SetRiskPercentage(double risk) { m_risk_percentage = risk; }
   void              SetMinRiskReward(double r) { m_min_risk_reward = r; }
   void              SetMaxTradesPerDay(int max_trades) { m_max_trades_per_day = max_trades; }
   void              SetMaxTradesPerSession(int max_trades) { m_max_trades_per_session = max_trades; }
   void              SetMaxSpread(double spread) { m_max_spread = spread; }
  };




//+------------------------------------------------------------------+
//| CalculatePositionSize: Determines lot size based on risk percentage |
//+------------------------------------------------------------------+
double Risk_Management::CalculatePositionSize(double stop_loss_pips)
  {
   if (stop_loss_pips <= 0)
     {
      Print("Stop loss in pips must be positive.");
      return 0.0;
     }

   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double tick_value      = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   double tick_size       = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   double contract_size   = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_CONTRACT_SIZE);

   if (tick_value == 0 || tick_size == 0 || contract_size == 0)
     {
      Print("Failed to get symbol info for position sizing.");
      return 0.0;
     }

   // Calculate risk amount in currency
   double risk_amount = account_balance * m_risk_percentage;

   // Calculate lot size
   double lot_size = risk_amount / (stop_loss_pips * tick_value / tick_size);

   // Normalize lot size to min/max/step
   double min_lot  = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double max_lot  = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double step_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

   lot_size = NormalizeDouble(lot_size, 2); // Normalize to 2 decimal places for lot size

   if (lot_size < min_lot)
     {
      lot_size = min_lot;
     }
   if (lot_size > max_lot)
     {
      lot_size = max_lot;
     }

   // Adjust to step size
   lot_size = MathFloor(lot_size / step_lot) * step_lot;

   return lot_size;
  }




//+------------------------------------------------------------------+
//| SetStopLossTakeProfit: Calculates SL/TP levels                   |
//+------------------------------------------------------------------+
void Risk_Management::SetStopLossTakeProfit(double &sl, double &tp, double entry_price, ENUM_ORDER_TYPE order_type, double crt_high, double crt_low)
  {
   double stop_loss_distance = 0.0;
   double take_profit_distance = 0.0;

   if (order_type == ORDER_TYPE_BUY)
     {
      // For Buy orders, SL is typically below entry, TP is above entry
      stop_loss_distance = entry_price - crt_low; // Example: SL at CRT low
      take_profit_distance = (crt_high - entry_price) * m_min_risk_reward; // Example: TP based on CRT high and R:R

      sl = NormalizeDouble(entry_price - stop_loss_distance, _Digits);
      tp = NormalizeDouble(entry_price + take_profit_distance, _Digits);
     }
   else if (order_type == ORDER_TYPE_SELL)
     {
      // For Sell orders, SL is typically above entry, TP is below entry
      stop_loss_distance = crt_high - entry_price; // Example: SL at CRT high
      take_profit_distance = (entry_price - crt_low) * m_min_risk_reward; // Example: TP based on CRT low and R:R

      sl = NormalizeDouble(entry_price + stop_loss_distance, _Digits);
      tp = NormalizeDouble(entry_price - take_profit_distance, _Digits);
     }
  }




//+------------------------------------------------------------------+
//| CheckTradeLimits: Enforces daily/session trade limits            |
//+------------------------------------------------------------------+
bool Risk_Management::CheckTradeLimits()
  {
   // This function needs to track the number of trades opened per day and per session.
   // For simplicity, we'll use a global counter for now. In a real EA, this would
   // involve persistent storage or more sophisticated tracking.

   // Placeholder for daily trade count
   static int daily_trade_count = 0;
   // Placeholder for session trade count (resets per session)
   static int session_trade_count = 0;

   // Reset daily count at the start of a new day (simplified)
   static datetime last_day = 0;
   MqlDateTime current_dt, last_dt;
   TimeToStruct(TimeCurrent(), current_dt);
   TimeToStruct(last_day, last_dt);
   if (current_dt.day_of_year != last_dt.day_of_year || current_dt.year != last_dt.year)
     {
      daily_trade_count = 0;
      last_day = TimeCurrent();
     }

   // Reset session count at the start of a new session (simplified)
   // This would ideally be linked to the Session_Manager class.
   // For now, let's assume a session resets every 4 hours for example.
   static datetime last_session_reset = 0;
   if (TimeCurrent() - last_session_reset > 4 * 3600) // 4 hours
     {
      session_trade_count = 0;
      last_session_reset = TimeCurrent();
     }

   if (daily_trade_count >= m_max_trades_per_day)
     {
      Print("Daily trade limit reached.");
      return false;
     }

   if (session_trade_count >= m_max_trades_per_session)
     {
      Print("Session trade limit reached.");
      return false;
     }

   // Increment counts if a trade is about to be placed (this logic would be called before placing a trade)
   // daily_trade_count++;
   // session_trade_count++;

   return true;
  }




//+------------------------------------------------------------------+
//| PerformMarginCheck: Ensures sufficient margin before opening trades |
//+------------------------------------------------------------------+
bool Risk_Management::PerformMarginCheck(double lot_size)
  {
   MqlTick tick;
   if (!SymbolInfoTick(Symbol(), tick))
     {
      Print("Failed to get tick info for margin check.");
      return false;
     }

   double margin_required = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double current_price = tick.ask; // For buy order
   if (m_trade.RequestType() == ORDER_TYPE_SELL)
     {
      current_price = tick.bid; // For sell order
     }

   // Calculate margin required for the potential trade
   // This is a simplified calculation and might need to be more precise
   // based on broker's margin requirements.
   double calculated_margin = lot_size * SymbolInfoDouble(Symbol(), SYMBOL_TRADE_CONTRACT_SIZE) * current_price / (double)AccountInfoInteger(ACCOUNT_LEVERAGE);

   if (calculated_margin > margin_required)
     {
      Print("Insufficient margin for trade. Required: ", calculated_margin, ", Free: ", margin_required);
      return false;
     }

   return true;
  }




//+------------------------------------------------------------------+
//| Session_Manager Class                                            |
//+------------------------------------------------------------------+
class Session_Manager
  {
private:
   int               m_gmt_offset;

public:
   //--- Constructor
                     Session_Manager()
     {
      m_gmt_offset = 0; // Will be adjusted automatically
     }

   //--- Methods
   bool              IsTradingSessionActive(ENUM_TRADE_SESSION session);
   void              AdjustGMT();
  };




//+------------------------------------------------------------------+
//| AdjustGMT: Automatically adjusts for broker server time GMT offset |
//+------------------------------------------------------------------+
void Session_Manager::AdjustGMT()
  {
   // This function calculates the GMT offset of the broker server.
   // It compares the current server time with the current GMT time.
   datetime current_server_time = TimeCurrent();
   datetime current_gmt_time = TimeGMT();

   m_gmt_offset = (int)((current_server_time - current_gmt_time) / 3600); // Offset in hours
   Print("Broker GMT Offset: ", m_gmt_offset, " hours");
  }




//+------------------------------------------------------------------+
//| IsTradingSessionActive: Checks if the current time falls within  |
//|                         an active trading session                |
//+------------------------------------------------------------------+
bool Session_Manager::IsTradingSessionActive(ENUM_TRADE_SESSION session)
  {
   datetime current_time_gmt = TimeGMT();
   MqlDateTime dt;
   TimeToStruct(current_time_gmt, dt);
   int hour_gmt = dt.hour;
   int minute_gmt = dt.min;

   // Define session times in GMT (24-hour format)
   // These are approximate and can be refined based on specific broker/market data
   struct SessionHours
     {
      int start_hour;
      int start_minute;
      int end_hour;
      int end_minute;
     };

   SessionHours sessions[];
   ArrayResize(sessions, 6); // 5 specific sessions + 1 for global

   // Sydney Session (GMT: 22:00 - 07:00)
   sessions[SESSION_SYDNEY].start_hour = 22;
   sessions[SESSION_SYDNEY].start_minute = 0;
   sessions[SESSION_SYDNEY].end_hour = 7;
   sessions[SESSION_SYDNEY].end_minute = 0;

   // Tokyo Session (GMT: 00:00 - 09:00)
   sessions[SESSION_TOKYO].start_hour = 0;
   sessions[SESSION_TOKYO].start_minute = 0;
   sessions[SESSION_TOKYO].end_hour = 9;
   sessions[SESSION_TOKYO].end_minute = 0;

   // Frankfurt Session (GMT: 07:00 - 16:00)
   sessions[SESSION_FRANKFURT].start_hour = 7;
   sessions[SESSION_FRANKFURT].start_minute = 0;
   sessions[SESSION_FRANKFURT].end_hour = 16;
   sessions[SESSION_FRANKFURT].end_minute = 0;

   // London Session (GMT: 08:00 - 17:00)
   sessions[SESSION_LONDON].start_hour = 8;
   sessions[SESSION_LONDON].start_minute = 0;
   sessions[SESSION_LONDON].end_hour = 17;
   sessions[SESSION_LONDON].end_minute = 0;

   // New York Session (GMT: 13:00 - 22:00)
   sessions[SESSION_NEW_YORK].start_hour = 13;
   sessions[SESSION_NEW_YORK].start_minute = 0;
   sessions[SESSION_NEW_YORK].end_hour = 22;
   sessions[SESSION_NEW_YORK].end_minute = 0;

   // Global Session (always active)
   sessions[SESSION_GLOBAL].start_hour = 0;
   sessions[SESSION_GLOBAL].start_minute = 0;
   sessions[SESSION_GLOBAL].end_hour = 23;
   sessions[SESSION_GLOBAL].end_minute = 59;

   int current_total_minutes_gmt = hour_gmt * 60 + minute_gmt;

   if (session == SESSION_GLOBAL)
     {
      return true;
     }

   int start_total_minutes = sessions[session].start_hour * 60 + sessions[session].start_minute;
   int end_total_minutes = sessions[session].end_hour * 60 + sessions[session].end_minute;

   if (start_total_minutes < end_total_minutes)
     {
      // Session does not cross midnight
      return (current_total_minutes_gmt >= start_total_minutes && current_total_minutes_gmt < end_total_minutes);
     }
   else
     {
      // Session crosses midnight
      return (current_total_minutes_gmt >= start_total_minutes || current_total_minutes_gmt < end_total_minutes);
     }
  }




//+------------------------------------------------------------------+
//| Filter_System Class                                              |
//+------------------------------------------------------------------+
class Filter_System
  {
private:
   double            m_max_spread_filter;

public:
   //--- Constructor
                     Filter_System()
     {
      m_max_spread_filter = 2.0; // Default max spread in pips
     }

   //--- Methods
   bool              ApplyTechnicalFilters();
   bool              ApplySessionFilters();

   //--- Setter
   void              SetMaxSpreadFilter(double spread) { m_max_spread_filter = spread; }
  };




//+------------------------------------------------------------------+
//| ApplyTechnicalFilters: Checks for various technical filters      |
//+------------------------------------------------------------------+
bool Filter_System::ApplyTechnicalFilters()
  {
   // This function will implement checks for Inside Bar, Key Level confluence,
   // CRT Plus, and Nested CRT multi-timeframe alignment.
   // These are complex and require detailed implementation based on specific definitions.
   // For now, placeholders returning true.

   // Example: Inside Bar (previous candle completely engulfs the current candle)
   MqlRates rates[];
   if (GetBars(Symbol(), Period(), rates) < 2)
     {
      return true; // Not enough bars to check
     }
   if (rates[0].high < rates[1].high && rates[0].low > rates[1].low)
     {
      // This is an inside bar, decide if it's a filter or a signal
      // For now, let's assume it passes the filter.
     }

   // Key Level confluence, CRT Plus, Nested CRT would involve more complex checks
   // with support/resistance levels, CRT patterns, and multi-timeframe analysis.

   return true; // Default return
  }




//+------------------------------------------------------------------+
//| ApplySessionFilters: Checks for session-based filters            |
//+------------------------------------------------------------------+
bool Filter_System::ApplySessionFilters()
  {
   // This function will implement checks for Monday/Friday filters,
   // high-impact news avoidance, and spread protection.

   // Monday/Friday filters
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int day_of_week = dt.day_of_week;
   if (day_of_week == MONDAY || day_of_week == FRIDAY)
     {
      // Decide whether to allow trading on Mondays/Fridays based on input parameters
      // For now, let's assume it passes the filter.
     }

   // High-impact news avoidance (requires external news calendar integration or manual input)
   // This is a complex feature and typically involves external data sources.
   // Placeholder for now.

   // Spread protection
   MqlTick tick;
   if (!SymbolInfoTick(Symbol(), tick))
     {
      Print("Failed to get tick info for spread check.");
      return false;
     }
   double current_spread = (tick.ask - tick.bid) / SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   if (current_spread > m_max_spread_filter)
     {
      Print("Spread (", current_spread, ") exceeds maximum allowed (", m_max_spread_filter, ").");
      return false;
     }

   return true; // Default return
  }




//+------------------------------------------------------------------+
//| Operational_Modes Class                                          |
//+------------------------------------------------------------------+
class Operational_Modes
  {
public:
   //--- Enums for Operational Mode - MOVED TO GLOBAL SCOPE

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
   ENUM_OPERATIONAL_MODE GetCurrentMode() const { return m_current_mode; }
  };




//+------------------------------------------------------------------+
//| SetAutoTradingMode: Activates fully automated trading            |
//+------------------------------------------------------------------+
void Operational_Modes::SetAutoTradingMode()
  {
   m_current_mode = MODE_AUTO_TRADING;
   Print("Operational Mode set to: Auto-Trading");
  }




//+------------------------------------------------------------------+
//| SetManualTradingMode: Activates manual trading with notifications |
//+------------------------------------------------------------------+
void Operational_Modes::SetManualTradingMode()
  {
   m_current_mode = MODE_MANUAL_TRADING;
   Print("Operational Mode set to: Manual Trading");
  }




//+------------------------------------------------------------------+
//| SetHybridMode: Allows switching between auto and manual          |
//+------------------------------------------------------------------+
void Operational_Modes::SetHybridMode()
  {
   m_current_mode = MODE_HYBRID;
   Print("Operational Mode set to: Hybrid Mode");
  }




//+------------------------------------------------------------------+
//| Dashboard_Manager Class                                          |
//+------------------------------------------------------------------+
class Dashboard_Manager
  {
private:
   //--- Dashboard elements (e.g., labels, rectangles)
   string            m_prefix;

public:
   //--- Constructor
                     Dashboard_Manager(string prefix = "CRT_Dashboard_")
     {
      m_prefix = prefix;
     }

   //--- Methods
   void              UpdateDashboard(ENUM_CRT_PHASE crt_phase, double win_rate, double profit_loss, int trades_count, double risk_exposure);
   void              DisplayCRTViz(ENUM_CRT_PHASE crt_phase, double crt_high, double crt_low);
   void              DisplayStats(double win_rate, double profit_loss, int trades_count, double risk_exposure);
   void              DisplaySignals(string signal_text, color signal_color);
   void              ApplyCustomization(color theme_color, int font_size);
   void              CreateDashboard();
   void              DeleteDashboard();
  };




//+------------------------------------------------------------------+
//| CreateDashboard: Creates the graphical dashboard objects         |
//+------------------------------------------------------------------+
void Dashboard_Manager::CreateDashboard()
  {
   // Create background rectangle
   ObjectCreate(0, m_prefix + "Background", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, m_prefix + "Background", OBJPROP_XSIZE, 300);
   ObjectSetInteger(0, m_prefix + "Background", OBJPROP_YSIZE, 200);
   ObjectSetInteger(0, m_prefix + "Background", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, m_prefix + "Background", OBJPROP_BGCOLOR, clrLightGray);
   ObjectSetInteger(0, m_prefix + "Background", OBJPROP_BORDER_COLOR, clrDarkGray);
   ObjectSetInteger(0, m_prefix + "Background", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, m_prefix + "Background", OBJPROP_ZORDER, 0);

   // Create labels for CRT Phase, Stats, Signals
   ObjectCreate(0, m_prefix + "CRTPhaseLabel", OBJ_LABEL, 0, 10, 10);
   ObjectSetString(0, m_prefix + "CRTPhaseLabel", OBJPROP_TEXT, "CRT Phase: ");
   ObjectSetInteger(0, m_prefix + "CRTPhaseLabel", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, m_prefix + "CRTPhaseLabel", OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, m_prefix + "CRTPhaseLabel", OBJPROP_COLOR, clrBlack);

   ObjectCreate(0, m_prefix + "StatsLabel", OBJ_LABEL, 0, 10, 30);
   ObjectSetString(0, m_prefix + "StatsLabel", OBJPROP_TEXT, "Stats: ");
   ObjectSetInteger(0, m_prefix + "StatsLabel", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, m_prefix + "StatsLabel", OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, m_prefix + "StatsLabel", OBJPROP_COLOR, clrBlack);

   ObjectCreate(0, m_prefix + "SignalsLabel", OBJ_LABEL, 0, 10, 50);
   ObjectSetString(0, m_prefix + "SignalsLabel", OBJPROP_TEXT, "Signals: ");
   ObjectSetInteger(0, m_prefix + "SignalsLabel", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, m_prefix + "SignalsLabel", OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, m_prefix + "SignalsLabel", OBJPROP_COLOR, clrBlack);

   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| DeleteDashboard: Deletes the graphical dashboard objects         |
//+------------------------------------------------------------------+
void Dashboard_Manager::DeleteDashboard()
  {
   ObjectsDeleteAll(0, m_prefix);
   ChartRedraw();
  }




//+------------------------------------------------------------------+
//| UpdateDashboard: Refreshes dashboard with live data              |
//+------------------------------------------------------------------+
void Dashboard_Manager::UpdateDashboard(ENUM_CRT_PHASE crt_phase, double win_rate, double profit_loss, int trades_count, double risk_exposure)
  {
   DisplayCRTViz(crt_phase, 0, 0); // CRT High/Low will be passed from CRT_Strategy
   DisplayStats(win_rate, profit_loss, trades_count, risk_exposure);
   DisplaySignals("", clrNONE); // Signals will be updated separately
   ChartRedraw();
  }




//+------------------------------------------------------------------+
//| DisplayCRTViz: Visualizes CRT phases and ranges                  |
//+------------------------------------------------------------------+
void Dashboard_Manager::DisplayCRTViz(ENUM_CRT_PHASE crt_phase, double crt_high, double crt_low)
  {
   string phase_text;
   color phase_color;

   switch (crt_phase)
     {
      case CRT_ACCUMULATION:
         phase_text = "Accumulation";
         phase_color = clrBlue;
         break;
      case CRT_MANIPULATION:
         phase_text = "Manipulation";
         phase_color = clrOrange;
         break;
      case CRT_DISTRIBUTION:
         phase_text = "Distribution";
         phase_color = clrRed;
         break;
      default:
         phase_text = "None";
         phase_color = clrGray;
         break;
     }
   ObjectSetString(0, m_prefix + "CRTPhaseLabel", OBJPROP_TEXT, "CRT Phase: " + phase_text);
   ObjectSetInteger(0, m_prefix + "CRTPhaseLabel", OBJPROP_COLOR, phase_color);

   // Display CRT range indicators (simplified, needs actual drawing of lines/rectangles)
   // This would involve creating OBJ_RECTANGLE or OBJ_TREND objects based on crt_high and crt_low
  }




//+------------------------------------------------------------------+
//| DisplayStats: Shows win rate, P/L, trade count, etc.             |
//+------------------------------------------------------------------+
void Dashboard_Manager::DisplayStats(double win_rate, double profit_loss, int trades_count, double risk_exposure)
  {
   string stats_text = StringFormat("Win Rate: %.2f%%\nProfit/Loss: %.2f\nTrades: %d\nRisk: %.2f%%",
                                    win_rate, profit_loss, trades_count, risk_exposure);
   ObjectSetString(0, m_prefix + "StatsLabel", OBJPROP_TEXT, "Stats:\n" + stats_text);
  }




//+------------------------------------------------------------------+
//| DisplaySignals: Shows bullish/bearish signals and strength       |
//+------------------------------------------------------------------+
void Dashboard_Manager::DisplaySignals(string signal_text, color signal_color)
  {
   ObjectSetString(0, m_prefix + "SignalsLabel", OBJPROP_TEXT, "Signals: " + signal_text);
   ObjectSetInteger(0, m_prefix + "SignalsLabel", OBJPROP_COLOR, signal_color);
  }




//+------------------------------------------------------------------+
//| ApplyCustomization: Handles color themes, font sizes, layout     |
//+------------------------------------------------------------------+
void Dashboard_Manager::ApplyCustomization(color theme_color, int font_size)
  {
   ObjectSetInteger(0, m_prefix + "Background", OBJPROP_BGCOLOR, theme_color);
   ObjectSetInteger(0, m_prefix + "CRTPhaseLabel", OBJPROP_FONTSIZE, font_size);
   ObjectSetInteger(0, m_prefix + "StatsLabel", OBJPROP_FONTSIZE, font_size);
   ObjectSetInteger(0, m_prefix + "SignalsLabel", OBJPROP_FONTSIZE, font_size);
   ChartRedraw();
  }




//+------------------------------------------------------------------+
//| Notification_System Class                                        |
//+------------------------------------------------------------------+
class Notification_System
  {
public:
   //--- Methods
   void              SendVisualAlert(string message);
   void              PlayAudioAlert(string sound_file);
   void              SendEmailNotification(string subject, string message);
   void              SendPushNotification(string message);
  };




//+------------------------------------------------------------------+
//| SendVisualAlert: Displays on-screen alerts                       |
//+------------------------------------------------------------------+
void Notification_System::SendVisualAlert(string message)
  {
   Alert(message);
  }




//+------------------------------------------------------------------+
//| PlayAudioAlert: Plays sound notifications                        |
//+------------------------------------------------------------------+
void Notification_System::PlayAudioAlert(string sound_file)
  {
   PlaySound(sound_file);
  }




//+------------------------------------------------------------------+
//| SendEmailNotification: Sends email alerts                        |
//+------------------------------------------------------------------+
void Notification_System::SendEmailNotification(string subject, string message)
  {
   SendMail(subject, message);
  }




//+------------------------------------------------------------------+
//| SendPushNotification: Sends mobile push notifications            |
//+------------------------------------------------------------------+
void Notification_System::SendPushNotification(string message)
  {
   SendNotification(message);
  }




//--- Expert Advisor global variables and instances (continued)
Risk_Management   g_risk_management;
Session_Manager   g_session_manager;
Filter_System     g_filter_system;
Operational_Modes g_operational_modes;
Dashboard_Manager g_dashboard_manager;
Notification_System g_notification_system;




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




//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Initialize classes
   g_operational_modes.SetAutoTradingMode(); // Default to auto-trading
   g_session_manager.AdjustGMT();

//--- Set input parameters to respective classes
   g_risk_management.SetRiskPercentage(InpRiskPercentage / 100.0);
   g_risk_management.SetMinRiskReward(InpMinRiskReward);
   g_risk_management.SetMaxTradesPerDay(InpMaxTradesPerDay);
   g_risk_management.SetMaxTradesPerSession(InpMaxTradesPerSession);
   g_risk_management.SetMaxSpread(InpMaxSpread);

   g_filter_system.SetMaxSpreadFilter(InpMaxSpread);

//--- Create dashboard
   g_dashboard_manager.CreateDashboard();
   g_dashboard_manager.ApplyCustomization(InpDashboardThemeColor, InpDashboardFontSize);

   return(INIT_SUCCEEDED);
  }




//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Clean up resources
   g_dashboard_manager.DeleteDashboard();
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

//--- Detect CRT phase and levels
   ENUM_CRT_PHASE current_crt_phase = g_crt_strategy.DetectCRTPhase();
   double crt_high, crt_low, crt_mid;
   g_crt_strategy.GetCRTLevels(crt_high, crt_low, crt_mid);

//--- Apply filters
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
      ENUM_ENTRY_METHOD entry_method = g_entry_methods.SelectAutoBestEntry();

      if (entry_method != ENTRY_NONE)
        {
         // Placeholder for trade execution logic
         // This would involve calculating lot size, SL/TP, and sending trade requests.
         // For now, just print a message.
         Print("Signal detected using ", EnumToString(entry_method), ". Current CRT Phase: ", EnumToString(current_crt_phase));

         // Example: Open a buy trade (simplified)
         double lot_size = g_risk_management.CalculatePositionSize(50); // Example SL of 50 pips
         if (lot_size > 0 && g_risk_management.CheckTradeLimits() && g_risk_management.PerformMarginCheck(lot_size))
           {
            double sl_price, tp_price;
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
   g_dashboard_manager.UpdateDashboard(current_crt_phase, 0.0, 0.0, 0, 0.0);

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


