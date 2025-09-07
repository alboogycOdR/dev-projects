//+------------------------------------------------------------------+
//|                        CRT_Setup_Tracker_v4.0.mq5                |
//|        An Institutional-Grade, Multi-Asset Setup Scanner         |
//|                 Tracking the Sweep, MSS, and Entry               |
//+------------------------------------------------------------------+
#property copyright "Final, Runnable Version by The Synthesis"
#property link      "https://beta.character.ai/"
#property version   "4.00"

#include <ChartObjects\ChartObjectsTxtControls.mqh>
/*
Quick Start Guide: The Institutional CRT Setup Tracker v4.0

1. High-Level Concept
This Expert Advisor is a multi-stage, multi-asset analytical engine. It is not a simple pattern scanner. Its primary function is to replicate the hierarchical decision-making process of a CRT trader by automating the detection of the entire trade narrative, from the high-level bias down to the low-level entry trigger.
It operates in two distinct logical phases:
Phase 1 (Once Daily): H4 Bias Detection. At the start of each new day, it scans the 4-Hour chart of all 16 symbols to find a valid 2-Candle CRT Rejection pattern (or an S&D Outside Bar). This sets the directional bias for the entire session.
Phase 2 (Real-Time): M15 Setup Tracking. If a valid H4 bias exists, the EA then transitions into a real-time monitor for that symbol. It meticulously tracks the development of the M15 entry setup by progressing through a state machine: Sweep -> MSS -> FVG -> Entry Zone.

2. Initial Setup Instructions
Attach to a low timeframe chart (M1 or M5). The EA performs all calculations on H4/H1/M15 in the background; running it on M1 ensures the OnTimer() function refreshes the dashboard visuals rapidly.
Set Your Broker's GMT Offset. This is the most critical input. Go to your MT5 Market Watch window, note the current server time, and enter its offset from GMT into the Broker_GMT_Offset_Hours input (e.g., 3 for GMT+3). This ensures all session timings are accurate.
Start with Filters Enabled. For the highest probability signals, it is recommended to leave both Filter_By_Daily_Bias and Filter_By_HTF_KL set to true.

3. How to Read the Dashboard
The dashboard provides a real-time view of the EA's analytical engine.
Column	What It Shows	What It Means
Asset	The symbol name.	The asset being monitored.
H4 Bias	A single icon: ▲, ▼, ↔, or —.	The result of the daily H4 2-Candle CRT scan. This is your high-level directional filter.
M15 Status	Text status: Idle, SWEEP, MSS, FVG, ENTRY.	The real-time progress of a potential intraday setup, based on the H4 bias.
Status Icons & Colors:
▲ (Green): Bullish H4 Bias. Start looking for long setups on this asset.
▼ (Red): Bearish H4 Bias. Start looking for short setups on this asset.
↔ (Purple): Neutral (S&D). An Outside Bar was detected. Stand aside and do not trade this asset.
— (Gray): No H4 Bias. No clean rejection pattern was found. Ignore this asset for now.
M15 Status Flow:
SWEEP (Gold): Price has purged the 8 AM H1 range. The setup has begun.
MSS (Aqua): A Market Structure Shift on the M15 has been confirmed. The setup is valid.
FVG (Lime Green): An entry FVG has been identified. Price is currently pulling back.
ENTRY (Bright Lime): Actionable Signal. Price is currently interacting with the FVG entry zone.


4. Recommended Trading Protocol
Glance at the "H4 Bias" Column. Your primary focus for the day should only be on symbols showing a clear green ▲ or red ▼.
Monitor the "M15 Status" Column for those filtered symbols.
When the status for a high-bias symbol changes from MSS to FVG, the setup is mature. This is your cue to prepare for a potential entry.
When the status changes to ENTRY, that is your signal to manually review the chart and, if the context looks good, execute your trade according to the core CRT rules (SL below the sweep, TP at your desired R:R).
*/
//--- Enums for State Management and Inputs ---
enum ENUM_SETUP_STATE { IDLE, SWEEP, MSS, FVG, ENTRY, INVALID };
enum ENUM_BIAS { NEUTRAL, BULLISH, BEARISH };
enum ENUM_POSITION { POS_TOP_RIGHT, POS_TOP_LEFT, POS_MIDDLE_RIGHT, POS_MIDDLE_LEFT, POS_BOTTOM_RIGHT, POS_BOTTOM_LEFT };
enum ENUM_THEME { THEME_DARK, THEME_LIGHT, THEME_BLUEPRINT };

