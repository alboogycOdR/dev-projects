
#include  <Ossi\LongTails\Utils.mqh>
//+------------------------------------------------------------------+

void PlaceContinuationNode(CTrade &trader, ulong reference_ticket, const GridInfo &grid)
{
    const int session_status = grid.session_status;
    if (session_status == SESSION_OVER) return;

    if (PositionSelectByTicket(reference_ticket))
    {
        // XXX: call core rules
        GridNode node;
        node.name = EA_CONTINUATION_TAG + " node";
        // Get ticket details
        long reference_type = PositionGetInteger(POSITION_TYPE);
        double reference_price = PositionGetDouble(POSITION_PRICE_OPEN);
        double take_profit = PositionGetDouble(POSITION_TP);

        // Assert Continuation Node
        node.volume = grid.progression_sequence[0];
        node.type = (reference_type == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP;
        node.price = reference_price + ((reference_type == POSITION_TYPE_BUY) ? (grid.target+grid.spread) : -grid.target);
         
        // Check if an order already exists at the node price
        ulong ticket_exists = NodeExistsAtPrice(node.price);
        if (ticket_exists!=0)
        {
            Print(__FUNCTION__, " - Continuation node with ticket:",ticket_exists , " already exists at price: ", node.price);
            return;
        }

        // Place a grid node
        node.comment = EA_TAG +" "+ node.name +" as "+ EnumToString(node.type);
        bool placed = trader.OrderOpen(_Symbol, node.type, node.volume, 0.0, node.price, 0, 0, ORDER_TIME_GTC, 0, node.comment);
        if (!placed)// Potential invalid price,handle stop limit
            Print(__FUNCTION__, " - Failed to place ", node.type, " continuation node on ", reference_type);
    }
    else 
    {
        Print(__FUNCTION__, " - FATAL. Continuation node can only be placed on open position. Reference ticket could not be selected"); // Rule 9
        return;
    }
}

void PlaceRecoveryNode(CTrade &trader, const GridInfo &grid, const GridBase &base) // Cannot pass pointer to type struct
{
    // Reference ticket type
    ulong reference_ticket = base.ticket;
    string reference_type = "";

    // Validate reference ticket
    if (PositionSelectByTicket(reference_ticket))
        reference_type = EnumToString((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE));
    else if (OrderSelect(reference_ticket))
    {
        reference_type = EnumToString((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)); 
        if (reference_type != EnumToString(ORDER_TYPE_BUY_STOP)){ // order must be a recovery buy stop
            Print(__FUNCTION__, " - FATAL. Recovery node can only be placed on buy stop"); // Rule 7
            return;
        }
        
        if (!IsRecoveryGap(grid, trader)){
            Print("Setup is not a Recovery Gap");
            return;
        }
    }
    else 
    {
        Print(__FUNCTION__, " - FATAL. Recovery node can only be placed on open position or buy stop. Reference ticket could not be selected"); // Rule 7
        return;
    }
    // XXX: call core rules

    // Assert Node values
    GridNode node;
    node.name = EA_RECOVERY_TAG + " node";
    node = AssertRecoveryNode(node, reference_ticket, grid, base);
    if (node.price == -1.0) return;

    // Check if an order already exists at the node price
     ulong ticket_exists = NodeExistsAtPrice(node.price);
     if (ticket_exists!=0)
     {
         Print(__FUNCTION__, " - Recovery node with ticket:",ticket_exists , " already exists at price: ", node.price);
         return;
     }

     // Place a grid node
     node.comment = EA_TAG +" "+ node.name +" as "+ EnumToString(node.type);
     bool placed = trader.OrderOpen(_Symbol, node.type, node.volume, 0.0, node.price, 0, 0, ORDER_TIME_GTC, 0, node.comment);
     if (!placed)// Potential invalid price,handle stop limit
         Print(__FUNCTION__, " - Failed to place ", node.type, " recovery node on ", reference_type);    
}

GridNode AssertRecoveryNode(GridNode &node, ulong ref_ticket, const GridInfo &grid, const GridBase &base)
{
    // If reference ticket is open position
    if (PositionSelectByTicket(ref_ticket))
    {
        if (base.name == NULL_BASE_NAME)
        {
            Print(__FUNCTION__," unable to assert recovery node on grid base. Please pass valid Base data not null.");
            node.price = -1.0;
            return node; // as it came
        }
        // Get ticket details
        long reference_type = PositionGetInteger(POSITION_TYPE);
        double reference_price = PositionGetDouble(POSITION_PRICE_OPEN);
        double stop_loss = PositionGetDouble(POSITION_SL);
        double reference_volume = PositionGetDouble(POSITION_VOLUME);

        // Set order details
        int reference_volume_index = base.volume_index;
        node.volume = grid.progression_sequence[reference_volume_index+1];
        node.type = (reference_type == POSITION_TYPE_SELL) ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP;
        node.price = reference_price +( (reference_type == POSITION_TYPE_SELL) ? (grid.unit+grid.spread) : -grid.unit);
    }

    // If reference ticket is pending order
    else if (OrderSelect(ref_ticket))
    {
        // Get ticket details
        long reference_type = OrderGetInteger(ORDER_TYPE);
        double reference_price = OrderGetDouble(ORDER_PRICE_OPEN);
        double reference_volume = OrderGetDouble(ORDER_VOLUME_CURRENT);
        string reference_comment = OrderGetString(ORDER_COMMENT);
        
        // Set order details 
        node.volume = reference_volume;
        node.type = ORDER_TYPE_SELL_STOP;
        node.price = reference_price - (grid.unit + grid.spread);
    }
    return node;
}

ulong IsRecoveryGap(const GridInfo &grid, CTrade &trade_obj)
{
    // Validate that current price is between the recovery node and grid unit
    // Get current recovery buy stop
    double curr_recovery_node_price = 0;
    ulong recovery_node_ticket = 0;
    
    for (int i = OrdersTotal() - 1; i >= 0; i--)
        {
        ulong order_ticket = OrderGetTicket(i);
        if (!OrderSelect(order_ticket)) continue;

        if ((OrderGetString(ORDER_SYMBOL) == _Symbol) &&
            ((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP) &&
            (StringFind(OrderGetString(ORDER_COMMENT), EA_RECOVERY_TAG) != -1))
            {
                recovery_node_ticket = order_ticket;
                curr_recovery_node_price = OrderGetDouble(ORDER_PRICE_OPEN);
                break;
            }
        }
    if (!curr_recovery_node_price) return 0;

    double price_current = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double recovery_threshold = curr_recovery_node_price - grid.unit;
    if (price_current > recovery_threshold && price_current < curr_recovery_node_price)
        return recovery_node_ticket;
    return 0;
}

//+------------------------------------------------------------------+