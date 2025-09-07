//+------------------------------------------------------------------+
//|                                                DeleteAllObjects.mq5 |
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
    // Delete all objects from the current chart
    ObjectsDeleteAll(ChartID());

    // Refresh the chart to show the changes
    ChartRedraw();

    // Notify user
    Print("All objects have been deleted from the chart.");
}