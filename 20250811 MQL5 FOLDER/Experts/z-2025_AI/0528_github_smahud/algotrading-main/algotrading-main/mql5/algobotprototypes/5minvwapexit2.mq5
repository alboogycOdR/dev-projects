//+------------------------------------------------------------------+
//|                                                       XAUUSD.mq5 |
//|                                    Copyright 2025, Shivam Shikhar |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Shivam Shikhar"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| Includes and Declarations                                        |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

// Declare trade object
CTrade trade;

// Indicator handles
int ema9_handle;
int vwap_handle;  // Handle for custom VWAP indicator

// Global variables
datetime last_bar_time = 0;
const double FIXED_LOT_SIZE = 0.20;
const string SYMBOL = "ETHUSDm";
const ENUM_TIMEFRAMES TIMEFRAME = PERIOD_M5;

//+------------------------------------------------------------------+
//| Initialization Function                                          |
//+------------------------------------------------------------------+
void OnInit()
{
    // Create EMA9 indicator handle
    ema9_handle = iMA(SYMBOL, TIMEFRAME, 9, 0, MODE_EMA, PRICE_CLOSE);
    if (ema9_handle == INVALID_HANDLE)
    {
        Print("Failed to create EMA9 handle. EA will terminate.");
        ExpertRemove();
        return;
    }

    // Create handle for custom VWAP indicator
    vwap_handle = iCustom(SYMBOL, TIMEFRAME, "VWAP_UTC_Final");
    if (vwap_handle == INVALID_HANDLE)
    {
        Print("Failed to create VWAP handle. EA will terminate.");
        ExpertRemove();
        return;
    }

    trade.SetDeviationInPoints(10);
    Print("EA initialized successfully on ", SYMBOL, " (M5)");
}

//+------------------------------------------------------------------+
//| Main Tick Function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check for new bar
    datetime current_bar_time = iTime(SYMBOL, TIMEFRAME, 0);
    if (current_bar_time <= last_bar_time)
        return;
    last_bar_time = current_bar_time;

    // Get indicator values
    double ema9[];
    ArraySetAsSeries(ema9, true);
    if (CopyBuffer(ema9_handle, 0, 0, 3, ema9) < 3)
    {
        Print("Failed to copy EMA9 data");
        return;
    }

    double vwap[];
    ArraySetAsSeries(vwap, true);
    if (CopyBuffer(vwap_handle, 0, 0, 3, vwap) < 3)
    {
        Print("Failed to copy VWAP data");
        return;
    }

    // Check and manage existing position
    if (PositionSelect(SYMBOL))
    {
        CheckExitCondition(ema9); // Pass the ema9 array
        CheckBetterOpportunity(ema9, vwap);
    }
    else
    {
        CheckEntryConditions(ema9, vwap);
    }
}

//+------------------------------------------------------------------+
//| Check Entry Conditions                                           |
//+------------------------------------------------------------------+
void CheckEntryConditions(double &ema9[], double &vwap[])
{
    int digits = (int)SymbolInfoInteger(SYMBOL, SYMBOL_DIGITS);
    double point = SymbolInfoDouble(SYMBOL, SYMBOL_POINT);

    // Buy condition: EMA9 crosses above VWAP
    if (ema9[2] < vwap[2] && ema9[1] > vwap[1])
    {
        double sl = NormalizeDouble(vwap[1] - 3 * point, digits);
        if (trade.Buy(FIXED_LOT_SIZE, SYMBOL, 0.0, sl, 0.0))
        {
            Print("Buy trade opened with SL: ", sl);
        }
        else
        {
            Print("Error opening Buy trade: ", GetLastError());
        }
    }
    // Sell condition: EMA9 crosses below VWAP
    else if (ema9[2] > vwap[2] && ema9[1] < vwap[1])
    {
        double sl = NormalizeDouble(vwap[1] + 3 * point, digits);
        if (trade.Sell(FIXED_LOT_SIZE, SYMBOL, 0.0, sl, 0.0))
        {
            Print("Sell trade opened with SL: ", sl);
        }
        else
        {
            Print("Error opening Sell trade: ", GetLastError());
        }
    }
}

//+------------------------------------------------------------------+
//| Check Exit Condition (Modified)                                 |
//+------------------------------------------------------------------+
void CheckExitCondition(double &ema9[])  //Now accepting array
{
    // Get previous two candles' closes
    double close1 = iClose(SYMBOL, TIMEFRAME, 1);
    double close2 = iClose(SYMBOL, TIMEFRAME, 2);


    if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
    {
        // Exit if two consecutive closes below EMA9
        if (close1 < ema9[1] && close2 < ema9[2])
        {
            trade.PositionClose(SYMBOL);
            Print("Buy position closed - two consecutive candles closed below EMA9");
        }
    }
    else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
    {
        // Exit if two consecutive closes above EMA9
        if (close1 > ema9[1] && close2 > ema9[2])
        {
            trade.PositionClose(SYMBOL);
            Print("Sell position closed - two consecutive candles closed above EMA9");
        }
    }
}

//+------------------------------------------------------------------+
//| Check for Better Opportunity                                     |
//+------------------------------------------------------------------+
void CheckBetterOpportunity(double &ema9[], double &vwap[])
{
    int digits = (int)SymbolInfoInteger(SYMBOL, SYMBOL_DIGITS);
    double point = SymbolInfoDouble(SYMBOL, SYMBOL_POINT);

    if (PositionSelect(SYMBOL))
    {
        long pos_type = PositionGetInteger(POSITION_TYPE);
        // Switch from sell to buy
        if (pos_type == POSITION_TYPE_SELL && ema9[2] < vwap[2] && ema9[1] > vwap[1])
        {
            trade.PositionClose(SYMBOL);
            double sl = NormalizeDouble(vwap[1] - 3 * point, digits);
            if (trade.Buy(FIXED_LOT_SIZE, SYMBOL, 0.0, sl, 0.0))
            {
                Print("Switched from Sell to Buy trade");
            }
            else
            {
                Print("Error switching from Sell to Buy: ", GetLastError());
            }
        }
        // Switch from buy to sell
        else if (pos_type == POSITION_TYPE_BUY && ema9[2] > vwap[2] && ema9[1] < vwap[1])
        {
            trade.PositionClose(SYMBOL);
            double sl = NormalizeDouble(vwap[1] + 3 * point, digits);
            if (trade.Sell(FIXED_LOT_SIZE, SYMBOL, 0.0, sl, 0.0))
            {
                Print("Switched from Buy to Sell trade");
            }
            else
            {
                Print("Error switching from Buy to Sell: ", GetLastError());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Deinitialization Function                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if (ema9_handle != INVALID_HANDLE)
        IndicatorRelease(ema9_handle);
    if (vwap_handle != INVALID_HANDLE)
        IndicatorRelease(vwap_handle);
    Print("EA deinitialized. Reason: ", reason);
}
//+------------------------------------------------------------------+