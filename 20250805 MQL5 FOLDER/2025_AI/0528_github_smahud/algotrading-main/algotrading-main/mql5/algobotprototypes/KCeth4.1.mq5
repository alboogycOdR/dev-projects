//+------------------------------------------------------------------+
//|              Advanced_EntryStrategy_DynamicPositioning.mq5        |
//|                                Copyright 2025, Shivam Shikhar    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Shivam Shikhar"
#property link      "https://www.instagram.com/artificialintelligencefacts?igsh=MXZ6"
#property version   "3.00"
#property strict

// Input parameters for indicators
input string VWAPSettings = "---VWAP Indicator Settings---";
input string VWAP_Name = "VWAP_UTC_Final"; // VWAP indicator name

input string EMASettings = "---EMA Indicator Settings---";
input int EMA_Period = 9; // EMA Period
input ENUM_MA_METHOD EMA_Method = MODE_EMA; // EMA Method
input ENUM_APPLIED_PRICE EMA_Applied_Price = PRICE_CLOSE; // Applied price

// Risk management
input string RiskSettings = "---Risk Management---";
input double RiskPercent = 1.0; // Risk percent per trade (of account)
input double MinLotSize = 0.01; // Minimum lot size
input double MaxLotSize = 5.0; // Maximum lot size

// Take profit and trailing stop settings
input string TPSettings = "---Take Profit and Trailing Stop Settings---";
input double InitialRiskReward = 1.5; // Initial risk:reward ratio (TP distance = SL distance * this value)
input double TrailStartPercent = 30.0; // Start trailing after securing this % of potential profit
input double TrailStepPercent = 10.0; // Move stop loss after price moves this % of ATR
input double ATRPeriod = 14; // ATR period for volatility-based exits
input double ATRMultiplierTP = 3.0; // ATR multiplier for take profit
input double ATRMultiplierSL = 2.0; // ATR multiplier for stop loss
input bool DynamicSLTP = true; // Use dynamic ATR-based SL/TP instead of fixed values

// Signal filter settings
input string SignalSettings = "---Signal Filter Settings---";
input int MinSecondsBetweenSignals = 300; // Minimum seconds between signals of same type
input double MinCrossoverDifference = 5.50; // Minimum difference between EMA and VWAP for valid signal
input bool UseExtremeRSI = true; // Filter entries using RSI
input int RSIPeriod = 14; // RSI period
input double RSIOverbought = 70.0; // RSI overbought level
input double RSIOversold = 30.0; // RSI oversold level

// Error handling settings
input string ErrorSettings = "---Error Handling Settings---";
input int MaxTradeRetries = 3; // Maximum number of trade retry attempts

// Global variables for indicator handles
int vwapHandle = INVALID_HANDLE; // Handle for VWAP indicator
int ema9Handle = INVALID_HANDLE;  // Handle for EMA9 indicator
int atrHandle = INVALID_HANDLE; // Handle for ATR indicator
int rsiHandle = INVALID_HANDLE; // Handle for RSI indicator

// Arrays to store indicator values
double vwapBuffer[];
double ema9Buffer[];
double atrBuffer[];
double rsiBuffer[];

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
double currentATR = 0.0;
double currentRSI = 0.0;
string currentMarketState = "NEUTRAL";

// Performance tracking
double totalProfit = 0.0;
int totalTrades = 0;
int successfulTrades = 0;
int failedTrades = 0;

