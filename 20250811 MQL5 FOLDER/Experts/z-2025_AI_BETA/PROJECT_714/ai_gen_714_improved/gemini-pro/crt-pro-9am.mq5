//+------------------------------------------------------------------+
//|                                         Institutional_9AM_CRT.mq5|
//|                                  Copyright 2023, Your Name/Company|
//|                                              http://www.your.site|
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Your Name/Company"
#property link      "http://www.your.site"
#property version   "1.00"
#property description "Expert Advisor for the Institutional 9 AM Candle Range Theory (CRT) Model."
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//--- Include files for modularity (placeholders for future expansion)
// #include "BiasAnalysis.mqh"
// #include "KeyLevelScanner.mqh"
// #include "Dashboard.mqh"
// #include "NewsFilter.mqh"
// #include "SMTDivergence.mqh"

//--- Global objects
CTrade trade;
CPositionInfo position;
CAccountInfo account;

//--- Enums for user inputs to make them more readable
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
input ENUM_BIAS_MODE        BiasDetectionMode = MANUAL;                 // Bias Detection Mode
input ENUM_DAILY_BIAS       ManualDailyBias = BULLISH;                  // Manual Daily Bias
input string                NY_Session_Start = "08:00";                 // NY Session Start (for CRT Range)
input string                NY_Killzone_Start = "09:30";                // NY Killzone Start (for Entries)
input string                NY_Killzone_End = "11:00";                  // NY Killzone End (for Entries)
input ENUM_ENTRY_MODEL      EntryLogicModel = CONFIRMATION_MSS;         // Preferred Entry Model

//--- Risk & Trade Management
input group "Risk & Trade Management"
input double                RiskPercent = 0.5;                          // Risk per Trade (%)
input double                TakeProfit1_RR = 1.0;                       // TP1 Risk:Reward Ratio (e.g., 1.0 for 1R)
input double                TakeProfit2_CRT_Target = 100.0;             // TP2 Target (% of CRT Range, e.g., 100% for full range)
input bool                  MoveToBE_After_TP1 = true;                  // Move SL to Breakeven after TP1?
input bool                  UseTrailingStop = false;                    // Use Trailing Stop?
input int                   TrailingStopPips = 200;                     // Trailing Stop (in Points)
input double                MinStopLossPips = 5.0;                      // Minimum Stop Loss in Pips

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
ulong magicNumber = 19910; // Unique magic number for this EA

// CRT Range
double crtHigh = 0;
double crtLow = 0;
datetime crtRangeSetTime = 0;
datetime lastResetTime = 0;

// HTF Levels (placeholders, would be populated by a scanner function)
double htfKeyLevelHigh = 0;
double htfKeyLevelLow = 0;

// Trade State
bool tradeTakenToday = false;
string entrySignal = "";
ENUM_DAILY_BIAS dailyBias;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Initialization
    Print("9 AM CRT Expert Advisor Initializing...");
    Print("Symbol: ", _Symbol);
    Print("Timeframe: ", EnumToString((ENUM_TIMEFRAMES)_Period));
    Print("Operational Mode: ", EnumToString(OperationalMode));

    //--- Setup Chart Objects (Dashboard, etc.)
    SetupDashboard();
    
    //--- Set magic number for trades
    trade.SetExpertMagicNumber(magicNumber); 
    trade.SetTypeFillingBySymbol(_Symbol);

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- Cleanup
    Print("9 AM CRT Expert Advisor Deinitializing...");
    ObjectDelete(0, "CRTDashboard");
    ObjectDelete(0, "CRTHighLine");
    ObjectDelete(0, "CRTLowLine");
    ObjectDelete(0, "HTF_Level_High");
    ObjectDelete(0, "HTF_Level_Low");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    //--- Reset daily variables if a new day has started
    if(IsNewDay())
    {
       ResetDailyVariables();
    }

    //--- Main Logic Flow
    // 1. Determine Bias & Key Levels (Done once per day, before session)
    if(crtRangeSetTime == 0) // Only run this logic once per day
    {
        DetermineBiasAndLevels();
    }

    // 2. Set the 8 AM CRT Range
    SetCRTRange();

    // 3. Check for Entry Conditions during the Killzone
    if(IsWithinKillzone() && crtHigh > 0 && !tradeTakenToday)
    {
        CheckForEntry();
    }
    
    // 4. Manage any open positions
    ManageOpenPositions();
    
    // 5. Update the dashboard
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
    tradeTakenToday = false;
    entrySignal = "";
    ObjectDelete(0, "CRTHighLine");
    ObjectDelete(0, "CRTLowLine");
    lastResetTime = TimeCurrent();
}

