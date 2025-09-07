//+------------------------------------------------------------------+
//|                                    19_intersect_some_columns.mq5 |
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
   //--- create temporary tables
   string table1_name, table2_name, sql_request;
   table1_name="Table1";
   table2_name="Table2";
   sql_request="SELECT COUNTRY_ID AS id, NAME AS name, CURRENCY "
               "as currency FROM COUNTRIES "
               "WHERE COUNTRY_ID<=578";
   if(!db_obj.CreateTableAs(table1_name, sql_request, true, true))
      {
      db_obj.Close();
      return;
      }
   db_obj.FinalizeSqlRequest();
   //--- print the temporary table
   string temp_col_names[]= {"*"};
   if(db_obj.SelectTable(table1_name, true))
      if(db_obj.SelectFrom(temp_col_names))
         {
         ::Print("   \nTable #1: ");
         db_obj.PrintSqlRequest();
         db_obj.FinalizeSqlRequest();
         }
   sql_request="SELECT COUNTRY_ID AS id, NAME AS name, CURRENCY "
               "as currency FROM COUNTRIES "
               "WHERE COUNTRY_ID>=392";
   if(!db_obj.CreateTableAs(table2_name, sql_request, true, true))
      {
      db_obj.Close();
      return;
      }
   db_obj.FinalizeSqlRequest();
   //--- print the temporary table
   if(db_obj.SelectTable(table2_name, true))
      if(db_obj.SelectFrom(temp_col_names))
         {
         ::Print("   \nTable #2: ");
         db_obj.PrintSqlRequest();
         db_obj.FinalizeSqlRequest();
         }
   if(db_obj.SelectTable(table1_name, true))
      {
      string col_names_to_select1[]=
         {
         "id", "name", "currency"
         };
      string col_names_to_select2[]=
         {
         "id", "name", "currency"
         };
      if(!db_obj.Intersect(col_names_to_select1, table2_name, col_names_to_select2))
         {
         db_obj.Close();
         return;
         }
      //--- print the SQL request
      long printed_rows=db_obj.PrintSqlRequest();
      if(printed_rows<=0)
         ::PrintFormat("Failed to print the SQL request, error %d", ::GetLastError());
      db_obj.FinalizeSqlRequest();
      }
   db_obj.Close();
   }
//+------------------------------------------------------------------+
