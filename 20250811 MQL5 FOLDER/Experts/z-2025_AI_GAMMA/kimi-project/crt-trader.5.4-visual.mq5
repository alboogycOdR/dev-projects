//+------------------------------------------------------------------+
//|                        CRT-Trader-5.4-Visual.mq5                 |
//|                Copyright 2024, QWEN AI & Gemini AI                 |
//|                                  www.metaquotes.net                |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, QWEN AI & Gemini AI"
#property link      "https://www.metaquotes.net"
#property version   "5.4"
#property description "A corrected and logically sound implementation of the CRT model with visualizations."

#include <Trade\Trade.mqh>
#include <Canvas\Canvas.mqh>

//16 & 15 on EURUSD

// --- CORE LOGIC DEFS ---
enum ENUM_SETUP_STATE { IDLE, SWEEP, MSS, FVG, ENTRY, INVALID };
enum ENUM_BIAS        { NEUTRAL, BULLISH, BEARISH };

struct CRT_State
{
   string            symbol;
   ENUM_BIAS         bias;
   datetime          bias_time;
   double            crt_high;
   double            crt_low;
   double            sweep_high; // Price of the actual sweep high
   double            sweep_low;  // Price of the actual sweep low
   double            mss_level;
   datetime          mss_confirmed_time; // The time the MSS break occurred
   double            fvg_high;
   double            fvg_low;
   ENUM_SETUP_STATE  bull_state;
   ENUM_SETUP_STATE  bear_state;
};

//--- EA Inputs ---
input group "Trade Settings"
input bool   use_atr_sl = true;          // Use ATR for Stop Loss
input int    atr_period = 14;            // ATR Period
input double atr_multiplier = 2.5;       // ATR Multiplier
input double risk_reward_ratio = 2.0;    // Risk/Reward Ratio
input double input_lots = 0.01;            // Fixed Lot Size

input group "Visualization Settings"
input bool   Use_FVG_SizeValidation = true; // Validate FVG size against minimum
input double MinFVGSizePips = 0.5;          // Minimum FVG size in pips for it to be valid
input bool   Use_EntryConfirmation = true;  // Require an engulfing candle at the FVG for entry

input group "Telegram Notifications"
input string TelegramToken = "";       // Your Telegram Bot Token
input string TelegramChatID = "";      // Your Telegram Chat ID

//--- Global Variables ---
CTrade trade;
CRT_State states[1]; // Array to hold states for multiple symbols if needed. For now, just one.
string g_symbol_name;
int atr_handle = INVALID_HANDLE;
CCanvas g_bias_canvas;

// --- Core Logic Function Prototypes ---
void M15_Step(CRT_State &s);
void ResetState(CRT_State &s, string symbol);
ENUM_BIAS CRT_Bias(string symbol, datetime &range_time, datetime &sweep_time, double &range_high, double &range_low);
double FindLastSwing(const MqlRates &rates[], bool find_high, int &swing_idx);
bool FindFVG(const MqlRates &rates[], CRT_State &s, bool find_bullish, int start_idx);
bool IsBullishEngulfing(const MqlRates &rates[], int index);
bool IsBearishEngulfing(const MqlRates &rates[], int index);

// --- Visualization Function Prototypes ---
void UpdateVisuals(CRT_State &s);
void DeleteChartObjects();
void DrawStateIndicator(CRT_State &s);
void DrawCRTRange(CRT_State &s);
void DrawSwingPoint(CRT_State &s);
void DrawFVGZone(CRT_State &s);
void DrawMSSConfirmation(CRT_State &s);
void DrawFVGSizeIndicator(CRT_State &s);
void DrawEntryZones(CRT_State &s);
void DrawEntryConfirmation(CRT_State &s);
void DrawBiasStrength(CRT_State &s);

