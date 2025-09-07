//+------------------------------------------------------------------+
//| CRT Session Open Scalper v5.3 (DST- and broker-time aware)       |
//| NY session kill zone auto-adjusts for any broker time            |
//+------------------------------------------------------------------+
#property copyright "Final Version by The Synthesis"
#property version   "5.30"
#property description "A DST- and broker-agnostic EA for CRT scalping using NY session logic."

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <ChartObjects\ChartObjectsTxtControls.mqh>

//--- Enums for user options
enum ENUM_SESSION_FOCUS    { LONDON_OPEN, NEW_YORK_OPEN };
enum ENUM_OPERATIONAL_MODE { SIGNALS_ONLY, FULLY_AUTOMATED };
enum ENUM_SETUP_STATE      { IDLE, AWAITING_SWEEP, AWAITING_CONFIRMATION, AWAITING_ENTRY, INVALID };
enum ENUM_ENTRY_MODEL      { CONFIRM_WITH_MSS, CONFIRM_WITH_CISD };
enum ENUM_BIAS             { NEUTRAL, BULLISH, BEARISH };
enum ENUM_WEEKLY_PROFILE   { NONE, CLASSIC_EXPANSION, MIDWEEK_REVERSAL, CONSOLIDATION_REVERSAL };
enum ENUM_POSITION         { POS_TOP_RIGHT, POS_TOP_LEFT, POS_MIDDLE_RIGHT, POS_MIDDLE_LEFT, POS_BOTTOM_RIGHT, POS_BOTTOM_LEFT };
enum ENUM_THEME            { THEME_DARK, THEME_LIGHT, THEME_BLUEPRINT };

//--- Structures
struct SetupState {
   ENUM_SETUP_STATE  state;
   double crt_high, crt_low, mss_level, fvg_high, fvg_low, sweep_price;
   ENUM_BIAS h4_bias;
};
struct SymbolState {
   string symbol_name;
   ENUM_BIAS h4_bias;
   ENUM_SETUP_STATE bull_state;
   ENUM_SETUP_STATE bear_state;
};

//--- Objects
CTrade        trade;
CPositionInfo position;

//--- Global variables
SetupState   bull_setup;
SetupState   bear_setup;
SymbolState  symbol_states[1];
string object_prefix = "CRT_SCALPER_";
color c_bg, c_header, c_text, c_bull_bias, c_bear_bias, c_neutral_bias;
color c_state_sweep, c_state_confirm, c_state_entry;
string icon_bull = "▲", icon_bear = "▼", icon_neutral = "↔", icon_wait = "—";
int    tradesTodayCount = 0;
string dashboardID = "CRT_SCALPER_";
double gRiskPercent    = 0.0;
double gTakeProfitRR   = 0.0;
int    gMaxTradesPerDay = 0;
long   MAGIC_NUMBER    = 2024053;

//+------------------------------------------+
//|             INPUT PARAMETERS             |
//+------------------------------------------+
input group                "CRT Model Settings";
input ENUM_SESSION_FOCUS   SessionToTrade          = NEW_YORK_OPEN;
input ENUM_ENTRY_MODEL     EntryLogicModel         = CONFIRM_WITH_MSS;
input group                "Risk & Trade Management";
input double               RiskPercent             = 0.5;
input double               TakeProfit_RR           = 2.0;
input bool                 MoveToBE_At_1R          = true;
input int                  MaxTradesPerDay         = 1;
input group                "Advanced Contextual Filters";
input bool                 Filter_By_Weekly_Profile= false;
input ENUM_WEEKLY_PROFILE  Assumed_Weekly_Profile  = NONE;
input bool                 Use_SMT_Divergence_Filter= false;
input string               SMT_Correlated_Symbol   = "DXY";
input group                "Operational Mode & UI";
input ENUM_OPERATIONAL_MODE OperationalMode         = SIGNALS_ONLY;
input ENUM_THEME           i_theme                 = THEME_DARK;
input ENUM_POSITION        i_table_pos             = POS_TOP_RIGHT;
input bool                 EnableVerboseLogging    = true;
bool IsWithinKillzone()
{
   MqlDateTime now; TimeToStruct(TimeCurrent(), now);
   int now_minutes = now.hour * 60 + now.min;
   int start_minutes, end_minutes;
   GetKillZoneInBrokerTime(start_minutes, end_minutes);
   return (now_minutes >= start_minutes && now_minutes <= end_minutes);
}
//+------------------------------------------------------------------+
//|            VALIDATION & INITIALIZATION                           |
//+------------------------------------------------------------------+
bool ValidateInputs() {
   bool ok = true;
   if(RiskPercent <= 0.0 || RiskPercent > 10.0) {
      Print("Invalid RiskPercent value (", RiskPercent, "), using default 0.5%");
      gRiskPercent = 0.5; ok = false;
   } else gRiskPercent = RiskPercent;
   if(TakeProfit_RR <= 0.1) {
      Print("TakeProfit_RR too low (", TakeProfit_RR, "), using default 2.0");
      gTakeProfitRR = 2.0; ok = false;
   } else gTakeProfitRR = TakeProfit_RR;
   if(MaxTradesPerDay < 1 || MaxTradesPerDay > 10) {
      Print("MaxTradesPerDay out of range (", MaxTradesPerDay, "), using default 1");
      gMaxTradesPerDay = 1; ok = false;
   } else gMaxTradesPerDay = MaxTradesPerDay;
   return ok;
}

