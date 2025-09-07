//+------------------------------------------------------------------+
//|                                        PortfolioProtectionEA.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

//--- Include necessary libraries
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//--- Input parameters
input group "=== Portfolio Protection Settings ==="
input double MaxRiskPercent = 2.0;           // Maximum risk per trade (%)
input double MaxDailyLoss = 5.0;             // Maximum daily loss (%)
input double MaxDrawdown = 10.0;             // Maximum drawdown (%)
input int MaxOpenTrades = 5;                 // Maximum open trades
input bool UseTrailingStop = true;           // Use trailing stop
input double TrailingStopPercent = 1.5;      // Trailing stop (%)

input group "=== Strategy Selection ==="
input bool UseStrategy1_TrendFollowing = true;    // Strategy 1: Trend Following
input bool UseStrategy2_MeanReversion = true;     // Strategy 2: Mean Reversion  
input bool UseStrategy3_Breakout = true;          // Strategy 3: Breakout
input bool UseStrategy4_GridHedging = false;      // Strategy 4: Grid Hedging
input bool UseStrategy5_Scalping = false;         // Strategy 5: Scalping

input group "=== Risk Management ==="
input double StopLossPercent = 1.0;          // Stop Loss (%)
input double TakeProfitPercent = 2.0;        // Take Profit (%)
input bool UsePositionSizing = true;         // Use position sizing
input double FixedLotSize = 0.01;            // Fixed lot size (if not using position sizing)

//--- Global variables
CTrade trade;
CPositionInfo positionInfo;
CAccountInfo accountInfo;

double AccountBalance;
double DailyStartBalance;
double MaxDailyLossAmount;
double MaxDrawdownAmount;
int TotalTrades = 0;
int WinningTrades = 0;
int LosingTrades = 0;
double TotalProfit = 0;
double TotalLoss = 0;

//--- Strategy statistics
struct StrategyStats {
    string name;
    int trades;
    int wins;
    int losses;
    double profit;
    double loss;
    double winRate;
    double riskReward;
    double avgProfit;
    double avgLoss;
};

StrategyStats strategies[5];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    AccountBalance = accountInfo.Balance();
    DailyStartBalance = AccountBalance;
    MaxDailyLossAmount = AccountBalance * MaxDailyLoss / 100.0;
    MaxDrawdownAmount = AccountBalance * MaxDrawdown / 100.0;
    
    // Initialize strategy statistics
    InitializeStrategyStats();
    
    Print("Portfolio Protection EA initialized");
    Print("Account Balance: ", AccountBalance);
    Print("Max Daily Loss: ", MaxDailyLossAmount);
    Print("Max Drawdown: ", MaxDrawdownAmount);
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    PrintFinalStatistics();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check portfolio protection rules
    if (!CheckPortfolioProtection()) {
        return;
    }
    
    // Update trailing stops
    if (UseTrailingStop) {
        UpdateTrailingStops();
    }
    
    // Execute strategies
    if (UseStrategy1_TrendFollowing) {
        ExecuteTrendFollowingStrategy();
    }
    
    if (UseStrategy2_MeanReversion) {
        ExecuteMeanReversionStrategy();
    }
    
    if (UseStrategy3_Breakout) {
        ExecuteBreakoutStrategy();
    }
    
    if (UseStrategy4_GridHedging) {
        ExecuteGridHedgingStrategy();
    }
    
    if (UseStrategy5_Scalping) {
        ExecuteScalpingStrategy();
    }
}

//+------------------------------------------------------------------+
//| Check portfolio protection rules                                 |
//+------------------------------------------------------------------+
bool CheckPortfolioProtection()
{
    double currentBalance = accountInfo.Balance();
    double currentEquity = accountInfo.Equity();
    
    // Check daily loss limit
    double dailyLoss = DailyStartBalance - currentBalance;
    if (dailyLoss >= MaxDailyLossAmount) {
        Print("Daily loss limit reached: ", dailyLoss);
        CloseAllPositions();
        return false;
    }
    
    // Check drawdown limit
    double drawdown = AccountBalance - currentEquity;
    if (drawdown >= MaxDrawdownAmount) {
        Print("Maximum drawdown reached: ", drawdown);
        CloseAllPositions();
        return false;
    }
    
    // Check maximum open trades
    if (PositionsTotal() >= MaxOpenTrades) {
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Strategy 1: Trend Following                                     |
//+------------------------------------------------------------------+
void ExecuteTrendFollowingStrategy()
{
    double ma20[], ma50[];
    ArraySetAsSeries(ma20, true);
    ArraySetAsSeries(ma50, true);
    
    if (CopyBuffer(iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_SMA, PRICE_CLOSE), 0, 0, 3, ma20) != 3) return;
    if (CopyBuffer(iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_SMA, PRICE_CLOSE), 0, 0, 3, ma50) != 3) return;
    
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Buy signal: MA20 > MA50 and price > MA20
    if (ma20[0] > ma50[0] && currentPrice > ma20[0] && ma20[1] <= ma50[1]) {
        if (!HasOpenPosition(ORDER_TYPE_BUY)) {
            OpenPosition(ORDER_TYPE_BUY, "TrendFollowing");
        }
    }
    
    // Sell signal: MA20 < MA50 and price < MA20
    if (ma20[0] < ma50[0] && currentPrice < ma20[0] && ma20[1] >= ma50[1]) {
        if (!HasOpenPosition(ORDER_TYPE_SELL)) {
            OpenPosition(ORDER_TYPE_SELL, "TrendFollowing");
        }
    }
}

