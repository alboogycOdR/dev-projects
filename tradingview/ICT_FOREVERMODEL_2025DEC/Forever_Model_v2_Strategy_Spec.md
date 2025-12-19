# Forever Model v2.0 Strategy Specification

## Document Information
- **Version:** 1.0
- **Date:** December 18, 2025
- **Base Indicator:** Forever Model v2.0
- **Target Platform:** TradingView Pine Script v6

---

## 1. Executive Summary

This specification defines the conversion of the Forever Model v2.0 indicator into a fully automated TradingView strategy capable of executing long and short trades based on ICT (Inner Circle Trader) concepts including Fair Value Gaps (FVG), Change in State of Delivery (CISD), and Smart Money Theory (SMT) divergences.

---

## 2. Strategy Overview

### 2.1 Core Trading Logic

The strategy generates trades based on the following sequence:

1. **HTF FVG Detection** → Identifies institutional order flow imbalances
2. **FVG Mitigation** → Price returns to fill the imbalance (entry zone)
3. **Pivot Formation** → Establishes confirmation level
4. **CISD Confirmation** → Price closes beyond pivot (trade trigger)
5. **Position Management** → Stop loss, take profit, and exit logic

### 2.2 Trade Direction

| Signal Type | Entry Trigger | Position |
|-------------|---------------|----------|
| Bullish CISD | Close > Pivot High after Bullish FVG mitigation | LONG |
| Bearish CISD | Close < Pivot Low after Bearish FVG mitigation | SHORT |

---

## 3. Strategy Parameters

### 3.1 Strategy Declaration

```pinescript
strategy(
    title = 'Forever Model v2.0 Strategy',
    overlay = true,
    initial_capital = 10000,
    default_qty_type = strategy.percent_of_equity,
    default_qty_value = 100,
    commission_type = strategy.commission.percent,
    commission_value = 0.04,
    slippage = 2,
    pyramiding = 0,
    calc_on_every_tick = false,
    process_orders_on_close = true,
    max_bars_back = 501
)
```

### 3.2 Input Groups

#### 3.2.1 Strategy Settings (NEW)
```pinescript
// ══════════════════════════════════════════════════════════════════════════════
// STRATEGY SETTINGS
// ══════════════════════════════════════════════════════════════════════════════

strategyGroup = 'Strategy Settings'

// Trade Direction
tradeDirection = input.string('Both', 'Trade Direction', 
    options = ['Both', 'Long Only', 'Short Only'], 
    group = strategyGroup,
    tooltip = 'Select which direction(s) to trade')

// Position Sizing
positionSizeType = input.string('Percent of Equity', 'Position Size Type',
    options = ['Percent of Equity', 'Fixed Contracts', 'Fixed USD', 'Risk-Based'],
    group = strategyGroup)

positionSizeValue = input.float(100.0, 'Position Size Value',
    minval = 0.1,
    group = strategyGroup,
    tooltip = 'Percent (1-100), Contracts, USD amount, or Risk % depending on type')

// Risk Management
useStopLoss = input.bool(true, 'Use Stop Loss', group = strategyGroup)
stopLossType = input.string('Signal-Based', 'Stop Loss Type',
    options = ['Signal-Based', 'Fixed Points', 'Fixed Percent', 'ATR-Based'],
    group = strategyGroup,
    tooltip = 'Signal-Based uses max/min price from signal creation to confirmation')

fixedStopPoints = input.float(50.0, 'Fixed Stop (Points)', 
    minval = 1, 
    group = strategyGroup)

fixedStopPercent = input.float(2.0, 'Fixed Stop (%)', 
    minval = 0.1, 
    group = strategyGroup)

atrStopMultiplier = input.float(2.0, 'ATR Stop Multiplier', 
    minval = 0.5, 
    group = strategyGroup)

atrStopLength = input.int(14, 'ATR Length', 
    minval = 1, 
    group = strategyGroup)

// Take Profit
useTakeProfit = input.bool(true, 'Use Take Profit', group = strategyGroup)
takeProfitType = input.string('Risk:Reward', 'Take Profit Type',
    options = ['Risk:Reward', 'Fixed Points', 'Fixed Percent', 'ATR-Based', 'ERL Target'],
    group = strategyGroup)

riskRewardRatio = input.float(2.0, 'Risk:Reward Ratio', 
    minval = 0.5, 
    group = strategyGroup,
    tooltip = 'Take profit at X times the risk (stop loss distance)')

fixedTPPoints = input.float(100.0, 'Fixed TP (Points)', 
    minval = 1, 
    group = strategyGroup)

fixedTPPercent = input.float(4.0, 'Fixed TP (%)', 
    minval = 0.1, 
    group = strategyGroup)

atrTPMultiplier = input.float(4.0, 'ATR TP Multiplier', 
    minval = 1.0, 
    group = strategyGroup)

// Partial Take Profit
usePartialTP = input.bool(false, 'Use Partial Take Profit', group = strategyGroup)
partialTPPercent = input.float(50.0, 'Partial TP Size (%)', 
    minval = 10, maxval = 90, 
    group = strategyGroup,
    tooltip = 'Percentage of position to close at first target')

partialTPRatio = input.float(1.0, 'Partial TP R:R', 
    minval = 0.5, 
    group = strategyGroup,
    tooltip = 'Risk:Reward ratio for partial take profit')

// Break Even
useBreakEven = input.bool(false, 'Move Stop to Break Even', group = strategyGroup)
breakEvenTriggerRR = input.float(1.0, 'Break Even Trigger (R:R)', 
    minval = 0.5, 
    group = strategyGroup,
    tooltip = 'Move stop to break even when price reaches this R:R')

breakEvenOffset = input.float(0.0, 'Break Even Offset (Points)', 
    minval = 0, 
    group = strategyGroup,
    tooltip = 'Additional offset beyond entry for break even stop')

// Trailing Stop
useTrailingStop = input.bool(false, 'Use Trailing Stop', group = strategyGroup)
trailingStopType = input.string('ATR-Based', 'Trailing Stop Type',
    options = ['Fixed Points', 'Fixed Percent', 'ATR-Based'],
    group = strategyGroup)

trailingStopActivation = input.float(1.5, 'Trailing Activation (R:R)', 
    minval = 0.5, 
    group = strategyGroup,
    tooltip = 'Activate trailing stop when price reaches this R:R')

trailingStopDistance = input.float(1.0, 'Trailing Distance', 
    minval = 0.1, 
    group = strategyGroup,
    tooltip = 'Points, Percent, or ATR multiplier depending on type')
```

