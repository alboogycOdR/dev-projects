//+------------------------------------------------------------------+
//|               Advanced_EntryStrategy_DynamicPositioning.mq5      |
//|                                Copyright 2025, Shivam Shikhar    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Shivam Shikhar"
#property link      "https://www.instagram.com/artificialintelligencefacts?igsh=MXZ6"
#property version   "2.00"
#property strict

// Input parameters for indicators
input string VWAPSettings = "---VWAP Indicator Settings---";
input string VWAP_Name = "VWAP_UTC_Final"; // VWAP indicator name

input string EMASettings = "---EMA Indicator Settings---";
input int EMA_Period = 9; // EMA Period
input ENUM_MA_METHOD EMA_Method = MODE_EMA; // EMA Method
input ENUM_APPLIED_PRICE EMA_Applied_Price = PRICE_CLOSE; // Applied price

// Trade parameters
input double LotSize = 0.20; // Fixed lot size for trades

// Signal filter settings
input string SignalSettings = "---Signal Filter Settings---";
input int MinSecondsBetweenSignals = 60; // Minimum seconds between signals of same type
input double MinCrossoverDifference = 4.50; // Minimum difference between EMA and VWAP for valid signal

// Error handling settings
input string ErrorSettings = "---Error Handling Settings---";
input int MaxTradeRetries = 3; // Maximum number of trade retry attempts

// Global variables for indicator handles
int vwapHandle = INVALID_HANDLE; // Handle for VWAP indicator
int ema9Handle = INVALID_HANDLE;  // Handle for EMA9 indicator

// Arrays to store indicator values
double vwapBuffer[];
double ema9Buffer[];

// For logging
int fileHandle = INVALID_HANDLE;

// Trade state variables
bool inLongPosition = false;
bool inShortPosition = false;
bool tradePending = false;
string pendingTradeType = "";

// Signal time tracking
datetime lastBullishSignalTime = 0;
datetime lastBearishSignalTime = 0;

// Current market state
double currentVwap = 0.0;
double currentEma = 0.0;
double currentDiff = 0.0;
string currentMarketState = "NEUTRAL";

