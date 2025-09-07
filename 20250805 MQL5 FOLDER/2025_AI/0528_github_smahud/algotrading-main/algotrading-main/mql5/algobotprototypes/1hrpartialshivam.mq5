//+------------------------------------------------------------------+
//| KC_4.7_H1_PartialClose.mq5 |
//| Copyright 2025, Shivam Shikhar |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Shivam Shikhar"
#property link "https://www.instagram.com/artificialintelligencefacts?igsh=MXZ6"
#property version "4.80"
#property strict


// Input parameters grouped by category
input string VWAPSettings = "---VWAP Indicator Settings---";
input string VWAP_Name = "VWAP_UTC_Final"; // VWAP indicator name


input string EMASettings = "---EMA Indicator Settings---";
input int EMA_Period = 9; // EMA Period
input ENUM_MA_METHOD EMA_Method = MODE_EMA; // EMA Method
input ENUM_APPLIED_PRICE EMA_Applied_Price = PRICE_CLOSE; // Applied price


input string PositionSettings = "---Position Settings---";
input double EntryLotSize = 0.50; // Initial lot size for entry
input double PartialCloseSize = 0.25; // Lot size to close at first target


input string RiskSettings = "---Risk Settings---";
input double FixedStopLossUSD = 5.0; // Fixed stop loss in USD money
input double PartialCloseProfitUSD = 3.0; // First target - partial close in USD
input double FinalProfitTargetUSD = 8.0; // Final take profit target in USD


input string SignalSettings = "---Signal Filter Settings---";
input int MinSecondsBetweenSignals = 240; // Minimum seconds between signals (adjusted for H1)
input double MinCrossoverDifference = 4.50; // Minimum difference for valid signal


input string StopLossSettings = "---Stop Loss Settings---";
input bool UseStopLossAtVWAP = false; // Use VWAP level as Stop Loss
input double AdditionalSLBuffer = 0.0; // Additional SL buffer pips


// Break-Even Settings
input string BreakEvenSettings = "---Break-Even Settings---";
input bool UseBreakEven = true; // Enable break-even function
input double StrongSignalThreshold = 15.0; // Differential threshold for strong signals
input double WeakSignalThreshold = 6.0; // Differential threshold for weak signals
input double PlateauTolerance = 1.0; // Maximum difference between values to consider a plateau
input double RecoveryStopLossOffset = 5.0; // Fixed profit points for strong signal recovery SL
input int MinCandlesForPlateau = 3; // Minimum consecutive candles to confirm plateau


input string ExitSettings = "---Exit Strategy Settings---";
input bool UseConsecutiveCandleExit = true; // Use consecutive candle exit strategy


input string ErrorSettings = "---Error Handling Settings---";
input int MaxTradeRetries = 3; // Max trade retry attempts


// Global variables
int vwapHandle = INVALID_HANDLE, ema9Handle = INVALID_HANDLE;
double vwapBuffer[], ema9Buffer[];
int fileHandle = INVALID_HANDLE;


// Trade state variables
bool inLongPosition = false, inShortPosition = false, tradePending = false;
string pendingTradeType = "";
ulong activePositionTicket = 0;
double activePositionOpenPrice = 0.0, currentStopLossLevel = 0.0;
bool partialCloseExecuted = false;


// Signal tracking
datetime lastBullishSignalTime = 0, lastBearishSignalTime = 0;
datetime lastBullishCrossoverTime = 0, lastBearishCrossoverTime = 0;
bool bullishCrossoverTraded = false, bearishCrossoverTraded = false;


// Consecutive candle exit strategy tracking
bool lastCandleBelowEma = false;
bool secondLastCandleBelowEma = false;
datetime lastCheckedCandleTime = 0;


// Market state
double currentVwap = 0.0, currentEma = 0.0, currentDiff = 0.0;
string currentMarketState = "NEUTRAL";


// Performance tracking
double totalProfit = 0.0;
int totalTrades = 0, successfulTrades = 0, failedTrades = 0;


// Break-Even tracking
bool breakEvenActivated = false;
bool safetyNetActivated = false;
double maxDifferential = 0.0;
datetime lastBreakEvenCheckTime = 0;
double diffHistory[10] = {0};
int plateauCounter = 0;
bool hadStrongSignal = false;


//+------------------------------------------------------------------+
//| Log message with formatting |
//+------------------------------------------------------------------+
void LogMessage(string message, string prefix = "", bool toFile = true)
{
    string formattedMsg = prefix != "" ? prefix + " " + message + " " + prefix : message;
    Print(formattedMsg);
    if(toFile && fileHandle != INVALID_HANDLE) FileWrite(fileHandle, message);
}


