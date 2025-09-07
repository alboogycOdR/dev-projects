//+------------------------------------------------------------------+
//|                                         Institutional_9AM_CRT.mq5|
//|                                  Copyright 2023, Your Name/Company|
//|                                              http://www.your.site|
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Your Name/Company"
#property link      "http://www.your.site"
#property version   "1.20"
#property description "Expert Advisor for the Institutional 1AM, 5AM, and 9AM Candle Range Theory (CRT) Models with Enhanced Visuals."
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <ChartObjects\ChartObjectsTxtControls.mqh> // For easier label creation

//--- Global objects
CTrade trade;
CPositionInfo position;
CAccountInfo account;

//--- Enums for user inputs
enum ENUM_CRT_MODEL
{
    CRT_1AM_ASIA,
    CRT_5AM_LONDON,
    CRT_9AM_NY
};

enum ENUM_BIAS_MODE
{
    MANUAL,
    AUTOMATIC
};

enum ENUM_DAILY_BIAS
{
    BULLISH,
    BEARISH,
    NEUTRAL
};

enum ENUM_ENTRY_MODEL
{
    CONFIRMATION_MSS, // Market Structure Shift + FVG/OB
    AGGRESSIVE_TURTLE_SOUP,
    THREE_CANDLE_PATTERN
};

enum ENUM_OPERATIONAL_MODE
{
    FULLY_AUTOMATED,
    SIGNALS_ONLY,
    MANUAL_PANEL
};

enum ENUM_WEEKLY_PROFILE
{
    NONE,
    CLASSIC_EXPANSION,
    MIDWEEK_REVERSAL,
    CONSOLIDATION_REVERSAL
};

//+------------------------------------------------------------------+
//| Expert Advisor Input Parameters                                  |
//+------------------------------------------------------------------+
//--- Core CRT Settings
input group "CRT Core Settings"
input ENUM_CRT_MODEL        CRTModelSelection = CRT_9AM_NY;             // Select the CRT Model to Trade
input ENUM_BIAS_MODE        BiasDetectionMode = MANUAL;                 // Bias Detection Mode
input ENUM_DAILY_BIAS       ManualDailyBias = BULLISH;                  // Manual Daily Bias
input ENUM_ENTRY_MODEL      EntryLogicModel = CONFIRMATION_MSS;         // Preferred Entry Model
input int                   NY_Time_Offset_Hours = -7;                  // Your Broker's Server Time vs NY Time (e.g., -7)

//--- Session Times (NY Time)
input group "Session Times (in NY Time)"
input string                Asia_Killzone_Start = "01:00";              // Asia Killzone Start
input string                Asia_Killzone_End = "03:00";                // Asia Killzone End
input string                London_Killzone_Start = "05:00";            // London Killzone Start
input string                London_Killzone_End = "07:00";              // London Killzone End
input string                NY_Killzone_Start = "09:30";                // NY Killzone Start
input string                NY_Killzone_End = "11:00";                  // NY Killzone End

//--- Risk & Trade Management
input group "Risk & Trade Management"
input double                RiskPercent = 0.5;                          // Risk per Trade (%)
input double                TakeProfit1_RR = 1.0;                       // TP1 Risk:Reward Ratio (e.g., 1.0 for 1R)
input double                TakeProfit2_CRT_Target = 100.0;             // TP2 Target (% of CRT Range, e.g., 100% for full range)
input bool                  MoveToBE_After_TP1 = true;                  // Move SL to Breakeven after TP1?
input bool                  UseTrailingStop = false;                    // Use Trailing Stop?
input int                   TrailingStopPips = 200;                     // Trailing Stop (in Points)

//--- Advanced Filters
input group "Advanced Contextual Filters"
input ENUM_WEEKLY_PROFILE   WeeklyProfileHypothesis = NONE;             // Assumed Weekly Profile
input bool                  Use_SMT_Divergence_Filter = false;          // Enable SMT Divergence Filter?
input string                SMT_Correlated_Symbol = "ESM24";            // SMT Correlated Symbol (e.g., ES, DXY)
input bool                  Use_News_Filter = true;                     // Enable High-Impact News Filter?
input int                   MinutesBeforeAfterNews = 30;                // Avoid trading X minutes before/after news

