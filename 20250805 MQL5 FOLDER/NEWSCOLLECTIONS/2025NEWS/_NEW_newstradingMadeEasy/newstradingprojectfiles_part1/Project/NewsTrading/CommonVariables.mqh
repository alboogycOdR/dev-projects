//+------------------------------------------------------------------+
//|                                                      NewsTrading |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
string broker=AccountInfoString(ACCOUNT_COMPANY);//Getting brokers name via AccountInfoString
int Str = StringReplace(broker," ","");//Removing or replacing any spaces in the broker's name with an empty string
int Str1 = StringReplace(broker,".","");//Removing or replacing any dots in the broker's name with an empty string
int Str2 = StringReplace(broker,",","");//Removing or replacing any commas in the broker's name with an empty string
#define BROKER_NAME                    broker//Broker's Name
#define NEWS_TRADING_FOLDER            "NewsTrading"//Name of main folder in common/files
#define NEWS_CALENDAR_FOLDER           StringFormat("%s\\NewsCalendar",NEWS_TRADING_FOLDER)//name of subfolder in NewsTrading
#define NEWS_CALENDAR_BROKER_FOLDER    StringFormat("%s\\%s",NEWS_CALENDAR_FOLDER,BROKER_NAME)//Name of subfolder in NewsCalendar
#define NEWS_DATABASE_FILE             StringFormat("%s\\Calendar.sqlite",NEWS_CALENDAR_BROKER_FOLDER)//Name of sqlite file in subfolder in "Broker's Name"
#define NEWS_TEXT_FILE                 StringFormat("%s\\CalendarOpen.txt",NEWS_CALENDAR_BROKER_FOLDER)//Name of text file to indicate Calendar is open.

struct Calendar
  {
   ulong             EventId;//Event Id
   string            CountryName;//Event Country
   string            EventName;//Event Name
   string            EventType;//Event Type
   string            EventImportance;//Event Importance
   string            EventDate;//Event Date
   string            EventCurrency;//Event Currency
   string            EventCode;//Event Code
   string            EventSector;//Event Sector
   string            EventForecast;//Event Forecast Value
   string            EventPreval;//Event Previous Value
   string            EventImpact;//Event Impact
   string            EventFrequency;//Event Frequency
  };

enum DST_type
  {
   US_DST,//US Daylight Savings
   UK_DST,//UK(EU) Daylight Savings
   AU_DST,//AU Daylight Savings
   DST_NONE//No Daylight Savings Available
  };
//+------------------------------------------------------------------+
