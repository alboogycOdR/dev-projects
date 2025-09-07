
#include  <Ossi\LongTails\Utils.mqh>

//+------------------------------------------------------------------+

void SetExits(CTrade &trader, ulong reference_ticket, GridInfo &grid)
{
    if (PositionSelectByTicket(reference_ticket))
    {     
        // Validate the position
        if (PositionGetString(POSITION_SYMBOL) != _Symbol) // Position not on current chart
        {
            Print(__FUNCTION__, " - Cannot modify external symbol. Skipping ticket: ", reference_ticket);
            return;
        }
        
        string position_comment = PositionGetString(POSITION_COMMENT);
        if (StringFind(position_comment, EA_TAG) == -1) // Position not placed by EA, should not be modified
        {
            Print(__FUNCTION__, " - Position was not placed by ",EA_TAG,". Skipping ticket: ", reference_ticket);
            return;
        }

        // Retrieve position details
        double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
        long position_type = PositionGetInteger(POSITION_TYPE);

        // Calculate take profit and stop loss using GridInfo instance
        double risk_size = grid.unit;
        double target = grid.target;
        double take_profit = (position_type == POSITION_TYPE_BUY) ? open_price + target : open_price - target;
        double stop_loss = (position_type == POSITION_TYPE_BUY) ? open_price - risk_size : open_price + risk_size;

        // Modify the position with the new TP and SL values
        bool modified = trader.PositionModify(reference_ticket, stop_loss, take_profit);
        if (modified)
        {
            Print(__FUNCTION__, " - Take profit and stop loss set for ticket: ", reference_ticket, " TP: ", take_profit, " SL: ", stop_loss);
        }
        else
        {
            Print(__FUNCTION__, " FATAL ERROR - Failed to set take profit and stop loss for ticket: ", reference_ticket, " Check stop symbol level");
            // close the open position, avoid further error
            if (trader.PositionClose(reference_ticket))
                Print(__FUNCTION__, " - Position closed due to error in setting TP/SL for ticket: ", reference_ticket);
            else
                Print(__FUNCTION__, " - Failed to close position with ticket: ", reference_ticket, " after TP/SL modification error. Check your account settings.");
        }
    }
    else
    {
        Print(__FUNCTION__, " - TP/SL can only be placed on open positions. Invalid ticket: ", reference_ticket);
    }
}
//+------------------------------------------------------------------+