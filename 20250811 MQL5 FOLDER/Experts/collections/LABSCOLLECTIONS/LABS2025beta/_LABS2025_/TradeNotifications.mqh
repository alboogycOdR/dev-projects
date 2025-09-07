//+------------------------------------------------------------------+
//|                                           TradeNotifications.mqh |
//|                                                No Copyright 2024 |
//|                                               mstrkidd@proton.me |
//+------------------------------------------------------------------+
#property library
#property copyright "No Copyright 2024"
#property link      "mstrkidd@proton.me"
#property version   "1.00"

//+------------------------------------------------------------------+
//|                 Send Push Notifications                          |
//+------------------------------------------------------------------+
void SendPushNotification(bool send_open_alert = true, bool send_close_alert = true)
  {
//--- Early exit if no alerts are requested
   if(!send_open_alert && !send_close_alert)
      return;

//--- Static variables persist between function calls
   static double last_volume = 0;
   static int last_num_deals = 0;
   static datetime last_check_time = 0;

//--- Throttle checks to avoid unnecessary processing (delete if you have another method)
   datetime current_time = TimeCurrent();
   if(current_time - last_check_time < 1)  // Don't check more than once per second
      return;
   last_check_time = current_time;

//--- Load recent trading history (last 2 hours)
   if(!HistorySelect(current_time - 7200, current_time))
     {
      Print("SendPushNotification() ERROR: HistorySelect() failed");
      return;
     }

//--- Check if we have any new deals
   int num_deals = HistoryDealsTotal();
   if(num_deals <= last_num_deals)
     {
      last_num_deals = num_deals;
      return;
     }

//--- Get the latest deal
   ulong deal_ticket = HistoryDealGetTicket(num_deals - 1);
   if(deal_ticket == 0)
     {
      Print("SendPushNotification() ERROR: Invalid deal ticket");
      return;
     }

//--- Get deal information
   string symbol = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
   if(symbol == "")
      return;

   long deal_entry = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
   long deal_type = HistoryDealGetInteger(deal_ticket, DEAL_TYPE);

   string message = "";

//--- Handle trade opening
   if(send_open_alert && deal_entry == DEAL_ENTRY_IN &&
      (deal_type == DEAL_TYPE_BUY || deal_type == DEAL_TYPE_SELL))
     {
      double volume;
      if(!HistoryDealGetDouble(deal_ticket, DEAL_VOLUME, volume))
        {
         Print("SendPushNotification() ERROR: Failed to retrieve volume");
         return;
        }

      last_volume = volume;
      message = StringFormat("%s New Trade:\n%s %.2f lots",
                             symbol,
                             EnumToString((ENUM_DEAL_TYPE)deal_type),
                             volume);
     }
//--- Handle trade closing
   else
      if(send_close_alert && deal_entry == DEAL_ENTRY_OUT)
        {
         double profit;
         if(!HistoryDealGetDouble(deal_ticket, DEAL_PROFIT, profit))
           {
            Print("SendPushNotification() ERROR: Failed to retrieve profit");
            return;
           }

         profit = NormalizeDouble(profit, 2);
         message = StringFormat("%s Trade Closed:\nProfit %s$%.2f",
                                symbol,
                                profit < 0 ? "-" : "",
                                MathAbs(profit));
        }

//--- Send notification if we have a message
   if(message != "")
     {
      if(MQLInfoInteger(MQL_TESTER)) // Prevents errors in tester
        {
         Print("\n", message, "\n");
        }
      else
         if(!SendNotification(message))
           {
            Print("SendPushNotification() ERROR: SendNotification() failed");
           }
     }

   last_num_deals = num_deals;
  }

//+------------------------------------------------------------------+