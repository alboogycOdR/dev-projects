//+------------------------------------------------------------------+
//|                                                       XAUUSD.mq5 |
//|                                    Copyright 2025, Shivam Shikhar |
//|                                   (Modified for M5 Trading)      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Shivam Shikhar"
#property link      ""
#property version   "1.01" // Increased version number

//+------------------------------------------------------------------+
//| Includes and Declarations                                        |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

// Declare trade object
CTrade trade;

// Indicator handles
int ema9_handle;
int ema50_handle;  // EMA50 on H1 (trend filter)
int vwap_handle;   // Custom VWAP indicator handle

// Global variables
datetime last_bar_time = 0;
const double FIXED_LOT_SIZE = 0.01; // Adjust as needed
const string SYMBOL = "XAUUSDm";     // *** CHANGE THIS TO YOUR BROKER'S SYMBOL ***
const ENUM_TIMEFRAMES TIMEFRAME = PERIOD_M5;      // Trading timeframe (M5)
const ENUM_TIMEFRAMES TREND_TIMEFRAME = PERIOD_H1;  // Trend timeframe (H1)
double   stopLossPips = 30; // *** ADJUST THIS VALUE *** Stop Loss in pips

//+------------------------------------------------------------------+
//| Initialization Function                                          |
//+------------------------------------------------------------------+
void OnInit()
{
    // Create EMA9 indicator handle (on M5)
    ema9_handle = iMA(SYMBOL, TIMEFRAME, 9, 0, MODE_EMA, PRICE_CLOSE);
    if(ema9_handle == INVALID_HANDLE)
    {
        Print("Failed to create EMA9 handle. EA will terminate.");
        ExpertRemove();
        return;
    }

    // Create EMA50 indicator handle (on H1)
    ema50_handle = iMA(SYMBOL, TREND_TIMEFRAME, 50, 0, MODE_EMA, PRICE_CLOSE);
    if(ema50_handle == INVALID_HANDLE)
    {
        Print("Failed to create EMA50 handle. EA will terminate.");
        ExpertRemove();
        return;
    }

    // Create handle for custom VWAP indicator (on M5)
    vwap_handle = iCustom(SYMBOL, TIMEFRAME, "VWAP_UTC_Final"); // *** ENSURE THIS WORKS ON M5 ***
    if(vwap_handle == INVALID_HANDLE)
    {
        Print("Failed to create VWAP handle. EA will terminate.");
        ExpertRemove();
        return;
    }

    trade.SetDeviationInPoints(10); // Allow 1 pip slippage (adjust as needed)
    trade.SetExpertMagicNumber(12345); // Good practice to set a Magic Number
    trade.SetTypeFilling(ORDER_FILLING_FOK); // Or ORDER_FILLING_IOC, depending on your broker

    Print("EA initialized successfully on ", SYMBOL, " (M5), Trend analysis on H1");
}

//+------------------------------------------------------------------+
//| Main Tick Function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
    //--- Check for Algo Trading enabled (CRITICAL)
    if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) {
        Print("Algo Trading is NOT enabled!  Please enable it.");
        return; // Exit if trading is not allowed
    }

    // Check for new bar (on M5)
    datetime current_bar_time = iTime(SYMBOL, TIMEFRAME, 0);
    if(current_bar_time <= last_bar_time)
        return;
    last_bar_time = current_bar_time;

    // Get indicator values
    double ema9[];
    ArraySetAsSeries(ema9, true);
    if(CopyBuffer(ema9_handle, 0, 0, 3, ema9) < 3)
    {
        Print("Failed to copy EMA9 data");
        return;
    }

    // Get EMA50 values from H1 timeframe
    double ema50[];
    ArraySetAsSeries(ema50, true);
    if(CopyBuffer(ema50_handle, 0, 0, 2, ema50) < 2)
    {
        Print("Failed to copy EMA50 data");
        return;
    }

    double vwap[];
    ArraySetAsSeries(vwap, true);
    if(CopyBuffer(vwap_handle, 0, 0, 3, vwap) < 3)
    {
        Print("Failed to copy VWAP data");
        return;
    }


    // Get previous candle's close (on M5)
    double close1 = iClose(SYMBOL, TIMEFRAME, 1);

    // Check and manage existing position (on M5)
    if(PositionSelect(SYMBOL))
    {
        CheckExitCondition(close1, ema9[1]);
        CheckBetterOpportunity(ema9, vwap);
    }
    else
    {
        CheckEntryConditions(ema9, vwap, ema50);
    }
}

