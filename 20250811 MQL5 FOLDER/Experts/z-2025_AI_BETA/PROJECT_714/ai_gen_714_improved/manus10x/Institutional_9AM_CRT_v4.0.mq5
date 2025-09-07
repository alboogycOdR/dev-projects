//+------------------------------------------------------------------+
//|                                  Institutional_9AM_CRT_v4.0.mq5   |
//|                          10x Upgraded Version                    |
//|      (Enhanced UI/UX, Advanced Logic, Dynamic Risk Management)   |
//+------------------------------------------------------------------+
#property copyright "10x Upgraded Version by AI Trading Expert"
#property link      "https://beta.character.ai/"
#property version   "4.00"
#property description "10x Upgraded EA for the CRT methodology. Features enhanced UI/UX, advanced filters, dynamic risk management, and AI integration capabilities."
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <ChartObjects\ChartObjectsTxtControls.mqh>

//--- Global objects
CTrade trade;
CPositionInfo position;
CAccountInfo account;

//--- UI Constants
#define UI_PANEL_WIDTH      300
#define UI_PANEL_HEIGHT     400
#define UI_PANEL_X          10
#define UI_PANEL_Y          10
#define UI_TAB_HEIGHT       25
#define UI_TAB_WIDTH        80
#define UI_CONTROL_HEIGHT   20
#define UI_CONTROL_SPACING  5

//--- UI Colors
#define CLR_PANEL_BG        clrBlack
#define CLR_PANEL_BORDER    clrDimGray
#define CLR_TAB_ACTIVE_BG   clrDarkSlateGray
#define CLR_TAB_INACTIVE_BG clrDimGray
#define CLR_TEXT            clrWhite
#define CLR_BUTTON_BG       clrDodgerBlue
#define CLR_BUTTON_TEXT     clrWhite

//--- Enums for user inputs
enum ENUM_MESSAGE_TYPE
  {
   MSG_INFO,
   MSG_WARNING,
   MSG_ERROR,
   MSG_DEBUG
  };

enum ENUM_CRT_MODEL
  {
   CRT_1AM_ASIA,
   CRT_5AM_LONDON,
   CRT_9AM_NY
  };

enum ENUM_ENTRY_MODEL
  {
   CONFIRMATION_MSS,       // RECOMMENDED: Market Structure Shift + FVG/OB Entry
   AGGRESSIVE_TURTLE_SOUP  // ADVANCED: Immediate entry on sweep
  };

enum ENUM_OPERATIONAL_MODE
  {
   SIGNALS_ONLY,
   FULLY_AUTOMATED,
   HYBRID_MODE
  };

enum ENUM_DAILY_BIAS
  {
   NEUTRAL,
   BULLISH,
   BEARISH
  };

enum ENUM_WEEKLY_PROFILE
  {
   WP_TRENDING,
   WP_RANGE,
   WP_REVERSAL
  };

// [CRT LOGIC UPGRADE] Enum for the new MSS confirmation state machine
enum ENUM_TRADE_STATE
  {
   MONITORING,             // Waiting for a sweep of the CRT Range
   SWEEP_DETECTED,         // Sweep has occurred, now monitoring for MSS
   MSS_CONFIRMED           // MSS has occurred, now waiting for retracement entry
  };

//--- UI Tab Enums
enum ENUM_UI_TAB
  {
   TAB_OVERVIEW,
   TAB_SETTINGS,
   TAB_PERFORMANCE,
   TAB_LOGS
  };

//--- Global & State Variables ---
double      crtHigh = 0, crtLow = 0;
datetime    crtRangeCandleTime = 0;
string      entrySignal = "";
bool        tradeTakenToday = false;
int         tradesTodayCount = 0;
string      dashboardID = "CRT_Dashboard_V4_";

// --- New variables for the Bias & KL Module ---
static ENUM_DAILY_BIAS  determinedBias = NEUTRAL;
static double           dol_target_price = 0;
static double           htf_kl_high = 0;
static double           htf_kl_low = 0;

// --- State machine variables ---
static ENUM_TRADE_STATE bullish_state = MONITORING;
static ENUM_TRADE_STATE bearish_state = MONITORING;
static double           bullish_sweep_low = 0;
static double           bearish_sweep_high = 0;
static double           m15_fvg_high = 0;
static double           m15_fvg_low = 0;

// --- UI State Variables ---
static ENUM_UI_TAB      currentTab = TAB_OVERVIEW;

// --- Global operational mode variable ---
static ENUM_OPERATIONAL_MODE OperationalMode = SIGNALS_ONLY;

//--- Expert Advisor Input Parameters ---
input group                 "CRT Core Settings"
input ENUM_CRT_MODEL        CRTModelSelection       = CRT_9AM_NY;       // Select the CRT Model to Trade
input ENUM_ENTRY_MODEL      EntryLogicModel         = CONFIRMATION_MSS; // Preferred Entry Model
input int                   Broker_GMT_Offset_Hours = 3;                // **IMPORTANT** Broker's GMT Offset (e.g., GMT+3)

input group                 "Risk & Trade Management"
input double                RiskPercent             = 0.5;              // Risk per Trade (%)
input double                TakeProfit1_RR          = 1.0;              // TP1 Risk:Reward Ratio
input bool                  MoveToBE_After_TP1      = true;             // Move SL to Breakeven after TP1?
input int                   Daily_Max_Trades        = 1;                // Maximum trades per day
input string                NY_Killzone_Start       = "09:00";          // New York Killzone Start Time
input string                NY_Killzone_End         = "12:00";          // New York Killzone End Time

input group                 "Advanced Trade Management"
input bool                  UseMultiTP              = false;            // Enable Multi-Stage Take Profit?
input double                TakeProfit2_RR          = 2.0;              // TP2 Risk:Reward Ratio
input double                TakeProfit3_RR          = 3.0;              // TP3 Risk:Reward Ratio
input double                PartialClose1_Percent   = 0.5;              // Percentage of volume to close at TP1
input double                PartialClose2_Percent   = 0.5;              // Percentage of remaining volume to close at TP2
input bool                  UseTrailingStop         = false;            // Enable Trailing Stop?
input int                   TrailingStopPips        = 10;               // Trailing Stop in Pips
input int                   TrailingStepPips        = 1;                // Trailing Step in Pips