//+------------------------------------------------------------------+
//| Send POST request to Telegram API                                |
//+------------------------------------------------------------------+
void Telegram_Send(string token, string chat_id, string message)
{
   if(token=="" || chat_id=="")
      return;

   //--- Create the request
   string url="https://api.telegram.org/bot"+token+"/sendMessage";
   string headers;
   char post[],result[];
   string data="chat_id="+chat_id+"&text="+message;
   
   //--- Convert string to char array
   StringToCharArray(data,post,0,StringLen(data));
   
   //--- Send request
   ResetLastError();
   int res=WebRequest("POST",url,NULL,NULL,5000,post,ArraySize(post),result,headers);
   
   //--- Check result
   if(res==-1)
     {
      Print("Error in WebRequest. Error code=",GetLastError());
     }
   else
     {
      //Print("Request sent. Server response: ",CharArrayToString(result));
     }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    g_symbol_name = Symbol();
    ResetState(states[0], g_symbol_name);
    trade.SetExpertMagicNumber(12345);
    trade.SetDeviationInPoints(10);
    trade.SetTypeFilling(ORDER_FILLING_FOK);

    // --- Initialize ATR Indicator ---
    if(use_atr_sl)
    {
        atr_handle = iATR(g_symbol_name, PERIOD_M15, atr_period);
        if(atr_handle == INVALID_HANDLE)
        {
            Print("Error creating ATR indicator handle. Error code: ", GetLastError());
            return(INIT_FAILED);
        }
    }
    
    // --- Initialize Graphics Library ---
    if(!g_bias_canvas.CreateBitmapLabel(0, 0, "BiasGauge", 10, 50, 200, 40))
    {
        Print("Error creating canvas for Bias Gauge: ", GetLastError());
        return(INIT_FAILED);
    }
    
    DeleteChartObjects(); // Clear previous objects on init
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // --- Release Indicator Handle ---
    if(atr_handle != INVALID_HANDLE)
    {
        IndicatorRelease(atr_handle);
    }
    g_bias_canvas.Destroy();
    ObjectsDeleteAll(0, "CRT_VISUAL_"); // Also delete canvas object
    DeleteChartObjects(); // Clear objects on deinit
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    datetime range_time, sweep_time;
    double range_high, range_low;

    // --- 1. Determine H4 Bias ---
    if(states[0].bias == NEUTRAL) {
        ENUM_BIAS detected_bias = CRT_Bias(g_symbol_name, range_time, sweep_time, range_high, range_low);
        if(detected_bias != NEUTRAL) {
            states[0].bias = detected_bias;
            states[0].bias_time = range_time; // Store the time of the range bar
            states[0].crt_high = range_high;
            states[0].crt_low = range_low;
            Print(g_symbol_name, " | New H4 Bias Detected: ", EnumToString(states[0].bias));
        }
    }

    // --- 2. Step through the M15 State Machine ---
    M15_Step(states[0]);

    // --- 3. Manage Trades based on State ---
    ManageTrade(states[0]);
    
    // --- 4. Update Visualizations ---
    UpdateVisuals(states[0]);

    // --- 5. Reset Logic ---
    // Reset if a new H4 bar forms and we are not in a trade.
    static datetime last_h4_time = 0;
    MqlRates h4[];
    CopyRates(g_symbol_name, PERIOD_H4, 0, 1, h4);
    if(ArraySize(h4) > 0 && last_h4_time != h4[0].time)
    {
        last_h4_time = h4[0].time;
        if(states[0].bias != NEUTRAL && !PositionSelect(g_symbol_name))
        {
             Print(g_symbol_name, " | Resetting state on new H4 bar.");
             ResetState(states[0], g_symbol_name);
        }
    }
}

