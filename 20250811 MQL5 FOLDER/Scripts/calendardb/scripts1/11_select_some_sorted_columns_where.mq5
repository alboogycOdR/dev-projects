//+------------------------------------------------------------------+
//|                          11_select_some_sorted_columns_where.mq5 |
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
   uint flags=DATABASE_OPEN_READONLY;
   if(!db_obj.Open(file_name, flags))
      {
      db_obj.Close();
      return;
      }
//--- check a table
   string table_name="COUNTRIES";
   if(db_obj.SelectTable(table_name))
      {
      string col_names_to_select[]=
         {
         "COUNTRY_ID", "NAME", "CODE",
         "CONTINENT", "CURRENCY"
         };
      string where_condition="COUNTRY_ID BETWEEN 392 AND 840";
      string ord_names[1];
      ord_names[0]=col_names_to_select[3];
      if(!db_obj.SelectFromWhereOrderedBy(col_names_to_select, where_condition, ord_names))
         {
         db_obj.Close();
         return;
         }
      //--- print the SQL request
      if(db_obj.PrintSqlRequest()<0)
         ::PrintFormat("Failed to print the SQL request, error %d", ::GetLastError());
      db_obj.FinalizeSqlRequest();
      }
   db_obj.Close();
   }
//+------------------------------------------------------------------+