input group                 "Advanced Contextual Filters"
input bool                  Filter_By_Daily_Bias    = true;             // Strictly enforce Daily Bias filter?
input bool                  Filter_By_HTF_KL        = true;             // Require sweep to occur at a H4 Key Level?
input bool                  Filter_By_WeeklyProfile = false;            // Enable Weekly Profile Filter?
input ENUM_WEEKLY_PROFILE   WeeklyProfileType       = WP_TRENDING;      // Expected Weekly Profile Type
input bool                  Filter_By_SMTDivergence = false;            // Enable SMT Divergence Filter?
input string                CorrelatedSymbol        = "EURUSD";         // Correlated Symbol for SMT Divergence
input bool                  Filter_By_HighImpactNews= false;            // Enable High-Impact News Filter?
input int                   NewsLookbackMinutes     = 30;               // Minutes before/after news to avoid trading

//--- Global functions (forward declarations)
void CreateDashboard();
void UpdateDashboard();
void ResetDailyVariables();
void AnalyzeHigherTimeframes();
void FindNearest_H4_PDArray_Below(double &kl_h, double &kl_l);
void FindNearest_H4_PDArray_Above(double &kl_h, double &kl_l);
void SetCRTRange();
void CheckForEntry();
void ManageOpenPositions();
datetime GetNYTime(datetime st=0);
long GetNYGMTOffset();
bool IsWithinKillzone();
void ParseTime(string ts,int&h,int&m);
double CalculateLotSize(double sl_dist);
void DrawRangeLines();
void DrawHTFKeyLevelZone();
void DrawDOLTarget();
void DrawTradeStateVisuals();
void LogMessage(string message, ENUM_MESSAGE_TYPE type = MSG_INFO);
bool CheckWeeklyProfile();
bool CheckSMTDivergence();
bool CheckHighImpactNews();
double FindLastM15SwingHigh(int l,int&idx);
double FindLastM15SwingLow(int l,int&idx);
bool FindFVG_AfterMSS(int start_bar,double&h,double&l,ENUM_DAILY_BIAS b);
void ExecuteTrade(ENUM_ORDER_TYPE order_type, double lots, double price, double sl, double tp);


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   LogMessage("Institutional CRT Advisor v4.0 (10x Upgraded) Initializing...", MSG_INFO);
   CreateDashboard();
   trade.SetExpertMagicNumber(19914);
   trade.SetTypeFillingBySymbol(_Symbol);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   LogMessage("CRT Expert Advisor v4.0 Deinitializing...", MSG_INFO);
// Clean up all chart objects created by this EA
   ObjectsDeleteAll(0, dashboardID);
  }


//+------------------------------------------------------------------+
//| Expert tick function (controlled by M1 bar timer)                |
//-------------------------------------------------------------------+
void OnTick()
  {
   static datetime lastBarTime = 0;
   if(iTime(_Symbol, _Period, 0) > lastBarTime)
     {
      lastBarTime = iTime(_Symbol, _Period, 0);

      static datetime last_day = 0;
      datetime current_day = TimeCurrent() / 86400; // Integer division gives day number
      if(current_day > last_day)
        {
         ResetDailyVariables();
         last_day = current_day;
        }

      SetCRTRange();

      if(crtHigh > 0 && !tradeTakenToday && tradesTodayCount < Daily_Max_Trades && IsWithinKillzone())
        {
         CheckForEntry();
        }
      UpdateDashboard();
      DrawHTFKeyLevelZone();
      DrawDOLTarget();
      DrawTradeStateVisuals();
     }
   ManageOpenPositions();
  }

//+------------------------------------------------------------------+
//| Resets variables and performs new daily analysis                 |
//+------------------------------------------------------------------+
void ResetDailyVariables()
  {
   LogMessage("New Day Reset Triggered.", MSG_INFO);
   crtHigh = 0;
   crtLow = 0;
   crtRangeCandleTime = 0;
   tradeTakenToday = false;
   tradesTodayCount = 0;
   entrySignal = "";

// Reset state machines and levels
   bullish_state = MONITORING;
   bearish_state = MONITORING;
   determinedBias = NEUTRAL;
   dol_target_price = 0;
   htf_kl_high = 0;
   htf_kl_low = 0;

   ObjectsDeleteAll(0, dashboardID);
   CreateDashboard();

// Perform the high-level analysis for the new day
   AnalyzeHigherTimeframes();
  }

//+------------------------------------------------------------------+
//| [v3.0] The HTF Analysis Engine                                   |
//+------------------------------------------------------------------+
void AnalyzeHigherTimeframes()
  {
   MqlRates d1_rates[];
   if(CopyRates(_Symbol, PERIOD_D1, 0, 30, d1_rates) < 30)
     {
      LogMessage("Could not get D1 data for bias analysis.", MSG_WARNING);
      return;
     }

   int highest_idx = 1;
   int lowest_idx = 1;
   for(int i = 2; i < 30; i++)
     {
      if(d1_rates[i].high > d1_rates[highest_idx].high)
         highest_idx = i;
      if(d1_rates[i].low < d1_rates[lowest_idx].low)
         lowest_idx = i;
     }

   double highest_high = d1_rates[highest_idx].high;
   double lowest_low = d1_rates[lowest_idx].low;
   double last_close = d1_rates[0].close;

   if(MathAbs(highest_high - last_close) < MathAbs(lowest_low - last_close))
     {
      determinedBias = BULLISH;
      dol_target_price = highest_high;
     }
   else
     {
      determinedBias = BEARISH;
      dol_target_price = lowest_low;
     }
   LogMessage("Daily Bias Analysis complete. Bias: " + EnumToString(determinedBias) + " | DOL Target: " + DoubleToString(dol_target_price), MSG_INFO);

   if(determinedBias == BULLISH)
      FindNearest_H4_PDArray_Below(htf_kl_high, htf_kl_low);
   else
      if(determinedBias == BEARISH)
         FindNearest_H4_PDArray_Above(htf_kl_high, htf_kl_low);

   LogMessage("Found HTF Key Level Zone: " + DoubleToString(htf_kl_low) + " - " + DoubleToString(htf_kl_high), MSG_INFO);
  }

