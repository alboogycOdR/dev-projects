//+------------------------------------------------------------------+
//|                                                      NewsTrading |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#include "TimeManagement.mqh"
#include "CommonVariables.mqh"
#include "DayLightSavings/DaylightSavings_UK.mqh"
#include "DayLightSavings/DaylightSavings_US.mqh"
#include "DayLightSavings/DaylightSavings_AU.mqh"
#include "CandleProperties.mqh"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CNews
  {
   //Private Declarations Only accessable by this class/header file
private:
   CTimeManagement   Time;//TimeManagement Object declaration
   CDaylightSavings_UK  Savings_UK;//DaylightSavings Object for the UK and EU
   CDaylightSavings_US  Savings_US;//DaylightSavings Object for the US
   CDaylightSavings_AU  Savings_AU;//DaylightSavings Object for the AU
   CCandleProperties Candle;//CandleProperties Object
   string            CurrencyBase,CurrencyProfit,EURUSD;//String variables declarations for working with EURUSD
   bool              EurusdIsSelected,EurusdIsFound,is_Custom;//Boolean variables declarations for working with EURUSD
   bool              timeIsShifted;//Boolean variable declaration will be used to determine if the broker changes it's timezone
   datetime          DaylightStart,DaylightEnd;//Datetime variables declarations for start and end dates for DaylightSavings
   //Structure Declaration for DST
   struct DST
     {
      bool           result;
      datetime       date;
     };
   bool              AutoDetectDST(DST_type &dstType);//Function will determine Broker DST
   DST_type          DSTType;//variable of DST_type enumeration declared in the CommonVariables class/header file
   bool              InsertIntoTable(int db,DST_type Type,Calendar &Evalues[]);//Function for inserting Economic Data in to a database's table
   void              CreateAutoDST(int db);//Function for creating and inserting Recommend DST for the Broker into a table
   bool              CreateTable(int db,string tableName,bool &tableExists);//Function for creating a table in a database
   void              CreateRecords(int db);//Creates a table to store records of when last the Calendar database was updated/created
   bool              UpdateRecords();//Checks if the main Calendar database needs an update or not
   void              EconomicDetails(Calendar &NewsTime[]);//Gets values from the MQL5 economic Calendar

   //Public declarations accessable via a class's Object
public:
                    ~CNews(void);//Deletes a text file created when the Calendar database is being worked on
   void              CreateEconomicDatabase();//Creates the Calendar database for a specific Broker
   datetime          GetLastestNewsDate();//Gets the lastest/newest date in the Calendar database
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CNews::~CNews(void)
  {
   if(FileIsExist(NEWS_TEXT_FILE,FILE_COMMON))//Check if the news database open text file exists
     {
      FileDelete(NEWS_TEXT_FILE,FILE_COMMON);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CNews::EconomicDetails(Calendar &NewsTime[])
  {
   int Size=0;//to keep track of the size of the events in the NewsTime array
   MqlCalendarCountry countries[];
   int count=CalendarCountries(countries);//Get the array of country names available in the Calendar
   string Country_code="";

   for(int i=0; i<count; i++)
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
               NewsTime[Size].EventImportance = EnumToString(event.importance);//storing the event importance from (ENUM_CALENDAR_EVENT_IMPORTANCE) to a string
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

               NewsTime[Size].EventImpact =  EnumToString(values[x].impact_type);//storing the event impact from (ENUM_CALENDAR_EVENT_IMPACT) to a string
               NewsTime[Size].EventFrequency =  EnumToString(event.frequency);//storing the event frequency from (ENUM_CALENDAR_EVENT_FREQUENCY) to a string
               Size++;//incrementing the Calendar array NewsTime
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CNews::UpdateRecords()
  {
//--- open/create
   int db=DatabaseOpen(NEWS_DATABASE_FILE, DATABASE_OPEN_READONLY|DATABASE_OPEN_COMMON);//try to open database Calendar

   if(db==INVALID_HANDLE)//Checks if the database was able to be opened
     {
      //if opening the database failed
      if(!FileIsExist(NEWS_DATABASE_FILE,FILE_COMMON))//Checks if the database Calendar exists in the common folder
        {
         return true;//Returns true when the database was failed to be opened and the file doesn't exist in the common folder
        }
     }

   if(!DatabaseTableExists(db,"Records"))//If the database table 'Records' doesn't exist
     {
      DatabaseClose(db);
      return true;
     }

   int recordtime=0;//will store the maximum date recorded in the database table 'Records'
   string request_text="SELECT MAX(RECORDEDTIME) FROM Records";//Sql query to determine the lastest or maximum date recorded
   int request=DatabasePrepare(db,request_text);//Creates a handle of a request, which can then be executed using DatabaseRead()
   if(request==INVALID_HANDLE)//Checks if the request failed to be completed
     {
      Print("DB: ",NEWS_DATABASE_FILE, " request failed with code ", GetLastError());
      DatabaseClose(db);
      return true;
     }

   for(int i=0; DatabaseRead(request); i++)//Will read all the results from the sql query/request
     {
      if(!DatabaseColumnInteger(request, 0, recordtime))//Will assign the first column value to the variable 'recordtime'
        {
         Print(i, ": DatabaseRead() failed with code ", GetLastError());
         DatabaseFinalize(request);//Removes a request created in DatabasePrepare()
         DatabaseClose(db);//Closes the database
         return true;
        }
     }

   DatabaseFinalize(request);//Removes a request created in DatabasePrepare()
   DatabaseClose(db);//Closes the database

   if(!Time.DateisToday((datetime)recordtime))//Checks if the recorded time/date is today(current day)
     {
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CNews::CreateEconomicDatabase()
  {
   Print("Please wait...");

   if(FileIsExist(NEWS_DATABASE_FILE,FILE_COMMON))//Check if the database exists
     {
      if(!UpdateRecords())//Check if the database is up to date
        {
         return;//will terminate execution of the rest of the code below
        }
     }
   else
     {
      if(!AutoDetectDST(DSTType))//Check if AutoDetectDST went through all the right procedures
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
   datetime lastestdate=D'1970.01.01 00:00:00';
//--- open/create the database 'Calendar'
   int db=DatabaseOpen(NEWS_DATABASE_FILE, DATABASE_OPEN_READWRITE | DATABASE_OPEN_CREATE| DATABASE_OPEN_COMMON);//will try to open/create in the common folder

   if(db==INVALID_HANDLE)//Checks if the database 'Calendar' failed to open/create
     {
      Print("DB: ",NEWS_DATABASE_FILE, " open failed with code ", GetLastError());
      return;//will terminate execution of the rest of the code below
     }
   else
     {
      file=FileOpen(NEWS_TEXT_FILE,FILE_WRITE|FILE_ANSI|FILE_TXT|FILE_COMMON);//try to create a text file 'NewsDatabaseOpen' in common folder
      if(file==INVALID_HANDLE)
        {
         DatabaseClose(db);//Closes the database 'Calendar' if the News text file failed to be created
         return;//will terminate execution of the rest of the code below
        }
     }

   DatabaseTransactionBegin(db);//Starts transaction execution
   Print("Please wait...");

//-- attempt to create the calendar tables
   if(!CreateTable(db,"None",tableExists)||!CreateTable(db,"US",tableExists)
      ||!CreateTable(db,"UK",tableExists)||!CreateTable(db,"AU",tableExists))
     {
      FileClose(file);//Closing the file 'NewsDatabaseOpen.txt'
      FileDelete(NEWS_TEXT_FILE,FILE_COMMON);//Deleting the file 'NewsDatabaseOpen.txt'
      return;//
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
   if(!InsertIntoTable(db,DST_NONE,Evalues)||!InsertIntoTable(db,US_DST,Evalues)
      ||!InsertIntoTable(db,UK_DST,Evalues)||!InsertIntoTable(db,AU_DST,Evalues))
     {
      failed=true;//Will assign true if inserting economic vaules failed in any of the Data tables
     }

   if(failed)//Checks if the event/s failed to be recorded/inserted into the database table 'Data_%s'
     {
      //--- roll back all transactions and unlock the database
      DatabaseTransactionRollback(db);
      PrintFormat("%s: DatabaseExecute() failed with code %d", __FUNCTION__, GetLastError());
      FileClose(file);//Close the text file 'NEWS_TEXT_FILE'
      FileDelete(NEWS_TEXT_FILE,FILE_COMMON);//Delete the text file, as we are reverted/rolled-back the database
      ArrayRemove(Evalues,0,WHOLE_ARRAY);//Removes the values in the array

     }
   else//if all the events were recorded or inserted into the tables 'Data_%s'
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

      CreateRecords(db);//Will create the 'Records' table and insert the  current time
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
//|                                                                  |
//+------------------------------------------------------------------+
bool CNews::CreateTable(int db,string tableName,bool &tableExists)
  {
   if(DatabaseTableExists(db,StringFormat("Data_%s",tableName)))//Checks if a table 'Data_%s' exists in the database 'Calendar'
     {
      tableExists=true;//Assigns true to tableExists variable

      if(!DatabaseExecute(db,StringFormat("DROP TABLE Data_%s",tableName)))//We will drop the table if the table already exists
        {
         //If the table failed to be dropped/deleted
         PrintFormat("Failed to drop table Data_%s with code %d",tableName,GetLastError());
         DatabaseClose(db);//Close the database
         return false;//will terminate execution of the rest of the code below and return false, when the table cannot be dropped
        }
     }

   if(!DatabaseTableExists(db,StringFormat("Data_%s",tableName)))//If the database table 'Data_%s' doesn't exist
     {
      //--- create the table 'Data' with the following columns
      if(!DatabaseExecute(db,StringFormat("CREATE TABLE Data_%s("
                                          "ID INT NOT NULL,"
                                          "EVENTID  INT   NOT NULL,"
                                          "COUNTRY  STRING   NOT NULL,"
                                          "EVENTNAME   STRING   NOT NULL,"
                                          "EVENTTYPE   STRING   NOT NULL,"
                                          "EVENTIMPORTANCE   STRING   NOT NULL,"
                                          "EVENTDATE   STRING   NOT NULL,"
                                          "EVENTCURRENCY  STRING   NOT NULL,"
                                          "EVENTCODE   STRING   NOT NULL,"
                                          "EVENTSECTOR STRING   NOT NULL,"
                                          "EVENTFORECAST  STRING   NOT NULL,"
                                          "EVENTPREVALUE  STRING   NOT NULL,"
                                          "EVENTIMPACT STRING   NOT NULL,"
                                          "EVENTFREQUENCY STRING   NOT NULL,"
                                          "PRIMARY KEY(ID));",tableName)))//Checks if the table was successfully created
        {
         Print("DB: create the Calendar table failed with code ", GetLastError());
         DatabaseClose(db);//Close the database
         return false;//Function returns false if creating the table failed
        }
     }
   return true;//Function returns true if creating the table was successful
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CNews::InsertIntoTable(int db,DST_type Type,Calendar &Evalues[])
  {
   string tableName;//will store the table name suffix
   for(uint i=0; i<Evalues.Size(); i++)//Looping through all the Economic Events
     {
      string Date;//Will store the date for the economic event
      switch(Type)//Switch statement to check all possible 'case' scenarios for the variable Type
        {
         case DST_NONE://if(Type==DST_NONE) then run code below
            Date = Evalues[i].EventDate;//Assign the normal Economic EventDate
            tableName = "None";//Full table name will be 'Data_None'
            break;//End switch statement
         case US_DST://if(Type==US_DST) then run code below
            Savings_US.adjustDaylightSavings(StringToTime(Evalues[i].EventDate),Date);//Assign by Reference the Economic EventDate adjusted for US DST(Daylight Savings Time)
            tableName = "US";//Full table name will be 'Data_US'
            break;//End switch statement
         case UK_DST://if(Type==UK_DST) then run code below
            Savings_UK.adjustDaylightSavings(StringToTime(Evalues[i].EventDate),Date);//Assign by Reference the Economic EventDate adjusted for UK DST(Daylight Savings Time)
            tableName = "UK";//Full table name will be 'Data_UK'
            break;//End switch statement
         case AU_DST://if(Type==AU_DST) then run code below
            Savings_AU.adjustDaylightSavings(StringToTime(Evalues[i].EventDate),Date);//Assign by Reference the Economic EventDate adjusted for AU DST(Daylight Savings Time)
            tableName = "AU";//Full table name will be 'Data_AU'
            break;//End switch statement
         default://if(Type==(Unknown value)) then run code below
            Date = Evalues[i].EventDate;//Assign the normal Economic EventDate
            tableName = "None";//Full table name will be 'Data_None'
            break;//End switch statement
        }

      string request_text =
         StringFormat("INSERT INTO 'Data_%s'(ID,EVENTID,COUNTRY,EVENTNAME,EVENTTYPE,EVENTIMPORTANCE,EVENTDATE,EVENTCURRENCY,EVENTCODE,"
                      "EVENTSECTOR,EVENTFORECAST,EVENTPREVALUE,EVENTIMPACT,EVENTFREQUENCY)"
                      "VALUES (%d,%d,'%s','%s', '%s', '%s', '%s','%s','%s','%s','%s','%s','%s','%s')",
                      tableName,
                      i,
                      Evalues[i].EventId,
                      Evalues[i].CountryName,
                      Evalues[i].EventName,
                      Evalues[i].EventType,
                      Evalues[i].EventImportance,
                      Date,
                      Evalues[i].EventCurrency,
                      Evalues[i].EventCode,
                      Evalues[i].EventSector,
                      Evalues[i].EventForecast,
                      Evalues[i].EventPreval,
                      Evalues[i].EventImpact,
                      Evalues[i].EventFrequency);//Inserting all the columns for each event record

      if(!DatabaseExecute(db, request_text))//Checks whether the event was inserted into the table 'Data_%s'
        {
         Print(GetLastError());
         PrintFormat("INSERT INTO 'Data_%s'(ID,EVENTID,COUNTRY,EVENTNAME,EVENTTYPE,EVENTIMPORTANCE,EVENTDATE,EVENTCURRENCY,EVENTCODE,"
                      "EVENTSECTOR,EVENTFORECAST,EVENTPREVALUE,EVENTIMPACT,EVENTFREQUENCY)"
                      "VALUES (%d,%d,'%s','%s', '%s', '%s', '%s','%s','%s','%s','%s','%s','%s','%s')",
                      tableName,
                      i,
                      Evalues[i].EventId,
                      Evalues[i].CountryName,
                      Evalues[i].EventName,
                      Evalues[i].EventType,
                      Evalues[i].EventImportance,
                      Date,
                      Evalues[i].EventCurrency,
                      Evalues[i].EventCode,
                      Evalues[i].EventSector,
                      Evalues[i].EventForecast,
                      Evalues[i].EventPreval,
                      Evalues[i].EventImpact,
                      Evalues[i].EventFrequency);//Will print the sql query to check for any errors or possible defaults in the query/request

         return false;//Will end the loop and return false, as values failed to be inserted into the table
        }
     }
   return true;//Will return true, all values were inserted into the table successfully
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CNews::CreateRecords(int db)
  {
   bool failed=false;

   if(!DatabaseTableExists(db,"Records"))//Checks if the table 'Records' exists in the databse 'Calendar'
     {
      //--- create the table
      if(!DatabaseExecute(db,"CREATE TABLE Records(RECORDEDTIME INT NOT NULL);"))//Will attempt to create the table 'Records'
        {
         Print("DB: create the Records table failed with code ", GetLastError());
         DatabaseClose(db);//Close the database
         return;//Exits the function if creating the table failed
        }
     }

//Sql query/request to insert the current time into the 'RECORDEDTIME' column in the table 'Records'
   string request_text=StringFormat("INSERT INTO 'Records'(RECORDEDTIME) VALUES (%d)",(int)TimeCurrent());

   if(!DatabaseExecute(db, request_text))//Will attempt to run this sql request/query
     {
      Print(GetLastError());
      PrintFormat("INSERT INTO 'Records'(RECORDEDTIME) VALUES (%d)",(int)TimeCurrent());
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
//|                                                                  |
//+------------------------------------------------------------------+
void CNews::CreateAutoDST(int db)
  {
   bool failed=false;//boolean variable

   if(!DatabaseTableExists(db,"AutoDST"))//Checks if the table 'AutoDST' exists in the databse 'Calendar'
     {
      //--- create the table AutoDST
      if(!DatabaseExecute(db,"CREATE TABLE AutoDST(DST STRING NOT NULL);"))//Will attempt to create the table 'AutoDST'
        {
         Print("DB: create the AutoDST table failed with code ", GetLastError());
         DatabaseClose(db);//Close the database
         return;//Exits the function if creating the table failed
        }
     }
   else
     {
      return;//Exits the function if the table AutoDST table already exists
     }

//Sql query/request to insert the recommend DST for the Broker using the DSTType variable to determine which string data to insert
   string request_text=StringFormat("INSERT INTO 'AutoDST'(DST) VALUES ('%s')",((DSTType==US_DST)?"Data_US":
                                    (DSTType==UK_DST)?"Data_UK":(DSTType==AU_DST)?"Data_AU":"Data_None"));

   if(!DatabaseExecute(db, request_text))//Will attempt to run this sql request/query
     {
      Print(GetLastError());
      PrintFormat("INSERT INTO 'AutoDST'(DST) VALUES ('%s')",((DSTType==US_DST)?"Data_US":
                  (DSTType==UK_DST)?"Data_UK":(DSTType==AU_DST)?"Data_AU":"Data_None"));//Will print the sql query if failed
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
//|                                                                  |
//+------------------------------------------------------------------+
datetime CNews::GetLastestNewsDate()
  {
//--- open the database 'Calendar' in the common folder
   int db=DatabaseOpen(NEWS_DATABASE_FILE, DATABASE_OPEN_READONLY|DATABASE_OPEN_COMMON);

   if(db==INVALID_HANDLE)//Checks if 'Calendar' failed to be opened
     {

      if(!FileIsExist(NEWS_DATABASE_FILE,FILE_COMMON))//Checks if 'Calendar' database exists
        {
         return 0;//Will return the earliest date which is 1970.01.01 00:00:00
        }
     }

   string eventtime="1970.01.01 00:00:00";//string variable with the first/earliest possible date in MQL5
//Sql query to determine the lastest or maximum recorded time from which the database was updated.
   string request_text="SELECT MAX(RECORDEDTIME) FROM Records";
   int request=DatabasePrepare(db,request_text);

   if(request==INVALID_HANDLE)
     {

      Print("DB: ",NEWS_DATABASE_FILE, " request failed with code ", GetLastError());
      DatabaseClose(db);
      return true;

     }

   for(int i=0; DatabaseRead(request); i++)//Will read all the results from the sql query/request
     {
      if(!DatabaseColumnText(request, 0,eventtime))//Will assign the first column(column 0) value to the variable 'eventtime'
        {

         Print(i, ": DatabaseRead() failed with code ", GetLastError());
         DatabaseFinalize(request);//Finalize request
         DatabaseClose(db);//Closes the database 'Calendar'
         return 0;//Will end the for loop and will return the earliest date which is 1970.01.01 00:00:00
        }
     }

   DatabaseFinalize(request);
   DatabaseClose(db);//Closes the database 'Calendar'

   return StringToTime(eventtime);//Returns the string eventtime converted to datetime
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CNews::AutoDetectDST(DST_type &dstType)
  {
   MqlCalendarValue values[];//Single array of MqlCalendarValue type
   string eventtime[];//Single string array variable to store NFP(Nonfarm Payrolls) dates for the 'United States' from the previous year
   int lastyear = Time.ReturnYear(Time.TimeMinusOffset(iTime(Symbol(),PERIOD_CURRENT,0),Time.YearsS()));//Will store the previous year into an integer
   datetime lastyearstart = StringToTime(StringFormat("%s.01.01 00:00:00",(string)lastyear));//Will store the start date for the previous year
   datetime lastyearend = StringToTime(StringFormat("%s.12.31 23:59:59",(string)lastyear));//Will store the end date for the previous year

   if(CalendarValueHistory(values,lastyearstart,lastyearend,"US"))//Getting last year's calendar values for CountryCode = 'US'
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

   datetime ShiftStart=D'1970.01.01 00:00:00',ShiftEnd=D'1970.01.01 00:00:00';//datetime variables to store the broker's timezone shift(change)
   DST previousresult,currentresult;//Variables of structure type DST declared at the beginning of the class

   EURUSD="";//String variable assigned empty string
   EurusdIsSelected = false;//Boolean variable assigned value false
   EurusdIsFound = false;//Boolean variable assigned value false

   for(int i=0;i<SymbolsTotal(true);i++)//Will loop through all the Symbols inside the Market Watch
     {
      string SymName = SymbolName(i,true);//Assign the Symbol Name of index 'i' from the list of Symbols inside the Market Watch
      CurrencyBase = SymbolInfoString(SymName,SYMBOL_CURRENCY_BASE);//Assign the Symbol's Currency Base
      CurrencyProfit = SymbolInfoString(SymName,SYMBOL_CURRENCY_PROFIT);//Assign the Symbol's Currency Profit
      SymbolExist(SymName,is_Custom);//Get the boolean value into 'is_Custom' for whether the Symbol Name is a Custom Symbol(Is not from the broker)

      //-- Check if the Symbol outside the Market Watch has a SYMBOL_CURRENCY_BASE of EUR
      //-- and a SYMBOL_CURRENCY_PROFIT of USD, and this Symbol is not a Custom Symbol(Is not from the broker)
      if(CurrencyBase=="EUR"&&CurrencyProfit=="USD"&&!is_Custom)
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
         CurrencyBase = SymbolInfoString(SymName,SYMBOL_CURRENCY_BASE);
         CurrencyProfit = SymbolInfoString(SymName,SYMBOL_CURRENCY_PROFIT);
         SymbolExist(SymName,is_Custom);//Get the boolean value into 'is_Custom' for whether the Symbol Name is a Custom Symbol(Is not from the broker)

         //-- Check if the Symbol outside the Market Watch has a SYMBOL_CURRENCY_BASE of EUR
         //-- and a SYMBOL_CURRENCY_PROFIT of USD, and this Symbol is not a Custom Symbol(Is not from the broker)
         if(CurrencyBase=="EUR"&&CurrencyProfit=="USD"&&!is_Custom)
           {
            EurusdIsSelected = SymbolSelect(SymName,true);//Adding the EURUSD Symbol to the Market Watch
            if(EurusdIsSelected)//Check if this program added EURUSD Symbol to Market Watch
              {
               EURUSD = SymName;//Assigning the name of the EURUSD Symbol found outside the Market Watch
               EurusdIsFound = true;//EURUSD Symbol was found in the Trading Terminal for your Broker
               break;//Will end the for loop
              }
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

   for(uint i=0;i<eventtime.Size();i++)
     {
      currentresult.result = Candle.IsLargerThanPreviousAndNext((datetime)eventtime[i],Time.HoursS(),EURUSD);//Store the result of if the eventdate is the larger candlestick
      currentresult.date = (datetime)eventtime[i];//Store the eventdate from eventtime[i]
      timeIsShifted = ((currentresult.result!=previousresult.result&&i>0)?true:false);//Check if there is a difference between the previous result and the current result

      //--- Print Event Dates and if the event date's candle is larger than the previous candle an hour ago and the next candle an hour ahead
      Print("Date: ",eventtime[i]," is Larger: ",Candle.IsLargerThanPreviousAndNext((datetime)eventtime[i],Time.HoursS(),EURUSD)," Shifted: ",timeIsShifted);

      if(timeIsShifted)//Check if the Larger candle has shifted from the previous event date to the current event date in eventtime[i] array
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

   if(ShiftStart==D'1970.01.01 00:00:00'&&eventtime.Size()>0)//Check if the ShiftStart variable has not been assigned a relevant value and the eventdates are more than zero
     {
      Print("Broker ServerTime unchanged!");
      dstType = DST_NONE;//Assigning enumeration value DST_NONE, Broker has no DST(Daylight Savings Time)
      return true;//Returning True, Broker's DST schedule was found successfully
     }

   if(Savings_AU.DaylightSavings(lastyear,DaylightStart,DaylightEnd))
     {
      if(Time.DateIsInRange(DaylightStart,DaylightEnd,ShiftStart,ShiftEnd))
        {
         Print("Broker ServerTime Adjusted For AU DST");
         if(EurusdIsSelected)//Check if this program added EURUSD Symbol to Market Watch
           {
            SymbolSelect(EURUSD,false);//Remove EURUSD Symbol from Market Watch
           }
         dstType = AU_DST;//Assigning enumeration value AU_DST, Broker has AU DST(Daylight Savings Time)
         return true;//Returning True, Broker's DST schedule was found successfully
        }
     }
   else
     {
      Print("Something went wrong!");
      Print("Cannot Find Daylight-Savings Date For AU");
      Print("Year: %d Cannot Be Found!",lastyear);
      if(EurusdIsSelected)//Check if this program added EURUSD Symbol to Market Watch
        {
         SymbolSelect(EURUSD,false);//Remove EURUSD Symbol from Market Watch
        }
      dstType = DST_NONE;//Assigning enumeration value DST_NONE, Broker has no DST(Daylight Savings Time)
      return false;//Returning False, Broker's DST schedule was not found
     }

   if(Savings_UK.DaylightSavings(lastyear,DaylightStart,DaylightEnd))
     {
      if(Time.DateIsInRange(DaylightStart,DaylightEnd,ShiftStart,ShiftEnd))
        {
         Print("Broker ServerTime Adjusted For UK DST");
         if(EurusdIsSelected)//Check if this program added EURUSD Symbol to Market Watch
           {
            SymbolSelect(EURUSD,false);//Remove EURUSD Symbol from Market Watch
           }
         dstType = UK_DST;//Assigning enumeration value UK_DST, Broker has UK/EU DST(Daylight Savings Time)
         return true;//Returning True, Broker's DST schedule was found successfully
        }
     }
   else
     {
      Print("Something went wrong!");
      Print("Cannot Find Daylight-Savings Date For UK");
      Print("Year: %d Cannot Be Found!",lastyear);
      if(EurusdIsSelected)//Check if this program added EURUSD Symbol to Market Watch
        {
         SymbolSelect(EURUSD,false);//Remove EURUSD Symbol from Market Watch
        }
      dstType = DST_NONE;//Assigning enumeration value DST_NONE, Broker has no DST(Daylight Savings Time)
      return false;//Returning False, Broker's DST schedule was not found
     }

   if(Savings_US.DaylightSavings(lastyear,DaylightStart,DaylightEnd))
     {
      if(Time.DateIsInRange(DaylightStart,DaylightEnd,ShiftStart,ShiftEnd))
        {
         Print("Broker ServerTime Adjusted For US DST");
         if(EurusdIsSelected)//Check if this program added EURUSD Symbol to Market Watch
           {
            SymbolSelect(EURUSD,false);//Remove EURUSD Symbol from Market Watch
           }
         dstType = US_DST;//Assigning enumeration value US_DST, Broker has US DST(Daylight Savings Time)
         return true;//Returning True, Broker's DST schedule was found successfully
        }
     }
   else
     {
      Print("Something went wrong!");
      Print("Cannot Find Daylight-Savings Date For US");
      Print("Year: %d Cannot Be Found!",lastyear);
      if(EurusdIsSelected)//Check if this program added EURUSD Symbol to Market Watch
        {
         SymbolSelect(EURUSD,false);//Remove EURUSD Symbol from Market Watch
        }
      dstType = DST_NONE;//Assigning enumeration value DST_NONE, Broker has no DST(Daylight Savings Time)
      return false;//Returning False, Broker's DST schedule was not found
     }

   if(EurusdIsSelected)//Check if this program added EURUSD Symbol to Market Watch
     {
      SymbolSelect(EURUSD,false);//Remove EURUSD Symbol from Market Watch
     }
   Print("Cannot Detect Broker ServerTime Configuration!");
   dstType = DST_NONE;//Assigning enumeration value DST_NONE, Broker has no DST(Daylight Savings Time)
   return false;//Returning False, Broker's DST schedule was not found
  }
//+------------------------------------------------------------------+
