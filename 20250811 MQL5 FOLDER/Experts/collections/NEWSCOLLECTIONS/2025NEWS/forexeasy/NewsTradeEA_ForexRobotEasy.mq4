
// Program: News Trade EA MT4
// Developer's Site: forexroboteasy.com
// Developer: Forex Robot Easy Team

// Include necessary libraries
#include <Trade\Trade.mqh>
#include <Timeseries\Timeseries.mqh>
#include <Calendar\Calendar.mqh>

// Define constants
#define SYMBOL_GBPUSD 'GBPUSD'
#define SYMBOL_EURGBP 'EURGBP'
#define SYMBOL_GBPJPY 'GBPJPY'
#define SYMBOL_GBPCAD 'GBPCAD'
#define SYMBOL_GBPAUD 'GBPAUD'
#define SYMBOL_GBPCHF 'GBPCHF'

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
CCalendar calendar;

// Initialize trading object
CTrade trade;

// Initialize timeseries object
CTimeseries series;

// Initialize trading function
void tradeGBP()
{
    // Check if GBP pairs are available for trading
    if (trade.SymbolInfoDouble(SYMBOL_GBPUSD, SYMBOL_ASK) == 0 ||
        trade.SymbolInfoDouble(SYMBOL_EURGBP, SYMBOL_ASK) == 0 ||
        trade.SymbolInfoDouble(SYMBOL_GBPJPY, SYMBOL_ASK) == 0 ||
        trade.SymbolInfoDouble(SYMBOL_GBPCAD, SYMBOL_ASK) == 0 ||
        trade.SymbolInfoDouble(SYMBOL_GBPAUD, SYMBOL_ASK) == 0 ||
        trade.SymbolInfoDouble(SYMBOL_GBPCHF, SYMBOL_ASK) == 0)
    {
        Print('GBP pairs are not available for trading.');
        return;
    }

    // Get economic news for GBP pairs
    CCalendarEvent event = calendar.GetNextEvent(SYMBOL_GBPUSD, PERIOD_D1, true);
    
    // Check if there is any news scheduled
    if (event.Time == 0)
    {
        Print('No news scheduled for GBP pairs.');
        return;
    }

    // Check if news is released
    if (event.Time > series.TimeCurrent())
    {
        Print('Waiting for news release...');
        return;
    }

    // Determine trading direction based on news impact
    ENUM_ORDER_TYPE direction = event.Importance > 2 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

    // Place market order based on trading mode
    if (mode == SEMI_AUTOMATIC)
    {
        // Prompt user to confirm trade
        Print('News released! Would you like to place a trade?');

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
    Print('Enter 'Y' to place a trade or 'N' to skip.');

    // Wait for user input
    string input;
    while (true)
    {
        input = GetStringFromTerminal();
        if (input == 'Y' || input == 'y')
            return true;
        else if (input == 'N' || input == 'n')
            return false;
        else
            Print('Invalid input. Try again.');
    }
}

// Get string input from terminal
string GetStringFromTerminal()
{
    // Initialize buffer
    string buffer = '';

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