//+------------------------------------------------------------------+
//| [v3.0] New helper to find H4 FVG for Bullish Bias                |
//+------------------------------------------------------------------+
void FindNearest_H4_PDArray_Below(double &kl_h, double &kl_l)
  {
   MqlRates h4_rates[];
   if(CopyRates(_Symbol, PERIOD_H4, 0, 10, h4_rates) < 3)
      return;
   double last_low = iLow(_Symbol, PERIOD_D1, 0);

   for(int i = ArraySize(h4_rates) - 2; i >= 1; i--)
     {
      if(h4_rates[i].high < last_low && h4_rates[i-1].high < h4_rates[i+1].low)
        {
         kl_h = h4_rates[i+1].low;
         kl_l = h4_rates[i-1].high;
         return;
        }
     }
  }
//+------------------------------------------------------------------+
//| [v3.0] New helper to find H4 FVG for Bearish Bias                |
//+------------------------------------------------------------------+
void FindNearest_H4_PDArray_Above(double &kl_h, double &kl_l)
  {
   MqlRates h4_rates[];
   if(CopyRates(_Symbol, PERIOD_H4, 0, 10, h4_rates) < 3)
      return;
   double last_high = iHigh(_Symbol, PERIOD_D1, 0);

   for(int i = ArraySize(h4_rates) - 2; i >= 1; i--)
     {
      if(h4_rates[i].low > last_high && h4_rates[i-1].low > h4_rates[i+1].high)
        {
         kl_h = h4_rates[i-1].low;
         kl_l = h4_rates[i+1].high;
         return;
        }
     }
  }
//+------------------------------------------------------------------+
//| Sets the daily CRT range using robust time logic                 |
//+------------------------------------------------------------------+
void SetCRTRange()
  {
   if(crtHigh > 0 && crtLow > 0) // Only calculate once per day
      return;

   datetime current_time_server = TimeCurrent();
   MqlDateTime tm_server;
   TimeToStruct(current_time_server, tm_server);

   datetime target_candle_time_server = 0;
   int target_hour_ny = 0;

   // Determine target NY hour based on CRT Model Selection
   if (CRTModelSelection == CRT_1AM_ASIA)
      target_hour_ny = 1; // 1 AM NY Time
   else if (CRTModelSelection == CRT_5AM_LONDON)
      target_hour_ny = 5; // 5 AM NY Time
   else if (CRTModelSelection == CRT_9AM_NY)
      target_hour_ny = 9; // 9 AM NY Time

   // Calculate the start of the current day in NY time
   datetime start_of_today_ny = GetNYTime(current_time_server) - (tm_server.hour * 3600 + tm_server.min * 60 + tm_server.sec);
   MqlDateTime tm_ny_today;
   TimeToStruct(start_of_today_ny, tm_ny_today);
   start_of_today_ny = start_of_today_ny - (tm_ny_today.hour * 3600 + tm_ny_today.min * 60 + tm_ny_today.sec); // Ensure it's truly start of NY day

   // Calculate the target candle time in NY time
   datetime target_candle_time_ny = start_of_today_ny + target_hour_ny * 3600;

   // Convert target NY time to server time
   target_candle_time_server = target_candle_time_ny - (datetime)((GetNYGMTOffset() - Broker_GMT_Offset_Hours) * 3600);

   // Ensure we are past the target candle time on the server
   if (current_time_server < target_candle_time_server + 3600) // +3600 to ensure the H1 candle has closed
      return;

   MqlRates rate[1];
   if(CopyRates(_Symbol, PERIOD_H1, target_candle_time_server, 1, rate) == 1)
     {
      crtHigh = rate[0].high;
      crtLow = rate[0].low;
      crtRangeCandleTime = rate[0].time;
      DrawRangeLines();
      LogMessage("CRT Range Set: High=" + DoubleToString(crtHigh) + ", Low=" + DoubleToString(crtLow) + ", Time=" + TimeToString(crtRangeCandleTime), MSG_INFO);
     }
   else
     {
      LogMessage("Failed to get H1 data for CRT Range at " + TimeToString(target_candle_time_server), MSG_ERROR);
     }
  }