//+------------------------------------------------------------------+
//| Strategy 2: Mean Reversion                                      |
//+------------------------------------------------------------------+
void ExecuteMeanReversionStrategy()
{
    double rsi[];
    double bb_upper[], bb_lower[], bb_middle[];
    ArraySetAsSeries(rsi, true);
    ArraySetAsSeries(bb_upper, true);
    ArraySetAsSeries(bb_lower, true);
    ArraySetAsSeries(bb_middle, true);
    
    if (CopyBuffer(iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE), 0, 0, 3, rsi) != 3) return;
    if (CopyBuffer(iBands(_Symbol, PERIOD_CURRENT, 20, 0, 2.0, PRICE_CLOSE), 0, 0, 3, bb_middle) != 3) return;
    if (CopyBuffer(iBands(_Symbol, PERIOD_CURRENT, 20, 0, 2.0, PRICE_CLOSE), 1, 0, 3, bb_upper) != 3) return;
    if (CopyBuffer(iBands(_Symbol, PERIOD_CURRENT, 20, 0, 2.0, PRICE_CLOSE), 2, 0, 3, bb_lower) != 3) return;
    
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Buy signal: RSI oversold and price near lower BB
    if (rsi[0] < 30 && currentPrice <= bb_lower[0]) {
        if (!HasOpenPosition(ORDER_TYPE_BUY)) {
            OpenPosition(ORDER_TYPE_BUY, "MeanReversion");
        }
    }
    
    // Sell signal: RSI overbought and price near upper BB
    if (rsi[0] > 70 && currentPrice >= bb_upper[0]) {
        if (!HasOpenPosition(ORDER_TYPE_SELL)) {
            OpenPosition(ORDER_TYPE_SELL, "MeanReversion");
        }
    }
}