//--- Operational Mode
input group "Operational Mode"
input ENUM_OPERATIONAL_MODE OperationalMode = SIGNALS_ONLY;             // How the EA should operate

//--- Global Variables
double crtHigh = 0;
double crtLow = 0;
datetime crtRangeSetTime = 0;
datetime crtRangeCandleTime = 0; // Time of the candle that set the range
double htfKeyLevelHigh = 0;
double htfKeyLevelLow = 0;
bool tradeTakenToday = false;
string entrySignal = "";
string dashboardID = "CRT_Dashboard_"; // Prefix for all dashboard objects

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("Multi-Session CRT Expert Advisor Initializing (v1.20)...");
    Print("Selected Model: ", EnumToString(CRTModelSelection));
    Print("NY Time Offset: ", NY_Time_Offset_Hours, " hours");

    CreateDashboard(); // Create the new visual dashboard
    trade.SetExpertMagicNumber(19912); // New magic number for updated version
    trade.SetTypeFillingBySymbol(_Symbol);
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("CRT Expert Advisor Deinitializing...");
    // Clean up all chart objects created by this EA
    ObjectsDeleteAll(0, dashboardID);
    ObjectDelete(0, "CRTHighLine");
    ObjectDelete(0, "CRTLowLine");
    ObjectDelete(0, "CRTHighLabel");
    ObjectDelete(0, "CRTLowLabel");
    ObjectDelete(0, "HTF_Level_High");
    ObjectDelete(0, "HTF_Level_Low");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if(TimeCurrent() >= NextDayResetTime())
    {
       ResetDailyVariables();
    }

    if(crtRangeSetTime == 0)
    {
        DetermineBiasAndLevels();
    }

    SetCRTRange();

    if(IsWithinKillzone() && crtHigh > 0 && !tradeTakenToday)
    {
        CheckForEntry();
    }
    
    ManageOpenPositions();
    UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Resets variables at the start of a new trading day               |
//+------------------------------------------------------------------+
void ResetDailyVariables()
{
    Print("New trading day detected. Resetting variables.");
    crtHigh = 0;
    crtLow = 0;
    crtRangeSetTime = 0;
    crtRangeCandleTime = 0;
    tradeTakenToday = false;
    entrySignal = "";
    ObjectDelete(0, "CRTHighLine");
    ObjectDelete(0, "CRTLowLine");
    ObjectDelete(0, "CRTHighLabel");
    ObjectDelete(0, "CRTLowLabel");
}

datetime NextDayResetTime()
{
    MqlDateTime tm;
    TimeToStruct(TimeCurrent(), tm);
    tm.hour = 0;
    tm.min = 1;
    tm.sec = 0;
    
    if(StructToTime(tm) < TimeCurrent())
    {
        tm.day += 1;
    }
    return StructToTime(tm);
}

//+------------------------------------------------------------------+
//| STEP 1 & 2: Determine Bias and Identify Key Levels               |
//+------------------------------------------------------------------+
void DetermineBiasAndLevels()
{
    ENUM_DAILY_BIAS currentBias = GetAutomaticBias();
    
    if(currentBias == BULLISH)
    {
        htfKeyLevelHigh = iHigh(_Symbol, PERIOD_D1, 1);
        DrawHorizontalLine("HTF_Level_High", htfKeyLevelHigh, clrDodgerBlue, STYLE_DOT);
    }
    else if (currentBias == BEARISH)
    {
        htfKeyLevelLow = iLow(_Symbol, PERIOD_D1, 1);
        DrawHorizontalLine("HTF_Level_Low", htfKeyLevelLow, clrCrimson, STYLE_DOT);
    }
}

