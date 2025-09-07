//+------------------------------------------------------------------+
//|                                                 20_drop_view.mq5 |
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
//--- drop a view
   string table_name="COUNTRIES";
   if(db_obj.SelectTable(table_name))
      for(int idx=0; idx<2; idx++)
        {
         string view_name=::StringFormat("European%d", idx+1);
         bool if_exists=idx;
         if(db_obj.DropView(view_name, if_exists))
            ::PrintFormat("A view \"%s\" has been successfully dropped!", view_name);
         db_obj.FinalizeSqlRequest();
        }
   db_obj.Close();
  }
//+------------------------------------------------------------------+
