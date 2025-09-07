//+------------------------------------------------------------------+
//|                                 CalendarMonitorCached_MOD_EA.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright (c) 2022, MetaQuotes Ltd."
#property description "Output a table with selected calendar events."

#property tester_file "xyz.cal"


#define LOGGING // calendar detailed logs


#include <MQL5Book/MqlTradeSync.mqh>
#include <MQL5Book/PositionFilter.mqh>
#include <MQL5Book/TrailingStop.mqh>
#include <MQL5Book/CalendarFilterCached.mqh>
#include <MQL5Book/CalendarCache.mqh>
#include <MQL5Book/Tableau.mqh>
#include <MQL5Book/AutoPtr.mqh>
#include <MQL5Book/StringUtils.mqh>


//+------------------------------------------------------------------+
//| I N P U T S                                                      |
//+------------------------------------------------------------------+
input group "General filters";
input string Context; // Context (country - 2 chars, currency - 3 chars, empty - all)
input ENUM_CALENDAR_SCOPE Scope = SCOPE_DAY;
input bool UseChartCurrencies = false;
input string CalendarCacheFile = "xyz.cal";

input group "Optional filters";
input ENUM_CALENDAR_EVENT_TYPE_EXT Type = TYPE_ANY;
input ENUM_CALENDAR_EVENT_SECTOR_EXT Sector = SECTOR_ANY;
input ENUM_CALENDAR_EVENT_IMPORTANCE_EXT Importance = IMPORTANCE_HIGH; // Importance (at least)
input string Text;
input ENUM_CALENDAR_HAS_VALUE HasActual = HAS_ANY;
input ENUM_CALENDAR_HAS_VALUE HasForecast = HAS_ANY;
input ENUM_CALENDAR_HAS_VALUE HasPrevious = HAS_ANY;
input ENUM_CALENDAR_HAS_VALUE HasRevised = HAS_ANY;
input int Limit = 30;

input group "Rendering settings";
input ENUM_BASE_CORNER Corner = CORNER_LEFT_UPPER;
input int Margins = 6;
input int FontSize = 8;
input string FontName = "Consolas";
input color BackgroundColor = clrGreen;
input uchar BackgroundTransparency = 128;    // BackgroundTransparency (255 - opaque, 0 - glassy)
input uint CALENDAR_REFRESH_COUNT=60;// REFRESH_COUNT(Secs)

