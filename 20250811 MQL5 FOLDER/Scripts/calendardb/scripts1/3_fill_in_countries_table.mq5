//+------------------------------------------------------------------+
//|                                    3_fill_in_countries_table.mq5 |
//|                                           Copyright 2023, denkir |
//|                             https://www.mql5.com/ru/users/denkir |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, denkir"
#property link      "https://www.mql5.com/ru/users/denkir"
#property version   "1.00"
//--- include
#include "..\CalendarInfo.mqh"
#include "..\CDatabase.mqh"
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
   {
//--- open a database
   CDatabase db_obj;
   string file_name="Databases\\test_calendar_db.sqlite";
   uint flags=DATABASE_OPEN_READWRITE;
   if(!db_obj.Open(file_name, flags))
      {
      db_obj.Close();
      return;
      }
//--- open a table
   string table_name="COUNTRIES";
   if(db_obj.SelectTable(table_name))
      if(db_obj.EmptyTable())
         {
         db_obj.FinalizeSqlRequest();
         string col_names[]=
            {
            "COUNTRY_ID", "NAME", "CODE", "CONTINENT",
            "CURRENCY", "CURRENCY_SYMBOL", "URL_NAME"
            };
//--- fill in the table
         CiCalendarInfo calendar_info;
         if(calendar_info.Init())
            {
            MqlCalendarCountry calendar_countries[];
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
   db_obj.Close();
   }
//+------------------------------------------------------------------+
