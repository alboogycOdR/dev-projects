//+------------------------------------------------------------------+
//|                                                      NewsTrading |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                            https://www.mql5.com/en/users/kaaiblo |
//+------------------------------------------------------------------+
#include "CommonVariables.mqh"
#include "DayLightSavings/DaylightSavings_UK.mqh"
#include "DayLightSavings/DaylightSavings_US.mqh"
#include "DayLightSavings/DaylightSavings_AU.mqh"
#include "CandleProperties.mqh"

//+------------------------------------------------------------------+
//|News class                                                        |
//+------------------------------------------------------------------+
class CNews : private CCandleProperties
  {
   //Private Declarations Only accessable by this class/header file
private:

   //-- To keep track of what is in our database
   enum CalendarComponents
     {
      AutoDST_Table,//AutoDST Table
      CalendarAU_View,//View for DST_AU
      CalendarNONE_View,//View for DST_NONE
      CalendarUK_View,//View for DST_UK
      CalendarUS_View,//View for DST_US
      Record_Table,// Record Table
      TimeSchedule_Table,//TimeSchedule Table
      MQL5Calendar_Table,//MQL5Calendar Table
      AutoDST_Trigger,//Table Trigger for AutoDST
      Record_Trigger//Table Trigger for Record
     };

   //-- structure to retrieve all the objects in the database
   struct SQLiteMaster
     {
      string         type;//will store object's type
      string         name;//will store object's name
      string         tbl_name;//will store table name
      int            rootpage;//will store rootpage
      string         sql;//Will store the sql create statement
     } DBContents[];//Array of type SQLiteMaster

   //--  MQL5CalendarContents inherits from SQLiteMaster structure
   struct MQL5CalendarContents:SQLiteMaster
     {
      CalendarComponents  Content;
      string         insert;//Will store the sql insert statement
     } CalendarContents[10];//Array to Store objects in our database

   CTimeManagement   Time;//TimeManagement Object declaration
   CDaylightSavings_UK  Savings_UK;//DaylightSavings Object for the UK and EU
   CDaylightSavings_US  Savings_US;//DaylightSavings Object for the US
   CDaylightSavings_AU  Savings_AU;//DaylightSavings Object for the AU

   bool              AutoDetectDST(DST_type &dstType);//Function will determine Broker DST
   DST_type          DSTType;//variable of DST_type enumeration declared in the CommonVariables class/header file
   bool              InsertIntoTables(int db,Calendar &Evalues[]);//Function for inserting Economic Data in to a database's table
   void              CreateAutoDST(int db);//Function for creating and inserting Recommend DST for the Broker into a table
   bool              CreateCalendarTable(int db,bool &tableExists);//Function for creating a table in a database
   bool              CreateTimeTable(int db,bool &tableExists);//Function for creating a table in a database
   void              CreateCalendarViews(int db);//Function for creating views in a database
   void              CreateRecordTable(int db);//Creates a table to store the record of when last the Calendar database was updated/created
   bool              UpdateRecords();//Checks if the main Calendar database needs an update or not
   void              EconomicDetails(Calendar &NewsTime[]);//Gets values from the MQL5 economic Calendar
   string            DropRequest;//Variable for dropping tables in the database

   //-- Function for retrieving the MQL5CalendarContents structure for the enumartion type CalendarComponents
   MQL5CalendarContents CalendarStruct(CalendarComponents Content)
     {
      MQL5CalendarContents Calendar;
      for(uint i=0;i<CalendarContents.Size();i++)
        {
         if(CalendarContents[i].Content==Content)
           {
            return CalendarContents[i];
           }
        }
      return Calendar;
     }

   //Public declarations accessable via a class's Object
public:
                     CNews(void);
                    ~CNews(void);//Deletes a text file created when the Calendar database is being worked on
   void              CreateEconomicDatabase();//Creates the Calendar database for a specific Broker
   datetime          GetLatestNewsDate();//Gets the lastest/newest date in the Calendar database
  };