//+------------------------------------------------------------------+
//| ManageTrade: Opens/closes trades based on the state machine.     |
//+------------------------------------------------------------------+
void ManageTrade(CRT_State &s)
{
    if(!PositionSelect(s.symbol))
    {
        if(s.bias == BULLISH && s.bull_state == ENTRY)
        {
            double ask_price = SymbolInfoDouble(s.symbol, SYMBOL_ASK);
            double point = SymbolInfoDouble(s.symbol, SYMBOL_POINT);
            double spread = SymbolInfoInteger(s.symbol, SYMBOL_SPREAD) * point;
            
            double sl_price = s.sweep_low - spread;
            if(use_atr_sl && atr_handle != INVALID_HANDLE) {
                double atr_buffer[];
                if(CopyBuffer(atr_handle, 0, 1, 1, atr_buffer) > 0)
                {
                    double atr_value = atr_buffer[0];
                    sl_price = ask_price - (atr_value * atr_multiplier);
                }
            }
            double tp_price = ask_price + (ask_price - sl_price) * risk_reward_ratio;

            if(trade.Buy(input_lots, s.symbol, ask_price, sl_price, tp_price, "CRT Buy Signal")) {
                SendTradeAlert(s, "BUY", ask_price, sl_price, tp_price);
                ResetState(s, s.symbol); // Reset state after taking trade to prevent re-entry
            }
        }
        else if(s.bias == BEARISH && s.bear_state == ENTRY)
        {
            double bid_price = SymbolInfoDouble(s.symbol, SYMBOL_BID);
            double point = SymbolInfoDouble(s.symbol, SYMBOL_POINT);
            double spread = SymbolInfoInteger(s.symbol, SYMBOL_SPREAD) * point;

            double sl_price = s.sweep_high + spread;
            if(use_atr_sl && atr_handle != INVALID_HANDLE) {
                double atr_buffer[];
                if(CopyBuffer(atr_handle, 0, 1, 1, atr_buffer) > 0)
                {
                    double atr_value = atr_buffer[0];
                    sl_price = bid_price + (atr_value * atr_multiplier);
                }
            }
            double tp_price = bid_price - (sl_price - bid_price) * risk_reward_ratio;
            
            if(trade.Sell(input_lots, s.symbol, bid_price, sl_price, tp_price, "CRT Sell Signal")) {
                SendTradeAlert(s, "SELL", bid_price, sl_price, tp_price);
                ResetState(s, s.symbol); // Reset state after taking trade
            }
        }
    }
}
//+------------------------------------------------------------------+
//| Send Telegram alert with emoji and trade details                 |
//+------------------------------------------------------------------+
void SendTradeAlert(CRT_State &s, string direction, double price, double sl, double tp)
{
   if(TelegramToken=="" || TelegramChatID=="") return;
   string entry_emoji = (direction == "BUY") ? "🐂" : "🐻";
   string message = entry_emoji + " CRT-TRADE: " + s.symbol + " " + direction + " | " +
                   "Entry: "+DoubleToString(price, _Digits) + " | " +
                   "SL: " + DoubleToString(sl, _Digits) + " | " +
                   "TP: " + DoubleToString(tp, _Digits);
   Telegram_Send(TelegramToken, TelegramChatID, message);
}
//+------------------------------------------------------------------+
//| [VISUALIZATION] Main Drawing Functions                           |
//+------------------------------------------------------------------+
void UpdateVisuals(CRT_State &s)
{
    // Clear old objects before drawing new ones to prevent clutter
    DeleteChartObjects();
    
    DrawStateIndicator(s);
    DrawCRTRange(s);
    DrawSwingPoint(s);
    DrawFVGZone(s);
    DrawMSSConfirmation(s);
    DrawFVGSizeIndicator(s);
    DrawEntryZones(s);
    DrawEntryConfirmation(s);
    DrawBiasStrength(s);
}

void DeleteChartObjects()
{
    ObjectsDeleteAll(0, "CRT_VISUAL_");
}

void DrawStateIndicator(CRT_State &s)
{
    string state_text = "STATE: ";
    ENUM_SETUP_STATE current_state;
    color state_color = clrGray;

    if(s.bias == BULLISH)
    {
        current_state = s.bull_state;
        state_text = "BULL | " + EnumToString(current_state);
    }
    else if(s.bias == BEARISH)
    {
        current_state = s.bear_state;
        state_text = "BEAR | " + EnumToString(current_state);
    }
    else
    {
        current_state = IDLE;
        state_text = "NEUTRAL | " + EnumToString(current_state);
    }
    
    switch(current_state)
    {
        case IDLE:    state_color = clrGray;           break;
        case SWEEP:   state_color = clrOrange;         break;
        case MSS:     state_color = clrCornflowerBlue; break;
        case FVG:     state_color = clrMediumPurple;   break;
        case ENTRY:   state_color = clrLawnGreen;      break;
        case INVALID: state_color = clrRed;            break;
    }
    
    string obj_name = "CRT_VISUAL_StateIndicator";
    ObjectCreate(0, obj_name, OBJ_LABEL, 0, 0, 0);
    ObjectSetString(0, obj_name, OBJPROP_TEXT, state_text);
    ObjectSetInteger(0, obj_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, 15);
    ObjectSetInteger(0, obj_name, OBJPROP_COLOR, state_color);
    ObjectSetInteger(0, obj_name, OBJPROP_FONTSIZE, 12);
    ObjectSetInteger(0, obj_name, OBJPROP_BGCOLOR, clrBlack);
    ObjectSetInteger(0, obj_name, OBJPROP_BORDER_COLOR, state_color);
}

