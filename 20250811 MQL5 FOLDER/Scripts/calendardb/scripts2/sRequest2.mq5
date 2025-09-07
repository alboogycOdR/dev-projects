//+------------------------------------------------------------------+
//|                                                    sRequest2.mq5 |
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
   string file_name="Databases\\Calendar_DB.sqlite";
   uint flags=DATABASE_OPEN_READONLY;
   if(!db_obj.Open(file_name, flags))
      {
      ::PrintFormat("Failed to open a calendar database \"%s\"!", file_name);
      db_obj.Close();
      return;
      }
   string table_name="EVENTS";
   if(db_obj.SelectTable(table_name))
      {
      //--- 1) countries by id where the indicator '%GDP q/q%' exists
      string col_names[]= {"COUNTRY_ID", "EVENT_ID"};
      string where_condition="(NAME LIKE 'GDP q/q' AND SECTOR='Gross Domestic Product')";
      if(!db_obj.SelectFromWhere(col_names, where_condition))
         {
         db_obj.Close();
         return;
         }
      ::Print("\nCountries by id where the indicator 'GDP q/q' exists:\n");
      //--- print the SQL request
      if(db_obj.PrintSqlRequest()<0)
         ::PrintFormat("Failed to print the SQL request, error %d", ::GetLastError());
      db_obj.FinalizeSqlRequest();
      //--- 2)  'GDP q/q' event and last values
      string subquery=db_obj.SqlRequest();
      string new_sql_request1=::StringFormat("SELECT evs.COUNTRY_ID AS country_id,"
                                             "evals.EVENT_ID AS event_id,"
                                             "evals.VALUE_ID AS value_id,"
                                             "evals.PERIOD AS period,"
                                             "evals.TIME AS time,"
                                             "evals.ACTUAL AS actual "
                                             "FROM EVENT_VALUES evals "
                                             "JOIN(%s) AS evs ON evals.event_id = evs.event_id "
                                             " WHERE (period = \'2022.07.01 00:00\')", subquery);
      if(!db_obj.Select(new_sql_request1))
         {
         db_obj.Close();
         return;
         }
      ::Print("\n'GDP q/q' event and last values:\n");
      //--- print the SQL request
      if(db_obj.PrintSqlRequest()<0)
         ::PrintFormat("Failed to print the SQL request, error %d", ::GetLastError());
      db_obj.FinalizeSqlRequest();
      //--- 3)  'GDP q/q' event and grouped last values
      subquery=db_obj.SqlRequest();
      string new_sql_request2=::StringFormat("%s GROUP BY evals.event_id "
                                             "HAVING MAX(value_id)", subquery);
      if(!db_obj.Select(new_sql_request2))
         {
         db_obj.Close();
         return;
         }
      ::Print("\n'GDP q/q' event and grouped last values:\n");
      //--- print the SQL request
      if(db_obj.PrintSqlRequest()<0)
         ::PrintFormat("Failed to print the SQL request, error %d", ::GetLastError());
      db_obj.FinalizeSqlRequest();
      //--- 4)  'GDP q/q' event and grouped last values with country names
      subquery=db_obj.SqlRequest();
      string new_sql_request3=::StringFormat("SELECT c.NAME AS country,"
                                             "ev_evals.event_id AS event_id,"
                                             "ev_evals.value_id AS value_id,"
                                             "ev_evals.period AS period,"
                                             "ev_evals.TIME AS time,"
                                             "ev_evals.ACTUAL AS actual "
                                             "FROM COUNTRIES c JOIN (%s) "
                                             "AS ev_evals ON c.COUNTRY_ID = ev_evals.country_id",
                                             subquery);
      if(!db_obj.Select(new_sql_request3))
         {
         db_obj.Close();
         return;
         }
      ::Print("\n'GDP q/q' event and grouped last values with country names:\n");
      //--- print the SQL request
      if(db_obj.PrintSqlRequest()<0)
         ::PrintFormat("Failed to print the SQL request, error %d", ::GetLastError());
      db_obj.FinalizeSqlRequest();
      }
   db_obj.Close();
   }
//+------------------------------------------------------------------+