#### 3.2.2 Trade Filters (NEW)
```pinescript
// ══════════════════════════════════════════════════════════════════════════════
// TRADE FILTERS
// ══════════════════════════════════════════════════════════════════════════════

filterGroup = 'Trade Filters'

// Time Filters
useTimeFilter = input.bool(false, 'Enable Time Filter', group = filterGroup)
tradingStartHour = input.int(7, 'Trading Start Hour', 
    minval = 0, maxval = 23, 
    group = filterGroup)

tradingStartMinute = input.int(0, 'Trading Start Minute', 
    minval = 0, maxval = 59, 
    group = filterGroup)

tradingEndHour = input.int(16, 'Trading End Hour', 
    minval = 0, maxval = 23, 
    group = filterGroup)

tradingEndMinute = input.int(0, 'Trading End Minute', 
    minval = 0, maxval = 59, 
    group = filterGroup)

// Day Filters
tradeMon = input.bool(true, 'Trade Monday', group = filterGroup)
tradeTue = input.bool(true, 'Trade Tuesday', group = filterGroup)
tradeWed = input.bool(true, 'Trade Wednesday', group = filterGroup)
tradeThu = input.bool(true, 'Trade Thursday', group = filterGroup)
tradeFri = input.bool(true, 'Trade Friday', group = filterGroup)

// Max Trades
maxTradesPerDay = input.int(0, 'Max Trades Per Day (0 = unlimited)', 
    minval = 0, 
    group = filterGroup)

maxConsecutiveLosses = input.int(0, 'Max Consecutive Losses (0 = unlimited)', 
    minval = 0, 
    group = filterGroup,
    tooltip = 'Stop trading after X consecutive losses until next session')

// Volatility Filter
useVolatilityFilter = input.bool(false, 'Use Volatility Filter', group = filterGroup)
minATR = input.float(0.0, 'Minimum ATR', 
    minval = 0, 
    group = filterGroup)

maxATR = input.float(0.0, 'Maximum ATR (0 = no max)', 
    minval = 0, 
    group = filterGroup)

// Spread Filter (for forex/CFD)
useSpreadFilter = input.bool(false, 'Use Spread Filter', group = filterGroup)
maxSpreadPoints = input.float(5.0, 'Max Spread (Points)', 
    minval = 0, 
    group = filterGroup)
```

#### 3.2.3 Signal Filters (NEW)
```pinescript
// ══════════════════════════════════════════════════════════════════════════════
// SIGNAL FILTERS
// ══════════════════════════════════════════════════════════════════════════════

signalFilterGroup = 'Signal Filters'

// FVG Quality Filters
minFVGSize = input.float(0.0, 'Minimum FVG Size (Points)', 
    minval = 0, 
    group = signalFilterGroup,
    tooltip = 'Filter out FVGs smaller than this size')

maxFVGSize = input.float(0.0, 'Maximum FVG Size (0 = no max)', 
    minval = 0, 
    group = signalFilterGroup,
    tooltip = 'Filter out FVGs larger than this size')

minFVGSizeATR = input.float(0.0, 'Minimum FVG Size (ATR Multiple)', 
    minval = 0, 
    group = signalFilterGroup)

maxFVGSizeATR = input.float(0.0, 'Maximum FVG Size (ATR Multiple, 0 = no max)', 
    minval = 0, 
    group = signalFilterGroup)

// Confirmation Quality
maxBarsToConfirm = input.int(0, 'Max Bars to Confirmation (0 = unlimited)', 
    minval = 0, 
    group = signalFilterGroup,
    tooltip = 'Cancel pending signal if not confirmed within X bars')

minBarsToConfirm = input.int(0, 'Min Bars to Confirmation', 
    minval = 0, 
    group = signalFilterGroup,
    tooltip = 'Require at least X bars between signal creation and confirmation')

// SMT Requirement (from indicator)
requireSMTConfirmation = input.bool(false, 'Require SMT for Entry', 
    group = signalFilterGroup,
    tooltip = 'Only enter trades when SMT divergence confirms signal')

// ERL Alignment
requireERLAlignment = input.bool(false, 'Require ERL Alignment', 
    group = signalFilterGroup,
    tooltip = 'Long: price below ERL high, Short: price above ERL low')

// HTF Bias Alignment
useHTFBiasFilter = input.bool(false, 'Use HTF Bias Filter', 
    group = signalFilterGroup)

htfBiasTimeframe = input.timeframe('D', 'HTF Bias Timeframe', 
    group = signalFilterGroup)

htfBiasMethod = input.string('Candle Direction', 'HTF Bias Method',
    options = ['Candle Direction', 'EMA Trend', 'Price vs VWAP'],
    group = signalFilterGroup)
```