void DrawCRTRange(CRT_State &s)
{
    if(s.crt_high <= 0 || s.crt_low <= 0 || s.bias_time <= 0) return;

    color range_color = (s.bias == BULLISH) ? C'0,100,0' : C'139,0,0'; // Dark Green/Red

    // The range is valid from its creation time until a new bias is formed or it times out.
    datetime time1 = s.bias_time; // Start from the bar that defined the range
    datetime time2 = time1 + 2 * PeriodSeconds(PERIOD_H4); // Extend for 2 H4 bars [[memory:2102791]]

    string rect_name = "CRT_VISUAL_CRTRange";
    if(ObjectFind(0, rect_name) < 0) {
        ObjectCreate(0, rect_name, OBJ_RECTANGLE, 0, time1, s.crt_high, time2, s.crt_low);
        ObjectSetInteger(0, rect_name, OBJPROP_COLOR, range_color);
        ObjectSetInteger(0, rect_name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, rect_name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, rect_name, OBJPROP_BACK, true);
        ObjectSetInteger(0, rect_name, OBJPROP_FILL, true);
    } else {
        ObjectSetInteger(0, rect_name, OBJPROP_TIME, 0, time1);
        ObjectSetDouble(0, rect_name, OBJPROP_PRICE, 0, s.crt_high);
        ObjectSetInteger(0, rect_name, OBJPROP_TIME, 1, time2);
        ObjectSetDouble(0, rect_name, OBJPROP_PRICE, 1, s.crt_low);
        ObjectSetInteger(0, rect_name, OBJPROP_COLOR, range_color);
    }
}

void DrawSwingPoint(CRT_State &s)
{
    if (s.mss_level <= 0) return;

    string obj_name = "CRT_VISUAL_MSS_Line";
    color line_color;
    string line_text;

    if (s.bias == BULLISH && s.bull_state >= SWEEP)
    {
        line_color = clrCornflowerBlue;
        line_text = "MSS High";
    }
    else if (s.bias == BEARISH && s.bear_state >= SWEEP)
    {
        line_color = clrRed;
        line_text = "MSS Low";
    }
    else
    {
        return; // Don't draw if not in a valid state
    }
    
    datetime time1 = s.mss_confirmed_time > 0 ? s.mss_confirmed_time : TimeCurrent();
    time1 -= PeriodSeconds(PERIOD_H4) * 6; // Start line a bit to the left
    datetime time2 = TimeCurrent() + PeriodSeconds(PERIOD_D1);

    ObjectCreate(0, obj_name, OBJ_HLINE, 0, 0, s.mss_level);
    ObjectSetInteger(0, obj_name, OBJPROP_COLOR, line_color);
    ObjectSetInteger(0, obj_name, OBJPROP_STYLE, STYLE_DASHDOT);
    ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 2);
    ObjectSetString(0, obj_name, OBJPROP_TEXT, line_text);
}


