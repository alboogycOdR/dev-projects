//+------------------------------------------------------------------+
//|            CRT_Session_Open_Scalper_v5_2.mq5                      |
//|                        Improved Version                          |
//|                                                                  |
//|  This EA implements the CRT scalping model using a 15‑minute     |
//|  opening range and executes trades on a 1‑minute chart with      |
//|  optional MSS or CISD confirmation. The code in this version     |
//|  addresses several shortcomings found in earlier revisions:      |
//|                                                                  |
//|  * Missing definitions (object_prefix, symbol_states) have been   |
//|    defined.                                                      |
//|  * Function signatures and array bounds have been corrected.      |
//|  * Additional input validation and error handling have been       |
//|    implemented to catch invalid settings or server errors.        |
//|  * Extensive comments have been added throughout the code to      |
//|    explain the purpose of variables and logic.                    |
//|                                                                  |
//|  NOTE: This EA is for educational purposes only. Trading on live  |
//|  accounts involves risk.                                         |
//+------------------------------------------------------------------+
#property copyright "Improved Version by The Synthesis"
#property link      "https://beta.character.ai/"
#property version   "5.20"
#property strict
#property description "Improved EA for the CRT Scalping Model with better error handling and validation."

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <ChartObjects\ChartObjectsTxtControls.mqh>

//-----------------------------------------------------------------------------
//  ENUMERATIONS AND STRUCTURES
//
//  Enumerations declare named constants to improve readability of code.
//  A structure is used to store the current trade setup information for
//  bullish and bearish scenarios.  Additional structures are defined to
//  support a simple dashboard for a single symbol.  Multi‑symbol trading
//  is outside the scope of this example but can be added by enlarging
//  the symbol_states array and iterating over it.
//-----------------------------------------------------------------------------

//--- Enumerations for user inputs
enum ENUM_SESSION_FOCUS      { LONDON_OPEN, NEW_YORK_OPEN };
enum ENUM_OPERATIONAL_MODE   { SIGNALS_ONLY, FULLY_AUTOMATED };
enum ENUM_SETUP_STATE        { IDLE, AWAITING_SWEEP, AWAITING_CONFIRMATION, AWAITING_ENTRY, INVALID };
enum ENUM_ENTRY_MODEL        { CONFIRM_WITH_MSS, CONFIRM_WITH_CISD };
enum ENUM_BIAS               { NEUTRAL, BULLISH, BEARISH };
enum ENUM_WEEKLY_PROFILE     { NONE, CLASSIC_EXPANSION, MIDWEEK_REVERSAL, CONSOLIDATION_REVERSAL };
enum ENUM_POSITION           { POS_TOP_RIGHT, POS_TOP_LEFT, POS_MIDDLE_RIGHT, POS_MIDDLE_LEFT, POS_BOTTOM_RIGHT, POS_BOTTOM_LEFT };
enum ENUM_THEME              { THEME_DARK, THEME_LIGHT, THEME_BLUEPRINT };

//--- Structure to hold the state of an individual trade setup
struct SetupState
{
   ENUM_SETUP_STATE  state;        // current stage in the state machine
   double            crt_high;     // CRT range high
   double            crt_low;      // CRT range low
   double            mss_level;    // last swing level for MSS confirmation
   double            fvg_high;     // top of fair value gap
   double            fvg_low;      // bottom of fair value gap
   double            sweep_price;  // price that swept the range
   ENUM_BIAS         h4_bias;      // detected H4 bias
};

//--- Structure to hold the status of a symbol for the dashboard
struct SymbolState
{
   string        symbol_name;      // symbol being monitored
   ENUM_BIAS     h4_bias;          // H4 bias for display
   ENUM_SETUP_STATE bull_state;    // state of bullish setup (IDLE->INVALID)
   ENUM_SETUP_STATE bear_state;    // state of bearish setup (IDLE->INVALID)
};

//-----------------------------------------------------------------------------
//  GLOBAL OBJECTS AND VARIABLES
//
//  The EA uses global objects from the Trade library to send and manage
//  orders.  Additional global variables hold configuration and runtime
//  information.  Default values are provided for optional parameters.  These
//  values can be overridden by user input.  The object_prefix is used to
//  namespace dashboard objects on the chart.
//-----------------------------------------------------------------------------

//--- Trade objects
CTrade        trade;        // order placement/modification helper
CPositionInfo position;     // information about open positions

//--- Setup states for bullish and bearish trades on the current symbol
SetupState   bull_setup;
SetupState   bear_setup;

//--- Symbol state array for the dashboard (single symbol only)
SymbolState  symbol_states[1];

//--- Dashboard identifier prefix (names all graphical objects)
string       object_prefix = "CRT_SCALPER_";

//--- Dashboard colours (initialised in SetThemeColors())
color        c_bg, c_header, c_text, c_bull_bias, c_bear_bias, c_neutral_bias;
color        c_state_sweep, c_state_confirm, c_state_entry;

//--- Icons for various states on the dashboard
string       icon_bull = "▲";
string       icon_bear = "▼";
string       icon_neutral = "↔";
string       icon_wait = "—";

//--- Other global variables
int          tradesTodayCount = 0;    // number of trades executed today
string       dashboardID = "CRT_SCALPER_"; // used to delete dashboard on deinit

