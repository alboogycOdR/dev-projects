//+------------------------------------------------------------------+
//|                                         DeleteAllExceptPartial.mq5 |
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
    int totalObjects = ObjectsTotal(ChartID());
    int deletedCount = 0;

    // Iterate through all objects in reverse order
    for(int i = totalObjects - 1; i >= 0; i--)
    {
        // Get object name
        string objectName = ObjectName(ChartID(), i);
        string lowerName = objectName;
        StringToLower(lowerName);  // Convert to lowercase for case-insensitive comparison

        // Skip objects with "partial" in their name
        if(StringFind(lowerName, "partial") >= 0)
            continue;

        // Delete other objects
        if(ObjectDelete(ChartID(), objectName))
            deletedCount++;
    }

    // Refresh the chart to show the changes
    ChartRedraw();

    // Notify user
    Print("Deleted ", deletedCount, " objects from the chart (kept objects with 'partial' in name).");
}