// Performance tracking
double totalProfit = 0.0;
int totalTrades = 0;
int successfulTrades = 0;
int failedTrades = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize the log file
    fileHandle = FileOpen("Advanced_EntryStrategy_DynamicPositioning.txt", FILE_WRITE|FILE_TXT);
    if(fileHandle == INVALID_HANDLE)
    {
        Print("Failed to open log file!");
        return(INIT_FAILED);
    }
    
    FileWrite(fileHandle, "=== Advanced Entry Strategy EA (Dynamic Positioning) ===");
    FileWrite(fileHandle, "Test started at: ", TimeToString(TimeCurrent()));
    FileWrite(fileHandle, "Minimum difference for valid entry: " + DoubleToString(MinCrossoverDifference, 2));
    FileWrite(fileHandle, "--- Strategy Logic ---");
    FileWrite(fileHandle, "- Continuously looking for new trade opportunities");
    FileWrite(fileHandle, "- Will close existing trades when opposite signals appear");
    FileWrite(fileHandle, "- Same direction signals will be ignored if already in position");
    FileWrite(fileHandle, "- Trade retry logic: Maximum " + IntegerToString(MaxTradeRetries) + " retry attempts");
    
    // Initialize VWAP indicator handle
    vwapHandle = iCustom(_Symbol, PERIOD_M5, VWAP_Name);
    if(vwapHandle == INVALID_HANDLE)
    {
        int error = GetLastError();
        string errorMsg = "Failed to create VWAP indicator handle! Error: " + IntegerToString(error);
        Print(errorMsg);
        FileWrite(fileHandle, errorMsg);
        return(INIT_FAILED);
    }
    
    // Initialize EMA indicator handle
    ema9Handle = iMA(_Symbol, PERIOD_M5, EMA_Period, 0, EMA_Method, EMA_Applied_Price);
    if(ema9Handle == INVALID_HANDLE)
    {
        int error = GetLastError();
        string errorMsg = "Failed to create EMA9 indicator handle! Error: " + IntegerToString(error);
        Print(errorMsg);
        FileWrite(fileHandle, errorMsg);
        return(INIT_FAILED);
    }
    
    // Initialize arrays for indicator values
    ArraySetAsSeries(vwapBuffer, true);
    ArraySetAsSeries(ema9Buffer, true);
    
    // Check for open positions at start
    CheckForOpenPositions();
    
    // Success message
    Print("Advanced Entry Strategy EA initialized successfully");
    FileWrite(fileHandle, "Both indicators initialized successfully");
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Check for any existing open positions                            |
//+------------------------------------------------------------------+
void CheckForOpenPositions()
{
    inLongPosition = false;
    inShortPosition = false;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0)
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
                long positionType = PositionGetInteger(POSITION_TYPE);
                
                if(positionType == POSITION_TYPE_BUY)
                {
                    inLongPosition = true;
                    Print("Found existing LONG position at startup");
                    FileWrite(fileHandle, "Detected existing LONG position at startup");
                }
                else if(positionType == POSITION_TYPE_SELL)
                {
                    inShortPosition = true;
                    Print("Found existing SHORT position at startup");
                    FileWrite(fileHandle, "Detected existing SHORT position at startup");
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Get current candle data
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copied = CopyRates(_Symbol, PERIOD_M5, 0, 5, rates);
    
    if(copied < 5)
    {
        Print("Failed to copy price data, only got ", copied, " candles");
        return;
    }
    
    // Copy indicator values
    int vwapCopied = CopyBuffer(vwapHandle, 0, 0, 5, vwapBuffer);
    int emaCopied = CopyBuffer(ema9Handle, 0, 0, 5, ema9Buffer);
    
    if(vwapCopied < 5 || emaCopied < 5)
    {
        Print("Not enough indicator data copied. VWAP: ", vwapCopied, ", EMA: ", emaCopied);
        return;
    }
    
    // Current values
    currentVwap = vwapBuffer[0];
    currentEma = ema9Buffer[0];
    currentDiff = currentEma - currentVwap;
    
    // Previous values
    double prevVwap = vwapBuffer[1];
    double prevEma = ema9Buffer[1];
    double prevDiff = prevEma - prevVwap;
    
    // Update market state
    if(currentDiff > 0)
    {
        currentMarketState = "BULLISH";
    }
    else if(currentDiff < 0)
    {
        currentMarketState = "BEARISH";
    }
    else
    {
        currentMarketState = "NEUTRAL";
    }
    
    // Check for new candle
    static datetime lastCandleTime = 0;
    bool isNewCandle = (rates[0].time != lastCandleTime);
    
    if(isNewCandle)
    {
        lastCandleTime = rates[0].time;
        
        // Log current values on each new candle
        string statusText = currentMarketState;
        string message = "Time: " + TimeToString(rates[0].time) + 
                         " | VWAP: " + DoubleToString(currentVwap, 2) + 
                         " | EMA9: " + DoubleToString(currentEma, 2) + 
                         " | Diff: " + DoubleToString(currentDiff, 2) + 
                         " | Status: " + statusText;
        
        Print(message);
        FileWrite(fileHandle, message);
    }
    
    // Current time
    datetime currentTime = TimeCurrent();
    
    // First, check for crossovers which are the primary entry signals
    bool bullishCrossover = (prevDiff <= 0 && currentDiff > 0);
    bool bearishCrossover = (prevDiff >= 0 && currentDiff < 0);
    
    // Process bullish crossover
    if(bullishCrossover && (currentTime >= lastBullishSignalTime + MinSecondsBetweenSignals))
    {
        lastBullishSignalTime = currentTime;
        
        string crossMsg = "BULLISH CROSSOVER at " + TimeToString(rates[0].time) + 
                        " | EMA9 crossed above VWAP | EMA9: " + DoubleToString(currentEma, 2) + 
                        " | VWAP: " + DoubleToString(currentVwap, 2) +
                        " | Diff: " + DoubleToString(currentDiff, 2);
        
        Print(">>> " + crossMsg + " <<<");
        FileWrite(fileHandle, crossMsg);
        
        // If in SHORT position, close it
        if(inShortPosition)
        {
            string closeMsg = "Closing SHORT position due to BULLISH crossover";
            Print("!!! " + closeMsg + " !!!");
            FileWrite(fileHandle, closeMsg);
            CloseAllPositions();
            
            // Flag for a pending LONG entry
            tradePending = true;
            pendingTradeType = "LONG";
        }
        // If no position, prepare for LONG entry
        else if(!inLongPosition)
        {
            tradePending = true;
            pendingTradeType = "LONG";
        }
        // If already in LONG position, maintain it
        else
        {
            string noActionMsg = "Already in LONG position, no action taken";
            Print("--- " + noActionMsg + " ---");
            FileWrite(fileHandle, noActionMsg);
        }
    }
    
    // Process bearish crossover
    if(bearishCrossover && (currentTime >= lastBearishSignalTime + MinSecondsBetweenSignals))
    {
        lastBearishSignalTime = currentTime;
        
        string crossMsg = "BEARISH CROSSOVER at " + TimeToString(rates[0].time) + 
                        " | EMA9 crossed below VWAP | EMA9: " + DoubleToString(currentEma, 2) + 
                        " | VWAP: " + DoubleToString(currentVwap, 2) +
                        " | Diff: " + DoubleToString(currentDiff, 2);
        
        Print(">>> " + crossMsg + " <<<");
        FileWrite(fileHandle, crossMsg);
        
        // If in LONG position, close it
        if(inLongPosition)
        {
            string closeMsg = "Closing LONG position due to BEARISH crossover";
            Print("!!! " + closeMsg + " !!!");
            FileWrite(fileHandle, closeMsg);
            CloseAllPositions();
            
            // Flag for a pending SHORT entry
            tradePending = true;
            pendingTradeType = "SHORT";
        }
        // If no position, prepare for SHORT entry
        else if(!inShortPosition)
        {
            tradePending = true;
            pendingTradeType = "SHORT";
        }
        // If already in SHORT position, maintain it
        else
        {
            string noActionMsg = "Already in SHORT position, no action taken";
            Print("--- " + noActionMsg + " ---");
            FileWrite(fileHandle, noActionMsg);
        }
    }
    
    // Check if pending trade meets confirmation criteria
    if(tradePending)
    {
        if(pendingTradeType == "LONG" && currentDiff >= MinCrossoverDifference)
        {
            string entryMsg = "LONG ENTRY CONFIRMED at " + TimeToString(currentTime) + 
                           " | EMA9: " + DoubleToString(currentEma, 2) + 
                           " | VWAP: " + DoubleToString(currentVwap, 2) +
                           " | Diff: " + DoubleToString(currentDiff, 2) +
                           " | Minimum difference threshold met";
            Print(">>> " + entryMsg + " <<<");
            FileWrite(fileHandle, entryMsg);
            
            ExecuteBuyOrder();
            tradePending = false;
        }
        else if(pendingTradeType == "SHORT" && currentDiff <= -MinCrossoverDifference)
        {
            string entryMsg = "SHORT ENTRY CONFIRMED at " + TimeToString(currentTime) + 
                           " | EMA9: " + DoubleToString(currentEma, 2) + 
                           " | VWAP: " + DoubleToString(currentVwap, 2) +
                           " | Diff: " + DoubleToString(currentDiff, 2) +
                           " | Minimum difference threshold met";
            Print(">>> " + entryMsg + " <<<");
            FileWrite(fileHandle, entryMsg);
            
            ExecuteSellOrder();
            tradePending = false;
        }
    }
    
    // Even if no crossover has occurred, check for extreme differences that might warrant trade action
    // This handles scenarios where market moves strongly without waiting for a formal crossover
    if(!tradePending)
    {
        // Strong bullish divergence while in SHORT position
        if(inShortPosition && currentDiff >= MinCrossoverDifference * 1.5)
        {
            string reversalMsg = "STRONG BULLISH DIVERGENCE DETECTED without crossover at " + TimeToString(currentTime) + 
                              " | EMA9: " + DoubleToString(currentEma, 2) + 
                              " | VWAP: " + DoubleToString(currentVwap, 2) +
                              " | Diff: " + DoubleToString(currentDiff, 2);
            Print("!!! " + reversalMsg + " !!!");
            FileWrite(fileHandle, reversalMsg);
            
            // Close SHORT position and open LONG
            CloseAllPositions();
            ExecuteBuyOrder();
        }
        // Strong bearish divergence while in LONG position
        else if(inLongPosition && currentDiff <= -MinCrossoverDifference * 1.5)
        {
            string reversalMsg = "STRONG BEARISH DIVERGENCE DETECTED without crossover at " + TimeToString(currentTime) + 
                              " | EMA9: " + DoubleToString(currentEma, 2) + 
                              " | VWAP: " + DoubleToString(currentVwap, 2) +
                              " | Diff: " + DoubleToString(currentDiff, 2);
            Print("!!! " + reversalMsg + " !!!");
            FileWrite(fileHandle, reversalMsg);
            
            // Close LONG position and open SHORT
            CloseAllPositions();
            ExecuteSellOrder();
        }
        // Strong bearish condition with no position - This addresses the missed opportunity case
        else if(!inLongPosition && !inShortPosition && currentDiff <= -MinCrossoverDifference)
        {
            string entryMsg = "SIGNIFICANT BEARISH CONDITION DETECTED with no position at " + TimeToString(currentTime) + 
                           " | EMA9: " + DoubleToString(currentEma, 2) + 
                           " | VWAP: " + DoubleToString(currentVwap, 2) +
                           " | Diff: " + DoubleToString(currentDiff, 2);
            Print("!!! " + entryMsg + " !!!");
            FileWrite(fileHandle, entryMsg);
            
            // Open SHORT position based on significant difference
            if(currentTime >= lastBearishSignalTime + MinSecondsBetweenSignals)
            {
                lastBearishSignalTime = currentTime;
                ExecuteSellOrder();
            }
        }
        // Strong bullish condition with no position
        else if(!inLongPosition && !inShortPosition && currentDiff >= MinCrossoverDifference)
        {
            string entryMsg = "SIGNIFICANT BULLISH CONDITION DETECTED with no position at " + TimeToString(currentTime) + 
                           " | EMA9: " + DoubleToString(currentEma, 2) + 
                           " | VWAP: " + DoubleToString(currentVwap, 2) +
                           " | Diff: " + DoubleToString(currentDiff, 2);
            Print("!!! " + entryMsg + " !!!");
            FileWrite(fileHandle, entryMsg);
            
            // Open LONG position based on significant difference
            if(currentTime >= lastBullishSignalTime + MinSecondsBetweenSignals)
            {
                lastBullishSignalTime = currentTime;
                ExecuteBuyOrder();
            }
        }
    }
    
    // Cancel pending trades if conditions reversed
    if(tradePending)
    {
        if(pendingTradeType == "LONG" && currentDiff < 0)
        {
            string cancelMsg = "LONG trade setup CANCELLED - EMA crossed back below VWAP";
            Print("!!! " + cancelMsg + " !!!");
            FileWrite(fileHandle, cancelMsg);
            tradePending = false;
        }
        else if(pendingTradeType == "SHORT" && currentDiff > 0)
        {
            string cancelMsg = "SHORT trade setup CANCELLED - EMA crossed back above VWAP";
            Print("!!! " + cancelMsg + " !!!");
            FileWrite(fileHandle, cancelMsg);
            tradePending = false;
        }
    }
}