//+------------------------------------------------------------------+
//| Check Entry Conditions (Trend Filtered on H1)                    |
//+------------------------------------------------------------------+
void CheckEntryConditions(double &ema9[], double &vwap[], double &ema50[])
{
    int digits = (int)SymbolInfoInteger(SYMBOL, SYMBOL_DIGITS);
    double point = SymbolInfoDouble(SYMBOL, SYMBOL_POINT);
    double ask = SymbolInfoDouble(SYMBOL, SYMBOL_ASK); // Get current Ask price
    double bid = SymbolInfoDouble(SYMBOL, SYMBOL_BID); // Get current Bid price


    // Determine the trend based on EMA50 on H1
    bool isUptrend  = (ema50[0] > ema50[1]);
    bool isDowntrend = (ema50[0] < ema50[1]);


    // Buy condition: EMA9 crosses above VWAP AND uptrend (on H1)
    if(isUptrend && ema9[2] < vwap[2] && ema9[1] > vwap[1])
    {
        // Calculate stop loss in points based on stopLossPips
        double sl = NormalizeDouble(ask - (stopLossPips * point), digits);
        //--- Check if SL is valid BEFORE attempting to trade
        if(sl >= ask) {
            Print("ERROR: Stop Loss is invalid for Buy (SL >= Ask).  Check stopLossPips.");
            return; // Don't trade if SL is invalid
        }
        if(trade.Buy(FIXED_LOT_SIZE, SYMBOL, ask, sl, 0.0))
        {
            Print("Buy trade opened with SL: ", sl, " (H1 Uptrend)");
        }
        else
        {
           Print("trade.Buy() FAILED.  Error: ", GetLastError()); // ADDED: Trade Failure

        }
    }
    // Sell condition: EMA9 crosses below VWAP AND downtrend (on H1)
    else if(isDowntrend && ema9[2] > vwap[2] && ema9[1] < vwap[1])
    {
       // Calculate stop loss in points based on stopLossPips
        double sl = NormalizeDouble(bid + (stopLossPips * point), digits);
        //--- Check if SL is valid BEFORE attempting to trade
        if(sl <= bid) {
           Print("ERROR: Stop Loss is invalid for Sell (SL <= Bid). Check stopLossPips.");
            return; // Don't trade if SL is invalid
        }

        if(trade.Sell(FIXED_LOT_SIZE, SYMBOL, bid, sl, 0.0))
        {
            Print("Sell trade opened with SL: ", sl, " (H1 Downtrend)");
        }
        else
        {
          Print("trade.Sell() FAILED.  Error: ", GetLastError()); // ADDED: Trade Failure

        }
    }
}

//+------------------------------------------------------------------+
//| Check Exit Condition                                             |
//+------------------------------------------------------------------+
void CheckExitCondition(double close1, double ema9_prev)
{
    if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
    {
        if(close1 < ema9_prev)
        {
            if(!trade.PositionClose(SYMBOL)){
                Print("Error closing Buy position. Error: ", GetLastError());
            } else {
                Print("Buy position closed - previous candle closed below EMA9");
            }

        }
    }
    else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
    {
        if(close1 > ema9_prev)
        {
            if(!trade.PositionClose(SYMBOL)){
                 Print("Error closing Sell position. Error: ", GetLastError());
            } else {
                Print("Sell position closed - previous candle closed above EMA9");
            }
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
    double ask = SymbolInfoDouble(SYMBOL, SYMBOL_ASK); // Get current Ask price
    double bid = SymbolInfoDouble(SYMBOL, SYMBOL_BID); // Get current Bid price

    if(PositionSelect(SYMBOL))
    {
        long pos_type = PositionGetInteger(POSITION_TYPE);
        // Switch from sell to buy
        if(pos_type == POSITION_TYPE_SELL && ema9[2] < vwap[2] && ema9[1] > vwap[1])
        {

            if(!trade.PositionClose(SYMBOL)){
                Print("Error closing Sell position for switch. Error: ", GetLastError());
            }
             else {
                // Calculate stop loss in points based on stopLossPips
                double sl = NormalizeDouble(ask - (stopLossPips * point), digits);
                 //--- Check if SL is valid BEFORE attempting to trade
                if(sl >= ask) {
                    Print("ERROR: Stop Loss is invalid for Buy (SL >= Ask) on switch. Check stopLossPips.");
                    return;
                 }
                if(trade.Buy(FIXED_LOT_SIZE, SYMBOL, ask, sl, 0.0)) {
                     Print("Switched from Sell to Buy trade");
                } else {
                   Print("Switch trade (Buy) FAILED. Error: ", GetLastError());
                }

            }

        }
        // Switch from buy to sell
        else if(pos_type == POSITION_TYPE_BUY && ema9[2] > vwap[2] && ema9[1] < vwap[1])
        {
           if(!trade.PositionClose(SYMBOL)) {
                Print("Error closing Buy position for switch. Error: ", GetLastError());
           }
            else
           {

                // Calculate stop loss in points based on stopLossPips
                double sl = NormalizeDouble(bid + (stopLossPips * point), digits);
               //--- Check if SL is valid BEFORE attempting to trade
                if(sl <= bid) {
                    Print("ERROR: Stop Loss is invalid for Sell (SL <= Bid) on switch.  Check stopLossPips.");
                    return; // Don't trade if SL is invalid
                }

                if(trade.Sell(FIXED_LOT_SIZE, SYMBOL, bid, sl, 0.0)) {
                   Print("Switched from Buy to Sell trade");
                } else {
                    Print("Switch trade (Sell) FAILED. Error: ", GetLastError());
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Deinitialization Function                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(ema9_handle != INVALID_HANDLE)
        IndicatorRelease(ema9_handle);
    if(ema50_handle != INVALID_HANDLE)
        IndicatorRelease(ema50_handle);
    if(vwap_handle != INVALID_HANDLE)
        IndicatorRelease(vwap_handle);
    Print("EA deinitialized. Reason: ", reason);
}
//+------------------------------------------------------------------+