#### 3.2.4 Exit Rules (NEW)
```pinescript
// ══════════════════════════════════════════════════════════════════════════════
// EXIT RULES
// ══════════════════════════════════════════════════════════════════════════════

exitGroup = 'Exit Rules'

// Opposite Signal Exit
exitOnOppositeSignal = input.bool(true, 'Exit on Opposite Signal', 
    group = exitGroup,
    tooltip = 'Close position when opposite direction signal is confirmed')

// Time-Based Exit
useTimeExit = input.bool(false, 'Use Time-Based Exit', group = exitGroup)
exitAfterBars = input.int(20, 'Exit After X Bars', 
    minval = 1, 
    group = exitGroup)

// End of Day Exit
useEODExit = input.bool(false, 'Exit at End of Day', group = exitGroup)
eodExitHour = input.int(15, 'EOD Exit Hour', 
    minval = 0, maxval = 23, 
    group = exitGroup)

eodExitMinute = input.int(45, 'EOD Exit Minute', 
    minval = 0, maxval = 59, 
    group = exitGroup)

// FVG Invalidation Exit
exitOnFVGInvalidation = input.bool(false, 'Exit on FVG Full Mitigation', 
    group = exitGroup,
    tooltip = 'Close position if the triggering FVG becomes fully mitigated')

// New HTF Candle Exit
exitOnNewHTFCandle = input.bool(false, 'Exit on New HTF Candle', 
    group = exitGroup,
    tooltip = 'Close position when a new HTF candle forms')
```

---

## 4. Entry Logic

### 4.1 Long Entry Conditions

```pinescript
// ══════════════════════════════════════════════════════════════════════════════
// LONG ENTRY CONDITIONS
// ══════════════════════════════════════════════════════════════════════════════

// Core Signal (from indicator)
bool bullishCISDConfirmed = false  // Set when close > pendingBullish.confirmationLevel

// Trade Direction Filter
bool longAllowed = tradeDirection == 'Both' or tradeDirection == 'Long Only'

// Session Filter (from indicator)
bool sessionAllowsEntry = not enableSessionFilter or isInSession()

// Time Filter
bool timeFilterPassed = not useTimeFilter or isWithinTradingHours()

// Day Filter  
bool dayFilterPassed = isDayAllowed()

// Max Trades Filter
bool maxTradesFilterPassed = maxTradesPerDay == 0 or dailyTradeCount < maxTradesPerDay

// Consecutive Losses Filter
bool lossFilterPassed = maxConsecutiveLosses == 0 or consecutiveLosses < maxConsecutiveLosses

// Volatility Filter
bool volatilityFilterPassed = not useVolatilityFilter or isVolatilityAcceptable()

// SMT Filter (if enabled)
bool smtFilterPassed = not requireSMTConfirmation or hasBullishSMT()

// ERL Alignment Filter
bool erlFilterPassed = not requireERLAlignment or (close < erlHighLevel or na(erlHighLevel))

// HTF Bias Filter
bool htfBiasFilterPassed = not useHTFBiasFilter or getHTFBias() >= 0

// FVG Quality Filters
bool fvgQualityPassed = checkFVGQuality(pendingBullish)

// Confirmation Timing Filter
bool confirmationTimingPassed = checkConfirmationTiming(pendingBullish)

// No Existing Position
bool noLongPosition = strategy.position_size <= 0

// ══════════════════════════════════════════════════════════════════════════════
// FINAL LONG ENTRY CONDITION
// ══════════════════════════════════════════════════════════════════════════════

bool longEntryCondition = bullishCISDConfirmed
    and longAllowed
    and sessionAllowsEntry
    and timeFilterPassed
    and dayFilterPassed
    and maxTradesFilterPassed
    and lossFilterPassed
    and volatilityFilterPassed
    and smtFilterPassed
    and erlFilterPassed
    and htfBiasFilterPassed
    and fvgQualityPassed
    and confirmationTimingPassed
    and noLongPosition
```

### 4.2 Short Entry Conditions