int OnInit() {
   Print("CRT Session Open Scalper v5.3 Initializing...");
   ValidateInputs();
   trade.SetExpertMagicNumber(MAGIC_NUMBER);
   trade.SetTypeFillingBySymbol(_Symbol);
   symbol_states[0].symbol_name = _Symbol;
   symbol_states[0].h4_bias = NEUTRAL;
   symbol_states[0].bull_state = IDLE;
   symbol_states[0].bear_state = IDLE;
   ResetDailyVariables();
   SetThemeColors();
   CreateDashboard();
   EventSetTimer(1);
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason){ EventKillTimer(); ObjectsDeleteAll(0, dashboardID); }
void ResetDailyVariables() {
    if(EnableVerboseLogging) Print("Resetting daily variables and scanning for CRT range...");
    bull_setup.state=IDLE; bear_setup.state=IDLE;
    bull_setup.crt_high=0; bear_setup.crt_high=0;
    tradesTodayCount = 0;
    AnalyzeHigherTimeframes();
}

//+------------------------------------------------------------------+
//|              MAIN TIMER LOOP                                     |
//+------------------------------------------------------------------+
//void OnTimer()
//{
//   static int last_day = -1;
//   MqlDateTime dt_day; TimeToStruct(TimeCurrent(), dt_day);
//   int current_day = dt_day.day_of_year;
//   if(last_day != current_day) { ResetDailyVariables(); last_day = current_day; }
//   if(bull_setup.crt_high == 0) SetCRTRange();
//   if(bull_setup.crt_high > 0 && tradesTodayCount < gMaxTradesPerDay && IsWithinKillzone()) { CheckForEntry(); }
//   UpdateDashboard();
//   ManageOpenPositions();
//}