//--- Copies of input parameters for internal use
//    Input variables in MQL5 are constant and cannot be modified at run time.
//    To allow validation and adjustment, we copy them to these globals during
//    OnInit().  Always reference gRiskPercent, gTakeProfitRR and
//    gMaxTradesPerDay in calculations rather than the input values directly.
double       gRiskPercent    = 0.0;
double       gTakeProfitRR   = 0.0;
int          gMaxTradesPerDay = 0;

//--- Magic number used when opening positions.  It should be unique to this EA
//    instance to avoid interference with other robots.  Adjust if multiple
//    instances of this EA are running on the same symbol.
long         MAGIC_NUMBER    = 2024052;

//-----------------------------------------------------------------------------
//  INPUT PARAMETERS
//
//  Parameters are grouped to logically separate model settings, risk management,
//  advanced filters and UI preferences.  Validation checks are performed in
//  OnInit() to ensure sensible values.
//-----------------------------------------------------------------------------

input group                "CRT Model Settings";
input ENUM_SESSION_FOCUS   SessionToTrade          = NEW_YORK_OPEN;   // Which session opening candle to trade?
input ENUM_ENTRY_MODEL     EntryLogicModel         = CONFIRM_WITH_MSS;  // Entry confirmation logic
input int                  Broker_GMT_Offset_Hours = 3;                 // Broker's GMT offset (hours)

input group                "Risk & Trade Management";
input double               RiskPercent             = 0.5;               // Risk per trade (% of account balance)
input double               TakeProfit_RR           = 2.0;               // Take profit (as risk:reward ratio)
input bool                 MoveToBE_At_1R          = true;              // Move stop to breakeven at 1R?
input int                  MaxTradesPerDay         = 1;                 // Maximum trades per day

input group                "Advanced Contextual Filters";
input bool                 Filter_By_Weekly_Profile= false;             // Enable weekly profile filter?
input ENUM_WEEKLY_PROFILE  Assumed_Weekly_Profile  = NONE;              // Assumed weekly profile for the day
input bool                 Use_SMT_Divergence_Filter= false;            // Enable SMT divergence filter?
input string               SMT_Correlated_Symbol   = "DXY";            // Correlated symbol for SMT check

input group                "Operational Mode & UI";
input ENUM_OPERATIONAL_MODE OperationalMode         = SIGNALS_ONLY;      // Signals only or fully automated mode
input ENUM_THEME           i_theme                 = THEME_DARK;        // Dashboard colour theme
input ENUM_POSITION        i_table_pos             = POS_TOP_RIGHT;     // Dashboard position on chart
input bool                 EnableVerboseLogging    = true;              // Enable detailed journal logs?

//-----------------------------------------------------------------------------
//  INPUT VALIDATION
//
//  Validate user inputs during EA initialization.  If invalid values are
//  detected, adjust them to reasonable defaults and inform the user via
//  journal messages.  This reduces the risk of unexpected behaviour.
//-----------------------------------------------------------------------------

// Validate user inputs and populate internal copies.  Input variables in MQL5
// are constant; therefore we cannot modify them directly.  Instead we assign
// validated values to the global variables gRiskPercent, gTakeProfitRR and
// gMaxTradesPerDay.  If a value falls outside acceptable bounds, a default
// value is used and a warning is printed.
bool ValidateInputs()
{
   bool ok = true;
   // Risk percent: must be within (0,10].  Use 0.5% by default.
   if(RiskPercent <= 0.0 || RiskPercent > 10.0)
   {
      Print("Invalid RiskPercent value (", RiskPercent, "), using default 0.5%");
      gRiskPercent = 0.5;
      ok = false;
   }
   else
      gRiskPercent = RiskPercent;
   // Take profit ratio: must be >0.1.  Use 2.0 by default.
   if(TakeProfit_RR <= 0.1)
   {
      Print("TakeProfit_RR too low (", TakeProfit_RR, "), using default 2.0");
      gTakeProfitRR = 2.0;
      ok = false;
   }
   else
      gTakeProfitRR = TakeProfit_RR;
   // Max trades per day: between 1 and 10.  Use 1 by default.
   if(MaxTradesPerDay < 1 || MaxTradesPerDay > 10)
   {
      Print("MaxTradesPerDay out of range (", MaxTradesPerDay, "), using default 1");
      gMaxTradesPerDay = 1;
      ok = false;
   }
   else
      gMaxTradesPerDay = MaxTradesPerDay;
   return ok;
}

//-----------------------------------------------------------------------------
//  EVENT HANDLERS
//
//  OnInit() is called once when the EA starts.  It performs initialisation
//  tasks such as resetting daily variables, validating inputs, setting colours
//  and constructing the dashboard.  A timer is set to trigger every second.
//  OnDeinit() cleans up on removal.  OnTimer() contains the main logic and
//  executes once per second.
//-----------------------------------------------------------------------------