//+------------------------------------------------------------------+
//|Constructor                                                       |
//+------------------------------------------------------------------+
CNews::CNews(void):DropRequest("PRAGMA foreign_keys = OFF; "
                                  "PRAGMA secure_delete = ON; "
                                  "Drop %s IF EXISTS %s; "
                                  "Vacuum; "
                                  "PRAGMA foreign_keys = ON;")//Sql drop statement
  {
//-- initializing properties for the AutoDST table
   CalendarContents[0].Content = AutoDST_Table;
   CalendarContents[0].name = "AutoDST";
   CalendarContents[0].sql = "CREATE TABLE AutoDST(DST TEXT NOT NULL DEFAULT 'DST_NONE')STRICT;";
   CalendarContents[0].tbl_name = "AutoDST";
   CalendarContents[0].type = "table";
   CalendarContents[0].insert = "INSERT INTO 'AutoDST'(DST) VALUES ('%s');";

   string views[] = {"UK","US","AU","NONE"};
   string view_sql = "CREATE VIEW IF NOT EXISTS Calendar_%s "
                     "AS "
                     "SELECT C.Eventid,C.Eventname,C.Country,T.DST_%s as Time,C.EventCurrency,C.Eventcode from MQL5Calendar C,Record R "
                     "Inner join TimeSchedule T on C.ID=T.ID "
                     "Where DATE(REPLACE(T.DST_%s,'.','-'))=R.Date "
                     "Order by T.DST_%s Asc;";

//-- Sql statements for creating the table views
   for(uint i=1;i<=views.Size();i++)
     {
      CalendarContents[i].Content = (CalendarComponents)i;
      CalendarContents[i].name = StringFormat("Calendar_%s",views[i-1]);
      CalendarContents[i].sql = StringFormat(view_sql,views[i-1],views[i-1],views[i-1],views[i-1]);
      CalendarContents[i].tbl_name = StringFormat("Calendar_%s",views[i-1]);
      CalendarContents[i].type = "view";
     }

//-- initializing properties for the Record table
   CalendarContents[5].Content = Record_Table;
   CalendarContents[5].name = "Record";
   CalendarContents[5].sql = "CREATE TABLE Record(Date TEXT NOT NULL)STRICT;";
   CalendarContents[5].tbl_name="Record";
   CalendarContents[5].type = "table";
   CalendarContents[5].insert = "INSERT INTO 'Record'(Date) VALUES (Date(REPLACE('%s','.','-')));";

//-- initializing properties for the TimeSchedule table
   CalendarContents[6].Content = TimeSchedule_Table;
   CalendarContents[6].name = "TimeSchedule";
   CalendarContents[6].sql = "CREATE TABLE TimeSchedule(ID INT NOT NULL,DST_UK   TEXT   NOT NULL,DST_US   TEXT   NOT NULL,"
                             "DST_AU   TEXT   NOT NULL,DST_NONE   TEXT   NOT NULL,FOREIGN KEY (ID) REFERENCES MQL5Calendar (ID))STRICT;";
   CalendarContents[6].tbl_name="TimeSchedule";
   CalendarContents[6].type = "table";
   CalendarContents[6].insert = "INSERT INTO 'TimeSchedule'(ID,DST_UK,DST_US,DST_AU,DST_NONE) "
                                "VALUES (%d,'%s','%s', '%s', '%s');";

//-- initializing properties for the MQL5Calendar table
   CalendarContents[7].Content = MQL5Calendar_Table;
   CalendarContents[7].name = "MQL5Calendar";
   CalendarContents[7].sql = "CREATE TABLE MQL5Calendar(ID INT NOT NULL,EVENTID  INT   NOT NULL,COUNTRY  TEXT   NOT NULL,"
                             "EVENTNAME   TEXT   NOT NULL,EVENTTYPE   TEXT   NOT NULL,EVENTIMPORTANCE   TEXT   NOT NULL,"
                             "EVENTCURRENCY  TEXT   NOT NULL,EVENTCODE   TEXT   NOT NULL,EVENTSECTOR TEXT   NOT NULL,"
                             "EVENTFORECAST  TEXT   NOT NULL,EVENTPREVALUE  TEXT   NOT NULL,EVENTIMPACT TEXT   NOT NULL,"
                             "EVENTFREQUENCY TEXT   NOT NULL,PRIMARY KEY(ID))STRICT;";
   CalendarContents[7].tbl_name="MQL5Calendar";
   CalendarContents[7].type = "table";
   CalendarContents[7].insert = "INSERT INTO 'MQL5Calendar'(ID,EVENTID,COUNTRY,EVENTNAME,EVENTTYPE,EVENTIMPORTANCE,EVENTCURRENCY,EVENTCODE,"
                                "EVENTSECTOR,EVENTFORECAST,EVENTPREVALUE,EVENTIMPACT,EVENTFREQUENCY) "
                                "VALUES (%d,%d,'%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s');";

//-- Sql statement for creating the AutoDST table's trigger
   CalendarContents[8].Content = AutoDST_Trigger;
   CalendarContents[8].name = "OnlyOne_AutoDST";
   CalendarContents[8].sql = "CREATE TRIGGER IF NOT EXISTS OnlyOne_AutoDST "
                             "BEFORE INSERT ON AutoDST "
                             "BEGIN "
                             "Delete from AutoDST; "
                             "END;";
   CalendarContents[8].tbl_name="AutoDST";
   CalendarContents[8].type = "trigger";

//-- Sql statement for creating the Record table's trigger
   CalendarContents[9].Content = Record_Trigger;
   CalendarContents[9].name = "OnlyOne_Record";
   CalendarContents[9].sql = "CREATE TRIGGER IF NOT EXISTS OnlyOne_Record "
                             "BEFORE INSERT ON Record "
                             "BEGIN "
                             "Delete from Record; "
                             "END;";
   CalendarContents[9].tbl_name="Record";
   CalendarContents[9].type = "trigger";
  }

//+------------------------------------------------------------------+
//|Destructor                                                        |
//+------------------------------------------------------------------+
CNews::~CNews(void)
  {
   if(FileIsExist(NEWS_TEXT_FILE,FILE_COMMON))//Check if the news database open text file exists
     {
      FileDelete(NEWS_TEXT_FILE,FILE_COMMON);
     }
  }