```pinescript
// ══════════════════════════════════════════════════════════════════════════════
// SHORT ENTRY CONDITIONS
// ══════════════════════════════════════════════════════════════════════════════

// Core Signal (from indicator)
bool bearishCISDConfirmed = false  // Set when close < pendingBearish.confirmationLevel

// Trade Direction Filter
bool shortAllowed = tradeDirection == 'Both' or tradeDirection == 'Short Only'

// Session Filter (from indicator)
bool sessionAllowsEntry = not enableSessionFilter or isInSession()

// Time Filter
bool timeFilterPassed = not useTimeFilter or isWithinTradingHours()

// Day Filter
bool dayFilterPassed = isDayAllowed()

// Max Trades Filter
bool maxTradesFilterPassed = maxTradesPerDay == 0 or dailyTradeCount < maxTradesPerDay

// Consecutive Losses Filter
bool lossFilterPassed = maxConsecutiveLosses == 0 or consecutiveLosses < maxConsecutiveLosses

// Volatility Filter
bool volatilityFilterPassed = not useVolatilityFilter or isVolatilityAcceptable()

// SMT Filter (if enabled)
bool smtFilterPassed = not requireSMTConfirmation or hasBearishSMT()

// ERL Alignment Filter
bool erlFilterPassed = not requireERLAlignment or (close > erlLowLevel or na(erlLowLevel))

// HTF Bias Filter
bool htfBiasFilterPassed = not useHTFBiasFilter or getHTFBias() <= 0

// FVG Quality Filters
bool fvgQualityPassed = checkFVGQuality(pendingBearish)

// Confirmation Timing Filter
bool confirmationTimingPassed = checkConfirmationTiming(pendingBearish)

// No Existing Position
bool noShortPosition = strategy.position_size >= 0

// ══════════════════════════════════════════════════════════════════════════════
// FINAL SHORT ENTRY CONDITION
// ══════════════════════════════════════════════════════════════════════════════

bool shortEntryCondition = bearishCISDConfirmed
    and shortAllowed
    and sessionAllowsEntry
    and timeFilterPassed
    and dayFilterPassed
    and maxTradesFilterPassed
    and lossFilterPassed
    and volatilityFilterPassed
    and smtFilterPassed
    and erlFilterPassed
    and htfBiasFilterPassed
    and fvgQualityPassed
    and confirmationTimingPassed
    and noShortPosition
```

---

## 5. Position Sizing Logic

### 5.1 Position Size Calculation

```pinescript
// ══════════════════════════════════════════════════════════════════════════════
// POSITION SIZE CALCULATION
// ══════════════════════════════════════════════════════════════════════════════

calculatePositionSize(float entryPrice, float stopPrice) =>
    float posSize = 0.0
    float riskPerUnit = math.abs(entryPrice - stopPrice)
    
    switch positionSizeType
        'Percent of Equity' =>
            posSize := (strategy.equity * positionSizeValue / 100) / entryPrice
        
        'Fixed Contracts' =>
            posSize := positionSizeValue
        
        'Fixed USD' =>
            posSize := positionSizeValue / entryPrice
        
        'Risk-Based' =>
            // Risk X% of equity on the trade
            float riskAmount = strategy.equity * positionSizeValue / 100
            if riskPerUnit > 0
                posSize := riskAmount / riskPerUnit
            else
                posSize := 0
    
    // Apply contract size adjustments for futures/forex
    posSize := adjustForContractSize(posSize)
    
    // Ensure minimum position size
    posSize := math.max(posSize, syminfo.mintick)
    
    posSize
```

### 5.2 Contract Size Adjustment

```pinescript
// Reuse getContractSize() from indicator for futures/forex adjustments
adjustForContractSize(float rawSize) =>
    float adjustedSize = rawSize
    
    if syminfo.type == "forex"
        // Convert to lots (standard lot = 100,000 units)
        adjustedSize := rawSize / 100000
    else if syminfo.type == "futures" or syminfo.type == "future"
        contractSize = getContractSize()
        adjustedSize := rawSize / contractSize
    
    adjustedSize
```

---

## 6. Stop Loss Logic

### 6.1 Stop Loss Calculation

```pinescript
// ══════════════════════════════════════════════════════════════════════════════
// STOP LOSS CALCULATION
// ══════════════════════════════════════════════════════════════════════════════

calculateStopLoss(bool isLong, float entryPrice, float signalStop) =>
    float stopPrice = na
    
    if not useStopLoss
        stopPrice := na
    else
        switch stopLossType
            'Signal-Based' =>
                // Use max/min price from signal creation to confirmation
                stopPrice := signalStop
            
            'Fixed Points' =>
                stopPrice := isLong ? entryPrice - fixedStopPoints * syminfo.mintick : entryPrice + fixedStopPoints * syminfo.mintick
            
            'Fixed Percent' =>
                stopPrice := isLong ? entryPrice * (1 - fixedStopPercent / 100) : entryPrice * (1 + fixedStopPercent / 100)
            
            'ATR-Based' =>
                float atrValue = ta.atr(atrStopLength)
                stopPrice := isLong ? entryPrice - atrValue * atrStopMultiplier : entryPrice + atrValue * atrStopMultiplier
    
    stopPrice
```

### 6.2 Stop Loss Management

```pinescript
// Track position for stop management
var float currentStopLoss = na
var float currentEntryPrice = na
var float initialRisk = na
var bool breakEvenActivated = false
var bool trailingActivated = false

manageStopLoss(bool isLong, float entryPrice, float stopPrice) =>
    float newStop = stopPrice
    
    if not na(currentStopLoss)
        // Calculate current R multiple
        float currentProfit = isLong ? close - entryPrice : entryPrice - close
        float rMultiple = initialRisk > 0 ? currentProfit / initialRisk : 0
        
        // Break Even Logic
        if useBreakEven and not breakEvenActivated
            if rMultiple >= breakEvenTriggerRR
                newStop := isLong ? entryPrice + breakEvenOffset * syminfo.mintick : entryPrice - breakEvenOffset * syminfo.mintick
                breakEvenActivated := true
        
        // Trailing Stop Logic
        if useTrailingStop and rMultiple >= trailingStopActivation
            trailingActivated := true
            float trailDistance = 0.0
            
            switch trailingStopType
                'Fixed Points' =>
                    trailDistance := trailingStopDistance * syminfo.mintick
                'Fixed Percent' =>
                    trailDistance := close * trailingStopDistance / 100
                'ATR-Based' =>
                    trailDistance := ta.atr(atrStopLength) * trailingStopDistance
            
            float trailStop = isLong ? close - trailDistance : close + trailDistance
            
            // Only move stop in favorable direction
            if isLong
                newStop := math.max(nz(currentStopLoss, stopPrice), trailStop)
            else
                newStop := math.min(nz(currentStopLoss, stopPrice), trailStop)
        
        // Ensure stop doesn't move against us
        if isLong
            newStop := math.max(newStop, nz(currentStopLoss, 0))
        else
            newStop := math.min(newStop, nz(currentStopLoss, 999999999))
    
    newStop
```

