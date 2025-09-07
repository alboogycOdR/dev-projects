//+------------------------------------------------------------------+
//|                                                    CalendarEA.mq5 |
//|                                      Copyright 2024, Rene Balke   |
//|                                       http://www.companyname.net  |
//+------------------------------------------------------------------+

#property copyright "Copyright 2024, Rene Balke"
#property description "All The Best and Good Trades :)"
#property link "https://m-.w.en.bmtrading.de"
#define VERSION "1.0"
#property version VERSION

#include <files/filebin.mqh>
#include <arrays/arrayobj.mqh>
#include <ChartObjects/ChartObjectsLines.mqh>
#include <Arrays/ArrayString.mqh>
#include <Trade/Trade.mqh>
/*
1130    created

1146 - future events
*/

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CCalendarEntry : public CObject
  {
public:
   ulong             country_id; // country ID (ISO 3166-1)
   string            country_name; // country text name (in the current terminal encoding)
   string            country_code; // country code name (ISO 3166-1 alpha-2)
   string            country_currency; // country currency code
   string            country_currency_symbol; // country currency symbol
   string            country_url_name; // country name used in the mqlS.com website URL

   ulong             event_id; // event ID
   ENUM_CALENDAR_EVENT_TYPE event_type; // event type from the ENUH_CALENDAR_EVENT_TYPE enumeration
   ENUM_CALENDAR_EVENT_SECTOR event_sector; // sector an event is related to
   ENUM_CALENDAR_EVENT_FREQUENCY event_frequency; // event frequency
   ENUM_CALENDAR_EVENT_TIMEMODE event_time_mode; // event time mode
   ENUM_CALENDAR_EVENT_UNIT event_unit; // economic indicator value's unit of measure
   ENUM_CALENDAR_EVENT_IMPORTANCE event_importance; // event importance
   ENUM_CALENDAR_EVENT_MULTIPLIER event_multiplier; // economic indicator value multiplier

   uint              event_digits; // number of decimal places
   string            event_source_url; // URL of a source where an event is published
   string            event_event_code; // event code
   string            event_name; // event text name in the terminal language (in the current terminal encoding)
   ulong             value_id; // value ID
   datetime          value_time; // event date and time
   datetime          value_period; // event reporting period
   int               value_revision; // revision of the published indicator relative to the reporting period
   long              value_actual_value; // actual value multiplied by 10A6 or LONG_MIN if the value is not set
   long              value_prev_yalue; // previous value multiplied by lGAS or LONG_MIN if the value is not set
   long              value_revised_prev_value; // revised previous value multiplied by 16"6 or LONG_HIN if the value is not set
   long              value_forecast_value; // forecast value multiplied by lDAG or LONG_HIN if the value is not set

   ENUM_CALENDAR_EVENT_IMPACT value_impact_type; // potential impact on the currency rate

   int               Compare(const CObject *node,const int mode=0) const
     {
      CCalendarEntry* other = (CCalendarEntry*)node;
      if(value_time == other.value_time)
        {
         return event_importance - other.event_importance;
        }
      return (int)(value_time - other.value_time);
     }


   string            ToString()
     {
      string txt;
      string importance = "None";
      if(event_importance == CALENDAR_IMPORTANCE_HIGH)
         importance = "High";
      else
         if(event_importance == CALENDAR_IMPORTANCE_MODERATE)
            importance = "Moderate";
         else
            if(event_importance == CALENDAR_IMPORTANCE_LOW)
               importance = "Low";
      StringConcatenate(txt,value_time," > ",event_name," (",country_code,"|",country_currency,") ",importance);
      return txt;
     }

  };

// ... existing code ...

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CCalendarHistory : public CArrayObj
  {
public:
   CCalendarEntry *  operator[](const int index) const {return (CCalendarEntry*)At(index);}
   CCalendarEntry    *At(const int index) const;
   bool              LoadCalendarEntriesFromFile(string fileName);
   bool              SaveCalendarValuesToFile(string fileName);
  };