//+------------------------------------------------------------------+
//| Expert initialization function |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize log file
    fileHandle = FileOpen("KC_4.7_H1_PartialClose.txt", FILE_WRITE|FILE_TXT);
    if(fileHandle == INVALID_HANDLE)
    {
        Print("Failed to open log file!");
        return(INIT_FAILED);
    }
    
    LogMessage("=== KC 4.7 H1 Partial Close EA ===");
    LogMessage("Test started at: " + TimeToString(TimeCurrent()));
    LogMessage("Timeframe: H1");
    LogMessage("Entry Strategy: Single entry of " + DoubleToString(EntryLotSize, 2) + " lots");
    LogMessage("Partial Close: " + DoubleToString(PartialCloseSize, 2) + " lots at $" + DoubleToString(PartialCloseProfitUSD, 2) + " profit");
    LogMessage("Final Target: $" + DoubleToString(FinalProfitTargetUSD, 2) + " profit");
    LogMessage("Fixed Stop Loss: $" + DoubleToString(FixedStopLossUSD, 2));
    LogMessage("Minimum difference for valid entry: " + DoubleToString(MinCrossoverDifference, 2));
    LogMessage("--- Strategy Logic ---");
    LogMessage("- Continuously looking for new trade opportunities");
    LogMessage("- Will close existing trades when opposite signals appear");
    LogMessage("- Using ONE-TRADE-PER-CROSSOVER rule");
    LogMessage("- Trade retry logic: Maximum " + IntegerToString(MaxTradeRetries) + " retry attempts");
    
    if(UseStopLossAtVWAP)
    {
        string slMessage = "- Stop Loss set at VWAP level";
        if(AdditionalSLBuffer > 0) slMessage += " with additional buffer of " + DoubleToString(AdditionalSLBuffer, 1) + " pips";
        LogMessage(slMessage);
    }
    else LogMessage("- Using fixed monetary Stop Loss of $" + DoubleToString(FixedStopLossUSD, 2));
    
    if(UseBreakEven)
    {
        LogMessage("- Break-Even strategy enabled:");
        LogMessage(" - Weak signal detection: Plateau below " + DoubleToString(StrongSignalThreshold, 1) + 
                 " followed by decline to " + DoubleToString(WeakSignalThreshold, 1));
        LogMessage(" - Fake signal detection: Sharp rise and fall without stable plateau");
        LogMessage(" - Strong signal recovery: Adds " + DoubleToString(RecoveryStopLossOffset, 1) + 
                 " point protection for strong signals after plateau detection");
        LogMessage(" - Plateau detection requires " + IntegerToString(MinCandlesForPlateau) + 
                 " consecutive candles within " + DoubleToString(PlateauTolerance, 1) + " difference");
    }
    
    if(UseConsecutiveCandleExit)
    {
        LogMessage("- Using consecutive candle exit strategy");
        LogMessage(" - For LONG: Exit if two consecutive candles close below EMA9");
        LogMessage(" - For SHORT: Exit if two consecutive candles close above EMA9");
    }
    
    // Initialize indicators
    vwapHandle = iCustom(_Symbol, PERIOD_H1, VWAP_Name);
    ema9Handle = iMA(_Symbol, PERIOD_H1, EMA_Period, 0, EMA_Method, EMA_Applied_Price);
    
    if(vwapHandle == INVALID_HANDLE || ema9Handle == INVALID_HANDLE)
    {
        int error = GetLastError();
        LogMessage("Failed to create indicator handle! Error: " + IntegerToString(error));
        return(INIT_FAILED);
    }
    
    // Initialize arrays
    ArraySetAsSeries(vwapBuffer, true);
    ArraySetAsSeries(ema9Buffer, true);
    
    // Initialize break-even tracking
    breakEvenActivated = false;
    safetyNetActivated = false;
    maxDifferential = 0.0;
    hadStrongSignal = false;
    plateauCounter = 0;
    for(int i = 0; i < 10; i++) diffHistory[i] = 0.0;
    
    // Check for open positions
    CheckForOpenPositions();
    
    LogMessage("KC 4.7 H1 Partial Close EA initialized successfully");
    return(INIT_SUCCEEDED);
}


//+------------------------------------------------------------------+
//| Check for existing open positions |
//+------------------------------------------------------------------+
void CheckForOpenPositions()
{
    inLongPosition = inShortPosition = false;
    activePositionTicket = 0;
    activePositionOpenPrice = 0.0;
    partialCloseExecuted = false;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol)
        {
            long positionType = PositionGetInteger(POSITION_TYPE);
            double positionVolume = PositionGetDouble(POSITION_VOLUME);
            
            activePositionTicket = ticket;
            activePositionOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            
            // Check if partial close has already been executed
            if(positionVolume < EntryLotSize && positionVolume == PartialCloseSize)
                partialCloseExecuted = true;
            
            if(positionType == POSITION_TYPE_BUY)
            {
                inLongPosition = true;
                bullishCrossoverTraded = true;
                LogMessage("Detected existing LONG position at startup - Ticket: " + IntegerToString((int)ticket) + 
                          (partialCloseExecuted ? " (Partial Close executed)" : ""));
            }
            else if(positionType == POSITION_TYPE_SELL)
            {
                inShortPosition = true;
                bearishCrossoverTraded = true;
                LogMessage("Detected existing SHORT position at startup - Ticket: " + IntegerToString((int)ticket) + 
                          (partialCloseExecuted ? " (Partial Close executed)" : ""));
            }
            
            // Check stop loss
            currentStopLossLevel = PositionGetDouble(POSITION_SL);
            if(currentStopLossLevel == 0)
                LogMessage("Position has no stop loss, will add in next tick");
            else
                LogMessage("Position has stop loss at " + DoubleToString(currentStopLossLevel, 2));
                
            // Reset break-even tracking
            breakEvenActivated = false;
            safetyNetActivated = false;
            maxDifferential = 0.0;
            hadStrongSignal = false;
            plateauCounter = 0;
            for(int j = 0; j < 10; j++) diffHistory[j] = 0.0;
        }
    }
}


//+------------------------------------------------------------------+
//| Calculate appropriate stop loss level based on fixed USD amount |
//+------------------------------------------------------------------+
double CalculateStopLossLevel(bool isLong, double entryPrice)
{
    if(UseStopLossAtVWAP)
    {
        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
        double buffer = AdditionalSLBuffer * point;
        
        // Calculate stop level based on position type
        double stopLevel = isLong ? 
                          NormalizeDouble(currentVwap - buffer, digits) : 
                          NormalizeDouble(currentVwap + buffer, digits);
        
        // Ensure stop level respects minimum distances
        double minLevel = SymbolInfoDouble(_Symbol, SYMBOL_BID) - SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
        double maxLevel = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
        
        if(isLong && stopLevel > minLevel) stopLevel = minLevel;
        if(!isLong && stopLevel < maxLevel) stopLevel = maxLevel;
        
        return stopLevel;
    }
    else
    {
        // Calculate stop loss based on fixed USD amount
        double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
        double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
        
        // Calculate how many points needed for the fixed USD stop loss
        double ticksRequired = FixedStopLossUSD / (EntryLotSize * tickValue);
        double pointsRequired = ticksRequired * tickSize;
        
        // Calculate stop loss price
        double stopLevel = isLong ? 
                          NormalizeDouble(entryPrice - pointsRequired, digits) : 
                          NormalizeDouble(entryPrice + pointsRequired, digits);
        
        return stopLevel;
    }
}


