//+------------------------------------------------------------------+
//| Function to draw vertical line at local time 13:00              |
//+------------------------------------------------------------------+
void DrawVerticalLineAtLocalTime()
{
    // Your local timezone offset from GMT (GMT+2 = +2)
    int localGMTOffset = 2;
    
    // Broker timezone offset from GMT (GMT+3 = +3) 
    int brokerGMTOffset = 3;
    
    // Calculate the difference between broker time and local time
    int timeDifference = brokerGMTOffset - localGMTOffset; // +1 hour
    
    // Get current broker time
    datetime brokerTime = TimeCurrent();
    
    // Get today's date in broker timezone
    MqlDateTime brokerDateTime;
    TimeToStruct(brokerTime, brokerDateTime);
    
    // Create target time: today at 13:00 local time
    // Convert to broker time by adding the time difference
    int targetHour = 13 + timeDifference; // 13 + 1 = 14 (broker time)
    
    // Handle hour overflow (if target hour >= 24, move to next day)
    int targetDay = brokerDateTime.day;
    int targetMonth = brokerDateTime.mon;
    int targetYear = brokerDateTime.year;
    
    if(targetHour >= 24)
    {
        targetHour -= 24;
        targetDay += 1;
        // You might want to add month/year overflow handling here if needed
    }
    
    // Create the target datetime in broker timezone
    datetime targetTime = StructToTime({targetYear, targetMonth, targetDay, targetHour, 0, 0});
    
    // Create unique object name with timestamp
    string objectName = "LocalTime_13_00_" + IntegerToString(targetTime);
    
    // Delete existing line if it exists
    ObjectDelete(0, objectName);
    
    // Create vertical line
    if(ObjectCreate(0, objectName, OBJ_VLINE, 0, targetTime, 0))
    {
        // Set line properties
        ObjectSetInteger(0, objectName, OBJPROP_COLOR, clrRed);
        ObjectSetInteger(0, objectName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, objectName, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, objectName, OBJPROP_BACK, false);
        ObjectSetInteger(0, objectName, OBJPROP_SELECTABLE, true);
        ObjectSetInteger(0, objectName, OBJPROP_SELECTED, false);
        ObjectSetString(0, objectName, OBJPROP_TEXT, "Local Time 13:00");
        
        Print("Vertical line drawn at broker time: ", TimeToString(targetTime, TIME_DATE|TIME_MINUTES));
        Print("This corresponds to local time 13:00");
    }
    else
    {
        Print("Failed to create vertical line. Error: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Alternative function with automatic timezone detection           |
//+------------------------------------------------------------------+
void DrawVerticalLineAtLocalTimeAuto()
{
    // Get current times
    datetime brokerTime = TimeCurrent();
    datetime localTime = TimeLocal();
    
    // Calculate timezone difference in seconds
    int timeDifferenceSeconds = (int)(brokerTime - localTime);
    
    // Convert to hours (rounded to nearest hour)
    int timeDifferenceHours = (int)MathRound(timeDifferenceSeconds / 3600.0);
    
    Print("Detected time difference: ", timeDifferenceHours, " hours");
    
    // Get today's date in local time
    MqlDateTime localDateTime;
    TimeToStruct(localTime, localDateTime);
    
    // Create target time: today at 13:00 local time
    datetime localTargetTime = StructToTime({localDateTime.year, localDateTime.mon, localDateTime.day, 13, 0, 0});
    
    // Convert to broker time
    datetime brokerTargetTime = localTargetTime + timeDifferenceSeconds;
    
    // Create unique object name
    string objectName = "AutoLocalTime_13_00_" + IntegerToString(brokerTargetTime);
    
    // Delete existing line if it exists
    ObjectDelete(0, objectName);
    
    // Create vertical line
    if(ObjectCreate(0, objectName, OBJ_VLINE, 0, brokerTargetTime, 0))
    {
        // Set line properties
        ObjectSetInteger(0, objectName, OBJPROP_COLOR, clrBlue);
        ObjectSetInteger(0, objectName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, objectName, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, objectName, OBJPROP_BACK, false);
        ObjectSetInteger(0, objectName, OBJPROP_SELECTABLE, true);
        ObjectSetInteger(0, objectName, OBJPROP_SELECTED, false);
        ObjectSetString(0, objectName, OBJPROP_TEXT, "Auto Local Time 13:00");
        
        Print("Auto vertical line drawn at broker time: ", TimeToString(brokerTargetTime, TIME_DATE|TIME_MINUTES));
        Print("Local target time was: ", TimeToString(localTargetTime, TIME_DATE|TIME_MINUTES));
    }
    else
    {
        Print("Failed to create auto vertical line. Error: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Example usage in OnInit() or OnTick()                           |
//+------------------------------------------------------------------+
void OnInit()
{
    // Method 1: Manual timezone specification
    DrawVerticalLineAtLocalTime();
    
    // Method 2: Automatic timezone detection
    DrawVerticalLineAtLocalTimeAuto();
}

//+------------------------------------------------------------------+
//| Function to draw line every day at 13:00 local time            |
//+------------------------------------------------------------------+
bool dailyLineDrawn = false;

void CheckAndDrawDailyLine()
{
    static datetime lastCheck = 0;
    datetime currentTime = TimeLocal();
    
    MqlDateTime dt;
    TimeToStruct(currentTime, dt);
    
    // Check if it's 13:00 local time and we haven't drawn today's line yet
    if(dt.hour == 13 && dt.min == 0 && !dailyLineDrawn)
    {
        DrawVerticalLineAtLocalTimeAuto();
        dailyLineDrawn = true;
    }
    
    // Reset flag at midnight
    if(dt.hour == 0 && dt.min == 0)
    {
        dailyLineDrawn = false;
    }
}