// ... existing code ...

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CCalendarEntry *CCalendarHistory::At(const int index) const
  {
   if(index<0 || index>=m_data_total)
      return(NULL);
   return (CCalendarEntry*)m_data[index];
  }

// ... existing code ...

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CCalendarHistory::LoadCalendarEntriesFromFile(string fileName)
  {
   CFileBin file;
   if(file.Open(fileName,FILE_READ|FILE_COMMON) > 0)
     {
      while(!file.IsEnding())
        {
         CCalendarEntry* entry = new CCalendarEntry();
         int len;
         file.ReadLong(entry.country_id); // country ID (ISO 3166—1)
         file.ReadInteger(len);
         file.ReadString(entry.country_name,len); // country text name (in the current terminal encoding)
         file.ReadInteger(len);
         file.ReadString(entry.country_code,len);
         file.ReadInteger(len);
         file.ReadString(entry.country_currency,len); // country currency code
         file.ReadInteger(len);
         file.ReadString(entry.country_currency_symbol,len); // country currency symbol
         file.ReadInteger(len);
         file.ReadString(entry.country_url_name,len); // country name used in the mqlS.com website URL
         file.ReadLong(entry.event_id); // event ID
         file.ReadEnum(entry.event_type); // event type from the ENUH_CALENDAR_EVENT_TYPE enumera
         file.ReadEnum(entry.event_sector); // sector an event is related to
         file.ReadEnum(entry.event_frequency); // event frequency
         file.ReadEnum(entry.event_time_mode); // event time mode
         file.ReadEnum(entry.event_unit); // economic indicator value's unit of measure
         file.ReadEnum(entry.event_importance); // event importance
         file.ReadEnum(entry.event_multiplier); // economic indicator value multiplier
         file.ReadInteger(entry.event_digits); // number of decimal places
         file.ReadInteger(len);
         file.ReadString(entry.event_source_url,len); // URL of a source where an event is published
         file.ReadInteger(len);
         file.ReadString(entry.event_event_code,len); // event code
         file.ReadInteger(len);
         file.ReadString(entry.event_name,len); // event text name in the terminal language (in the cur
         file.ReadLong(entry.value_id); // value ID
         file.ReadLong(entry.value_time); // event date and time
         //--------------------------------
         file.ReadLong(entry.value_period); // event reporting period
         file.ReadInteger(entry.value_revision); // revision of the published indicator relative to the reporting period
         file.ReadLong(entry.value_actual_value); // actual value multiplied by 10A6 or LONG_MIN if the value is not set
         file.ReadLong(entry.value_prev_yalue); // previous value multiplied by lGAS or LONG_MIN if the value is not set
         file.ReadLong(entry.value_revised_prev_value); // revised previous value multiplied by 16"6 or LONG_HIN if the value is not set
         file.ReadLong(entry.value_forecast_value); // forecast value multiplied by lDAG or LONG_HIN if the value is not set
         file.ReadEnum(entry.value_impact_type); // potential impact on the currency rate
         CArrayObj::Add(entry);
        }
      Print(__FUNCTION__, " > Loaded ", CArrayObj::Total(), " Calendar Entries From ", fileName, "...");
      CArray::Sort();
      file.Close();
      return true;
     }
   return false;
  }