//+------------------------------------------------------------------+
//| STEP 3: Set the CRT Range based on selected model                |
//+------------------------------------------------------------------+
void SetCRTRange()
{
    if(crtHigh > 0) return;

    int range_candle_hour = 0;
    int range_set_ready_hour = 0;

    switch(CRTModelSelection)
    {
        case CRT_1AM_ASIA:
            range_candle_hour = 0; // The 00:00 NY Time candle defines the 1AM range
            range_set_ready_hour = 1;
            break;
        case CRT_5AM_LONDON:
            range_candle_hour = 4; // The 04:00 NY Time candle defines the 5AM range
            range_set_ready_hour = 5;
            break;
        case CRT_9AM_NY:
            range_candle_hour = 8; // The 08:00 NY Time candle defines the 9AM range
            range_set_ready_hour = 9;
            break;
    }

    long timeShiftSeconds = NY_Time_Offset_Hours * 3600;
    datetime nyTime = (datetime)(TimeCurrent() + timeShiftSeconds);
    MqlDateTime ny_tm;
    TimeToStruct(nyTime, ny_tm);

    if(ny_tm.hour >= range_set_ready_hour)
    {
        MqlRates h1_rates[];
        if(CopyRates(_Symbol, PERIOD_H1, 0, 24, h1_rates) < 24)
        {
            Print("Could not get H1 rates to set CRT range.");
            return;
        }

        for(int i = ArraySize(h1_rates) - 1; i >= 0; i--)
        {
            datetime candle_ny_time = (datetime)(h1_rates[i].time + timeShiftSeconds);
            MqlDateTime candle_ny_tm;
            TimeToStruct(candle_ny_time, candle_ny_tm);

            if(candle_ny_tm.hour == range_candle_hour)
            {
                crtHigh = h1_rates[i].high;
                crtLow = h1_rates[i].low;
                crtRangeSetTime = TimeCurrent();
                crtRangeCandleTime = h1_rates[i].time; // *** STORE THE CANDLE TIME ***

                Print(EnumToString(CRTModelSelection), " Range Set for ", TimeToString(crtRangeSetTime, TIME_DATE));
                Print("High: ", DoubleToString(crtHigh, _Digits), " Low: ", DoubleToString(crtLow, _Digits));

                // *** USE NEW DRAWING FUNCTION ***
                DrawRangeLinesFromCandle("CRTHighLine", "CRTHighLabel", crtRangeCandleTime, crtHigh, "CRT High", clrGold, ANCHOR_TOP);
                DrawRangeLinesFromCandle("CRTLowLine", "CRTLowLabel", crtRangeCandleTime, crtLow, "CRT Low", clrGold, ANCHOR_BOTTOM);
                break;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Checks if the current time is within the selected Killzone       |
//+------------------------------------------------------------------+
bool IsWithinKillzone()
{
    long timeShiftSeconds = NY_Time_Offset_Hours * 3600;
    datetime nyTime = (datetime)(TimeCurrent() + timeShiftSeconds);
    MqlDateTime ny_tm;
    TimeToStruct(nyTime, ny_tm);

    string kz_start_str, kz_end_str;
    switch(CRTModelSelection)
    {
        case CRT_1AM_ASIA: kz_start_str = Asia_Killzone_Start; kz_end_str = Asia_Killzone_End; break;
        case CRT_5AM_LONDON: kz_start_str = London_Killzone_Start; kz_end_str = London_Killzone_End; break;
        case CRT_9AM_NY: kz_start_str = NY_Killzone_Start; kz_end_str = NY_Killzone_End; break;
    }

    int start_hour, start_min, end_hour, end_min;
    ParseTime(kz_start_str, start_hour, start_min);
    ParseTime(kz_end_str, end_hour, end_min);

    int currentTimeInMinutes = ny_tm.hour * 60 + ny_tm.min;
    int startTimeInMinutes = start_hour * 60 + start_min;
    int endTimeInMinutes = end_hour * 60 + end_min;

    return (currentTimeInMinutes >= startTimeInMinutes && currentTimeInMinutes <= endTimeInMinutes);
}

//+------------------------------------------------------------------+
//| ENTRY LOGIC: Checks for a valid trade entry                      |
//+------------------------------------------------------------------+
void CheckForEntry()
{
    MqlRates m15_rates[];
    if(CopyRates(_Symbol, PERIOD_M15, 0, 5, m15_rates) < 5) return;

    double last_closed_high = m15_rates[1].high;
    double last_closed_low = m15_rates[1].low;
    ENUM_DAILY_BIAS activeBias = GetAutomaticBias();

    if(activeBias == BULLISH && last_closed_low < crtLow)
    {
        Print("Potential bullish setup: CRT Low has been swept.");
        if(EntryLogicModel == CONFIRMATION_MSS) {
            entrySignal = "BUY Signal (MSS)";
            if(OperationalMode == SIGNALS_ONLY) Alert(entrySignal);
            if(OperationalMode == FULLY_AUTOMATED) ExecuteTrade("BUY");
        }
        else if(EntryLogicModel == AGGRESSIVE_TURTLE_SOUP && m15_rates[1].close > crtLow) {
            entrySignal = "BUY Signal (Turtle Soup)";
            if(OperationalMode == SIGNALS_ONLY) Alert(entrySignal);
            if(OperationalMode == FULLY_AUTOMATED) ExecuteTrade("BUY");
        }
    }
    else if(activeBias == BEARISH && last_closed_high > crtHigh)
    {
        Print("Potential bearish setup: CRT High has been swept.");
        if(EntryLogicModel == CONFIRMATION_MSS) {
            entrySignal = "SELL Signal (MSS)";
            if(OperationalMode == SIGNALS_ONLY) Alert(entrySignal);
            if(OperationalMode == FULLY_AUTOMATED) ExecuteTrade("SELL");
        }
        else if(EntryLogicModel == AGGRESSIVE_TURTLE_SOUP && m15_rates[1].close < crtHigh) {
            entrySignal = "SELL Signal (Turtle Soup)";
            if(OperationalMode == SIGNALS_ONLY) Alert(entrySignal);
            if(OperationalMode == FULLY_AUTOMATED) ExecuteTrade("SELL");
        }
    }
}

//+------------------------------------------------------------------+
//| TRADE EXECUTION: Opens a trade based on signal                   |
//+------------------------------------------------------------------+
void ExecuteTrade(string direction)
{
    if(tradeTakenToday) return;

    MqlRates m15_rates[];
    if(CopyRates(_Symbol, PERIOD_M15, 0, 2, m15_rates) < 2) return;
    double manipulationWickHigh = m15_rates[1].high;
    double manipulationWickLow = m15_rates[1].low;

    double entry_price, sl_price, tp1_price, lot_size;

    if(direction == "BUY")
    {
        entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        sl_price = manipulationWickLow - (SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point);
        double sl_distance = entry_price - sl_price;
        if(sl_distance <= 0) return;

        tp1_price = entry_price + (sl_distance * TakeProfit1_RR);
        lot_size = CalculateLotSize(sl_distance);
        
        if(trade.Buy(lot_size, _Symbol, entry_price, sl_price, tp1_price, "CRT Buy"))
        {
            tradeTakenToday = true;
            Print("BUY Trade Executed. Lot: ", lot_size, " SL: ", sl_price, " TP1: ", tp1_price);
        }
    }
    else if(direction == "SELL")
    {
        entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        sl_price = manipulationWickHigh + (SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point);
        double sl_distance = sl_price - entry_price;
        if(sl_distance <= 0) return;
        
        tp1_price = entry_price - (sl_distance * TakeProfit1_RR);
        lot_size = CalculateLotSize(sl_distance);

        if(trade.Sell(lot_size, _Symbol, entry_price, sl_price, tp1_price, "CRT Sell"))
        {
            tradeTakenToday = true;
            Print("SELL Trade Executed. Lot: ", lot_size, " SL: ", sl_price, " TP1: ", tp1_price);
        }
    }
}

//+------------------------------------------------------------------+
//| RISK MANAGEMENT: Calculates position size based on risk %        |
//+------------------------------------------------------------------+
double CalculateLotSize(double sl_distance_price)
{
    if(sl_distance_price <= 0) return 0.0;

    double account_balance = account.Balance();
    double risk_amount = account_balance * (RiskPercent / 100.0);
    
    double tick_value, tick_size;
    if(!SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE, tick_value) || !SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE, tick_size))
        return 0.0;
    if(tick_size <= 0) return 0.0;

    double ticks_for_sl = sl_distance_price / tick_size;
    double loss_per_lot = ticks_for_sl * tick_value;

    if(loss_per_lot <= 0) return 0.0;

    double lot_size = risk_amount / loss_per_lot;
    
    double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    lot_size = MathFloor(lot_size / volume_step) * volume_step;
    
    double min_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    if(lot_size < min_volume) lot_size = min_volume;
    if(lot_size > max_volume) lot_size = max_volume;

    return lot_size;
}

//+------------------------------------------------------------------+
//| TRADE MANAGEMENT: Manages open positions (BE, Trailing)          |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
    if(position.SelectByMagic(_Symbol, 19912))
    {
        long pos_type = position.PositionType();
        double open_price = position.PriceOpen();
        double current_price = (pos_type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double sl = position.StopLoss();
        double tp = position.TakeProfit();

        if(MoveToBE_After_TP1 && sl != open_price)
        {
            if((pos_type == POSITION_TYPE_BUY && current_price >= tp) ||
               (pos_type == POSITION_TYPE_SELL && current_price <= tp))
            {
                trade.PositionModify(_Symbol, open_price, tp);
                Print("Position moved to Breakeven.");
            }
        }
        
        if(UseTrailingStop)
        {
             if(pos_type == POSITION_TYPE_BUY)
             {
                 if(current_price - open_price > TrailingStopPips * _Point)
                 {
                     double new_sl = current_price - (TrailingStopPips * _Point);
                     if(sl < new_sl) trade.PositionModify(_Symbol, new_sl, tp);
                 }
             }
             else
             {
                 if(open_price - current_price > TrailingStopPips * _Point)
                 {
                     double new_sl = current_price + (TrailingStopPips * _Point);
                     if(sl > new_sl || sl == 0) trade.PositionModify(_Symbol, new_sl, tp);
                 }
             }
        }
    }
}

//+------------------------------------------------------------------+
//| UI & DASHBOARD Functions                                         |
//+------------------------------------------------------------------+
void CreateDashboard()
{
    // Main Panel
    CreateLabel(dashboardID + "Panel", 5, 5, 220, 150, clrGray, 100);

    // Title
    CreateTextLabel(dashboardID + "Title", "CRT Institutional Model", 15, 15, clrGold, 10);

    // Static Labels
    CreateTextLabel(dashboardID + "Model_Static", "Model:", 15, 35, clrBlack);
    CreateTextLabel(dashboardID + "Bias_Static", "Bias:", 15, 50, clrBlack);
    CreateTextLabel(dashboardID + "RangeH_Static", "CRT High:", 15, 65, clrBlack);
    CreateTextLabel(dashboardID + "RangeL_Static", "CRT Low:", 15, 80, clrBlack);
    CreateTextLabel(dashboardID + "Killzone_Static", "Killzone:", 15, 95, clrBlack);
    CreateTextLabel(dashboardID + "Status_Static", "Status:", 15, 110, clrBlack);
    CreateTextLabel(dashboardID + "Spread_Static", "Spread:", 15, 125, clrBlack);

    // Dynamic Value Labels (to be updated in UpdateDashboard)
    CreateTextLabel(dashboardID + "Model_Value", "...", 100, 35, clrBlack);
    CreateTextLabel(dashboardID + "Bias_Value", "...", 100, 50, clrBlack);
    CreateTextLabel(dashboardID + "RangeH_Value", "...", 100, 65, clrBlack);
    CreateTextLabel(dashboardID + "RangeL_Value", "...", 100, 80, clrBlack);
    CreateTextLabel(dashboardID + "Killzone_Value", "...", 100, 95, clrBlack);
    CreateTextLabel(dashboardID + "Status_Value", "...", 100, 110, clrBlack);
    CreateTextLabel(dashboardID + "Spread_Value", "...", 100, 125, clrBlack);
}

void UpdateDashboard()
{
    // Model & Bias
    ObjectSetString(0, dashboardID + "Model_Value", OBJPROP_TEXT, EnumToString(CRTModelSelection));
    string bias_str = EnumToString(GetAutomaticBias());
    color bias_color = (GetAutomaticBias() == BULLISH) ? clrLimeGreen : (GetAutomaticBias() == BEARISH) ? clrTomato : clrGray;
    ObjectSetString(0, dashboardID + "Bias_Value", OBJPROP_TEXT, bias_str);
    ObjectSetInteger(0, dashboardID + "Bias_Value", OBJPROP_COLOR, bias_color);
    
    // CRT Range
    ObjectSetString(0, dashboardID + "RangeH_Value", OBJPROP_TEXT, crtHigh > 0 ? DoubleToString(crtHigh, _Digits) : "N/A");
    ObjectSetString(0, dashboardID + "RangeL_Value", OBJPROP_TEXT, crtLow > 0 ? DoubleToString(crtLow, _Digits) : "N/A");

    // Killzone Status
    bool kz_active = IsWithinKillzone();
    ObjectSetString(0, dashboardID + "Killzone_Value", OBJPROP_TEXT, kz_active ? "ACTIVE" : "INACTIVE");
    ObjectSetInteger(0, dashboardID + "Killzone_Value", OBJPROP_COLOR, kz_active ? clrLimeGreen : clrTomato);

    // Trade Status
    string status_text = tradeTakenToday ? "Trade Taken" : (entrySignal != "" ? "Signal!" : "Monitoring...");
    ObjectSetString(0, dashboardID + "Status_Value", OBJPROP_TEXT, status_text);

    // Spread
    int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    ObjectSetString(0, dashboardID + "Spread_Value", OBJPROP_TEXT, IntegerToString(spread) + " points");
}

//+------------------------------------------------------------------+
//| Helper Functions                                                 |
//+------------------------------------------------------------------+
// Draws a trend line starting from a specific candle time
void DrawRangeLinesFromCandle(string line_name, string label_name, datetime start_time, double price, string label_text, color line_color, int anchor)
{
    if(ObjectFind(0, line_name) < 0)
    {
        ObjectCreate(0, line_name, OBJ_TREND, 0, start_time, price, TimeCurrent() + 3600*24, price);
        ObjectSetInteger(0, line_name, OBJPROP_COLOR, line_color);
        ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, true); // Extend to the right
        ObjectSetInteger(0, line_name, OBJPROP_BACK, false);
        
        // Add a text label next to the line
        ObjectCreate(0, label_name, OBJ_TEXT, 0, start_time, price);
        ObjectSetString(0, label_name, OBJPROP_TEXT, " " + label_text);
        ObjectSetInteger(0, label_name, OBJPROP_COLOR, line_color);
        ObjectSetInteger(0, label_name, OBJPROP_ANCHOR, (ENUM_ANCHOR_POINT)anchor);
        ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 8);
        ObjectSetInteger(0, label_name, OBJPROP_XDISTANCE, -5);
    }
    else
    {
        ObjectMove(0, line_name, 0, start_time, price);
        ObjectMove(0, line_name, 1, TimeCurrent() + 3600*24, price);
        ObjectMove(0, label_name, 0, start_time, price);
    }
}

