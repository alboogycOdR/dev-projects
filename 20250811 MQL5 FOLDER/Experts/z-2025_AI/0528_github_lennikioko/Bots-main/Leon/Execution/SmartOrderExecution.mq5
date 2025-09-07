//+------------------------------------------------------------------+
//|                                           SmartOrderExecution.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property script_show_inputs

#include <Trade/Trade.mqh>
#include <Helpers/OrderManagement.mqh>

// Input parameters
input ENUM_ORDER_TYPE OrderType = ORDER_TYPE_BUY;  // Order Type
input double RiskAmount = 100.0;                   // Risk Amount in USD
input string Comment = "";                         // Trade Comment

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    // Check if all required lines exist
    if(!CheckRequiredLines()) {
        Print("Error: Not all required lines (ENTRY, SL, TP) are present on the chart!");
        return;
    }

    // Get line prices
    double entryPrice = ObjectGetDouble(ChartID(), "ENTRY", OBJPROP_PRICE);
    double slPrice = ObjectGetDouble(ChartID(), "SL", OBJPROP_PRICE);
    double tpPrice = ObjectGetDouble(ChartID(), "TP", OBJPROP_PRICE);

    // Validate price levels based on order type
    if(!ValidatePriceLevels(OrderType, entryPrice, slPrice, tpPrice)) {
        Print("Error: Invalid price levels for the selected order type!");
        return;
    }

    // Calculate lot size based on risk
    double lotSize = CalculateLotSize(RiskAmount, entryPrice, slPrice);

    if(lotSize <= 0) {
        Print("Error: Invalid lot size calculated!");
        return;
    }

    // Execute the trade
    ExecuteTrade(OrderType, lotSize, entryPrice, slPrice, tpPrice);
}

//+------------------------------------------------------------------+
//| Check if all required lines exist on the chart                   |
//+------------------------------------------------------------------+
bool CheckRequiredLines()
{
    string requiredLines[] = {"ENTRY", "SL", "TP"};

    for(int i = 0; i < ArraySize(requiredLines); i++) {
        if(ObjectFind(ChartID(), requiredLines[i]) < 0) {
            Print("Line not found: ", requiredLines[i]);
            return false;
        }
    }
    return true;
}

//+------------------------------------------------------------------+
//| Validate price levels based on order type                        |
//+------------------------------------------------------------------+
bool ValidatePriceLevels(ENUM_ORDER_TYPE orderType, double entry, double sl, double tp)
{
    if(orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_BUY_STOP) {
        // For buy orders, SL should be below entry and TP above entry
        return (sl < entry && tp > entry);
    }
    else if(orderType == ORDER_TYPE_SELL || orderType == ORDER_TYPE_SELL_LIMIT || orderType == ORDER_TYPE_SELL_STOP) {
        // For sell orders, SL should be above entry and TP below entry
        return (sl > entry && tp < entry);
    }
    return false;
}

//+------------------------------------------------------------------+
//| Execute the trade with given parameters                          |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE orderType, double lotSize, double entry, double sl, double tp)
{
    // Set magic number and deviation
    trade.SetExpertMagicNumber(123456);
    trade.SetDeviationInPoints(10);

    bool result = false;

    switch(orderType) {
        case ORDER_TYPE_BUY:
            result = trade.Buy(lotSize, _Symbol, 0, sl, tp, Comment);
            break;

        case ORDER_TYPE_SELL:
            result = trade.Sell(lotSize, _Symbol, 0, sl, tp, Comment);
            break;

        case ORDER_TYPE_BUY_LIMIT:
            result = trade.BuyLimit(lotSize, entry, _Symbol, sl, tp, 0, 0, Comment);
            break;

        case ORDER_TYPE_SELL_LIMIT:
            result = trade.SellLimit(lotSize, entry, _Symbol, sl, tp, 0, 0, Comment);
            break;

        case ORDER_TYPE_BUY_STOP:
            result = trade.BuyStop(lotSize, entry, _Symbol, sl, tp, 0, 0, Comment);
            break;

        case ORDER_TYPE_SELL_STOP:
            result = trade.SellStop(lotSize, entry, _Symbol, sl, tp, 0, 0, Comment);
            break;
    }

    if(result) {
        Print("Trade executed successfully! Lot Size: ", lotSize);
    } else {
        Print("Trade execution failed! Error: ", GetLastError());
    }
}