// ... existing code ...

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CCalendarHistory::SaveCalendarValuesToFile(string fileName)
  {
   CFileBin file;
   if(file.Open(fileName, FILE_WRITE|FILE_COMMON) > 0)
     {
      MqlCalendarValue values[];
      // Get all calendar values up to current time
      CalendarValueHistory(values, 0, TimeCurrent());
      int savedCount = 0;
      Print("Retrieved ", values.Size(), " total calendar entries from MetaTrader calendar");
      for(uint i = 0; i < values.Size(); i++)
        {
         MqlCalendarEvent event;
         if(!CalendarEventById(values[i].event_id, event))
           {
            Print("Warning: Could not get event details for ID ", values[i].event_id);
            continue;
           }
         MqlCalendarCountry country;
         if(!CalendarCountryById(event.country_id, country))
           {
            Print("Warning: Could not get country details for ID ", event.country_id);
            continue;
           }
         // Debug output for first few entries
         if(i < 10)
           {
            Print("Entry ", i, ": ", event.name, " (", country.currency, "), importance: ", event.importance);
           }
         // Write all data to file
         file.WriteLong(country.id);
         file.WriteInteger(country.name.Length());
         file.WriteString(country.name, country.name.Length());
         file.WriteInteger(country.code.Length());
         file.WriteString(country.code, country.code.Length());
         file.WriteInteger(country.currency.Length());
         file.WriteString(country.currency, country.currency.Length());
         file.WriteInteger(country.currency_symbol.Length());
         file.WriteString(country.currency_symbol, country.currency_symbol.Length());
         file.WriteInteger(country.url_name.Length());
         file.WriteString(country.url_name, country.url_name.Length());
         file.WriteLong(event.id);
         file.WriteEnum(event.type);
         file.WriteEnum(event.sector);
         file.WriteEnum(event.frequency);
         file.WriteEnum(event.time_mode);
         file.WriteEnum(event.unit);
         file.WriteEnum(event.importance);
         file.WriteEnum(event.multiplier);
         file.WriteInteger(event.digits);
         file.WriteInteger(event.source_url.Length());
         file.WriteString(event.source_url, event.source_url.Length());
         file.WriteInteger(event.event_code.Length());
         file.WriteString(event.event_code, event.event_code.Length());
         file.WriteInteger(event.name.Length());
         file.WriteString(event.name, event.name.Length());
         file.WriteLong(values[i].id);
         file.WriteLong(values[i].time);
         file.WriteLong(values[i].period);
         file.WriteInteger(values[i].revision);
         file.WriteLong(values[i].actual_value);
         file.WriteLong(values[i].prev_value);
         file.WriteLong(values[i].revised_prev_value);
         file.WriteLong(values[i].forecast_value);
         file.WriteEnum(values[i].impact_type);
         savedCount++;
        }
      Print(__FUNCTION__, " > Saved ", savedCount, " Calendar Entries To ", fileName, "...");
      file.Close();
      return true;
     }
   return false;
  }

#define FILE_NAME "CalendarHistory.bin"
#define OBJ_PREFIX "[Cal]"

enum ENUM_MODE
  {
   MODE_CREATE_FILE,
   MODE_TRADING
  };

enum ENUM_TRADE_ACTION
  {
   ACTION_NONE,           // No trading action
   ACTION_CLOSE_ALL,      // Close all positions before news
   ACTION_NO_NEW_TRADES,  // Don't open new trades before news
   ACTION_CUSTOM          // Custom trading strategy
  };

// Input parameters
input ENUM_MODE Mode = MODE_TRADING;
input string Currencies = "USD"; // Currencies separated by ; e.g. USD;EUR;GBP
input ENUM_CALENDAR_EVENT_IMPORTANCE Importance = CALENDAR_IMPORTANCE_HIGH; // >= Event Importance
input bool IsChartComment = true; // Show Chart Comment
input int MinutesBeforeNews = 240; // Minutes to take action before news (60)
input int MinutesAfterNews = 30; // Minutes to resume normal trading after news
input ENUM_TRADE_ACTION TradeAction = ACTION_CLOSE_ALL; // Action to take before news
input double LotSize = 0.01; // Lot size for trading
input int StopLoss = 50; // Stop Loss in points
input int TakeProfit = 100; // Take Profit in points

// Global variables
CCalendarHistory calendar;
CArrayObj lines;
CTrade trade;
datetime lastNewsCheck = 0;
bool isNewsTime = false;
datetime nextNewsTime = 0;
string nextNewsName = "";

//+------------------------------------------------------------------+
//| Expert initialization function with improved filtering           |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(Mode == MODE_CREATE_FILE)
     {
      if(!calendar.SaveCalendarValuesToFile(FILE_NAME))
        {
         Print("Failed to create calendar file!");
         return INIT_FAILED;
        }
      Print("Calendar file created successfully. Please switch to MODE_TRADING to use the EA.");
      return INIT_SUCCEEDED;
     }
   calendar.Clear();
   if(!calendar.LoadCalendarEntriesFromFile(FILE_NAME))
     {
      Print("Failed to load calendar file. Please run with Mode=MODE_CREATE_FILE first!");
      return INIT_FAILED;
     }
   Print("Loaded ", calendar.Total(), " calendar entries from file.");
