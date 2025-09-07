//+------------------------------------------------------------------+
//|                                               SessionManager.mqh |
//|                                      Copyright 2025, Anyim Ossi. |
//|                                          anyimossi.dev@gmail.com |
//+------------------------------------------------------------------+
#include  <Ossi\LongTails\Utils.mqh>

//+------------------------------------------------------------------+
void UpdateSesionStatus(GridInfo &grid)
{
  if (IsWithinTradingTime(grid.session_time_start, grid.session_time_end))
    grid.session_status = SESSION_RUNNING;
  else grid.session_status = SESSION_OVER;
}
//+------------------------------------------------------------------+
void HandleSessionEnd(CTrade &trader, const GridInfo &grid)
{
  if (IsEmptyChart()) return;

  // clear continuation orders
  ClearContinuationNodes(trader);

  // clear post-session recovery lag
  ClearPostSessionRecoveryNode(trader, grid);
}
//+------------------------------------------------------------------+
void StartSession(const double &progression_sequence[], const string ea_tag)
{ /* Starts a trading session*/
  if (!IsEmptyChart())
    return; // Progression cycle ongoing: Proceeding to manage cycle.
  else
  {
      Print("Starting Trading session within trading time. Current time: ", TimeCurrent());
      
      double order_volume = progression_sequence[0];
      ulong ticket = OpenShort(order_volume, trade);
      if (ticket){
        Base.UpdateGridBase(ticket);
        Base.volume_index = 0;
        Print(__FUNCTION__, ": Started trading session with short at market price.");
      }else
          Print(__FUNCTION__, ": Failed to start new session with short position at market price.");
    }  
}
//+------------------------------------------------------------------+
void ClearPostSessionRecoveryNode(CTrade &trader, const GridInfo &grid)
{
    // One recovery node lags after session ends and cycle ends
    if (PositionSelect(_Symbol)) return;
    if (grid.session_status != SESSION_OVER)  Print(__FUNCTION__,': LTS might not be functioning properly, inappropriate grid placement.');
    
    if (OrdersTotal() == 1)
    {   
        ulong order_ticket = OrderGetTicket(0);
        if (order_ticket != 0)
        {
            double order_price = OrderGetDouble(ORDER_PRICE_OPEN);
            ulong order_ticket = OrderGetInteger(ORDER_TICKET);
            string order_comment = OrderGetString(ORDER_COMMENT);
            double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

            // Confirm node lag
            double threshold = grid.unit * 2;
            double distance = MathAbs(current_price - order_price);
            if (distance > threshold)
            {
                bool deleted = trader.OrderDelete(order_ticket);
                if (deleted)
                    Print(__FUNCTION__, " - Deleted order with ticket: ", order_ticket, " and comment: ", order_comment, " as forgotten order cleanup ");
                else
                    Print(__FUNCTION__, " - Failed to delete order with ticket: ", order_ticket, " and comment: ", order_comment, " as forgotten order cleanup ");
            }
        }
    }
}
//+------------------------------------------------------------------+