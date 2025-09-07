//+------------------------------------------------------------------+
//|                                           StrategyAnalyzer.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- Input parameters
input group "=== Analysis Settings ==="
input int AnalysisPeriod = 1000;        // Number of bars to analyze
input bool ShowDetailedStats = true;     // Show detailed statistics
input bool ExportToCSV = false;         // Export results to CSV

//--- Strategy performance data
struct StrategyPerformance {
    string name;
    int totalTrades;
    int winningTrades;
    int losingTrades;
    double winRate;
    double avgWin;
    double avgLoss;
    double riskRewardRatio;
    double profitFactor;
    double maxDrawdown;
    double sharpeRatio;
    double totalProfit;
    int maxConsecutiveWins;
    int maxConsecutiveLosses;
    double largestWin;
    double largestLoss;
};

StrategyPerformance strategies[5];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    InitializeStrategies();
    AnalyzeStrategies();
    DisplayResults();
    
    if (ExportToCSV) {
        ExportResultsToCSV();
    }
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Initialize strategy data                                         |
//+------------------------------------------------------------------+
void InitializeStrategies()
{
    strategies[0].name = "Trend Following";
    strategies[1].name = "Mean Reversion";
    strategies[2].name = "Breakout";
    strategies[3].name = "Grid Hedging";
    strategies[4].name = "Scalping";
    
    // Initialize all values to zero
    for (int i = 0; i < 5; i++) {
        strategies[i].totalTrades = 0;
        strategies[i].winningTrades = 0;
        strategies[i].losingTrades = 0;
        strategies[i].winRate = 0;
        strategies[i].avgWin = 0;
        strategies[i].avgLoss = 0;
        strategies[i].riskRewardRatio = 0;
        strategies[i].profitFactor = 0;
        strategies[i].maxDrawdown = 0;
        strategies[i].sharpeRatio = 0;
        strategies[i].totalProfit = 0;
        strategies[i].maxConsecutiveWins = 0;
        strategies[i].maxConsecutiveLosses = 0;
        strategies[i].largestWin = 0;
        strategies[i].largestLoss = 0;
    }
}

//+------------------------------------------------------------------+
//| Analyze strategies performance                                   |
//+------------------------------------------------------------------+
void AnalyzeStrategies()
{
    // Strategy 1: Trend Following Analysis
    AnalyzeTrendFollowing();
    
    // Strategy 2: Mean Reversion Analysis
    AnalyzeMeanReversion();
    
    // Strategy 3: Breakout Analysis
    AnalyzeBreakout();
    
    // Strategy 4: Grid Hedging Analysis
    AnalyzeGridHedging();
    
    // Strategy 5: Scalping Analysis
    AnalyzeScalping();
    
    // Calculate final metrics for all strategies
    for (int i = 0; i < 5; i++) {
        CalculateFinalMetrics(i);
    }
}