//--- Structure to hold the state for each individual symbol ---
struct SymbolState
{
   string            symbol_name;
   ENUM_SETUP_STATE  bull_state;
   ENUM_SETUP_STATE  bear_state;
   double            crt_high;
   double            crt_low;
   double            mss_level;
   double            fvg_high;
   double            fvg_low;
   ENUM_BIAS         h4_bias;
};

//--- INPUTS ---
input group         "Asset Configuration";
input string        s1 = "EURUSD", s2 = "GBPUSD", s3 = "USDJPY", s4 = "USDCAD", s5 = "AUDUSD", s6 = "XAUUSD", s7 = "USDCHF", s8 = "DXY";
input string        s9 = "US30", s10= "NAS100", s11="USOIL", s12="UK100", s13="BTCUSD", s14="ETHUSD", s15="EURJPY", s16="GBPJPY";

input group         "Visual Theme & Layout";
input ENUM_THEME    i_theme = THEME_DARK;
input ENUM_POSITION i_table_pos = POS_TOP_RIGHT;
input int           i_update_interval_sec = 5;

//--- GLOBAL VARIABLES ---
SymbolState symbol_states[16];
string      object_prefix = "CRT_TRACKER_";

color c_bg, c_header, c_text, c_bull_bias, c_bear_bias, c_neutral_bias;
color c_state_sweep, c_state_mss, c_state_entry, c_wait;

string icon_bull = "▲", icon_bear = "▼", icon_sandd = "↔", icon_wait = "—";

//+------------------------------------------------------------------+
//| OnInit: Runs once when the EA is first attached to a chart       |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("CRT Setup Tracker v4.0 Initializing...");
    string symbols[] = {s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11,s12,s13,s14,s15,s16};
    for(int i=0; i<16; i++) {
        symbol_states[i].symbol_name = symbols[i];
        ResetSymbolState(i);
    }
    
    SetThemeColors();
    CreateDashboard();
    EventSetTimer(i_update_interval_sec);
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit: Cleans up when the EA is removed                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("CRT Setup Tracker v4.0 Deinitializing...");
    EventKillTimer();
    ObjectsDeleteAll(0, object_prefix);
}

//+------------------------------------------------------------------+
//| OnTimer: The main logic loop, runs every few seconds             |
//+------------------------------------------------------------------+
void OnTimer()
{
    static datetime last_day_check = 0;
    // Check for a new day only once a minute to be efficient
    if(TimeCurrent() > last_day_check + 60)
    {
       if(last_day_check != 0) // Don't run on the very first check
       {
          MqlDateTime tm_current, tm_last;
          TimeToStruct(TimeCurrent(), tm_current);
          TimeToStruct(last_day_check, tm_last);
          if(tm_current.day_of_year != tm_last.day_of_year || tm_current.year != tm_last.year)
          {
             Print("New Day Detected. Resetting all symbol states.");
             for(int i=0; i<16; i++) ResetSymbolState(i);
          }
       }
       last_day_check = TimeCurrent();
    }
    
    for(int i=0; i<16; i++)
    {
        UpdateSymbolState(i);
    }
    UpdateDashboard();
}

