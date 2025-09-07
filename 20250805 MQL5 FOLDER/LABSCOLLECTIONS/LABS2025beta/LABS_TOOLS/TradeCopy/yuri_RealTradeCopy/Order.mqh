//+------------------------------------------------------------------+
//|                                                     Order.mqh |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#include <Arrays\Functions.mqh>
#include <Trade\OrderInfo.mqh>

struct Order {
   ulong ticket;
   datetime timeSetup;
   long orderType;
   double volumeInitial;
   double volume;
   string symbol;
   double priceOpen;
   double stopLoss;
   double takeProfit;
   datetime expiration;
   ulong magic;
   string comment;

   Order();
   Order(ulong ticket);
   Order(int pos);

   bool operator!=(const Order& o) const;
   void ReadFromFile(int f);

   Order(COrderInfo& o);
   
#ifdef __MQL4__
   void ReadSelected();
#endif
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Order::Order(void) {
   ticket = 0;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool Order::operator!=(const Order& o) const {
   if(ticket != o.ticket
         || volumeInitial != o.volumeInitial
         || stopLoss != o.stopLoss
         || takeProfit != o.takeProfit
         || expiration != o.expiration) {
      return true;
   }

   return false;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Order::ReadFromFile(int f) {
   ticket = (ulong) FileReadNumber(f);
   timeSetup = FileReadDatetime(f);
   orderType = (long) FileReadNumber(f);
   volumeInitial = FileReadNumber(f);
   volume = FileReadNumber(f);
   symbol = FileReadString(f);
   priceOpen = FileReadNumber(f);
   stopLoss = FileReadNumber(f);
   takeProfit = FileReadNumber(f);
   expiration = FileReadDatetime(f);
   magic = (ulong) FileReadNumber(f);
   comment = FileReadString(f);
}

#ifdef __MQL4__
void Order::ReadSelected() {
   ticket = OrderTicket();
   timeSetup = OrderOpenTime();
   orderType = OrderType();
   volumeInitial = OrderLots();
   volume = OrderLots();
   symbol = OrderSymbol();
   priceOpen = OrderOpenPrice();
   stopLoss = OrderStopLoss();
   takeProfit = OrderTakeProfit();
   expiration = OrderExpiration();
   magic = OrderMagicNumber();
   comment = OrderComment();
}
#endif
Order::Order(COrderInfo &o) {
   ticket = o.Ticket();
   timeSetup = o.TimeSetup();
   orderType = (long) o.OrderType();
   volumeInitial = o.VolumeInitial();
   volume = o.VolumeCurrent();
   symbol = o.Symbol();
   priceOpen = o.PriceOpen();
   stopLoss = o.StopLoss();
   takeProfit = o.TakeProfit();
   expiration = o.TimeExpiration();
   magic = o.Magic();
   comment = o.Comment();
}

//+------------------------------------------------------------------+
