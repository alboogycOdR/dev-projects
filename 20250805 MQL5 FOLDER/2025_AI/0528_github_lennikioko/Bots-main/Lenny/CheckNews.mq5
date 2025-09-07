//+------------------------------------------------------------------+
//|                                                  CheckNews.mq5   |
//|                                                  Copyright 2025  |
//|                                     https://www.yourwebsite.com  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      "https://www.yourwebsite.com"
#property version   "1.00"
#property strict

#include <Helpers\TextDisplay.mqh>


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    EventSetTimer(5);
    clearTextDisplay();
    Print("CheckNews initialized successfully");
    GetRelevantNews();
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    // Cleanup code if needed
    EventKillTimer();
    Print("CheckNews deinitialized.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTimer() {
    datetime currentTime = TimeCurrent();
    string timeStr = TimeToString(currentTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS);
    Print("Current time: ", timeStr);
    clearTextDisplay();
    addTextOnScreen(timeStr, clrWhite);
    GetRelevantNews();
}

//+------------------------------------------------------------------+
//| Functions to check for news events                               |
//+------------------------------------------------------------------+
void GetRelevantNews() {
    string code = "US";
    MqlCalendarValue values[];
    datetime currentTime = TimeCurrent();
    datetime tomorrow = currentTime + 24 * 3600; // Add 24 hours
    datetime dateFrom = TimeCurrent();
    datetime dateTo = dateFrom + 36 * 3600; // 36 hours ahead

    if(CalendarValueHistory(values, dateFrom, dateTo, code)) {
        for(int i = 0; i < ArraySize(values); i++) {
            MqlCalendarEvent event;
            ulong eventId = values[i].event_id;

            if(CalendarEventById(eventId, event)) {
                datetime eventTime = values[i].time;
                if(event.importance == CALENDAR_IMPORTANCE_HIGH || event.type == CALENDAR_TYPE_HOLIDAY) {
                    Print("Time: " + eventTime +
                        " | Event ID: " + IntegerToString(eventId) +
                        " | Name: " + event.name +
                        " | Importance: " + EnumToString((ENUM_CALENDAR_EVENT_IMPORTANCE)event.importance) +
                        " | Type: " + EnumToString((ENUM_CALENDAR_EVENT_TYPE)event.type));
                }

                // Add event details to the screen
                if(event.type == CALENDAR_TYPE_HOLIDAY &&
                   TimeToString(eventTime, TIME_DATE) == TimeToString(currentTime, TIME_DATE)) {
                    Print("Bank Holiday today");
                    addTextOnScreen("Bank Holiday today", clrWhite);
                }

                if(event.name == "Nonfarm Payrolls" &&
                   TimeToString(eventTime, TIME_DATE) == TimeToString(tomorrow, TIME_DATE)) {
                    Print("NFP tomorrow");
                    addTextOnScreen("NFP tomorrow", clrWhite);
                }

                if(StringFind(event.name, "CPI") >= 0 &&
                   TimeToString(eventTime, TIME_DATE) == TimeToString(currentTime, TIME_DATE)) {
                    Print("CPI today");
                    addTextOnScreen("CPI today", clrWhite);
                }

            } else {
                Print("Error retrieving event by ID: " + IntegerToString(GetLastError()));
            }
        }
    } else {
        Print("Error retrieving news values: " + IntegerToString(GetLastError()));
    }
}

//+------------------------------------------------------------------+