//+------------------------------------------------------------------+
//| Close all existing positions                                     |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
    // First check if we actually have positions to close
    int totalPositions = PositionsTotal();
    if(totalPositions == 0)
    {
        Print("No positions to close");
        inLongPosition = false;
        inShortPosition = false;
        return;
    }
    
    // Loop through all positions and close them one by one
    for(int i = totalPositions - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0)
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
                MqlTradeRequest request = {};
                MqlTradeResult result = {};
                
                request.action = TRADE_ACTION_DEAL;
                request.symbol = _Symbol;
                
                long positionType = PositionGetInteger(POSITION_TYPE);
                double positionVolume = PositionGetDouble(POSITION_VOLUME);
                double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double currentProfit = PositionGetDouble(POSITION_PROFIT);
                
                if(positionType == POSITION_TYPE_BUY)
                {
                    request.type = ORDER_TYPE_SELL;
                    request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                    request.volume = positionVolume;
                    request.position = ticket;
                    request.comment = "Close LONG position";
                }
                else if(positionType == POSITION_TYPE_SELL)
                {
                    request.type = ORDER_TYPE_BUY;
                    request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                    request.volume = positionVolume;
                    request.position = ticket;
                    request.comment = "Close SHORT position";
                }
                
                request.deviation = 10;
                
                // Implement retry logic
                bool orderSent = false;
                int retryCount = 0;
                
                while(!orderSent && retryCount < MaxTradeRetries)
                {
                    bool sent = OrderSend(request, result);
                    
                    if(sent && result.retcode == TRADE_RETCODE_DONE)
                    {
                        string posType = (positionType == POSITION_TYPE_BUY) ? "LONG" : "SHORT";
                        double closePrice = request.price;
                        double priceDifference = (posType == "LONG") ? 
                                               (closePrice - openPrice) : 
                                               (openPrice - closePrice);
                        
                        string closeMsg = posType + " position closed at " + TimeToString(TimeCurrent()) + 
                                          " - Open Price: " + DoubleToString(openPrice, 2) +
                                          " - Close Price: " + DoubleToString(closePrice, 2) +
                                          " - P/L: " + DoubleToString(currentProfit, 2) +
                                          " - Point Diff: " + DoubleToString(priceDifference, 2) +
                                          " - Ticket: " + IntegerToString(ticket);
                        Print(">>> " + closeMsg + " <<<");
                        FileWrite(fileHandle, closeMsg);
                        
                        totalProfit += currentProfit;
                        totalTrades++;
                        successfulTrades++;
                        orderSent = true;
                    }
                    else
                    {
                        retryCount++;
                        if(retryCount < MaxTradeRetries)
                        {
                            string retryMsg = "Retrying close operation - Attempt " + IntegerToString(retryCount + 1) + 
                                              " - Error: " + IntegerToString(result.retcode);
                            Print(retryMsg);
                            FileWrite(fileHandle, retryMsg);
                            Sleep(500); // Wait 500ms before retrying
                        }
                        else
                        {
                            string posType = (positionType == POSITION_TYPE_BUY) ? "LONG" : "SHORT";
                            string errorMsg = "Failed to close " + posType + " position after " + 
                                             IntegerToString(MaxTradeRetries) + " attempts" +
                                             " - Error: " + IntegerToString(result.retcode);
                            Print("!!! " + errorMsg + " !!!");
                            FileWrite(fileHandle, errorMsg);
                            failedTrades++;
                        }
                    }
                }
            }
        }
    }
    
    // Reset position flags
    inLongPosition = false;
    inShortPosition = false;
}

