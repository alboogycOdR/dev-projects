//+------------------------------------------------------------------+
//|                                                 WorldClassEA.mq5 |
//|                                  Copyright 2024, Your Company    |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Your Company"
#property link      "https://www.mql5.com"
#property version   "2.00"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//--- Input parameters
input group "=== GENERAL SETTINGS ==="
input double   LotSize = 0.01;                    // Lot size
input int      MagicNumber = 123456;              // Magic number
input double   MaxRisk = 2.0;                     // Maximum risk per trade (%)
input int      MaxSpread = 30;                    // Maximum spread (points)
input int      MaxPositions = 1;                  // Maximum concurrent positions

input group "=== STRATEGY SELECTION ==="
input bool     UseTrendFollowing = true;          // Use Trend Following Strategy
input bool     UseMeanReversion = true;           // Use Mean Reversion Strategy
input bool     UseScalping = false;               // Use Scalping Strategy
input bool     UseMultiTimeframe = true;          // Use Multi-Timeframe Analysis
input bool     UseBreakoutStrategy = true;        // Use Breakout Strategy

input group "=== TREND FOLLOWING ==="
input int      FastMA = 20;                       // Fast Moving Average
input int      SlowMA = 50;                       // Slow Moving Average
input int      MACD_Fast = 12;                    // MACD Fast EMA
input int      MACD_Slow = 26;                    // MACD Slow EMA
input int      MACD_Signal = 9;                   // MACD Signal SMA

input group "=== MEAN REVERSION ==="
input int      RSI_Period = 14;                   // RSI Period
input double   RSI_Oversold = 30;                 // RSI Oversold Level
input double   RSI_Overbought = 70;               // RSI Overbought Level
input int      BB_Period = 20;                    // Bollinger Bands Period
input double   BB_Deviation = 2.0;                // Bollinger Bands Deviation

input group "=== SCALPING SETTINGS ==="
input int      ScalpingPeriod = 5;                // Scalping MA Period
input double   ScalpingThreshold = 0.0001;        // Price movement threshold
input int      QuickTP = 10;                      // Quick Take Profit (points)
input int      QuickSL = 5;                       // Quick Stop Loss (points)

input group "=== BREAKOUT SETTINGS ==="
input int      BreakoutPeriod = 20;               // Breakout detection period
input double   BreakoutThreshold = 1.5;           // Breakout threshold multiplier
input bool     UseVolumeConfirmation = true;      // Use volume confirmation

input group "=== RISK MANAGEMENT ==="
input double   StopLoss = 100;                    // Stop Loss (points)
input double   TakeProfit = 200;                  // Take Profit (points)
input bool     UseTrailingStop = true;            // Use Trailing Stop
input double   TrailingStop = 50;                 // Trailing Stop (points)
input double   TrailingStep = 10;                 // Trailing Step (points)
input bool     UseBreakEven = true;               // Use Break Even
input double   BreakEvenPoints = 20;              // Break Even trigger (points)

input group "=== FILTERS ==="
input bool     UseTimeFilter = true;              // Use Time Filter
input int      StartHour = 8;                     // Start Hour (Server Time)
input int      EndHour = 18;                      // End Hour (Server Time)
input bool     UseVolatilityFilter = true;        // Use Volatility Filter
input double   MinATR = 0.0001;                   // Minimum ATR value
input double   MaxATR = 0.01;                     // Maximum ATR value

//--- Global variables
CTrade         trade;
CPositionInfo  position;
COrderInfo     order;

int            handleMA_Fast, handleMA_Slow;
int            handleMACD;
int            handleRSI;
int            handleBB;
int            handleATR;
int            handleScalpMA;

double         ma_fast[], ma_slow[];
double         macd_main[], macd_signal[];
double         rsi[];
double         bb_upper[], bb_middle[], bb_lower[];
double         atr[];
double         scalp_ma[];