---

## 7. Take Profit Logic

### 7.1 Take Profit Calculation

```pinescript
// ══════════════════════════════════════════════════════════════════════════════
// TAKE PROFIT CALCULATION
// ══════════════════════════════════════════════════════════════════════════════

calculateTakeProfit(bool isLong, float entryPrice, float stopPrice) =>
    float tpPrice = na
    
    if not useTakeProfit
        tpPrice := na
    else
        float riskDistance = math.abs(entryPrice - stopPrice)
        
        switch takeProfitType
            'Risk:Reward' =>
                float rewardDistance = riskDistance * riskRewardRatio
                tpPrice := isLong ? entryPrice + rewardDistance : entryPrice - rewardDistance
            
            'Fixed Points' =>
                tpPrice := isLong ? entryPrice + fixedTPPoints * syminfo.mintick : entryPrice - fixedTPPoints * syminfo.mintick
            
            'Fixed Percent' =>
                tpPrice := isLong ? entryPrice * (1 + fixedTPPercent / 100) : entryPrice * (1 - fixedTPPercent / 100)
            
            'ATR-Based' =>
                float atrValue = ta.atr(atrStopLength)
                tpPrice := isLong ? entryPrice + atrValue * atrTPMultiplier : entryPrice - atrValue * atrTPMultiplier
            
            'ERL Target' =>
                // Use opposite ERL as target
                if isLong and not na(erlHighLevel) and erlHighLevel > entryPrice
                    tpPrice := erlHighLevel
                else if not isLong and not na(erlLowLevel) and erlLowLevel < entryPrice
                    tpPrice := erlLowLevel
                else
                    // Fallback to R:R
                    tpPrice := isLong ? entryPrice + riskDistance * riskRewardRatio : entryPrice - riskDistance * riskRewardRatio
    
    tpPrice

// Partial Take Profit Calculation
calculatePartialTP(bool isLong, float entryPrice, float stopPrice) =>
    float partialPrice = na
    
    if usePartialTP
        float riskDistance = math.abs(entryPrice - stopPrice)
        float partialReward = riskDistance * partialTPRatio
        partialPrice := isLong ? entryPrice + partialReward : entryPrice - partialReward
    
    partialPrice
```

---

## 8. Trade Execution

### 8.1 Entry Execution

```pinescript
// ══════════════════════════════════════════════════════════════════════════════
// TRADE EXECUTION
// ══════════════════════════════════════════════════════════════════════════════

// Track partial TP state
var bool partialTPTaken = false

// Long Entry
if longEntryCondition
    float entryPrice = close
    float stopPrice = calculateStopLoss(true, entryPrice, pendingBullish.minPrice)
    float tpPrice = calculateTakeProfit(true, entryPrice, stopPrice)
    float partialTP = calculatePartialTP(true, entryPrice, stopPrice)
    float posSize = calculatePositionSize(entryPrice, stopPrice)
    
    // Store trade info
    currentEntryPrice := entryPrice
    currentStopLoss := stopPrice
    initialRisk := entryPrice - stopPrice
    breakEvenActivated := false
    trailingActivated := false
    partialTPTaken := false
    
    // Execute entry
    strategy.entry('Long', strategy.long, qty = posSize)
    
    // Set exit orders
    if useStopLoss and not na(stopPrice)
        strategy.exit('Long SL/TP', 'Long', stop = stopPrice, limit = tpPrice)
    else if useTakeProfit and not na(tpPrice)
        strategy.exit('Long TP', 'Long', limit = tpPrice)
    
    // Track daily trades
    dailyTradeCount := dailyTradeCount + 1

// Short Entry
if shortEntryCondition
    float entryPrice = close
    float stopPrice = calculateStopLoss(false, entryPrice, pendingBearish.maxPrice)
    float tpPrice = calculateTakeProfit(false, entryPrice, stopPrice)
    float partialTP = calculatePartialTP(false, entryPrice, stopPrice)
    float posSize = calculatePositionSize(entryPrice, stopPrice)
    
    // Store trade info
    currentEntryPrice := entryPrice
    currentStopLoss := stopPrice
    initialRisk := stopPrice - entryPrice
    breakEvenActivated := false
    trailingActivated := false
    partialTPTaken := false
    
    // Execute entry
    strategy.entry('Short', strategy.short, qty = posSize)
    
    // Set exit orders
    if useStopLoss and not na(stopPrice)
        strategy.exit('Short SL/TP', 'Short', stop = stopPrice, limit = tpPrice)
    else if useTakeProfit and not na(tpPrice)
        strategy.exit('Short TP', 'Short', limit = tpPrice)
    
    // Track daily trades
    dailyTradeCount := dailyTradeCount + 1
```

### 8.2 Exit Execution