void DrawFVGZone(CRT_State &s)
{
    if(s.fvg_high <= 0 || s.fvg_low <= 0) return;
    
    ENUM_SETUP_STATE state = (s.bias == BULLISH) ? s.bull_state : s.bear_state;
    if(state < FVG) return; // Only draw if FVG state is reached

    color fvg_color = (s.bias == BULLISH) ? C'144,238,144' : C'255,182,193'; // LightGreen / LightPink

    MqlRates m15[];
    ArraySetAsSeries(m15, true);
    if(CopyRates(s.symbol, PERIOD_M15, 0, 100, m15) < 3) return;

    // Find the bar that created the FVG to start drawing from there.
    // This is an approximation. A more precise way would be to store the FVG time.
    datetime time1 = 0;
    for(int i = 0; i < ArraySize(m15) - 2; i++)
    {
        // Bullish FVG check
        if(s.bias == BULLISH && m15[i].low > m15[i+2].high) {
            if (m15[i+2].high == s.fvg_high) { // found our FVG
                 time1 = m15[i].time;
                 break;
            }
        }
        // Bearish FVG check
        if(s.bias == BEARISH && m15[i].high < m15[i+2].low) {
             if (m15[i].high == s.fvg_high) { // found our FVG
                 time1 = m15[i].time;
                 break;
             }
        }
    }
    if(time1==0) time1 = TimeCurrent();


    datetime time2 = TimeCurrent() + PeriodSeconds(PERIOD_D1);
    
    string rect_name = "CRT_VISUAL_FVGZone";
    ObjectCreate(0, rect_name, OBJ_RECTANGLE, 0, time1, s.fvg_high, time2, s.fvg_low);
    ObjectSetInteger(0, rect_name, OBJPROP_COLOR, fvg_color);
    ObjectSetInteger(0, rect_name, OBJPROP_BACK, true);
    ObjectSetInteger(0, rect_name, OBJPROP_FILL, true);
    ObjectSetString(0, rect_name, OBJPROP_TEXT, "FVG");
}

void DrawMSSConfirmation(CRT_State &s)
{
    if (s.mss_confirmed_time <= 0) return;

    string obj_name = "CRT_VISUAL_MSS_Confirm";
    int arrow_code = 0;
    color arrow_color = clrNONE;
    double price = 0;
    
    MqlRates m15[];
    ArraySetAsSeries(m15, true);
    if(CopyRates(s.symbol, PERIOD_M15, 0, 1, m15) > 0) // Look at the most recent bar
    {
       if (s.bias == BULLISH && s.bull_state >= MSS)
       {
           arrow_code = 233; // Wingdings Arrow Up
           arrow_color = clrDodgerBlue;
           price = m15[0].low - 100 * _Point;
       }
       else if (s.bias == BEARISH && s.bear_state >= MSS)
       {
           arrow_code = 234; // Wingdings Arrow Down
           arrow_color = clrMagenta;
           price = m15[0].high + 100 * _Point;
       }
       else return;

       ObjectCreate(0, obj_name, OBJ_ARROW, 0, s.mss_confirmed_time, price);
       ObjectSetInteger(0, obj_name, OBJPROP_ARROWCODE, arrow_code);
       ObjectSetString(0, obj_name, OBJPROP_FONT, "Wingdings");
       ObjectSetInteger(0, obj_name, OBJPROP_COLOR, arrow_color);
       ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 2);
    }
}
//+------------------------------------------------------------------+
//| [VISUALIZATION] FVG Size Indicator                               |
//+------------------------------------------------------------------+
void DrawFVGSizeIndicator(CRT_State &s)
{
    if(s.fvg_high <= 0 || s.fvg_low <= 0) return;

    ENUM_SETUP_STATE state = (s.bias == BULLISH) ? s.bull_state : s.bear_state;
    if(state < FVG) return;

    double point = SymbolInfoDouble(s.symbol, SYMBOL_POINT);
    if(point <= 0) return;

    double fvg_size_pips = MathAbs(s.fvg_high - s.fvg_low) / point / 10.0;
    string fvg_text = "FVG: " + DoubleToString(fvg_size_pips, 1) + " pips";
    color text_color = (fvg_size_pips >= MinFVGSizePips) ? clrLimeGreen : clrOrangeRed;
    
    // Find the time of the FVG to position the text correctly
    MqlRates m15[];
    ArraySetAsSeries(m15, true);
    if(CopyRates(s.symbol, PERIOD_M15, 0, 100, m15) < 3) return;

    datetime fvg_time = 0;
    for(int i = 0; i < ArraySize(m15) - 2; i++)
    {
        if(s.bias == BULLISH && m15[i].low > m15[i+2].high && m15[i+2].high == s.fvg_high) {
            fvg_time = m15[i].time;
            break;
        }
        if(s.bias == BEARISH && m15[i].high < m15[i+2].low && m15[i].high == s.fvg_high) {
            fvg_time = m15[i].time;
            break;
        }
    }
    if(fvg_time == 0) fvg_time = TimeCurrent();


    string obj_name = "CRT_VISUAL_FVG_Size";
    ObjectCreate(0, obj_name, OBJ_TEXT, 0, fvg_time, s.fvg_high + 50 * point);
    ObjectSetString(0, obj_name, OBJPROP_TEXT, fvg_text);
    ObjectSetInteger(0, obj_name, OBJPROP_COLOR, text_color);
    ObjectSetInteger(0, obj_name, OBJPROP_FONTSIZE, 8);
    ObjectSetInteger(0, obj_name, OBJPROP_ANCHOR, ANCHOR_LEFT);
}