int OnInit()
{
   Print("CRT Session Open Scalper v5.2 Initializing...");
   // Validate user inputs and set internal copies
   ValidateInputs();
   
   // Set the unique magic number for this EA
   trade.SetExpertMagicNumber(MAGIC_NUMBER);
   trade.SetTypeFillingBySymbol(_Symbol);
   
   // Initialise symbol state for dashboard (single symbol)
   symbol_states[0].symbol_name = _Symbol;
   symbol_states[0].h4_bias = NEUTRAL;
   symbol_states[0].bull_state = IDLE;
   symbol_states[0].bear_state = IDLE;
   
   // Reset daily variables and bias
   ResetDailyVariables();
   
   // Apply colour theme and build dashboard
   SetThemeColors();
   CreateDashboard();
   
   // Set timer to run every second
   EventSetTimer(1);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   Print("CRT Scalper Deinitializing...");
   // Kill timer event
   EventKillTimer();
   // Delete dashboard objects
   ObjectsDeleteAll(0, dashboardID);
}

//--- Main timer loop: runs every second
void OnTimer()
{
   static datetime lastM1Bar = 0;
   // Only process on new M1 bar
   datetime currentBarTime = iTime(_Symbol, PERIOD_M1, 0);
   if(currentBarTime <= lastM1Bar)
      return;
   lastM1Bar = currentBarTime;
   
   // Reset variables at start of new day
   static int last_day = -1;
   // Determine day of year using MqlDateTime structure
   MqlDateTime dt_day;
   TimeToStruct(TimeCurrent(), dt_day);
   int current_day = dt_day.day_of_year;
   if(last_day != current_day)
   {
      ResetDailyVariables();
      last_day = current_day;
   }
   // Determine the CRT range if not already set
   if(bull_setup.crt_high == 0.0)
      SetCRTRange();
   
   // Check for entry only if range is defined, inside killzone and trade limit not exceeded
   if(bull_setup.crt_high > 0.0 && tradesTodayCount < gMaxTradesPerDay && IsWithinKillzone())
   {
      CheckForEntry();
   }
   // Update dashboard with latest states
   UpdateDashboard();
   // Manage any open positions (move to breakeven etc.)
   ManageOpenPositions();
}

//-----------------------------------------------------------------------------
//  DAILY RESET AND HTF LOGIC
//
//  ResetDailyVariables() clears the state machine at the start of a new day and
//  calls AnalyzeHigherTimeframes() to detect the current bias.  SetCRTRange()
//  searches the last 15‑minute bars for the opening candle of the chosen
//  session and records the high and low of that candle to define the CRT range.
//-----------------------------------------------------------------------------

// Reset daily variables and calculate higher‑timeframe bias
void ResetDailyVariables()
{
   if(EnableVerboseLogging) Print("Resetting daily variables and scanning for CRT range...");
   // Reset state machine and range values
   bull_setup.state = IDLE;
   bear_setup.state = IDLE;
   bull_setup.crt_high = 0.0;
   bull_setup.crt_low  = 0.0;
   bear_setup.crt_high = 0.0;
   bear_setup.crt_low  = 0.0;
   bull_setup.mss_level = 0.0;
   bear_setup.mss_level = 0.0;
   tradesTodayCount = 0;
   // Determine H4 bias
   AnalyzeHigherTimeframes();
}

// Determine the CRT range using the chosen session's opening candle
void SetCRTRange()
{
   // If range already set, skip
   if(bull_setup.crt_high > 0.0)
      return;
   
   // Determine target hour and minute for chosen session
   int target_hour = 0;
   int target_min  = 0;
   if(SessionToTrade == LONDON_OPEN)
   {
      target_hour = 3;
      target_min  = 0;
   }
   else // NEW_YORK_OPEN
   {
      target_hour = 9;
      target_min  = 30;
   }
   
   // Copy last 100 M15 candles
   MqlRates m15_rates[];
   ArraySetAsSeries(m15_rates, true);
   if(CopyRates(_Symbol, PERIOD_M15, 0, 100, m15_rates) <= 0)
      return;
   
   // Iterate backwards to find the first bar that matches the session window
   for(int i = ArraySize(m15_rates) - 1; i >= 0; i--)
   {
      // Convert bar time to New York time (using simple GMT offset; adjust manually for DST if required)
      datetime ny_time = GetNYTime(m15_rates[i].time);
      MqlDateTime tm_ny;
      TimeToStruct(ny_time, tm_ny);
      // Check if bar falls within the start of the session (within the first 15 minutes)
      if(tm_ny.hour == target_hour && tm_ny.min >= target_min && tm_ny.min < target_min + 15)
      {
         bull_setup.crt_high = bear_setup.crt_high = m15_rates[i].high;
         bull_setup.crt_low  = bear_setup.crt_low  = m15_rates[i].low;
         if(EnableVerboseLogging)
            PrintFormat("CRT range set: High=%.5f Low=%.5f", bull_setup.crt_high, bull_setup.crt_low);
         DrawRangeLines();
         return;
      }
   }
}