//+------------------------------------------------------------------+
//| Execute partial close when first target is reached |
//+------------------------------------------------------------------+
bool ExecutePartialClose()
{
    if(partialCloseExecuted || activePositionTicket == 0) return false;
    
    if(!PositionSelectByTicket(activePositionTicket)) return false;
    
    double currentProfit = PositionGetDouble(POSITION_PROFIT);
    
    // Check if profit target is reached
    if(currentProfit >= PartialCloseProfitUSD)
    {
        long positionType = PositionGetInteger(POSITION_TYPE);
        double currentVolume = PositionGetDouble(POSITION_VOLUME);
        
        // Ensure we have enough volume to partially close
        if(currentVolume < PartialCloseSize)
        {
            LogMessage("Cannot execute partial close - position volume (" + 
                      DoubleToString(currentVolume, 2) + ") is less than partial close size (" + 
                      DoubleToString(PartialCloseSize, 2) + ")");
            return false;
        }
        
        MqlTradeRequest request = {};
        MqlTradeResult result = {};
        
        request.action = TRADE_ACTION_DEAL;
        request.symbol = _Symbol;
        request.volume = PartialCloseSize;
        request.position = activePositionTicket;
        
        if(positionType == POSITION_TYPE_BUY)
        {
            request.type = ORDER_TYPE_SELL;
            request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        }
        else
        {
            request.type = ORDER_TYPE_BUY;
            request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        }
        
        request.comment = "Partial close at $" + DoubleToString(PartialCloseProfitUSD, 2) + " profit";
        request.deviation = 10;
        
        // Retry logic
        bool orderSent = false;
        int retryCount = 0;
        
        while(!orderSent && retryCount < MaxTradeRetries)
        {
            bool sent = OrderSend(request, result);
            
            if(sent && result.retcode == TRADE_RETCODE_DONE)
            {
                string posType = (positionType == POSITION_TYPE_BUY) ? "LONG" : "SHORT";
                
                LogMessage("PARTIAL CLOSE executed - " + posType + " position - Closed: " + 
                          DoubleToString(PartialCloseSize, 2) + " lots at $" + 
                          DoubleToString(currentProfit, 2) + " profit - Remaining: " + 
                          DoubleToString(currentVolume - PartialCloseSize, 2) + " lots", ">>>");
                
                partialCloseExecuted = true;
                totalProfit += currentProfit * (PartialCloseSize / currentVolume);
                return true;
            }
            else
            {
                retryCount++;
                if(retryCount < MaxTradeRetries)
                {
                    LogMessage("Retrying partial close - Attempt " + IntegerToString(retryCount + 1) + 
                              " - Error: " + IntegerToString(result.retcode));
                    Sleep(500);
                }
                else
                {
                    LogMessage("Failed to execute partial close after " + IntegerToString(MaxTradeRetries) + 
                              " attempts - Error: " + IntegerToString(result.retcode), "!!!");
                    return false;
                }
            }
        }
    }
    
    return false;
}


//+------------------------------------------------------------------+
//| Check for break-even conditions based on EMA-VWAP differential |
//+------------------------------------------------------------------+
bool CheckBreakEvenConditions()
{
    if(!UseBreakEven || activePositionTicket == 0 || breakEvenActivated)
        return false;
        
    // Only run on new candle data
    datetime currentTime = TimeCurrent();
    
    // Return if we already checked recently (240 seconds minimum between checks for H1)
    if(currentTime <= lastBreakEvenCheckTime + 240)
        return false;
        
    lastBreakEvenCheckTime = currentTime;
    
    // Update maximum differential seen
    double currentAbsDiff = MathAbs(currentDiff);
    if(currentAbsDiff > maxDifferential)
    {
        maxDifferential = currentAbsDiff;
        
        // Check if we've reached strong signal threshold
        if(maxDifferential >= StrongSignalThreshold)
        {
            hadStrongSignal = true;
            LogMessage("Strong signal detected (max diff: " + DoubleToString(maxDifferential, 2) + 
                      " >= " + DoubleToString(StrongSignalThreshold, 2) + ") - allowing to run without break-even");
                      
            // Reset plateau counter when we reach strong signal
            plateauCounter = 0;
        }
    }
    
    // Exit early if this is a strong signal - we'll handle it in CheckStrongSignalRecovery
    if(hadStrongSignal)
        return false;
        
    // Get position direction
    if(!PositionSelectByTicket(activePositionTicket))
        return false;
        
    bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
    
    // Store current differential value for pattern detection
    // Shift values
    for(int i = 9; i > 0; i--)
        diffHistory[i] = diffHistory[i-1];
    
    // Add current value
    diffHistory[0] = currentDiff;
    
    // Log current diff history
    string historyStr = "";
    for(int i = 0; i < 5; i++)
    {
        if(diffHistory[i] != 0)
            historyStr += DoubleToString(diffHistory[i], 2) + " ";
    }
    LogMessage("Differential history: " + historyStr + " (max: " + DoubleToString(maxDifferential, 2) + ")");
    
    // 1. Weak Signal Detection: Plateau below threshold followed by decline
    bool weakSignalDetected = false;
    bool hasFormedPlateauBelow15 = false;
    
    // Look for plateau pattern in history (similar values for at least 2 consecutive readings)
    for(int i = 1; i < 4; i++)
    {
        if(diffHistory[i] != 0 && diffHistory[i-1] != 0 && diffHistory[i+1] != 0 &&
           MathAbs(diffHistory[i] - diffHistory[i-1]) < PlateauTolerance && 
           MathAbs(diffHistory[i] - diffHistory[i+1]) < PlateauTolerance)
        {
            hasFormedPlateauBelow15 = true;
            
            LogMessage("Plateau detected in differential: values around " + 
                      DoubleToString(diffHistory[i], 2) + " (tolerance: " + 
                      DoubleToString(PlateauTolerance, 2) + ")");
            break;
        }
    }
    
    // If plateau detected, check for subsequent decline to WeakSignalThreshold or below
    if(hasFormedPlateauBelow15)
    {
        if((isLong && currentDiff <= WeakSignalThreshold) || (!isLong && currentDiff >= -WeakSignalThreshold))
        {
            LogMessage("Weak signal detected: Plateau below " + DoubleToString(StrongSignalThreshold, 2) + 
                      " followed by decline to " + DoubleToString(WeakSignalThreshold, 2), "!!!");
            weakSignalDetected = true;
        }
    }
    
    // 2. Fake Signal Detection: Sharp rise and fall without stable plateau
    bool fakeSignalDetected = false;
    
    // Pattern: Initial rise followed by sharp decline
    if(diffHistory[3] != 0 && diffHistory[2] != 0 && diffHistory[1] != 0)
    {
        double rise = isLong ? 
                     (diffHistory[2] - diffHistory[3]) : 
                     (diffHistory[3] - diffHistory[2]);
                     
        double fall = isLong ? 
                     (diffHistory[1] - diffHistory[2]) : 
                     (diffHistory[2] - diffHistory[1]);
        
        // Initial rise followed by larger fall
        if(rise > 1.5 && fall < -2.5)
        {
            LogMessage("Fake signal detected: Sharp rise (" + DoubleToString(rise, 2) + 
                      ") followed by decline (" + DoubleToString(fall, 2) + ")", "!!!");
            fakeSignalDetected = true;
        }
    }
    
    // Apply break even if either condition is met
    if(weakSignalDetected || fakeSignalDetected)
    {
        MqlTradeRequest request = {};
        MqlTradeResult result = {};
        
        request.action = TRADE_ACTION_SLTP;
        request.symbol = _Symbol;
        request.sl = activePositionOpenPrice; // Set SL to entry price
        request.tp = PositionGetDouble(POSITION_TP);
        request.position = activePositionTicket;
        
        bool success = OrderSend(request, result);
        
        if(success && result.retcode == TRADE_RETCODE_DONE)
        {
            currentStopLossLevel = activePositionOpenPrice;
            
            string reason = weakSignalDetected ? "Weak signal plateau pattern" : "Fake signal volatility pattern";
            
            LogMessage("Break-even activated! " + (isLong ? "LONG" : "SHORT") + 
                      " position stop loss moved to entry price " + 
                      DoubleToString(activePositionOpenPrice, 2) + " - Reason: " + reason, "!!!");
                      
            breakEvenActivated = true;
            return true;
        }
        else
        {
            LogMessage("Failed to set break-even stop loss. Error: " + IntegerToString(GetLastError()));
        }
    }
    
    return false;
}