//+------------------------------------------------------------------+
//|Gets values from the MQL5 economic Calendar                       |
//+------------------------------------------------------------------+
void CNews::EconomicDetails(Calendar &NewsTime[])
  {
   int Size=0;//to keep track of the size of the events in the NewsTime array
   MqlCalendarCountry countries[];
   string Country_code="";

   for(int i=0,count=CalendarCountries(countries); i<count; i++)
     {
      MqlCalendarValue values[];
      datetime date_from=0;//Get date from the beginning
      datetime date_to=(datetime)(Time.MonthsS()+iTime(Symbol(),PERIOD_D1,0));//Date of the next month from the current day
      if(CalendarValueHistory(values,date_from,date_to,countries[i].code))
        {
         for(int x=0; x<(int)ArraySize(values); x++)
           {
            MqlCalendarEvent event;
            ulong event_id=values[x].event_id;//Get the event id
            if(CalendarEventById(event_id,event))
              {
               ArrayResize(NewsTime,Size+1,Size+2);//Readjust the size of the array to +1 of the array size
               StringReplace(event.name,"'","");//Removing or replacing single quotes(') from event name with an empty string
               NewsTime[Size].CountryName = countries[i].name;//storing the country's name from the specific event
               NewsTime[Size].EventName = event.name;//storing the event's name
               NewsTime[Size].EventType = EnumToString(event.type);//storing the event type from (ENUM_CALENDAR_EVENT_TYPE) to a string
               //-- storing the event importance from (ENUM_CALENDAR_EVENT_IMPORTANCE) to a string
               NewsTime[Size].EventImportance = EnumToString(event.importance);
               NewsTime[Size].EventId = event.id;//storing the event id
               NewsTime[Size].EventDate = TimeToString(values[x].time);//storing normal event time
               NewsTime[Size].EventCurrency = countries[i].currency;//storing event currency
               NewsTime[Size].EventCode = countries[i].code;//storing event code
               NewsTime[Size].EventSector = EnumToString(event.sector);//storing event sector from (ENUM_CALENDAR_EVENT_SECTOR) to a string
               if(values[x].HasForecastValue())//Checks if the event has a forecast value
                 {
                  NewsTime[Size].EventForecast = (string)values[x].forecast_value;//storing the forecast value into a string
                 }
               else
                 {
                  NewsTime[Size].EventForecast = "None";//storing 'None' as the forecast value
                 }

               if(values[x].HasPreviousValue())//Checks if the event has a previous value
                 {
                  NewsTime[Size].EventPreval = (string)values[x].prev_value;//storing the previous value into a string
                 }
               else
                 {
                  NewsTime[Size].EventPreval = "None";//storing 'None' as the previous value
                 }
               //-- storing the event impact from (ENUM_CALENDAR_EVENT_IMPACT) to a string
               NewsTime[Size].EventImpact =  EnumToString(values[x].impact_type);
               //-- storing the event frequency from (ENUM_CALENDAR_EVENT_FREQUENCY) to a string
               NewsTime[Size].EventFrequency =  EnumToString(event.frequency);
               Size++;//incrementing the Calendar array NewsTime
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|Checks if the main Calendar database needs an update or not       |
//+------------------------------------------------------------------+
bool CNews::UpdateRecords()
  {
//initialize variable to true
   bool perform_update=true;
//--- open/create
//-- try to open database Calendar
   int db=DatabaseOpen(NEWS_DATABASE_FILE, DATABASE_OPEN_READWRITE | DATABASE_OPEN_CREATE| DATABASE_OPEN_COMMON);
   if(db==INVALID_HANDLE)//Checks if the database was able to be opened
     {
      //if opening the database failed
      if(!FileIsExist(NEWS_DATABASE_FILE,FILE_COMMON))//Checks if the database Calendar exists in the common folder
        {
         return perform_update;//Returns true when the database was failed to be opened and the file doesn't exist in the common folder
        }
     }

   int MasterRequest = DatabasePrepare(db,"select * from sqlite_master where type<>'index';");
   if(MasterRequest==INVALID_HANDLE)
     {
      Print("DB: ",NEWS_DATABASE_FILE, " request failed with code ", GetLastError());
     }
   else
     {
      SQLiteMaster ReadContents;
      //Assigning values from the sql query into DBContents array
      for(int i=0; DatabaseReadBind(MasterRequest,ReadContents); i++)
        {
         ArrayResize(DBContents,i+1,i+2);
         DBContents[i].type = ReadContents.type;
         DBContents[i].name = ReadContents.name;
         DBContents[i].tbl_name = ReadContents.tbl_name;
         DBContents[i].rootpage = ReadContents.rootpage;
         /*Check if the end of the sql string has a character ';' if not add this character to the string*/
         DBContents[i].sql = (StringFind(ReadContents.sql,";",StringLen(ReadContents.sql)-1)==
                              (StringLen(ReadContents.sql)-1))?ReadContents.sql:ReadContents.sql+";";;
        }

      uint contents_exists = 0;
      for(uint i=0;i<DBContents.Size();i++)
        {
         bool isCalendarContents = false;
         for(uint x=0;x<CalendarContents.Size();x++)
           {
            /*Store Sql query from CalendarContents without string ' IF NOT EXISTS'*/
            string CalendarSql=CalendarContents[x].sql;
            StringReplace(CalendarSql," IF NOT EXISTS","");
            //-- Check if the Db object is in our list
            if(DBContents[i].name==CalendarContents[x].name&&
               (DBContents[i].sql==CalendarSql||
                DBContents[i].sql==CalendarContents[x].sql)&&
               CalendarContents[x].type==DBContents[i].type&&
               CalendarContents[x].tbl_name==DBContents[i].tbl_name)
              {
               contents_exists++;
               isCalendarContents = true;
              }
           }
         if(!isCalendarContents)
           {
            //-- Print DBcontent's name if it does not match with CalendarContents
            PrintFormat("DBContent: %s is not needed!",DBContents[i].name);
            //-- We will drop the table if it is not neccessary
            DatabaseExecute(db,StringFormat(DropRequest,DBContents[i].type,DBContents[i].name));
            Print("Attempting To Clean Database...");
           }
        }
      /*If not all the CalendarContents exist in the Calendar Database before an update */
      if(contents_exists!=CalendarContents.Size())
        {
         return perform_update;
        }
     }
   if(!DatabaseTableExists(db,CalendarStruct(Record_Table).name))//If the database table 'Record' doesn't exist
     {
      DatabaseClose(db);
      return perform_update;
     }

//-- Sql query to determine the lastest or maximum date recorded
   /* If the last recorded date data in the 'Record' table is not equal to the current day, perform an update! */
   string request_text=StringFormat("SELECT Date FROM %s where Date=Date(REPLACE('%s','.','-'))",
                                    CalendarStruct(Record_Table).name,TimeToString(TimeTradeServer()));
   int request=DatabasePrepare(db,request_text);//Creates a handle of a request, which can then be executed using DatabaseRead()
   if(request==INVALID_HANDLE)//Checks if the request failed to be completed
     {
      Print("DB: ",NEWS_DATABASE_FILE, " request failed with code ", GetLastError());
      DatabaseClose(db);
      return perform_update;
     }

   if(DatabaseRead(request))//Will be true if there are results from the sql query/request
     {
      DatabaseFinalize(request);//Removes a request created in DatabasePrepare()
      DatabaseClose(db);//Closes the database
      perform_update=false;
      return perform_update;
     }
   else
     {
      DatabaseFinalize(request);//Removes a request created in DatabasePrepare()
      DatabaseClose(db);//Closes the database
      return perform_update;
     }
  }

//+------------------------------------------------------------------+
//|Creates the Calendar database for a specific Broker               |
//+------------------------------------------------------------------+
void CNews::CreateEconomicDatabase()
  {
   if(FileIsExist(NEWS_DATABASE_FILE,FILE_COMMON))//Check if the database exists
     {
      if(!UpdateRecords())//Check if the database is up to date
        {
         return;//will terminate execution of the rest of the code below
        }
     }
   if(FileIsExist(NEWS_TEXT_FILE,FILE_COMMON))//Check if the database is open
     {
      return;//will terminate execution of the rest of the code below
     }

   Calendar Evalues[];//Creating a Calendar array variable
   bool failed=false,tableExists=false;
   int file=INVALID_HANDLE;
//--- open/create the database 'Calendar'
//-- will try to open/create in the common folder
   int db=DatabaseOpen(NEWS_DATABASE_FILE, DATABASE_OPEN_READWRITE | DATABASE_OPEN_CREATE| DATABASE_OPEN_COMMON);
   if(db==INVALID_HANDLE)//Checks if the database 'Calendar' failed to open/create
     {
      Print("DB: ",NEWS_DATABASE_FILE, " open failed with code ", GetLastError());
      return;//will terminate execution of the rest of the code below
     }
   else
     {
      //-- try to create a text file 'NewsDatabaseOpen' in common folder
      file=FileOpen(NEWS_TEXT_FILE,FILE_WRITE|FILE_ANSI|FILE_TXT|FILE_COMMON);
      if(file==INVALID_HANDLE)
        {
         DatabaseClose(db);//Closes the database 'Calendar' if the News text file failed to be created
         return;//will terminate execution of the rest of the code below
        }
     }

   DatabaseTransactionBegin(db);//Starts transaction execution
   Print("Please wait...");

//-- attempt to create the MQL5Calendar and TimeSchedule tables
   if(!CreateCalendarTable(db,tableExists)||!CreateTimeTable(db,tableExists))
     {
      FileClose(file);//Closing the file 'NewsDatabaseOpen.txt'
      FileDelete(NEWS_TEXT_FILE,FILE_COMMON);//Deleting the file 'NewsDatabaseOpen.txt'
      return;//will terminate execution of the rest of the code below
     }

   EconomicDetails(Evalues);//Retrieving the data from the Economic Calendar
   if(tableExists)//Checks if there is an existing table within the Calendar Database
     {
      //if there is an existing table we will notify the user that we are updating the table.
      PrintFormat("Updating %s",NEWS_DATABASE_FILE);
     }
   else
     {
      //if there isn't an existing table we will notify the user that we about to create one
      PrintFormat("Creating %s",NEWS_DATABASE_FILE);
     }

//-- attempt to insert economic event data into the calendar tables
   if(!InsertIntoTables(db,Evalues))
     {
      //-- Will assign true if inserting economic vaules failed in the MQL5Calendar and TimeSchedule tables
      failed=true;
     }

   if(failed)
     {
      //--- roll back all transactions and unlock the database
      DatabaseTransactionRollback(db);
      PrintFormat("%s: DatabaseExecute() failed with code %d", __FUNCTION__, GetLastError());
      FileClose(file);//Close the text file 'NEWS_TEXT_FILE'
      FileDelete(NEWS_TEXT_FILE,FILE_COMMON);//Delete the text file, as we are reverted/rolled-back the database
      ArrayRemove(Evalues,0,WHOLE_ARRAY);//Removes the values in the array
     }
   else
     {
      if(tableExists)
        {
         //Let the user/trader know that the database was updated
         PrintFormat("%s Updated",NEWS_DATABASE_FILE);
        }
      else
        {
         //Let the user/trader know that the database was created
         PrintFormat("%s Created",NEWS_DATABASE_FILE);
        }
      CreateCalendarViews(db);//Will create Calendar views
      CreateRecordTable(db);//Will create the 'Record' table and insert the  current time
      CreateAutoDST(db);//Will create the 'AutoDST' table and insert the broker's DST schedule
      FileClose(file);//Close the text file 'NEWS_TEXT_FILE'
      FileDelete(NEWS_TEXT_FILE,FILE_COMMON);//Delete the text file, as we are about to close the database
      ArrayRemove(Evalues,0,WHOLE_ARRAY);//Removes the values in the array
     }
//--- all transactions have been performed successfully - record changes and unlock the database
   DatabaseTransactionCommit(db);
   DatabaseClose(db);//Close the database
  }


//+------------------------------------------------------------------+
//|Function for creating a table in a database                       |
//+------------------------------------------------------------------+
bool CNews::CreateCalendarTable(int db,bool &tableExists)
  {
//-- Checks if a table 'MQL5Calendar' exists
   if(DatabaseTableExists(db,CalendarStruct(MQL5Calendar_Table).name))
     {
      tableExists=true;//Assigns true to tableExists variable
      //-- Checks if a table 'TimeSchedule' exists in the database 'Calendar'
      if(DatabaseTableExists(db,CalendarStruct(TimeSchedule_Table).name))
        {
         //-- We will drop the table if the table already exists
         if(!DatabaseExecute(db,StringFormat("Drop Table %s",CalendarStruct(TimeSchedule_Table).name)))
           {
            //If the table failed to be dropped/deleted
            PrintFormat("Failed to drop table %s with code %d",CalendarStruct(TimeSchedule_Table).name,GetLastError());
            DatabaseClose(db);//Close the database
            return false;//will terminate execution of the rest of the code below and return false, when the table cannot be dropped
           }
        }
      //--We will drop the table if the table already exists
      if(!DatabaseExecute(db,StringFormat("Drop Table %s",CalendarStruct(MQL5Calendar_Table).name)))
        {
         //If the table failed to be dropped/deleted
         PrintFormat("Failed to drop table %s with code %d",CalendarStruct(MQL5Calendar_Table).name,GetLastError());
         DatabaseClose(db);//Close the database
         return false;//will terminate execution of the rest of the code below and return false, when the table cannot be dropped
        }
     }
//-- If the database table 'MQL5Calendar' doesn't exist
   if(!DatabaseTableExists(db,CalendarStruct(MQL5Calendar_Table).name))
     {
      //--- create the table 'MQL5Calendar'
      if(!DatabaseExecute(db,CalendarStruct(MQL5Calendar_Table).sql))//Checks if the table was successfully created
        {
         Print("DB: create the Calendar table failed with code ", GetLastError());
         DatabaseClose(db);//Close the database
         return false;//Function returns false if creating the table failed
        }
     }
   return true;//Function returns true if creating the table was successful
  }

//+------------------------------------------------------------------+
//|Function for creating a table in a database                       |
//+------------------------------------------------------------------+
bool CNews::CreateTimeTable(int db,bool &tableExists)
  {
//-- If the database table 'TimeSchedule' doesn't exist
   if(!DatabaseTableExists(db,CalendarStruct(TimeSchedule_Table).name))
     {
      //--- create the table 'TimeSchedule'
      if(!DatabaseExecute(db,CalendarStruct(TimeSchedule_Table).sql))//Checks if the table was successfully created
        {
         Print("DB: create the Calendar table failed with code ", GetLastError());
         DatabaseClose(db);//Close the database
         return false;//Function returns false if creating the table failed
        }
     }
   return true;//Function returns true if creating the table was successful
  }

//+------------------------------------------------------------------+
//|Function for creating views in a database                         |
//+------------------------------------------------------------------+
void CNews::CreateCalendarViews(int db)
  {
   for(uint i=1;i<=4;i++)
     {
      if(!DatabaseExecute(db,CalendarStruct((CalendarComponents)i).sql))//Checks if the view was successfully created
        {
         Print("DB: create the Calendar view failed with code ", GetLastError());
        }
     }
  }

//+------------------------------------------------------------------+
//|Function for inserting Economic Data in to a database's table     |
//+------------------------------------------------------------------+
bool CNews::InsertIntoTables(int db,Calendar &Evalues[])
  {
   for(uint i=0; i<Evalues.Size(); i++)//Looping through all the Economic Events
     {
      string request_insert_into_calendar =
         StringFormat(CalendarStruct(MQL5Calendar_Table).insert,
                      i,
                      Evalues[i].EventId,
                      Evalues[i].CountryName,
                      Evalues[i].EventName,
                      Evalues[i].EventType,
                      Evalues[i].EventImportance,
                      Evalues[i].EventCurrency,
                      Evalues[i].EventCode,
                      Evalues[i].EventSector,
                      Evalues[i].EventForecast,
                      Evalues[i].EventPreval,
                      Evalues[i].EventImpact,
                      Evalues[i].EventFrequency);//Inserting all the columns for each event record
      if(DatabaseExecute(db,request_insert_into_calendar))//Check if insert query into calendar was successful
        {
         string request_insert_into_time =
            StringFormat(CalendarStruct(TimeSchedule_Table).insert,
                         i,
                         //-- Economic EventDate adjusted for UK DST(Daylight Savings Time)
                         Savings_UK.adjustDaylightSavings(StringToTime(Evalues[i].EventDate)),
                         //-- Economic EventDate adjusted for US DST(Daylight Savings Time)
                         Savings_US.adjustDaylightSavings(StringToTime(Evalues[i].EventDate)),
                         //-- Economic EventDate adjusted for AU DST(Daylight Savings Time)
                         Savings_AU.adjustDaylightSavings(StringToTime(Evalues[i].EventDate)),
                         Evalues[i].EventDate//normal Economic EventDate
                        );//Inserting all the columns for each event record
         if(!DatabaseExecute(db,request_insert_into_time))
           {
            Print(GetLastError());
            //-- Will print the sql query to check for any errors or possible defaults in the query/request
            Print(request_insert_into_time);
            return false;//Will end the loop and return false, as values failed to be inserted into the table
           }
        }
      else
        {
         Print(GetLastError());
         //-- Will print the sql query to check for any errors or possible defaults in the query/request
         Print(request_insert_into_calendar);
         return false;//Will end the loop and return false, as values failed to be inserted into the table
        }
     }
   return true;//Will return true, all values were inserted into the table successfully
  }

//+------------------------------------------------------------------+
//|Creates a table to store the record of when last the Calendar     |
//|database was updated/created                                      |
//+------------------------------------------------------------------+
void CNews::CreateRecordTable(int db)
  {
   bool failed=false;
   if(!DatabaseTableExists(db,CalendarStruct(Record_Table).name))//Checks if the table 'Record' exists in the databse 'Calendar'
     {
      //--- create the table
      if(!DatabaseExecute(db,CalendarStruct(Record_Table).sql))//Will attempt to create the table 'Record'
        {
         Print("DB: create the Records table failed with code ", GetLastError());
         DatabaseClose(db);//Close the database
         return;//Exits the function if creating the table failed
        }
      else//If Table was created Successfully then Create Trigger
        {
         DatabaseExecute(db,CalendarStruct(Record_Trigger).sql);
        }
     }
   else
     {
      DatabaseExecute(db,CalendarStruct(Record_Trigger).sql);
     }
//Sql query/request to insert the current time into the 'Date' column in the table 'Record'
   string request_text=StringFormat(CalendarStruct(Record_Table).insert,TimeToString(TimeTradeServer()));
   if(!DatabaseExecute(db, request_text))//Will attempt to run this sql request/query
     {
      Print(GetLastError());
      PrintFormat(CalendarStruct(Record_Table).insert,TimeToString(TimeTradeServer()));
      failed=true;//assign true if the request failed
     }
   if(failed)
     {
      //--- roll back all transactions and unlock the database
      DatabaseTransactionRollback(db);
      PrintFormat("%s: DatabaseExecute() failed with code %d", __FUNCTION__, GetLastError());
     }
  }

//+------------------------------------------------------------------+
//|Function for creating and inserting Recommend DST for the Broker  |
//|into a table                                                      |
//+------------------------------------------------------------------+
void CNews::CreateAutoDST(int db)
  {
   bool failed=false;//boolean variable
   if(!AutoDetectDST(DSTType))//Check if AutoDetectDST went through all the right procedures
     {
      return;//will terminate execution of the rest of the code below
     }

   if(!DatabaseTableExists(db,CalendarStruct(AutoDST_Table).name))//Checks if the table 'AutoDST' exists in the databse 'Calendar'
     {
      //--- create the table AutoDST
      if(!DatabaseExecute(db,CalendarStruct(AutoDST_Table).sql))//Will attempt to create the table 'AutoDST'
        {
         Print("DB: create the AutoDST table failed with code ", GetLastError());
         DatabaseClose(db);//Close the database
         return;//Exits the function if creating the table failed
        }
      else//If Table was created Successfully then Create Trigger
        {
         DatabaseExecute(db,CalendarStruct(AutoDST_Trigger).sql);
        }
     }
   else
     {
      //Create trigger if AutoDST table exists
      DatabaseExecute(db,CalendarStruct(AutoDST_Trigger).sql);
     }
//Sql query/request to insert the recommend DST for the Broker using the DSTType variable to determine which string data to insert
   string request_text=StringFormat(CalendarStruct(AutoDST_Table).insert,EnumToString(DSTType));
   if(!DatabaseExecute(db, request_text))//Will attempt to run this sql request/query
     {
      Print(GetLastError());
      PrintFormat(CalendarStruct(AutoDST_Table).insert,EnumToString(DSTType));//Will print the sql query if failed
      failed=true;//assign true if the request failed
     }
   if(failed)
     {
      //--- roll back all transactions and unlock the database
      DatabaseTransactionRollback(db);
      PrintFormat("%s: DatabaseExecute() failed with code %d", __FUNCTION__, GetLastError());
     }
  }

//+------------------------------------------------------------------+
//|Gets the latest/newest date in the Calendar database              |
//+------------------------------------------------------------------+
datetime CNews::GetLatestNewsDate()
  {
//--- open the database 'Calendar' in the common folder
   int db=DatabaseOpen(NEWS_DATABASE_FILE, DATABASE_OPEN_READONLY|DATABASE_OPEN_COMMON);

   if(db==INVALID_HANDLE)//Checks if 'Calendar' failed to be opened
     {
      if(!FileIsExist(NEWS_DATABASE_FILE,FILE_COMMON))//Checks if 'Calendar' database exists
        {
         Print("Could not find Database!");
         return 0;//Will return the earliest date which is 1970.01.01 00:00:00
        }
     }
   string latest_record="1970.01.01";//string variable with the first/earliest possible date in MQL5
//Sql query to determine the lastest or maximum recorded time from which the database was updated.
   string request_text="SELECT REPLACE(Date,'-','.') FROM 'Record'";
   int request=DatabasePrepare(db,request_text);
   if(request==INVALID_HANDLE)
     {
      Print("DB: ",NEWS_DATABASE_FILE, " request failed with code ", GetLastError());
      DatabaseClose(db);//Close Database
      return 0;
     }
   if(DatabaseRead(request))//Will read the one record in the 'Record' table
     {
      //-- Will assign the first column(column 0) value to the variable 'latest_record'
      if(!DatabaseColumnText(request,0,latest_record))
        {
         Print("DatabaseRead() failed with code ", GetLastError());
         DatabaseFinalize(request);//Finalize request
         DatabaseClose(db);//Closes the database 'Calendar'
         return D'1970.01.01';//Will end the for loop and will return the earliest date which is 1970.01.01 00:00:00
        }
     }
   DatabaseFinalize(request);
   DatabaseClose(db);//Closes the database 'Calendar'
   return (datetime)latest_record;//Returns the string latest_record converted to datetime
  }

//+------------------------------------------------------------------+
//|Function will determine Broker DST                                |
//+------------------------------------------------------------------+
bool CNews::AutoDetectDST(DST_type &dstType)
  {
   MqlCalendarValue values[];//Single array of MqlCalendarValue type
   string eventtime[];//Single string array variable to store NFP(Nonfarm Payrolls) dates for the 'United States' from the previous year
//-- Will store the previous year into an integer
   int lastyear = Time.ReturnYear(Time.TimeMinusOffset(iTime(Symbol(),PERIOD_CURRENT,0),Time.YearsS()));
//-- Will store the start date for the previous year
   datetime lastyearstart = StringToTime(StringFormat("%s.01.01 00:00:00",(string)lastyear));
//-- Will store the end date for the previous year
   datetime lastyearend = StringToTime(StringFormat("%s.12.31 23:59:59",(string)lastyear));
//-- Getting last year's calendar values for CountryCode = 'US'
   if(CalendarValueHistory(values,lastyearstart,lastyearend,"US"))
     {
      for(int x=0; x<(int)ArraySize(values); x++)
        {
         if(values[x].event_id==840030016)//Get only NFP Event Dates
           {
            ArrayResize(eventtime,eventtime.Size()+1,eventtime.Size()+2);//Increasing the size of eventtime array by 1
            eventtime[eventtime.Size()-1] = TimeToString(values[x].time);//Storing the dates in an array of type string
           }
        }
     }
//-- datetime variables to store the broker's timezone shift(change)
   datetime ShiftStart=D'1970.01.01 00:00:00',ShiftEnd=D'1970.01.01 00:00:00';
   string   EURUSD="";//String variables declarations for working with EURUSD
   bool     EurusdIsFound=false;//Boolean variables declarations for working with EURUSD
   for(int i=0;i<SymbolsTotal(true);i++)//Will loop through all the Symbols inside the Market Watch
     {
      string SymName = SymbolName(i,true);//Assign the Symbol Name of index 'i' from the list of Symbols inside the Market Watch
      //-- Check if the Symbol outside the Market Watch has a SYMBOL_CURRENCY_BASE of EUR
      //-- and a SYMBOL_CURRENCY_PROFIT of USD, and this Symbol is not a Custom Symbol(Is not from the broker)
      if(((CurrencyBase(SymName)=="EUR"&&CurrencyProfit(SymName)=="USD")||
          (StringFind(SymName,"EUR")>-1&&CurrencyProfit(SymName)=="USD"))&&!Custom(SymName))
        {
         EURUSD = SymName;//Assigning the name of the EURUSD Symbol found inside the Market Watch
         EurusdIsFound = true;//EURUSD Symbol was found in the Trading Terminal for your Broker
         break;//Will end the for loop
        }
     }
   if(!EurusdIsFound)//Check if EURUSD Symbol was already Found in the Market Watch
     {
      for(int i=0; i<SymbolsTotal(false); i++)//Will loop through all the available Symbols outside the Market Watch
        {
         string SymName = SymbolName(i,false);//Assign the Symbol Name of index 'i' from the list of Symbols outside the Market Watch
         //-- Check if the Symbol outside the Market Watch has a SYMBOL_CURRENCY_BASE of EUR
         //-- and a SYMBOL_CURRENCY_PROFIT of USD, and this Symbol is not a Custom Symbol(Is not from the broker)
         if(((CurrencyBase(SymName)=="EUR"&&CurrencyProfit(SymName)=="USD")||
             (StringFind(SymName,"EUR")>-1&&CurrencyProfit(SymName)=="USD"))&&!Custom(SymName))
           {
            EURUSD = SymName;//Assigning the name of the EURUSD Symbol found outside the Market Watch
            EurusdIsFound = true;//EURUSD Symbol was found in the Trading Terminal for your Broker
            break;//Will end the for loop
           }
        }
     }
   if(!EurusdIsFound)//Check if EURUSD Symbol was Found in the Trading Terminal for your Broker
     {
      Print("Cannot Find EURUSD!");
      Print("Cannot Create Database!");
      Print("Server DST Cannot be Detected!");
      dstType = DST_NONE;//Assigning enumeration value DST_NONE, Broker has no DST(Daylight Savings Time)
      return false;//Returning False, Broker's DST schedule was not found
     }

   struct DST
     {
      bool           result;
      datetime       date;
     } previousresult,currentresult;

   bool timeIsShifted;//Boolean variable declaration will be used to determine if the broker changes it's timezone
   for(uint i=0;i<eventtime.Size();i++)
     {
      //-- Store the result of if the eventdate is the larger candlestick
      currentresult.result = IsLargerThanPreviousAndNext((datetime)eventtime[i],Time.HoursS(),EURUSD);
      currentresult.date = (datetime)eventtime[i];//Store the eventdate from eventtime[i]
      //-- Check if there is a difference between the previous result and the current result
      timeIsShifted = ((currentresult.result!=previousresult.result&&i>0)?true:false);

      //-- Check if the Larger candle has shifted from the previous event date to the current event date in eventtime[i] array
      if(timeIsShifted)
        {
         if(ShiftStart==D'1970.01.01 00:00:00')//Check if the ShiftStart variable has not been assigned a relevant value yet
           {
            ShiftStart=currentresult.date;//Store the eventdate for when the timeshift began
           }
         ShiftEnd=previousresult.date;//Store the eventdate timeshift
        }
      previousresult.result = currentresult.result;//Store the previous result of if the eventdate is the larger candlestick
      previousresult.date = currentresult.date;//Store the eventdate from eventtime[i]
     }
//-- Check if the ShiftStart variable has not been assigned a relevant value and the eventdates are more than zero
   if(ShiftStart==D'1970.01.01 00:00:00'&&eventtime.Size()>0)
     {
      Print("Broker ServerTime unchanged!");
      dstType = DST_NONE;//Assigning enumeration value DST_NONE, Broker has no DST(Daylight Savings Time)
      return true;//Returning True, Broker's DST schedule was found successfully
     }

   datetime DaylightStart,DaylightEnd;//Datetime variables declarations for start and end dates for DaylightSavings
   if(Savings_AU.DaylightSavings(lastyear,DaylightStart,DaylightEnd))
     {
      if(Time.DateIsInRange(DaylightStart,DaylightEnd,ShiftStart,ShiftEnd))
        {
         Print("Broker ServerTime Adjusted For AU DST");
         dstType = DST_AU;//Assigning enumeration value AU_DST, Broker has AU DST(Daylight Savings Time)
         return true;//Returning True, Broker's DST schedule was found successfully
        }
     }
   else
     {
      Print("Something went wrong!");
      Print("Cannot Find Daylight-Savings Date For AU");
      Print("Year: %d Cannot Be Found!",lastyear);
      dstType = DST_NONE;//Assigning enumeration value DST_NONE, Broker has no DST(Daylight Savings Time)
      return false;//Returning False, Broker's DST schedule was not found
     }

   if(Savings_UK.DaylightSavings(lastyear,DaylightStart,DaylightEnd))
     {
      if(Time.DateIsInRange(DaylightStart,DaylightEnd,ShiftStart,ShiftEnd))
        {
         Print("Broker ServerTime Adjusted For UK DST");
         dstType = DST_UK;//Assigning enumeration value UK_DST, Broker has UK/EU DST(Daylight Savings Time)
         return true;//Returning True, Broker's DST schedule was found successfully
        }
     }
   else
     {
      Print("Something went wrong!");
      Print("Cannot Find Daylight-Savings Date For UK");
      Print("Year: %d Cannot Be Found!",lastyear);
      dstType = DST_NONE;//Assigning enumeration value DST_NONE, Broker has no DST(Daylight Savings Time)
      return false;//Returning False, Broker's DST schedule was not found
     }

   if(Savings_US.DaylightSavings(lastyear,DaylightStart,DaylightEnd))
     {
      if(Time.DateIsInRange(DaylightStart,DaylightEnd,ShiftStart,ShiftEnd))
        {
         Print("Broker ServerTime Adjusted For US DST");
         dstType = DST_US;//Assigning enumeration value US_DST, Broker has US DST(Daylight Savings Time)
         return true;//Returning True, Broker's DST schedule was found successfully
        }
     }
   else
     {
      Print("Something went wrong!");
      Print("Cannot Find Daylight-Savings Date For US");
      Print("Year: %d Cannot Be Found!",lastyear);
      dstType = DST_NONE;//Assigning enumeration value DST_NONE, Broker has no DST(Daylight Savings Time)
      return false;//Returning False, Broker's DST schedule was not found
     }
   Print("Cannot Detect Broker ServerTime Configuration!");
   dstType = DST_NONE;//Assigning enumeration value DST_NONE, Broker has no DST(Daylight Savings Time)
   return false;//Returning False, Broker's DST schedule was not found
  }
//+------------------------------------------------------------------+
