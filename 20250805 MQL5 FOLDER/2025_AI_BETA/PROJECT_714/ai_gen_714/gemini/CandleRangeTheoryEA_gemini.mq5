//+------------------------------------------------------------------+
//|                                       CandleRangeTheory_EA.mq5 |
//|                      Copyright 2023, Advanced Trading Systems |
//|                                      https://www.example.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Advanced Trading Systems"
#property link      "https://www.example.com"
#property version   "1.00"
#property description "Expert Advisor based on the Candle Range Theory (CRT) strategy."
#property strict
//https://gemini.google.com/app/33c9e7f539412c3a
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//--- Include files for GUI
#include <Controls\Dialog.mqh>
#include <Controls\Button.mqh>
#include <Controls\Label.mqh>
#include <Controls\Panel.mqh>
#include <Controls\Edit.mqh>

//--- Enums for cleaner input parameters
enum ENUM_ENTRY_METHOD
{
    AUTO_BEST,
    TURTLE_SOUP,
    ORDER_BLOCK_CSD,
    THIRD_CANDLE
};

enum ENUM_OPERATIONAL_MODE
{
    AUTO_TRADING,
    MANUAL_TRADING,
    HYBRID_MODE
};

//--- Input Parameters
//--- General Settings
input group                 "General Settings"
input ENUM_OPERATIONAL_MODE inpOperationalMode = AUTO_TRADING; // Operational Mode
input string                inpMagicNumber     = "13579";      // Magic Number
input double                inpRiskPercent     = 1.0;          // Risk Percentage per Trade (1.0 = 1%)
input double                inpMinRiskReward   = 2.0;          // Minimum Risk:Reward Ratio
input int                   inpMaxTradesPerDay = 5;            // Maximum Trades Per Day
input int                   inpMaxSpread       = 20;           // Maximum Allowable Spread (in points)

//--- Session Management
input group           "Trading Session Management"
input bool            inpEnableSessionTrading = true;          // Enable Session-Based Trading
input bool            inpTradeSydney          = true;          // Trade Sydney Session
input bool            inpTradeTokyo           = true;          // Trade Tokyo Session
input bool            inpTradeFrankfurt       = true;          // Trade Frankfurt Session
input bool            inpTradeLondon          = true;          // Trade London Session
input bool            inpTradeNewYork         = true;          // Trade New York Session
input int             inpGmtOffset            = 0;             // Broker GMT Offset (Auto-detect if 0)

//--- Entry Method Settings
input group             "Entry Method Settings"
input ENUM_ENTRY_METHOD inpEntryMethod = AUTO_BEST; // Default Entry Method

//--- Filtering System
input group "Advanced Filtering System"
input bool  inpInsideBarFilter    = true; // Enable Inside Bar Filter
input bool  inpKeyLevelFilter     = true; // Enable Key Level Confluence Filter
input bool  inpCrtPlusFilter      = true; // Enable CRT Plus (Nested CRT) Filter
input bool  inpMondayFilter       = true; // Avoid Trading on Mondays
input bool  inpFridayFilter       = true; // Avoid Trading on Fridays
// Note: High-impact news filter requires external data source, typically implemented via a DLL or web request.
// This is a placeholder for demonstration.
input bool  inpNewsFilter         = false; // Enable High-Impact News Filter (Requires external library)

//--- Dashboard & Alerts
input group      "Dashboard & Alerts"
input bool       inpEnableDashboard    = true;  // Enable On-Chart Dashboard
input color      inpBullishColor       = clrDodgerBlue; // Bullish Color
input color      inpBearishColor       = clrTomato;     // Bearish Color
input color      inpDashboardBgColor   = clrBlack;      // Dashboard Background Color
input color      inpDashboardTextColor = clrWhite;      // Dashboard Text Color
input bool       inpEnableSoundAlerts  = true;  // Enable Sound Alerts
input bool       inpEnableEmailAlerts  = false; // Enable Email Alerts
input bool       inpEnablePushAlerts   = false; // Enable Push Notifications