bool IsNewDay()
{
    if(lastResetTime == 0) // First run
    {
        lastResetTime = TimeCurrent();
        return true; 
    }
    
    MqlDateTime tm_last, tm_current;
    TimeToStruct(lastResetTime, tm_last);
    TimeToStruct(TimeCurrent(), tm_current);
    
    if(tm_current.day != tm_last.day)
    {
        return true;
    }
    
    return false;
}


//+------------------------------------------------------------------+
//| STEP 1 & 2: Determine Bias and Identify Key Levels               |
//+------------------------------------------------------------------+
void DetermineBiasAndLevels()
{
    // This function would be more complex in a live version.
    // For now, it uses manual input or a very simple automatic logic.
    if(BiasDetectionMode == AUTOMATIC)
    {
        // --- Simple Automatic Bias Detection (Example) ---
        // Looks at the previous day's candle.
        double prevDayHigh = iHigh(_Symbol, PERIOD_D1, 1);
        double prevDayLow = iLow(_Symbol, PERIOD_D1, 1);
        double prevDayClose = iClose(_Symbol, PERIOD_D1, 1);

        if(prevDayClose > (prevDayHigh + prevDayLow) / 2)
            dailyBias = BULLISH;
        else
            dailyBias = BEARISH;
        Print("Automatic Bias Detected: ", EnumToString(dailyBias));
    }
    else
    {
        dailyBias = ManualDailyBias;
    }
    
    // --- Identify HTF Key Levels (PD Arrays) ---
    // This is a placeholder for a more sophisticated scanner.
    // It would search for Order Blocks, FVGs, etc.
    // For now, we'll use previous day's high/low as proxy DOL.
    if(dailyBias == BULLISH)
    {
        htfKeyLevelHigh = iHigh(_Symbol, PERIOD_D1, 1); // Draw on Liquidity is Previous Day High
        DrawHorizontalLine("HTF_Level_High", htfKeyLevelHigh, clrDodgerBlue, STYLE_DOT);
    }
    else if (dailyBias == BEARISH)
    {
        htfKeyLevelLow = iLow(_Symbol, PERIOD_D1, 1); // Draw on Liquidity is Previous Day Low
        DrawHorizontalLine("HTF_Level_Low", htfKeyLevelLow, clrCrimson, STYLE_DOT);
    }
}