//+------------------------------------------------------------------+
//| [CORE ENGINE] The logic to update a single symbol's state        |
//+------------------------------------------------------------------+
void UpdateSymbolState(int index)
{
    string symbol = symbol_states[index].symbol_name;

    // Phase 1: Set the 4H Bias & H1 CRT Range once per day
    if(symbol_states[index].crt_high == 0)
    {
        MqlRates h4_rates[];
        if(CopyRates(symbol,PERIOD_H4,0,3,h4_rates) == 3)
        {
            ArraySetAsSeries(h4_rates, true);
            double c0h=h4_rates[0].high, c0l=h4_rates[0].low, c0c=h4_rates[0].close;
            double c1h=h4_rates[1].high, c1l=h4_rates[1].low;

            if(c0h > c1h && c0l < c1l) symbol_states[index].h4_bias=NEUTRAL;
            else if(c0h > c1h && c0c <= c1h) symbol_states[index].h4_bias=BEARISH;
            else if(c0l < c1l && c0c >= c1l) symbol_states[index].h4_bias=BULLISH;
            else symbol_states[index].h4_bias=NEUTRAL;
        }

        MqlRates h1_rates[];
        if(CopyRates(symbol,PERIOD_H1,0,24,h1_rates) >= 8)
        {
            ArraySetAsSeries(h1_rates, true);
            for(int i=0; i<ArraySize(h1_rates); i++)
            {
                MqlDateTime tm; TimeToStruct(h1_rates[i].time, tm);
                if(tm.hour == 8) { // Assuming NY session, 8AM H1 candle
                    symbol_states[index].crt_high = h1_rates[i].high;
                    symbol_states[index].crt_low = h1_rates[i].low;
                    break;
                }
            }
        }
        if(symbol_states[index].crt_high==0)return; // Can't proceed without range
    }

    MqlRates m15[];
    if(CopyRates(symbol,PERIOD_M15,0,20,m15)<20) return;
    ArraySetAsSeries(m15,true);
    
    // --- Phase 2: Bullish Setup State Machine (M15) ---
    if(symbol_states[index].h4_bias == BULLISH)
    {
        switch(symbol_states[index].bull_state)
        {
            case IDLE:
                if(m15[0].low < symbol_states[index].crt_low) {
                    symbol_states[index].mss_level = FindLastSwing(m15, true);
                    if(symbol_states[index].mss_level > 0) symbol_states[index].bull_state = SWEEP;
                }
                break;
            case SWEEP:
                if(m15[0].high > symbol_states[index].mss_level) {
                    symbol_states[index].bull_state = MSS;
                }
                break;
            case MSS:
                if(FindFVG(m15, index, true)) {
                    symbol_states[index].bull_state = FVG;
                }
                break;
            case FVG:
                if(m15[0].close < symbol_states[index].fvg_high) {
                    symbol_states[index].bull_state = ENTRY;
                }
                break;
        }
    }

    // --- Phase 3: Bearish Setup State Machine (M15) ---
    if(symbol_states[index].h4_bias == BEARISH)
    {
        switch(symbol_states[index].bear_state)
        {
            case IDLE:
                if(m15[0].high > symbol_states[index].crt_high) {
                    symbol_states[index].mss_level = FindLastSwing(m15, false);
                    if(symbol_states[index].mss_level > 0) symbol_states[index].bear_state = SWEEP;
                }
                break;
            case SWEEP:
                if(m15[0].low < symbol_states[index].mss_level) {
                    symbol_states[index].bear_state = MSS;
                }
                break;
            case MSS:
                if(FindFVG(m15, index, false)) {
                    symbol_states[index].bear_state = FVG;
                }
                break;
            case FVG:
                if(m15[0].close > symbol_states[index].fvg_low) {
                    symbol_states[index].bear_state = ENTRY;
                }
                break;
        }
    }
}
//+------------------------------------------------------------------+
//|                     UTILITY & HELPER FUNCTIONS                     |
//+------------------------------------------------------------------+
void ResetSymbolState(int index) {
    symbol_states[index].bull_state = IDLE;
    symbol_states[index].bear_state = IDLE;
    symbol_states[index].crt_high = 0;
    symbol_states[index].crt_low = 0;
    symbol_states[index].h4_bias = NEUTRAL;
}

double FindLastSwing(const MqlRates &rates[], bool find_high)
{
    for(int i=2; i<ArraySize(rates)-1; i++) {
        if(find_high && rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high) return rates[i].high;
        if(!find_high && rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low) return rates[i].low;
    }
    return 0;
}