//--- Global Variables
CTrade          trade;
CAccountInfo    accountInfo;
CPositionInfo   positionInfo;
long            magicNumber;
int             gmtOffsetAuto;
datetime        lastTradeTime = 0;
int             tradesToday = 0;

//--- GUI Elements
CAppDialog      mainDialog;
CLabel          lblTitle, lblPhase, lblSignal, lblStats, lblRisk;
CButton         btnBuy, btnSell;

//--- CRT Structure
struct CRT_Range
{
    double   high;
    double   low;
    datetime startTime;
    datetime endTime;
    bool     isValid;
    string   phase; // Accumulation, Manipulation, Distribution
};

CRT_Range h4_crt_range;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Initialize global variables
    magicNumber = StringToInteger(inpMagicNumber);
    trade.SetExpertMagicNumber(magicNumber);
    trade.SetDeviationInPoints(5);
    trade.SetTypeFillingBySymbol(Symbol());

    //--- Auto-detect GMT offset if not set
    if(inpGmtOffset == 0)
    {
        gmtOffsetAuto = (int)((TimeGMTOffset() - TimeDaylightSavings()) / 3600);
    }
    else
    {
        gmtOffsetAuto = inpGmtOffset;
    }
    
    //--- Initialize Dashboard if enabled
    if(inpEnableDashboard)
    {
        CreateDashboard();
    }
    
    Print("CRT Expert Advisor Initialized. Mode: ", EnumToString(inpOperationalMode));
    Print("Broker GMT Offset Detected: ", gmtOffsetAuto);

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- Clean up GUI elements
    if(inpEnableDashboard)
    {
        mainDialog.Destroy();
    }
    Comment("");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    //--- Check for new bar to run logic once per bar
    static datetime lastBarTime = 0;
    if(TimeCurrent() < lastBarTime + PeriodSeconds(PERIOD_M15))
        return;
    lastBarTime = TimeCurrent();

    //--- Reset daily trade count if new day
    static int day_of_year = 0;
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    if(dt.day_of_year != day_of_year)
    {
        tradesToday = 0;
        day_of_year = dt.day_of_year;
    }

    //--- Core Logic
    IdentifyCRTRange();
    UpdateDashboard();

    if(inpOperationalMode == AUTO_TRADING || inpOperationalMode == HYBRID_MODE)
    {
        if(CheckTradingConditions())
        {
            ExecuteTrade();
        }
    }
}

