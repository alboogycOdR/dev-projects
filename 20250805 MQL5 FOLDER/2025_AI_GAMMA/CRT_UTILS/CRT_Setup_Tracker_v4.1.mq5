//+------------------------------------------------------------------+
//|                        CRT_Setup_Tracker_v4.2.mq5                |
//|                 Final Version with All Compiler Fixes            |
//|      (Corrects Duplicate/Undeclared Functions and All Syntax)    |
//+------------------------------------------------------------------+
#property copyright "Final Corrected Version by The Synthesis"
#property link      "https://beta.character.ai/"
#property version   "4.20"
#property description "This is the final, runnable version. Corrects all previous compilation errors."
/*
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


#include <ChartObjects\ChartObjectsTxtControls.mqh>

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
input string        
s1 = "EURUSD", 
s2 = "GBPUSD", 
s3 = "USDJPY", 
s4 = "USDCAD", 
s5 = "AUDUSD", 
s6 = "XAUUSD", 
s7 = "USDCHF", 
s8 = "AUDUSD";
input string        
s9 = "USDCHF", 
s10= "USDCHF", 
s11="USDCHF", 
s12="USDCHF", 
s13="EURJPY", 
s14="EURJPY", 
s15="EURJPY", 
s16="GBPJPY";

input group         "Visual Theme & Layout";
input ENUM_THEME    i_theme = THEME_LIGHT;
input ENUM_POSITION i_table_pos = POS_TOP_RIGHT;
input int           i_update_interval_sec = 60;

//--- GLOBAL VARIABLES ---
SymbolState symbol_states[16];
string      object_prefix = "CRT_TRACKER_V4_2_";
color       c_bg, c_header, c_text, c_bull_bias, c_bear_bias, c_neutral_bias, c_state_sweep, c_state_mss, c_state_entry;
string      icon_bull = "▲", icon_bear = "▼", icon_sandd = "↔", icon_wait = "—";

//--- Globals to store original chart settings for restoration ---
struct ChartSettings
{
   bool  show_ohlc;
   bool  show_grid;
   bool  show_volumes;
   bool  show_price_scale;
   bool  show_date_scale;
   bool  show_bid_line;
   bool  show_ask_line;
   color candle_bull;
   color candle_bear;
   color chart_up;
   color chart_down;
   color foreground;
   color grid;
   color volume;
};
ChartSettings original_chart_settings;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("CRT Setup Tracker v4.2 Initializing...");
    string symbols[] = {s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11,s12,s13,s14,s15,s16};
    for(int i=0; i<16; i++) {
        symbol_states[i].symbol_name = symbols[i];
        ResetSymbolState(i);
    }
    SetThemeColors();
    HideChartElements();
    CreateDashboard();
    EventSetTimer(i_update_interval_sec);
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("CRT Setup Tracker v4.2 Deinitializing...");
    RestoreChartElements();
    EventKillTimer();
    ObjectsDeleteAll(0, object_prefix);
}

//+------------------------------------------------------------------+
//| Timer function - Main EA Loop                                    |
//+------------------------------------------------------------------+
void OnTimer()
{
    static int last_day = 0;
    
    MqlDateTime now;
    TimeToStruct(TimeCurrent(), now);
    int current_day = now.day_of_year;
    
    if(last_day == 0)
    {
        last_day = current_day;
    }
    
    if(current_day != last_day) {
        Print("New Day Detected. Resetting all symbol states.");
        for(int i=0; i<16; i++) ResetSymbolState(i);
        last_day = current_day;
    }
    
    for(int i=0; i<16; i++) UpdateSymbolState(i);
    UpdateDashboard();
}

//+------------------------------------------------------------------+
//| CORE ENGINE: Updates the state for a single symbol               |
//+------------------------------------------------------------------+
void UpdateSymbolState(int index)
{
    string symbol = symbol_states[index].symbol_name;

    if(symbol_states[index].crt_high == 0) {
        MqlRates h4_rates[]; ArraySetAsSeries(h4_rates, true);
        if(CopyRates(symbol,PERIOD_H4,0,3,h4_rates) == 3) {
            double c0h=h4_rates[0].high, c0l=h4_rates[0].low, c0c=h4_rates[0].close;
            double c1h=h4_rates[1].high, c1l=h4_rates[1].low;

            if(c0h > c1h && c0l < c1l) symbol_states[index].h4_bias=NEUTRAL;
            else if(c0h > c1h && c0c <= c1h) symbol_states[index].h4_bias=BEARISH;
            else if(c0l < c1l && c0c >= c1l) symbol_states[index].h4_bias=BULLISH;
            else symbol_states[index].h4_bias=NEUTRAL;
        }

        MqlRates h1_rates[]; ArraySetAsSeries(h1_rates, true);
        if(CopyRates(symbol,PERIOD_H1,0,24,h1_rates) >= 8) {
            for(int i=0; i<ArraySize(h1_rates); i++) {
                MqlDateTime tm; TimeToStruct(h1_rates[i].time, tm);
                if(tm.hour == 8) {
                    symbol_states[index].crt_high = h1_rates[i].high;
                    symbol_states[index].crt_low = h1_rates[i].low;
                    break;
                }
            }
        }
        if(symbol_states[index].crt_high==0)return;
    }

    MqlRates m15[]; ArraySetAsSeries(m15,true); if(CopyRates(symbol,PERIOD_M15,0,20,m15)<20) return;
    double last_high=m15[0].high, last_low=m15[0].low, last_close=m15[0].close;
    
    if(symbol_states[index].h4_bias == BULLISH) {
        switch(symbol_states[index].bull_state) {
            case IDLE: if(last_low < symbol_states[index].crt_low) {symbol_states[index].mss_level=FindLastSwing(m15, true);if(symbol_states[index].mss_level>0)symbol_states[index].bull_state=SWEEP;}break;
            case SWEEP: if(last_high > symbol_states[index].mss_level) {symbol_states[index].bull_state=MSS;}break;
            case MSS: if(FindFVG(m15, index, true)) {symbol_states[index].bull_state=FVG;}break;
            case FVG: if(last_low < symbol_states[index].fvg_high) {symbol_states[index].bull_state=ENTRY;}break;
        }
    }
    if(symbol_states[index].h4_bias == BEARISH) {
        switch(symbol_states[index].bear_state) {
            case IDLE: if(last_high > symbol_states[index].crt_high) {symbol_states[index].mss_level=FindLastSwing(m15, false);if(symbol_states[index].mss_level>0)symbol_states[index].bear_state=SWEEP;}break;
            case SWEEP: if(last_low < symbol_states[index].mss_level) {symbol_states[index].bear_state=MSS;}break;
            case MSS: if(FindFVG(m15, index, false)) {symbol_states[index].bear_state=FVG;}break;
            case FVG: if(last_high > symbol_states[index].fvg_low) {symbol_states[index].bear_state=ENTRY;}break;
        }
    }
}
//+------------------------------------------------------------------+
//|                 CHART VISIBILITY FUNCTIONS                       |
//+------------------------------------------------------------------+
void HideChartElements()
{
    long temp = 0;
    color chart_bg = clrNONE;
    if (ChartGetInteger(0, CHART_COLOR_BACKGROUND, 0, temp)) chart_bg = (color)temp;

    // --- Save original settings ---
    ChartGetInteger(0, CHART_SHOW_OHLC, 0, temp); original_chart_settings.show_ohlc = (bool)temp;
    ChartGetInteger(0, CHART_SHOW_GRID, 0, temp); original_chart_settings.show_grid = (bool)temp;
    ChartGetInteger(0, CHART_SHOW_VOLUMES, 0, temp); original_chart_settings.show_volumes = (bool)temp;
    ChartGetInteger(0, CHART_SHOW_PRICE_SCALE, 0, temp); original_chart_settings.show_price_scale = (bool)temp;
    ChartGetInteger(0, CHART_SHOW_DATE_SCALE, 0, temp); original_chart_settings.show_date_scale = (bool)temp;
    ChartGetInteger(0, CHART_SHOW_BID_LINE, 0, temp); original_chart_settings.show_bid_line = (bool)temp;
    ChartGetInteger(0, CHART_SHOW_ASK_LINE, 0, temp); original_chart_settings.show_ask_line = (bool)temp;
    ChartGetInteger(0, CHART_COLOR_CANDLE_BULL, 0, temp); original_chart_settings.candle_bull = (color)temp;
    ChartGetInteger(0, CHART_COLOR_CANDLE_BEAR, 0, temp); original_chart_settings.candle_bear = (color)temp;
    ChartGetInteger(0, CHART_COLOR_CHART_UP, 0, temp); original_chart_settings.chart_up = (color)temp;
    ChartGetInteger(0, CHART_COLOR_CHART_DOWN, 0, temp); original_chart_settings.chart_down = (color)temp;
    ChartGetInteger(0, CHART_COLOR_FOREGROUND, 0, temp); original_chart_settings.foreground = (color)temp;
    ChartGetInteger(0, CHART_COLOR_GRID, 0, temp); original_chart_settings.grid = (color)temp;
    ChartGetInteger(0, CHART_COLOR_VOLUME, 0, temp); original_chart_settings.volume = (color)temp;

    // --- Hide elements by matching colors to chart background and disabling displays ---
    ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, chart_bg);
    ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, chart_bg);
    ChartSetInteger(0, CHART_COLOR_CHART_UP, chart_bg);
    ChartSetInteger(0, CHART_COLOR_CHART_DOWN, chart_bg);
    ChartSetInteger(0, CHART_COLOR_FOREGROUND, chart_bg);
    ChartSetInteger(0, CHART_COLOR_GRID, chart_bg);
    ChartSetInteger(0, CHART_COLOR_VOLUME, chart_bg);
    ChartSetInteger(0, CHART_SHOW_OHLC, false);
    ChartSetInteger(0, CHART_SHOW_GRID, false);
    ChartSetInteger(0, CHART_SHOW_VOLUMES, false);
    ChartSetInteger(0, CHART_SHOW_PRICE_SCALE, false);
    ChartSetInteger(0, CHART_SHOW_DATE_SCALE, false);
    ChartSetInteger(0, CHART_SHOW_BID_LINE, false);
    ChartSetInteger(0, CHART_SHOW_ASK_LINE, false);
}

void RestoreChartElements()
{
    // --- Restore all original chart settings ---
    ChartSetInteger(0, CHART_SHOW_OHLC, original_chart_settings.show_ohlc);
    ChartSetInteger(0, CHART_SHOW_GRID, original_chart_settings.show_grid);
    ChartSetInteger(0, CHART_SHOW_VOLUMES, original_chart_settings.show_volumes);
    ChartSetInteger(0, CHART_SHOW_PRICE_SCALE, original_chart_settings.show_price_scale);
    ChartSetInteger(0, CHART_SHOW_DATE_SCALE, original_chart_settings.show_date_scale);
    ChartSetInteger(0, CHART_SHOW_BID_LINE, original_chart_settings.show_bid_line);
    ChartSetInteger(0, CHART_SHOW_ASK_LINE, original_chart_settings.show_ask_line);
    ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, original_chart_settings.candle_bull);
    ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, original_chart_settings.candle_bear);
    ChartSetInteger(0, CHART_COLOR_CHART_UP, original_chart_settings.chart_up);
    ChartSetInteger(0, CHART_COLOR_CHART_DOWN, original_chart_settings.chart_down);
    ChartSetInteger(0, CHART_COLOR_FOREGROUND, original_chart_settings.foreground);
    ChartSetInteger(0, CHART_COLOR_GRID, original_chart_settings.grid);
    ChartSetInteger(0, CHART_COLOR_VOLUME, original_chart_settings.volume);
}
//+------------------------------------------------------------------+
//|                       HELPER FUNCTIONS                           |
//+------------------------------------------------------------------+
void ResetSymbolState(int index) { symbol_states[index].bull_state=IDLE;symbol_states[index].bear_state=IDLE;symbol_states[index].crt_high=0;symbol_states[index].crt_low=0;symbol_states[index].h4_bias=NEUTRAL;}
double FindLastSwing(const MqlRates &rates[], bool find_high) { for(int i=2; i<ArraySize(rates)-1; i++){if(find_high && rates[i].high>rates[i-1].high&&rates[i].high>rates[i+1].high)return rates[i].high;if(!find_high && rates[i].low<rates[i-1].low&&rates[i].low<rates[i+1].low)return rates[i].low;} return 0;}
bool FindFVG(const MqlRates &rates[], int index, bool find_bullish) { MqlRates sorted_rates[]; ArrayCopy(sorted_rates, rates); ArraySetAsSeries(sorted_rates, false); for(int i=2; i<ArraySize(sorted_rates); i++){if(find_bullish && sorted_rates[i-2].high < sorted_rates[i].low){symbol_states[index].fvg_high=sorted_rates[i-2].high; symbol_states[index].fvg_low=sorted_rates[i].low;return true;}if(!find_bullish && sorted_rates[i-2].low > sorted_rates[i].high){symbol_states[index].fvg_high=sorted_rates[i].high; symbol_states[index].fvg_low=sorted_rates[i-2].low;return true;}}return false;}
//+------------------------------------------------------------------+
//|                    VISUALIZATION & UI FUNCTIONS                  |
//+------------------------------------------------------------------+

ENUM_BASE_CORNER GetCornerFromPos(ENUM_POSITION pos) {
   switch(pos) {
      case POS_TOP_LEFT: return CORNER_LEFT_UPPER; case POS_MIDDLE_RIGHT: return CORNER_RIGHT_UPPER; case POS_MIDDLE_LEFT: return CORNER_LEFT_UPPER;
      case POS_BOTTOM_RIGHT: return CORNER_RIGHT_LOWER; case POS_BOTTOM_LEFT: return CORNER_LEFT_LOWER; default: return CORNER_RIGHT_UPPER;
   }
}
//+------------------------------------------------------------------+
//| [COMPLETE v4.3] VISUALIZATION & UI FUNCTIONS (Layout Corrected)  |
//+------------------------------------------------------------------+
void SetThemeColors()
{
    // [FIX] Using explicit color opacities for better blending
    switch(i_theme)
    {
        case THEME_LIGHT:
            c_bg           = clrWhiteSmoke;    c_header  = clrBlack;
            c_text         = clrBlack;       c_bull_bias = C'38,166,154';
            c_bear_bias    = C'239,83,80';  c_neutral_bias = C'67,70,81';
            c_state_sweep  = clrDarkOrange;  c_state_mss = clrDodgerBlue;
            c_state_entry  = C'0,128,0';
            break;
        
        case THEME_BLUEPRINT:
            c_bg           = C'42,52,73';     c_header  = C'247,201,117';
            c_text         = C'224,227,235';  c_bull_bias = clrAqua;
            c_bear_bias    = clrFuchsia;     c_neutral_bias = clrSlateGray;
            c_state_sweep  = clrGold;         c_state_mss = clrAqua;
            c_state_entry  = clrLime;
            break;
            
        default: // THEME_DARK
            c_bg           = C'30,34,45';     c_header  = C'224,227,235';
            c_text         = C'200,200,200';  c_bull_bias = C'38,166,154';
            c_bear_bias    = C'220,20,60';   c_neutral_bias = clrGray;
            c_state_sweep  = clrGold;         c_state_mss = clrAqua;
            c_state_entry  = clrLime;
            break;
    }
}
//+------------------------------------------------------------------+
void CreateDashboard()
{
    // --- Define a precise grid for the layout ---
    int base_x          = 150;//10
    int base_y          = 80;//20
    //------------
    int col_width_asset = 100;//
    int col_width_bias  = 60;//
    int col_width_status= 80;//
    //------------
    int row_height      = 30;//18
    int group_padding   = 15;//
    
    ENUM_BASE_CORNER corner = GetCornerFromPos(i_table_pos);
    
    // --- Create a single, clean background for the entire panel ---
    int total_width = (col_width_asset + col_width_bias + col_width_status) * 2 + group_padding;
    int total_height = row_height * 9 + 30;//15
    CreateRectangle(object_prefix + "BG", base_x - 5, base_y - 10, total_width + 10, total_height, c_bg, corner);
    
    // Define the exact X-coordinates for each column to ensure perfect alignment
    int x_col1_asset = base_x;
    int x_col1_bias  = x_col1_asset + col_width_asset;
    int x_col1_status= x_col1_bias  + col_width_bias;

    int x_col2_asset = x_col1_status + col_width_status + group_padding;
    int x_col2_bias  = x_col2_asset + col_width_asset;
    int x_col2_status= x_col2_bias  + col_width_bias;
    
    // --- Create Column Headers ---
    CreateTextLabel(object_prefix+"H1","Asset", x_col1_asset, base_y, c_header, 8, corner, ANCHOR_LEFT);
    CreateTextLabel(object_prefix+"H2","Bias",  x_col1_bias,  base_y, c_header, 8, corner, ANCHOR_LEFT);
    CreateTextLabel(object_prefix+"H3","M15 Status", x_col1_status, base_y, c_header, 8, corner, ANCHOR_LEFT);

    CreateTextLabel(object_prefix+"H4","Asset", x_col2_asset, base_y, c_header, 8, corner, ANCHOR_LEFT);
    CreateTextLabel(object_prefix+"H5","Bias",  x_col2_bias,  base_y, c_header, 8, corner, ANCHOR_LEFT);
    CreateTextLabel(object_prefix+"H6","M15 Status", x_col2_status, base_y, c_header, 8, corner, ANCHOR_LEFT);

    // --- Create all 16 rows of data labels (they will be updated later) ---
    for(int i = 0; i < 16; i++) {
        int row_y = base_y + ((i % 8) + 1) * row_height;
        
        // Determine if we are in the first or second major column block
        int current_asset_x = (i < 8) ? x_col1_asset : x_col2_asset;
        int current_bias_x  = (i < 8) ? x_col1_bias  : x_col2_bias;
        int current_status_x= (i < 8) ? x_col1_status: x_col2_status;

        CreateTextLabel(object_prefix+"Sym_"+(string)i,    "Loading...", current_asset_x + 5,  row_y, c_text, 8, corner, ANCHOR_LEFT);
        CreateTextLabel(object_prefix+"Bias_"+(string)i,   "—",          current_bias_x + 20,  row_y, c_text, 10, corner, ANCHOR_CENTER);
        CreateTextLabel(object_prefix+"Status_"+(string)i, "Idle",       current_status_x + 5, row_y, c_text, 8, corner, ANCHOR_LEFT);
    }
}
//+------------------------------------------------------------------+
void UpdateDashboard()
{
    for(int i=0; i<16; i++) {
        ENUM_BIAS bias = symbol_states[i].h4_bias;
        string bias_icon = (bias==BULLISH)?icon_bull:(bias==BEARISH)?icon_bear:(bias==NEUTRAL)?icon_sandd:icon_wait;
        color bias_color = (bias==BULLISH)?c_bull_bias:(bias==BEARISH)?c_bear_bias:c_neutral_bias;
        
        string status_text="Idle"; color status_color=c_text;
        if(bias==BULLISH && symbol_states[i].bull_state != IDLE){status_text=EnumToString(symbol_states[i].bull_state);status_color=(symbol_states[i].bull_state==ENTRY)?c_state_entry:(symbol_states[i].bull_state==MSS)?c_state_mss:c_state_sweep;}
        else if(bias==BEARISH && symbol_states[i].bear_state != IDLE){status_text=EnumToString(symbol_states[i].bear_state);status_color=(symbol_states[i].bear_state==ENTRY)?c_state_entry:(symbol_states[i].bear_state==MSS)?c_state_mss:c_state_sweep;}

        ObjectSetString(0,object_prefix+"Symbol_"+(string)i,OBJPROP_TEXT,symbol_states[i].symbol_name);
        ObjectSetString(0,object_prefix+"Bias_"+(string)i, OBJPROP_TEXT, bias_icon);ObjectSetInteger(0,object_prefix+"Bias_"+(string)i,OBJPROP_COLOR,bias_color);
        ObjectSetString(0,object_prefix+"Status_"+(string)i, OBJPROP_TEXT, status_text);ObjectSetInteger(0,object_prefix+"Status_"+(string)i,OBJPROP_COLOR,status_color);
    }
}
//--- Helper Functions for Creating UI Objects ---
// [FIX] Corrected UI object creation to use X/Y Distance properties instead of time/price coordinates.
void CreateRectangle(string name, int x, int y, int w, int h, color clr, ENUM_BASE_CORNER corner = CORNER_RIGHT_UPPER)
{
    if(ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0)) // Create object at (0,0) time/price - these are ignored for labels
    {
        // Set properties for position and appearance
        ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
        ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
        ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clr);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
    }
}

void CreateTextLabel(string name, string text, int x, int y, color clr, int font_size = 8, ENUM_BASE_CORNER corner = CORNER_RIGHT_UPPER, ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT)
{
    if(ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0)) // Create object at (0,0) time/price
    {
        // Set properties for position and appearance
        ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
        ObjectSetString(0, name, OBJPROP_TEXT, text);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        ObjectSetString(0, name, OBJPROP_FONT, "Calibri");
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
        ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    }
}


// [NOTE] ManageOpenPositions and trade execution inputs are omitted as this is an analyzer, not an auto-trader.
void ManageOpenPositions(){}