void OnTimer()
{
   static int last_day = -1;
   MqlDateTime dt_day; TimeToStruct(TimeCurrent(), dt_day);
   int current_day = dt_day.day_of_year;

   // --- DEBUGGING BLOCK START ---
   int broker_offset = GetBrokerGMTOffsetHours();
   int start_minutes, end_minutes;
   GetKillZoneInBrokerTime(start_minutes, end_minutes);
   MqlDateTime now; TimeToStruct(TimeCurrent(), now);
   int now_minutes = now.hour * 60 + now.min;
   bool in_kz = (now_minutes >= start_minutes && now_minutes <= end_minutes);

   PrintFormat("DEBUG: Server time = %04d-%02d-%02d %02d:%02d, Broker Offset from GMT = %d",
       now.year, now.mon, now.day, now.hour, now.min, broker_offset);
   PrintFormat("DEBUG: Killzone (in broker/server time): %02d:%02d - %02d:%02d [%d - %d min]",
       start_minutes / 60, start_minutes % 60, end_minutes / 60, end_minutes % 60, start_minutes, end_minutes);
   PrintFormat("DEBUG: Now = %02d:%02d (%d min since midnight), InKillzone = %s",
       now.hour, now.min, now_minutes, (in_kz ? "YES" : "NO"));
   // --- DEBUGGING BLOCK END ---

   if(last_day != current_day) { ResetDailyVariables(); last_day = current_day; }
   if(bull_setup.crt_high == 0) SetCRTRange();

   // LOG WHEN CheckForEntry IS CALLED
   if(bull_setup.crt_high > 0 && tradesTodayCount < gMaxTradesPerDay && in_kz) {
      Print("DEBUG: Calling CheckForEntry (within killzone and trade limit)");
      CheckForEntry();
   }
   UpdateDashboard();
   ManageOpenPositions();
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
ENUM_BASE_CORNER GetCornerFromPos(ENUM_POSITION p)
{
   switch(p){
      case POS_TOP_LEFT: return CORNER_LEFT_UPPER;
      case POS_TOP_RIGHT: return CORNER_RIGHT_UPPER;
      case POS_MIDDLE_RIGHT: return CORNER_RIGHT_UPPER;
      case POS_MIDDLE_LEFT: return CORNER_LEFT_UPPER;
      case POS_BOTTOM_RIGHT: return CORNER_RIGHT_LOWER;
      case POS_BOTTOM_LEFT: return CORNER_LEFT_LOWER;
      default: return CORNER_RIGHT_UPPER;
   }
}
void CreateRectangle(string n,int x,int y,int w,int h,color c,ENUM_BASE_CORNER crn)
{
   if(ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,x,y))
   {
      ObjectSetInteger(0,n,OBJPROP_XSIZE,w);
      ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
      ObjectSetInteger(0,n,OBJPROP_BGCOLOR,c);
      ObjectSetInteger(0,n,OBJPROP_CORNER,crn);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,n,OBJPROP_COLOR,c);
   }
}
void CreateTextLabel(string n,string t,int x,int y,color c,int s=8,ENUM_BASE_CORNER crn=CORNER_RIGHT_UPPER ,ENUM_ANCHOR_POINT a=ANCHOR_LEFT)
{
   if(ObjectCreate(0,n,OBJ_LABEL,0,x,y))
   {
      ObjectSetString(0,n,OBJPROP_TEXT,t);
      ObjectSetInteger(0,n,OBJPROP_COLOR,c);
      ObjectSetString(0,n,OBJPROP_FONT,"Arial");
      ObjectSetInteger(0,n,OBJPROP_FONTSIZE,s);
      ObjectSetInteger(0,n,OBJPROP_CORNER,crn);
      ObjectSetInteger(0,n,OBJPROP_ANCHOR,a);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   }
}
void DrawRangeLines()
{
   // Optional: draw CRT range on the chart if you like
}

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

//+------------------------------------------------------------------+
//|             KILLZONE: DST-Aware NY Session Logic                 |
//+------------------------------------------------------------------+
int GetBrokerGMTOffsetHours()
{
   datetime server_time = TimeCurrent();
   datetime gmt_time = TimeGMT();
   return (int)((server_time - gmt_time) / 3600);
}
void GetKillZoneInBrokerTime(int &start_minutes, int &end_minutes)
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   bool isDST = (dt.mon >= 3 && dt.mon <= 11); // Approx DST months
   int ny_offset = isDST ? -4 : -5;
   int broker_offset = GetBrokerGMTOffsetHours();
   int shift = broker_offset - ny_offset;
   start_minutes = (9*60+30) + shift*60;
   end_minutes   = (11*60)   + shift*60;
}
// Return true if a strong CISD (momentum) is found
bool CheckCISD(const MqlRates &rates[], bool is_bullish)
{
   double avg_body = 0;
   for(int i=2; i<7; i++)
      avg_body += MathAbs(rates[i].close - rates[i].open);
   avg_body /= 5.0;
   if(is_bullish)
   {
      double b = rates[0].close - rates[0].open;
      return b > (avg_body*1.5) && rates[0].close > rates[1].open;
   }
   else
   {
      double b = rates[0].open - rates[0].close;
      return b > (avg_body*1.5) && rates[0].close < rates[1].open;
   }
}

// Find most recent swing high (bullish) or swing low (bearish)
double FindLastSwing(const MqlRates &r[], bool high)
{
   for(int i=2; i<15; i++)
   {
      if(high && r[i].high > r[i-1].high && r[i].high > r[i+1].high)
         return r[i].high;
      if(!high && r[i].low < r[i-1].low && r[i].low < r[i+1].low)
         return r[i].low;
   }
   return 0;
}
void ExecuteTrade(bool is_buy)
{
   double entry_price, stop_loss, take_profit;
   if(is_buy)
   {
      entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      stop_loss = bull_setup.sweep_price - (_Point * 3);
   }
   else
   {
      entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      stop_loss = bear_setup.sweep_price + (_Point * 3);
   }
   double dist = MathAbs(entry_price - stop_loss);
   if(dist == 0) return;
   take_profit = entry_price + (dist * gTakeProfitRR * (is_buy ? 1 : -1));
   double lots = CalculateLotSize(dist);
   if(trade.PositionOpen(_Symbol, is_buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, lots, entry_price, stop_loss, take_profit, "CRT_Scalp"))
   {
      if(EnableVerboseLogging) Print("Trade Executed.");
      tradesTodayCount++;
   }
}