//+------------------------------------------------------------------+
//| STEP 3: Set the 8 AM (New York Time) 1-Hour Candle Range         |
//+------------------------------------------------------------------+
void SetCRTRange()
{
    if(crtHigh > 0) return; // Range already set for the day

    // We need to find the correct 1-hour candle corresponding to 8:00-8:59 NY Time
    // This requires converting server time to NY time (EST/EDT, GMT-5/GMT-4)
    // For simplicity, this example assumes a fixed offset. A robust solution would handle DST.
    int timeShiftSeconds = -7 * 3600; // Example: Server is GMT+2, NY is GMT-5. Shift is -7 hours.
    
    datetime nyTime = TimeCurrent() + timeShiftSeconds;
    MqlDateTime ny_tm;
    TimeToStruct(nyTime, ny_tm);

    // Check if the current time is past 9:00 AM NY time
    if(ny_tm.hour >= 9)
    {
        // Find the 8 AM candle on the H1 chart
        MqlRates h1_rates[];
        if(CopyRates(_Symbol, PERIOD_H1, 0, 10, h1_rates) < 10)
        {
            Print("Could not get H1 rates to set CRT range.");
            return;
        }

        for(int i = ArraySize(h1_rates) - 1; i >= 0; i--)
        {
            datetime candle_ny_time = h1_rates[i].time + timeShiftSeconds;
            MqlDateTime candle_ny_tm;
            TimeToStruct(candle_ny_time, candle_ny_tm);

            if(candle_ny_tm.hour == 8)
            {
                crtHigh = h1_rates[i].high;
                crtLow = h1_rates[i].low;
                crtRangeSetTime = TimeCurrent();

                Print("CRT Range Set for ", TimeToString(crtRangeSetTime, TIME_DATE));
                Print("High: ", DoubleToString(crtHigh, _Digits));
                Print("Low: ", DoubleToString(crtLow, _Digits));

                // Draw lines on chart
                DrawHorizontalLine("CRTHighLine", crtHigh, clrGold, STYLE_SOLID, 2);
                DrawHorizontalLine("CRTLowLine", crtLow, clrGold, STYLE_SOLID, 2);
                break;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Checks if the current time is within the NY Killzone             |
//+------------------------------------------------------------------+
bool IsWithinKillzone()
{
    int timeShiftSeconds = -7 * 3600; // Same time shift as above
    datetime nyTime = TimeCurrent() + timeShiftSeconds;
    MqlDateTime ny_tm;
    TimeToStruct(nyTime, ny_tm);

    int start_hour=0, start_min=0, end_hour=0, end_min=0;
    string parts[];

    if(StringSplit(NY_Killzone_Start, ':', parts) == 2)
     {
      start_hour = (int)StringToInteger(parts[0]);
      start_min = (int)StringToInteger(parts[1]);
     }

    if(StringSplit(NY_Killzone_End, ':', parts) == 2)
     {
      end_hour = (int)StringToInteger(parts[0]);
      end_min = (int)StringToInteger(parts[1]);
     }

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
    // Get latest M15 candles
    MqlRates m15_rates[];
    if(CopyRates(_Symbol, PERIOD_M15, 0, 5, m15_rates) < 5) return;

    // We look at the recently completed candle (index 1)
    double last_closed_high = m15_rates[1].high;
    double last_closed_low = m15_rates[1].low;

    // --- Bullish Setup (Manipulation below CRT Low, looking for BUY) ---
    if(dailyBias == BULLISH)
    {
        // Check for a sweep of the CRT Low
        if(last_closed_low < crtLow)
        {
            Print("Potential bullish setup: CRT Low has been swept.");
            // Now, apply the specific entry model logic
            if(EntryLogicModel == CONFIRMATION_MSS)
            {
                // TODO: Implement MSS Logic (check for break of a recent M15 swing high)
                // TODO: Identify resulting FVG or Order Block
                // For this example, we'll trigger a simplified signal
                entrySignal = "BUY Signal (MSS Confirmation)";
                if(OperationalMode == SIGNALS_ONLY) Alert(entrySignal);
                if(OperationalMode == FULLY_AUTOMATED) ExecuteTrade("BUY");
            }
            else if(EntryLogicModel == AGGRESSIVE_TURTLE_SOUP)
            {
                // Enter immediately after the sweep if price closes back above the low
                if(m15_rates[1].close > crtLow)
                {
                    entrySignal = "BUY Signal (Turtle Soup)";
                    if(OperationalMode == SIGNALS_ONLY) Alert(entrySignal);
                    if(OperationalMode == FULLY_AUTOMATED) ExecuteTrade("BUY");
                }
            }
            // TODO: Implement 3-Candle Pattern Logic
        }
    }

    // --- Bearish Setup (Manipulation above CRT High, looking for SELL) ---
    else if(dailyBias == BEARISH)
    {
        // Check for a sweep of the CRT High
        if(last_closed_high > crtHigh)
        {
            Print("Potential bearish setup: CRT High has been swept.");
            if(EntryLogicModel == CONFIRMATION_MSS)
            {
                // TODO: Implement MSS Logic (check for break of a recent M15 swing low)
                // TODO: Identify resulting FVG or Order Block
                entrySignal = "SELL Signal (MSS Confirmation)";
                if(OperationalMode == SIGNALS_ONLY) Alert(entrySignal);
                if(OperationalMode == FULLY_AUTOMATED) ExecuteTrade("SELL");
            }
            else if(EntryLogicModel == AGGRESSIVE_TURTLE_SOUP)
            {
                if(m15_rates[1].close < crtHigh)
                {
                    entrySignal = "SELL Signal (Turtle Soup)";
                    if(OperationalMode == SIGNALS_ONLY) Alert(entrySignal);
                    if(OperationalMode == FULLY_AUTOMATED) ExecuteTrade("SELL");
                }
            }
            // TODO: Implement 3-Candle Pattern Logic
        }
    }
}

//+------------------------------------------------------------------+
//| TRADE EXECUTION: Opens a trade based on signal                   |
//+------------------------------------------------------------------+
void ExecuteTrade(string direction)
{
    if(tradeTakenToday) return;

    // --- Get latest M15 rates to define SL from manipulation wick
    MqlRates m15_rates[];
    if(CopyRates(_Symbol, PERIOD_M15, 0, 2, m15_rates) < 2) return;
    double manipulationWickHigh = m15_rates[1].high;
    double manipulationWickLow = m15_rates[1].low;

    double entry_price = 0;
    double sl_price = 0;
    double tp1_price = 0;
    double tp2_price = 0;
    double lot_size = 0;
    double sl_distance = 0;

    // --- Define minimum SL distance based on pips (1 pip = 10 points for most pairs)
    double min_sl_distance = MinStopLossPips * 10 * _Point;

    if(direction == "BUY")
    {
        entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        sl_price = manipulationWickLow - (SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point);
        sl_distance = entry_price - sl_price;
        
        // --- Validate and adjust SL distance if it's too small
        if(sl_distance < min_sl_distance)
        {
            Print("Original SL distance (", DoubleToString(sl_distance, _Digits), ") is less than MinStopLossPips. Adjusting SL price.");
            sl_distance = min_sl_distance;
            sl_price = entry_price - sl_distance;
        }

        // Calculate TPs
        tp1_price = entry_price + (sl_distance * TakeProfit1_RR);
        tp2_price = crtHigh; // Target opposite side of CRT range

        lot_size = CalculateLotSize(sl_distance);
        
        Print("Attempting BUY Trade: Entry=", DoubleToString(entry_price, _Digits), 
              " SL=", DoubleToString(sl_price, _Digits), 
              " SL_Distance=", DoubleToString(sl_distance, _Digits),
              " LotSize=", DoubleToString(lot_size, 2));

        if(trade.Buy(lot_size, _Symbol, entry_price, sl_price, tp1_price, "CRT Buy"))
        {
            tradeTakenToday = true;
            Print("BUY Trade Executed. Lot: ", lot_size, " SL: ", sl_price, " TP1: ", tp1_price);
            // Open a second position for TP2 if desired
        }
    }
    else if(direction == "SELL")
    {
        entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        sl_price = manipulationWickHigh + (SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point);
        sl_distance = sl_price - entry_price;

        // --- Validate and adjust SL distance if it's too small
        if(sl_distance < min_sl_distance)
        {
            Print("Original SL distance (", DoubleToString(sl_distance, _Digits), ") is less than MinStopLossPips. Adjusting SL price.");
            sl_distance = min_sl_distance;
            sl_price = entry_price + sl_distance;
        }
        
        // Calculate TPs
        tp1_price = entry_price - (sl_distance * TakeProfit1_RR);
        tp2_price = crtLow; // Target opposite side of CRT range
        
        lot_size = CalculateLotSize(sl_distance);

        Print("Attempting SELL Trade: Entry=", DoubleToString(entry_price, _Digits), 
              " SL=", DoubleToString(sl_price, _Digits), 
              " SL_Distance=", DoubleToString(sl_distance, _Digits),
              " LotSize=", DoubleToString(lot_size, 2));

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
    if(sl_distance_price <= 0) 
    {
      Print("Cannot calculate lot size because stop loss distance is zero or negative.");
      return 0.0;
    }

    double account_balance = account.Balance();
    double risk_amount = account_balance * (RiskPercent / 100.0);
    
    // Get Tick Value and Tick Size
    double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

    if(tick_size <= 0) return 0.01;

    double ticks_for_sl = sl_distance_price / tick_size;
    double loss_per_lot = ticks_for_sl * tick_value;

    if(loss_per_lot <= 0) return 0.01;

    double lot_size = risk_amount / loss_per_lot;
    
    // Normalize lot size to broker's allowed volume steps
    double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    lot_size = MathFloor(lot_size / volume_step) * volume_step;
    
    // Check against min and max volume
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
    if(position.SelectByMagic(_Symbol, magicNumber))
    {
        long pos_type = position.PositionType();
        double open_price = position.PriceOpen();
        double current_price = (pos_type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double sl = position.StopLoss();
        double tp = position.TakeProfit();

        // Breakeven Logic
        if(MoveToBE_After_TP1 && sl != open_price)
        {
            if((pos_type == POSITION_TYPE_BUY && current_price >= tp) ||
               (pos_type == POSITION_TYPE_SELL && current_price <= tp))
            {
                // This logic assumes TP1 is hit. A more robust system would track partial closes.
                // For now, if price hits the first TP, we move SL to BE.
                trade.PositionModify(_Symbol, open_price, tp);
                Print("Position moved to Breakeven.");
            }
        }
        
        // Trailing Stop Logic
        if(UseTrailingStop)
        {
             // Simple trailing stop
             if(pos_type == POSITION_TYPE_BUY)
             {
                 if(current_price - open_price > TrailingStopPips * _Point)
                 {
                     double new_sl = current_price - (TrailingStopPips * _Point);
                     if(sl < new_sl)
                     {
                         trade.PositionModify(_Symbol, new_sl, tp);
                     }
                 }
             }
             else // SELL
             {
                 if(open_price - current_price > TrailingStopPips * _Point)
                 {
                     double new_sl = current_price + (TrailingStopPips * _Point);
                     if(sl > new_sl || sl == 0)
                     {
                         trade.PositionModify(_Symbol, new_sl, tp);
                     }
                 }
             }
        }
    }
}


//+------------------------------------------------------------------+
//| UI & DASHBOARD: Functions to draw and update the on-chart display |
//+------------------------------------------------------------------+
void SetupDashboard()
{
    // Create a basic label object for the dashboard
    ObjectCreate(0, "CRTDashboard", OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "CRTDashboard", OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, "CRTDashboard", OBJPROP_YDISTANCE, 15);
    ObjectSetInteger(0, "CRTDashboard", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetString(0, "CRTDashboard", OBJPROP_FONT, "Arial");
    ObjectSetInteger(0, "CRTDashboard", OBJPROP_FONTSIZE, 10);
    ObjectSetInteger(0, "CRTDashboard", OBJPROP_COLOR, clrWhite);
}

void UpdateDashboard()
{
    string dashboard_text = "--- 9 AM CRT Institutional Model ---\n";
    
    // Bias & DOL
    string bias_str = (BiasDetectionMode == MANUAL) ? EnumToString(ManualDailyBias) : "AUTO";
    dashboard_text += "Daily Bias: " + bias_str + "\n";
    if(htfKeyLevelHigh > 0) dashboard_text += "HTF DOL (High): " + DoubleToString(htfKeyLevelHigh, _Digits) + "\n";
    if(htfKeyLevelLow > 0) dashboard_text += "HTF DOL (Low): " + DoubleToString(htfKeyLevelLow, _Digits) + "\n";
    
    // CRT Range
    dashboard_text += "CRT Range Set: " + (crtHigh > 0 ? "YES" : "NO") + "\n";
    if(crtHigh > 0)
    {
        dashboard_text += "  - High: " + DoubleToString(crtHigh, _Digits) + "\n";
        dashboard_text += "  - Low: " + DoubleToString(crtLow, _Digits) + "\n";
    }
    
    // Session & Status
    dashboard_text += "NY Killzone Active: " + (IsWithinKillzone() ? "YES" : "NO") + "\n";
    dashboard_text += "Trade Taken Today: " + (tradeTakenToday ? "YES" : "NO") + "\n";
    if(entrySignal != "") dashboard_text += "Last Signal: " + entrySignal + "\n";
    
    // Filters
    dashboard_text += "Weekly Profile: " + EnumToString(WeeklyProfileHypothesis) + "\n";
    dashboard_text += "News Filter: " + (Use_News_Filter ? "ON" : "OFF") + "\n";
    
    // Set the text to the label object
    ObjectSetString(0, "CRTDashboard", OBJPROP_TEXT, dashboard_text);
}

//+------------------------------------------------------------------+
//| Helper Functions                                                 |
//+------------------------------------------------------------------+
void DrawHorizontalLine(string name, double price, color line_color, ENUM_LINE_STYLE style, int width=1)
{
    if(ObjectFind(0, name) != 0)
    {
        ObjectMove(0, name, 0, TimeCurrent(), price);
    }
    else
    {
        ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
        ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
        ObjectSetInteger(0, name, OBJPROP_STYLE, style);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
    }
}
//+------------------------------------------------------------------+

