//+------------------------------------------------------------------+
//|                                        17_union_some_columns.mq5 |
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
      db_obj.Close();
      return;
      }
//--- create tables
   string table1_name, table2_name, sql_request;
   table1_name="EUROPEAN_COUNTRIES";
   table2_name="NORTH_AMERICAN_COUNTRIES";
   sql_request="SELECT COUNTRY_ID AS id, NAME AS name, CURRENCY "
               "as currency FROM COUNTRIES "
               "WHERE CONTINENT='North America'";
   if(!db_obj.CreateTableAs(table2_name, sql_request, true))
      {
      db_obj.Close();
      return;
      }
   db_obj.FinalizeSqlRequest();
   sql_request="SELECT COUNTRY_ID AS id, NAME AS name, CURRENCY "
               "as currency FROM COUNTRIES "
               "WHERE CONTINENT='Europe'";
   if(!db_obj.CreateTableAs(table1_name, sql_request, true))
      {
      db_obj.Close();
      return;
      }
   db_obj.FinalizeSqlRequest();
   CArrayString tables_list;
   if(!db_obj.ListTables(tables_list, true))
      {
      db_obj.Close();
      return;
      }
   if(db_obj.SelectTable(table1_name, true))
      {
      string col_names_to_select1[]={"*"};
      string where_cond1="";
      string col_names_to_select2[]={"*"};
      string where_cond2="";
      if(!db_obj.Union(col_names_to_select1, where_cond1, table2_name,
                       col_names_to_select2, where_cond2))
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
