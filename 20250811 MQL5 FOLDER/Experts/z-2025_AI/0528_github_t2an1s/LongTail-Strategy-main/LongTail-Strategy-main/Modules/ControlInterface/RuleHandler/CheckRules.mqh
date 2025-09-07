//+------------------------------------------------------------------+
//|                                            StrictRuleManager.mqh |
//|                                      Copyright 2025, Anyim Ossi. |
//|                                          anyimossi.dev@gmail.com |
//+------------------------------------------------------------------+
#ifndef RuleManager_MQH
#define RuleManager_MQH

#property copyright "Copyright 2025, Anyim Ossi."
#property link      "anyimossi.dev@gmail.com"

#include  "Utils.mqh"

//+------------------------------------------------------------------+
// Controller function checks all rules.
void EnforceStrategyRules(CTrade &trader, GridInfo &grid, GridBase &base)
{
    NoInterferenceOnPos(trader);
    NoInterferenceOnOrders(trader);
    EnforceExits(grid, trader);

    CheckSLTP();
    EnforceCoreRules(trader);
    //EnforceGridPlacementAccuracy(trader);
    
    //CheckVolumeAccuracy(grid, base);
    //CheckSequenceAccuracy();
    
    // consider unseen edge cases
    // - deleted node by foreign
}

//+------------------------------------------------------------------+
// check if orders are priced correctly, relative to open position
void EnforceGridPlacementAccuracy(GridInfo &grid, CTrade &trader)
{
    // get the base by selecting open position
    // calculate correct recovery node// open_price - grid.unit for buy position
    // calculate correct continuation node// open_price + grid.target + grid.spread for buy position

    // Respect allowed deviation

    // get actual recovery node
    // if price don't match,modify

    // get actual continuation node
    // if price don't match,modify
}
void NoInterferenceOnPos(CTrade &trader)
{
    // Handle human interference on Positions.
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        string symbol = PositionGetSymbol(i);
        if (symbol == _Symbol)
        {
            string comment = PositionGetString(POSITION_COMMENT);
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            if (StringFind(comment, EA_TAG) == -1) // EA_TAG not found in comment
            {
                if (!trader.PositionClose(ticket))
                    Print(__FUNCTION__, " - Error: Failed to close foreign position with ticket: ", ticket);
                else
                    Print(__FUNCTION__, " - Closed foreign position with ticket: ", ticket);
            }
        }
    }
}
void NoInterferenceOnOrders(CTrade &trader)
{
    // Handle human interference on Orders
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        //XXX: Check if request to stop bot first.
        ulong order_ticket = OrderGetTicket(i);
        if (order_ticket == 0) continue;
        if (OrderGetString(ORDER_SYMBOL) != _Symbol) continue;

        string comment = OrderGetString(ORDER_COMMENT);
        ulong ticket = OrderGetInteger(ORDER_TICKET);
        if (StringFind(comment, EA_TAG) == -1) // EA_TAG not found in comment
        {
            if (!trader.OrderDelete(ticket))
                Print(__FUNCTION__, " - Error: Failed to delete foreign order with ticket: ", ticket);
            else
                Print(__FUNCTION__, " - Deleted foreign order with ticket: ", ticket);
        }
    }
}
void EnforceExits(GridInfo &grid, CTrade &trader)
{ //XXX: Use coherence, use SetExits
    // Enforce no interference on exits(SL/TP) on all open positions
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        string symbol = PositionGetSymbol(i);
        if (symbol == _Symbol)
        {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            if (!ticket) continue;
            double tp = PositionGetDouble(POSITION_TP);
            double sl = PositionGetDouble(POSITION_SL);
            double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

            // Supposed exits
            double corr_sl = NormalizeDouble(open_price - (type == POSITION_TYPE_BUY ? grid.unit : -grid.unit), _Digits);
            double corr_tp = NormalizeDouble(open_price + (type == POSITION_TYPE_BUY ? grid.target : -grid.target), _Digits);

            // Ensure SL and TP are within symbol limits
            double min_distance = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
            if (MathAbs(corr_tp - current_price) < min_distance || MathAbs(current_price - corr_sl) < min_distance)
            {
                Print(__FUNCTION__, " - Warning: Corrected SL/TP for position with ticket ", ticket, " violates symbol stop limits. Skipping modification.");
                continue;
            }

            // Correct tampered exits
            if (tp != corr_tp || sl != corr_sl)
            {
                if (!trader.PositionModify(ticket, corr_sl, corr_tp))
                    Print(__FUNCTION__, " - Error: Failed to modify tampered position with ticket ", ticket);
                else
                    Print(__FUNCTION__, " - Modified inaccurate exits on position with ticket ", ticket);
            }
        }
    }
}

