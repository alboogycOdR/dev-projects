//+------------------------------------------------------------------+
//|                                                  GridManager.mqh |
//|                                      Copyright 2025, Anyim Ossi. |
//|                                          anyimossi.dev@gmail.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Anyim Ossi."
#property link      "anyimossi.dev@gmail.com"

#include  "GridNodes.mqh"
#include  "ExitManager.mqh"

//+------------------------------------------------------------------+
void HandleNewPosition(GridBase &base, GridInfo &grid, CTrade &trade_obj)
{
    if (!PositionSelect(_Symbol)) return;
    ulong ticket = PositionGetInteger(POSITION_TICKET);

    // update GridBase
    base.UpdateGridBase(ticket);
    if (StringFind(base.name, EA_RECOVERY_TAG) != -1)
        base.volume_index ++;
    else 
      base.volume_index = 0;
    
    // set TP/SL
    SetExits(trade_obj, ticket, grid);
    
    // Update grid nodes
    DeleteAllPending(trade_obj, _Symbol);
    PlaceRecoveryNode(trade_obj, grid, base);
    PlaceContinuationNode(trade_obj, ticket, grid);
}

//+------------------------------------------------------------------+
void HandleGridGap(GridInfo &grid, GridBase &base, CTrade &trade_obj) // place recovery node on orders only
{
    //XXX: EnforceCoreRules(trade_obj); -> complete and test rules Enforcing first
    // Context validation
    int orders_total = SymbolOrdersTotal();
    if (PositionSelect(_Symbol) || orders_total == 0) return;
    
    if (base.type == POSITION_TYPE_BUY) return;// grid shifts on a short position
    
    ClearContinuationNodes(trade_obj);
    int remaining_orders = SymbolOrdersTotal();
    if (remaining_orders == 0) 
        {Print(__FUNCTION__," FATAL. Unable to handle grid gap, no recovery node found.");
        return;}
    if (remaining_orders > 1) return; // already placed

    // If price is not within range
    ulong recovery_node_ticket = IsRecoveryGap(grid, trade_obj);
    if (!recovery_node_ticket) return;
        
    GridBase null_base; null_base.UpdateOrderAsBase(recovery_node_ticket);
    PlaceRecoveryNode(trade_obj, grid, null_base); // Recovery_node_ticket should never be 0.
}

//+------------------------------------------------------------------+