// Find Fair Value Gap in price array
bool FindFVG(const MqlRates &r[], SetupState &s, bool bullish)
{
   for(int i=2; i<15; i++)
   {
      if(bullish && r[i-2].high < r[i].low)
      {
         s.fvg_high = r[i-2].high;
         s.fvg_low  = r[i].low;
         return true;
      }
      if(!bullish && r[i-2].low > r[i].high)
      {
         s.fvg_high = r[i].high;
         s.fvg_low  = r[i-2].low;
         return true;
      }
   }
   return false;
}


datetime GetNYTime(datetime st=0)
{
   if(st==0) st=TimeCurrent();
   // Use the same DST logic as kill zone: NY is -4 or -5
   MqlDateTime dt; TimeToStruct(st, dt);
   bool isDST = (dt.mon >= 3 && dt.mon <= 11);
   int ny_offset = isDST ? -4 : -5;
   int broker_offset = GetBrokerGMTOffsetHours();
   int shift = ny_offset - broker_offset;
   return st + shift*3600;
}

//+------------------------------------------------------------------+
//|             CRT RANGE LOGIC, ENTRIES, FILTERS, DASHBOARD         |
//+------------------------------------------------------------------+
// (Paste your existing logic for SetCRTRange, AnalyzeHigherTimeframes,
// CheckForEntry, CheckFilters, ExecuteTrade, CalculateLotSize,
// ManageOpenPositions, SetThemeColors, CreateDashboard, UpdateDashboard, etc.)

// -------- For brevity, this block is left out here, but
// -------- copy the rest of your unchanged EA code below this section!

//+------------------------------------------------------------------+

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

