//+------------------------------------------------------------------+
//|                                               20_create_view.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
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
//--- create a view
   string table_name="COUNTRIES";
   if(db_obj.SelectTable(table_name))
      {
      string view_name="All_countries";
      string col_names[3];
      col_names[0]="NAME AS Country";
      col_names[1]="CONTINENT AS Continent";
      col_names[2]="CURRENCY AS Currency";
      bool is_temp=true;
      if(!db_obj.CreateView(view_name, col_names))
         {
         ::PrintFormat("Failed to create a view \"%s\"!", view_name);
         db_obj.Close();
         return;
         }
      db_obj.FinalizeSqlRequest();
      }
   db_obj.Close();
   }
//+------------------------------------------------------------------+