//+------------------------------------------------------------------+
//| [VISUALIZATION] Entry Zone Markers                               |
//+------------------------------------------------------------------+
void DrawEntryZones(CRT_State &s)
{
    ENUM_SETUP_STATE state = (s.bias == BULLISH) ? s.bull_state : s.bear_state;
    if (state < FVG || state >= ENTRY) return;

    MqlRates m15_rates[];
    if(CopyRates(s.symbol, PERIOD_M15, 0, 1, m15_rates) < 1) return;
    datetime last_bar_time = m15_rates[0].time;

    if(s.bias == BULLISH)
    {
        string obj_name = "CRT_VISUAL_EntryZone_Bull";
        ObjectCreate(0, obj_name, OBJ_ARROW_BUY, 0, last_bar_time, s.fvg_high);
        ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clrDodgerBlue);
        ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 1);
    }
    else if(s.bias == BEARISH)
    {
        string obj_name = "CRT_VISUAL_EntryZone_Bear";
        ObjectCreate(0, obj_name, OBJ_ARROW_SELL, 0, last_bar_time, s.fvg_low);
        ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clrMagenta);
        ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 1);
    }
}

//+------------------------------------------------------------------+
//| [VISUALIZATION] Entry Confirmation Candle                        |
//+------------------------------------------------------------------+
void DrawEntryConfirmation(CRT_State &s)
{
    ENUM_SETUP_STATE state = (s.bias == BULLISH) ? s.bull_state : s.bear_state;
    if (state != ENTRY) return;

    MqlRates m15[];
    ArraySetAsSeries(m15, false); // Use normal series for this
    if (CopyRates(s.symbol, PERIOD_M15, 0, 2, m15) < 2) return;
    
    int last = ArraySize(m15) - 1;
    datetime time1 = m15[last-1].time;
    datetime time2 = m15[last].time;
    
    string obj_name = "CRT_VISUAL_EntryConfirm_Candle";

    if (s.bias == BULLISH && IsBullishEngulfing(m15, last))
    {
        ObjectCreate(0, obj_name, OBJ_RECTANGLE, 0, time1, m15[last-1].high, time2, m15[last-1].low);
        ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clrLimeGreen);
        ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
        ObjectSetInteger(0, obj_name, OBJPROP_FILL, true);
    }
    else if (s.bias == BEARISH && IsBearishEngulfing(m15, last))
    {
        ObjectCreate(0, obj_name, OBJ_RECTANGLE, 0, time1, m15[last-1].high, time2, m15[last-1].low);
        ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clrRed);
        ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
        ObjectSetInteger(0, obj_name, OBJPROP_FILL, true);
    }
}
//+------------------------------------------------------------------+
//| [VISUALIZATION] Bias Strength Gauge                              |
//+------------------------------------------------------------------+
void DrawBiasStrength(CRT_State &s)
{
    g_bias_canvas.Erase(clrBlack);

    double strength = 0.5; // Neutral
    if(s.bias == BULLISH)
    {
       // Very simple strength logic: 0.5 is neutral, moves towards 1.0 as state progresses
       strength = 0.5 + (0.5 * (double)s.bull_state / (double)ENTRY);
    }
    else if (s.bias == BEARISH)
    {
       // Moves towards 0.0 as state progresses
       strength = 0.5 - (0.5 * (double)s.bear_state / (double)ENTRY);
    }

    // Determine color based on strength
    color gauge_color;
    if (strength > 0.66)
        gauge_color = clrLimeGreen;
    else if (strength > 0.5)
        gauge_color = clrGreen;
    else if (strength < 0.33)
        gauge_color = clrOrangeRed;
    else if (strength < 0.5)
        gauge_color = clrRed;
    else
        gauge_color = clrGray;
        
    int width = g_bias_canvas.Width();
    int height = g_bias_canvas.Height();

    // Draw the gauge background
    g_bias_canvas.FillRectangle(0, 0, width-1, height-1, clrDimGray);
    g_bias_canvas.Rectangle(0, 0, width-1, height-1, clrDarkGray);


    // Draw the strength bar
    int bar_width = (int)(width * strength);
    g_bias_canvas.FillRectangle(0, 0, bar_width, height-1, gauge_color);
    
    // Draw Text
    string bias_text = "BIAS: " + EnumToString(s.bias);
    g_bias_canvas.FontSet("Arial", 10, FW_BOLD);
    g_bias_canvas.TextOut(width/2, height/2, bias_text, clrWhite, TA_CENTER|TA_VCENTER);

    g_bias_canvas.Update();
}