// Parse currencies input
   string currencyArray[];
   StringSplit(Currencies, StringGetCharacter(";", 0), currencyArray);
   Print("Filtering for currencies: ", Currencies);
   Print("Parsed ", ArraySize(currencyArray), " currencies from input");
// Debug: Print all entries to check what's loaded
   datetime currentTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   datetime todayStart = StructToTime(dt);
   datetime todayEnd = todayStart + 86400;
   Print("Today's date range: ", TimeToString(todayStart), " to ", TimeToString(todayEnd));
   Print("Current time: ", TimeToString(currentTime));
// Filter calendar entries by currency and importance
   int removedCount = 0;
   for(int i = calendar.Total() - 1; i >= 0; i--)
     {
      CCalendarEntry* entry = calendar.At(i);
      bool keepEntry = false;
      // Check if entry's currency matches any of our target currencies
      for(int j = 0; j < ArraySize(currencyArray); j++)
        {
         if(entry.country_currency == currencyArray[j])
           {
            keepEntry = true;
            break;
           }
        }
      // Also check importance
      if(!keepEntry || entry.event_importance < Importance)
        {
         if(entry.value_time >= todayStart && entry.value_time < todayEnd)
           {
            Print("Removing event: ", entry.event_name, " (", entry.country_currency,
                  "), importance: ", entry.event_importance,
                  ", time: ", TimeToString(entry.value_time));
           }
         calendar.Delete(i);
         removedCount++;
        }
      else
         if(entry.value_time >= todayStart && entry.value_time < todayEnd)
           {
            Print("Keeping event: ", entry.event_name, " (", entry.country_currency,
                  "), importance: ", entry.event_importance,
                  ", time: ", TimeToString(entry.value_time));
           }
     }
   Print("Removed ", removedCount, " entries that didn't match filters. ",
         calendar.Total(), " entries remain.");
// Count today's events after filtering
   int todayEventsCount = 0;
   for(int i = 0; i < calendar.Total(); i++)
     {
      CCalendarEntry* entry = calendar.At(i);
      if(entry.value_time >= todayStart && entry.value_time < todayEnd)
        {
         Print("Today's filtered event: ", entry.ToString());
         todayEventsCount++;
        }
     }
   Print("Found ", todayEventsCount, " filtered events for today");
// Create lines for all remaining events (they're already filtered)
   lines.Clear();
   for(int i = 0; i < calendar.Total(); i++)
     {
      CCalendarEntry* entry = calendar.At(i);
      // Create a vertical line for this event
      CChartObjectVLine* line = new CChartObjectVLine();
      string objname = OBJ_PREFIX + " " + entry.event_name + " " + TimeToString(entry.value_time);
      line.Create(0, objname, 0, entry.value_time);
      line.Style(STYLE_DOT);
      if(entry.event_importance == CALENDAR_IMPORTANCE_HIGH)
         line.Color(clrRed);
      else
         if(entry.event_importance == CALENDAR_IMPORTANCE_MODERATE)
            line.Color(clrOrange);
         else
            if(entry.event_importance == CALENDAR_IMPORTANCE_LOW)
               line.Color(clrGray);
            else
               if(entry.event_importance == CALENDAR_IMPORTANCE_NONE)
                  line.Color(clrLightGray);
      lines.Add(line);
     }
   Print("Created lines for ", lines.Total(), " events");
// Initialize trade object
   trade.SetExpertMagicNumber(123456);
// Force an immediate update of the chart comment
   UpdateChartComment(true);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
// Clean up objects - properly delete CChartObjectVLine objects
   for(int i = 0; i < lines.Total(); i++)
     {
      CChartObjectVLine* line = (CChartObjectVLine*)lines.At(i);
      if(line != NULL)
        {
         line.Delete();
         delete line; // Properly delete the object to prevent memory leaks
        }
     }
   lines.Clear();
   calendar.Clear();
   Comment("");
  }