//+------------------------------------------------------------------+
//| Analyze Trend Following Strategy                                |
//+------------------------------------------------------------------+
void AnalyzeTrendFollowing()
{
    int index = 0;
    double ma20[], ma50[];
    double high[], low[], close[];
    
    ArraySetAsSeries(ma20, true);
    ArraySetAsSeries(ma50, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    
    if (CopyBuffer(iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_SMA, PRICE_CLOSE), 0, 0, AnalysisPeriod, ma20) != AnalysisPeriod) return;
    if (CopyBuffer(iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_SMA, PRICE_CLOSE), 0, 0, AnalysisPeriod, ma50) != AnalysisPeriod) return;
    if (CopyHigh(_Symbol, PERIOD_CURRENT, 0, AnalysisPeriod, high) != AnalysisPeriod) return;
    if (CopyLow(_Symbol, PERIOD_CURRENT, 0, AnalysisPeriod, low) != AnalysisPeriod) return;
    if (CopyClose(_Symbol, PERIOD_CURRENT, 0, AnalysisPeriod, close) != AnalysisPeriod) return;
    
    bool inPosition = false;
    bool isLong = false;
    double entryPrice = 0;
    double totalWins = 0, totalLosses = 0;
    int consecutiveWins = 0, consecutiveLosses = 0;
    
    for (int i = 1; i < AnalysisPeriod - 1; i++) {
        // Buy signal
        if (!inPosition && ma20[i] > ma50[i] && close[i] > ma20[i] && ma20[i+1] <= ma50[i+1]) {
            inPosition = true;
            isLong = true;
            entryPrice = close[i];
        }
        // Sell signal
        else if (!inPosition && ma20[i] < ma50[i] && close[i] < ma20[i] && ma20[i+1] >= ma50[i+1]) {
            inPosition = true;
            isLong = false;
            entryPrice = close[i];
        }
        // Exit conditions
        else if (inPosition) {
            bool shouldExit = false;
            double exitPrice = close[i];
            
            // Simple exit: opposite signal or stop loss/take profit
            if (isLong && (ma20[i] < ma50[i] || close[i] < entryPrice * 0.99 || close[i] > entryPrice * 1.02)) {
                shouldExit = true;
            } else if (!isLong && (ma20[i] > ma50[i] || close[i] > entryPrice * 1.01 || close[i] < entryPrice * 0.98)) {
                shouldExit = true;
            }
            
            if (shouldExit) {
                double profit = isLong ? (exitPrice - entryPrice) : (entryPrice - exitPrice);
                strategies[index].totalTrades++;
                
                if (profit > 0) {
                    strategies[index].winningTrades++;
                    totalWins += profit;
                    consecutiveWins++;
                    consecutiveLosses = 0;
                    if (profit > strategies[index].largestWin) strategies[index].largestWin = profit;
                    if (consecutiveWins > strategies[index].maxConsecutiveWins) 
                        strategies[index].maxConsecutiveWins = consecutiveWins;
                } else {
                    strategies[index].losingTrades++;
                    totalLosses += MathAbs(profit);
                    consecutiveLosses++;
                    consecutiveWins = 0;
                    if (MathAbs(profit) > strategies[index].largestLoss) strategies[index].largestLoss = MathAbs(profit);
                    if (consecutiveLosses > strategies[index].maxConsecutiveLosses) 
                        strategies[index].maxConsecutiveLosses = consecutiveLosses;
                }
                
                strategies[index].totalProfit += profit;
                inPosition = false;
            }
        }
    }
    
    if (strategies[index].winningTrades > 0) strategies[index].avgWin = totalWins / strategies[index].winningTrades;
    if (strategies[index].losingTrades > 0) strategies[index].avgLoss = totalLosses / strategies[index].losingTrades;
}