//+------------------------------------------------------------------+
//| CORE LOGIC FUNCTIONS                                             |
//+------------------------------------------------------------------+
void M15_Step(CRT_State &s)
{
    if(s.bias != BULLISH && s.bias != BEARISH) return;

    MqlRates m15[];
    ArraySetAsSeries(m15, false); // Use standard array indexing (0 = oldest)
    if(CopyRates(s.symbol, PERIOD_M15, 0, 50, m15) < 20) return; // Get more bars for lookbacks

    int last_idx = ArraySize(m15) - 1;

    // --- BULLISH STATE MACHINE ---
    if(s.bias == BULLISH)
    {
        switch(s.bull_state)
        {
            case IDLE:
                if(m15[last_idx].low < s.crt_low)
                {
                    int swing_idx = -1;
                    s.mss_level = FindLastSwing(m15, true, swing_idx);
                    if(s.mss_level > 0)
                    {
                       s.sweep_low = m15[last_idx].low;
                       s.bull_state = SWEEP;
                       Print(s.symbol, " | BULL | IDLE->SWEEP | MSS Level Target: ", s.mss_level);
                    }
                }
                break;

            case SWEEP:
                if(m15[last_idx].high > s.mss_level)
                {
                    s.mss_confirmed_time = m15[last_idx].time;
                    s.bull_state = MSS;
                    Print(s.symbol, " | BULL | SWEEP->MSS | Structure Broken.");
                }
                break;

            case MSS:
                if(FindFVG(m15, s, true, ArraySize(m15)-1))
                {
                   s.bull_state = FVG;
                   Print(s.symbol, " | BULL | MSS->FVG | Entry FVG found: ", s.fvg_low, "-", s.fvg_high);
                }
                break;
                
            case FVG:
                if(m15[last_idx].low < s.fvg_high)
                {
                    if(!Use_EntryConfirmation || IsBullishEngulfing(m15, last_idx))
                    {
                       s.bull_state = ENTRY;
                       Print(s.symbol, " | BULL | FVG->ENTRY | ENTRY TRIGGERED!");
                    }
                }
                break;
        }
    }
    // --- BEARISH STATE MACHINE ---
    else if(s.bias == BEARISH)
    {
        switch(s.bear_state)
        {
            case IDLE:
                if(m15[last_idx].high > s.crt_high)
                {
                    int swing_idx = -1;
                    s.mss_level = FindLastSwing(m15, false, swing_idx);
                    if(s.mss_level > 0)
                    {
                       s.sweep_high = m15[last_idx].high;
                       s.bear_state = SWEEP;
                       Print(s.symbol, " | BEAR | IDLE->SWEEP | MSS Level Target: ", s.mss_level);
                    }
                }
                break;

            case SWEEP:
                if(m15[last_idx].low < s.mss_level)
                {
                    s.mss_confirmed_time = m15[last_idx].time;
                    s.bear_state = MSS;
                    Print(s.symbol, " | BEAR | SWEEP->MSS | Structure Broken.");
                }
                break;

            case MSS:
                if(FindFVG(m15, s, false, ArraySize(m15)-1))
                {
                   s.bear_state = FVG;
                   Print(s.symbol, " | BEAR | MSS->FVG | Entry FVG found: ", s.fvg_low, "-", s.fvg_high);
                }
                break;

            case FVG:
                if(m15[last_idx].high > s.fvg_low)
                {
                    if(!Use_EntryConfirmation || IsBearishEngulfing(m15, last_idx))
                    {
                       s.bear_state = ENTRY;
                       Print(s.symbol, " | BEAR | FVG->ENTRY | ENTRY TRIGGERED!");
                    }
                }
                break;
        }
    }
}
void ResetState(CRT_State &s, string symbol)
{
   s.symbol = symbol;
   s.bias = NEUTRAL;
   s.bias_time = 0;
   s.crt_high = 0;
   s.crt_low = 0;
   s.sweep_high = 0;
   s.sweep_low = 0;
   s.mss_level = 0;
   s.mss_confirmed_time = 0;
   s.fvg_high = 0;
   s.fvg_low = 0;
   s.bull_state = IDLE;
   s.bear_state = IDLE;
}
ENUM_BIAS CRT_Bias(string symbol, datetime &range_time, datetime &sweep_time, double &range_high, double &range_low)
{
    MqlRates h4_rates[];
    ArraySetAsSeries(h4_rates, true);
    if(CopyRates(symbol, PERIOD_H4, 0, 5, h4_rates) < 5)
    {
        Print("Not enough H4 bars for bias detection.");
        return NEUTRAL;
    }

    range_high = h4_rates[2].high;
    range_low  = h4_rates[2].low;
    range_time = h4_rates[2].time;

    if (h4_rates[1].low < range_low && h4_rates[1].close > range_low)
    {
        sweep_time = h4_rates[1].time;
        return BULLISH;
    }
    if (h4_rates[1].high > range_high && h4_rates[1].close < range_high)
    {
        sweep_time = h4_rates[1].time;
        return BEARISH;
    }

    return NEUTRAL;
}
double FindLastSwing(const MqlRates &rates[], bool find_high, int &swing_idx)
{
    for(int i = ArraySize(rates) - 3; i >= 0; i--)
    {
        if(find_high && rates[i].high > rates[i+1].high && rates[i].high > rates[i-1].high)
        {
            swing_idx = i;
            return rates[i].high;
        }
        if(!find_high && rates[i].low < rates[i+1].low && rates[i].low < rates[i-1].low)
        {
            swing_idx = i;
            return rates[i].low;
        }
    }
    return 0;
}
bool FindFVG(const MqlRates &rates[], CRT_State &s, bool find_bullish, int start_idx)
{
    for(int i = start_idx; i > 1; i--)
    {
        if(find_bullish && rates[i].low > rates[i-2].high)
        {
            s.fvg_high = rates[i-2].high;
            s.fvg_low  = rates[i].low;
            if(Use_FVG_SizeValidation)
            {
               double point = SymbolInfoDouble(s.symbol, SYMBOL_POINT);
               if(point > 0)
               {
                   double fvg_size_pips = (s.fvg_low - s.fvg_high) / point / 10.0;
                   if(fvg_size_pips < MinFVGSizePips) return false;
               }
            }
            return true;
        }
        if(!find_bullish && rates[i].high < rates[i-2].low)
        {
            s.fvg_high = rates[i].high;
            s.fvg_low  = rates[i-2].low;
            if(Use_FVG_SizeValidation)
            {
               double point = SymbolInfoDouble(s.symbol, SYMBOL_POINT);
               if(point > 0)
               {
                   double fvg_size_pips = (s.fvg_high - s.fvg_low) / point / 10.0;
                   if(fvg_size_pips < MinFVGSizePips) return false;
               }
            }
            return true;
        }
    }
    return false;
}
bool IsBullishEngulfing(const MqlRates &rates[], int index) 
{
    if(index < 1) return false;
    return(rates[index].close > rates[index].open &&
           rates[index-1].open > rates[index-1].close &&
           rates[index].close > rates[index-1].open &&
           rates[index].open < rates[index-1].close);
}
bool IsBearishEngulfing(const MqlRates &rates[], int index) 
{
    if(index < 1) return false;
    return(rates[index].open > rates[index].close &&
           rates[index-1].close > rates[index-1].open &&
           rates[index].open > rates[index-1].close &&
           rates[index].close < rates[index-1].open);
}
//+------------------------------------------------------------------+