void DrawHorizontalLine(string name, double price, color line_color, ENUM_LINE_STYLE style, int width=1)
{
    if(ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
        ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
        ObjectSetInteger(0, name, OBJPROP_STYLE, style);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
    }
    else
    {
       ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price);
    }
}

void ParseTime(string time_str, int &hour, int &min)
{
    string parts[];
    if(StringSplit(time_str, ':', parts) == 2)
    {
        hour = (int)StringToInteger(parts[0]);
        min = (int)StringToInteger(parts[1]);
    }
}

ENUM_DAILY_BIAS GetAutomaticBias()
{
    if(BiasDetectionMode == MANUAL) return ManualDailyBias;
    
    double prevDayHigh = iHigh(_Symbol, PERIOD_D1, 1);
    double prevDayLow = iLow(_Symbol, PERIOD_D1, 1);
    double prevDayClose = iClose(_Symbol, PERIOD_D1, 1);

    if(prevDayClose > (prevDayHigh + prevDayLow) / 2)
        return BULLISH;
    else
        return BEARISH;
}

//--- Dashboard Helper Functions ---
void CreateLabel(string name, int x, int y, int w, int h, color clr, int alpha=255)
{
    CChartObjectRectLabel* label = new CChartObjectRectLabel;
    if(label.Create(0, name, 0, x, y))
    {
        label.X_Size(w);
        label.Y_Size(h);
        label.BackColor(clr);
        label.Color(clr);
        label.Corner(CORNER_LEFT_UPPER);
        label.Background(true);
    }
    delete label;
}

void CreateTextLabel(string name, string text, int x, int y, color clr, int font_size=9)
{
    CChartObjectLabel* txt = new CChartObjectLabel;
    if(txt.Create(0, name, 0, x, y))
    {
        txt.Description(text);
        txt.Color(clr);
        txt.Font("Arial");
        txt.FontSize(font_size);
        txt.Corner(CORNER_LEFT_UPPER);
        txt.Anchor(ANCHOR_LEFT_UPPER);
    }
    delete txt;
}
//+------------------------------------------------------------------+

