#include <Trade/Trade.mqh>
CTrade m_trade;

input bool initialPositionBuy = true;
input double distance = 15;
input double takeProfit = 5;
input double initialLotSize = 0.01;
input double lotSizeMultiplier = 2;

bool gridCycleRunning = false;
double lastPositionLotSize, lastPositionPrice, priceLevelsSumation, totalLotSizeSummation;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
   {
    return(INIT_SUCCEEDED);
   }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
   {
   }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
   {
    double price = initialPositionBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

    if(!gridCycleRunning)
       {
        StartGridCycle();
       }

    if(initialPositionBuy && price <= lastPositionPrice - distance * _Point * 10 && gridCycleRunning)
       {
        double newPositionLotSize = NormalizeDouble(lastPositionLotSize * lotSizeMultiplier, 2);
        m_trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, newPositionLotSize, price, 0, 0);

        lastPositionLotSize *= lotSizeMultiplier;
        lastPositionPrice = price;
        ObjectCreate(0, "Next Position Price", OBJ_HLINE, 0, 0, lastPositionPrice - distance * _Point * 10);
        ObjectSetInteger(0, "Next Position Price", OBJPROP_COLOR, clrRed);

        priceLevelsSumation += newPositionLotSize * lastPositionPrice;
        totalLotSizeSummation += newPositionLotSize;
        ObjectCreate(0, "Average Price", OBJ_HLINE, 0, 0, priceLevelsSumation / totalLotSizeSummation);
        ObjectSetInteger(0, "Average Price", OBJPROP_COLOR, clrGreen);
       }

    if(!initialPositionBuy && price >= lastPositionPrice + distance * _Point * 10 && gridCycleRunning)
       {
        double newPositionLotSize = NormalizeDouble(lastPositionLotSize * lotSizeMultiplier, 2);
        m_trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, newPositionLotSize, price, 0, 0);

        lastPositionLotSize *= lotSizeMultiplier;
        lastPositionPrice = price;
        ObjectCreate(0, "Next Position Price", OBJ_HLINE, 0, 0, lastPositionPrice - distance * _Point * 10);
        ObjectSetInteger(0, "Next Position Price", OBJPROP_COLOR, clrRed);

        priceLevelsSumation += newPositionLotSize * lastPositionPrice;
        totalLotSizeSummation += newPositionLotSize;
        ObjectCreate(0, "Average Price", OBJ_HLINE, 0, 0, priceLevelsSumation / totalLotSizeSummation);
        ObjectSetInteger(0, "Average Price", OBJPROP_COLOR, clrGreen);
       }

    if(gridCycleRunning)
       {
        if(initialPositionBuy && price >= (priceLevelsSumation / totalLotSizeSummation) + takeProfit * _Point * 10)
            StopGridCycle();

        if(!initialPositionBuy && price <= (priceLevelsSumation / totalLotSizeSummation) - takeProfit * _Point * 10)
            StopGridCycle();
       }

   }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Hedge Cycle Intialization Function                               |
//+------------------------------------------------------------------+
void StartGridCycle()
   {
    double initialPrice = initialPositionBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

    ENUM_ORDER_TYPE positionType = initialPositionBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    m_trade.PositionOpen(_Symbol, positionType, initialLotSize, initialPrice, 0, 0);

    lastPositionLotSize = initialLotSize;
    lastPositionPrice = initialPrice;
    ObjectCreate(0, "Next Position Price", OBJ_HLINE, 0, 0, lastPositionPrice - distance * _Point * 10);
    ObjectSetInteger(0, "Next Position Price", OBJPROP_COLOR, clrRed);

    priceLevelsSumation = initialLotSize * lastPositionPrice;
    totalLotSizeSummation = initialLotSize;

    if(m_trade.ResultRetcode() == 10009)
        gridCycleRunning = true;
   }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Stop Function for a particular Grid Cycle                        |
//+------------------------------------------------------------------+
void StopGridCycle()
   {
    gridCycleRunning = false;
    ObjectDelete(0, "Next Position Price");
    ObjectDelete(0, "Average Price");
    for(int i = PositionsTotal() - 1; i >= 0; i--)
       {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
           {
            m_trade.PositionClose(ticket);
           }
       }
   }
//+------------------------------------------------------------------+
