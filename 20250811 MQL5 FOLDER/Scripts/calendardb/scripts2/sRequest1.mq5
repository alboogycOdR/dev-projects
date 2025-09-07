//+------------------------------------------------------------------+
//|                                                    sRequest1.mq5 |
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
   //--- 1) group events number by country id
   string table_name="EVENTS";
   if(db_obj.SelectTable(table_name))
      {
      string col_names_to_select[]=
         {
         "COUNTRY_ID AS id", "COUNT(EVENT_ID) AS events_num"
         };
      string gr_names[]=
         {
         "COUNTRY_ID"
         };
      if(!db_obj.SelectFromGroupBy(col_names_to_select, gr_names))
         {
         db_obj.Close();
         return;
         }
      //--- print the SQL request
      if(db_obj.PrintSqlRequest()<0)
         ::PrintFormat("Failed to print the SQL request, error %d", ::GetLastError());
      db_obj.FinalizeSqlRequest();
      //--- 2) group events number by country name using a subquery
      ::Print("\nGroup events number by country name using a subquery:\n");
      string subquery=db_obj.SqlRequest();
      string new_sql_request1=::StringFormat("SELECT c.NAME AS country,"
                                             "ev.events_num AS events_number FROM COUNTRIES c "
                                             "JOIN(%s) AS ev "
                                             "ON c.COUNTRY_ID=ev.id", subquery);
      if(!db_obj.Select(new_sql_request1))
         {
         db_obj.Close();
         return;
         }
      //--- print the SQL request
      if(db_obj.PrintSqlRequest()<0)
         ::PrintFormat("Failed to print the SQL request, error %d", ::GetLastError());
      db_obj.FinalizeSqlRequest();
      //--- 3) group events number by country name using CTE
      ::Print("\nGroup events number by country name using CTE:\n");
      string new_sql_request2=::StringFormat("WITH ev_cnt AS (%s)"
                                             "SELECT c.NAME AS country,"
                                             "ev.events_num AS events_number FROM COUNTRIES c "
                                             "INNER JOIN ev_cnt AS ev ON c.COUNTRY_ID=ev.id", subquery);
      if(!db_obj.Select(new_sql_request2))
         {
         db_obj.Close();
         return;
         }
      //--- print the SQL request
      if(db_obj.PrintSqlRequest()<0)
         ::PrintFormat("Failed to print the SQL request, error %d", ::GetLastError());
      db_obj.FinalizeSqlRequest();
      //--- 4) important events - ids and important events number
      ::Print("\nGroup important events number by country id:\n");
      string new_sql_request3="SELECT COUNTRY_ID AS id,"
                              "COUNT(IMPORTANCE) AS high "
                              "FROM EVENTS WHERE IMPORTANCE='High' GROUP BY COUNTRY_ID";
      if(!db_obj.Select(new_sql_request3))
         {
         db_obj.Close();
         return;
         }
      //--- print the SQL request
      if(db_obj.PrintSqlRequest()<0)
         ::PrintFormat("Failed to print the SQL request, error %d", ::GetLastError());
      db_obj.FinalizeSqlRequest();
      //--- 5) important events - ids, events number and important events number
      ::Print("\nGroup events number and important events number by country id:\n");
      subquery=db_obj.SqlRequest();
      string new_sql_request4=::StringFormat("SELECT ev.COUNTRY_ID AS id, COUNT(EVENT_ID) AS events_num,"
                                             "imp.high AS imp_events_num "
                                             "FROM EVENTS ev JOIN (%s) AS imp "
                                             "ON ev.COUNTRY_ID=imp.id GROUP BY COUNTRY_ID", subquery);
      if(!db_obj.Select(new_sql_request4))
         {
         db_obj.Close();
         return;
         }
      //--- print the SQL request
      if(db_obj.PrintSqlRequest()<0)
         ::PrintFormat("Failed to print the SQL request, error %d", ::GetLastError());
      db_obj.FinalizeSqlRequest();
      //--- 6) important events - countries, events number and important events number
      ::Print("\nGroup events number and important events number by country:\n");
      subquery=db_obj.SqlRequest();
      string new_sql_request5=::StringFormat("SELECT c.NAME AS country,"
                                             "ev.events_num AS events_number,"
                                             "ev.imp_events_num AS imp_events_number "
                                             "FROM COUNTRIES c "
                                             "JOIN(%s) AS ev "
                                             "ON c.COUNTRY_ID=ev.id "
                                             "ORDER BY imp_events_number DESC", subquery);
      if(!db_obj.Select(new_sql_request5))
         {
         db_obj.Close();
         return;
         }
      //--- print the SQL request
      if(db_obj.PrintSqlRequest()<0)
         ::PrintFormat("Failed to print the SQL request, error %d", ::GetLastError());
      db_obj.FinalizeSqlRequest();
      //--- 7) countries having no important events
      ::Print("\nCountries having no important events:\n");
      string last_request=db_obj.SqlRequest();
      string new_sql_request6=::StringFormat("SELECT NAME FROM COUNTRIES "
                                             "EXCEPT SELECT country FROM (%s)", last_request);
      if(!db_obj.Select(new_sql_request6))
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
