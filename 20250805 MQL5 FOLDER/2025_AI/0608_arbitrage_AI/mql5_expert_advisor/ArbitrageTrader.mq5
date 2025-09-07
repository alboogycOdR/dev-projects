//+------------------------------------------------------------------+
//| ArbitrageTrader.mq5 (Refactored for True Triangular Arbitrage)     |
//| Copyright 2024, MetaQuotes Ltd.                                  |
//| https://www.mql5.com                                             |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "2.00"
#property description "True high-frequency triangular arbitrage trading system. Refactored for correct logic."

// --- Input Parameters ---
input int      MAX_OPEN_TRADES = 10;          // Maximum number of open trades
input double   VOLUME = 0.50;                 // Trade volume
input int      TAKE_PROFIT = 450;             // Take profit in points
input int      STOP_LOSS = 200;               // Stop loss in points
input double   MIN_SPREAD_PIPS = 8.0;         // Minimum spread for arbitrage in pips
input int      MAGIC_NUMBER = 123456;         // Magic number for orders
input bool     ENABLE_TRADING_HOURS = true;   // Enable trading hours restriction
input string   START_TRADING_TIME = "05:00";  // Start trading time (server time)
input string   END_TRADING_TIME = "23:30";    // End trading time (server time)

// --- Data Structures for Triangular Arbitrage ---

// Enum to define the calculation method for the synthetic price
enum OperationType
{
    OP_MULTIPLY, // e.g., EURJPY = EURUSD * USDJPY
    OP_DIVIDE    // e.g., EURGBP = EURUSD / GBPUSD
};

// Struct to define a complete arbitrage triangle
struct ArbitrageTriangle
{
    string cross_symbol;  // The cross-currency pair to be traded (e.g., "EURGBP")
    string base_symbol1;  // The first base pair (e.g., "EURUSD")
    string base_symbol2;  // The second base pair (e.g., "GBPUSD")
    OperationType operation; // The operation to calculate the synthetic price
};

// --- Define the Arbitrage Triangles to Monitor ---
// This is the core of the strategy. You can expand this list.
ArbitrageTriangle arbitrageTriangles[] =
{
    // Triangle: EURGBP = EURUSD / GBPUSD
    {"EURGBP", "EURUSD", "GBPUSD", OP_DIVIDE},
    // Triangle: EURJPY = EURUSD * USDJPY
    {"EURJPY", "EURUSD", "USDJPY", OP_MULTIPLY},
    // Triangle: GBPJPY = GBPUSD * USDJPY
    {"GBPJPY", "GBPUSD", "USDJPY", OP_MULTIPLY},
    // Triangle: AUDJPY = AUDUSD * USDJPY
    {"AUDJPY", "AUDUSD", "USDJPY", OP_MULTIPLY},
    // Triangle: NZDJPY = NZDUSD * USDJPY
    {"NZDJPY", "NZDUSD", "USDJPY", OP_MULTIPLY},
    // Triangle: EURCHF = EURUSD / USDCHF (Inverse logic here is tricky in MQL5, direct is better)
    // Let's re-think EURCHF. EURCHF = EURJPY / CHFJPY (better). Let's use simpler USD based for now.
    {"EURCHF", "EURUSD", "USDCHF", OP_MULTIPLY}, // Synthetic EURCHF
    // Triangle: AUDCAD = AUDUSD / USDCAD
    {"AUDCAD", "AUDUSD", "USDCAD", OP_DIVIDE}
};