//+------------------------------------------------------------------+
//| Check for upcoming news events                                   |
//+------------------------------------------------------------------+
bool CheckForNews()
  {
   datetime currentTime = TimeCurrent();
// Only check for news every minute to save resources
   if(currentTime - lastNewsCheck < 60)
      return isNewsTime;
   lastNewsCheck = currentTime;
   isNewsTime = false;
   nextNewsTime = 0;
   nextNewsName = "";
   for(int i = 0; i < calendar.Total(); i++)
     {
      CCalendarEntry* entry = calendar.At(i);
      // Check if we're in the time window before news
      if(entry.value_time > currentTime &&
         entry.value_time - currentTime <= MinutesBeforeNews * 60)
        {
         isNewsTime = true;
         if(nextNewsTime == 0 || entry.value_time < nextNewsTime)
           {
            nextNewsTime = entry.value_time;
            nextNewsName = entry.event_name;
           }
        }
      // Check if we're in the time window after news
      if(entry.value_time <= currentTime &&
         currentTime - entry.value_time <= MinutesAfterNews * 60)
        {
         isNewsTime = true;
        }
     }
   return isNewsTime;
  }

//+------------------------------------------------------------------+
//| Handle trading actions based on news                             |
//+------------------------------------------------------------------+
void HandleNewsTrading()
  {
   if(!isNewsTime)
      return;
   switch(TradeAction)
     {
      case ACTION_CLOSE_ALL:
         CloseAllPositions();
         break;
      case ACTION_NO_NEW_TRADES:
         // Just don't open new trades
         break;
      case ACTION_CUSTOM:
         ExecuteCustomStrategy();
         break;
     }
  }