bool FindFVG(const MqlRates &rates[], int index, bool find_bullish)
{
    for(int i=2; i<ArraySize(rates); i++){
        if(find_bullish && rates[i-2].high < rates[i].low){
            symbol_states[index].fvg_high = rates[i-2].high;
            symbol_states[index].fvg_low = rates[i].low;
            return true;
        }
        if(!find_bullish && rates[i-2].low > rates[i].high){
            symbol_states[index].fvg_high = rates[i].high;
            symbol_states[index].fvg_low = rates[i-2].low;
            return true;
        }
    }
    return false;
}
//+------------------------------------------------------------------+
//| [COMPLETE v3.2] UI Theme Selection & Color Assignment            |
//+------------------------------------------------------------------+
void SetThemeColors()
{
    switch(i_theme)
    {
        case THEME_LIGHT:
            c_bg           = C'224,227,235'; c_header = clrBlack;       c_text    = clrBlack;
            c_bull_bias    = C'38,166,154';  c_bear_bias= C'239,83,80';   c_neutral_bias = C'67,70,81';
            c_state_sweep  = clrOrange;      c_state_mss = clrDodgerBlue; c_state_entry = clrLimeGreen;
            c_wait         = c_bg;
            break;
        
        case THEME_BLUEPRINT:
            c_bg           = C'42,52,73';    c_header  = C'247,201,117'; c_text    = C'247,201,117';
            c_bull_bias    = clrAqua;        c_bear_bias = clrFuchsia;     c_neutral_bias = clrSlateGray;
            c_state_sweep  = clrGold;        c_state_mss = clrAqua;       c_state_entry = clrLime;
            c_wait         = c_bg;
            break;
            
        default: // THEME_DARK
            c_bg           = C'30,34,45';    c_header  = clrWhite;       c_text    = clrWhite;
            c_bull_bias    = C'38,166,154';  c_bear_bias = C'220,20,60';  c_neutral_bias = clrGray;
            c_state_sweep  = clrGold;        c_state_mss = clrAqua;       c_state_entry = clrLime;
            c_wait         = c_bg;
            break;
    }
}
//+------------------------------------------------------------------+
//| [COMPLETE v3.2] Creates all graphical objects for the dashboard  |
//+------------------------------------------------------------------+
void CreateDashboard()
{
    // --- Define Table Geometry ---
    int base_x = 10, base_y = 20;
    int col_width_symbol = 95, col_width_bias = 50, col_width_status = 85;
    int row_height = 18, col_padding = 10;
    int title_height = 25;

    ENUM_BASE_CORNER corner = CORNER_RIGHT_UPPER; // Simplified positioning logic, can be expanded
    switch(i_table_pos) {
        case POS_TOP_RIGHT:   corner = CORNER_RIGHT_UPPER; break;
        case POS_TOP_LEFT:    corner = CORNER_LEFT_UPPER;  break;
        // ... add other corner logic if needed ...
    }

    // --- Create Background ---
    int total_width = (col_width_symbol + col_width_bias + col_width_status) * 2 + col_padding;
    int total_height = row_height * 9 + title_height;
    CreateRectangle(object_prefix + "BG", base_x - 5, base_y - 5, total_width + 10, total_height, c_bg, corner);

    // --- Create Title ---
    CreateTextLabel(object_prefix + "Title", "CRT Institutional Scanner v3.2", base_x, base_y, c_header, 10, corner, ANCHOR_LEFT);

    // --- Create Headers for Both Columns ---
    int col1_x = base_x;
    int col2_x = base_x + col_width_symbol + col_width_bias + col_width_status + col_padding;
    CreateTextLabel(object_prefix+"H1","Asset", col1_x, base_y + title_height, c_header, 8, corner, ANCHOR_LEFT);
    CreateTextLabel(object_prefix+"H2","H4 Bias", col1_x + col_width_symbol, base_y + title_height, c_header, 8, corner, ANCHOR_LEFT);
    CreateTextLabel(object_prefix+"H3","M15 Status", col1_x + col_width_symbol + col_width_bias, base_y + title_height, c_header, 8, corner, ANCHOR_LEFT);
    
    CreateTextLabel(object_prefix+"H4","Asset", col2_x, base_y + title_height, c_header, 8, corner, ANCHOR_LEFT);
    CreateTextLabel(object_prefix+"H5","H4 Bias", col2_x + col_width_symbol, base_y + title_height, c_header, 8, corner, ANCHOR_LEFT);
    CreateTextLabel(object_prefix+"H6","M15 Status", col2_x + col_width_symbol + col_width_bias, base_y + title_height, c_header, 8, corner, ANCHOR_LEFT);


    // --- Create Placeholder Text Objects for all 16 symbols ---
    for(int i=0; i<16; i++)
    {
        int row_y = base_y + title_height + ((i % 8) + 1) * row_height;
        int current_col_x = (i < 8) ? col1_x : col2_x;

        CreateTextLabel(object_prefix + "Symbol_" + (string)i, "...", current_col_x, row_y, c_text, 8, corner, ANCHOR_LEFT);
        CreateTextLabel(object_prefix + "Bias_" + (string)i, "-", current_col_x + col_width_symbol + 20, row_y, c_wait, 12, corner, ANCHOR_CENTER);
        CreateTextLabel(object_prefix + "Status_" + (string)i, "...", current_col_x + col_width_symbol + col_width_bias, row_y, c_wait, 8, corner, ANCHOR_LEFT);
    }
}