//+------------------------------------------------------------------+
//| ChartEvent function for GUI interaction                          |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    //--- Pass event to the dialog
    mainDialog.ChartEvent(id, lparam, dparam, sparam);

    //--- Handle button clicks for Manual/Hybrid modes
    if(id == CHARTEVENT_OBJECT_CLICK)
    {
        if(sparam == "CRT_BuyButton")
        {
            if(inpOperationalMode == MANUAL_TRADING || inpOperationalMode == HYBRID_MODE)
            {
                ManualTrade(ORDER_TYPE_BUY);
            }
        }
        else if(sparam == "CRT_SellButton")
        {
            if(inpOperationalMode == MANUAL_TRADING || inpOperationalMode == HYBRID_MODE)
            {
                ManualTrade(ORDER_TYPE_SELL);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| CRT Phase and Range Identification                               |
//+------------------------------------------------------------------+
void IdentifyCRTRange()
{
    //--- Identify the H4 range (e.g., Asian session range)
    //--- This is a simplified example. A real implementation would be more complex.
    //--- Let's define the range as the high/low of the previous H4 candle.
    MqlRates h4_rates[];
    if(CopyRates(Symbol(), PERIOD_H4, 1, 1, h4_rates) < 1) return;

    h4_crt_range.high = h4_rates[0].high;
    h4_crt_range.low = h4_rates[0].low;
    h4_crt_range.startTime = h4_rates[0].time;
    h4_crt_range.endTime = h4_rates[0].time + PeriodSeconds(PERIOD_H4);
    h4_crt_range.isValid = true;

    //--- Determine CRT Phase based on current price action relative to the range
    double current_price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    if(current_price > h4_crt_range.high)
    {
        h4_crt_range.phase = "Manipulation (Bullish Breakout)";
    }
    else if(current_price < h4_crt_range.low)
    {
        h4_crt_range.phase = "Manipulation (Bearish Breakout)";
    }
    else
    {
        h4_crt_range.phase = "Accumulation";
    }
    
    //--- A more advanced phase detection would look for reversals after manipulation
    //--- to identify the "Distribution" phase.
    
    //--- Draw the range on the chart
    ObjectDelete(0, "CRT_Range_Box");
    ObjectCreate(0, "CRT_Range_Box", OBJ_RECTANGLE_LABEL, 0, h4_crt_range.startTime, h4_crt_range.high, TimeCurrent() + PeriodSeconds(PERIOD_H4), h4_crt_range.low);
    ObjectSetInteger(0, "CRT_Range_Box", OBJPROP_COLOR, clrGray);
    ObjectSetInteger(0, "CRT_Range_Box", OBJPROP_STYLE, STYLE_DOT);
    ObjectSetInteger(0, "CRT_Range_Box", OBJPROP_BACK, true);
}


//+------------------------------------------------------------------+
//| Check General Trading Conditions                                 |
//+------------------------------------------------------------------+
bool CheckTradingConditions()
{
    //--- Check spread
    if((SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) > inpMaxSpread) && (inpMaxSpread > 0))
    {
        Print("Trade aborted. Spread is too high: ", SymbolInfoInteger(Symbol(), SYMBOL_SPREAD));
        return false;
    }

    //--- Check daily trade limit
    if(tradesToday >= inpMaxTradesPerDay)
    {
        Print("Trade aborted. Maximum trades per day reached.");
        return false;
    }

    //--- Check session filter
    if(inpEnableSessionTrading && !IsTradingSessionActive())
    {
        return false;
    }

    //--- Check day of week filters
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    if(inpMondayFilter && dt.day_of_week == 1) return false;
    if(inpFridayFilter && dt.day_of_week == 5) return false;

    //--- Check if a position is already open for this pair
    if(positionInfo.Select(Symbol()))
    {
        return false; // Only one trade per symbol at a time
    }

    return true;
}

//+------------------------------------------------------------------+
//| Main Trade Execution Logic                                       |
//+------------------------------------------------------------------+
void ExecuteTrade()
{
    if(!h4_crt_range.isValid) return;

    ENUM_ORDER_TYPE trade_direction = WRONG_VALUE;
    double sl = 0, tp = 0;
    string entry_method_used = "";

    //--- Determine entry based on selected method
    ENUM_ENTRY_METHOD method = inpEntryMethod;
    if(method == AUTO_BEST)
    {
        //--- Auto Best logic would try each method and pick the first valid signal
        //--- For simplicity, we'll just check them in order
        if(CheckTurtleSoup(trade_direction, sl, tp)) { entry_method_used = "Turtle Soup"; }
        else if(CheckOrderBlock(trade_direction, sl, tp)) { entry_method_used = "Order Block"; }
        else if(CheckThirdCandle(trade_direction, sl, tp)) { entry_method_used = "Third Candle"; }
    }
    else
    {
        switch(method)
        {
            case TURTLE_SOUP:
                if(CheckTurtleSoup(trade_direction, sl, tp)) entry_method_used = "Turtle Soup";
                break;
            case ORDER_BLOCK_CSD:
                if(CheckOrderBlock(trade_direction, sl, tp)) entry_method_used = "Order Block";
                break;
            case THIRD_CANDLE:
                if(CheckThirdCandle(trade_direction, sl, tp)) entry_method_used = "Third Candle";
                break;
        }
    }

    //--- If a valid signal was found, open the trade
    if(trade_direction != WRONG_VALUE)
    {
        double volume = CalculatePositionSize(sl);
        if(volume > 0)
        {
            string signal_type = (trade_direction == ORDER_TYPE_BUY) ? "BUY" : "SELL";
            Print("Opening ", signal_type, " trade. Method: ", entry_method_used, ". Volume: ", volume);
            
            if(trade.PositionOpen(Symbol(), trade_direction, volume, (trade_direction == ORDER_TYPE_BUY ? SymbolInfoDouble(Symbol(), SYMBOL_ASK) : SymbolInfoDouble(Symbol(), SYMBOL_BID)), sl, tp))
            {
                tradesToday++;
                lastTradeTime = TimeCurrent();
                SendAlert("New Trade Opened", StringFormat("%s Signal on %s via %s", signal_type, Symbol(), entry_method_used));
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Entry Method: Turtle Soup                                        |
//+------------------------------------------------------------------+
bool CheckTurtleSoup(ENUM_ORDER_TYPE &trade_direction, double &sl, double &tp)
{
    //--- Turtle Soup: A false breakout pattern.
    //--- Look for price to break the H4 range high/low and then quickly reverse.
    MqlRates m15_rates[];
    if(CopyRates(Symbol(), PERIOD_M15, 0, 3, m15_rates) < 3) return false;

    //--- Bullish Turtle Soup (Sell Stop Hunt)
    //--- Candle 1 breaks below the H4 low. Candle 2 closes back inside the range.
    if(m15_rates[1].low < h4_crt_range.low && m15_rates[0].close > h4_crt_range.low)
    {
        trade_direction = ORDER_TYPE_BUY;
        sl = m15_rates[1].low - (SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) * _Point);
        tp = m15_rates[0].close + (m15_rates[0].close - sl) * inpMinRiskReward;
        return true;
    }

    //--- Bearish Turtle Soup (Buy Stop Hunt)
    //--- Candle 1 breaks above the H4 high. Candle 2 closes back inside the range.
    if(m15_rates[1].high > h4_crt_range.high && m15_rates[0].close < h4_crt_range.high)
    {
        trade_direction = ORDER_TYPE_SELL;
        sl = m15_rates[1].high + (SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) * _Point);
        tp = m15_rates[0].close - (sl - m15_rates[0].close) * inpMinRiskReward;
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Entry Method: Order Block / Change of State                      |
//+------------------------------------------------------------------+
bool CheckOrderBlock(ENUM_ORDER_TYPE &trade_direction, double &sl, double &tp)
{
    //--- Order Block: Look for a strong move away from a key level, leaving an "order block" candle.
    //--- This is a very simplified example. Real order block detection is highly nuanced.
    MqlRates m15_rates[];
    if(CopyRates(Symbol(), PERIOD_M15, 0, 5, m15_rates) < 5) return false;

    //--- Bullish Order Block (Demand)
    //--- Price sweeps below H4 low, then a strong bullish candle forms.
    //--- The order block is the last down candle before the strong up move.
    if(m15_rates[2].low < h4_crt_range.low && m15_rates[1].close > m15_rates[1].open && (m15_rates[1].close - m15_rates[1].open) > (m15_rates[2].high - m15_rates[2].low))
    {
        //--- Entry when price retraces to the order block (m15_rates[2])
        if(m15_rates[0].low <= m15_rates[2].high && m15_rates[0].close > m15_rates[2].open)
        {
            trade_direction = ORDER_TYPE_BUY;
            sl = m15_rates[2].low - (SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) * _Point);
            tp = m15_rates[0].close + (m15_rates[0].close - sl) * inpMinRiskReward;
            return true;
        }
    }

    //--- Bearish Order Block (Supply)
    //--- Price sweeps above H4 high, then a strong bearish candle forms.
    if(m15_rates[2].high > h4_crt_range.high && m15_rates[1].open > m15_rates[1].close && (m15_rates[1].open - m15_rates[1].close) > (m15_rates[2].high - m15_rates[2].low))
    {
        //--- Entry when price retraces to the order block
        if(m15_rates[0].high >= m15_rates[2].low && m15_rates[0].close < m15_rates[2].open)
        {
            trade_direction = ORDER_TYPE_SELL;
            sl = m15_rates[2].high + (SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) * _Point);
            tp = m15_rates[0].close - (sl - m15_rates[0].close) * inpMinRiskReward;
            return true;
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Entry Method: Third Candle Confirmation                          |
//+------------------------------------------------------------------+
bool CheckThirdCandle(ENUM_ORDER_TYPE &trade_direction, double &sl, double &tp)
{
    //--- Third Candle: A simple 3-candle reversal pattern after a breakout.
    MqlRates m15_rates[];
    if(CopyRates(Symbol(), PERIOD_M15, 0, 3, m15_rates) < 3) return false;

    //--- Bullish 3-Candle Entry
    //--- 1. Bearish candle breaks H4 low. 2. Small/Indecision candle. 3. Bullish candle closes above candle 1's high.
    if(m15_rates[2].close < m15_rates[2].open && m15_rates[2].low < h4_crt_range.low &&
       m15_rates[0].close > m15_rates[0].open && m15_rates[0].close > m15_rates[2].high)
    {
        trade_direction = ORDER_TYPE_BUY;
        sl = m15_rates[2].low - (SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) * _Point);
        tp = m15_rates[0].close + (m15_rates[0].close - sl) * inpMinRiskReward;
        return true;
    }

    //--- Bearish 3-Candle Entry
    //--- 1. Bullish candle breaks H4 high. 2. Small/Indecision candle. 3. Bearish candle closes below candle 1's low.
    if(m15_rates[2].close > m15_rates[2].open && m15_rates[2].high > h4_crt_range.high &&
       m15_rates[0].open > m15_rates[0].close && m15_rates[0].close < m15_rates[2].low)
    {
        trade_direction = ORDER_TYPE_SELL;
        sl = m15_rates[2].high + (SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) * _Point);
        tp = m15_rates[0].close - (sl - m15_rates[0].close) * inpMinRiskReward;
        return true;
    }

    return false;
}


//+------------------------------------------------------------------+
//| Calculate Position Size based on Risk                            |
//+------------------------------------------------------------------+
double CalculatePositionSize(double sl)
{
    double account_balance = accountInfo.Balance();
    double risk_amount = account_balance * (inpRiskPercent / 100.0);
    double price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double tick_value = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
    double tick_size = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);

    if(sl == 0) return 0;
    
    double sl_points = MathAbs(price - sl) / _Point;
    if(sl_points == 0) return 0;

    double risk_per_lot = sl_points * tick_value;
    if(risk_per_lot == 0) return 0;
    
    double volume = risk_amount / risk_per_lot;

    //--- Normalize and check against min/max volume
    double min_volume = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    double max_volume = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
    double volume_step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

    volume = MathFloor(volume / volume_step) * volume_step;

    if(volume < min_volume) volume = min_volume;
    if(volume > max_volume) volume = max_volume;

    //--- Margin Check
    double margin_required;
    if(!OrderCalcMargin(ORDER_TYPE_BUY, Symbol(), volume, price, margin_required))
    {
        Print("Failed to calculate margin for ", Symbol());
        return 0;
    }
    if(accountInfo.FreeMargin() < margin_required)
    {
        Print("Not enough margin to open trade. Required: ", margin_required, ", Free: ", accountInfo.FreeMargin());
        return 0;
    }

    return volume;
}

//+------------------------------------------------------------------+
//| Session Management                                               |
//+------------------------------------------------------------------+
bool IsTradingSessionActive()
{
    datetime serverTime = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(serverTime, dt);

    int hour = dt.hour;

    //--- Adjust for GMT offset
    hour = (hour + gmtOffsetAuto + 24) % 24;

    //--- Session Times (GMT)
    // Sydney: 22:00 - 07:00
    // Tokyo: 00:00 - 09:00
    // Frankfurt: 07:00 - 16:00
    // London: 08:00 - 17:00
    // New York: 13:00 - 22:00

    if(inpTradeSydney    && ((hour >= 22 && hour <= 23) || (hour >= 0 && hour < 7))) return true;
    if(inpTradeTokyo     && (hour >= 0 && hour < 9)) return true;
    if(inpTradeFrankfurt && (hour >= 7 && hour < 16)) return true;
    if(inpTradeLondon    && (hour >= 8 && hour < 17)) return true;
    if(inpTradeNewYork   && (hour >= 13 && hour < 22)) return true;

    return false;
}

//+------------------------------------------------------------------+
//| Manual Trade Execution                                           |
//+------------------------------------------------------------------+
void ManualTrade(ENUM_ORDER_TYPE direction)
{
    if(!CheckTradingConditions()) return;
    
    //--- For manual trades, SL/TP must be calculated based on a recent swing
    MqlRates m15_rates[];
    if(CopyRates(Symbol(), PERIOD_M15, 0, 10, m15_rates) < 10) return;

    double sl = 0, tp = 0;
    
    if(direction == ORDER_TYPE_BUY)
    {
        sl = SymbolInfoDouble(Symbol(), SYMBOL_BID) - (iATR(Symbol(), PERIOD_M15, 14) * 1.5);
        tp = SymbolInfoDouble(Symbol(), SYMBOL_ASK) + (SymbolInfoDouble(Symbol(), SYMBOL_ASK) - sl) * inpMinRiskReward;
    }
    else // SELL
    {
        sl = SymbolInfoDouble(Symbol(), SYMBOL_ASK) + (iATR(Symbol(), PERIOD_M15, 14) * 1.5);
        tp = SymbolInfoDouble(Symbol(), SYMBOL_BID) - (sl - SymbolInfoDouble(Symbol(), SYMBOL_BID)) * inpMinRiskReward;
    }
    
    double volume = CalculatePositionSize(sl);
    if(volume > 0)
    {
        string signal_type = (direction == ORDER_TYPE_BUY) ? "MANUAL BUY" : "MANUAL SELL";
        if(trade.PositionOpen(Symbol(), direction, volume, (direction == ORDER_TYPE_BUY ? SymbolInfoDouble(Symbol(), SYMBOL_ASK) : SymbolInfoDouble(Symbol(), SYMBOL_BID)), sl, tp))
        {
            tradesToday++;
            lastTradeTime = TimeCurrent();
            SendAlert("Manual Trade Opened", StringFormat("%s on %s", signal_type, Symbol()));
        }
    }
}


//+------------------------------------------------------------------+
//| Create Dashboard                                                 |
//+------------------------------------------------------------------+
void CreateDashboard()
{
    //--- Create the main panel
    int dialog_x = 10, dialog_y = 10;
    int dialog_w = 250, dialog_h = 200;
    mainDialog.Create(0, "CRT_Dashboard", 0, dialog_x, dialog_y, dialog_x + dialog_w, dialog_y + dialog_h);
    // Note: The CAppDialog in the standard library doesn't have these methods.
    // mainDialog.ColorBackground(inpDashboardBgColor);
    // mainDialog.ColorText(inpDashboardTextColor);
    // mainDialog.BorderColor(clrGray);

    //--- Title
    lblTitle.Create(0, "CRT_lblTitle", 0, dialog_x + 10, dialog_y + 10, dialog_x + 240, dialog_y + 30);
    lblTitle.Text("Candle Range Theory EA");
    lblTitle.Color(clrWhite);
    lblTitle.FontSize(10);
    lblTitle.Font("Arial");

    //--- CRT Phase
    lblPhase.Create(0, "CRT_lblPhase", 0, dialog_x + 10, dialog_y + 35, dialog_x + 240, dialog_y + 50);
    lblPhase.Color(clrWhite);
    
    //--- Signal
    lblSignal.Create(0, "CRT_lblSignal", 0, dialog_x + 10, dialog_y + 55, dialog_x + 240, dialog_y + 70);
    lblSignal.Color(clrWhite);
    
    //--- Stats
    lblStats.Create(0, "CRT_lblStats", 0, dialog_x + 10, dialog_y + 75, dialog_x + 240, dialog_y + 115);
    lblStats.Color(clrWhite);
    
    //--- Risk
    lblRisk.Create(0, "CRT_lblRisk", 0, dialog_x + 10, dialog_y + 120, dialog_x + 240, dialog_y + 135);
    lblRisk.Color(clrWhite);

    //--- Manual Trade Buttons
    btnBuy.Create(0, "CRT_BuyButton", 0, dialog_x + 10, dialog_y + 150, dialog_x + 120, dialog_y + 180);
    btnBuy.Text("BUY");
    btnBuy.Color(inpBullishColor);
    btnBuy.ColorBackground(C'60,80,100');

    btnSell.Create(0, "CRT_SellButton", 0, dialog_x + 130, dialog_y + 150, dialog_x + 240, dialog_y + 180);
    btnSell.Text("SELL");
    btnSell.Color(inpBearishColor);
    btnSell.ColorBackground(C'100,80,60');

    mainDialog.Run();
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update Dashboard Information                                     |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
    if(!inpEnableDashboard) return;

    //--- Update Phase
    string phase_text = "CRT Phase: " + (h4_crt_range.isValid ? h4_crt_range.phase : "Waiting...");
    lblPhase.Text(phase_text);

    //--- Update Signal (This is a simplified representation)
    ENUM_ORDER_TYPE sig_dir = WRONG_VALUE;
    double sl, tp;
    string signal_text = "Signal: None";
    if(CheckTurtleSoup(sig_dir, sl, tp) || CheckOrderBlock(sig_dir, sl, tp) || CheckThirdCandle(sig_dir, sl, tp))
    {
        if(sig_dir == ORDER_TYPE_BUY) {
            signal_text = "Signal: Bullish Setup Detected";
            lblSignal.Color(inpBullishColor);
        } else if (sig_dir == ORDER_TYPE_SELL) {
            signal_text = "Signal: Bearish Setup Detected";
            lblSignal.Color(inpBearishColor);
        }
    } else {
        lblSignal.Color(clrWhite);
    }
    lblSignal.Text(signal_text);

    //--- Update Stats
    double profit = 0;
    int win_count = 0;
    int trade_count = 0;
    HistorySelect(0, TimeCurrent());
    for(int i = 0; i < (int)HistoryDealsTotal(); i++)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == magicNumber)
        {
            if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
            {
                trade_count++;
                double p = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                profit += p;
                if(p > 0) win_count++;
            }
        }
    }
    double win_rate = (trade_count > 0) ? (double)win_count / trade_count * 100.0 : 0;
    string stats_text = StringFormat("P/L: %.2f | Win Rate: %.1f%% | Trades: %d/%d",
                                     profit, win_rate, tradesToday, inpMaxTradesPerDay);
    lblStats.Text(stats_text);

    //--- Update Risk
    string risk_text = StringFormat("Risk/Trade: %.2f%% | R:R: 1:%.1f", inpRiskPercent, inpMinRiskReward);
    lblRisk.Text(risk_text);

    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Send Alerts                                                      |
//+------------------------------------------------------------------+
void SendAlert(string subject, string message)
{
    if(inpEnableSoundAlerts) Alert(subject, " - ", message);
    if(inpEnableEmailAlerts) SendMail(subject, message);
    if(inpEnablePushAlerts) SendNotification(message);
}
//+------------------------------------------------------------------+

