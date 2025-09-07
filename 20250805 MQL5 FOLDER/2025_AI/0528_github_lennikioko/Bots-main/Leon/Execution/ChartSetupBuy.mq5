//+------------------------------------------------------------------+
//|                                                   ChartSetupBuy.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    // Delete all objects first
    ObjectsDeleteAll(ChartID());

    // Get current price for initial line placement
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double points = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // Create Entry line at current price
    CreateHorizontalLine("ENTRY", currentPrice, clrYellow, "Entry Price");

    // For Buy trades: SL below entry, TP and Partial above
    CreateHorizontalLine("SL", currentPrice - (100 * points), clrRed, "Stop Loss");
    CreateHorizontalLine("TP", currentPrice + (150 * points), clrGreen, "Take Profit");
    CreateHorizontalLine("PARTIAL", currentPrice + (100 * points), clrBlue, "Partial Take Profit");

    // Refresh the chart
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Creates a horizontal line with specified parameters              |
//+------------------------------------------------------------------+
void CreateHorizontalLine(string name, double price, color lineColor, string description)
{
    ObjectCreate(ChartID(), name, OBJ_HLINE, 0, 0, price);
    ObjectSetInteger(ChartID(), name, OBJPROP_COLOR, lineColor);
    ObjectSetInteger(ChartID(), name, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(ChartID(), name, OBJPROP_WIDTH, 1);
    ObjectSetInteger(ChartID(), name, OBJPROP_SELECTABLE, true);
    ObjectSetInteger(ChartID(), name, OBJPROP_SELECTED, true);
    ObjectSetInteger(ChartID(), name, OBJPROP_HIDDEN, false);
    ObjectSetInteger(ChartID(), name, OBJPROP_ZORDER, 0);
    ObjectSetString(ChartID(), name, OBJPROP_TEXT, description);
}