//+------------------------------------------------------------------+
//| Checks for trade entries based on state machine                  |
//+------------------------------------------------------------------+
void CheckForEntry()
  {
// Apply filters before proceeding
   if(Filter_By_Daily_Bias && (determinedBias == NEUTRAL))
      return;

   // Apply advanced contextual filters
   if (!CheckWeeklyProfile())
     {
      Print("Entry filtered by Weekly Profile.");
      return;
     }
   if (!CheckSMTDivergence())
     {
      Print("Entry filtered by SMT Divergence.");
      return;
     }
   if (!CheckHighImpactNews())
     {
      Print("Entry filtered by High-Impact News.");
      return;
     }

   MqlRates m15_rates[];
   if(CopyRates(_Symbol, PERIOD_M15, 0, 10, m15_rates) < 10)
      return;

   double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if (determinedBias == BULLISH)
   {
      switch(bullish_state)
      {
         case MONITORING:
            {
            // Check for sweep of CRT Low
            if (current_bid < crtLow)
            {
               bullish_sweep_low = current_bid;
               bullish_state = SWEEP_DETECTED;
               LogMessage("Bullish: Sweep Detected at " + DoubleToString(bullish_sweep_low), MSG_INFO);
            }
            break;
            }

         case SWEEP_DETECTED:
            {
            // Check for Market Structure Shift (MSS) - M15 higher high after sweep
            int swing_high_idx = 0;
            double last_swing_high = FindLastM15SwingHigh(5, swing_high_idx);
            if (last_swing_high > crtHigh && m15_rates[0].close > last_swing_high) // Price closes above previous swing high
            {
               bullish_state = MSS_CONFIRMED;
               LogMessage("Bullish: MSS Confirmed. Looking for FVG.", MSG_INFO);
            }
            break;
            }

         case MSS_CONFIRMED:
            {
            // Check for retracement into M15 FVG/OB
            double fvg_h = 0, fvg_l = 0;
            if (FindFVG_AfterMSS(0, fvg_h, fvg_l, BULLISH))
            {
               m15_fvg_high = fvg_h;
               m15_fvg_low = fvg_l;
               if (current_ask >= m15_fvg_low && current_ask <= m15_fvg_high)
               {
                  entrySignal = "BUY";
                  LogMessage("Bullish: Entry Signal - Retracement into FVG.", MSG_INFO);
                  // Execute trade if in automated mode
                  if (OperationalMode == FULLY_AUTOMATED)
                  {
                     double sl_price = m15_fvg_low;
                     double lot_size = CalculateLotSize(MathAbs(current_ask - sl_price));
                     double tp_price = current_ask + (current_ask - sl_price) * TakeProfit1_RR;
                     ExecuteTrade(ORDER_TYPE_BUY, lot_size, current_ask, sl_price, tp_price);
                     LogMessage("Executing BUY trade...", MSG_INFO);
                     tradeTakenToday = true;
                     tradesTodayCount++;
                  }
               }
            }
            break;
            }
      }
   }
   else if (determinedBias == BEARISH)
   {
      switch(bearish_state)
      {
         case MONITORING:
            {
            // Check for sweep of CRT High
            if (current_ask > crtHigh)
            {
               bearish_sweep_high = current_ask;
               bearish_state = SWEEP_DETECTED;
               LogMessage("Bearish: Sweep Detected at " + DoubleToString(bearish_sweep_high), MSG_INFO);
            }
            break;
            }

         case SWEEP_DETECTED:
            {
            // Check for Market Structure Shift (MSS) - M15 lower low after sweep
            int swing_low_idx = 0;
            double last_swing_low = FindLastM15SwingLow(5, swing_low_idx);
            if (last_swing_low < crtLow && m15_rates[0].close < last_swing_low) // Price closes below previous swing low
            {
               bearish_state = MSS_CONFIRMED;
               LogMessage("Bearish: MSS Confirmed. Looking for FVG.", MSG_INFO);
            }
            break;
            }

         case MSS_CONFIRMED:
            {
            // Check for retracement into M15 FVG/OB
            double fvg_h = 0, fvg_l = 0;
            if (FindFVG_AfterMSS(0, fvg_h, fvg_l, BEARISH))
            {
               m15_fvg_high = fvg_h;
               m15_fvg_low = fvg_l;
               if (current_bid <= m15_fvg_high && current_bid >= m15_fvg_low) // Price enters FVG/OB
               {
                  entrySignal = "SELL";
                  LogMessage("Bearish: Entry Signal - Retracement into FVG.", MSG_INFO);
                  // Execute trade if in automated mode
                  if (OperationalMode == FULLY_AUTOMATED)
                  {
                     double sl_price = m15_fvg_high;
                     double lot_size = CalculateLotSize(MathAbs(sl_price - current_bid));
                     double tp_price = current_bid - (sl_price - current_bid) * TakeProfit1_RR;
                     ExecuteTrade(ORDER_TYPE_SELL, lot_size, current_bid, sl_price, tp_price);
                     LogMessage("Executing SELL trade...", MSG_INFO);
                     tradeTakenToday = true;
                     tradesTodayCount++;
                  }
               }
            }
            break;
            }
      }
   }
  }


//+------------------------------------------------------------------+
//| Manage Open Positions (Breakeven, Trailing Stop, Multi-TP)       |
//+------------------------------------------------------------------+
void ManageOpenPositions() 
  {
    if(!position.SelectByMagic(_Symbol, 19914)) return;
    long t = position.PositionType();
    double op = position.PriceOpen();
    double sl = position.StopLoss();
    double tp = position.TakeProfit();
    double current_price = (t == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // --- Move to Breakeven after TP1 ---
    if(MoveToBE_After_TP1 && sl != op && ((t == POSITION_TYPE_BUY && current_price >= op + (tp-op)*TakeProfit1_RR) || (t == POSITION_TYPE_SELL && current_price <= op - (op-tp)*TakeProfit1_RR))) {
        trade.PositionModify(_Symbol, op, tp);
        LogMessage("Position moved to Breakeven.", MSG_INFO);
    }

    // --- Multi-Stage Take Profit and Partial Close ---
    if (UseMultiTP)
    {
        if (t == POSITION_TYPE_BUY)
        {
            // TP1 and Partial Close 1
            if (current_price >= op + (tp-op)*TakeProfit1_RR && position.Volume() > 0.01) // Ensure some volume remains
            {
                double volume_to_close = position.Volume() * PartialClose1_Percent;
                if(trade.PositionClose(position.Ticket(), volume_to_close))
                  {
                     LogMessage("Partial Close 1 executed at TP1 (BUY). Volume closed: " + DoubleToString(volume_to_close), MSG_INFO);
                  }
            }
        }
        else if (t == POSITION_TYPE_SELL)
        {
            // TP1 and Partial Close 1
            if (current_price <= op - (op-tp)*TakeProfit1_RR && position.Volume() > 0.01)
            {
                double volume_to_close = position.Volume() * PartialClose1_Percent;
                if(trade.PositionClose(position.Ticket(), volume_to_close))
                  {
                     LogMessage("Partial Close 1 executed at TP1 (SELL). Volume closed: " + DoubleToString(volume_to_close), MSG_INFO);
                  }
            }
            // TP2 and Partial Close 2
            if (current_price <= op - (op-tp)*TakeProfit2_RR && position.Volume() > 0.01)
            {
                double volume_to_close = position.Volume() * PartialClose2_Percent;
                if(trade.PositionClose(position.Ticket(), volume_to_close))
                  {
                     LogMessage("Partial Close 2 executed at TP2 (SELL). Volume closed: " + DoubleToString(volume_to_close), MSG_INFO);
                  }
            }
            // TP3 (Full Close)
            if (current_price <= op - (op-tp)*TakeProfit3_RR && position.Volume() > 0.01)
            {
                if (trade.PositionClose(position.Ticket()))
                {
                    LogMessage("Full Close executed at TP3 (SELL).", MSG_INFO);
                }
            }
        }
    }

    // --- Trailing Stop ---
    if (UseTrailingStop && sl != 0) // Check if SL is set and trailing stop is enabled
    {
        double new_sl = sl;
        if (t == POSITION_TYPE_BUY)
        {
            if (current_price - sl > TrailingStopPips * point)
            {
                new_sl = current_price - TrailingStopPips * point;
                if (new_sl > sl + TrailingStepPips * point) // Only modify if SL moves by at least TrailingStepPips
                {
                    if (trade.PositionModify(position.Ticket(), new_sl, tp))
                    {
                        LogMessage("Trailing Stop: BUY SL moved to " + DoubleToString(new_sl), MSG_INFO);
                    }
                }
            }
        }
        else if (t == POSITION_TYPE_SELL)
        {
            if (sl - current_price > TrailingStopPips * point)
            {
                new_sl = current_price + TrailingStopPips * point;
                if (new_sl < sl - TrailingStepPips * point) // Only modify if SL moves by at least TrailingStepPips
                {
                    if (trade.PositionModify(position.Ticket(), new_sl, tp))
                    {
                        LogMessage("Trailing Stop: SELL SL moved to " + DoubleToString(new_sl), MSG_INFO);
                    }
                }
            }
        }
    }
  }

//+------------------------------------------------------------------+
//| Get New York Time based on broker offset                         |
//+------------------------------------------------------------------+
datetime GetNYTime(datetime st=0) {if(st==0)st=TimeCurrent();return st+(GetNYGMTOffset()-Broker_GMT_Offset_Hours)*3600;}
long GetNYGMTOffset() {return -5;}
bool IsWithinKillzone() {datetime nt=GetNYTime();MqlDateTime ntm;TimeToStruct(nt,ntm);int sh,sm,eh,em;ParseTime(NY_Killzone_Start,sh,sm);ParseTime(NY_Killzone_End,eh,em);int now_m=ntm.hour*60+ntm.min,s_m=sh*60+sm,e_m=eh*60+em;return(now_m>=s_m&&now_m<=e_m);}

//+------------------------------------------------------------------+
//| Helper to parse time string (HH:MM)                              |
//+------------------------------------------------------------------+
void ParseTime(string ts,int&h,int&m) {string p[];if(StringSplit(ts,":",p)==2) {h=(int)StringToInteger(p[0]);m=(int)StringToInteger(p[1]);}}

//+------------------------------------------------------------------+
//| Calculate Lot Size based on Risk Percent                         |
//+------------------------------------------------------------------+
double CalculateLotSize(double sl_dist) {if(sl_dist<=0)return 0;double ra=AccountInfoDouble(ACCOUNT_BALANCE)*(RiskPercent/100.0),tv,ts;if(!SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE,tv)||!SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE,ts)||ts<=0)return 0;double lpl=(sl_dist/ts)*tv;if(lpl<=0)return 0;double l=ra/lpl,vs=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);l=MathFloor(l/vs)*vs;return fmin(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),fmax(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),l));}