//void CheckForEntry()
//{
//   MqlRates m1_rates[];
//   ArraySetAsSeries(m1_rates, true);
//   // Copy last 25 M1 bars; need at least 25 for swing/FVG logic
//   if(CopyRates(_Symbol, PERIOD_M1, 0, 25, m1_rates) < 25)
//      return;
//   
//   double high = m1_rates[0].high;
//   double low  = m1_rates[0].low;
//   
//   //---------------------------------------------------------------
//   // Bullish logic
//   //---------------------------------------------------------------
//   if(bull_setup.state < INVALID && bull_setup.h4_bias == BULLISH)
//   {
//      switch(bull_setup.state)
//      {
//         // IDLE: wait for sweep below CRT low
//         case IDLE:
//            if(low < bull_setup.crt_low)
//            {
//               if(!CheckFilters(true))
//               {
//                  bull_setup.state = INVALID;
//                  break;
//               }
//               bull_setup.sweep_price = low;
//               bull_setup.state = AWAITING_CONFIRMATION;
//               if(EnableVerboseLogging)
//                  Print("Bullish sweep detected; awaiting confirmation.");
//            }
//            break;
//         // Confirmation: MSS or CISD
//         case AWAITING_CONFIRMATION:
//            if(EntryLogicModel == CONFIRM_WITH_MSS)
//            {
//               bull_setup.mss_level = FindLastSwing(m1_rates, true);
//               if(bull_setup.mss_level > 0.0 && high > bull_setup.mss_level)
//               {
//                  if(FindFVG(m1_rates, bull_setup, true))
//                  {
//                     bull_setup.state = AWAITING_ENTRY;
//                     if(EnableVerboseLogging)
//                        Print("Bullish MSS confirmed; awaiting entry into FVG.");
//                  }
//               }
//            }
//            else // CONFIRM_WITH_CISD
//            {
//               if(CheckCISD(m1_rates, true))
//               {
//                  if(FindFVG(m1_rates, bull_setup, true))
//                  {
//                     bull_setup.state = AWAITING_ENTRY;
//                     if(EnableVerboseLogging)
//                        Print("Bullish CISD confirmed; awaiting entry into FVG.");
//                  }
//               }
//            }
//            break;
//         // Awaiting entry: price returns into FVG high; then trade
//         case AWAITING_ENTRY:
//            if(low < bull_setup.fvg_high)
//            {
//               if(OperationalMode == SIGNALS_ONLY)
//               {
//                  Alert(_Symbol, " Bullish setup detected!");
//               }
//               else
//               {
//                  ExecuteTrade(true);
//               }
//               // Invalidate setups to prevent double entries
//               bull_setup.state = INVALID;
//               bear_setup.state = INVALID;
//            }
//            break;
//         default:
//            break;
//      }
//   }
//   //---------------------------------------------------------------
//   // Bearish logic
//   //---------------------------------------------------------------
//   if(bear_setup.state < INVALID && bear_setup.h4_bias == BEARISH)
//   {
//      switch(bear_setup.state)
//      {
//         case IDLE:
//            if(high > bear_setup.crt_high)
//            {
//               if(!CheckFilters(false))
//               {
//                  bear_setup.state = INVALID;
//                  break;
//               }
//               bear_setup.sweep_price = high;
//               bear_setup.state = AWAITING_CONFIRMATION;
//               if(EnableVerboseLogging)
//                  Print("Bearish sweep detected; awaiting confirmation.");
//            }
//            break;
//         case AWAITING_CONFIRMATION:
//            if(EntryLogicModel == CONFIRM_WITH_MSS)
//            {
//               bear_setup.mss_level = FindLastSwing(m1_rates, false);
//               if(bear_setup.mss_level > 0.0 && low < bear_setup.mss_level)
//               {
//                  if(FindFVG(m1_rates, bear_setup, false))
//                  {
//                     bear_setup.state = AWAITING_ENTRY;
//                     if(EnableVerboseLogging)
//                        Print("Bearish MSS confirmed; awaiting entry into FVG.");
//                  }
//               }
//            }
//            else
//            {
//               if(CheckCISD(m1_rates, false))
//               {
//                  if(FindFVG(m1_rates, bear_setup, false))
//                  {
//                     bear_setup.state = AWAITING_ENTRY;
//                     if(EnableVerboseLogging)
//                        Print("Bearish CISD confirmed; awaiting entry into FVG.");
//                  }
//               }
//            }
//            break;
//         case AWAITING_ENTRY:
//            if(high > bear_setup.fvg_low)
//            {
//               if(OperationalMode == SIGNALS_ONLY)
//               {
//                  Alert(_Symbol, " Bearish setup detected!");
//               }
//               else
//               {
//                  ExecuteTrade(false);
//               }
//               bear_setup.state = INVALID;
//               bull_setup.state = INVALID;
//            }
//            break;
//         default:
//            break;
//      }
//   }
//}

