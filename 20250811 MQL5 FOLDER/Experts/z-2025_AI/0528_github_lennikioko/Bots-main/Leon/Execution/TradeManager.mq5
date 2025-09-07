//+------------------------------------------------------------------+
//|                                                 TradeManager.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>
#include <Helpers/OrderManagement.mqh>

// Input parameters
input double PartialSize = 0.5;        // Partial Size (0.5 = 50% of position)
input bool MoveToBreakeven = true;     // Move to Breakeven after Partial
input int MinimumProfit = 10;          // Minimum Profit in Points before BE

bool g_partialTaken = false;
ulong g_managedTicket = 0;
double g_originalStopLoss = 0.0;
double g_positionEntryPrice = 0.0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Check if PARTIAL line exists
    if(ObjectFind(ChartID(), "PARTIAL") < 0) {
        Print("Error: PARTIAL line not found on chart!");
        return INIT_FAILED;
    }

    // Reset state variables
    g_partialTaken = false;
    g_managedTicket = 0;
    g_originalStopLoss = 0.0;
    g_positionEntryPrice = 0.0;

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Clean up if needed
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check if we have any open positions
    if(PositionsTotal() == 0) {
        // Reset state if no positions
        g_partialTaken = false;
        g_managedTicket = 0;
        g_originalStopLoss = 0.0;
        g_positionEntryPrice = 0.0;
        return;
    }

    // Get the PARTIAL line price
    double partialPrice = ObjectGetDouble(ChartID(), "PARTIAL", OBJPROP_PRICE);

    // Iterate through positions
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);

        if(ticket == 0) continue;

        // Only manage positions for the current symbol
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

        // Store position details if we haven't yet
        if(g_managedTicket == 0) {
            g_managedTicket = ticket;
            g_originalStopLoss = PositionGetDouble(POSITION_SL);
            g_positionEntryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        }

        // Skip if this isn't our managed position
        if(ticket != g_managedTicket) continue;

        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        double positionVolume = PositionGetDouble(POSITION_VOLUME);

        // Check if partial target is reached
        bool partialTargetReached = false;
        if(posType == POSITION_TYPE_BUY) {
            partialTargetReached = currentPrice >= partialPrice;
        } else {
            partialTargetReached = currentPrice <= partialPrice;
        }

        // Take partial profit if target reached and not taken yet
        if(partialTargetReached && !g_partialTaken) {
            double volumeToClose = NormalizeDouble(positionVolume * PartialSize, 2);

            if(trade.PositionClosePartial(ticket, volumeToClose)) {
                Print("Partial profit taken: ", volumeToClose, " lots");
                g_partialTaken = true;

                // Move stop loss to breakeven if enabled
                if(MoveToBreakeven) {
                    // Calculate minimum distance for breakeven
                    double minMove = MinimumProfit * _Point;
                    bool canMoveToBreakeven = false;

                    if(posType == POSITION_TYPE_BUY) {
                        canMoveToBreakeven = (currentPrice - g_positionEntryPrice) >= minMove;
                    } else {
                        canMoveToBreakeven = (g_positionEntryPrice - currentPrice) >= minMove;
                    }

                    if(canMoveToBreakeven) {
                        double tp = PositionGetDouble(POSITION_TP);
                        if(trade.PositionModify(ticket, g_positionEntryPrice, tp)) {
                            Print("Stop loss moved to breakeven");
                        }
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Custom functions                                                 |
//+------------------------------------------------------------------+