//+------------------------------------------------------------------+
//| Strategy 3: Breakout                                            |
//+------------------------------------------------------------------+
void ExecuteBreakoutStrategy()
{
    double high[], low[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    
    if (CopyHigh(_Symbol, PERIOD_H1, 0, 24, high) != 24) return;
    if (CopyLow(_Symbol, PERIOD_H1, 0, 24, low) != 24) return;
    
    double resistance = high[ArrayMaximum(high, 1, 23)];
    double support = low[ArrayMinimum(low, 1, 23)];
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Buy signal: breakout above resistance
    if (currentPrice > resistance) {
        if (!HasOpenPosition(ORDER_TYPE_BUY)) {
            OpenPosition(ORDER_TYPE_BUY, "Breakout");
        }
    }
    
    // Sell signal: breakdown below support
    if (currentPrice < support) {
        if (!HasOpenPosition(ORDER_TYPE_SELL)) {
            OpenPosition(ORDER_TYPE_SELL, "Breakout");
        }
    }
}

//+------------------------------------------------------------------+
//| Strategy 4: Grid Hedging                                        |
//+------------------------------------------------------------------+
void ExecuteGridHedgingStrategy()
{
    // Grid hedging strategy implementation
    double gridSize = 100 * _Point;
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Check if we need to place grid orders
    if (PositionsTotal() == 0) {
        OpenPosition(ORDER_TYPE_BUY, "GridHedging");
        OpenPosition(ORDER_TYPE_SELL, "GridHedging");
    }
}

//+------------------------------------------------------------------+
//| Strategy 5: Scalping                                            |
//+------------------------------------------------------------------+
void ExecuteScalpingStrategy()
{
    double ema5[], ema13[];
    ArraySetAsSeries(ema5, true);
    ArraySetAsSeries(ema13, true);
    
    if (CopyBuffer(iMA(_Symbol, PERIOD_M5, 5, 0, MODE_EMA, PRICE_CLOSE), 0, 0, 3, ema5) != 3) return;
    if (CopyBuffer(iMA(_Symbol, PERIOD_M5, 13, 0, MODE_EMA, PRICE_CLOSE), 0, 0, 3, ema13) != 3) return;
    
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Quick scalping signals
    if (ema5[0] > ema13[0] && ema5[1] <= ema13[1]) {
        if (!HasOpenPosition(ORDER_TYPE_BUY)) {
            OpenPosition(ORDER_TYPE_BUY, "Scalping");
        }
    }
    
    if (ema5[0] < ema13[0] && ema5[1] >= ema13[1]) {
        if (!HasOpenPosition(ORDER_TYPE_SELL)) {
            OpenPosition(ORDER_TYPE_SELL, "Scalping");
        }
    }
}

//+------------------------------------------------------------------+
//| Open position with risk management                              |
//+------------------------------------------------------------------+
bool OpenPosition(ENUM_ORDER_TYPE orderType, string strategy)
{
    double lotSize = CalculateLotSize();
    double price = (orderType == ORDER_TYPE_BUY) ? 
                   SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                   SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    double sl = CalculateStopLoss(orderType, price);
    double tp = CalculateTakeProfit(orderType, price);
    
    trade.SetExpertMagicNumber(12345);
    
    bool success = false;
    if (orderType == ORDER_TYPE_BUY) {
        success = trade.Buy(lotSize, _Symbol, price, sl, tp, strategy);
    } else {
        success = trade.Sell(lotSize, _Symbol, price, sl, tp, strategy);
    }
    
    if (success) {
        UpdateStrategyStats(strategy, 0, 0); // Initialize trade
        Print("Position opened: ", strategy, " - Ticket: ", trade.ResultOrder());
        return true;
    } else {
        Print("Error opening position: ", trade.ResultRetcode(), " - ", strategy);
        return false;
    }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk management                     |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
    if (!UsePositionSizing) {
        return FixedLotSize;
    }
    
    double balance = accountInfo.Balance();
    double riskAmount = balance * MaxRiskPercent / 100.0;
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double stopLossPoints = StopLossPercent * SymbolInfoDouble(_Symbol, SYMBOL_BID) / 100.0 / _Point;
    
    double lotSize = riskAmount / (stopLossPoints * tickValue);
    
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    
    return MathMax(minLot, MathMin(maxLot, lotSize));
}

//+------------------------------------------------------------------+
//| Calculate stop loss                                             |
//+------------------------------------------------------------------+
double CalculateStopLoss(ENUM_ORDER_TYPE orderType, double price)
{
    double slDistance = price * StopLossPercent / 100.0;
    
    if (orderType == ORDER_TYPE_BUY) {
        return price - slDistance;
    } else {
        return price + slDistance;
    }
}

//+------------------------------------------------------------------+
//| Calculate take profit                                           |
//+------------------------------------------------------------------+
double CalculateTakeProfit(ENUM_ORDER_TYPE orderType, double price)
{
    double tpDistance = price * TakeProfitPercent / 100.0;
    
    if (orderType == ORDER_TYPE_BUY) {
        return price + tpDistance;
    } else {
        return price - tpDistance;
    }
}

//+------------------------------------------------------------------+
//| Check if position exists                                        |
//+------------------------------------------------------------------+
bool HasOpenPosition(ENUM_ORDER_TYPE orderType)
{
    for (int i = 0; i < PositionsTotal(); i++) {
        if (positionInfo.SelectByIndex(i)) {
            if (positionInfo.Symbol() == _Symbol) {
                ENUM_POSITION_TYPE posType = positionInfo.PositionType();
                if ((orderType == ORDER_TYPE_BUY && posType == POSITION_TYPE_BUY) ||
                    (orderType == ORDER_TYPE_SELL && posType == POSITION_TYPE_SELL)) {
                    return true;
                }
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Update trailing stops                                           |
//+------------------------------------------------------------------+
void UpdateTrailingStops()
{
    for (int i = 0; i < PositionsTotal(); i++) {
        if (positionInfo.SelectByIndex(i)) {
            if (positionInfo.Symbol() == _Symbol) {
                double openPrice = positionInfo.PriceOpen();
                double currentPrice = (positionInfo.PositionType() == POSITION_TYPE_BUY) ?
                                     SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                                     SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                double currentSL = positionInfo.StopLoss();
                
                double trailDistance = openPrice * TrailingStopPercent / 100.0;
                double newSL = 0;
                
                if (positionInfo.PositionType() == POSITION_TYPE_BUY) {
                    newSL = currentPrice - trailDistance;
                    if (newSL > currentSL) {
                        ModifyPosition(positionInfo.Ticket(), newSL, positionInfo.TakeProfit());
                    }
                } else {
                    newSL = currentPrice + trailDistance;
                    if (newSL < currentSL || currentSL == 0) {
                        ModifyPosition(positionInfo.Ticket(), newSL, positionInfo.TakeProfit());
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Modify position                                                 |
//+------------------------------------------------------------------+
bool ModifyPosition(ulong ticket, double sl, double tp)
{
    bool success = trade.PositionModify(ticket, sl, tp);
    if (!success) {
        Print("Error modifying position: ", trade.ResultRetcode());
    }
    return success;
}

//+------------------------------------------------------------------+
//| Close all positions                                             |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        if (positionInfo.SelectByIndex(i)) {
            if (positionInfo.Symbol() == _Symbol) {
                if (!trade.PositionClose(positionInfo.Ticket())) {
                    Print("Error closing position: ", trade.ResultRetcode());
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Initialize strategy statistics                                   |
//+------------------------------------------------------------------+
void InitializeStrategyStats()
{
    strategies[0].name = "TrendFollowing";
    strategies[1].name = "MeanReversion";
    strategies[2].name = "Breakout";
    strategies[3].name = "GridHedging";
    strategies[4].name = "Scalping";
    
    for (int i = 0; i < 5; i++) {
        strategies[i].trades = 0;
        strategies[i].wins = 0;
        strategies[i].losses = 0;
        strategies[i].profit = 0;
        strategies[i].loss = 0;
        strategies[i].winRate = 0;
        strategies[i].riskReward = 0;
        strategies[i].avgProfit = 0;
        strategies[i].avgLoss = 0;
    }
}

//+------------------------------------------------------------------+
//| Update strategy statistics                                       |
//+------------------------------------------------------------------+
void UpdateStrategyStats(string strategyName, double profit, double loss)
{
    int index = -1;
    for (int i = 0; i < 5; i++) {
        if (strategies[i].name == strategyName) {
            index = i;
            break;
        }
    }
    
    if (index >= 0) {
        strategies[index].trades++;
        if (profit > 0) {
            strategies[index].wins++;
            strategies[index].profit += profit;
        } else if (loss > 0) {
            strategies[index].losses++;
            strategies[index].loss += loss;
        }
        
        // Calculate statistics
        if (strategies[index].trades > 0) {
            strategies[index].winRate = (double)strategies[index].wins / strategies[index].trades * 100.0;
        }
        
        if (strategies[index].wins > 0) {
            strategies[index].avgProfit = strategies[index].profit / strategies[index].wins;
        }
        
        if (strategies[index].losses > 0) {
            strategies[index].avgLoss = strategies[index].loss / strategies[index].losses;
        }
        
        if (strategies[index].avgLoss > 0) {
            strategies[index].riskReward = strategies[index].avgProfit / strategies[index].avgLoss;
        }
    }
}

//+------------------------------------------------------------------+
//| Print final statistics                                          |
//+------------------------------------------------------------------+
void PrintFinalStatistics()
{
    Print("=== Portfolio Protection EA Statistics ===");
    Print("Strategy Rankings by Performance:");
    Print("Rank | Strategy      | Trades | WR(%) | RR   | Profit | Orders");
    Print("-----|---------------|--------|-------|------|--------|-------");
    
    // Sort strategies by performance score
    for (int i = 0; i < 4; i++) {
        for (int j = i + 1; j < 5; j++) {
            double score1 = strategies[i].winRate * strategies[i].riskReward;
            double score2 = strategies[j].winRate * strategies[j].riskReward;
            if (score2 > score1) {
                StrategyStats temp = strategies[i];
                strategies[i] = strategies[j];
                strategies[j] = temp;
            }
        }
    }
    
    for (int i = 0; i < 5; i++) {
        Print(StringFormat("%4d | %-13s | %6d | %5.1f | %4.2f | %6.2f | %6d",
                          i + 1,
                          strategies[i].name,
                          strategies[i].trades,
                          strategies[i].winRate,
                          strategies[i].riskReward,
                          strategies[i].profit - strategies[i].loss,
                          strategies[i].trades));
    }
} 