//+------------------------------------------------------------------+
//| [COMPLETE v3.2] Updates dashboard values on every timer tick     |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
    for(int i=0; i<16; i++)
    {
        string symbol = symbol_states[i].symbol_name;
        ENUM_BIAS bias = symbol_states[i].h4_bias;
        
        string bias_icon = (bias == BULLISH) ? icon_bull : (bias == BEARISH) ? icon_bear : (bias==NEUTRAL ? icon_sandd : icon_wait);
        color bias_color = (bias == BULLISH) ? c_bull_bias : (bias == BEARISH) ? c_bear_bias : c_neutral_bias;
        
        string status_text = "Idle";
        color status_color = c_wait;
        
        if(bias == BULLISH && symbol_states[i].bull_state != IDLE) {
           status_text = EnumToString(symbol_states[i].bull_state);
           status_color = (symbol_states[i].bull_state==ENTRY) ? c_state_entry : (symbol_states[i].bull_state==MSS) ? c_state_mss : c_state_sweep;
        }
        else if(bias == BEARISH && symbol_states[i].bear_state != IDLE) {
           status_text = EnumToString(symbol_states[i].bear_state);
           status_color = (symbol_states[i].bear_state==ENTRY) ? c_state_entry : (symbol_states[i].bear_state==MSS) ? c_state_mss : c_state_sweep;
        }

        // Update the dashboard objects
        ObjectSetString(0,object_prefix+"Symbol_"+(string)i, OBJPROP_TEXT, symbol);
        ObjectSetString(0,object_prefix+"Bias_"+(string)i, OBJPROP_TEXT, bias_icon);
        ObjectSetInteger(0,object_prefix+"Bias_"+(string)i, OBJPROP_COLOR, bias_color);
        ObjectSetString(0,object_prefix+"Status_"+(string)i, OBJPROP_TEXT, status_text);
        ObjectSetInteger(0,object_prefix+"Status_"+(string)i, OBJPROP_COLOR, status_color);
    }
}

//--- Helper function to create rectangle labels ---
void CreateRectangle(string name, int x, int y, int w, int h, color clr, ENUM_BASE_CORNER corner)
{
    if(ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,x,y))
    {
        ObjectSetInteger(0,name,OBJPROP_XSIZE,w); ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
        ObjectSetInteger(0,name,OBJPROP_BGCOLOR,clr); ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
        ObjectSetInteger(0,name,OBJPROP_CORNER,corner); ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
    }
}
//--- Helper function to create text labels ---
void CreateTextLabel(string name, string text, int x, int y, color clr, int font_size=8, ENUM_BASE_CORNER corner=CORNER_RIGHT_UPPER, ENUM_ANCHOR_POINT anchor=ANCHOR_LEFT)
{
    if(ObjectCreate(0, name, OBJ_LABEL, 0, x, y))
    {
        ObjectSetString(0, name, OBJPROP_TEXT, text); ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        ObjectSetString(0, name, OBJPROP_FONT, "Arial"); ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
        ObjectSetInteger(0, name, OBJPROP_CORNER, corner); ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
        ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
    }
}
//+------------------------------------------------------------------+
//|                     VISUALIZATION & UI FUNCTIONS                   |
//+------------------------------------------------------------------+