//+------------------------------------------------------------------+
//|                                                NewsTradingEA.mq5 |
//|                                  Copyright 2024, Your Company    |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Your Company"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//--- Input parameters
input group "=== NEWS TRADING SETTINGS ==="
input int      NewsFilterMinutes = 30;            // Minutes before/after news to avoid trading
input bool     TradeHighImpactOnly = true;        // Trade only high impact news
input double   VolatilityThreshold = 0.001;       // Minimum volatility for news trading
input int      NewsTimeframe = PERIOD_M1;         // Timeframe for news analysis

input group "=== BREAKOUT SETTINGS ==="
input int      BreakoutPeriod = 5;                // Period to measure breakout (minutes)
input double   BreakoutMultiplier = 1.5;          // Breakout threshold multiplier
input int      MaxNewsPositions = 2;              // Maximum positions per news event

input group "=== RISK MANAGEMENT ==="
input double   NewsLotSize = 0.01;                // Lot size for news trading
input double   NewsStopLoss = 50;                 // Stop loss in points
input double   NewsTakeProfit = 100;              // Take profit in points
input int      MagicNumber = 456789;              // Magic number

input group "=== TIME SETTINGS ==="
input bool     UseNewsCalendar = true;            // Use economic calendar
input string   HighImpactCurrencies = "USD,EUR,GBP,JPY"; // High impact currencies

//--- Global variables
CTrade         trade;
CPositionInfo  position;

struct NewsEvent
{
    datetime time;
    string currency;
    string event;
    int impact; // 1=Low, 2=Medium, 3=High
    bool traded;
};

NewsEvent newsEvents[100];
int newsCount = 0;

double preNewsHigh = 0;
double preNewsLow = 0;
bool newsSetupReady = false;
datetime lastNewsTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    trade.SetExpertMagicNumber(MagicNumber);
    
    // Initialize news events (in real implementation, this would come from calendar)
    InitializeNewsEvents();
    
    Print("News Trading EA initialized successfully");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    datetime currentTime = TimeCurrent();
    
    // Check for upcoming news events
    CheckNewsEvents(currentTime);
    
    // Trade news breakouts
    if(newsSetupReady)
    {
        TradeNewsBreakout();
    }
    
    // Manage existing positions
    ManageNewsPositions();
}

//+------------------------------------------------------------------+
//| Initialize news events (demo data)                               |
//+------------------------------------------------------------------+
void InitializeNewsEvents()
{
    // In real implementation, this would fetch from economic calendar
    // This is demo data for illustration
    
    datetime baseTime = TimeCurrent();
    
    // Add some sample news events
    newsEvents[0].time = baseTime + 3600; // 1 hour from now
    newsEvents[0].currency = "USD";
    newsEvents[0].event = "Non-Farm Payrolls";
    newsEvents[0].impact = 3; // High impact
    newsEvents[0].traded = false;
    
    newsEvents[1].time = baseTime + 7200; // 2 hours from now
    newsEvents[1].currency = "EUR";
    newsEvents[1].event = "ECB Interest Rate Decision";
    newsEvents[1].impact = 3; // High impact
    newsEvents[1].traded = false;
    
    newsCount = 2;
}

