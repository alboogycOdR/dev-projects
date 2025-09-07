//+------------------------------------------------------------------+
//|                                     sCreateAndFillCalendarDB.mq5 |
//|                                           Copyright 2023, denkir |
//|                             https://www.mql5.com/ru/users/denkir |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, denkir"
#property link      "https://www.mql5.com/ru/users/denkir"
#property version   "1.00"
//--- include
#include <Arrays\ArrayInt.mqh>
#include <Arrays\ArrayLong.mqh>
#include "..\CalendarInfo.mqh"
#include "..\CDatabase.mqh"
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
   {
//--- open a database
   CDatabase db_obj;
   string file_name="Databases\\Calendar_DB.sqlite";
   uint flags=DATABASE_OPEN_READWRITE | DATABASE_OPEN_CREATE;
   if(!db_obj.Open(file_name, flags))
      {
      ::PrintFormat("Failed to open a calendar database \"%s\"!", file_name);
      db_obj.Close();
      return;
      }
//--- Create tables
//--- Table 1
   string table_name="COUNTRIES";
   string params1[]=
      {
      //--- columns
      "COUNTRY_ID UNSIGNED BIG INT PRIMARY KEY NOT NULL,",  // 1) country ID
      "NAME TEXT,",                                         // 2) country name
      "CODE TEXT,",                                         // 3) country code
      "CONTINENT TEXT,",                                    // 4) country continent
      "CURRENCY TEXT,",                                     // 5) currency code
      "CURRENCY_SYMBOL TEXT,",                              // 6) currency symbol
      "URL_NAME TEXT"                                       // 7) country URL
      };
   if(!db_obj.CreateTable(table_name, params1))
      {
      ::PrintFormat("Failed to create a table \"%s\"!", table_name);
      db_obj.Close();
      return;
      }
   db_obj.FinalizeSqlRequest();
//--- Table 2
   table_name="EVENTS";
   string params2[]=
      {
      //--- columns
      "EVENT_ID UNSIGNED BIG INT PRIMARY KEY NOT NULL,",  // 1) event ID
      "TYPE TEXT,",                                       // 2) event type
      "SECTOR TEXT,",                                     // 3) event sector
      "FREQUENCY TEXT,",                                  // 4) event frequency
      "TIME_MODE TEXT,",                                   // 5) event time mode
      "COUNTRY_ID UNSIGNED BIG INT NOT NULL,",            // 6) country ID*
      "UNIT TEXT,",                                       // 7) event unit
      "IMPORTANCE TEXT,",                                 // 8) event importance
      "MULTIPLIER TEXT,",                                 // 9) event multiplier
      "DIGITS UNSIGNED INT,",                             // 10) event digits
      "SOURCE TEXT,",                                     // 11) event source
      "CODE TEXT,",                                       // 12) event code
      "NAME TEXT,",                                       // 13) event name
      //--- foreign key
      "FOREIGN KEY (COUNTRY_ID) ",
      "REFERENCES COUNTRIES(COUNTRY_ID) ",
      "ON UPDATE CASCADE ",
      "ON DELETE CASCADE"
      };
   if(!db_obj.CreateTable(table_name, params2))
      {
      ::PrintFormat("Failed to create a table \"%s\"!", table_name);
      db_obj.Close();
      return;
      }
   db_obj.FinalizeSqlRequest();
//--- Table 3
   table_name="EVENT_VALUES";
   string col_names3[]=
      {
      //--- columns
      "VALUE_ID UNSIGNED BIG INT PRIMARY KEY NOT NULL,", // 1) value ID
      "EVENT_ID UNSIGNED BIG INT NOT NULL,",             // 2) event ID
      /*
      "TIME INT,",                                       // 3) value time
      "PERIOD INT,",                                     // 4) value period
      */
      "TIME TEXT,",                                       // 3) value time
      "PERIOD TEXT,",                                     // 4) value period
      "REVISION INT,",                                   // 5) value revision
      "ACTUAL REAL,",                                    // 6) actual value
      "PREVIOUS REAL,",                                  // 7) previous value
      "REVISED REAL,",                                   // 8) revised previous value
      "FORECAST REAL,",                                  // 9) forecast value
      "IMPACT TEXT,",                                    // 10) impact
      //--- foreign key
      "FOREIGN KEY (EVENT_ID) ",
      "REFERENCES EVENTS(EVENT_ID) ",
      "ON UPDATE CASCADE ",
      "ON DELETE CASCADE"
      };
   if(!db_obj.CreateTable(table_name, col_names3))
      {
      ::PrintFormat("Failed to create a table \"%s\"!", table_name);
      db_obj.Close();
      return;
      }
   db_obj.FinalizeSqlRequest();
//--- Fill in tables
//--- Table 1
   MqlCalendarCountry calendar_countries[];
   table_name="COUNTRIES";
   if(db_obj.SelectTable(table_name))
      if(db_obj.EmptyTable())
         {
         db_obj.FinalizeSqlRequest();
         string col_names[]=
            {
            "COUNTRY_ID",     // 1
            "NAME",           // 2
            "CODE",           // 3
            "CONTINENT",      // 4
            "CURRENCY",       // 5
            "CURRENCY_SYMBOL",// 6
            "URL_NAME"        // 7
            };
         CiCalendarInfo calendar_info;
         if(calendar_info.Init())
            {
            if(calendar_info.GetCountries(calendar_countries))
               {
               if(db_obj.TransactionBegin())
                  for(int c_idx=0; c_idx<::ArraySize(calendar_countries); c_idx++)
                     {
                     MqlCalendarCountry curr_country=calendar_countries[c_idx];
                     string col_vals[];
                     ::ArrayResize(col_vals, 7);
                     col_vals[0]=::StringFormat("%I64u", curr_country.id);
                     col_vals[1]=::StringFormat("'%s'", curr_country.name);
                     col_vals[2]=::StringFormat("'%s'", curr_country.code);
                     col_vals[3]="NULL";
                     SCountryByContinent curr_country_continent_data;
                     if(curr_country_continent_data.Init(curr_country.code))
                        col_vals[3]=::StringFormat("'%s'",
                                                   curr_country_continent_data.ContinentDescription());
                     col_vals[4]=::StringFormat("'%s'", curr_country.currency);
                     col_vals[5]=::StringFormat("'%s'", curr_country.currency_symbol);
                     col_vals[6]=::StringFormat("'%s'", curr_country.url_name);
                     if(!db_obj.InsertSingleRow(col_names, col_vals))
                        {
                        db_obj.TransactionRollback();
                        db_obj.Close();
                        return;
                        }
                     db_obj.FinalizeSqlRequest();
                     }
               if(!db_obj.TransactionCommit())
                  ::PrintFormat("Failed to complete transaction execution, error %d", ::GetLastError());
               }
            //--- print
            if(db_obj.PrintTable()<0)
               ::PrintFormat("Failed to print the table \"%s\", error %d", table_name, ::GetLastError());
            }
         }
//--- Table 2
   CArrayLong ids_arr;
   ids_arr.Step(64);
   CArrayInt digs_arr;
   digs_arr.Step(64);
   table_name="EVENTS";
   if(db_obj.SelectTable(table_name))
      if(db_obj.EmptyTable())
         {
         db_obj.FinalizeSqlRequest();
         string col_names[]=
            {
            "EVENT_ID",   // 1
            "TYPE",       // 2
            "SECTOR",     // 3
            "FREQUENCY",  // 4
            "TIME_MODE",  // 5
            "COUNTRY_ID", // 6
            "UNIT",       // 7
            "IMPORTANCE", // 8
            "MULTIPLIER", // 9
            "DIGITS",     // 10
            "SOURCE",     // 11
            "CODE",       // 12
            "NAME"        // 13
            };
         for(int c_idx=0; c_idx<::ArraySize(calendar_countries); c_idx++)
            {
            MqlCalendarCountry curr_country=calendar_countries[c_idx];
            CiCalendarInfo country_info;
            if(country_info.Init(NULL, curr_country.id))
               {
               MqlCalendarEvent country_events[];
               if(country_info.EventsByCountryDescription(country_events))
                  {
                  bool failed=false;
                  if(db_obj.TransactionBegin())
                     for(int ev_idx=0; ev_idx<::ArraySize(country_events); ev_idx++)
                        {
                        MqlCalendarEvent curr_event=country_events[ev_idx];
                        string col_vals[];
                        ::ArrayResize(col_vals, 13);
                        col_vals[0]=::StringFormat("%I64u", curr_event.id);
                        col_vals[1]=::StringFormat("'%s'", country_info.EventTypeDescription(curr_event.type));
                        col_vals[2]=::StringFormat("'%s'", country_info.EventSectorDescription(curr_event.sector));
                        col_vals[3]=::StringFormat("'%s'", country_info.EventFrequencyDescription(curr_event.frequency));
                        col_vals[4]=::StringFormat("'%s'", country_info.EventTimeModeDescription(curr_event.time_mode));
                        col_vals[5]=::StringFormat("%I64u", curr_event.country_id);
                        col_vals[6]=::StringFormat("'%s'", country_info.EventUnitDescription(curr_event.unit));
                        col_vals[7]=::StringFormat("'%s'", country_info.EventImportanceDescription(curr_event.importance));
                        col_vals[8]=::StringFormat("'%s'", country_info.EventMultiplierDescription(curr_event.multiplier));
                        col_vals[9]=::StringFormat("%I32u", curr_event.digits);
                        col_vals[10]=::StringFormat("'%s'", curr_event.source_url);
                        col_vals[11]=::StringFormat("'%s'", curr_event.event_code);
                        string temp_name, strings_to_find[2], strings_replacement[2];
                        temp_name=curr_event.name;
                        strings_to_find[0]="'";
                        strings_to_find[1]=",";
                        strings_replacement[0]="''";
                        strings_replacement[1]=" ";
                        for(uint tdx=0; tdx<strings_to_find.Size(); tdx++)
                           {
                           string curr_find=strings_to_find[tdx];
                           string curr_rep=strings_replacement[tdx];
                           int rep=::StringReplace(temp_name, curr_find, curr_rep);
                           }
                        col_vals[12]=::StringFormat("'%s'", temp_name);
                        if(!db_obj.InsertSingleRow(col_names, col_vals))
                           {
                           ::PrintFormat("DB: %s insert failed with code %d", file_name, ::GetLastError());
                           failed=true;
                           break;
                           }
                        db_obj.FinalizeSqlRequest();
                        }
                  if(failed)
                     {
                     db_obj.TransactionRollback();
                     ::PrintFormat("%s: DatabaseExecute() failed with code %d",
                                   __FUNCTION__, ::GetLastError());
                     db_obj.Close();
                     return;
                     }
                  db_obj.TransactionCommit();
                  }
               }
            }
         //--- read event ids and digits
         string ev_col_names[]=
            {
            "EVENT_ID", "DIGITS"
            };
         //--- collect event ids and digits
         if(db_obj.SelectFrom(ev_col_names))
            while(db_obj.SqlRequestRead())
               {
               long curr_event_id=db_obj.ColumnLong(0);
               if(curr_event_id!=WRONG_VALUE)
                  {
                  int curr_digs=db_obj.ColumnInteger(1);
                  if(curr_digs!=WRONG_VALUE)
                     {
                     ids_arr.Add(curr_event_id);
                     digs_arr.Add(curr_digs);
                     }
                  }
               }
         db_obj.FinalizeSqlRequest();
         }
//--- Table 3
   table_name="EVENT_VALUES";
   if(db_obj.SelectTable(table_name))
      if(db_obj.EmptyTable())
         {
         db_obj.FinalizeSqlRequest();
         string col_names[]=
            {
            "VALUE_ID", "EVENT_ID", "TIME", "PERIOD",
            "REVISION", "ACTUAL", "PREVIOUS", "REVISED",
            "FORECAST", "IMPACT"
            };
         datetime now=::TimeTradeServer();
         if(db_obj.TransactionBegin())
            for(int r_idx=0; r_idx<ids_arr.Total(); r_idx++)
               {
               long curr_event_id=ids_arr.At(r_idx);
               if(curr_event_id!=LONG_MAX)
                  {
                  int curr_digs=digs_arr.At(r_idx);
                  if(curr_digs!=INT_MAX)
                     {
                     CiCalendarInfo event_info;
                     if(event_info.Init(NULL, WRONG_VALUE, curr_event_id))
                        {
                        MqlCalendarValue values[];
                        if(event_info.ValueHistorySelectByEvent(values, 0, now))
                           {
                           CArrayString rows_str_arr;
                           bool failed=false;
                           for(int v_idx=0; v_idx<::ArraySize(values); v_idx++)
                              {
                              MqlCalendarValue curr_value=values[v_idx];
                              string col_vals[];
                              ::ArrayResize(col_vals, 10);
                              col_vals[0]=::StringFormat("%I64u", curr_value.id);
                              col_vals[1]=::StringFormat("%I64u", curr_value.event_id);
                              /*col_vals[2]=::StringFormat("%I32u", curr_value.time);
                              col_vals[3]=::StringFormat("%I32u", curr_value.period);*/
                              col_vals[2]=::StringFormat("'%s'", ::TimeToString(curr_value.time));       
                              col_vals[3]=::StringFormat("'%s'", ::TimeToString(curr_value.period));
                              col_vals[4]=::StringFormat("%I32u", curr_value.revision);
                              string format_str=::StringFormat("%%0.%df", curr_digs);
                              col_vals[5]="'NULL'";
                              if(curr_value.HasActualValue())
                                 col_vals[5]=::StringFormat(format_str, curr_value.GetActualValue());
                              col_vals[6]="'NULL'";
                              if(curr_value.HasPreviousValue())
                                 col_vals[6]=::StringFormat(format_str, curr_value.GetPreviousValue());
                              col_vals[7]="'NULL'";
                              if(curr_value.HasRevisedValue())
                                 col_vals[7]=::StringFormat(format_str, curr_value.GetRevisedValue());
                              col_vals[8]="'NULL'";
                              if(curr_value.HasForecastValue())
                                 col_vals[8]=::StringFormat(format_str, curr_value.GetForecastValue());
                              col_vals[9]=::StringFormat("'%s'", CiCalendarInfo::ValueImpactDescription(curr_value.impact_type));
                              string row_str_to_add;
                              for(uint s_idx=0; s_idx<col_vals.Size(); s_idx++)
                                 {
                                 string curr_col_val=col_vals[s_idx];
                                 row_str_to_add+=curr_col_val+",";
                                 }
                              row_str_to_add=::StringSubstr(row_str_to_add, 0, ::StringLen(row_str_to_add)-1); // delete the last comma
                              if(!rows_str_arr.Add(row_str_to_add))
                                 {
                                 failed=false;
                                 break;
                                 }
                              }
                           if(failed)
                              {
                              db_obj.TransactionRollback();
                              db_obj.Close();
                              return;
                              }
                           if(!db_obj.InsertMultipleRows(col_names, rows_str_arr))
                              {
                              db_obj.TransactionRollback();
                              db_obj.Close();
                              return;
                              }
                           db_obj.FinalizeSqlRequest();
                           }
                        }
                     }
                  }
               }
         db_obj.TransactionCommit();
         }
   db_obj.Close();
   }
//+------------------------------------------------------------------+