//+------------------------------------------------------------------+
//| G L O B A L S                                                    |
//+------------------------------------------------------------------+
AutoPtr<CalendarFilter> fptr;
AutoPtr<Tableau> tableau;
AutoPtr<CalendarCache> cache;
AutoPtr<TrailingStop> trailing[];


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input double Volume;               // Volume (0 = minimal lot)
input int Distance2SLTP = 500;     // Distance to SL/TP in points (0 = no)
input uint MultiplePositions = 25;
double Lot;
bool Hedging;
string Base;
string Profit;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   /* for trading */
   if(AccountInfoInteger(ACCOUNT_TRADE_MODE) != ACCOUNT_TRADE_MODE_DEMO)
     {
      Alert("This is a test EA! Run it on a DEMO account only!");
      return INIT_FAILED;
     }

   Lot = Volume == 0 ? SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN) : Volume;
   Hedging = AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;
   Base = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
   Profit = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);
   //const string base = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
   //const string profit = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);





   /*__     for trading      __*/

   cache = new CalendarCache(CalendarCacheFile, true);
   if(cache[].isLoaded())
     {
      fptr = new CalendarFilterCached(cache[]);
     }
   else
     {
      //TESTING
      if(MQLInfoInteger(MQL_TESTER))
        {
         Print("Can't run in the tester without calendar cache file");
         return INIT_FAILED;
        }
      else
         //LIVE or DEMO
         //
         if(StringLen(CalendarCacheFile))
           {
            Alert("Calendar cache not found, trying to create '" + CalendarCacheFile + "'");
            cache = new CalendarCache();
            if(cache[].save(CalendarCacheFile))
              {
               Alert("File saved. Re-run indicator in online chart or in the tester");
              }
            else
              {
               Alert("Error: ", _LastError);
              }
            ChartIndicatorDelete(0, 0, MQLInfoString(MQL_PROGRAM_NAME));
            return INIT_PARAMETERS_INCORRECT;
           }
      Alert("Currently working in online mode (no cache)");
      fptr = new CalendarFilter(Context);
     }
   CalendarFilter *calendar_fltr_ptr = fptr[];

   if(!calendar_fltr_ptr.isLoaded())
      return INIT_FAILED;

   if(UseChartCurrencies)
     {
      calendar_fltr_ptr.let(Base);
      if(Base != Profit)
        {
         calendar_fltr_ptr.let(Profit);
        }
     }



   if(Type != TYPE_ANY)
     {
      calendar_fltr_ptr.let((ENUM_CALENDAR_EVENT_TYPE)Type);
     }

   if(Sector != SECTOR_ANY)
     {
      calendar_fltr_ptr.let((ENUM_CALENDAR_EVENT_SECTOR)Sector);
     }

   if(Importance != IMPORTANCE_ANY)
     {
      calendar_fltr_ptr.let((ENUM_CALENDAR_EVENT_IMPORTANCE)(Importance - 1), GREATER);
     }

   if(StringLen(Text))
     {
      calendar_fltr_ptr.let(Text);
     }

   if(HasActual != HAS_ANY)
     {
      calendar_fltr_ptr.let(LONG_MIN, CALENDAR_PROPERTY_RECORD_ACTUAL, HasActual == HAS_SET ? NOT_EQUAL : EQUAL);
     }

   if(HasPrevious != HAS_ANY)
     {
      calendar_fltr_ptr.let(LONG_MIN, CALENDAR_PROPERTY_RECORD_PREVIOUS, HasPrevious == HAS_SET ? NOT_EQUAL : EQUAL);
     }

   if(HasRevised != HAS_ANY)
     {
      calendar_fltr_ptr.let(LONG_MIN, CALENDAR_PROPERTY_RECORD_REVISED, HasRevised == HAS_SET ? NOT_EQUAL : EQUAL);
     }

   if(HasForecast != HAS_ANY)
     {
      calendar_fltr_ptr.let(LONG_MIN, CALENDAR_PROPERTY_RECORD_FORECAST, HasForecast == HAS_SET ? NOT_EQUAL : EQUAL);
     }
   if(Distance2SLTP)
     {
      ArrayResize(trailing, Hedging && MultiplePositions ? MultiplePositions : 1);
     }
   EventSetTimer(CALENDAR_REFRESH_COUNT);//SECONDS

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Timer event handler (main processing of calendar goes here)      |
//+------------------------------------------------------------------+
void OnTimer()
  {
  Print("____________________");
   Print(__FUNCTION__);
   

   CalendarFilter *calendar_fltr_ptr = fptr[];
   MqlCalendarValue records[];
   
   calendar_fltr_ptr.let(TimeTradeServer() - Scope, TimeTradeServer() + Scope);

   static const ENUM_CALENDAR_PROPERTY props[] =
     {
      CALENDAR_PROPERTY_RECORD_TIME,CALENDAR_PROPERTY_COUNTRY_CURRENCY,CALENDAR_PROPERTY_EVENT_NAME,
      CALENDAR_PROPERTY_EVENT_IMPORTANCE,CALENDAR_PROPERTY_RECORD_ACTUAL,CALENDAR_PROPERTY_RECORD_FORECAST,
      CALENDAR_PROPERTY_RECORD_PREVISED,CALENDAR_PROPERTY_RECORD_IMPACT,CALENDAR_PROPERTY_EVENT_SECTOR,
     };
   static const int p = ArraySize(props);


   const ulong trackID = calendar_fltr_ptr.getChangeID();
   if(trackID) // already has a state, try to detect changes
     {
      Print("already has a state, try to detect changes");
      if(calendar_fltr_ptr.update(records)) // find changes that match filters
        {
         Print("find changes that match filters");
         // notify user about new changes
         
         string result[];
         calendar_fltr_ptr.format(records, props, result);
         
         for(int i = 0; i < ArraySize(result) / p; ++i)
           {
            //Alert(SubArrayCombine(result, " | ", i * p, p));
            Print(SubArrayCombine(result, " | ", i * p, p));
           }
         // fall through to the table redraw

         //CALC NEWS IMPACT
         //string base,profit;
         //if(UseChartCurrencies)
         //  {
         //   base = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
         //   profit = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);
         //  }


         // calculate news impact
         static const int impacts[3] = {0, +1, -1};
         int impact = 0;
         string about = "";
         ulong lasteventid = 0;
         for(int i = 0; i < ArraySize(records); ++i)
           {
            const int sign = result[i * p + 1] == Profit ? -1 : +1;
            impact += sign * impacts[records[i].impact_type];
            about += StringFormat("%+lld ", sign * (long)records[i].event_id);
            lasteventid = records[i].event_id;
           }

         if(impact == 0)
            return; // no signal

         // close existing positions if needed
         PositionFilter positions;
         ulong tickets[];
         positions.let(POSITION_SYMBOL, _Symbol).select(tickets);
         const int n = ArraySize(tickets);

         if(n >= (int)(Hedging ? MultiplePositions : 1))
           {
            MqlTradeRequestSync position;
            position.close(_Symbol) && position.completed();
           }

         // open new position according to the signal direction
         MqlTradeRequestSync request;
         request.magic = lasteventid;
         request.comment = about;
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         ulong ticket = 0;
         //Print("impact: "+impact);
         //IMPACT:POSITIVE
         if(impact > 0)
           {
            ticket = request.buy(Lot, 0
                                 ,0//Distance2SLTP ? ask - point * Distance2SLTP : 0
                                 ,Distance2SLTP ? ask + point * Distance2SLTP : 0);
           }
         //IMPACT:NEGATIVE
         else
            if(impact < 0)
              {
               ticket = request.sell(Lot, 0
                                     ,0//Distance2SLTP ? bid + point * Distance2SLTP : 0
                                     ,Distance2SLTP ? bid - point * Distance2SLTP : 0);
              }

         if(ticket && request.completed() && Distance2SLTP)
           {
            for(int i = 0; i < ArraySize(trailing); ++i)
              {
               if(trailing[i][] == NULL) // find free slot, create trailing object
                 {
                  trailing[i] = new TrailingStop(ticket
                                                 , Distance2SLTP
                                                 , Distance2SLTP / 50);
                  break;
                 }
              }
           }


        }
      else
         if(trackID == calendar_fltr_ptr.getChangeID())
           {/*no changes in the calendar*/ return;  }
     }


   calendar_fltr_ptr.select(records, true, Limit);// request complete set of events according to filters
   string result[];// rebuild the table displayed on chart
   calendar_fltr_ptr.format(records, props, result, true, true);


// on-chart table copy in the log
   for(int i = 0; i < ArraySize(result) / p; ++i)
     {
      //Print(SubArrayCombine(result, " | ", i * p, p));
     }


   if(tableau[] == NULL || tableau[].getRows() != ArraySize(records) + 1)
     {
      tableau = new Tableau("CALT",
                            ArraySize(records) + 1,
                            p,
                            TBL_CELL_HEIGHT_AUTO,
                            TBL_CELL_WIDTH_AUTO,
                            Corner,
                            Margins,
                            FontSize,
                            FontName,
                            FontName + " Bold",
                            TBL_FLAG_ROW_0_HEADER,
                            BackgroundColor,
                            BackgroundTransparency);
     }
   const string hints[] = {};
   tableau[].fill(result, hints);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0,0,-1);

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   for(int i = 0; i < ArraySize(trailing); ++i)
     {
      if(trailing[i][])
        {
         if(!trailing[i][].trail()) // position was closed
           {
            trailing[i] = NULL; // free the slot, delete object
           }
        }
     }

  }
//+------------------------------------------------------------------+