//+------------------------------------------------------------------+
//| Check for strong signal recovery conditions |
//+------------------------------------------------------------------+
bool CheckStrongSignalRecovery()
{
    if(!UseBreakEven || activePositionTicket == 0 || breakEvenActivated || safetyNetActivated)
        return false;
        
    // Only proceed if we previously detected a strong signal
    if(!hadStrongSignal)
        return false;
        
    // Only run on new candle data (240 second intervals for H1)
    datetime currentTime = TimeCurrent();
    if(currentTime <= lastBreakEvenCheckTime + 240)
        return false;
        
    // Get position direction
    if(!PositionSelectByTicket(activePositionTicket))
        return false;
        
    bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
    
    // Check for plateau formation in recent differential values
    bool inPlateau = true;
    double plateauValue = diffHistory[0]; // Current value
    
    // We need at least MinCandlesForPlateau consecutive values within tolerance
    for(int i = 0; i < MinCandlesForPlateau; i++)
    {
        if(i > 0 && diffHistory[i] != 0)
        {
            // If any value differs by more than tolerance, we're not in a plateau
            if(MathAbs(diffHistory[i] - plateauValue) > PlateauTolerance)
            {
                inPlateau = false;
                plateauCounter = 0;
                break;
            }
        }
    }
    
    // If we're in a plateau, increment counter
    if(inPlateau)
    {
        plateauCounter++;
        LogMessage("Potential plateau detected in strong signal recovery: " + 
                  IntegerToString(plateauCounter) + "/" + IntegerToString(MinCandlesForPlateau) + 
                  " consecutive candles around " + DoubleToString(plateauValue, 2));
                  
        // Only activate safety net if we've had enough consecutive plateau candles
        if(plateauCounter >= MinCandlesForPlateau)
        {
            LogMessage("Strong signal plateau confirmed after " + IntegerToString(plateauCounter) + 
                      " consecutive readings around " + DoubleToString(plateauValue, 2), "!!!");
                      
            // Calculate recovery stop loss with fixed RecoveryStopLossOffset point offset from entry
            int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
            
            // For LONG positions: SL at entry + RecoveryStopLossOffset points (profit)
            // For SHORT positions: SL at entry - RecoveryStopLossOffset points (profit)
            double recoverySL = isLong ? 
                              NormalizeDouble(activePositionOpenPrice + RecoveryStopLossOffset, digits) : 
                              NormalizeDouble(activePositionOpenPrice - RecoveryStopLossOffset, digits);
            
            // Apply the recovery stop loss
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            
            request.action = TRADE_ACTION_SLTP;
            request.symbol = _Symbol;
            request.sl = recoverySL;
            request.tp = PositionGetDouble(POSITION_TP);
            request.position = activePositionTicket;
            
            bool success = OrderSend(request, result);
            
            if(success && result.retcode == TRADE_RETCODE_DONE)
            {
                currentStopLossLevel = recoverySL;
                
                LogMessage("STRONG SIGNAL SAFETY NET ACTIVATED! " + (isLong ? "LONG" : "SHORT") + 
                          " position stop loss moved to fixed " + DoubleToString(RecoveryStopLossOffset, 2) + 
                          " points profit at " + DoubleToString(recoverySL, 2) + " (Entry: " + 
                          DoubleToString(activePositionOpenPrice, 2) + 
                          ", Max diff: " + DoubleToString(maxDifferential, 2) + 
                          ", Current diff: " + DoubleToString(currentDiff, 2) + ")", "!!!");
                          
                safetyNetActivated = true;
                return true;
            }
            else
            {
                LogMessage("Failed to set safety net stop loss. Error: " + IntegerToString(GetLastError()));
            }
        }
    }
    else
    {
        // If different pattern found, reset plateau counter
        plateauCounter = 0;
    }
    
    return false;
}