```pinescript
// ══════════════════════════════════════════════════════════════════════════════
// EXIT EXECUTION
// ══════════════════════════════════════════════════════════════════════════════

// Opposite Signal Exit
if exitOnOppositeSignal
    if strategy.position_size > 0 and bearishCISDConfirmed
        strategy.close('Long', comment = 'Opposite Signal')
    if strategy.position_size < 0 and bullishCISDConfirmed
        strategy.close('Short', comment = 'Opposite Signal')

// Time-Based Exit
if useTimeExit and strategy.position_size != 0
    int barsInTrade = bar_index - strategy.opentrades.entry_bar_index(0)
    if barsInTrade >= exitAfterBars
        strategy.close_all(comment = 'Time Exit')

// End of Day Exit
if useEODExit and strategy.position_size != 0
    if hour == eodExitHour and minute >= eodExitMinute
        strategy.close_all(comment = 'EOD Exit')

// New HTF Candle Exit
if exitOnNewHTFCandle and strategy.position_size != 0
    if newPeriod
        strategy.close_all(comment = 'New HTF Candle')

// Partial Take Profit Execution
if usePartialTP and not partialTPTaken and strategy.position_size != 0
    bool isLong = strategy.position_size > 0
    float partialTarget = calculatePartialTP(isLong, currentEntryPrice, currentStopLoss)
    
    if not na(partialTarget)
        bool partialHit = isLong ? high >= partialTarget : low <= partialTarget
        
        if partialHit
            float closeQty = strategy.position_size * partialTPPercent / 100
            if isLong
                strategy.close('Long', qty = math.abs(closeQty), comment = 'Partial TP')
            else
                strategy.close('Short', qty = math.abs(closeQty), comment = 'Partial TP')
            partialTPTaken := true

// Dynamic Stop Loss Update
if strategy.position_size != 0
    bool isLong = strategy.position_size > 0
    float newStop = manageStopLoss(isLong, currentEntryPrice, currentStopLoss)
    
    if newStop != currentStopLoss
        currentStopLoss := newStop
        float tpPrice = calculateTakeProfit(isLong, currentEntryPrice, currentStopLoss)
        
        if isLong
            strategy.exit('Long SL/TP', 'Long', stop = currentStopLoss, limit = tpPrice)
        else
            strategy.exit('Short SL/TP', 'Short', stop = currentStopLoss, limit = tpPrice)
```

---

## 9. Helper Functions

### 9.1 Filter Functions

```pinescript
// ══════════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ══════════════════════════════════════════════════════════════════════════════

// Time Filter
isWithinTradingHours() =>
    int currentMinutes = hour * 60 + minute
    int startMinutes = tradingStartHour * 60 + tradingStartMinute
    int endMinutes = tradingEndHour * 60 + tradingEndMinute
    
    if startMinutes < endMinutes
        currentMinutes >= startMinutes and currentMinutes < endMinutes
    else
        // Handles overnight sessions
        currentMinutes >= startMinutes or currentMinutes < endMinutes

// Day Filter
isDayAllowed() =>
    int dow = dayofweek
    bool allowed = true
    
    if dow == dayofweek.monday and not tradeMon
        allowed := false
    else if dow == dayofweek.tuesday and not tradeTue
        allowed := false
    else if dow == dayofweek.wednesday and not tradeWed
        allowed := false
    else if dow == dayofweek.thursday and not tradeThu
        allowed := false
    else if dow == dayofweek.friday and not tradeFri
        allowed := false
    
    allowed

// Volatility Filter
isVolatilityAcceptable() =>
    float atrValue = ta.atr(14)
    bool acceptable = true
    
    if minATR > 0 and atrValue < minATR
        acceptable := false
    if maxATR > 0 and atrValue > maxATR
        acceptable := false
    
    acceptable

// SMT Check Functions
hasBullishSMT() =>
    bool found = false
    if enableSMT and array.size(smtArray) > 0
        for i = array.size(smtArray) - 1 to 0
            smt = array.get(smtArray, i)
            if smt.smtType == "BULLISH" and smt.confirmed
                found := true
                break
    found

hasBearishSMT() =>
    bool found = false
    if enableSMT and array.size(smtArray) > 0
        for i = array.size(smtArray) - 1 to 0
            smt = array.get(smtArray, i)
            if smt.smtType == "BEARISH" and smt.confirmed
                found := true
                break
    found

// HTF Bias
getHTFBias() =>
    int bias = 0  // -1 = bearish, 0 = neutral, 1 = bullish
    
    switch htfBiasMethod
        'Candle Direction' =>
            [htfO, htfC] = request.security(syminfo.tickerid, htfBiasTimeframe, [open, close])
            bias := htfC > htfO ? 1 : htfC < htfO ? -1 : 0
        
        'EMA Trend' =>
            htfEMA = request.security(syminfo.tickerid, htfBiasTimeframe, ta.ema(close, 20))
            htfClose = request.security(syminfo.tickerid, htfBiasTimeframe, close)
            bias := htfClose > htfEMA ? 1 : htfClose < htfEMA ? -1 : 0
        
        'Price vs VWAP' =>
            htfVWAP = request.security(syminfo.tickerid, htfBiasTimeframe, ta.vwap)
            htfClose = request.security(syminfo.tickerid, htfBiasTimeframe, close)
            bias := htfClose > htfVWAP ? 1 : htfClose < htfVWAP ? -1 : 0
    
    bias

// FVG Quality Check
checkFVGQuality(PendingSignal signal) =>
    bool passed = true
    
    if not na(signal) and not na(signal.fvgRangeHigh) and not na(signal.fvgRangeLow)
        float fvgSize = math.abs(signal.fvgRangeLow - signal.fvgRangeHigh)
        float fvgSizePoints = fvgSize / syminfo.mintick
        float atrValue = ta.atr(14)
        float fvgSizeATR = atrValue > 0 ? fvgSize / atrValue : 0
        
        if minFVGSize > 0 and fvgSizePoints < minFVGSize
            passed := false
        if maxFVGSize > 0 and fvgSizePoints > maxFVGSize
            passed := false
        if minFVGSizeATR > 0 and fvgSizeATR < minFVGSizeATR
            passed := false
        if maxFVGSizeATR > 0 and fvgSizeATR > maxFVGSizeATR
            passed := false
    
    passed

// Confirmation Timing Check
checkConfirmationTiming(PendingSignal signal) =>
    bool passed = true
    
    if not na(signal)
        int barsSinceCreation = bar_index - signal.creationBar
        
        if maxBarsToConfirm > 0 and barsSinceCreation > maxBarsToConfirm
            passed := false
        if minBarsToConfirm > 0 and barsSinceCreation < minBarsToConfirm
            passed := false
    
    passed
```