// Trailing stop variables
double highestPrice = 0.0;  // Tracks highest price for long positions
double lowestPrice = 0.0;   // Tracks lowest price for short positions
bool trailingStopActive = false; // Flag to track if trailing stop is active
double initialStopLoss = 0.0; // Initial stop loss level
double initialTarget = 0.0; // Initial take profit level
double profitLockLevel = 0.0; // Level at which we lock in profit
double lastTrailUpdate = 0.0; // Last price at which trail was updated
double profitLockPercentage = 0.0; // Percentage of profit to lock in

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
    
    FileWrite(fileHandle, "=== Advanced Entry Strategy EA (Advanced Dynamic Positioning v3.0) ===");
    FileWrite(fileHandle, "Test started at: ", TimeToString(TimeCurrent()));
    FileWrite(fileHandle, "Minimum difference for valid entry: " + DoubleToString(MinCrossoverDifference, 2));
    FileWrite(fileHandle, "--- Risk Management ---");
    FileWrite(fileHandle, "Risk per trade: " + DoubleToString(RiskPercent, 2) + "% of account");
    FileWrite(fileHandle, "--- Trailing Stop Settings ---");
    FileWrite(fileHandle, "Initial Risk:Reward: " + DoubleToString(InitialRiskReward, 2));
    FileWrite(fileHandle, "Trail Start Percent: " + DoubleToString(TrailStartPercent, 1) + "%");
    FileWrite(fileHandle, "Trail Step Percent: " + DoubleToString(TrailStepPercent, 1) + "%");
    FileWrite(fileHandle, "Using Dynamic ATR-based SL/TP: " + (DynamicSLTP ? "Yes" : "No"));
    FileWrite(fileHandle, "ATR Multiplier for SL: " + DoubleToString(ATRMultiplierSL, 1));
    FileWrite(fileHandle, "ATR Multiplier for TP: " + DoubleToString(ATRMultiplierTP, 1));
    
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
    
    // Initialize ATR indicator handle
    atrHandle = iATR(_Symbol, PERIOD_M5, ATRPeriod);
    if(atrHandle == INVALID_HANDLE)
    {
        int error = GetLastError();
        string errorMsg = "Failed to create ATR indicator handle! Error: " + IntegerToString(error);
        Print(errorMsg);
        FileWrite(fileHandle, errorMsg);
        return(INIT_FAILED);
    }
    
    // Initialize RSI indicator handle if enabled
    if(UseExtremeRSI)
    {
        rsiHandle = iRSI(_Symbol, PERIOD_M5, RSIPeriod, PRICE_CLOSE);
        if(rsiHandle == INVALID_HANDLE)
        {
            int error = GetLastError();
            string errorMsg = "Failed to create RSI indicator handle! Error: " + IntegerToString(error);
            Print(errorMsg);
            FileWrite(fileHandle, errorMsg);
            return(INIT_FAILED);
        }
    }
    
    // Initialize arrays for indicator values
    ArraySetAsSeries(vwapBuffer, true);
    ArraySetAsSeries(ema9Buffer, true);
    ArraySetAsSeries(atrBuffer, true);
    if(UseExtremeRSI) ArraySetAsSeries(rsiBuffer, true);
    
    // Check for open positions at start
    CheckForOpenPositions();
    
    // Success message
    Print("Advanced Entry Strategy EA v3.0 initialized successfully");
    FileWrite(fileHandle, "All indicators initialized successfully");
    
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
                double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double currentSL = PositionGetDouble(POSITION_SL);
                
                if(positionType == POSITION_TYPE_BUY)
                {
                    inLongPosition = true;
                    highestPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                    initialStopLoss = currentSL;
                    initialTarget = PositionGetDouble(POSITION_TP);
                    lastTrailUpdate = openPrice;
                    Print("Found existing LONG position at startup");
                    FileWrite(fileHandle, "Detected existing LONG position at startup - Setting highest price to current price");
                }
                else if(positionType == POSITION_TYPE_SELL)
                {
                    inShortPosition = true;
                    lowestPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                    initialStopLoss = currentSL;
                    initialTarget = PositionGetDouble(POSITION_TP);
                    lastTrailUpdate = openPrice;
                    Print("Found existing SHORT position at startup");
                    FileWrite(fileHandle, "Detected existing SHORT position at startup - Setting lowest price to current price");
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk                           |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLossDistance)
{
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * (RiskPercent / 100.0);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    
    // Calculate the pip value
    double pipValue = (tickValue / tickSize);
    
    // Calculate the lot size
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double calculatedLotSize = NormalizeDouble(riskAmount / (stopLossDistance * pipValue), 2);
    
    // Ensure lot size is within allowed limits
    double minLot = MathMax(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), MinLotSize);
    double maxLot = MathMin(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX), MaxLotSize);
    
    calculatedLotSize = MathMax(minLot, MathMin(maxLot, calculatedLotSize));
    
    // Round to the nearest allowed lot step
    return NormalizeDouble(MathFloor(calculatedLotSize / lotStep) * lotStep, 2);
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
    int atrCopied = CopyBuffer(atrHandle, 0, 0, 5, atrBuffer);
    
    if(vwapCopied < 5 || emaCopied < 5 || atrCopied < 5)
    {
        Print("Not enough indicator data copied. VWAP: ", vwapCopied, ", EMA: ", emaCopied, ", ATR: ", atrCopied);
        return;
    }
    
    // Get RSI if enabled
    bool rsiValid = true;
    if(UseExtremeRSI)
    {
        int rsiCopied = CopyBuffer(rsiHandle, 0, 0, 5, rsiBuffer);
        if(rsiCopied < 5)
        {
            Print("Not enough RSI data copied: ", rsiCopied);
            rsiValid = false;
        }
        else
        {
            currentRSI = rsiBuffer[0];
        }
    }
    
    // Current values
    currentVwap = vwapBuffer[0];
    currentEma = ema9Buffer[0];
    currentDiff = currentEma - currentVwap;
    currentATR = atrBuffer[0];
    
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
                         " | ATR: " + DoubleToString(currentATR, 2);
                         
        if(UseExtremeRSI && rsiValid)
        {
            message += " | RSI: " + DoubleToString(currentRSI, 1);
        }
        
        message += " | Status: " + statusText;
        
        Print(message);
        FileWrite(fileHandle, message);
    }
    
    // Check and update trailing stops (using advanced trailing stop)
    ManageTrailingStops();
    
    // Current time
    datetime currentTime = TimeCurrent();
    
    // First, check for crossovers which are the primary entry signals
    bool bullishCrossover = (prevDiff <= 0 && currentDiff > 0);
    bool bearishCrossover = (prevDiff >= 0 && currentDiff < 0);
    
    // Process bullish crossover
    if(bullishCrossover && (currentTime >= lastBullishSignalTime + MinSecondsBetweenSignals))
    {
        // Apply RSI filter if enabled
        bool rsiConfirmation = true;
        if(UseExtremeRSI && rsiValid)
        {
            rsiConfirmation = (currentRSI < 50); // Look for bullish signal when RSI is below 50
            if(!rsiConfirmation)
            {
                Print("RSI filter rejecting bullish signal - RSI: " + DoubleToString(currentRSI, 1));
                return;
            }
        }
        
        lastBullishSignalTime = currentTime;
        
        string crossMsg = "BULLISH CROSSOVER at " + TimeToString(rates[0].time) + 
                        " | EMA9 crossed above VWAP | EMA9: " + DoubleToString(currentEma, 2) + 
                        " | VWAP: " + DoubleToString(currentVwap, 2) +
                        " | Diff: " + DoubleToString(currentDiff, 2);
        
        if(UseExtremeRSI && rsiValid)
        {
            crossMsg += " | RSI: " + DoubleToString(currentRSI, 1);
        }
        
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
        // Apply RSI filter if enabled
        bool rsiConfirmation = true;
        if(UseExtremeRSI && rsiValid)
        {
            rsiConfirmation = (currentRSI > 50); // Look for bearish signal when RSI is above 50
            if(!rsiConfirmation)
            {
                Print("RSI filter rejecting bearish signal - RSI: " + DoubleToString(currentRSI, 1));
                return;
            }
        }
        
        lastBearishSignalTime = currentTime;
        
        string crossMsg = "BEARISH CROSSOVER at " + TimeToString(rates[0].time) + 
                        " | EMA9 crossed below VWAP | EMA9: " + DoubleToString(currentEma, 2) + 
                        " | VWAP: " + DoubleToString(currentVwap, 2) +
                        " | Diff: " + DoubleToString(currentDiff, 2);
        
        if(UseExtremeRSI && rsiValid)
        {
            crossMsg += " | RSI: " + DoubleToString(currentRSI, 1);
        }
        
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
            // Additional confirmation with RSI
            if(UseExtremeRSI && rsiValid && currentRSI > RSIOverbought)
            {
                string rejectMsg = "LONG entry rejected - RSI overbought at " + DoubleToString(currentRSI, 1);
                Print("!!! " + rejectMsg + " !!!");
                FileWrite(fileHandle, rejectMsg);
                tradePending = false;
                return;
            }
            
            string entryMsg = "LONG ENTRY CONFIRMED at " + TimeToString(currentTime) + 
                           " | EMA9: " + DoubleToString(currentEma, 2) + 
                           " | VWAP: " + DoubleToString(currentVwap, 2) +
                           " | Diff: " + DoubleToString(currentDiff, 2) +
                           " | ATR: " + DoubleToString(currentATR, 2) +
                           " | Minimum difference threshold met";
            Print(">>> " + entryMsg + " <<<");
            FileWrite(fileHandle, entryMsg);
            
            ExecuteBuyOrder();
            tradePending = false;
        }
        else if(pendingTradeType == "SHORT" && currentDiff <= -MinCrossoverDifference)
        {
            // Additional confirmation with RSI
            if(UseExtremeRSI && rsiValid && currentRSI < RSIOversold)
            {
                string rejectMsg = "SHORT entry rejected - RSI oversold at " + DoubleToString(currentRSI, 1);
                Print("!!! " + rejectMsg + " !!!");
                FileWrite(fileHandle, rejectMsg);
                tradePending = false;
                return;
            }
            
            string entryMsg = "SHORT ENTRY CONFIRMED at " + TimeToString(currentTime) + 
                           " | EMA9: " + DoubleToString(currentEma, 2) + 
                           " | VWAP: " + DoubleToString(currentVwap, 2) +
                           " | Diff: " + DoubleToString(currentDiff, 2) +
                           " | ATR: " + DoubleToString(currentATR, 2) +
                           " | Minimum difference threshold met";
            Print(">>> " + entryMsg + " <<<");
            FileWrite(fileHandle, entryMsg);
            
            ExecuteSellOrder();
            tradePending = false;
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
//| Manage advanced trailing stops for open positions                |
//+------------------------------------------------------------------+
void ManageTrailingStops()
{
    if(PositionsTotal() == 0)
        return;
    
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0)
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
                long positionType = PositionGetInteger(POSITION_TYPE);
                double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double currentSL = PositionGetDouble(POSITION_SL);
                double currentTP = PositionGetDouble(POSITION_TP);
                
                // LONG position management
                if(positionType == POSITION_TYPE_BUY)
                {
                    // Update highest price if current price is higher
                    if(bid > highestPrice)
                    {
                        highestPrice = bid;
                    }
                    
                    // If we don't have an initial stop loss recorded, get it
                    if(initialStopLoss <= 0)
                    {
                        initialStopLoss = currentSL;
                    }
                    
                    // If we don't have an initial target recorded, get it
                    if(initialTarget <= 0)
                    {
                        initialTarget = currentTP;
                    }
                    
                    // Calculate potential profit and current profit
                    double potentialProfit = (initialTarget > 0) ? initialTarget - openPrice : currentATR * ATRMultiplierTP;
                    double currentProfit = bid - openPrice;
                    double profitPercent = (potentialProfit > 0) ? (currentProfit / potentialProfit) * 100.0 : 0;
                    
                    // Calculate risk (distance to stop loss)
                    double risk = openPrice - initialStopLoss;
                    
                    // Initial trail activation check - start trailing once we've reached TrailStartPercent of potential profit
                    if(profitPercent >= TrailStartPercent)
                    {
                        if(!trailingStopActive)
                        {
                            trailingStopActive = true;
                            lastTrailUpdate = bid;
                            profitLockPercentage = TrailStartPercent;
                            string activateMsg = "ACTIVATING Trailing Stop for LONG position - Reached " + 
                                              DoubleToString(TrailStartPercent, 1) + "% of potential profit";
                            Print(">>> " + activateMsg + " <<<");
                            FileWrite(fileHandle, activateMsg);
                        }
                        
                        // Calculate how much profit to lock in (increases with price movement)
                        double profitToLock = risk * (profitLockPercentage / 100.0);
                        double newSL = openPrice + profitToLock;
                        
                        // Check if we need to step up our trailing
                        if(bid - lastTrailUpdate >= currentATR * (TrailStepPercent / 100.0))
                        {
                            // Increase profit lock percentage with each step
                            profitLockPercentage += 10.0; // Increase by 10% each step
                            profitLockPercentage = MathMin(profitLockPercentage, 90.0); // Cap at 90%
                            
                            // Recalculate profit to lock with new percentage
                            profitToLock = risk * (profitLockPercentage / 100.0);
                            newSL = openPrice + profitToLock;
                            
                            lastTrailUpdate = bid;
                            string trailMsg = "STEPPING UP profit lock to " + DoubleToString(profitLockPercentage, 1) + 
                                           "% for LONG position - New SL: " + DoubleToString(newSL, _Digits);
                            Print(">>> " + trailMsg + " <<<");
                            FileWrite(fileHandle, trailMsg);
                        }
                        
                        // Only move stop loss if it's better than the current one
                        if(newSL > currentSL)
                        {
                            ModifyPositionStopLoss(ticket, newSL);
                        }
                    }
                }
                // SHORT position management
                else if(positionType == POSITION_TYPE_SELL)
                {
                    // Update lowest price if current price is lower
                    if(ask < lowestPrice || lowestPrice == 0)
                    {
                        lowestPrice = ask;
                    }
                    
                    // If we don't have an initial stop loss recorded, get it
                    if(initialStopLoss <= 0)
                    {
                        initialStopLoss = currentSL;
                    }
                    
                    // If we don't have an initial target recorded, get it
                    if(initialTarget <= 0)
                    {
                        initialTarget = currentTP;
                    }
                    
                    // Calculate potential profit and current profit
                    double potentialProfit = (initialTarget > 0) ? openPrice - initialTarget : currentATR * ATRMultiplierTP;
                    double currentProfit = openPrice - ask;
                    double profitPercent = (potentialProfit > 0) ? (currentProfit / potentialProfit) * 100.0 : 0;
                    
                    // Calculate risk (distance to stop loss)
                    double risk = initialStopLoss - openPrice;
                    
                    // Initial trail activation check - start trailing once we've reached TrailStartPercent of potential profit
                    if(profitPercent >= TrailStartPercent)
                    {
                        if(!trailingStopActive)
                        {
                            trailingStopActive = true;
                            lastTrailUpdate = ask;
                            profitLockPercentage = TrailStartPercent;
                            string activateMsg = "ACTIVATING Trailing Stop for SHORT position - Reached " + 
                                              DoubleToString(TrailStartPercent, 1) + "% of potential profit";
                            Print(">>> " + activateMsg + " <<<");
                            FileWrite(fileHandle, activateMsg);
                        }
                        
                        // Calculate how much profit to lock in (increases with price movement)
                        double profitToLock = risk * (profitLockPercentage / 100.0);
                        double newSL = openPrice - profitToLock;
                        
                        // Check if we need to step down our trailing
                        if(lastTrailUpdate - ask >= currentATR * (TrailStepPercent / 100.0))
                        {
                            // Increase profit lock percentage with each step
                            profitLockPercentage += 10.0; // Increase by 10% each step
                            profitLockPercentage = MathMin(profitLockPercentage, 90.0); // Cap at 90%
                            
                            // Recalculate profit to lock with new percentage
                            profitToLock = risk * (profitLockPercentage / 100.0);
                            newSL = openPrice - profitToLock;
                            
                            lastTrailUpdate = ask;
                            string trailMsg = "STEPPING UP profit lock to " + DoubleToString(profitLockPercentage, 1) + 
                                           "% for SHORT position - New SL: " + DoubleToString(newSL, _Digits);
                            Print(">>> " + trailMsg + " <<<");
                            FileWrite(fileHandle, trailMsg);
                        }
                        
                        // Only move stop loss if it's better than the current one
                        if(newSL < currentSL || currentSL == 0)
                        {
                            ModifyPositionStopLoss(ticket, newSL);
                        }
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Modify the stop loss of an existing position                     |
//+------------------------------------------------------------------+
bool ModifyPositionStopLoss(ulong ticket, double newStopLoss)
{
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_SLTP; // Only modify SL/TP
    request.position = ticket;
    request.symbol = _Symbol;
    request.sl = NormalizeDouble(newStopLoss, _Digits);
    request.tp = PositionGetDouble(POSITION_TP); // Keep existing TP if any
    
    bool orderSent = OrderSend(request, result);
    
    if(orderSent && result.retcode == TRADE_RETCODE_DONE)
    {
        string updateMsg = "Stop loss updated to " + DoubleToString(newStopLoss, _Digits);
        Print(updateMsg);
        FileWrite(fileHandle, updateMsg);
        return true;
    }
    else
    {
        string errorMsg = "Failed to modify stop loss - Error: " + IntegerToString(result.retcode);
        Print("!!! " + errorMsg + " !!!");
        FileWrite(fileHandle, errorMsg);
        return false;
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
                        
                        // Reset trailing stop tracking
                        trailingStopActive = false;
                        highestPrice = 0.0;
                        lowestPrice = 0.0;
                        initialStopLoss = 0.0;
                        initialTarget = 0.0;
                        profitLockPercentage = 0.0;
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
    double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double stopLoss = 0.0;
    double takeProfit = 0.0;
    double lotSize = 0.0;
    
    // Determine stop loss and take profit based on ATR or VWAP
    if(DynamicSLTP)
    {
        // ATR-based stop loss and take profit (dynamic based on volatility)
        stopLoss = NormalizeDouble(entryPrice - (currentATR * ATRMultiplierSL), _Digits);
        takeProfit = NormalizeDouble(entryPrice + (currentATR * ATRMultiplierTP), _Digits);
    }
    else
    {
        // VWAP-based stop loss
        stopLoss = currentVwap;
        
        // Calculate take profit based on risk:reward ratio
        double riskInPoints = entryPrice - stopLoss;
        takeProfit = NormalizeDouble(entryPrice + (riskInPoints * InitialRiskReward), _Digits);
    }
    
    // Calculate position size based on risk management
    double stopLossDistance = entryPrice - stopLoss;
    lotSize = CalculateLotSize(stopLossDistance);
    
    // Prepare trade request
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lotSize;
    request.type = ORDER_TYPE_BUY;
    request.price = entryPrice;
    request.sl = stopLoss;
    request.tp = takeProfit;
    request.deviation = 10;
    request.comment = "ETH EMA9-VWAP Buy v3.0";
    
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
            
            // Initialize tracking for trailing stop
            highestPrice = entryPrice;
            initialStopLoss = stopLoss;
            initialTarget = takeProfit;
            lastTrailUpdate = entryPrice;
            trailingStopActive = false;
            profitLockPercentage = 0.0;
            
            // Calculate expected risk:reward
            double riskPoints = entryPrice - stopLoss;
            double rewardPoints = takeProfit - entryPrice;
            double riskRewardRatio = rewardPoints / riskPoints;
            
            string entryMsg = "LONG Entry executed at " + TimeToString(TimeCurrent()) + 
                             " - Entry Price: " + DoubleToString(request.price, _Digits) + 
                             " - Stop Loss: " + DoubleToString(request.sl, _Digits) + 
                             " - Take Profit: " + DoubleToString(request.tp, _Digits) +
                             " - Risk/Reward: 1:" + DoubleToString(riskRewardRatio, 2) +
                             " - Lot Size: " + DoubleToString(lotSize, 2) + 
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
    double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double stopLoss = 0.0;
    double takeProfit = 0.0;
    double lotSize = 0.0;
    
    // Determine stop loss and take profit based on ATR or VWAP
    if(DynamicSLTP)
    {
        // ATR-based stop loss and take profit (dynamic based on volatility)
        stopLoss = NormalizeDouble(entryPrice + (currentATR * ATRMultiplierSL), _Digits);
        takeProfit = NormalizeDouble(entryPrice - (currentATR * ATRMultiplierTP), _Digits);
    }
    else
    {
        // VWAP-based stop loss
        stopLoss = currentVwap;
        
        // Calculate take profit based on risk:reward ratio
        double riskInPoints = stopLoss - entryPrice;
        takeProfit = NormalizeDouble(entryPrice - (riskInPoints * InitialRiskReward), _Digits);
    }
    
    // Calculate position size based on risk management
    double stopLossDistance = stopLoss - entryPrice;
    lotSize = CalculateLotSize(stopLossDistance);
    
    // Prepare trade request
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lotSize;
    request.type = ORDER_TYPE_SELL;
    request.price = entryPrice;
    request.sl = stopLoss;
    request.tp = takeProfit;
    request.deviation = 10;
    request.comment = "ETH EMA9-VWAP Sell v3.0";
    
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
            
            // Initialize tracking for trailing stop
            lowestPrice = entryPrice;
            initialStopLoss = stopLoss;
            initialTarget = takeProfit;
            lastTrailUpdate = entryPrice;
            trailingStopActive = false;
            profitLockPercentage = 0.0;
            
            // Calculate expected risk:reward
            double riskPoints = stopLoss - entryPrice;
            double rewardPoints = entryPrice - takeProfit;
            double riskRewardRatio = rewardPoints / riskPoints;
            
            string entryMsg = "SHORT Entry executed at " + TimeToString(TimeCurrent()) + 
                             " - Entry Price: " + DoubleToString(request.price, _Digits) + 
                             " - Stop Loss: " + DoubleToString(request.sl, _Digits) + 
                             " - Take Profit: " + DoubleToString(request.tp, _Digits) +
                             " - Risk/Reward: 1:" + DoubleToString(riskRewardRatio, 2) +
                             " - Lot Size: " + DoubleToString(lotSize, 2) + 
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
                double currentSL = PositionGetDouble(POSITION_SL);
                double currentTP = PositionGetDouble(POSITION_TP);
                string type = (positionType == POSITION_TYPE_BUY) ? "LONG" : "SHORT";
                
                FileWrite(fileHandle, "Position #" + IntegerToString(i+1) + ": " + type + 
                         " - Open Price: " + DoubleToString(openPrice, 2) +
                         " - Volume: " + DoubleToString(volume, 2) +
                         " - Stop Loss: " + DoubleToString(currentSL, 2) +
                         (currentTP > 0 ? " - Take Profit: " + DoubleToString(currentTP, 2) : "") +
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
        
    if(atrHandle != INVALID_HANDLE)
        IndicatorRelease(atrHandle);
        
    if(UseExtremeRSI && rsiHandle != INVALID_HANDLE)
        IndicatorRelease(rsiHandle);
    
    // Free array memory
    ArrayFree(vwapBuffer);
    ArrayFree(ema9Buffer);
    ArrayFree(atrBuffer);
    if(UseExtremeRSI) ArrayFree(rsiBuffer);
    
    Print("Advanced Entry Strategy EA v3.0 deinitialized");
}