void EnforceCoreRules(CTrade &trader)
{
    // Check positions excess
    if (PositionsTotal() > 1)
    {
        Print(__FUNCTION__, " - Fatal: More than one position open. Closing older");

        // Close all positions except the most recent one. Access by index.
        for (int i = PositionsTotal() - 1; i > 0; i--)
        {
            if (PositionGetTicket(i-1))
            {
                ulong ticket = PositionGetInteger(POSITION_TICKET);
                if (!trader.PositionClose(ticket))
                    Print(__FUNCTION__, " - Error: Failed to close excess position with ticket: ", ticket);
                else
                    Print(__FUNCTION__, " - Closed excess position with ticket: ", ticket);
            }
        }
    }

    // Check orders excess
    if (OrdersTotal() > 2)
    {
        Print(__FUNCTION__, " - Fatal error: More than two orders open. Closing older");

        // Close all orders except the last two. Access by index.
        for (int i = OrdersTotal() - 1; i > 1; i--)
        {
            if (OrderGetTicket(i-2))
            {
                ulong ticket = OrderGetInteger(ORDER_TICKET);
                if (!trader.OrderDelete(ticket))
                    Print(__FUNCTION__, " - Error: Failed to delete excess order with ticket: ", ticket);
                else
                    Print(__FUNCTION__, " - Deleted excess order with ticket: ", ticket);
            }
        }
    }

    // XXX: Check post-session lag, handled by session manager.
}
//+------------------------------------------------------------------+
// Check Stop loss and Take profit
void CheckSLTP()
{
    //Loop all open pos on symbol
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        string symbol = PositionGetSymbol(i);
        if (symbol == _Symbol)
        {
            double tp = PositionGetDouble(POSITION_TP);
            double sl = PositionGetDouble(POSITION_SL);
            
            // Check if TP and SL are set
            if (tp == 0 || sl == 0)
            {
                for (int j = 2; j >= 0; j-- )
                {Print(__FUNCTION__, " - Warning: TP/SL not set for position with ticket: ", PositionGetInteger(POSITION_TICKET));}
            }
        }
    }
}

// check volume of open position from sequence
void CheckVolumeAccuracy(const GridInfo &grid, const GridBase &base)
{/*
    // Check mathematical accuracy across all nodes

    // Check open position volume in sequence
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        string symbol=PositionGetSymbol(i);
        if (symbol == _Symbol)
        {
            double volume = PositionGetDouble(POSITION_VOLUME);
            int sequence[] = grid.progression_sequence;
            bool volume_ok = false;

            for (int j = 0; j < ArraySize(sequence); j++)
            {
                if (volume == sequence[j])
                {
                    volume_ok = true;
                    break;
                }
            }

            if (!volume_ok)
                Print(__FUNCTION__, " - Warning: Volume for position with ticket: ", PositionGetInteger(POSITION_TICKET), " does not match any value in the progression sequence array.");
        }
    }

    // check node volume accuracy by index in sequence
    
    // get recovery volume index
    // base volume should be -1
    // compare first term of sequence with continuation volume
*/}
// check that sequence is init accurate to account balance XXX
void CheckSequenceAccuracy(const GridInfo &grid)
{
    // calculate minimum term
    // compare minimum term with first term of progression sequence

    // RebuildSequence();
}
void RebuildSequence()
{
    // calculate how many points is $1, that should be grid size. exception for rapid moving pairs

  // Updates the progression sequence based on account balance increase.
  // Update every 10% increase or decrease
}

// Implement remote stopping of the bot; use strange order like buystoplimit, moving on, open communication via telegram

#endif // RuleManager_MQH