// Determine H4 bias by inspecting last two H4 candles
void AnalyzeHigherTimeframes()
{
   MqlRates h4_rates[];
   ArraySetAsSeries(h4_rates, true);
   // Need at least 2 H4 bars
   if(CopyRates(_Symbol, PERIOD_H4, 0, 3, h4_rates) < 2)
   {
      bull_setup.h4_bias = bear_setup.h4_bias = NEUTRAL;
      return;
   }
   // Current and previous H4 candles
   double c0h = h4_rates[0].high;
   double c0l = h4_rates[0].low;
   double c0c = h4_rates[0].close;
   double c1h = h4_rates[1].high;
   double c1l = h4_rates[1].low;
   // Determine bias: if current candle engulfs previous, bias is neutral
   if(c0h > c1h && c0l < c1l)
   {
      bull_setup.h4_bias = bear_setup.h4_bias = NEUTRAL;
   }
   else if(c0h > c1h && c0c <= c1h)
   {
      bull_setup.h4_bias = bear_setup.h4_bias = BEARISH;
   }
   else if(c0l < c1l && c0c >= c1l)
   {
      bull_setup.h4_bias = bear_setup.h4_bias = BULLISH;
   }
   else
   {
      bull_setup.h4_bias = bear_setup.h4_bias = NEUTRAL;
   }
   // Update symbol state for dashboard
   symbol_states[0].h4_bias = bull_setup.h4_bias;
}

//-----------------------------------------------------------------------------
//  ENTRY LOGIC
//
//  The CheckForEntry() function implements the state machine for both bullish
//  and bearish setups.  It uses the M1 timeframe to detect sweeps, confirmation
//  signals (MSS or CISD) and fair value gaps.  Helper functions ensure
//  separation of concerns and readability.
//-----------------------------------------------------------------------------

void CheckForEntry()
{
   MqlRates m1_rates[];
   ArraySetAsSeries(m1_rates, true);
   // Copy last 25 M1 bars; need at least 25 for swing/FVG logic
   if(CopyRates(_Symbol, PERIOD_M1, 0, 25, m1_rates) < 25)
      return;
   
   double high = m1_rates[0].high;
   double low  = m1_rates[0].low;
   
   //---------------------------------------------------------------
   // Bullish logic
   //---------------------------------------------------------------
   if(bull_setup.state < INVALID && bull_setup.h4_bias == BULLISH)
   {
      switch(bull_setup.state)
      {
         // IDLE: wait for sweep below CRT low
         case IDLE:
            if(low < bull_setup.crt_low)
            {
               if(!CheckFilters(true))
               {
                  bull_setup.state = INVALID;
                  break;
               }
               bull_setup.sweep_price = low;
               bull_setup.state = AWAITING_CONFIRMATION;
               if(EnableVerboseLogging)
                  Print("Bullish sweep detected; awaiting confirmation.");
            }
            break;
         // Confirmation: MSS or CISD
         case AWAITING_CONFIRMATION:
            if(EntryLogicModel == CONFIRM_WITH_MSS)
            {
               bull_setup.mss_level = FindLastSwing(m1_rates, true);
               if(bull_setup.mss_level > 0.0 && high > bull_setup.mss_level)
               {
                  if(FindFVG(m1_rates, bull_setup, true))
                  {
                     bull_setup.state = AWAITING_ENTRY;
                     if(EnableVerboseLogging)
                        Print("Bullish MSS confirmed; awaiting entry into FVG.");
                  }
               }
            }
            else // CONFIRM_WITH_CISD
            {
               if(CheckCISD(m1_rates, true))
               {
                  if(FindFVG(m1_rates, bull_setup, true))
                  {
                     bull_setup.state = AWAITING_ENTRY;
                     if(EnableVerboseLogging)
                        Print("Bullish CISD confirmed; awaiting entry into FVG.");
                  }
               }
            }
            break;
         // Awaiting entry: price returns into FVG high; then trade
         case AWAITING_ENTRY:
            if(low < bull_setup.fvg_high)
            {
               if(OperationalMode == SIGNALS_ONLY)
               {
                  Alert(_Symbol, " Bullish setup detected!");
               }
               else
               {
                  ExecuteTrade(true);
               }
               // Invalidate setups to prevent double entries
               bull_setup.state = INVALID;
               bear_setup.state = INVALID;
            }
            break;
         default:
            break;
      }
   }
   //---------------------------------------------------------------
   // Bearish logic
   //---------------------------------------------------------------
   if(bear_setup.state < INVALID && bear_setup.h4_bias == BEARISH)
   {
      switch(bear_setup.state)
      {
         case IDLE:
            if(high > bear_setup.crt_high)
            {
               if(!CheckFilters(false))
               {
                  bear_setup.state = INVALID;
                  break;
               }
               bear_setup.sweep_price = high;
               bear_setup.state = AWAITING_CONFIRMATION;
               if(EnableVerboseLogging)
                  Print("Bearish sweep detected; awaiting confirmation.");
            }
            break;
         case AWAITING_CONFIRMATION:
            if(EntryLogicModel == CONFIRM_WITH_MSS)
            {
               bear_setup.mss_level = FindLastSwing(m1_rates, false);
               if(bear_setup.mss_level > 0.0 && low < bear_setup.mss_level)
               {
                  if(FindFVG(m1_rates, bear_setup, false))
                  {
                     bear_setup.state = AWAITING_ENTRY;
                     if(EnableVerboseLogging)
                        Print("Bearish MSS confirmed; awaiting entry into FVG.");
                  }
               }
            }
            else
            {
               if(CheckCISD(m1_rates, false))
               {
                  if(FindFVG(m1_rates, bear_setup, false))
                  {
                     bear_setup.state = AWAITING_ENTRY;
                     if(EnableVerboseLogging)
                        Print("Bearish CISD confirmed; awaiting entry into FVG.");
                  }
               }
            }
            break;
         case AWAITING_ENTRY:
            if(high > bear_setup.fvg_low)
            {
               if(OperationalMode == SIGNALS_ONLY)
               {
                  Alert(_Symbol, " Bearish setup detected!");
               }
               else
               {
                  ExecuteTrade(false);
               }
               bear_setup.state = INVALID;
               bull_setup.state = INVALID;
            }
            break;
         default:
            break;
      }
   }
}

