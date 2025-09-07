
// Program: News Trade EA MT4
// Developer's Site: forexroboteasy.com
// Developer: Forex Robot Easy Team
/*
This code is an Expert Advisor (EA) for MetaTrader 4 (MT4) developed by the Forex Robot Easy Team. It is designed to trade news events specifically for GBP pairs. The EA includes functions to check for the availability of GBP pairs, retrieve economic news for GBP pairs from an economic calendar, determine the trading direction based on the news impact, and place market orders automatically or with user confirmation.

Trade GBP pairs: The EA checks if GBP pairs (GBPUSD, EURGBP, GBPJPY, GBPCAD, GBPAUD, GBPCHF) are available for trading.
Economic calendar integration: The EA uses the CCalendar class to retrieve the next economic event for GBP pairs on the daily timeframe.
Trading modes: The EA supports two trading modes - SEMI_AUTOMATIC and FULLY_AUTOMATIC.
User confirmation: In SEMI_AUTOMATIC mode, the EA prompts the user to confirm the trade before placing market orders.
Customizable parameters: The EA allows customization of trading parameters such as lot size, stop loss, and take profit.


Include the necessary libraries: The EA requires the Trade, Timeseries, and Calendar libraries.
Define constants: SYMBOL_GBPUSD, SYMBOL_EURGBP, SYMBOL_GBPJPY, SYMBOL_GBPCAD, SYMBOL_GBPAUD, and SYMBOL_GBPCHF are defined as constants representing the GBP pairs.
Define trading modes: The TradingMode enum defines two modes - SEMI_AUTOMATIC and FULLY_AUTOMATIC. Specify the desired mode using the 'mode' input variable.
Define trading parameters: Specify the desired lot size, stop loss, and take profit using the 'lotSize', 'stopLoss', and 'takeProfit' input variables.
Initialize objects: Initialize the CCalendar, CTrade, and CTimeseries objects for economic calendar, trading, and timeseries functionalities respectively.
Implement the tradeGBP() function: This function checks for the availability of GBP pairs, retrieves the next economic event for GBP pairs, determines the trading direction based on the news impact, and places market orders.
Implement the OnTick() function: This function is the entry point of the program and calls the tradeGBP() function.
Implement the GetUserConfirmation() function: This function prompts the user for input to confirm or skip the trade.
Implement the GetStringFromTerminal() function: This function reads a string input from the terminal.

*/
// Include necessary libraries
#include <Trade\Trade.mqh>
#include <Timeseries.mqh>
#include <Calendar.mqh>
#include <MT4Bridge/MT4MarketInfo.mqh>
#include <MT4Bridge/MT4Account.mqh>
#include <MT4Bridge/MT4Orders.mqh>
#include <mt4objects_1.mqh>
#define HistoryTotal OrdersHistoryTotal
#include <errordescription.mqh>
// Define constants
#define SYMBOL_GBPUSD "GBPUSD"
#define SYMBOL_EURGBP "EURGBP"
#define SYMBOL_GBPJPY "GBPJPY"
#define SYMBOL_GBPCAD "GBPCAD"
#define SYMBOL_GBPAUD "GBPAUD"
#define SYMBOL_GBPCHF "GBPCHF"

// Define trading modes
enum TradingMode
{
    SEMI_AUTOMATIC,
    FULLY_AUTOMATIC
};

// Define trading parameters
input TradingMode mode = FULLY_AUTOMATIC;
input double lotSize = 0.1;
input int stopLoss = 50;
input int takeProfit = 100;

// Define economic calendar
CALENDAR calendar;

// Initialize trading object
CTrade trade;

// Initialize timeseries object
//CTimeseries series;

