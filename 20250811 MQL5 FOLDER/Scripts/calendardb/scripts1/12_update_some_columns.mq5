//+------------------------------------------------------------------+
//|                                       12_update_some_columns.mq5 |
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
//--- check a table
   string table_name="COUNTRIES";
   if(db_obj.SelectTable(table_name))
      {
      string col_names_to_update[]=
         {
         "CURRENCY", "CURRENCY_SYMBOL"
         };
      string col_vals_to_update[]=
         {
         "'None'", "'None'"
         };
      string where_condition="CONTINENT = 'Asia'";
      if(!db_obj.Update(col_names_to_update, col_vals_to_update, where_condition))
         {
         db_obj.Close();
         return;
         }
      //--- print the SQL request
      if(db_obj.PrintTable()<0)
         ::PrintFormat("Failed to print the SQL request, error %d", ::GetLastError());
      db_obj.FinalizeSqlRequest();
      }
   db_obj.Close();
   }
//+------------------------------------------------------------------+
