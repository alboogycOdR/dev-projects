//+------------------------------------------------------------------+
//|                                         11_replace_some_rows.mq5 |
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
      //--- the current row for "COUNTRY_NAME=Mexico"
      string col_names_to_select[]=
         {
         "COUNTRY_ID", "NAME", "CODE", "CONTINENT",
         "CURRENCY", "CURRENCY_SYMBOL", "URL_NAME"
         };
      string where_condition="COUNTRY_ID=484";
      if(!db_obj.SelectFromWhere(col_names_to_select, where_condition))
         {
         db_obj.Close();
         return;
         }
      //--- print the SQL request
      ::Print("\n 'Mexico' row before replacement");
      if(db_obj.PrintSqlRequest()<0)
         ::PrintFormat("Failed to print the SQL request, error %d", ::GetLastError());
      db_obj.FinalizeSqlRequest();
      //--- the replaced row for "COUNTRY_NAME=Mexico"
      string col_names[]=
         {
         "COUNTRY_ID", "NAME", "CODE",
         "CONTINENT", "CURRENCY", "CURRENCY_SYMBOL",
         "URL_NAME"
         };
      string col_vals[7];
      col_vals[0]=::StringFormat("%I64u", 484);
      col_vals[1]=::StringFormat("'%s'", "Mexico");
      col_vals[2]=::StringFormat("'%s'", "MX");
      col_vals[3]=::StringFormat("'%s'", "North America");
      col_vals[4]=::StringFormat("'%s'", "MXN");
      col_vals[5]=::StringFormat("'%s'", "Peso mexicano");
      col_vals[6]=::StringFormat("'%s'", "mexico");
      if(!db_obj.Replace(col_names, col_vals))
         {
         db_obj.Close();
         return;
         }
      //--- print the SQL request
      ::Print("\n 'Mexico' row after replacement");
      where_condition="COUNTRY_ID=484";
      if(!db_obj.SelectFromWhere(col_names_to_select, where_condition))
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
