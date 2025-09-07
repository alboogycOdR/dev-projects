
//+------------------------------------------------------------------+
//|                     NewsEA.mq5 - Dynamic News Filter            |
//|           Allows user to select relevant news categories        |
//+------------------------------------------------------------------+

#property copyright "Müller Peter"
#property version   "1.01"

#include <Trade\Trade.mqh>

// Define an enum for the Expert Advisor mode
enum e_Type {
   Trading = 0,
   Alerting = 1
};

// Input parameters
input e_Type Type = Alerting;
input int Magic = 1125021;
input int TPPoints = 150;
input int SLPoints = 150;
input double Volume = 0.1;
input string NewsCategories = "cpi,ppi,interest rate decision"; // User-defined news categories

//+------------------------------------------------------------------+
bool IsRelevantNews(string eventName)
{
   string categories[];
   int count = StringSplit(NewsCategories, ',', categories);
   
   for(int i = 0; i < count; i++)
   {
      if(StringContains(eventName, categories[i]))
         return true;
   }
   return false;
}
//+------------------------------------------------------------------+
// Modify OnTick function to use IsRelevantNews
void OnTick()
{
   MqlCalendarValue CalendarValues[];
   MqlCalendarEvent CalendarEvent;
   MqlCalendarCountry CalendarCountry;
   static datetime LastRequest = TimeTradeServer();
   static CTrade trade;
   trade.SetExpertMagicNumber(Magic);
   static datetime Expiry = 0;
   
   CalendarValueHistory(CalendarValues, LastRequest, TimeTradeServer() + 50);
   if(ArraySize(CalendarValues) != 0)
      LastRequest = TimeTradeServer() + 50;

   for(int i = 0; i < ArraySize(CalendarValues); i++)
   {
       CalendarEventById(CalendarValues[i].event_id, CalendarEvent);
       CalendarCountryById(CalendarEvent.country_id, CalendarCountry);
       string currency = CalendarCountry.currency;
       
       if(currency == SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE) || 
          currency == SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT))
       {
          if(CalendarEvent.importance == CALENDAR_IMPORTANCE_MODERATE && Type == Alerting)
          {
             Alert("News Event: " + CalendarEvent.name + " at " + TimeToString(CalendarValues[i].time));
          }
          
          if(IsRelevantNews(CalendarEvent.name) && Type == Trading)
          {
             if(Expiry != 0) continue;
             double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
             double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
             Expiry = TimeTradeServer() + 500;
             
             trade.BuyStop(Volume, ask + TPPoints * _Point, NULL, 
                           ask + TPPoints * _Point - SLPoints * _Point, 
                           ask + 2 * TPPoints * _Point);

             trade.SellStop(Volume, bid - TPPoints * _Point, NULL, 
                            bid - TPPoints * _Point + SLPoints * _Point, 
                            bid - 2 * TPPoints * _Point);
          }
       }
   }
   if(TimeTradeServer() > Expiry && Expiry != 0)
   {
      Expiry = 0;
      DeletePending();
   }
}
