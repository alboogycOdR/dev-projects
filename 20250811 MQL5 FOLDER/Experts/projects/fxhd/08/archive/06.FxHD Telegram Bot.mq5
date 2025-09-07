//+------------------------------------------------------------------+
//|                                            FxHD Telegram Bot.mq5 |
//|                                    Copyright 2024, FxHD Academy. |
//|                            https://www.mql5.com/users/brendonren |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, FxHD Academy."
#property link      "https://www.mql5.com/users/brendonren"
#property version   "1.00"


//--- Include necessary libraries
#include <Trade\Trade.mqh>

//--- Input parameters
input string botToken = "6903673851:AAHM_CWmx7Pze0VPxqrLxCgYbBD7U_W9C88";      // Your Telegram bot token
input string chatID = "-1002346149118";          // Your Telegram chat ID
input string screenshotFilename = "screenshot_trade.jpg"; // Screenshot filename
input string reportScreenshotFilename = "report_screenshot.jpg"; // Report screenshot filename


//--- Global variables
CTrade trade;                            // Trading object




//--- Function to send a message to Telegram
//--- Function to send a message to Telegram
void SendTelegramMessage(string message)
{
    string url = "https://api.telegram.org/bot" + botToken + "/sendMessage";
    string headers = "Content-Type: application/x-www-form-urlencoded\r\n";
    string data = "chat_id=" + chatID + "&text=" + UrlEncode(message);

    char result[];
    string error;
    int timeout = 5000;

    int res = WebRequest("POST", url, headers, data, NULL, result, error, timeout);

    if (res == -1)
    {
        Print("Error in WebRequest: ", error);
    }
    else
    {
        string response = CharArrayToString(result);
        Print("Message sent successfully. Response: ", response);
    }
}

//--- Function to URL encode a string
string UrlEncode(string str)
{
    string result;
    for (int i = 0; i < StringLen(str); i++)
    {
        int c = StringGetCharacter(str, i);
        if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.' || c == '~')
        {
            result += CharToString(c);
        }
        else
        {
            result += "%" + StringFormat("%02X", c);
        }
    }
    return result;
}



//--- Function to take a screenshot and save it as a file
void TakeScreenshot(string filename)
{
    if (ChartScreenShot(0, filename, 1024, 768))
    {
        Print("Screenshot saved successfully as: ", filename);
    }
    else
    {
        Print("Failed to take screenshot.");
    }
}

//--- Function to send a screenshot to Telegram
void SendScreenshotToTelegram(string filename)
{
    // You need to handle file uploads manually; this part is just illustrative.
    // Typically, you would upload the file to a server or use a service that supports file uploads.
    // For now, we assume you have a method to send the file URL or manage it.
    
    string message = "Screenshot: " + filename;
    SendTelegramMessage(message);
}

//--- Function to send trade details to Telegram
void SendTradeDetails(double slPrice, double tpPrice)
{
    string tradeMessage = "New trade opened!\n"
                          "Stop Loss: " + DoubleToString(slPrice, _Digits) + "\n"
                          "Take Profit: " + DoubleToString(tpPrice, _Digits);
    SendTelegramMessage(tradeMessage);
    TakeScreenshot(screenshotFilename);
    SendScreenshotToTelegram(screenshotFilename);
}

//--- Function to send daily, weekly, or monthly report to Telegram
void SendReport(string timeframe)
{
    string reportMessage = "Report for " + timeframe + ":\n";
    double profit = 0.0;

    if (timeframe == "daily")
    {
        profit = AccountInfoDouble(ACCOUNT_PROFIT); // Adjust based on actual report logic
        reportMessage += "Today's Profit: " + DoubleToString(profit, 2);
    }
    else if (timeframe == "weekly")
    {
        profit = AccountInfoDouble(ACCOUNT_BALANCE) - AccountInfoDouble(ACCOUNT_CREDIT); // Example for weekly logic
        reportMessage += "This Week's Balance: " + DoubleToString(profit, 2);
    }
    else if (timeframe == "monthly")
    {
        profit = AccountInfoDouble(ACCOUNT_EQUITY); // Example for monthly logic
        reportMessage += "This Month's Equity: " + DoubleToString(profit, 2);
    }
    
    SendTelegramMessage(reportMessage);
    TakeScreenshot(reportScreenshotFilename);
    SendScreenshotToTelegram(reportScreenshotFilename);
}

//--- Initialization function
int OnInit()
{
    Print("Initializing the script...");
    // Initialization code here (e.g., setting up timers or other configurations)
    return INIT_SUCCEEDED;
}

//--- Function to handle new tick data
void OnTick()
{
    // Check for open positions and send trade details if applicable
    if (PositionSelect(_Symbol))
    {
        double slPrice = PositionGetDouble(POSITION_SL);
        double tpPrice = PositionGetDouble(POSITION_TP);
        SendTradeDetails(slPrice, tpPrice);
    }
}

//--- Function to handle daily report (triggered by some mechanism, e.g., timer or button)
void OnDailyReport()
{
    SendReport("daily");
}

//--- Function to handle weekly report (triggered by some mechanism, e.g., timer or button)
void OnWeeklyReport()
{
    SendReport("weekly");
}

//--- Function to handle monthly report (triggered by some mechanism, e.g., timer or button)
void OnMonthlyReport()
{
    SendReport("monthly");
}



//+------------------------------------------------------------------+