// Initialize trading function
void tradeGBP()
{
    // Check if GBP pairs are available for trading
    if (SymbolInfoDouble(SYMBOL_GBPUSD, SYMBOL_ASK) == 0 ||
        SymbolInfoDouble(SYMBOL_EURGBP, SYMBOL_ASK) == 0 ||
        SymbolInfoDouble(SYMBOL_GBPJPY, SYMBOL_ASK) == 0 ||
        SymbolInfoDouble(SYMBOL_GBPCAD, SYMBOL_ASK) == 0 ||
        SymbolInfoDouble(SYMBOL_GBPAUD, SYMBOL_ASK) == 0 ||
        SymbolInfoDouble(SYMBOL_GBPCHF, SYMBOL_ASK) == 0)
    {
        Print("GBP pairs are not available for trading.");
        return;
    }

    // Get economic news for GBP pairs
    CCalendarEvent event = calendar.GetNextEvent(SYMBOL_GBPUSD, PERIOD_D1, true);
    
    // Check if there is any news scheduled
    if (event.Time == 0)
    {
        Print("No news scheduled for GBP pairs.");
        return;
    }

    // Check if news is released
    if (event.Time > /*series.*/TimeCurrent())
    {
        Print("Waiting for news release...");
        return;
    }

    // Determine trading direction based on news impact
    ENUM_ORDER_TYPE direction = event.Importance > 2 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

    // Place market order based on trading mode
    if (mode == SEMI_AUTOMATIC)
    {
        // Prompt user to confirm trade
        Print("News released! Would you like to place a trade?");

        // Wait for user input
        if (GetUserConfirmation())
        {
            trade.PlaceMarketOrder(direction, SYMBOL_GBPUSD, lotSize, 0, stopLoss, takeProfit);
            trade.PlaceMarketOrder(direction, SYMBOL_EURGBP, lotSize, 0, stopLoss, takeProfit);
            trade.PlaceMarketOrder(direction, SYMBOL_GBPJPY, lotSize, 0, stopLoss, takeProfit);
            trade.PlaceMarketOrder(direction, SYMBOL_GBPCAD, lotSize, 0, stopLoss, takeProfit);
            trade.PlaceMarketOrder(direction, SYMBOL_GBPAUD, lotSize, 0, stopLoss, takeProfit);
            trade.PlaceMarketOrder(direction, SYMBOL_GBPCHF, lotSize, 0, stopLoss, takeProfit);
        }
    }
    else if (mode == FULLY_AUTOMATIC)
    {
        // Place market order automatically
        trade.PlaceMarketOrder(direction, SYMBOL_GBPUSD, lotSize, 0, stopLoss, takeProfit);
        trade.PlaceMarketOrder(direction, SYMBOL_EURGBP, lotSize, 0, stopLoss, takeProfit);
        trade.PlaceMarketOrder(direction, SYMBOL_GBPJPY, lotSize, 0, stopLoss, takeProfit);
        trade.PlaceMarketOrder(direction, SYMBOL_GBPCAD, lotSize, 0, stopLoss, takeProfit);
        trade.PlaceMarketOrder(direction, SYMBOL_GBPAUD, lotSize, 0, stopLoss, takeProfit);
        trade.PlaceMarketOrder(direction, SYMBOL_GBPCHF, lotSize, 0, stopLoss, takeProfit);
    }
}

// Entry point of the program
void OnTick()
{
    // Perform GBP trading
    tradeGBP();
}

// Check if user wants to place a trade
bool GetUserConfirmation()
{
    // Prompt user for input
    Print("Enter 'Y' to place a trade or 'N' to skip.");

    // Wait for user input
    string input;
    while (true)
    {
        input = GetStringFromTerminal();
        if (input == "Y" || input == "y")
            return true;
        else if (input == "N" || input == "n")
            return false;
        else
            Print("Invalid input. Try again.");
    }
}

// Get string input from terminal
string GetStringFromTerminal()
{
    // Initialize buffer
    string buffer = "";

    // Read characters from terminal
    while (!IsStopped())
    {
        char ch = CharToLowerCase(GetChar());

        // Append character to buffer
        if (ch == CHAR_BACKSPACE)
        {
            if (StringLen(buffer) > 0)
                buffer = StringSubstr(buffer, 0, StringLen(buffer) - 1);
        }
        else if (ch == CHAR_ENTER)
        {
            break;
        }
        else if (CharIsPrintable(ch))
        {
            buffer += ch;
        }

        Sleep(10);
    }

    return buffer;
}


/*

Forex Robot Easy presents the News Trade EA MT4, an Expert Advisor specifically designed to trade news events for GBP pairs on MetaTrader 4. With its integration of an economic calendar and customizable trading parameters, this EA provides a reliable and automated solution for trading news events.

The News Trade EA MT4 allows traders to take advantage of market volatility during news releases by automatically placing market orders based on the trading mode selected. In SEMI_AUTOMATIC mode, the EA prompts the user for confirmation before placing trades, ensuring full control over the trading decisions. In FULLY_AUTOMATIC mode, the EA automatically executes trades without any user intervention.

Key Features:

Trade GBP pairs: The EA supports trading of popular GBP pairs including GBPUSD, EURGBP, GBPJPY, GBPCAD, GBPAUD, and GBPCHF.
Economic calendar integration: The EA retrieves the next economic news event for GBP pairs on the daily timeframe, allowing traders to stay updated on market-moving events.
Customizable parameters: Traders can customize the lot size, stop loss, and take profit according to their risk appetite and trading strategy.
User confirmation: In SEMI_AUTOMATIC mode, the EA prompts the user to confirm trades, ensuring complete control over trading decisions.
Easy to use: The EA is designed to be user-friendly and can be easily integrated into existing trading setups.
Please note that ForexRobotEasy is not the official developer of this product. We provide this sample code to showcase the functionality of the News Trade EA MT4. To find the official developer of this product and access detailed reviews and trading results, please visit Forex Robot Easy - News Trade EA MT4 Review. For additional support and updates, we recommend using the MQL5 platform.
*/