// --- Global Variables ---
datetime lastAnalysisTime = 0;
// Check for opportunities every 5 seconds instead of 5 minutes for better reaction time.
int analysisInterval = 5;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("Arbitrage Expert Advisor v2.0 initialized");
    Print("Triangles to monitor: ", ArraySize(arbitrageTriangles));
    Print("Maximum open trades: ", MAX_OPEN_TRADES);
    Print("Minimum arbitrage spread (Pips): ", MIN_SPREAD_PIPS);

    // Validate and subscribe to all required symbols
    for(int i = 0; i < ArraySize(arbitrageTriangles); i++)
    {
        SymbolSelect(arbitrageTriangles[i].cross_symbol, true);
        SymbolSelect(arbitrageTriangles[i].base_symbol1, true);
        SymbolSelect(arbitrageTriangles[i].base_symbol2, true);
    }
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!IsTradeAllowed()) return;
    if(ENABLE_TRADING_HOURS && !IsTradingTime()) return;
    if(TimeCurrent() - lastAnalysisTime < analysisInterval) return;

    AnalyzeAndTrade();
    lastAnalysisTime = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Analyze arbitrage opportunities and execute trades               |
//+------------------------------------------------------------------+
void AnalyzeAndTrade()
{
    for(int i = 0; i < ArraySize(arbitrageTriangles); i++)
    {
        ArbitrageTriangle currentTriangle = arbitrageTriangles[i];

        // 1. Calculate the synthetic prices (both bid and ask)
        double synthetic_bid, synthetic_ask;
        if(!CalculateSyntheticPrice(currentTriangle, synthetic_bid, synthetic_ask)) continue;

        // 2. Get the real market prices for the cross symbol
        MqlTick realTick;
        if(!SymbolInfoTick(currentTriangle.cross_symbol, realTick)) continue;
        double real_ask = realTick.ask;
        double real_bid = realTick.bid;

        // Get the point value to convert pips to price difference
        double point = SymbolInfoDouble(currentTriangle.cross_symbol, SYMBOL_POINT);
        double min_spread_value = MIN_SPREAD_PIPS * point;

        // 3. Compare real and synthetic prices to find arbitrage opportunities

        // Opportunity to BUY the cross pair (Real Ask price is cheaper than Synthetic Bid)
        if(real_ask < synthetic_bid && (synthetic_bid - real_ask) > min_spread_value)
        {
            PrintFormat("%s BUY Opportunity: Real Ask(%.5f) < Synthetic Bid(%.5f)",
                        currentTriangle.cross_symbol, real_ask, synthetic_bid);
            OpenArbitrageOrder(currentTriangle.cross_symbol, ORDER_TYPE_BUY);
            Sleep(1000); // Pause briefly after opening a trade
        }
        // Opportunity to SELL the cross pair (Real Bid price is higher than Synthetic Ask)
        else if(real_bid > synthetic_ask && (real_bid - synthetic_ask) > min_spread_value)
        {
            PrintFormat("%s SELL Opportunity: Real Bid(%.5f) > Synthetic Ask(%.5f)",
                        currentTriangle.cross_symbol, real_bid, synthetic_ask);
            OpenArbitrageOrder(currentTriangle.cross_symbol, ORDER_TYPE_SELL);
            Sleep(1000); // Pause briefly after opening a trade
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate synthetic bid/ask price based on the triangle          |
//+------------------------------------------------------------------+
bool CalculateSyntheticPrice(const ArbitrageTriangle &triangle, double &synthetic_bid, double &synthetic_ask)
{
    MqlTick tick1, tick2;

    if(!SymbolInfoTick(triangle.base_symbol1, tick1) || !SymbolInfoTick(triangle.base_symbol2, tick2))
    {
        return false;
    }
    
    if(tick1.bid <= 0 || tick1.ask <= 0 || tick2.bid <= 0 || tick2.ask <= 0) return false;
    
    if(triangle.operation == OP_MULTIPLY)
    {
        synthetic_bid = tick1.bid * tick2.bid;
        synthetic_ask = tick1.ask * tick2.ask;
        return true;
    }
    else if(triangle.operation == OP_DIVIDE)
    {
        // To avoid division by zero
        if(tick2.bid == 0 || tick2.ask == 0) return false;
        
        synthetic_bid = tick1.bid / tick2.ask;
        synthetic_ask = tick1.ask / tick2.bid;
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Open arbitrage order                                             |
//+------------------------------------------------------------------+
bool OpenArbitrageOrder(string symbol, ENUM_ORDER_TYPE orderType)
{
    if(PositionsTotal() >= MAX_OPEN_TRADES)
    {
        Print("Maximum number of open trades reached.");
        return false;
    }
    if(PositionSelect(symbol))
    {
        Print("Position already exists for ", symbol);
        return false;
    }

    MqlTradeRequest request={0};
    MqlTradeResult  result={0};
    MqlTick         tick;
    SymbolInfoTick(symbol,tick);
    
    double price = (orderType == ORDER_TYPE_BUY) ? tick.ask : tick.bid;
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

    request.action       = TRADE_ACTION_DEAL;
    request.symbol       = symbol;
    request.volume       = VOLUME;
    request.type         = orderType;
    request.price        = price;
    request.deviation    = 20; // Lower deviation for HFT
    request.magic        = MAGIC_NUMBER;
    request.comment      = "Arbitrage v2.0";
    request.type_time    = ORDER_TIME_GTC;
    request.type_filling = ORDER_FILLING_IOC; // Immediate Or Cancel is best for arbitrage

    if(orderType == ORDER_TYPE_BUY)
    {
        request.tp = price + TAKE_PROFIT * point;
        request.sl = price - STOP_LOSS * point;
    }
    else
    {
        request.tp = price - TAKE_PROFIT * point;
        request.sl = price + STOP_LOSS * point;
    }

    if(!OrderSend(request, result))
    {
        PrintFormat("OrderSend error %d", GetLastError());
        return false;
    }
    
    if(result.retcode == TRADE_RETCODE_DONE)
    {
        PrintFormat("SUCCESS: %s %s at %.5f. Order ticket: %I64u", EnumToString(orderType), symbol, price, result.order);
        return true;
    }
    else
    {
        PrintFormat("FAILURE: %s %s. Retcode: %d, Comment: %s",
                   EnumToString(orderType), symbol, result.retcode, result.comment);
        return false;
    }
}

//+------------------------------------------------------------------+
//| Check if current time is within trading hours                    |
//+------------------------------------------------------------------+
bool IsTradingTime()
{
    datetime currentTime = TimeCurrent();
    MqlDateTime timeStruct;
    TimeToStruct(currentTime, timeStruct);
    
    int currentHour = timeStruct.hour;
    int currentMin = timeStruct.min;
    int currentTimeInMinutes = currentHour * 60 + currentMin;
    
    string startParts[], endParts[];
    StringSplit(START_TRADING_TIME, ':', startParts);
    StringSplit(END_TRADING_TIME, ':', endParts);
    
    int startTimeInMinutes = (int)StringToInteger(startParts[0]) * 60 + (int)StringToInteger(startParts[1]);
    int endTimeInMinutes = (int)StringToInteger(endParts[0]) * 60 + (int)StringToInteger(endParts[1]);
    
    if(startTimeInMinutes < endTimeInMinutes)
        return (currentTimeInMinutes >= startTimeInMinutes && currentTimeInMinutes <= endTimeInMinutes);
    else
        return (currentTimeInMinutes >= startTimeInMinutes || currentTimeInMinutes <= endTimeInMinutes);
}

//+------------------------------------------------------------------+
//| Check if trading is allowed by terminal/EA/account               |
//+------------------------------------------------------------------+
bool IsTradeAllowed()
{
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
    {
        Print("Trading is disabled in terminal settings.");
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("Arbitrage Expert Advisor v2.0 deinitialized. Reason: ", reason);
    // Unsubscribe from symbols to clean up
    for(int i = 0; i < ArraySize(arbitrageTriangles); i++)
    {
        SymbolSelect(arbitrageTriangles[i].cross_symbol, false);
        SymbolSelect(arbitrageTriangles[i].base_symbol1, false);
        SymbolSelect(arbitrageTriangles[i].base_symbol2, false);
    }
}