//+------------------------------------------------------------------+
//| Drawing and UI functions                                         |
//+------------------------------------------------------------------+
void DrawRangeLines()
{
    string highLineName = "CRTHighLine";
    string lowLineName = "CRTLowLine";
    
    // Delete old lines to prevent clutter
    ObjectDelete(0, highLineName);
    ObjectDelete(0, lowLineName);

    // Calculate end time for the line (e.g., extend for 24 hours)
    datetime endTime = (datetime)(crtRangeCandleTime + 24 * 3600);

    // Create High Line
    ObjectCreate(0, highLineName, OBJ_TREND, 0, crtRangeCandleTime, crtHigh, endTime, crtHigh);
    ObjectSetInteger(0, highLineName, OBJPROP_COLOR, clrGold);
    ObjectSetInteger(0, highLineName, OBJPROP_STYLE, STYLE_DOT);
    ObjectSetInteger(0, highLineName, OBJPROP_WIDTH, 1);
    ObjectSetString(0, highLineName, OBJPROP_TEXT, "CRT High");

    // Create Low Line
    ObjectCreate(0, lowLineName, OBJ_TREND, 0, crtRangeCandleTime, crtLow, endTime, crtLow);
    ObjectSetInteger(0, lowLineName, OBJPROP_COLOR, clrGold);
    ObjectSetInteger(0, lowLineName, OBJPROP_STYLE, STYLE_DOT);
    ObjectSetInteger(0, lowLineName, OBJPROP_WIDTH, 1);
    ObjectSetString(0, lowLineName, OBJPROP_TEXT, "CRT Low");
}

void DrawHTFKeyLevelZone()
{
    string klRectName = "HTF_KL_Zone";
    ObjectDelete(0, klRectName);

    if (htf_kl_high > 0 && htf_kl_low > 0)
    {
        datetime now = TimeCurrent();
        ObjectCreate(0, klRectName, OBJ_RECTANGLE, 0, now, htf_kl_high, (datetime)(now + 24*3600), htf_kl_low);
        ObjectSetInteger(0, klRectName, OBJPROP_COLOR, clrLightSkyBlue);
        ObjectSetInteger(0, klRectName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, klRectName, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, klRectName, OBJPROP_BACK, true);
        ObjectSetInteger(0, klRectName, OBJPROP_FILL, true);
        ObjectSetInteger(0, klRectName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, klRectName, OBJPROP_ZORDER, 0);
        ObjectSetInteger(0, klRectName, OBJPROP_RAY_RIGHT, true);
    }
}

void DrawDOLTarget()
{
    string dolLineName = "DOLTargetLine";
    ObjectDelete(0, dolLineName);

    if (dol_target_price > 0)
    {
        datetime now = TimeCurrent();
        ObjectCreate(0, dolLineName, OBJ_HLINE, 0, now, dol_target_price);
        ObjectSetInteger(0, dolLineName, OBJPROP_COLOR, clrRed);
        ObjectSetInteger(0, dolLineName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, dolLineName, OBJPROP_WIDTH, 2);
        ObjectSetString(0, dolLineName, OBJPROP_TEXT, "DOL Target");
    }
}