//-----------------------------------------------------------------------------
//  FILTERS
//
//  Filters are optional checks that can invalidate a setup.  They include
//  weekly profile alignment and SMT divergence with a correlated symbol.  If
//  filters are disabled or pass their checks, true is returned.  If a filter
//  fails, false is returned and the setup is invalidated.
//-----------------------------------------------------------------------------

bool CheckFilters(bool is_bullish_setup)
{
   if(EnableVerboseLogging) Print("Checking advanced filters...");
   //--- Weekly profile filter
   if(Filter_By_Weekly_Profile && Assumed_Weekly_Profile != NONE)
   {
      // Determine day of week using MqlDateTime struct (0=Sunday..6=Saturday)
      MqlDateTime day_tm;
      TimeToStruct(TimeCurrent(), day_tm);
      int day = day_tm.day_of_week;
      bool is_aligned = false;
      if(is_bullish_setup)
      {
         // Align bullish days with profile
         if((Assumed_Weekly_Profile == CLASSIC_EXPANSION && (day == 2 || day == 3 || day == 4)) ||
            (Assumed_Weekly_Profile == MIDWEEK_REVERSAL && (day == 3 || day == 4 || day == 5)))
            is_aligned = true;
      }
      else
      {
         // Align bearish days with profile (same logic here for simplicity)
         if((Assumed_Weekly_Profile == CLASSIC_EXPANSION && (day == 2 || day == 3 || day == 4)) ||
            (Assumed_Weekly_Profile == MIDWEEK_REVERSAL && (day == 3 || day == 4 || day == 5)))
            is_aligned = true;
      }
      if(!is_aligned)
      {
         if(EnableVerboseLogging) Print("FILTERED: Setup does not align with weekly profile");
         return false;
      }
   }
   
   //--- SMT divergence filter
   if(Use_SMT_Divergence_Filter && SMT_Correlated_Symbol != "")
   {
      // Copy two bars of M1 for current and correlated symbol
      MqlRates sym1_m1[];
      MqlRates sym2_m1[];
      ArraySetAsSeries(sym1_m1, true);
      ArraySetAsSeries(sym2_m1, true);
      if(CopyRates(_Symbol, PERIOD_M1, 0, 2, sym1_m1) < 2 || CopyRates(SMT_Correlated_Symbol, PERIOD_M1, 0, 2, sym2_m1) < 2)
      {
         if(EnableVerboseLogging) Print("SMT filter: not enough data for correlated symbol");
         return true; // don't block trade if data missing
      }
      bool smt_confirmed = false;
      if(is_bullish_setup)
      {
         // Bullish: our symbol sweeps a low, correlated fails
         if(sym1_m1[0].low < sym1_m1[1].low && sym2_m1[0].low > sym2_m1[1].low)
            smt_confirmed = true;
      }
      else
      {
         // Bearish: our symbol sweeps a high, correlated fails
         if(sym1_m1[0].high > sym1_m1[1].high && sym2_m1[0].high < sym2_m1[1].high)
            smt_confirmed = true;
      }
      if(!smt_confirmed)
      {
         if(EnableVerboseLogging) Print("FILTERED: SMT divergence not present");
         return false;
      }
      if(EnableVerboseLogging) Print("FILTER PASSED: SMT confirmed");
   }
   return true;
}

//-----------------------------------------------------------------------------
//  CORE LOGIC HELPER FUNCTIONS
//
//  Helper functions encapsulate common checks such as CISD detection,
//  swing detection and fair value gap identification.  Array bounds are
//  checked to prevent out‑of‑range errors.  These functions return true
//  when the respective condition is satisfied.
//-----------------------------------------------------------------------------

// Check for a Change in State of Delivery (CISD).  A strong momentum candle
// relative to the average size of previous candles indicates a momentum shift.
bool CheckCISD(const MqlRates &rates[], bool is_bullish)
{
   // Need at least 7 bars (i=0..6)
   if(ArraySize(rates) < 7)
      return false;
   double avg_range = 0.0;
   // Calculate average body size of last 5 candles (excluding current)
   for(int i = 2; i < 7; i++)
      avg_range += MathAbs(rates[i].close - rates[i].open);
   avg_range /= 5.0;
   if(avg_range <= 0.0)
      return false;
   // Compute body size of current candle
   double body = is_bullish ? (rates[0].close - rates[0].open) : (rates[0].open - rates[0].close);
   // Momentum should be 50% larger than average and close above/below previous open
   if(is_bullish)
      return (body > avg_range * 1.5 && rates[0].close > rates[1].open);
   else
      return (body > avg_range * 1.5 && rates[0].close < rates[1].open);
}