//+------------------------------------------------------------------+
//| Check if Stop Loss has been hit |
//+------------------------------------------------------------------+
bool IsStopLossHit()
{
    if(activePositionTicket == 0) return false;
    
    if(!PositionSelectByTicket(activePositionTicket)) return false;
    
    double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
    
    // Check if price has crossed stop level (if we have one set)
    if(currentStopLossLevel != 0)
    {
        if((isLong && currentBid <= currentStopLossLevel) ||
           (!isLong && currentAsk >= currentStopLossLevel))
        {
            string priceStr = isLong ? DoubleToString(currentBid, 2) : DoubleToString(currentAsk, 2);
            string slType = safetyNetActivated ? "safety net" : (breakEvenActivated ? "break-even" : "fixed USD");
            
            LogMessage((isLong ? "LONG" : "SHORT") + " position stop loss triggered: Current price (" + 
                      priceStr + ") crossed " + slType + " level (" + DoubleToString(currentStopLossLevel, 2) + ")", "!!!");
            return true;
        }
    }
    
    // Check if price has crossed VWAP (only if VWAP SL is enabled and we're not in break-even mode)
    if(UseStopLossAtVWAP && !breakEvenActivated && !safetyNetActivated &&
      ((isLong && inLongPosition && currentBid <= currentVwap) ||
       (!isLong && inShortPosition && currentAsk >= currentVwap)))
    {
        string priceStr = isLong ? DoubleToString(currentBid, 2) : DoubleToString(currentAsk, 2);
        LogMessage((isLong ? "LONG" : "SHORT") + " position stop loss triggered: Current price (" + 
                  priceStr + ") crossed VWAP (" + DoubleToString(currentVwap, 2) + ")", "!!!");
        return true;
    }
    
    return false;
}


//+------------------------------------------------------------------+
//| Check if final profit target has been reached |
//+------------------------------------------------------------------+
bool IsFinalTargetReached()
{
    if(activePositionTicket == 0) return false;
    
    if(!PositionSelectByTicket(activePositionTicket)) return false;
    
    double currentProfit = PositionGetDouble(POSITION_PROFIT);
    
    if(currentProfit >= FinalProfitTargetUSD)
    {
        LogMessage("Final profit target of $" + DoubleToString(FinalProfitTargetUSD, 2) + 
                  " reached. Current profit: $" + DoubleToString(currentProfit, 2), ">>>");
        return true;
    }
    
    return false;
}


//+------------------------------------------------------------------+
//| Check consecutive candle exit condition |
//+------------------------------------------------------------------+
bool CheckConsecutiveCandleExit()
{
    if(!UseConsecutiveCandleExit || (!inLongPosition && !inShortPosition)) 
        return false;
    
    // For long positions - exit if two consecutive candles closed below EMA9
    if(inLongPosition && secondLastCandleBelowEma && lastCandleBelowEma)
    {
        LogMessage("EXIT SIGNAL: Two consecutive candles closed below EMA9", "!!!");
        return true;
    }
    
    // For short positions - exit if two consecutive candles closed above EMA9
    if(inShortPosition && !secondLastCandleBelowEma && !lastCandleBelowEma)
    {
        LogMessage("EXIT SIGNAL: Two consecutive candles closed above EMA9", "!!!");
        return true;
    }
    
    return false;
}


//+------------------------------------------------------------------+
//| Update candle close vs EMA tracking |
//+------------------------------------------------------------------+
void UpdateCandleEmaStatus(MqlRates &rates[], double &emaBuffer[])
{
    // Only update on new completed candle
    if(rates[1].time != lastCheckedCandleTime)
    {
        lastCheckedCandleTime = rates[1].time;
        
        // Shift previous state
        secondLastCandleBelowEma = lastCandleBelowEma;
        
        // Update with newest completed candle (index 1 is the last completed candle)
        lastCandleBelowEma = rates[1].close < emaBuffer[1];
        
        string candle1Status = lastCandleBelowEma ? "below" : "above";
        string candle2Status = secondLastCandleBelowEma ? "below" : "above";
        
        LogMessage("Candle close status update - Last: " + candle1Status + 
                  " EMA9, Second Last: " + candle2Status + " EMA9");
    }
}