void DrawTradeStateVisuals()
{
    string stateTextName = "TradeStateText";
    ObjectDelete(0, stateTextName);

    string stateStr = "";
    color stateColor = clrWhite;

    if (determinedBias == BULLISH)
    {
        switch(bullish_state)
        {
            case MONITORING: stateStr = "Bullish: Monitoring"; stateColor = clrLightGray; break;
            case SWEEP_DETECTED: stateStr = "Bullish: Sweep Detected"; stateColor = clrOrange; break;
            case MSS_CONFIRMED: stateStr = "Bullish: MSS Confirmed"; stateColor = clrGreen; break;
        }
    }
    else if (determinedBias == BEARISH)
    {
        switch(bearish_state)
        {
            case MONITORING: stateStr = "Bearish: Monitoring"; stateColor = clrLightGray; break;
            case SWEEP_DETECTED: stateStr = "Bearish: Sweep Detected"; stateColor = clrOrange; break;
            case MSS_CONFIRMED: stateStr = "Bearish: MSS Confirmed"; stateColor = clrRed; break;
        }
    }
    else
    {
        stateStr = "Bias: Neutral"; stateColor = clrLightGray;
    }

    ObjectCreate(0, stateTextName, OBJ_TEXT, 0, 0, 0);
    ObjectSetInteger(0, stateTextName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
    ObjectSetInteger(0, stateTextName, OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, stateTextName, OBJPROP_YDISTANCE, 10);
    ObjectSetString(0, stateTextName, OBJPROP_TEXT, stateStr);
    ObjectSetInteger(0, stateTextName, OBJPROP_COLOR, stateColor);
    ObjectSetInteger(0, stateTextName, OBJPROP_FONTSIZE, 12);
    ObjectSetString(0, stateTextName, OBJPROP_FONT, "Arial");
}

void CreateDashboard()
{
    // --- Main Panel Background ---
    ObjectCreate(0, dashboardID + "Panel", OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, dashboardID + "Panel", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, dashboardID + "Panel", OBJPROP_XDISTANCE, UI_PANEL_X);
    ObjectSetInteger(0, dashboardID + "Panel", OBJPROP_YDISTANCE, UI_PANEL_Y);
    ObjectSetInteger(0, dashboardID + "Panel", OBJPROP_XSIZE, UI_PANEL_WIDTH);
    ObjectSetInteger(0, dashboardID + "Panel", OBJPROP_YSIZE, UI_PANEL_HEIGHT);
    ObjectSetInteger(0, dashboardID + "Panel", OBJPROP_BGCOLOR, CLR_PANEL_BG);
    ObjectSetInteger(0, dashboardID + "Panel", OBJPROP_BORDER_COLOR, CLR_PANEL_BORDER);
    ObjectSetInteger(0, dashboardID + "Panel", OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, dashboardID + "Panel", OBJPROP_ZORDER, 0);

    // --- Tabs ---
    string tabNames[] = {"Overview", "Settings", "Performance", "Logs"};
    for (int i = 0; i < ArraySize(tabNames); i++)
    {
        string tabObjName = dashboardID + "Tab_" + IntegerToString(i);
        ObjectCreate(0, tabObjName, OBJ_BUTTON, 0, 0, 0);
        ObjectSetInteger(0, tabObjName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, tabObjName, OBJPROP_XDISTANCE, UI_PANEL_X + i * UI_TAB_WIDTH);
        ObjectSetInteger(0, tabObjName, OBJPROP_YDISTANCE, UI_PANEL_Y + UI_PANEL_HEIGHT);
        ObjectSetInteger(0, tabObjName, OBJPROP_XSIZE, UI_TAB_WIDTH);
        ObjectSetInteger(0, tabObjName, OBJPROP_YSIZE, UI_TAB_HEIGHT);
        ObjectSetString(0, tabObjName, OBJPROP_TEXT, tabNames[i]);
        ObjectSetInteger(0, tabObjName, OBJPROP_COLOR, CLR_BUTTON_TEXT);
        ObjectSetInteger(0, tabObjName, OBJPROP_BGCOLOR, (i == currentTab) ? CLR_TAB_ACTIVE_BG : CLR_TAB_INACTIVE_BG);
        ObjectSetInteger(0, tabObjName, OBJPROP_BORDER_COLOR, CLR_PANEL_BORDER);
        ObjectSetInteger(0, tabObjName, OBJPROP_SELECTABLE, true);
        ObjectSetInteger(0, tabObjName, OBJPROP_ZORDER, 1);
    }

    // --- Content for Overview Tab (initial view) ---
    int yPos = UI_PANEL_Y + UI_TAB_HEIGHT + UI_CONTROL_SPACING;
    string labels[] = {"Bias", "DOL Target", "HTF KL Zone", "Bullish State", "Bearish State", "Last Signal"};
    for(int i = 0; i < ArraySize(labels); i++)
    {
        // Label for the static text
        ObjectCreate(0, dashboardID + labels[i] + "_label", OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, dashboardID + labels[i] + "_label", OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, dashboardID + labels[i] + "_label", OBJPROP_XDISTANCE, UI_PANEL_X + 10);
        ObjectSetInteger(0, dashboardID + labels[i] + "_label", OBJPROP_YDISTANCE, yPos);
        ObjectSetString(0, dashboardID + labels[i] + "_label", OBJPROP_TEXT, labels[i] + ":");
        ObjectSetInteger(0, dashboardID + labels[i] + "_label", OBJPROP_COLOR, CLR_TEXT);
        ObjectSetInteger(0, dashboardID + labels[i] + "_label", OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, dashboardID + labels[i] + "_label", OBJPROP_ZORDER, 1);

        // Label for the dynamic value
        ObjectCreate(0, dashboardID + labels[i] + "_value", OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, dashboardID + labels[i] + "_value", OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, dashboardID + labels[i] + "_value", OBJPROP_XDISTANCE, UI_PANEL_X + 120);
        ObjectSetInteger(0, dashboardID + labels[i] + "_value", OBJPROP_YDISTANCE, yPos);
        ObjectSetString(0, dashboardID + labels[i] + "_value", OBJPROP_TEXT, "...");
        ObjectSetInteger(0, dashboardID + labels[i] + "_value", OBJPROP_COLOR, CLR_TEXT);
        ObjectSetInteger(0, dashboardID + labels[i] + "_value", OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, dashboardID + labels[i] + "_value", OBJPROP_ZORDER, 1);
        yPos += UI_CONTROL_HEIGHT + UI_CONTROL_SPACING;
    }

    // --- Example of a button for Settings tab (initially hidden) ---
    ObjectCreate(0, dashboardID + "ToggleAutoModeBtn", OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, dashboardID + "ToggleAutoModeBtn", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, dashboardID + "ToggleAutoModeBtn", OBJPROP_XDISTANCE, UI_PANEL_X + 10);
    ObjectSetInteger(0, dashboardID + "ToggleAutoModeBtn", OBJPROP_YDISTANCE, UI_PANEL_Y + UI_TAB_HEIGHT + 10);
    ObjectSetInteger(0, dashboardID + "ToggleAutoModeBtn", OBJPROP_XSIZE, 150);
    ObjectSetInteger(0, dashboardID + "ToggleAutoModeBtn", OBJPROP_YSIZE, UI_CONTROL_HEIGHT);
    ObjectSetString(0, dashboardID + "ToggleAutoModeBtn", OBJPROP_TEXT, "Toggle Auto Mode");
    ObjectSetInteger(0, dashboardID + "ToggleAutoModeBtn", OBJPROP_COLOR, CLR_BUTTON_TEXT);
    ObjectSetInteger(0, dashboardID + "ToggleAutoModeBtn", OBJPROP_BGCOLOR, CLR_BUTTON_BG);
    ObjectSetInteger(0, dashboardID + "ToggleAutoModeBtn", OBJPROP_BORDER_COLOR, CLR_PANEL_BORDER);
    ObjectSetInteger(0, dashboardID + "ToggleAutoModeBtn", OBJPROP_SELECTABLE, true);
    ObjectSetInteger(0, dashboardID + "ToggleAutoModeBtn", OBJPROP_ZORDER, 1);
    ObjectSetInteger(0, dashboardID + "ToggleAutoModeBtn", OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS); // Hidden by default
}

void UpdateDashboard()
{
    // --- Update Tab Colors ---
    string tabNames[] = {"Overview", "Settings", "Performance", "Logs"};
    for (int i = 0; i < ArraySize(tabNames); i++)
    {
        string tabObjName = dashboardID + "Tab_" + IntegerToString(i);
        ObjectSetInteger(0, tabObjName, OBJPROP_BGCOLOR, (i == currentTab) ? CLR_TAB_ACTIVE_BG : CLR_TAB_INACTIVE_BG);
    }

    // --- Update Content based on currentTab ---
    // Hide all content elements first, then show only for the active tab
    string allLabels[] = {"Bias", "DOL Target", "HTF KL Zone", "Bullish State", "Bearish State", "Last Signal"};
    for(int i = 0; i < ArraySize(allLabels); i++)
    {
        ObjectSetInteger(0, dashboardID + allLabels[i] + "_label", OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
        ObjectSetInteger(0, dashboardID + allLabels[i] + "_value", OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
    }
    ObjectSetInteger(0, dashboardID + "ToggleAutoModeBtn", OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);

    if (currentTab == TAB_OVERVIEW)
    {
        // --- Update Dynamic Values for Overview Tab ---
        string bias_str = EnumToString(determinedBias);
        string dol_str = (dol_target_price > 0) ? DoubleToString(dol_target_price, _Digits) : "N/A";
        string kl_zone_str = (htf_kl_low > 0) ? DoubleToString(htf_kl_low, _Digits) + " - " + DoubleToString(htf_kl_high, _Digits) : "N/A";
        string bullish_state_str = EnumToString(bullish_state);
        string bearish_state_str = EnumToString(bearish_state);
        string signal_str = (entrySignal != "") ? entrySignal : "None";

        ObjectSetString(0, dashboardID + "Bias_value", OBJPROP_TEXT, bias_str);
        ObjectSetString(0, dashboardID + "DOL Target_value", OBJPROP_TEXT, dol_str);
        ObjectSetString(0, dashboardID + "HTF KL Zone_value", OBJPROP_TEXT, kl_zone_str);
        ObjectSetString(0, dashboardID + "Bullish State_value", OBJPROP_TEXT, bullish_state_str);
        ObjectSetString(0, dashboardID + "Bearish State_value", OBJPROP_TEXT, bearish_state_str);
        ObjectSetString(0, dashboardID + "Last Signal_value", OBJPROP_TEXT, signal_str);

        for(int i = 0; i < ArraySize(allLabels); i++)
        {
            ObjectSetInteger(0, dashboardID + allLabels[i] + "_label", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
            ObjectSetInteger(0, dashboardID + allLabels[i] + "_value", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
        }
    }
    else if (currentTab == TAB_SETTINGS)
    {
        ObjectSetInteger(0, dashboardID + "ToggleAutoModeBtn", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
        // TODO: Add more settings controls here
    }
    else if (currentTab == TAB_PERFORMANCE)
    {
        // TODO: Add performance metrics here
    }
    else if (currentTab == TAB_LOGS)
    {
        // TODO: Add log display here
    }
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    if (id == CHARTEVENT_CLICK)
    {
        // Handle tab clicks
        string tabNames[] = {"Overview", "Settings", "Performance", "Logs"};
        for (int i = 0; i < ArraySize(tabNames); i++)
        {
            string tabObjName = dashboardID + "Tab_" + IntegerToString(i);
            if (sparam == tabObjName)
            {
                currentTab = (ENUM_UI_TAB)i;
                UpdateDashboard();
                ChartRedraw();
                return;
            }
        }

        // Handle button clicks
        if (sparam == dashboardID + "ToggleAutoModeBtn")
        {
            if (OperationalMode == SIGNALS_ONLY || OperationalMode == HYBRID_MODE)
            {
                OperationalMode = FULLY_AUTOMATED;
                Print("Operational Mode set to FULLY_AUTOMATED");
            }
            else
            {
                OperationalMode = SIGNALS_ONLY;
                Print("Operational Mode set to SIGNALS_ONLY");
            }
            UpdateDashboard();
            ChartRedraw();
            return;
        }
    }
}




//+------------------------------------------------------------------+
//|                     Other Helper Functions                       |
//+------------------------------------------------------------------+
double FindLastM15SwingHigh(int l,int&idx) {MqlRates r[];if(CopyRates(_Symbol,PERIOD_M15,0,l,r)<3)return 0;ArraySetAsSeries(r,true);for(int i=1;i<l-1;i++) {if(r[i].high>r[i-1].high&&r[i].high>r[i+1].high) {idx=i;return r[i].high;}} return 0;}
double FindLastM15SwingLow(int l,int&idx) {MqlRates r[];if(CopyRates(_Symbol,PERIOD_M15,0,l,r)<3)return 0;ArraySetAsSeries(r,true);for(int i=1;i<l-1;i++) {if(r[i].low<r[i-1].low&&r[i].low<r[i+1].low) {idx=i;return r[i].low;}} return 0;}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool FindFVG_AfterMSS(int start_bar,double&h,double&l,ENUM_DAILY_BIAS b)
{
   MqlRates r[];
   if(CopyRates(_Symbol,PERIOD_M15,0,start_bar+50,r)<3) return false;
   ArraySetAsSeries(r,true);
   for(int i=start_bar; i < ArraySize(r)-2; i++)
   {
      if(b==BULLISH && r[i+2].high < r[i].low)
      {
         h=r[i].low;
         l=r[i+2].high;
         return true;
      }
      if(b==BEARISH && r[i+2].low > r[i].high)
      {
         h=r[i+2].low;
         l=r[i].high;
         return true;
      }
   }
   return false;
}




//+------------------------------------------------------------------+
//| Execute Trade                                                    |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE order_type, double lots, double price, double sl, double tp)
  {
   if (order_type == ORDER_TYPE_BUY)
     {
      if(!trade.Buy(lots, _Symbol, price, sl, tp))
        {
         LogMessage("Failed to send BUY order: " + IntegerToString(trade.ResultRetcode()) + " - " + IntegerToString(trade.ResultDeal()) + " - " + trade.ResultComment(), MSG_ERROR);
        }
     }
   else if (order_type == ORDER_TYPE_SELL)
     {
      if(!trade.Sell(lots, _Symbol, price, sl, tp))
        {
         LogMessage("Failed to send SELL order: " + IntegerToString(trade.ResultRetcode()) + " - " + IntegerToString(trade.ResultDeal()) + " - " + trade.ResultComment(), MSG_ERROR);
        }
     }
  }

//+------------------------------------------------------------------+
//|                     Advanced Filter Functions                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Checks the weekly profile                                        |
//+------------------------------------------------------------------+
bool CheckWeeklyProfile()
  {
   if (!Filter_By_WeeklyProfile)
      return true; // Filter is disabled

   MqlRates w1_rates[];
   if(CopyRates(_Symbol, PERIOD_W1, 0, 2, w1_rates) < 2)
     {
      LogMessage("Could not get W1 data for weekly profile analysis.", MSG_WARNING);
      return true; // Allow trading if data is not available
     }

   // Simple check for trending vs ranging for now
   // This can be significantly expanded with more complex logic
   double week_range = w1_rates[0].high - w1_rates[0].low;
   double prev_week_range = w1_rates[1].high - w1_rates[1].low;

   if (WeeklyProfileType == WP_TRENDING)
     {
      // If current week's range is significantly larger than previous, might be trending
      if (week_range > prev_week_range * 1.5)
         return true;
     }
   else if (WeeklyProfileType == WP_RANGE)
     {
      // If current week's range is similar or smaller, might be ranging
      if (week_range < prev_week_range * 1.2 && week_range > prev_week_range * 0.8)
         return true;
     }
   else if (WeeklyProfileType == WP_REVERSAL)
     {
      // This would require more complex logic, e.g., pin bars, engulfing patterns
      // For now, we'll just return true, but this is a placeholder for future development
      return true;
     }

   return false; // Filtered out
  }

//+------------------------------------------------------------------+
//| Checks for SMT Divergence with a correlated symbol               |
//+------------------------------------------------------------------+
bool CheckSMTDivergence()
  {
   if (!Filter_By_SMTDivergence)
      return true; // Filter is disabled

   if (CorrelatedSymbol == _Symbol)
     {
      LogMessage("Correlated Symbol cannot be the same as the current symbol.", MSG_WARNING);
      return true; // Allow trading if misconfigured
     }

   MqlRates current_rates[];
   MqlRates correlated_rates[];

   // Get recent M15 data for current symbol
   if(CopyRates(_Symbol, PERIOD_M15, 0, 5, current_rates) < 5)
     {
      LogMessage("Could not get current symbol M15 data for SMT divergence.", MSG_WARNING);
      return true;
     }

   // Get recent M15 data for correlated symbol
   if(CopyRates(CorrelatedSymbol, PERIOD_M15, 0, 5, correlated_rates) < 5)
     {
      LogMessage("Could not get correlated symbol M15 data for SMT divergence.", MSG_WARNING);
      return true;
     }

   // Simple SMT Divergence check (can be expanded)
   // Example: Check if current symbol makes a higher high while correlated makes a lower high (bearish divergence)
   // Or if current symbol makes a lower low while correlated makes a higher low (bullish divergence)

   // Assuming current_rates[0] is the current candle, [1] is previous, etc.
   // This is a very basic example and needs significant refinement for real-world use

   // Bearish Divergence: Current symbol HH, Correlated LH
   if (current_rates[0].high > current_rates[1].high && correlated_rates[0].high < correlated_rates[1].high)
     {
      LogMessage("Potential Bearish SMT Divergence detected.", MSG_INFO);
      return false; // Filter out if bearish divergence and we are looking for buy
     }

   // Bullish Divergence: Current symbol LL, Correlated HL
   if (current_rates[0].low < current_rates[1].low && correlated_rates[0].low > correlated_rates[1].low)
     {
      LogMessage("Potential Bullish SMT Divergence detected.", MSG_INFO);
      return false; // Filter out if bullish divergence and we are looking for sell
     }

   return true; // No significant divergence detected or filter is off
  }

//+------------------------------------------------------------------+
//| Checks for High-Impact News Events                               |
//+------------------------------------------------------------------+
bool CheckHighImpactNews()
  {
   if (!Filter_By_HighImpactNews)
      return true; // Filter is disabled

   // Simple news filter implementation
   // In a real implementation, you would integrate with a news feed
   // For now, we'll just return true to allow trading
   LogMessage("News filter is enabled but not implemented - allowing trade", MSG_INFO);
   return true; // No high-impact news found within the lookback period
  }

//+------------------------------------------------------------------+
//| Custom Logging Function                                          |
//+------------------------------------------------------------------+
void LogMessage(string message, ENUM_MESSAGE_TYPE type = MSG_INFO)
  {
   string prefix = "";
   switch(type)
     {
      case MSG_INFO:    prefix = "[INFO]";    break;
      case MSG_WARNING: prefix = "[WARN]";    break;
      case MSG_ERROR:   prefix = "[ERROR]";   break;
      case MSG_DEBUG:   prefix = "[DEBUG]";   break;
     }
   PrintFormat("%s %s", prefix, message);
  }




//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


