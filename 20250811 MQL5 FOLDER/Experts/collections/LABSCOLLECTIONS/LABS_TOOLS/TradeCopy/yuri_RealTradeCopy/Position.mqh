//+------------------------------------------------------------------+
//|                                                     Position.mqh |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#include <Arrays\Functions.mqh>
#include <Trade\PositionInfo.mqh>

struct Position {
   ulong ticket;
   datetime openTime;
   long positionType;
   double volume;
   string symbol;
   double priceOpen;
   double stopLoss;
   double takeProfit;
   ulong magic;
   string comment;

   Position();
   Position(ulong ticket);
   Position(int pos);

   bool operator!=(const Position& p) const;
   void ReadFromFile(int f);

   Position(CPositionInfo& p);
   string ToString() const;

#ifdef __MQL4__
   void ReadSelected();
#endif
   static string ToString(const Position& p[]);
   static string TitleString();
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Position::Position(void) {
   ticket = 0;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool Position::operator!=(const Position& p) const {
   if(ticket != p.ticket
         || volume != p.volume
         || stopLoss != p.stopLoss
         || takeProfit != p.takeProfit) {
      return true;
   }

   return false;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Position::ReadFromFile(int f) {
   ticket = (ulong) FileReadNumber(f);
   openTime = FileReadDatetime(f);
   positionType = (long) FileReadNumber(f);
   volume = FileReadNumber(f);
   symbol = FileReadString(f);
   priceOpen = FileReadNumber(f);
   stopLoss = FileReadNumber(f);
   takeProfit = FileReadNumber(f);
   magic = (ulong) FileReadNumber(f);
   comment = FileReadString(f);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string Position::ToString() const {
   string sTicket = IntegerToString(ticket);
   if(StringLen(sTicket) > 8) {
      sTicket = ".." + StringSubstr(sTicket, StringLen(sTicket) - 6, 6);
   }

   string sMagic = IntegerToString(magic);
   if(StringLen(sMagic) > 8) {
      sMagic = ".." + StringSubstr(sMagic, StringLen(sMagic) - 6, 6);
   }

   string sType = (positionType == POSITION_TYPE_BUY ? "BUY" : (positionType == POSITION_TYPE_SELL ? "SELL" : "???"));
   return StringFormat("%8s | %19s | %5s | %5.2f | %8s | %9.5f | %9.5f | %9.5f | %8s | %s", sTicket,
                       TimeToString(openTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS),
                       sType,
                       volume,
                       symbol,
                       priceOpen,
                       stopLoss,
                       takeProfit,
                       sMagic,
                       comment
                      );
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string Position::TitleString() {
   return StringFormat("  %8s   %19s  %5s   %5s   %8s   %9s   %9s   %9s   %8s %-s",
                       "[Ticket]", "[Time]", "[Type]", "[Vol]", "[Symbol]",
                       "[Price]", "[SL]", "[TP]", "[Magic]", "[Comment]" );
}


#ifdef __MQL4__

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Position::ReadSelected() {
   ticket = OrderTicket();
   openTime = OrderOpenTime();
   positionType = OrderType();
   volume = OrderLots();
   symbol = OrderSymbol();
   priceOpen = OrderOpenPrice();
   stopLoss = OrderStopLoss();
   takeProfit = OrderTakeProfit();
   magic = OrderMagicNumber();
   comment = OrderComment();
}

#endif

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Position::Position(CPositionInfo &p) {
   ticket = p.Identifier();
   openTime = p.Time();
   positionType = (long) p.PositionType();
   volume = p.Volume();
   symbol = p.Symbol();
   priceOpen = p.PriceOpen();
   stopLoss = p.StopLoss();
   takeProfit = p.TakeProfit();
   magic = p.Magic();
   comment = p.Comment();
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string Position::ToString(const Position &p[]) {
   int size = ArraySize(p);
   string s = "";

   if (size > 0) {
      s += " [#] " + Position::TitleString() + "\n";
      for(int i = 0; i < size; i++) {
         s += StringFormat("[%2d] ", i) + p[i].ToString() + "\n";
      }
   } else {
      s = "[No positions]";
   }

   return s;
}
//+------------------------------------------------------------------+