//+------------------------------------------------------------------+
//| Execute Buy Order                                                |
//+------------------------------------------------------------------+
void ExecuteBuyOrder()
{
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = LotSize;
    request.type = ORDER_TYPE_BUY;
    request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    request.sl = currentVwap; // Setting stop loss at VWAP level
    request.deviation = 10;
    request.comment = "ETH EMA9-VWAP Buy";
    
    // Implement retry logic
    bool orderSent = false;
    int retryCount = 0;
    
    while(!orderSent && retryCount < MaxTradeRetries)
    {
        bool sent = OrderSend(request, result);
        
        if(sent && result.retcode == TRADE_RETCODE_DONE)
        {
            inLongPosition = true;
            inShortPosition = false;
            
            string entryMsg = "LONG Entry executed at " + TimeToString(TimeCurrent()) + 
                             " - Entry Price: " + DoubleToString(request.price, 2) + 
                             " - Stop Loss: " + DoubleToString(request.sl, 2) + 
                             " - Lot Size: " + DoubleToString(LotSize, 2) + 
                             " - Ticket: " + IntegerToString(result.deal);
            Print(">>> " + entryMsg + " <<<");
            FileWrite(fileHandle, entryMsg);
            orderSent = true;
            totalTrades++;
            successfulTrades++;
        }
        else
        {
            retryCount++;
            if(retryCount < MaxTradeRetries)
            {
                string retryMsg = "Retrying LONG entry - Attempt " + IntegerToString(retryCount + 1) + 
                                 " - Error: " + IntegerToString(result.retcode);
                Print(retryMsg);
                FileWrite(fileHandle, retryMsg);
                Sleep(500); // Wait 500ms before retrying
            }
            else
            {
                string errorMsg = "LONG Entry failed after " + IntegerToString(MaxTradeRetries) + 
                                 " attempts - Error: " + IntegerToString(result.retcode);
                Print("!!! " + errorMsg + " !!!");
                FileWrite(fileHandle, errorMsg);
                failedTrades++;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Execute Sell Order                                               |
//+------------------------------------------------------------------+
void ExecuteSellOrder()
{
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = LotSize;
    request.type = ORDER_TYPE_SELL;
    request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    request.sl = currentVwap; // Setting stop loss at VWAP level
    request.deviation = 10;
    request.comment = "ETH EMA9-VWAP Sell";
    
    // Implement retry logic
    bool orderSent = false;
    int retryCount = 0;
    
    while(!orderSent && retryCount < MaxTradeRetries)
    {
        bool sent = OrderSend(request, result);
        
        if(sent && result.retcode == TRADE_RETCODE_DONE)
        {
            inShortPosition = true;
            inLongPosition = false;
            
            string entryMsg = "SHORT Entry executed at " + TimeToString(TimeCurrent()) + 
                             " - Entry Price: " + DoubleToString(request.price, 2) + 
                             " - Stop Loss: " + DoubleToString(request.sl, 2) + 
                             " - Lot Size: " + DoubleToString(LotSize, 2) + 
                             " - Ticket: " + IntegerToString(result.deal);
            Print(">>> " + entryMsg + " <<<");
            FileWrite(fileHandle, entryMsg);
            orderSent = true;
            totalTrades++;
            successfulTrades++;
        }
        else
        {
            retryCount++;
            if(retryCount < MaxTradeRetries)
            {
                string retryMsg = "Retrying SHORT entry - Attempt " + IntegerToString(retryCount + 1) + 
                                 " - Error: " + IntegerToString(result.retcode);
                Print(retryMsg);
                FileWrite(fileHandle, retryMsg);
                Sleep(500); // Wait 500ms before retrying
            }
            else
            {
                string errorMsg = "SHORT Entry failed after " + IntegerToString(MaxTradeRetries) + 
                                 " attempts - Error: " + IntegerToString(result.retcode);
                Print("!!! " + errorMsg + " !!!");
                FileWrite(fileHandle, errorMsg);
                failedTrades++;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Generate summary statistics
    FileWrite(fileHandle, "=== STRATEGY SUMMARY ===");
    FileWrite(fileHandle, "Test ended at: ", TimeToString(TimeCurrent()));
    FileWrite(fileHandle, "Total trades executed: " + IntegerToString(totalTrades));
    FileWrite(fileHandle, "Successful trade operations: " + IntegerToString(successfulTrades));
    FileWrite(fileHandle, "Failed trade operations: " + IntegerToString(failedTrades));
    FileWrite(fileHandle, "Total realized profit/loss: " + DoubleToString(totalProfit, 2));
    
    // If there are open positions at shutdown, log their details
    int openPositions = PositionsTotal();
    if(openPositions > 0)
    {
        double unrealizedProfit = 0.0;
        
        FileWrite(fileHandle, "=== OPEN POSITIONS AT SHUTDOWN ===");
        for(int i = 0; i < openPositions; i++)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
                long positionType = PositionGetInteger(POSITION_TYPE);
                double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double currentProfit = PositionGetDouble(POSITION_PROFIT);
                double volume = PositionGetDouble(POSITION_VOLUME);
                string type = (positionType == POSITION_TYPE_BUY) ? "LONG" : "SHORT";
                
                FileWrite(fileHandle, "Position #" + IntegerToString(i+1) + ": " + type + 
                         " - Open Price: " + DoubleToString(openPrice, 2) +
                         " - Volume: " + DoubleToString(volume, 2) +
                         " - Unrealized P/L: " + DoubleToString(currentProfit, 2));
                
                unrealizedProfit += currentProfit;
            }
        }
        
        FileWrite(fileHandle, "Total unrealized profit/loss: " + DoubleToString(unrealizedProfit, 2));
        FileWrite(fileHandle, "Combined total (realized + unrealized): " + DoubleToString(totalProfit + unrealizedProfit, 2));
    }
    
    // Close the log file
    if(fileHandle != INVALID_HANDLE)
    {
        FileClose(fileHandle);
    }
    
    // Release indicator handles
    if(vwapHandle != INVALID_HANDLE)
        IndicatorRelease(vwapHandle);
    
    if(ema9Handle != INVALID_HANDLE)
        IndicatorRelease(ema9Handle);
    
    // Free array memory
    ArrayFree(vwapBuffer);
    ArrayFree(ema9Buffer);
    
    Print("Advanced Entry Strategy EA deinitialized");
}