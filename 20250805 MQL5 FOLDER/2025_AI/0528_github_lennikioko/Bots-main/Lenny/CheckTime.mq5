//+------------------------------------------------------------------+
//|                                                  CheckTime.mq5   |
//|                                                  Copyright 2025  |
//|                                     https://www.yourwebsite.com  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      "https://www.yourwebsite.com"
#property version   "1.00"
#property strict

#include <Helpers\TextDisplay.mqh>


//+------------------------------------------------------------------+
//| Expert initialization function                                      |
//+------------------------------------------------------------------+
int OnInit() {
    EventSetTimer(5);
    clearTextDisplay();
    Print("CheckTime initialized successfully");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    // Cleanup code if needed
    EventKillTimer();
    Print("CheckTime deinitialized.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTimer() {
    datetime currentTime = TimeCurrent();
    string timeStr = TimeToString(currentTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS);
    Print("Current time: ", timeStr);
    clearTextDisplay();
    addTextOnScreen(timeStr, clrWhite);
}