// Find the last swing high (bullish) or swing low (bearish) within a lookback
// window.  If no swing is found, returns 0.0.  Array size is checked to
// prevent out‑of‑range errors.
double FindLastSwing(const MqlRates &r[], bool is_bullish)
{
   int size = ArraySize(r);
   // Need at least 15 bars for swing detection
   int max_index = MathMin(15, size - 1);
   for(int i = 2; i < max_index; i++)
   {
      if(is_bullish)
      {
         if(r[i].high > r[i - 1].high && r[i].high > r[i + 1].high)
            return r[i].high;
      }
      else
      {
         if(r[i].low < r[i - 1].low && r[i].low < r[i + 1].low)
            return r[i].low;
      }
   }
   return 0.0;
}

// Identify a Fair Value Gap (FVG).  Looks for a gap between the high of
// a candle two bars ago and the low of the current bar (bullish) or
// the low of a candle two bars ago and the high of the current bar (bearish).
// Returns true if an FVG is found and sets the fvg_high/fvg_low in the
// provided SetupState.  The array must have at least 3 bars.
bool FindFVG(const MqlRates &rates[], SetupState &s, bool is_bullish)
{
   int size = ArraySize(rates);
   if(size < 3)
      return false;
   // Iterate from oldest to newest (series arrays are reversed)
   for(int i = size - 2; i >= 2; i--)
   {
      if(is_bullish)
      {
         // Bullish FVG: earlier high < later low
         if(rates[i - 2].high < rates[i].low)
         {
            s.fvg_high = rates[i - 2].high;
            s.fvg_low  = rates[i].low;
            return true;
         }
      }
      else
      {
         // Bearish FVG: earlier low > later high
         if(rates[i - 2].low > rates[i].high)
         {
            s.fvg_high = rates[i].high;
            s.fvg_low  = rates[i - 2].low;
            return true;
         }
      }
   }
   return false;
}

//-----------------------------------------------------------------------------
//  TRADE, RISK AND POSITION MANAGEMENT
//
//  ExecuteTrade() opens a position with calculated volume and appropriate
//  stop loss and take profit.  It checks for errors when sending the order.
//  CalculateLotSize() computes the lot size based on risk percentage and stop
//  distance.  ManageOpenPositions() moves stop loss to breakeven at 1R if
//  configured.
//-----------------------------------------------------------------------------

// Execute a buy or sell trade based on is_buy flag
void ExecuteTrade(bool is_buy)
{
   double entry_price;
   double stop_loss;
   double take_profit;
   // Calculate entry and stop levels
   if(is_buy)
   {
      entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      stop_loss   = bull_setup.sweep_price - (_Point * 3);
   }
   else
   {
      entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      stop_loss   = bear_setup.sweep_price + (_Point * 3);
   }
   double dist = MathAbs(entry_price - stop_loss);
   if(dist <= 0.0)
      return;
   // Compute take profit based on risk:reward ratio
   // Use validated gTakeProfitRR for risk:reward ratio
   take_profit = entry_price + (dist * gTakeProfitRR * (is_buy ? 1.0 : -1.0));
   // Calculate lot size
   double lot = CalculateLotSize(dist);
   if(lot <= 0.0)
      return;
   // Send trade request
   bool result = trade.PositionOpen(_Symbol, is_buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, lot, entry_price, stop_loss, take_profit, "CRT_Scalp");
   int retcode = trade.ResultRetcode();
   if(result)
   {
      tradesTodayCount++;
      if(EnableVerboseLogging) Print("Trade executed successfully. Ticket: ", trade.ResultOrder());
   }
   else
   {
      // Log error if order failed
      Print("Trade execution failed. Retcode=", retcode, " Error: ", trade.ResultRetcodeDescription());
   }
}

// Calculate lot size based on account balance, risk percent and stop distance
double CalculateLotSize(double stop_distance)
{
   if(stop_distance <= 0.0)
      return 0.0;
   // Risk amount in account currency
   // Use validated gRiskPercent for risk calculation
   double risk_amount = AccountInfoDouble(ACCOUNT_BALANCE) * (gRiskPercent / 100.0);
   // Tick value and size
   double tick_value, tick_size;
   if(!SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE, tick_value) || !SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE, tick_size) || tick_size == 0.0)
      return 0.0;
   // Loss per lot = stop_distance / tick_size * tick_value
   double loss_per_lot = (stop_distance / tick_size) * tick_value;
   if(loss_per_lot <= 0.0)
      return 0.0;
   double lots = risk_amount / loss_per_lot;
   // Adjust to broker min/max/step
   double min_lot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   // Round down to nearest step
   lots = MathFloor(lots / lot_step) * lot_step;
   // Clamp to allowed range
   lots = MathMax(min_lot, MathMin(lots, max_lot));
   return lots;
}