// Performance tracking
int            totalTrades = 0;
int            winningTrades = 0;
double         totalProfit = 0.0;
datetime       lastTradeTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Set magic number
    trade.SetExpertMagicNumber(MagicNumber);
    
    // Initialize indicators
    handleMA_Fast = iMA(_Symbol, PERIOD_CURRENT, FastMA, 0, MODE_EMA, PRICE_CLOSE);
    handleMA_Slow = iMA(_Symbol, PERIOD_CURRENT, SlowMA, 0, MODE_EMA, PRICE_CLOSE);
    handleMACD = iMACD(_Symbol, PERIOD_CURRENT, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
    handleRSI = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
    handleBB = iBands(_Symbol, PERIOD_CURRENT, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
    handleATR = iATR(_Symbol, PERIOD_CURRENT, 14);
    handleScalpMA = iMA(_Symbol, PERIOD_CURRENT, ScalpingPeriod, 0, MODE_EMA, PRICE_CLOSE);
    
    // Check if indicators are created successfully
    if(handleMA_Fast == INVALID_HANDLE || handleMA_Slow == INVALID_HANDLE ||
       handleMACD == INVALID_HANDLE || handleRSI == INVALID_HANDLE || 
       handleBB == INVALID_HANDLE || handleATR == INVALID_HANDLE || 
       handleScalpMA == INVALID_HANDLE)
    {
        Print("Error creating indicators");
        return INIT_FAILED;
    }
    
    // Set array as series
    ArraySetAsSeries(ma_fast, true);
    ArraySetAsSeries(ma_slow, true);
    ArraySetAsSeries(macd_main, true);
    ArraySetAsSeries(macd_signal, true);
    ArraySetAsSeries(rsi, true);
    ArraySetAsSeries(bb_upper, true);
    ArraySetAsSeries(bb_middle, true);
    ArraySetAsSeries(bb_lower, true);
    ArraySetAsSeries(atr, true);
    ArraySetAsSeries(scalp_ma, true);
    
    Print("WorldClass EA v2.0 initialized successfully");
    PrintAccountInfo();
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Release indicator handles
    IndicatorRelease(handleMA_Fast);
    IndicatorRelease(handleMA_Slow);
    IndicatorRelease(handleMACD);
    IndicatorRelease(handleRSI);
    IndicatorRelease(handleBB);
    IndicatorRelease(handleATR);
    IndicatorRelease(handleScalpMA);
    
    // Print final statistics
    PrintFinalStats();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check if new bar
    static datetime lastBar = 0;
    datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(currentBar == lastBar) return;
    lastBar = currentBar;
    
    // Update indicator values
    if(!UpdateIndicators()) return;
    
    // Apply filters
    if(!PassFilters()) return;
    
    // Main trading logic
    CheckForTrade();
    
    // Manage existing positions
    ManagePositions();
    
    // Update statistics
    UpdateStatistics();
}

//+------------------------------------------------------------------+
//| Update indicator values                                          |
//+------------------------------------------------------------------+
bool UpdateIndicators()
{
    // Copy indicator values
    if(CopyBuffer(handleMA_Fast, 0, 0, 3, ma_fast) < 3) return false;
    if(CopyBuffer(handleMA_Slow, 0, 0, 3, ma_slow) < 3) return false;
    if(CopyBuffer(handleMACD, 0, 0, 3, macd_main) < 3) return false;
    if(CopyBuffer(handleMACD, 1, 0, 3, macd_signal) < 3) return false;
    if(CopyBuffer(handleRSI, 0, 0, 3, rsi) < 3) return false;
    if(CopyBuffer(handleBB, 0, 0, 3, bb_upper) < 3) return false;
    if(CopyBuffer(handleBB, 1, 0, 3, bb_middle) < 3) return false;
    if(CopyBuffer(handleBB, 2, 0, 3, bb_lower) < 3) return false;
    if(CopyBuffer(handleATR, 0, 0, 3, atr) < 3) return false;
    if(CopyBuffer(handleScalpMA, 0, 0, 3, scalp_ma) < 3) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Check all filters                                                |
//+------------------------------------------------------------------+
bool PassFilters()
{
    // Time filter
    if(UseTimeFilter && !IsTimeToTrade()) return false;
    
    // Spread filter
    if(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > MaxSpread) return false;
    
    // Volatility filter
    if(UseVolatilityFilter && !IsVolatilityGood()) return false;
    
    // Maximum positions filter
    if(CountMyPositions() >= MaxPositions) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Check volatility conditions                                      |
//+------------------------------------------------------------------+
bool IsVolatilityGood()
{
    double currentATR = atr[0];
    return (currentATR >= MinATR && currentATR <= MaxATR);
}

//+------------------------------------------------------------------+
//| Count positions opened by this EA                                |
//+------------------------------------------------------------------+
int CountMyPositions()
{
    int count = 0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(position.SelectByIndex(i))
        {
            if(position.Symbol() == _Symbol && position.Magic() == MagicNumber)
                count++;
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Check for trading opportunities                                  |
//+------------------------------------------------------------------+
void CheckForTrade()
{
    int signal = 0;
    
    // Trend Following Strategy
    if(UseTrendFollowing)
    {
        signal += GetTrendFollowingSignal();
    }
    
    // Mean Reversion Strategy
    if(UseMeanReversion)
    {
        signal += GetMeanReversionSignal();
    }
    
    // Scalping Strategy
    if(UseScalping)
    {
        signal += GetScalpingSignal();
    }
    
    // Breakout Strategy
    if(UseBreakoutStrategy)
    {
        signal += GetBreakoutSignal();
    }
    
    // Multi-timeframe confirmation
    if(UseMultiTimeframe)
    {
        signal += GetMultiTimeframeSignal();
    }
    
    // Execute trade based on signal strength
    if(signal >= 2)
    {
        if(UseScalping && GetScalpingSignal() != 0)
            OpenScalpOrder(ORDER_TYPE_BUY);
        else
            OpenBuyOrder();
    }
    else if(signal <= -2)
    {
        if(UseScalping && GetScalpingSignal() != 0)
            OpenScalpOrder(ORDER_TYPE_SELL);
        else
            OpenSellOrder();
    }
}

//+------------------------------------------------------------------+
//| Get Trend Following Signal                                       |
//+------------------------------------------------------------------+
int GetTrendFollowingSignal()
{
    int signal = 0;
    
    // Moving Average Crossover
    if(ma_fast[0] > ma_slow[0] && ma_fast[1] <= ma_slow[1])
        signal += 1;
    else if(ma_fast[0] < ma_slow[0] && ma_fast[1] >= ma_slow[1])
        signal -= 1;
    
    // MACD Signal
    if(macd_main[0] > macd_signal[0] && macd_main[1] <= macd_signal[1] && macd_main[0] < 0)
        signal += 1;
    else if(macd_main[0] < macd_signal[0] && macd_main[1] >= macd_signal[1] && macd_main[0] > 0)
        signal -= 1;
    
    return signal;
}

//+------------------------------------------------------------------+
//| Get Mean Reversion Signal                                        |
//+------------------------------------------------------------------+
int GetMeanReversionSignal()
{
    int signal = 0;
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // RSI Oversold/Overbought
    if(rsi[0] < RSI_Oversold && rsi[1] >= RSI_Oversold)
        signal += 1;
    else if(rsi[0] > RSI_Overbought && rsi[1] <= RSI_Overbought)
        signal -= 1;
    
    // Bollinger Bands
    if(currentPrice <= bb_lower[0] && SymbolInfoDouble(_Symbol, SYMBOL_BID) > bb_lower[1])
        signal += 1;
    else if(currentPrice >= bb_upper[0] && SymbolInfoDouble(_Symbol, SYMBOL_ASK) < bb_upper[1])
        signal -= 1;
    
    return signal;
}

//+------------------------------------------------------------------+
//| Get Multi-timeframe Signal                                       |
//+------------------------------------------------------------------+
int GetMultiTimeframeSignal()
{
    // Get higher timeframe trend
    ENUM_TIMEFRAMES higherTF = GetHigherTimeframe();
    
    int handleMA_H4 = iMA(_Symbol, higherTF, 50, 0, MODE_EMA, PRICE_CLOSE);
    double ma_h4[];
    ArraySetAsSeries(ma_h4, true);
    
    if(CopyBuffer(handleMA_H4, 0, 0, 2, ma_h4) < 2)
    {
        IndicatorRelease(handleMA_H4);
        return 0;
    }
    
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    int signal = 0;
    
    if(currentPrice > ma_h4[0] && ma_h4[0] > ma_h4[1])
        signal = 1;  // Uptrend
    else if(currentPrice < ma_h4[0] && ma_h4[0] < ma_h4[1])
        signal = -1; // Downtrend
    
    IndicatorRelease(handleMA_H4);
    return signal;
}

//+------------------------------------------------------------------+
//| Get higher timeframe                                             |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetHigherTimeframe()
{
    ENUM_TIMEFRAMES currentTF = Period();
    
    switch(currentTF)
    {
        case PERIOD_M1:  return PERIOD_M5;
        case PERIOD_M5:  return PERIOD_M15;
        case PERIOD_M15: return PERIOD_H1;
        case PERIOD_H1:  return PERIOD_H4;
        case PERIOD_H4:  return PERIOD_D1;
        default:         return PERIOD_H4;
    }
}

//+------------------------------------------------------------------+
//| Open Buy Order                                                   |
//+------------------------------------------------------------------+
void OpenBuyOrder()
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double sl = ask - StopLoss * _Point;
    double tp = ask + TakeProfit * _Point;
    
    double lotSize = CalculateLotSize();
    
    if(trade.Buy(lotSize, _Symbol, ask, sl, tp, "WorldClass EA Buy"))
    {
        Print("Buy order opened successfully");
    }
    else
    {
        Print("Error opening buy order: ", trade.ResultRetcode());
    }
}

//+------------------------------------------------------------------+
//| Open Sell Order                                                  |
//+------------------------------------------------------------------+
void OpenSellOrder()
{
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double sl = bid + StopLoss * _Point;
    double tp = bid - TakeProfit * _Point;
    
    double lotSize = CalculateLotSize();
    
    if(trade.Sell(lotSize, _Symbol, bid, sl, tp, "WorldClass EA Sell"))
    {
        Print("Sell order opened successfully");
    }
    else
    {
        Print("Error opening sell order: ", trade.ResultRetcode());
    }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk                                 |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = balance * MaxRisk / 100.0;
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double lotSize = riskAmount / (StopLoss * tickValue);
    
    // Normalize lot size
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
    lotSize = NormalizeDouble(lotSize / lotStep, 0) * lotStep;
    
    return lotSize;
}

//+------------------------------------------------------------------+
//| Manage existing positions                                        |
//+------------------------------------------------------------------+
void ManagePositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(position.SelectByIndex(i))
        {
            if(position.Symbol() == _Symbol && position.Magic() == MagicNumber)
            {
                // Break Even Management
                if(UseBreakEven)
                {
                    BreakEvenStop(position.Ticket());
                }
                
                // Trailing Stop
                if(UseTrailingStop)
                {
                    TrailingStop(position.Ticket());
                }
                
                // Partial Close for profitable positions
                PartialClose(position.Ticket());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Break Even Stop function                                         |
//+------------------------------------------------------------------+
void BreakEvenStop(ulong ticket)
{
    if(!position.SelectByTicket(ticket)) return;
    
    double openPrice = position.PriceOpen();
    double currentPrice;
    
    if(position.PositionType() == POSITION_TYPE_BUY)
    {
        currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        if(currentPrice >= openPrice + BreakEvenPoints * _Point)
        {
            if(position.StopLoss() < openPrice)
            {
                trade.PositionModify(ticket, openPrice + _Point, position.TakeProfit());
                Print("Break even applied to buy position");
            }
        }
    }
    else if(position.PositionType() == POSITION_TYPE_SELL)
    {
        currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        if(currentPrice <= openPrice - BreakEvenPoints * _Point)
        {
            if(position.StopLoss() > openPrice)
            {
                trade.PositionModify(ticket, openPrice - _Point, position.TakeProfit());
                Print("Break even applied to sell position");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Partial Close function                                           |
//+------------------------------------------------------------------+
void PartialClose(ulong ticket)
{
    if(!position.SelectByTicket(ticket)) return;
    
    double profit = position.Profit();
    double volume = position.Volume();
    
    // Close 50% when profit reaches 50% of target
    if(profit > 0 && volume > SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
    {
        double targetProfit = TakeProfit * _Point * volume * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        
        if(profit >= targetProfit * 0.5 && volume > SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN) * 2)
        {
            double closeVolume = volume / 2;
            closeVolume = NormalizeDouble(closeVolume, 2);
            
            if(trade.PositionClosePartial(ticket, closeVolume))
            {
                Print("Partial close executed: ", closeVolume, " lots");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Enhanced Trailing Stop function                                  |
//+------------------------------------------------------------------+
void TrailingStop(ulong ticket)
{
    if(!position.SelectByTicket(ticket)) return;
    
    double currentPrice;
    double newSL;
    double atrValue = atr[0];
    double dynamicTrailing = MathMax(TrailingStop * _Point, atrValue * 2);
    
    if(position.PositionType() == POSITION_TYPE_BUY)
    {
        currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        newSL = currentPrice - dynamicTrailing;
        
        if(newSL > position.StopLoss() + TrailingStep * _Point)
        {
            trade.PositionModify(ticket, newSL, position.TakeProfit());
            Print("Trailing stop updated for buy position");
        }
    }
    else if(position.PositionType() == POSITION_TYPE_SELL)
    {
        currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        newSL = currentPrice + dynamicTrailing;
        
        if(newSL < position.StopLoss() - TrailingStep * _Point || position.StopLoss() == 0)
        {
            trade.PositionModify(ticket, newSL, position.TakeProfit());
            Print("Trailing stop updated for sell position");
        }
    }
}

//+------------------------------------------------------------------+
//| Check if it's time to trade                                      |
//+------------------------------------------------------------------+
bool IsTimeToTrade()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    return (dt.hour >= StartHour && dt.hour < EndHour);
}

//+------------------------------------------------------------------+
//| Print account information                                       |
//+------------------------------------------------------------------+
void PrintAccountInfo()
{
    Print("Account Balance: ", AccountInfoDouble(ACCOUNT_BALANCE));
    Print("Account Equity: ", AccountInfoDouble(ACCOUNT_EQUITY));
    Print("Account Profit: ", AccountInfoDouble(ACCOUNT_PROFIT));
}

//+------------------------------------------------------------------+
//| Print final statistics                                           |
//+------------------------------------------------------------------+
void PrintFinalStats()
{
    Print("Total Trades: ", totalTrades);
    Print("Winning Trades: ", winningTrades);
    Print("Total Profit: ", totalProfit);
}

//+------------------------------------------------------------------+
//| Update statistics                                               |
//+------------------------------------------------------------------+
void UpdateStatistics()
{
    static int lastPositionCount = 0;
    int currentPositionCount = CountMyPositions();
    
    // Check if a position was closed (position count decreased)
    if(currentPositionCount < lastPositionCount)
    {
        totalTrades++;
        
        // Calculate total current profit from remaining positions
        double currentProfit = 0;
        for(int i = 0; i < PositionsTotal(); i++)
        {
            if(position.SelectByIndex(i))
            {
                if(position.Symbol() == _Symbol && position.Magic() == MagicNumber)
                {
                    currentProfit += position.Profit();
                }
            }
        }
        
        // Simple profit tracking (this is a basic implementation)
        if(currentProfit > totalProfit)
        {
            winningTrades++;
        }
        totalProfit = currentProfit;
    }
    
    lastPositionCount = currentPositionCount;
}

//+------------------------------------------------------------------+
//| Get Scalping Signal                                              |
//+------------------------------------------------------------------+
int GetScalpingSignal()
{
    int signal = 0;
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Quick price movement detection
    if(currentPrice > scalp_ma[0] + ScalpingThreshold && currentPrice > scalp_ma[1])
        signal = 1;
    else if(currentPrice < scalp_ma[0] - ScalpingThreshold && currentPrice < scalp_ma[1])
        signal = -1;
    
    return signal;
}

//+------------------------------------------------------------------+
//| Get Breakout Signal                                              |
//+------------------------------------------------------------------+
int GetBreakoutSignal()
{
    int signal = 0;
    double high = iHigh(_Symbol, PERIOD_CURRENT, 1);
    double low = iLow(_Symbol, PERIOD_CURRENT, 1);
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Calculate recent high/low
    double recentHigh = high;
    double recentLow = low;
    
    for(int i = 2; i <= BreakoutPeriod; i++)
    {
        double h = iHigh(_Symbol, PERIOD_CURRENT, i);
        double l = iLow(_Symbol, PERIOD_CURRENT, i);
        if(h > recentHigh) recentHigh = h;
        if(l < recentLow) recentLow = l;
    }
    
    double range = recentHigh - recentLow;
    double breakoutLevel = range * BreakoutThreshold;
    
    // Breakout detection
    if(currentPrice > recentHigh + breakoutLevel)
        signal = 1;
    else if(currentPrice < recentLow - breakoutLevel)
        signal = -1;
    
    // Volume confirmation (if available)
    if(UseVolumeConfirmation && signal != 0)
    {
        long currentVolume = iVolume(_Symbol, PERIOD_CURRENT, 0);
        long avgVolume = 0;
        for(int i = 1; i <= 10; i++)
        {
            avgVolume += iVolume(_Symbol, PERIOD_CURRENT, i);
        }
        avgVolume /= 10;
        
        if(currentVolume < avgVolume * 1.5)
            signal = 0; // Cancel signal if volume is not confirming
    }
    
    return signal;
}

//+------------------------------------------------------------------+
//| Open Scalping Order                                              |
//+------------------------------------------------------------------+
void OpenScalpOrder(ENUM_ORDER_TYPE orderType)
{
    double price, sl, tp;
    double lotSize = CalculateLotSize();
    
    if(orderType == ORDER_TYPE_BUY)
    {
        price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        sl = price - QuickSL * _Point;
        tp = price + QuickTP * _Point;
        
        if(trade.Buy(lotSize, _Symbol, price, sl, tp, "Scalp Buy"))
        {
            Print("Scalping buy order opened successfully");
            lastTradeTime = TimeCurrent();
        }
    }
    else if(orderType == ORDER_TYPE_SELL)
    {
        price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        sl = price + QuickSL * _Point;
        tp = price - QuickTP * _Point;
        
        if(trade.Sell(lotSize, _Symbol, price, sl, tp, "Scalp Sell"))
        {
            Print("Scalping sell order opened successfully");
            lastTradeTime = TimeCurrent();
        }
    }
} 