void CheckForEntry()
{
   MqlRates m1_rates[];
   ArraySetAsSeries(m1_rates, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 25, m1_rates) < 25)
      return;

   double high = m1_rates[0].high;
   double low  = m1_rates[0].low;
   double close = m1_rates[0].close;

   // ---- BULLISH LOGIC ----
   if(bull_setup.state < INVALID && bull_setup.h4_bias == BULLISH)
   {
      Print("BULL: State=", EnumToString(bull_setup.state), " | CRT low=", bull_setup.crt_low, " | M1 low=", low);

      switch(bull_setup.state)
      {
         case IDLE:
            if(low < bull_setup.crt_low)
            {
               Print("BULL: Sweep detected below CRT low (", low, " < ", bull_setup.crt_low, ")");
               if(!CheckFilters(true))
               {
                  Print("BULL: Filter failed. Setup invalidated.");
                  bull_setup.state = INVALID;
                  break;
               }
               bull_setup.sweep_price = low;
               bull_setup.state = AWAITING_CONFIRMATION;
               Print("BULL: Awaiting confirmation. Sweep price=", low);
            }
            break;

         case AWAITING_CONFIRMATION:
            if(EntryLogicModel == CONFIRM_WITH_MSS)
            {
               bull_setup.mss_level = FindLastSwing(m1_rates, true);
               Print("BULL: Awaiting MSS confirmation. MSS level=", bull_setup.mss_level, " | M1 high=", high);
               if(bull_setup.mss_level > 0.0 && high > bull_setup.mss_level)
               {
                  bool fvgFound = FindFVG(m1_rates, bull_setup, true);
                  Print("BULL: MSS confirmed. FVG found? ", (fvgFound ? "YES" : "NO"), " | FVG High=", bull_setup.fvg_high);
                  if(fvgFound)
                  {
                     bull_setup.state = AWAITING_ENTRY;
                     Print("BULL: Awaiting entry into FVG...");
                  }
               }
            }
            else // CISD
            {
               bool cisd = CheckCISD(m1_rates, true);
               Print("BULL: Awaiting CISD confirmation. CISD? ", (cisd ? "YES" : "NO"));
               if(cisd)
               {
                  bool fvgFound = FindFVG(m1_rates, bull_setup, true);
                  Print("BULL: CISD confirmed. FVG found? ", (fvgFound ? "YES" : "NO"), " | FVG High=", bull_setup.fvg_high);
                  if(fvgFound)
                  {
                     bull_setup.state = AWAITING_ENTRY;
                     Print("BULL: Awaiting entry into FVG...");
                  }
               }
            }
            break;

         case AWAITING_ENTRY:
            Print("BULL: Awaiting price to trade into FVG high. M1 low=", low, " | FVG high=", bull_setup.fvg_high);
            if(low < bull_setup.fvg_high)
            {
               Print("BULL: Entry triggered! Low (", low, ") < FVG high (", bull_setup.fvg_high, ")");
               if(OperationalMode == SIGNALS_ONLY)
                  Alert(_Symbol, " Bullish setup detected!");
               else
                  ExecuteTrade(true);
               bull_setup.state = INVALID;
               bear_setup.state = INVALID;
            }
            break;

         default:
            Print("BULL: State is INVALID or unhandled.");
            break;
      }
   }

   // ---- BEARISH LOGIC ----
   if(bear_setup.state < INVALID && bear_setup.h4_bias == BEARISH)
   {
      Print("BEAR: State=", EnumToString(bear_setup.state), " | CRT high=", bear_setup.crt_high, " | M1 high=", high);

      switch(bear_setup.state)
      {
         case IDLE:
            if(high > bear_setup.crt_high)
            {
               Print("BEAR: Sweep detected above CRT high (", high, " > ", bear_setup.crt_high, ")");
               if(!CheckFilters(false))
               {
                  Print("BEAR: Filter failed. Setup invalidated.");
                  bear_setup.state = INVALID;
                  break;
               }
               bear_setup.sweep_price = high;
               bear_setup.state = AWAITING_CONFIRMATION;
               Print("BEAR: Awaiting confirmation. Sweep price=", high);
            }
            break;

         case AWAITING_CONFIRMATION:
            if(EntryLogicModel == CONFIRM_WITH_MSS)
            {
               bear_setup.mss_level = FindLastSwing(m1_rates, false);
               Print("BEAR: Awaiting MSS confirmation. MSS level=", bear_setup.mss_level, " | M1 low=", low);
               if(bear_setup.mss_level > 0.0 && low < bear_setup.mss_level)
               {
                  bool fvgFound = FindFVG(m1_rates, bear_setup, false);
                  Print("BEAR: MSS confirmed. FVG found? ", (fvgFound ? "YES" : "NO"), " | FVG Low=", bear_setup.fvg_low);
                  if(fvgFound)
                  {
                     bear_setup.state = AWAITING_ENTRY;
                     Print("BEAR: Awaiting entry into FVG...");
                  }
               }
            }
            else // CISD
            {
               bool cisd = CheckCISD(m1_rates, false);
               Print("BEAR: Awaiting CISD confirmation. CISD? ", (cisd ? "YES" : "NO"));
               if(cisd)
               {
                  bool fvgFound = FindFVG(m1_rates, bear_setup, false);
                  Print("BEAR: CISD confirmed. FVG found? ", (fvgFound ? "YES" : "NO"), " | FVG Low=", bear_setup.fvg_low);
                  if(fvgFound)
                  {
                     bear_setup.state = AWAITING_ENTRY;
                     Print("BEAR: Awaiting entry into FVG...");
                  }
               }
            }
            break;

         case AWAITING_ENTRY:
            Print("BEAR: Awaiting price to trade into FVG low. M1 high=", high, " | FVG low=", bear_setup.fvg_low);
            if(high > bear_setup.fvg_low)
            {
               Print("BEAR: Entry triggered! High (", high, ") > FVG low (", bear_setup.fvg_low, ")");
               if(OperationalMode == SIGNALS_ONLY)
                  Alert(_Symbol, " Bearish setup detected!");
               else
                  ExecuteTrade(false);
               bear_setup.state = INVALID;
               bull_setup.state = INVALID;
            }
            break;

         default:
            Print("BEAR: State is INVALID or unhandled.");
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

//+------------------------------------------------------------------+