// Move stop loss to breakeven at 1R if configured
void ManageOpenPositions()
{
   // Select by the EA's magic number set during OnInit
   if(!position.SelectByMagic(_Symbol, MAGIC_NUMBER))
      return;
   long type = position.PositionType();
   double open_price = position.PriceOpen();
   double stop_loss  = position.StopLoss();
   double take_profit= position.TakeProfit();
   double current_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(MoveToBE_At_1R && stop_loss != open_price)
   {
      double risk_distance = MathAbs(open_price - stop_loss);
      if(risk_distance <= 0.0)
         return;
      double be_level = open_price + (risk_distance * (type == POSITION_TYPE_BUY ? 1.0 : -1.0));
      // Check if price has reached or exceeded breakeven threshold
      bool reached = (type == POSITION_TYPE_BUY) ? (current_price >= be_level) : (current_price <= be_level);
      if(reached)
      {
         // Modify stop loss to open price (breakeven)
         if(trade.PositionModify(_Symbol, open_price, take_profit))
         {
            if(EnableVerboseLogging) Print("Stop moved to breakeven.");
         }
         else
         {
            Print("Failed to modify position to breakeven. Retcode=", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
         }
      }
   }
}

//-----------------------------------------------------------------------------
//  TIME AND KILLZONE UTILITY FUNCTIONS
//
//  Utility functions to convert server time to New‑York time (approximate) and
//  check whether the current time falls within the kill zone of the chosen
//  session.  Note: this implementation does not automatically adjust for
//  daylight savings; adjust Broker_GMT_Offset_Hours accordingly when DST
//  changes.
//-----------------------------------------------------------------------------

// Convert server time to New‑York time using simple GMT offset
datetime GetNYTime(datetime st = 0)
{
   if(st == 0)
      st = TimeCurrent();
   // New York GMT offset (static); DST not handled automatically
   long ny_offset = -5;
   // Convert to NY time using broker and NY offsets
   return st + (long)((ny_offset - Broker_GMT_Offset_Hours) * 3600);
}

// Determine if current time (NY time) is within kill zone
bool IsWithinKillzone()
{
   MqlDateTime tm;
   TimeToStruct(GetNYTime(), tm);
   int start_hour, start_min, end_hour, end_min;
   if(SessionToTrade == LONDON_OPEN)
   {
      start_hour = 3;
      start_min  = 0;
      end_hour   = 5;
      end_min    = 0;
   }
   else
   {
      start_hour = 9;
      start_min  = 30;
      end_hour   = 11;
      end_min    = 0;
   }
   int now_minutes   = tm.hour * 60 + tm.min;
   int start_minutes = start_hour * 60 + start_min;
   int end_minutes   = end_hour * 60 + end_min;
   return (now_minutes >= start_minutes && now_minutes <= end_minutes);
}

//-----------------------------------------------------------------------------
//  UI AND VISUALISATION FUNCTIONS
//
//  These functions build and update a simple dashboard on the chart.  The
//  dashboard displays the symbol name, H4 bias and current state (idle,
//  awaiting sweep, confirmation, entry or invalid).  Colours and positions
//  reflect user preferences.  For simplicity the dashboard supports one
//  symbol; to extend to multiple symbols, enlarge symbol_states and adjust
//  loops accordingly.
//-----------------------------------------------------------------------------

void SetThemeColors()
{
   switch(i_theme)
   {
      case THEME_LIGHT:
         c_bg    = C'224,227,235';
         c_header= clrBlack;
         c_text  = clrBlack;
         c_bull_bias = C'38,166,154';
         c_bear_bias = C'239,83,80';
         c_neutral_bias = C'67,70,81';
         c_state_sweep = clrOrange;
         c_state_confirm = clrDodgerBlue;
         c_state_entry = clrLimeGreen;
         break;
      case THEME_BLUEPRINT:
         c_bg    = C'42,52,73';
         c_header= C'247,201,117';
         c_text  = C'247,201,117';
         c_bull_bias = clrAqua;
         c_bear_bias = clrFuchsia;
         c_neutral_bias = clrSlateGray;
         c_state_sweep = clrGold;
         c_state_confirm = clrAqua;
         c_state_entry = clrLime;
         break;
      default:
         c_bg    = C'30,34,45';
         c_header= clrWhite;
         c_text  = clrWhite;
         c_bull_bias = C'38,166,154';
         c_bear_bias = C'220,20,60';
         c_neutral_bias = clrGray;
         c_state_sweep = clrGold;
         c_state_confirm = clrAqua;
         c_state_entry = clrLime;
         break;
   }
}

// Create the dashboard objects on the chart
void CreateDashboard()
{
   // Coordinates and sizes for layout (in pixels)
   int x_offset = 10;
   int y_offset = 20;
   int row_height = 18;
   int col_width1 = 95;
   int col_width2 = 60;
   int col_width3 = 95;
   int column_padding = 15;
   int title_height = 25;
   
   // Determine corner from position input
   ENUM_BASE_CORNER corner = GetCornerFromPos(i_table_pos);
   
   // Create background rectangle
   CreateRectangle(object_prefix + "BG", x_offset - 5, y_offset - 5, (col_width1 + col_width2 + col_width3) + column_padding + 10, row_height * 2 + title_height, c_bg, corner);
   // Title
   CreateTextLabel(object_prefix + "Title", "CRT Scalper v5.2", x_offset, y_offset, c_header, 10, corner, ANCHOR_LEFT);
   // Column headers
   int header_y = y_offset + title_height;
   CreateTextLabel(object_prefix + "H_Asset", "Asset", x_offset, header_y, c_header, 8, corner, ANCHOR_LEFT);
   CreateTextLabel(object_prefix + "H_Bias", "H4 Bias", x_offset + col_width1, header_y, c_header, 8, corner, ANCHOR_LEFT);
   CreateTextLabel(object_prefix + "H_State", "Status", x_offset + col_width1 + col_width2, header_y, c_header, 8, corner, ANCHOR_LEFT);
   
   // Initialize labels for symbol (single row)
   int row_y = header_y + row_height;
   CreateTextLabel(object_prefix + "Sym_0", symbol_states[0].symbol_name, x_offset, row_y, c_text, 9, corner, ANCHOR_LEFT);
   CreateTextLabel(object_prefix + "Bias_0", "-", x_offset + col_width1, row_y, c_text, 12, corner, ANCHOR_LEFT);
   CreateTextLabel(object_prefix + "Status_0", "Idle", x_offset + col_width1 + col_width2, row_y, c_text, 9, corner, ANCHOR_LEFT);
}

// Update the dashboard with current bias and state
void UpdateDashboard()
{
   // Determine bias icon and colour
   string bias_icon;
   color bias_color;
   switch(symbol_states[0].h4_bias)
   {
      case BULLISH: bias_icon = icon_bull; bias_color = c_bull_bias; break;
      case BEARISH: bias_icon = icon_bear; bias_color = c_bear_bias; break;
      default:      bias_icon = icon_neutral; bias_color = c_neutral_bias; break;
   }
   // Determine status text and colour (choose active state)
   string state_text = "Idle";
   color state_color = c_text;
   // Use bull state if bias is bullish, bear if bearish
   if(symbol_states[0].h4_bias == BULLISH && bull_setup.state != IDLE)
   {
      state_text = EnumToString(bull_setup.state);
      state_color = (bull_setup.state == AWAITING_ENTRY) ? c_state_confirm : (bull_setup.state == AWAITING_CONFIRMATION ? c_state_sweep : c_state_entry);
   }
   else if(symbol_states[0].h4_bias == BEARISH && bear_setup.state != IDLE)
   {
      state_text = EnumToString(bear_setup.state);
      state_color = (bear_setup.state == AWAITING_ENTRY) ? c_state_confirm : (bear_setup.state == AWAITING_CONFIRMATION ? c_state_sweep : c_state_entry);
   }
   // Update labels
   ObjectSetString(0, object_prefix + "Sym_0",    OBJPROP_TEXT, symbol_states[0].symbol_name);
   ObjectSetString(0, object_prefix + "Bias_0",   OBJPROP_TEXT, bias_icon);
   ObjectSetInteger(0, object_prefix + "Bias_0",   OBJPROP_COLOR, bias_color);
   ObjectSetString(0, object_prefix + "Status_0", OBJPROP_TEXT, state_text);
   ObjectSetInteger(0, object_prefix + "Status_0", OBJPROP_COLOR, state_color);
}

// Helper: map dashboard position to MetaTrader chart corner
ENUM_BASE_CORNER GetCornerFromPos(ENUM_POSITION p)
{
   switch(p)
   {
      case POS_TOP_LEFT:    return CORNER_LEFT_UPPER;
      case POS_MIDDLE_RIGHT:return CORNER_RIGHT_UPPER;
      case POS_MIDDLE_LEFT: return CORNER_LEFT_UPPER;
      case POS_BOTTOM_RIGHT:return CORNER_RIGHT_LOWER;
      case POS_BOTTOM_LEFT: return CORNER_LEFT_LOWER;
      default:              return CORNER_RIGHT_UPPER;
   }
}

// Create a filled rectangle label object
void CreateRectangle(string name, int x, int y, int w, int h, color c, ENUM_BASE_CORNER corner)
{
   if(ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, x, y))
   {
       ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
       ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
       ObjectSetInteger(0, name, OBJPROP_BGCOLOR, c);
       ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
       ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
       ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
       ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   }
}