//+------------------------------------------------------------------+
//| Check for news events                                            |
//+------------------------------------------------------------------+
void CheckNewsEvents(datetime currentTime)
{
    for(int i = 0; i < newsCount; i++)
    {
        if(newsEvents[i].traded) continue;
        
        // Check if we're in the news window
        int minutesToNews = (int)((newsEvents[i].time - currentTime) / 60);
        
        // Setup for news trading (5-10 minutes before news)
        if(minutesToNews >= 5 && minutesToNews <= 10)
        {
            if(!newsSetupReady)
            {
                SetupNewsTrading();
                lastNewsTime = newsEvents[i].time;
            }
        }
        
        // Disable trading around news time
        if(MathAbs(minutesToNews) <= NewsFilterMinutes)
        {
            if(minutesToNews <= 0 && minutesToNews >= -NewsFilterMinutes)
            {
                newsEvents[i].traded = true;
                newsSetupReady = false;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Setup news trading parameters                                    |
//+------------------------------------------------------------------+
void SetupNewsTrading()
{
    // Calculate pre-news high and low
    preNewsHigh = 0;
    preNewsLow = 999999;
    
    for(int i = 1; i <= BreakoutPeriod; i++)
    {
        double high = iHigh(_Symbol, NewsTimeframe, i);
        double low = iLow(_Symbol, NewsTimeframe, i);
        
        if(high > preNewsHigh) preNewsHigh = high;
        if(low < preNewsLow) preNewsLow = low;
    }
    
    newsSetupReady = true;
    Print("News trading setup ready. Range: ", preNewsLow, " - ", preNewsHigh);
}

//+------------------------------------------------------------------+
//| Trade news breakout                                              |
//+------------------------------------------------------------------+
void TradeNewsBreakout()
{
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double range = preNewsHigh - preNewsLow;
    double breakoutLevel = range * BreakoutMultiplier;
    
    // Check for breakout above resistance
    if(currentPrice > preNewsHigh + breakoutLevel)
    {
        if(CountNewsPositions() < MaxNewsPositions)
        {
            OpenNewsBuyOrder();
        }
    }
    // Check for breakout below support
    else if(currentPrice < preNewsLow - breakoutLevel)
    {
        if(CountNewsPositions() < MaxNewsPositions)
        {
            OpenNewsSellOrder();
        }
    }
}

//+------------------------------------------------------------------+
//| Open news buy order                                              |
//+------------------------------------------------------------------+
void OpenNewsBuyOrder()
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double sl = ask - NewsStopLoss * _Point;
    double tp = ask + NewsTakeProfit * _Point;
    
    if(trade.Buy(NewsLotSize, _Symbol, ask, sl, tp, "News Breakout Buy"))
    {
        Print("News buy order opened at ", ask);
    }
}

//+------------------------------------------------------------------+
//| Open news sell order                                             |
//+------------------------------------------------------------------+
void OpenNewsSellOrder()
{
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double sl = bid + NewsStopLoss * _Point;
    double tp = bid - NewsTakeProfit * _Point;
    
    if(trade.Sell(NewsLotSize, _Symbol, bid, sl, tp, "News Breakout Sell"))
    {
        Print("News sell order opened at ", bid);
    }
}

//+------------------------------------------------------------------+
//| Count news positions                                             |
//+------------------------------------------------------------------+
int CountNewsPositions()
{
    int count = 0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(position.SelectByIndex(i))
        {
            if(position.Symbol() == _Symbol && position.Magic() == MagicNumber)
            {
                count++;
            }
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Manage news positions                                            |
//+------------------------------------------------------------------+
void ManageNewsPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(position.SelectByIndex(i))
        {
            if(position.Symbol() == _Symbol && position.Magic() == MagicNumber)
            {
                // Close positions after certain time or conditions
                datetime openTime = (datetime)position.Time();
                if(TimeCurrent() - openTime > 3600) // Close after 1 hour
                {
                    trade.PositionClose(position.Ticket());
                    Print("News position closed after time limit");
                }
                
                // Apply trailing stop for profitable positions
                ApplyNewsTrailingStop(position.Ticket());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Apply trailing stop for news positions                           |
//+------------------------------------------------------------------+
void ApplyNewsTrailingStop(ulong ticket)
{
    if(!position.SelectByTicket(ticket)) return;
    
    double profit = position.Profit();
    if(profit <= 0) return; // Only trail profitable positions
    
    double currentPrice;
    double newSL;
    double trailDistance = NewsStopLoss * 0.5 * _Point; // Trail at half the original SL
    
    if(position.PositionType() == POSITION_TYPE_BUY)
    {
        currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        newSL = currentPrice - trailDistance;
        
        if(newSL > position.StopLoss())
        {
            trade.PositionModify(ticket, newSL, position.TakeProfit());
        }
    }
    else if(position.PositionType() == POSITION_TYPE_SELL)
    {
        currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        newSL = currentPrice + trailDistance;
        
        if(newSL < position.StopLoss() || position.StopLoss() == 0)
        {
            trade.PositionModify(ticket, newSL, position.TakeProfit());
        }
    }
}

//+------------------------------------------------------------------+
//| Check if currency is in high impact list                         |
//+------------------------------------------------------------------+
bool IsHighImpactCurrency(string currency)
{
    return StringFind(HighImpactCurrencies, currency) >= 0;
} 