//+------------------------------------------------------------------+
//| Close all existing positions |
//+------------------------------------------------------------------+
void CloseAllPositions(string exitReason = "")
{
    int totalPositions = PositionsTotal();
    if(totalPositions == 0)
    {
        inLongPosition = inShortPosition = false;
        activePositionTicket = 0;
        activePositionOpenPrice = 0.0;
        breakEvenActivated = false;
        safetyNetActivated = false;
        maxDifferential = 0.0;
        hadStrongSignal = false;
        plateauCounter = 0;
        partialCloseExecuted = false;
        for(int i = 0; i < 10; i++) diffHistory[i] = 0.0;
        return;
    }
    
    for(int i = totalPositions - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol)
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
            }
            else
            {
                request.type = ORDER_TYPE_BUY;
                request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            }
            
            request.volume = positionVolume;
            request.position = ticket;
            request.comment = "Close " + (positionType == POSITION_TYPE_BUY ? "LONG" : "SHORT") + 
                             (exitReason == "" ? " position" : " - " + exitReason);
            request.deviation = 10;
            
            // Retry logic
            bool orderSent = false;
            int retryCount = 0;
            
            while(!orderSent && retryCount < MaxTradeRetries)
            {
                bool sent = OrderSend(request, result);
                
                if(sent && result.retcode == TRADE_RETCODE_DONE)
                {
                    string posType = (positionType == POSITION_TYPE_BUY) ? "LONG" : "SHORT";
                    double closePrice = request.price;
                    double priceDiff = (posType == "LONG") ? (closePrice - openPrice) : (openPrice - closePrice);
                    
                    string beStatus = "";
                    if(safetyNetActivated)
                        beStatus = " (Safety Net was active)";
                    else if(breakEvenActivated)
                        beStatus = " (Break-Even was active)";
                    
                    string partialStatus = partialCloseExecuted ? 
                                          " (After partial close of " + DoubleToString(PartialCloseSize, 2) + " lots)" : "";
                    
                    LogMessage(posType + " position closed - Open: " + DoubleToString(openPrice, 2) +
                              " - Close: " + DoubleToString(closePrice, 2) +
                              " - P/L: " + DoubleToString(currentProfit, 2) +
                              " - Points: " + DoubleToString(priceDiff, 2) +
                              " - Volume: " + DoubleToString(positionVolume, 2) +
                              " - Ticket: " + IntegerToString(ticket) +
                              " - Max Diff: " + DoubleToString(maxDifferential, 2) +
                              " - Had Strong Signal: " + (hadStrongSignal ? "YES" : "NO") +
                              beStatus + partialStatus +
                              (exitReason != "" ? " - Reason: " + exitReason : ""), ">>>");
                    
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
                        LogMessage("Retrying close - Attempt " + IntegerToString(retryCount + 1) + 
                                  " - Error: " + IntegerToString(result.retcode));
                        Sleep(500);
                    }
                    else
                    {
                        LogMessage("Failed to close position after " + IntegerToString(MaxTradeRetries) + 
                                  " attempts - Error: " + IntegerToString(result.retcode), "!!!");
                        failedTrades++;
                    }
                }
            }
        }
    }
    
    inLongPosition = inShortPosition = false;
    activePositionTicket = 0;
    activePositionOpenPrice = 0.0;
    breakEvenActivated = false;
    safetyNetActivated = false;
    maxDifferential = 0.0;
    hadStrongSignal = false;
    plateauCounter = 0;
    partialCloseExecuted = false;
    for(int i = 0; i < 10; i++) diffHistory[i] = 0.0;
}


//+------------------------------------------------------------------+
//| Execute Order |
//+------------------------------------------------------------------+
void ExecuteOrder(bool isBuy)
{
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = EntryLotSize;
    request.type = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    request.price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Stop Loss
    request.sl = CalculateStopLossLevel(isBuy, request.price);
    
    request.deviation = 10;
    request.comment = "ETH EMA9-VWAP " + (isBuy ? "Buy" : "Sell");
    
    // Retry logic
    bool orderSent = false;
    int retryCount = 0;
    
    while(!orderSent && retryCount < MaxTradeRetries)
    {
        bool sent = OrderSend(request, result);
        
        if(sent && result.retcode == TRADE_RETCODE_DONE)
        {
            inLongPosition = isBuy;
            inShortPosition = !isBuy;
            isBuy ? bullishCrossoverTraded = true : bearishCrossoverTraded = true;
            activePositionTicket = result.deal;
            activePositionOpenPrice = request.price;
            currentStopLossLevel = request.sl;
            partialCloseExecuted = false;
            
            // Reset break-even tracking
            breakEvenActivated = false;
            safetyNetActivated = false;
            maxDifferential = 0.0;
            hadStrongSignal = false;
            plateauCounter = 0;
            for(int i = 0; i < 10; i++) diffHistory[i] = 0.0;
            lastBreakEvenCheckTime = TimeCurrent();
            
            string entryMsg = (isBuy ? "LONG" : "SHORT") + " Entry executed at " + TimeToString(TimeCurrent()) + 
                             " - Price: " + DoubleToString(request.price, 2) +
                             " - SL: " + DoubleToString(request.sl, 2) +
                             " - Lot: " + DoubleToString(EntryLotSize, 2) + 
                             " - Ticket: " + IntegerToString(result.deal) +
                             " - Partial target: $" + DoubleToString(PartialCloseProfitUSD, 2) +
                             " - Final target: $" + DoubleToString(FinalProfitTargetUSD, 2);
                             
            LogMessage(entryMsg, ">>>");
            orderSent = true;
            totalTrades++;
            successfulTrades++;
        }
        else
        {
            retryCount++;
            if(retryCount < MaxTradeRetries)
            {
                LogMessage("Retrying " + (isBuy ? "LONG" : "SHORT") + " entry - Attempt " + 
                         IntegerToString(retryCount + 1) + " - Error: " + IntegerToString(result.retcode));
                Sleep(500);
            }
            else
            {
                LogMessage((isBuy ? "LONG" : "SHORT") + " Entry failed after " + 
                          IntegerToString(MaxTradeRetries) + " attempts - Error: " + 
                          IntegerToString(result.retcode), "!!!");
                failedTrades++;
            }
        }
    }
}


//+------------------------------------------------------------------+
//| Process trading signals |
//+------------------------------------------------------------------+
void ProcessCrossover(bool isBullish, datetime currentTime)
{
    string crossType = isBullish ? "BULLISH" : "BEARISH";
    
    // Update timestamps
    if(isBullish)
    {
        lastBullishCrossoverTime = currentTime;
        bearishCrossoverTraded = false;
    }
    else
    {
        lastBearishCrossoverTime = currentTime;
        bullishCrossoverTraded = false;
    }
    
    LogMessage(crossType + " CROSSOVER | EMA9: " + DoubleToString(currentEma, 2) + 
              " | VWAP: " + DoubleToString(currentVwap, 2) +
              " | Diff: " + DoubleToString(currentDiff, 2), ">>>");
    
    // Close opposite positions
    if((isBullish && inShortPosition) || (!isBullish && inLongPosition))
    {
        LogMessage("Closing " + (!isBullish ? "LONG" : "SHORT") + " position due to " + 
                  crossType + " crossover", "!!!");
        CloseAllPositions(crossType + " Crossover Signal");
        
        // Reset traded flags to allow new entries
        if(isBullish) bullishCrossoverTraded = false;
        else bearishCrossoverTraded = false;
    }
    
    // Check if we can take a new position
    bool canTrade = isBullish ? 
                   (!bullishCrossoverTraded && currentTime >= lastBullishSignalTime + MinSecondsBetweenSignals) : 
                   (!bearishCrossoverTraded && currentTime >= lastBearishSignalTime + MinSecondsBetweenSignals);
    
    if(canTrade)
    {
        if(isBullish) lastBullishSignalTime = currentTime; 
        else lastBearishSignalTime = currentTime;
        
        // Flag for pending trade if not already in position
        if((isBullish && !inLongPosition) || (!isBullish && !inShortPosition))
        {
            tradePending = true;
            pendingTradeType = isBullish ? "LONG" : "SHORT";
        }
        else
        {
            LogMessage("Already in " + (isBullish ? "LONG" : "SHORT") + " position, no action taken", "---");
        }
    }
    else
    {
        LogMessage(crossType + " crossover already traded - ONE-TRADE-PER-CROSSOVER rule", "---");
    }
}