// Create a text label object
void CreateTextLabel(string name, string text, int x, int y, color c, int fontsize, ENUM_BASE_CORNER corner, ENUM_ANCHOR_POINT anchor)
{
   if(ObjectCreate(0, name, OBJ_LABEL, 0, x, y))
   {
       ObjectSetString(0, name, OBJPROP_TEXT, text);
       ObjectSetInteger(0, name, OBJPROP_COLOR, c);
       ObjectSetString(0, name, OBJPROP_FONT, "Arial");
       ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontsize);
       ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
       ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
       ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   }
}

// Draw the CRT range on the chart (placeholder, implement as needed)
void DrawRangeLines()
{
   // Example: draw two horizontal lines representing CRT high and low
   if(bull_setup.crt_high <= 0.0 || bull_setup.crt_low <= 0.0)
      return;
   // Remove existing lines
   ObjectDelete(0, object_prefix + "CRTHigh");
   ObjectDelete(0, object_prefix + "CRTLow");
   // Create new lines
   ObjectCreate(0, object_prefix + "CRTHigh", OBJ_HLINE, 0, TimeCurrent(), bull_setup.crt_high);
   ObjectSetInteger(0, object_prefix + "CRTHigh", OBJPROP_COLOR, c_state_sweep);
   ObjectCreate(0, object_prefix + "CRTLow", OBJ_HLINE, 0, TimeCurrent(), bull_setup.crt_low);
   ObjectSetInteger(0, object_prefix + "CRTLow", OBJPROP_COLOR, c_state_sweep);
}
