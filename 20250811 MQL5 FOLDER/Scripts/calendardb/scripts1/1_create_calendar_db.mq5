//+------------------------------------------------------------------+
//|                                         1_create_calendar_db.mq5 |
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
   CDatabase db_obj;
   string file_name="Databases\\test_calendar_db.sqlite";
   uint flags=DATABASE_OPEN_READWRITE | DATABASE_OPEN_CREATE;
   if(!db_obj.Open(file_name, flags))
      ::PrintFormat("Failed to create a calendar database \"%s\"!", file_name);
   db_obj.Close();
  }
//+------------------------------------------------------------------+