//+------------------------------------------------------------------+
//| Expert tick function |
//+------------------------------------------------------------------+
void OnTick()
{
    // Get current candle data
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copied = CopyRates(_Symbol, PERIOD_H1, 0, 5, rates);
    
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
        Print("Not enough indicator data. VWAP: ", vwapCopied, ", EMA: ", emaCopied);
        return;
    }
    
    // Current and previous values
    currentVwap = vwapBuffer[0];
    currentEma = ema9Buffer[0];
    currentDiff = currentEma - currentVwap;
    
    double prevVwap = vwapBuffer[1];
    double prevEma = ema9Buffer[1];
    double prevDiff = prevEma - prevVwap;
    
    // Update market state
    currentMarketState = currentDiff > 0 ? "BULLISH" : (currentDiff < 0 ? "BEARISH" : "NEUTRAL");
    
    // Store current differential value for pattern detection
    if(activePositionTicket > 0)
    {
        // Shift values
        for(int i = 9; i > 0; i--)
            diffHistory[i] = diffHistory[i-1];
        
        // Add current value
        diffHistory[0] = currentDiff;
    }
    
    // Check for partial close opportunity
    if(activePositionTicket > 0 && !partialCloseExecuted)
    {
        bool partialClosed = ExecutePartialClose();
        if(partialClosed)
        {
            LogMessage("Partial close executed successfully", ">>>");
        }
    }
    
    // Check if final profit target reached
    if(activePositionTicket > 0 && partialCloseExecuted && IsFinalTargetReached())
    {
        LogMessage("FINAL TARGET REACHED - Closing remaining position", ">>>");
        CloseAllPositions("Final Target Reached");
        return;
    }
    
    // Check break-even conditions
    if(UseBreakEven && (inLongPosition || inShortPosition) && !breakEvenActivated && !safetyNetActivated)
    {
        // First check for strong signal safety net activation
        if(hadStrongSignal)
        {
            bool safetyNetApplied = CheckStrongSignalRecovery();
            if(safetyNetApplied)
            {
                safetyNetActivated = true;
                LogMessage("Safety net activated for strong signal with plateau", "!!!");
            }
        }
        // Then check regular break-even for weak signals if safety net wasn't activated
        else
        {
            bool breakEvenApplied = CheckBreakEvenConditions();
            if(breakEvenApplied)
            {
                breakEvenActivated = true;
                LogMessage("Break-even activated via regular conditions", "!!!");
            }
        }
    }
    
    // Check if stop loss hit - highest priority
    if(IsStopLossHit())
    {
        string slType = "Fixed USD";
        if(UseStopLossAtVWAP) slType = "VWAP";
        if(safetyNetActivated) slType = "Safety Net";
        else if(breakEvenActivated) slType = "Break-Even";
        
        LogMessage("Stop Loss triggered - closing position", "!!!");
        CloseAllPositions("Stop Loss at " + slType);
        return;
    }
    
    // Update candle close vs EMA tracking
    UpdateCandleEmaStatus(rates, ema9Buffer);
    
    // Check for consecutive candle exit condition
    if(CheckConsecutiveCandleExit())
    {
        string posType = inLongPosition ? "LONG" : "SHORT";
        string exitReason = posType + " position closed due to consecutive candle exit strategy";
        CloseAllPositions(exitReason);
        return;
    }
    
    // Check for new candle and log status
    static datetime lastCandleTime = 0;
    bool isNewCandle = (rates[0].time != lastCandleTime);
    
    if(isNewCandle)
    {
        lastCandleTime = rates[0].time;
        
        // Extended logging with break-even status if in position
        string beStatus = "";
        if(inLongPosition || inShortPosition)
        {
            if(safetyNetActivated)
                beStatus = " | BE: Safety Net";
            else if(breakEvenActivated)
                beStatus = " | BE: Active";
            else
                beStatus = " | BE: Inactive";
                
            beStatus += " | MaxDiff: " + DoubleToString(maxDifferential, 2);
            beStatus += " | Strong: " + (hadStrongSignal ? "YES" : "NO");
            
            if(plateauCounter > 0)
                beStatus += " | Plateau: " + IntegerToString(plateauCounter) + "/" + IntegerToString(MinCandlesForPlateau);
                
            if(partialCloseExecuted)
                beStatus += " | Partial Close: Done";
        }
        
        LogMessage("Time: " + TimeToString(rates[0].time) + 
                  " | VWAP: " + DoubleToString(currentVwap, 2) + 
                  " | EMA9: " + DoubleToString(currentEma, 2) + 
                  " | Diff: " + DoubleToString(currentDiff, 2) + 
                  " | Status: " + currentMarketState +
                  beStatus);
    }
    
    // Current time
    datetime currentTime = TimeCurrent();
    
    // Check for crossovers
    bool bullishCrossover = (prevDiff <= 0 && currentDiff > 0);
    bool bearishCrossover = (prevDiff >= 0 && currentDiff < 0);
    
    // Process crossovers
    if(bullishCrossover) ProcessCrossover(true, currentTime);
    if(bearishCrossover) ProcessCrossover(false, currentTime);
    
    // Check if pending trade meets confirmation criteria
    if(tradePending)
    {
        bool confirmSignal = false;
        
        if(pendingTradeType == "LONG" && currentDiff >= MinCrossoverDifference)
        {
            LogMessage("LONG ENTRY CONFIRMED | Diff: " + DoubleToString(currentDiff, 2) +
                      " | Minimum difference threshold met", ">>>");
            ExecuteOrder(true);
            confirmSignal = true;
        }
        else if(pendingTradeType == "SHORT" && currentDiff <= -MinCrossoverDifference)
        {
            LogMessage("SHORT ENTRY CONFIRMED | Diff: " + DoubleToString(currentDiff, 2) +
                      " | Minimum difference threshold met", ">>>");
            ExecuteOrder(false);
            confirmSignal = true;
        }
        
        if(confirmSignal) tradePending = false;
    }
    
    // Check for extreme conditions without crossovers
    if(!tradePending)
    {
        // Strong bullish divergence while in SHORT
        if(inShortPosition && currentDiff >= MinCrossoverDifference * 1.5)
        {
            LogMessage("STRONG BULLISH DIVERGENCE without crossover | Diff: " + 
                      DoubleToString(currentDiff, 2), "!!!");
            
            CloseAllPositions("Strong Bullish Divergence");
            
            if(!bullishCrossoverTraded && (currentTime >= lastBullishSignalTime + MinSecondsBetweenSignals))
            {
                lastBullishSignalTime = currentTime;
                LogMessage("Opening LONG on strong divergence (no previous bullish crossover traded)", ">>>");
                ExecuteOrder(true);
                bullishCrossoverTraded = true;
            }
        }
        // Strong bearish divergence while in LONG
        else if(inLongPosition && currentDiff <= -MinCrossoverDifference * 1.5)
        {
            LogMessage("STRONG BEARISH DIVERGENCE without crossover | Diff: " + 
                      DoubleToString(currentDiff, 2), "!!!");
            
            CloseAllPositions("Strong Bearish Divergence");
            
            if(!bearishCrossoverTraded && (currentTime >= lastBearishSignalTime + MinSecondsBetweenSignals))
            {
                lastBearishSignalTime = currentTime;
                LogMessage("Opening SHORT on strong divergence (no previous bearish crossover traded)", ">>>");
                ExecuteOrder(false);
                bearishCrossoverTraded = true;
            }
        }
        // Strong conditions with no position
        else if(!inLongPosition && !inShortPosition)
        {
            if(currentDiff <= -MinCrossoverDifference && !bearishCrossoverTraded && 
               currentTime >= lastBearishSignalTime + MinSecondsBetweenSignals)
            {
                LogMessage("SIGNIFICANT BEARISH CONDITION with no position | Diff: " + 
                          DoubleToString(currentDiff, 2), "!!!");
                lastBearishSignalTime = currentTime;
                ExecuteOrder(false);
                bearishCrossoverTraded = true;
            }
            else if(currentDiff >= MinCrossoverDifference && !bullishCrossoverTraded && 
                    currentTime >= lastBullishSignalTime + MinSecondsBetweenSignals)
            {
                LogMessage("SIGNIFICANT BULLISH CONDITION with no position | Diff: " + 
                          DoubleToString(currentDiff, 2), "!!!");
                lastBullishSignalTime = currentTime;
                ExecuteOrder(true);
                bullishCrossoverTraded = true;
            }
        }
    }
    
    // Cancel pending trades if conditions reversed
    if(tradePending)
    {
        if((pendingTradeType == "LONG" && currentDiff < 0) || 
           (pendingTradeType == "SHORT" && currentDiff > 0))
        {
            LogMessage(pendingTradeType + " trade setup CANCELLED - Market conditions reversed", "!!!");
            tradePending = false;
        }
    }
}