//+------------------------------------------------------------------+
//| Close all open positions that belong to this EA                  |
//+------------------------------------------------------------------+
void CloseAllPositions()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
        {
         if(PositionSelectByTicket(ticket))
           {
            // Only close positions that belong to this EA by checking magic number
            if(PositionGetInteger(POSITION_MAGIC) == trade.RequestMagic())
              {
               if(!trade.PositionClose(ticket))
                 {
                  Print("Failed to close position #", ticket, ". Error: ", GetLastError());
                 }
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Execute custom trading strategy                                  |
//+------------------------------------------------------------------+
void ExecuteCustomStrategy()
  {
// Implement your custom trading strategy here
// This is just a placeholder for your own logic
// Example: Open a buy position if not in news time window
   if(!isNewsTime)
     {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = ask - StopLoss * _Point;
      double tp = ask + TakeProfit * _Point;
      trade.Buy(LotSize, _Symbol, ask, sl, tp, "Calendar EA Buy");
     }
  }

//+------------------------------------------------------------------+
//| Update chart comment with calendar information                   |
//+------------------------------------------------------------------+
void UpdateChartComment(bool forceUpdate = false)
  {
   if(!IsChartComment)
      return;
      
      
   //MqlDateTime dt;
   //TimeCurrent(dt);
   //dt.hour=0;
   //dt.min=0;
   //dt.sec=0;
   //datetime timeStartDay = StructToTime(dt);
   //static datetime timestamp;
   //if(timestamp != timeStartDay)
   //  {
   //   timestamp = timeStartDay;
   //   CCalendarEntry* temp = new CCalendarEntry();
   //   temp.value_time = timeStartDay;
   //   int index = calendar.SearchGreatOrEqual(temp);
   //   delete temp;
   //   if(index > 0)
   //     {
   //      CCalendarHistory calendarDay;
   //      for(int i=index;i<calendar.Total();i++)
   //        {
   //         CCalendarEntry* entry = calendar.At(i);
   //         if(entry.value_time > timeStartDay + 86400)
   //            break;
   //         calendarDay.Add(entry);
   //        }
   //      string txt;
   //      for(int i = 0; i < calendarDay.Total(); i++)
   //        {
   //         CCalendarEntry* entry = calendarDay.At(i);
   //         StringConcatenate(txt,txt,"\n",entry.ToString());
   //         Comment(txt);
   //        }
   //     }
   //  }
   
   
//================================
   datetime currentTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   datetime timeStartDay = StructToTime(dt);
   datetime timeEndDay = timeStartDay + 86400; // End of the current day
   static datetime timestamp;

   static datetime lastCommentUpdate = 0;
   static bool newsAlertShown = false;

   // Full comment update when the day changes, on first run, or when forced
   if(lastCommentUpdate != timeStartDay || forceUpdate)
     {
      lastCommentUpdate = timeStartDay;
      newsAlertShown = isNewsTime;

      string txt = "";

      if(isNewsTime)
        {
         txt = "NEWS ALERT: Trading restrictions in effect!\n";
         if(nextNewsTime > 0)
            txt += "Next news: " + nextNewsName + " at " + TimeToString(nextNewsTime, TIME_DATE|TIME_MINUTES) + "\n\n";
        }

      txt += "Calendar Events for " + TimeToString(timeStartDay, TIME_DATE) + ":\n";

      // Find all events for today (between timeStartDay and timeEndDay)
      int todayEventsCount = 0;
      string eventsList = "";

      // All events in the calendar are already filtered, so just display those for today
      for(int i = 0; i < calendar.Total(); i++)
        {
         CCalendarEntry* entry = calendar.At(i);

         if(entry.value_time >= timeStartDay && entry.value_time < timeEndDay)
           {
            todayEventsCount++;

            // Mark past events differently
            if(entry.value_time < currentTime)
               eventsList += "\n[PAST] " + entry.ToString();
            else
               eventsList += "\n[UPCOMING] " + entry.ToString();
           }
        }

      if(todayEventsCount > 0)
        {
         txt += eventsList;
        }
      else
        {
         txt += "\nNo calendar events for today matching your filters.";
         txt += "\nCurrencies: " + Currencies;
         txt += "\nMinimum Importance: " + EnumToString(Importance);
        }

      Comment(txt);

      // Debug output
      if(forceUpdate)
        {
         Print("UpdateChartComment found ", todayEventsCount, " events for today");
        }
     }
     else if(isNewsTime != newsAlertShown)
     {
      // News alert status changed, update the comment
      newsAlertShown = isNewsTime;

      string txt = "";

      if(isNewsTime)
        {
         txt = "NEWS ALERT: Trading restrictions in effect!\n";
         if(nextNewsTime > 0)
            txt += "Next news: " + nextNewsName + " at " + TimeToString(nextNewsTime, TIME_DATE|TIME_MINUTES) + "\n\n";
        }

      txt += "Calendar Events for " + TimeToString(timeStartDay, TIME_DATE) + ":\n";

      // Find all events for today
      int todayEventsCount = 0;
      string eventsList = "";

      for(int i = 0; i < calendar.Total(); i++)
        {
         CCalendarEntry* entry = calendar.At(i);
         if(entry.value_time >= timeStartDay && entry.value_time < timeEndDay)
           {
            todayEventsCount++;

            // Mark past events differently
            if(entry.value_time < currentTime)
               eventsList += "\n[PAST] " + entry.ToString();
            else
               eventsList += "\n[UPCOMING] " + entry.ToString();
           }
        }

      if(todayEventsCount > 0)
        {
         txt += eventsList;
        }
      else
        {
         txt += "\nNo calendar events for today matching your filters.";
         txt += "\nCurrencies: " + Currencies;
         txt += "\nMinimum Importance: " + EnumToString(Importance);
        }

      Comment(txt);
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   static datetime lastNewsCheckTime = 0;
   datetime currentTime = TimeCurrent();
// Only check for news once per minute to optimize performance
   if(currentTime - lastNewsCheckTime >= 60) // Check every 60 seconds
     {
      lastNewsCheckTime = currentTime;
      CheckForNews();
      UpdateChartComment();
     }
// Handle trading based on news (this should run on every tick)
   HandleNewsTrading();
  }
//+------------------------------------------------------------------+ 
//+------------------------------------------------------------------+