### 9.2 Trade Tracking

```pinescript
// ══════════════════════════════════════════════════════════════════════════════
// TRADE TRACKING
// ══════════════════════════════════════════════════════════════════════════════

// Daily trade counter
var int dailyTradeCount = 0
var int lastTradeDay = 0

// Reset daily counter
if dayofweek != lastTradeDay
    dailyTradeCount := 0
    lastTradeDay := dayofweek

// Consecutive losses tracker
var int consecutiveLosses = 0
var int lastStrategyClosedTrades = 0

// Update consecutive losses
if strategy.closedtrades > lastStrategyClosedTrades
    lastStrategyClosedTrades := strategy.closedtrades
    float lastProfit = strategy.closedtrades.profit(strategy.closedtrades - 1)
    
    if lastProfit < 0
        consecutiveLosses := consecutiveLosses + 1
    else
        consecutiveLosses := 0

// Reset consecutive losses at session start (if using session filter)
if enableSessionFilter
    bool sessionJustStarted = isInSession() and not isInSession()[1]
    if sessionJustStarted
        consecutiveLosses := 0
```

---

## 10. Visual Elements

### 10.1 Strategy-Specific Plots

```pinescript
// ══════════════════════════════════════════════════════════════════════════════
// STRATEGY VISUALS
// ══════════════════════════════════════════════════════════════════════════════

// Plot current stop loss
plot(strategy.position_size != 0 ? currentStopLoss : na, 
     title = 'Current Stop', 
     color = color.red, 
     style = plot.style_linebr, 
     linewidth = 1)

// Plot entry price
plot(strategy.position_size != 0 ? currentEntryPrice : na, 
     title = 'Entry Price', 
     color = color.gray, 
     style = plot.style_linebr, 
     linewidth = 1)

// Plot take profit target
var float currentTP = na
plot(strategy.position_size != 0 ? currentTP : na, 
     title = 'Take Profit', 
     color = color.green, 
     style = plot.style_linebr, 
     linewidth = 1)

// Background color for active trades
bgcolor(strategy.position_size > 0 ? color.new(color.green, 95) : 
        strategy.position_size < 0 ? color.new(color.red, 95) : na, 
        title = 'Position Background')

// Entry markers (in addition to default strategy markers)
plotshape(longEntryCondition, 
          title = 'Long Entry', 
          location = location.belowbar, 
          color = color.green, 
          style = shape.triangleup, 
          size = size.small)

plotshape(shortEntryCondition, 
          title = 'Short Entry', 
          location = location.abovebar, 
          color = color.red, 
          style = shape.triangledown, 
          size = size.small)
```

### 10.2 Strategy Dashboard Updates

```pinescript
// Add strategy-specific rows to dashboard
if showDashboard
    // Add row for position info
    int posRow = signalRow + 1
    string posText = ""
    
    if strategy.position_size > 0
        posText := "LONG: " + str.tostring(strategy.position_size, '#.##')
        posText := posText + "\nP&L: " + str.tostring(strategy.openprofit, '#.##')
    else if strategy.position_size < 0
        posText := "SHORT: " + str.tostring(math.abs(strategy.position_size), '#.##')
        posText := posText + "\nP&L: " + str.tostring(strategy.openprofit, '#.##')
    else
        posText := "FLAT"
    
    table.cell(dashboardTable, 0, posRow, posText,
               text_color = strategy.position_size > 0 ? color.green : 
                           strategy.position_size < 0 ? color.red : dashboardTextColor,
               text_size = dashboardSize,
               text_font_family = font.family_monospace,
               bgcolor = dashboardBgColor)
    
    // Add row for performance stats
    int statsRow = posRow + 1
    string statsText = "Trades: " + str.tostring(strategy.closedtrades)
    statsText := statsText + "\nWin%: " + str.tostring(strategy.wintrades / math.max(1, strategy.closedtrades) * 100, '#.#') + "%"
    statsText := statsText + "\nPF: " + str.tostring(strategy.grossprofit / math.max(1, math.abs(strategy.grossloss)), '#.##')
    
    table.cell(dashboardTable, 0, statsRow, statsText,
               text_color = dashboardTextColor,
               text_size = dashboardSize,
               text_font_family = font.family_monospace,
               bgcolor = dashboardBgColor)
```

