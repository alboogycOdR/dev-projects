//+------------------------------------------------------------------+
//|                                            15_add_new_column.mq5 |
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
//--- rename a table
   string table_name="COUNTRIES";
   if(db_obj.SelectTable(table_name))
      {
      string new_col_name="EVENTS_NUM";
      string col_definition=new_col_name+" UNSIGNED INT";
      if(!db_obj.AddColumn(col_definition))
         {
         ::PrintFormat("Failed to add a column \"%s\"!", new_col_name);
         db_obj.Close();
         return;
         }
      db_obj.FinalizeSqlRequest();
      }
   db_obj.Close();
   }
//+------------------------------------------------------------------+