//+------------------------------------------------------------------+
//| Expert deinitialization function |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Generate summary statistics
    LogMessage("=== STRATEGY SUMMARY ===");
    LogMessage("Test ended at: " + TimeToString(TimeCurrent()));
    LogMessage("Total trades executed: " + IntegerToString(totalTrades));
    LogMessage("Successful trade operations: " + IntegerToString(successfulTrades));
    LogMessage("Failed trade operations: " + IntegerToString(failedTrades));
    LogMessage("Total realized profit/loss: " + DoubleToString(totalProfit, 2));
    
    // Log open positions at shutdown
    int openPositions = PositionsTotal();
    if(openPositions > 0)
    {
        double unrealizedProfit = 0.0;
        
        LogMessage("=== OPEN POSITIONS AT SHUTDOWN ===");
        for(int i = 0; i < openPositions; i++)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
                long positionType = PositionGetInteger(POSITION_TYPE);
                double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double currentProfit = PositionGetDouble(POSITION_PROFIT);
                double volume = PositionGetDouble(POSITION_VOLUME);
                double stopLoss = PositionGetDouble(POSITION_SL);
                string type = (positionType == POSITION_TYPE_BUY) ? "LONG" : "SHORT";
                
                string beStatus = "";
                if(safetyNetActivated)
                    beStatus = " - Safety Net Active";
                else if(breakEvenActivated)
                    beStatus = " - Break-Even Active";
                
                string partialStatus = partialCloseExecuted ? " - Partial Close Executed" : "";
                
                LogMessage("Position #" + IntegerToString(i+1) + ": " + type + 
                         " - Open: " + DoubleToString(openPrice, 2) +
                         " - SL: " + DoubleToString(stopLoss, 2) +
                         " - Vol: " + DoubleToString(volume, 2) +
                         " - P/L: " + DoubleToString(currentProfit, 2) +
                         beStatus + partialStatus);
                
                unrealizedProfit += currentProfit;
            }
        }
        
        LogMessage("Total unrealized profit/loss: " + DoubleToString(unrealizedProfit, 2));
        LogMessage("Combined total (realized + unrealized): " + DoubleToString(totalProfit + unrealizedProfit, 2));
    }
    
    // Cleanup
    if(fileHandle != INVALID_HANDLE) FileClose(fileHandle);
    if(vwapHandle != INVALID_HANDLE) IndicatorRelease(vwapHandle);
    if(ema9Handle != INVALID_HANDLE) IndicatorRelease(ema9Handle);
    
    ArrayFree(vwapBuffer);
    ArrayFree(ema9Buffer);
    
    Print("KC 4.7 H1 Partial Close EA deinitialized");
}