---

## 11. Alerts

### 11.1 Strategy Alerts

```pinescript
// ══════════════════════════════════════════════════════════════════════════════
// ALERTS
// ══════════════════════════════════════════════════════════════════════════════

// Entry Alerts
alertcondition(longEntryCondition, 
               title = 'Long Entry', 
               message = 'Forever Model: LONG entry at {{close}}. Stop: {{plot("Current Stop")}}')

alertcondition(shortEntryCondition, 
               title = 'Short Entry', 
               message = 'Forever Model: SHORT entry at {{close}}. Stop: {{plot("Current Stop")}}')

// Exit Alerts
alertcondition(strategy.position_size[1] > 0 and strategy.position_size == 0, 
               title = 'Long Exit', 
               message = 'Forever Model: LONG position closed')

alertcondition(strategy.position_size[1] < 0 and strategy.position_size == 0, 
               title = 'Short Exit', 
               message = 'Forever Model: SHORT position closed')

// Stop Hit Alerts
alertcondition(strategy.position_size[1] > 0 and strategy.position_size == 0 and low <= currentStopLoss[1], 
               title = 'Long Stop Hit', 
               message = 'Forever Model: LONG stop loss triggered')

alertcondition(strategy.position_size[1] < 0 and strategy.position_size == 0 and high >= currentStopLoss[1], 
               title = 'Short Stop Hit', 
               message = 'Forever Model: SHORT stop loss triggered')

// Take Profit Alerts
alertcondition(strategy.position_size[1] > 0 and strategy.position_size == 0 and high >= currentTP[1], 
               title = 'Long TP Hit', 
               message = 'Forever Model: LONG take profit reached')

alertcondition(strategy.position_size[1] < 0 and strategy.position_size == 0 and low <= currentTP[1], 
               title = 'Short TP Hit', 
               message = 'Forever Model: SHORT take profit reached')
```

---

## 12. Implementation Checklist

### 12.1 Conversion Steps

- [ ] Change `indicator()` to `strategy()` declaration
- [ ] Add all strategy input parameters
- [ ] Implement position sizing logic
- [ ] Implement stop loss calculation and management
- [ ] Implement take profit calculation
- [ ] Add entry condition filters
- [ ] Implement `strategy.entry()` calls
- [ ] Implement `strategy.exit()` calls
- [ ] Implement `strategy.close()` calls for discretionary exits
- [ ] Add break-even and trailing stop logic
- [ ] Add partial take profit logic
- [ ] Implement trade tracking (daily count, consecutive losses)
- [ ] Update dashboard with strategy-specific info
- [ ] Add strategy-specific alerts
- [ ] Test on multiple timeframes
- [ ] Test on multiple instruments
- [ ] Optimize parameters

### 12.2 Testing Protocol

1. **Compilation Test:** Ensure code compiles without errors
2. **Visual Test:** Verify entries/exits display correctly on chart
3. **Logic Test:** Confirm signals match indicator signals
4. **Filter Test:** Verify all filters work as expected
5. **Exit Test:** Confirm all exit types function properly
6. **Performance Test:** Review strategy performance report
7. **Walk-Forward Test:** Test on out-of-sample data
8. **Multi-Instrument Test:** Verify on forex, futures, crypto, stocks

---

## 13. Default Settings Recommendations

### 13.1 Conservative Profile
```
Position Size: 1% Risk-Based
Stop Loss: Signal-Based
Take Profit: 2:1 R:R
Use Break Even: Yes (1.0 R:R trigger)
Use Trailing: No
Session Filter: Enabled (London + NY AM)
Require SMT: Yes
```

### 13.2 Moderate Profile
```
Position Size: 2% Risk-Based
Stop Loss: Signal-Based
Take Profit: 2.5:1 R:R
Use Break Even: Yes (1.5 R:R trigger)
Use Trailing: Yes (ATR-Based, 2.0 R:R activation)
Session Filter: Enabled (London + NY AM)
Require SMT: No
```

### 13.3 Aggressive Profile
```
Position Size: 3% Risk-Based
Stop Loss: Signal-Based
Take Profit: 3:1 R:R or ERL Target
Use Break Even: No
Use Trailing: Yes (ATR-Based, 1.0 R:R activation)
Session Filter: Optional
Require SMT: No
```

---

## 14. Known Limitations

1. **Repainting:** HTF data may repaint on live bars; strategy uses confirmed bars only
2. **Slippage:** Real-world slippage may exceed strategy settings
3. **Fills:** Strategy assumes fills at exact prices; real trading may differ
4. **Gaps:** Overnight gaps may cause stop losses to execute beyond intended level
5. **Commission:** Actual commission may vary from strategy settings
6. **Broker Compatibility:** Not all brokers support all order types

---

## 15. Future Enhancements

1. **Multiple Take Profit Levels:** Scale out at 1R, 2R, 3R
2. **Pyramiding Logic:** Add to winning positions at FVG retests
3. **Correlation Filter:** Avoid trades when correlated pairs conflict
4. **News Filter:** Avoid trading during high-impact news events
5. **Machine Learning Integration:** Optimize parameters dynamically
6. **Portfolio Mode:** Trade multiple instruments with capital allocation

---

## Document History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-12-18 | Initial specification |

---

*End of Specification*