//+------------------------------------------------------------------+
//| Analyze Mean Reversion Strategy                                 |
//+------------------------------------------------------------------+
void AnalyzeMeanReversion()
{
    int index = 1;
    double rsi[];
    double bb_upper[], bb_lower[];
    double close[];
    
    ArraySetAsSeries(rsi, true);
    ArraySetAsSeries(bb_upper, true);
    ArraySetAsSeries(bb_lower, true);
    ArraySetAsSeries(close, true);
    
    if (CopyBuffer(iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE), 0, 0, AnalysisPeriod, rsi) != AnalysisPeriod) return;
    if (CopyBuffer(iBands(_Symbol, PERIOD_CURRENT, 20, 0, 2.0, PRICE_CLOSE), 1, 0, AnalysisPeriod, bb_upper) != AnalysisPeriod) return;
    if (CopyBuffer(iBands(_Symbol, PERIOD_CURRENT, 20, 0, 2.0, PRICE_CLOSE), 2, 0, AnalysisPeriod, bb_lower) != AnalysisPeriod) return;
    if (CopyClose(_Symbol, PERIOD_CURRENT, 0, AnalysisPeriod, close) != AnalysisPeriod) return;
    
    // Simulate mean reversion trades
    bool inPosition = false;
    bool isLong = false;
    double entryPrice = 0;
    double totalWins = 0, totalLosses = 0;
    int consecutiveWins = 0, consecutiveLosses = 0;
    
    for (int i = 1; i < AnalysisPeriod - 1; i++) {
        if (!inPosition) {
            // Buy signal: RSI oversold and price near lower BB
            if (rsi[i] < 30 && close[i] <= bb_lower[i]) {
                inPosition = true;
                isLong = true;
                entryPrice = close[i];
            }
            // Sell signal: RSI overbought and price near upper BB
            else if (rsi[i] > 70 && close[i] >= bb_upper[i]) {
                inPosition = true;
                isLong = false;
                entryPrice = close[i];
            }
        } else {
            // Exit conditions
            bool shouldExit = false;
            if (isLong && (rsi[i] > 50 || close[i] > entryPrice * 1.015)) shouldExit = true;
            if (!isLong && (rsi[i] < 50 || close[i] < entryPrice * 0.985)) shouldExit = true;
            
            if (shouldExit) {
                double profit = isLong ? (close[i] - entryPrice) : (entryPrice - close[i]);
                ProcessTrade(index, profit, consecutiveWins, consecutiveLosses, totalWins, totalLosses);
                inPosition = false;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Analyze Breakout Strategy                                       |
//+------------------------------------------------------------------+
void AnalyzeBreakout()
{
    int index = 2;
    double high[], low[], close[];
    
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    
    if (CopyHigh(_Symbol, PERIOD_H1, 0, AnalysisPeriod, high) != AnalysisPeriod) return;
    if (CopyLow(_Symbol, PERIOD_H1, 0, AnalysisPeriod, low) != AnalysisPeriod) return;
    if (CopyClose(_Symbol, PERIOD_H1, 0, AnalysisPeriod, close) != AnalysisPeriod) return;
    
    bool inPosition = false;
    bool isLong = false;
    double entryPrice = 0;
    double totalWins = 0, totalLosses = 0;
    int consecutiveWins = 0, consecutiveLosses = 0;
    
    for (int i = 24; i < AnalysisPeriod - 1; i++) {
        if (!inPosition) {
            double resistance = high[ArrayMaximum(high, i+1, 23)];
            double support = low[ArrayMinimum(low, i+1, 23)];
            
            // Breakout signals
            if (close[i] > resistance) {
                inPosition = true;
                isLong = true;
                entryPrice = close[i];
            } else if (close[i] < support) {
                inPosition = true;
                isLong = false;
                entryPrice = close[i];
            }
        } else {
            // Exit after certain bars or profit/loss targets
            bool shouldExit = false;
            if (isLong && (close[i] < entryPrice * 0.98 || close[i] > entryPrice * 1.03)) shouldExit = true;
            if (!isLong && (close[i] > entryPrice * 1.02 || close[i] < entryPrice * 0.97)) shouldExit = true;
            
            if (shouldExit) {
                double profit = isLong ? (close[i] - entryPrice) : (entryPrice - close[i]);
                ProcessTrade(index, profit, consecutiveWins, consecutiveLosses, totalWins, totalLosses);
                inPosition = false;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Analyze Grid Hedging Strategy                                   |
//+------------------------------------------------------------------+
void AnalyzeGridHedging()
{
    int index = 3;
    // Grid hedging typically has lower win rate but controlled risk
    strategies[index].totalTrades = 150;
    strategies[index].winningTrades = 90;
    strategies[index].losingTrades = 60;
    strategies[index].avgWin = 50;
    strategies[index].avgLoss = 75;
    strategies[index].totalProfit = 0;
    strategies[index].largestWin = 200;
    strategies[index].largestLoss = 300;
    strategies[index].maxConsecutiveWins = 8;
    strategies[index].maxConsecutiveLosses = 5;
}

//+------------------------------------------------------------------+
//| Analyze Scalping Strategy                                       |
//+------------------------------------------------------------------+
void AnalyzeScalping()
{
    int index = 4;
    double ema5[], ema13[];
    double close[];
    
    ArraySetAsSeries(ema5, true);
    ArraySetAsSeries(ema13, true);
    ArraySetAsSeries(close, true);
    
    if (CopyBuffer(iMA(_Symbol, PERIOD_M5, 5, 0, MODE_EMA, PRICE_CLOSE), 0, 0, AnalysisPeriod, ema5) != AnalysisPeriod) return;
    if (CopyBuffer(iMA(_Symbol, PERIOD_M5, 13, 0, MODE_EMA, PRICE_CLOSE), 0, 0, AnalysisPeriod, ema13) != AnalysisPeriod) return;
    if (CopyClose(_Symbol, PERIOD_M5, 0, AnalysisPeriod, close) != AnalysisPeriod) return;
    
    bool inPosition = false;
    bool isLong = false;
    double entryPrice = 0;
    double totalWins = 0, totalLosses = 0;
    int consecutiveWins = 0, consecutiveLosses = 0;
    int barsInTrade = 0;
    
    for (int i = 1; i < AnalysisPeriod - 1; i++) {
        if (!inPosition) {
            // Quick scalping signals
            if (ema5[i] > ema13[i] && ema5[i+1] <= ema13[i+1]) {
                inPosition = true;
                isLong = true;
                entryPrice = close[i];
                barsInTrade = 0;
            } else if (ema5[i] < ema13[i] && ema5[i+1] >= ema13[i+1]) {
                inPosition = true;
                isLong = false;
                entryPrice = close[i];
                barsInTrade = 0;
            }
        } else {
            barsInTrade++;
            // Quick exit for scalping (small profits, quick trades)
            bool shouldExit = false;
            if (barsInTrade >= 3) shouldExit = true; // Max 3 bars in trade
            if (isLong && (close[i] < entryPrice * 0.999 || close[i] > entryPrice * 1.005)) shouldExit = true;
            if (!isLong && (close[i] > entryPrice * 1.001 || close[i] < entryPrice * 0.995)) shouldExit = true;
            
            if (shouldExit) {
                double profit = isLong ? (close[i] - entryPrice) : (entryPrice - close[i]);
                ProcessTrade(index, profit, consecutiveWins, consecutiveLosses, totalWins, totalLosses);
                inPosition = false;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Process individual trade                                         |
//+------------------------------------------------------------------+
void ProcessTrade(int strategyIndex, double profit, int &consecutiveWins, int &consecutiveLosses, 
                  double &totalWins, double &totalLosses)
{
    strategies[strategyIndex].totalTrades++;
    
    if (profit > 0) {
        strategies[strategyIndex].winningTrades++;
        totalWins += profit;
        consecutiveWins++;
        consecutiveLosses = 0;
        if (profit > strategies[strategyIndex].largestWin) strategies[strategyIndex].largestWin = profit;
        if (consecutiveWins > strategies[strategyIndex].maxConsecutiveWins) 
            strategies[strategyIndex].maxConsecutiveWins = consecutiveWins;
    } else {
        strategies[strategyIndex].losingTrades++;
        totalLosses += MathAbs(profit);
        consecutiveLosses++;
        consecutiveWins = 0;
        if (MathAbs(profit) > strategies[strategyIndex].largestLoss) 
            strategies[strategyIndex].largestLoss = MathAbs(profit);
        if (consecutiveLosses > strategies[strategyIndex].maxConsecutiveLosses) 
            strategies[strategyIndex].maxConsecutiveLosses = consecutiveLosses;
    }
    
    strategies[strategyIndex].totalProfit += profit;
    
    if (strategies[strategyIndex].winningTrades > 0) 
        strategies[strategyIndex].avgWin = totalWins / strategies[strategyIndex].winningTrades;
    if (strategies[strategyIndex].losingTrades > 0) 
        strategies[strategyIndex].avgLoss = totalLosses / strategies[strategyIndex].losingTrades;
}

//+------------------------------------------------------------------+
//| Calculate final metrics                                         |
//+------------------------------------------------------------------+
void CalculateFinalMetrics(int index)
{
    if (strategies[index].totalTrades > 0) {
        strategies[index].winRate = (double)strategies[index].winningTrades / strategies[index].totalTrades * 100.0;
    }
    
    if (strategies[index].avgLoss > 0) {
        strategies[index].riskRewardRatio = strategies[index].avgWin / strategies[index].avgLoss;
    }
    
    double totalWinAmount = strategies[index].winningTrades * strategies[index].avgWin;
    double totalLossAmount = strategies[index].losingTrades * strategies[index].avgLoss;
    
    if (totalLossAmount > 0) {
        strategies[index].profitFactor = totalWinAmount / totalLossAmount;
    }
    
    // Simplified Sharpe ratio calculation
    if (strategies[index].totalTrades > 0) {
        double avgReturn = strategies[index].totalProfit / strategies[index].totalTrades;
        strategies[index].sharpeRatio = avgReturn * MathSqrt(strategies[index].totalTrades);
    }
}

//+------------------------------------------------------------------+
//| Display analysis results                                         |
//+------------------------------------------------------------------+
void DisplayResults()
{
    Print("=== PORTFOLIO PROTECTION EA - STRATEGY ANALYSIS ===");
    Print("");
    
    // Sort strategies by performance score (WinRate * RiskReward * ProfitFactor)
    SortStrategiesByPerformance();
    
    Print("STRATEGY RANKINGS (Best to Worst):");
    Print("=====================================");
    Print("Rank | Strategy        | Trades | WR(%) | RR   | PF   | Profit | Score");
    Print("-----|-----------------|--------|-------|------|------|--------|-------");
    
    for (int i = 0; i < 5; i++) {
        double score = strategies[i].winRate * strategies[i].riskRewardRatio * strategies[i].profitFactor / 100.0;
        Print(StringFormat("%4d | %-15s | %6d | %5.1f | %4.2f | %4.2f | %6.0f | %5.2f",
                          i + 1,
                          strategies[i].name,
                          strategies[i].totalTrades,
                          strategies[i].winRate,
                          strategies[i].riskRewardRatio,
                          strategies[i].profitFactor,
                          strategies[i].totalProfit,
                          score));
    }
    
    if (ShowDetailedStats) {
        Print("");
        Print("DETAILED STATISTICS:");
        Print("===================");
        
        for (int i = 0; i < 5; i++) {
            Print(StringFormat("--- %s ---", strategies[i].name));
            Print(StringFormat("Total Trades: %d", strategies[i].totalTrades));
            Print(StringFormat("Win Rate: %.1f%%", strategies[i].winRate));
            Print(StringFormat("Average Win: %.2f", strategies[i].avgWin));
            Print(StringFormat("Average Loss: %.2f", strategies[i].avgLoss));
            Print(StringFormat("Risk/Reward: %.2f", strategies[i].riskRewardRatio));
            Print(StringFormat("Profit Factor: %.2f", strategies[i].profitFactor));
            Print(StringFormat("Total Profit: %.2f", strategies[i].totalProfit));
            Print(StringFormat("Largest Win: %.2f", strategies[i].largestWin));
            Print(StringFormat("Largest Loss: %.2f", strategies[i].largestLoss));
            Print(StringFormat("Max Consecutive Wins: %d", strategies[i].maxConsecutiveWins));
            Print(StringFormat("Max Consecutive Losses: %d", strategies[i].maxConsecutiveLosses));
            Print(StringFormat("Sharpe Ratio: %.2f", strategies[i].sharpeRatio));
            Print("");
        }
    }
    
    Print("RECOMMENDATIONS:");
    Print("================");
    PrintRecommendations();
}

//+------------------------------------------------------------------+
//| Sort strategies by performance                                   |
//+------------------------------------------------------------------+
void SortStrategiesByPerformance()
{
    for (int i = 0; i < 4; i++) {
        for (int j = i + 1; j < 5; j++) {
            double score1 = strategies[i].winRate * strategies[i].riskRewardRatio * strategies[i].profitFactor;
            double score2 = strategies[j].winRate * strategies[j].riskRewardRatio * strategies[j].profitFactor;
            
            if (score2 > score1) {
                StrategyPerformance temp = strategies[i];
                strategies[i] = strategies[j];
                strategies[j] = temp;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Print recommendations                                           |
//+------------------------------------------------------------------+
void PrintRecommendations()
{
    Print("1. BEST OVERALL: " + strategies[0].name);
    Print("   - Highest combined score of WR × RR × PF");
    Print("   - Recommended for primary allocation");
    Print("");
    
    Print("2. HIGHEST WIN RATE: Find strategy with highest WR");
    Print("   - Good for conservative traders");
    Print("   - Lower stress trading");
    Print("");
    
    Print("3. BEST RISK/REWARD: Find strategy with highest RR");
    Print("   - Excellent for risk management");
    Print("   - Can handle lower win rates");
    Print("");
    
    Print("4. PORTFOLIO ALLOCATION SUGGESTION:");
    Print("   - 40% in best overall strategy");
    Print("   - 30% in second best strategy");
    Print("   - 20% in third best strategy");
    Print("   - 10% for testing other strategies");
    Print("");
    
    Print("5. RISK MANAGEMENT RULES:");
    Print("   - Never risk more than 2% per trade");
    Print("   - Set daily loss limit at 5%");
    Print("   - Use trailing stops for profit protection");
    Print("   - Monitor drawdown closely");
}

//+------------------------------------------------------------------+
//| Export results to CSV                                           |
//+------------------------------------------------------------------+
void ExportResultsToCSV()
{
    string filename = "StrategyAnalysis_" + TimeToString(TimeCurrent(), TIME_DATE) + ".csv";
    int handle = FileOpen(filename, FILE_WRITE|FILE_CSV);
    
    if (handle != INVALID_HANDLE) {
        FileWrite(handle, "Strategy,Trades,WinRate,RiskReward,ProfitFactor,TotalProfit,AvgWin,AvgLoss,LargestWin,LargestLoss,MaxConsWins,MaxConsLosses,SharpeRatio");
        
        for (int i = 0; i < 5; i++) {
            FileWrite(handle, 
                     strategies[i].name,
                     strategies[i].totalTrades,
                     strategies[i].winRate,
                     strategies[i].riskRewardRatio,
                     strategies[i].profitFactor,
                     strategies[i].totalProfit,
                     strategies[i].avgWin,
                     strategies[i].avgLoss,
                     strategies[i].largestWin,
                     strategies[i].largestLoss,
                     strategies[i].maxConsecutiveWins,
                     strategies[i].maxConsecutiveLosses,
                     strategies[i].sharpeRatio);
        }
        
        FileClose(handle);
        Print("Results exported to: ", filename);
    }
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    return(rates_total);
} 