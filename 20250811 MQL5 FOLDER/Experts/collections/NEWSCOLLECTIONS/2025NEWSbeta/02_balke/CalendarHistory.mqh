//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#include <files/filebin.mqh>
#include <arrays/arrayobj.mqh>
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


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CCalendarEntry *CCalendarHistory::At(const int index) const
  {
   if(index<0 || index>=m_data_total)
      return(NULL);
   return (CCalendarEntry*)m_data[index];
  }


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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CCalendarHistory::SaveCalendarValuesToFile(string fileName)
  {
   CFileBin file;
   if(file.Open(fileName,FILE_WRITE|FILE_COMMON) > 0)
     {
      MqlCalendarValue values[];
      CalendarValueHistory(values,0,TimeCurrent());
      for(uint i = 0; i < values.Size(); i++)
        {
         MqlCalendarEvent event;
         CalendarEventById(values[i].event_id,event);
         MqlCalendarCountry country;
         CalendarCountryById(event.country_id,country);
         file.WriteLong(country.id); // country ID (ISO 3166-1)
         file.WriteInteger(country.name.Length()); // country text name (in the current terminal encoding)
         file.WriteString(country.name,country.name.Length());
         file.WriteInteger(country.code.Length()); // country code name (ISO 3166-1 alpha—2)
         file.WriteString(country.code,country.code.Length());
         file.WriteInteger(country.currency.Length()); // country currency code
         file.WriteString(country.currency,country.currency.Length());
         file.WriteInteger(country.currency_symbol.Length()); // country currency symbol
         file.WriteString(country.currency_symbol,country.currency_symbol.Length());
         file.WriteInteger(country.url_name.Length()); // country name used in the mqlS.com website URL
         file.WriteString(country.url_name,country.url_name.Length());
         file.WriteLong(event.id); // event ID
         file.WriteEnum(event.type); // event type from the ENUH_CALENDAR_EVENT_TYPE enumeration
         file.WriteEnum(event.sector); // sector an event is related to
         file.WriteEnum(event.frequency); // event frequency
         file.WriteEnum(event.time_mode); // event time mode
         file.WriteEnum(event.unit); // economic indicator value's unit of measure
         file.WriteEnum(event.importance); // event importance
         file.WriteEnum(event.multiplier); // economic indicator value multiplier
         file.WriteInteger(event.digits); // number of decimal places
         file.WriteInteger(event.source_url.Length()); // URL of a source where an event is published
         file.WriteString(event.source_url,event.source_url.Length());
         file.WriteInteger(event.event_code.Length()); // event code
         file.WriteString(event.event_code,event.event_code.Length());
         file.WriteInteger(event.name.Length()); // event text name in the terminal language (in the current terminal encoding)
         file.WriteString(event.name,event.name.Length());
         file.WriteLong(values[i].id); // value ID
         file.WriteLong(values[i].time); // event date and time
         file.WriteLong(values[i].period); // event reporting period
         file.WriteInteger(values[i].revision); // revision of the published indicator relative to the reporting period
         file.WriteLong(values[i].actual_value); // actual value multiplied by 10A6 or LONG_MIN if the value is not set
         file.WriteLong(values[i].prev_value); // previous value multiplied by lGAS or LONG_MIN if the value is not set
         file.WriteLong(values[i].revised_prev_value); // revised previous value multiplied by 16"6 or LONG_HIN if the value is not set
         file.WriteLong(values[i].forecast_value); // forecast value multiplied by lDAG or LONG_HIN if the value is not set
         file.WriteEnum(values[i].impact_type); // potential impact on the currency rate
        }
      Print(__FUNCTION__, " > Saved ", values.Size(), " Calendar Entries To ", fileName,"...");
      file.Close();
      return true;
     }
   return false;
  }



















//+------------------------------------------------------------------+
