//+------------------------------------------------------------------+
//|                                                 GridTradingEA.mq5 |
//|                                  Copyright 2024, Your Company    |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Your Company"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//--- Input parameters
input group "=== GRID SETTINGS ==="
input double   InitialLot = 0.01;                 // Initial lot size
input double   LotMultiplier = 1.5;               // Lot multiplier for grid levels
input int      GridStep = 200;                    // Grid step in points
input int      MaxGridLevels = 10;                // Maximum grid levels
input double   TotalTakeProfit = 500;             // Total take profit in currency

input group "=== RISK MANAGEMENT ==="
input double   MaxDrawdown = 1000;                // Maximum drawdown in currency
input double   MaxRisk = 5.0;                     // Maximum risk percentage
input int      MagicNumber = 789123;              // Magic number

input group "=== TREND FILTER ==="
input bool     UseTrendFilter = true;             // Use trend filter
input int      TrendMA_Period = 50;               // Trend MA period
input bool     OnlyWithTrend = false;             // Trade only with trend

//--- Global variables
CTrade         trade;
CPositionInfo  position;

int            handleTrendMA;
double         trendMA[];

struct GridLevel
{
    double price;
    double lotSize;
    ulong ticket;
    bool isActive;
};

GridLevel buyGrid[20];
GridLevel sellGrid[20];
int activeBuyLevels = 0;
int activeSellLevels = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    trade.SetExpertMagicNumber(MagicNumber);
    
    if(UseTrendFilter)
    {
        handleTrendMA = iMA(_Symbol, PERIOD_CURRENT, TrendMA_Period, 0, MODE_EMA, PRICE_CLOSE);
        if(handleTrendMA == INVALID_HANDLE)
        {
            Print("Error creating trend MA indicator");
            return INIT_FAILED;
        }
        ArraySetAsSeries(trendMA, true);
    }
    
    InitializeGrid();
    Print("Grid Trading EA initialized successfully");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(UseTrendFilter)
        IndicatorRelease(handleTrendMA);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    static datetime lastBar = 0;
    datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(currentBar == lastBar) return;
    lastBar = currentBar;
    
    if(UseTrendFilter)
    {
        if(CopyBuffer(handleTrendMA, 0, 0, 2, trendMA) < 2) return;
    }
    
    // Check drawdown
    if(CheckDrawdown()) return;
    
    // Manage grid
    ManageGrid();
    
    // Check for grid closure
    CheckGridClosure();
}

//+------------------------------------------------------------------+
//| Initialize grid levels                                           |
//+------------------------------------------------------------------+
void InitializeGrid()
{
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Initialize buy grid (below current price)
    for(int i = 0; i < MaxGridLevels; i++)
    {
        buyGrid[i].price = currentPrice - (i + 1) * GridStep * _Point;
        buyGrid[i].lotSize = InitialLot * MathPow(LotMultiplier, i);
        buyGrid[i].ticket = 0;
        buyGrid[i].isActive = false;
    }
    
    // Initialize sell grid (above current price)
    for(int i = 0; i < MaxGridLevels; i++)
    {
        sellGrid[i].price = currentPrice + (i + 1) * GridStep * _Point;
        sellGrid[i].lotSize = InitialLot * MathPow(LotMultiplier, i);
        sellGrid[i].ticket = 0;
        sellGrid[i].isActive = false;
    }
}

//+------------------------------------------------------------------+
//| Manage grid trading                                              |
//+------------------------------------------------------------------+
void ManageGrid()
{
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    bool trendUp = true, trendDown = true;
    
    if(UseTrendFilter)
    {
        trendUp = currentPrice > trendMA[0] && trendMA[0] > trendMA[1];
        trendDown = currentPrice < trendMA[0] && trendMA[0] < trendMA[1];
    }
    
    // Check buy grid levels
    if(!OnlyWithTrend || trendDown)
    {
        for(int i = 0; i < MaxGridLevels; i++)
        {
            if(!buyGrid[i].isActive && currentPrice <= buyGrid[i].price)
            {
                PlaceBuyOrder(i);
            }
        }
    }
    
    // Check sell grid levels
    if(!OnlyWithTrend || trendUp)
    {
        for(int i = 0; i < MaxGridLevels; i++)
        {
            if(!sellGrid[i].isActive && currentPrice >= sellGrid[i].price)
            {
                PlaceSellOrder(i);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Place buy order at grid level                                    |
//+------------------------------------------------------------------+
void PlaceBuyOrder(int level)
{
    if(trade.Buy(buyGrid[level].lotSize, _Symbol, 0, 0, 0, "Grid Buy Level " + IntegerToString(level)))
    {
        buyGrid[level].ticket = trade.ResultOrder();
        buyGrid[level].isActive = true;
        activeBuyLevels++;
        Print("Buy order placed at grid level ", level, " with lot size ", buyGrid[level].lotSize);
    }
}

//+------------------------------------------------------------------+
//| Place sell order at grid level                                   |
//+------------------------------------------------------------------+
void PlaceSellOrder(int level)
{
    if(trade.Sell(sellGrid[level].lotSize, _Symbol, 0, 0, 0, "Grid Sell Level " + IntegerToString(level)))
    {
        sellGrid[level].ticket = trade.ResultOrder();
        sellGrid[level].isActive = true;
        activeSellLevels++;
        Print("Sell order placed at grid level ", level, " with lot size ", sellGrid[level].lotSize);
    }
}

//+------------------------------------------------------------------+
//| Check for grid closure conditions                                |
//+------------------------------------------------------------------+
void CheckGridClosure()
{
    double totalProfit = 0;
    
    // Calculate total profit from all positions
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(position.SelectByIndex(i))
        {
            if(position.Symbol() == _Symbol && position.Magic() == MagicNumber)
            {
                totalProfit += position.Profit();
            }
        }
    }
    
    // Close all positions if total profit target is reached
    if(totalProfit >= TotalTakeProfit)
    {
        CloseAllPositions();
        ResetGrid();
        Print("Grid closed with profit: ", totalProfit);
    }
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(position.SelectByIndex(i))
        {
            if(position.Symbol() == _Symbol && position.Magic() == MagicNumber)
            {
                trade.PositionClose(position.Ticket());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Reset grid after closure                                         |
//+------------------------------------------------------------------+
void ResetGrid()
{
    for(int i = 0; i < MaxGridLevels; i++)
    {
        buyGrid[i].isActive = false;
        buyGrid[i].ticket = 0;
        sellGrid[i].isActive = false;
        sellGrid[i].ticket = 0;
    }
    
    activeBuyLevels = 0;
    activeSellLevels = 0;
    
    // Reinitialize grid at current price
    InitializeGrid();
}

//+------------------------------------------------------------------+
//| Check drawdown limit                                             |
//+------------------------------------------------------------------+
bool CheckDrawdown()
{
    double totalProfit = 0;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(position.SelectByIndex(i))
        {
            if(position.Symbol() == _Symbol && position.Magic() == MagicNumber)
            {
                totalProfit += position.Profit();
            }
        }
    }
    
    if(totalProfit <= -MaxDrawdown)
    {
        Print("Maximum drawdown reached: ", totalProfit);
        CloseAllPositions();
        ResetGrid();
        return true;
    }
    
    return false;
} 