//+------------------------------------------------------------------+
//|                                     2_create_countries_table.mq5 |
//|                                           Copyright 2023, denkir |
//|                             https://www.mql5.com/ru/users/denkir |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, denkir"
#property link      "https://www.mql5.com/ru/users/denkir"
#property version   "1.00"
//--- include
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
      ::PrintFormat("Failed to open a calendar database \"%s\"!", file_name);
      db_obj.Close();
      return;
      }
//--- create a table
   string table_name="COUNTRIES";
   string col_names[]=
      {
      "COUNTRY_ID UNSIGNED BIG INT PRIMARY KEY NOT NULL,",  // 1) country ID
      "NAME TEXT,",                                         // 2) country name
      "CODE TEXT,",                                         // 3) country code
      "CONTINENT TEXT,",                                    // 4) country continent
      "CURRENCY TEXT,",                                     // 5) currency code
      "CURRENCY_SYMBOL TEXT,",                              // 6) currency symbol
      "URL_NAME TEXT",                                      // 7) country URL
      };
   if(!db_obj.CreateTable(table_name, col_names))
      ::PrintFormat("Failed to create a table \"%s\"!", table_name);
   db_obj.Close();
   }
//+------------------------------------------------------------------+
