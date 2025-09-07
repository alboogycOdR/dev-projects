//+------------------------------------------------------------------+
//|                                             16_rename_column.mq5 |
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
      string curr_name, new_name;
      curr_name="EVENTS_NUM";
      new_name="EVENTS_NUMBER";
      if(!db_obj.RenameColumn(curr_name, new_name))
        {
         ::PrintFormat("Failed to rename a column \"%s\"!", curr_name);
         db_obj.Close();
         return;
        }
      db_obj.FinalizeSqlRequest();
     }
   db_obj.Close();
  }
//+------------------------------------------------------------------+
