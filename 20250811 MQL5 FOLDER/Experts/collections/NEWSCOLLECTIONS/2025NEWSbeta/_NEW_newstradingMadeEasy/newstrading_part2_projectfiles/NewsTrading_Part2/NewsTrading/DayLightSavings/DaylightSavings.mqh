//+------------------------------------------------------------------+
//|                                                      NewsTrading |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                            https://www.mql5.com/en/users/kaaiblo |
//+------------------------------------------------------------------+

#include <Object.mqh>
#include <Arrays\ArrayObj.mqh>
#include "../TimeManagement.mqh"

//+------------------------------------------------------------------+
//|DaylightSavings class                                             |
//+------------------------------------------------------------------+
class CDaylightSavings: public CObject
  {

protected:
   CTimeManagement   Time;
                     CDaylightSavings(datetime startdate,datetime enddate);
   CObject           *List() { return savings;}//Gets the list of Daylightsavings time
   datetime          StartDate;
   datetime          EndDate;
   CArrayObj         *savings;
   CArrayObj         *getSavings;
   CDaylightSavings      *dayLight;
   virtual void      SetDaylightSavings_UK();//Initialize UK Daylight Savings Dates into List
   virtual void      SetDaylightSavings_US();//Initialize US Daylight Savings Dates into List
   virtual void      SetDaylightSavings_AU();//Initialize AU Daylight Savings Dates into List

public:
                     CDaylightSavings(void);
                    ~CDaylightSavings(void);
   bool              isDaylightSavings(datetime Date);//This function checks if a given date falls within Daylight Savings Time.
   bool              DaylightSavings(int Year,datetime &startDate,datetime &endDate);//Check if DaylightSavings Dates are available for a certain Year
   string            adjustDaylightSavings(datetime EventDate);//Will adjust the date's timezone depending on DaylightSavings
  };


//+------------------------------------------------------------------+
//|Constructor                                                       |
//+------------------------------------------------------------------+
CDaylightSavings::CDaylightSavings(void)
  {
  }

//+------------------------------------------------------------------+
//|Initialize variables                                              |
//+------------------------------------------------------------------+
CDaylightSavings::CDaylightSavings(datetime startdate,datetime enddate)
  {
   StartDate = startdate;//Assign class's global variable StartDate value from parameter variable startdate
   EndDate = enddate;//Assign class's global variable EndDate value from parameter variable enddate
  }

//+------------------------------------------------------------------+
//|checks if a given date falls within Daylight Savings Time         |
//+------------------------------------------------------------------+
bool CDaylightSavings::isDaylightSavings(datetime Date)
  {
// Initialize a list to store daylight savings periods.
   getSavings = List();
// Iterate through all the periods in the list.
   for(int i=0; i<getSavings.Total(); i++)
     {
      // Access the current daylight savings period.
      dayLight = getSavings.At(i);
      // Check if the given date is within the current daylight savings period.
      if(Time.DateIsInRange(dayLight.StartDate,dayLight.EndDate,Date))
        {
         // If yes, return true indicating it is daylight savings time.
         return true;
        }
     }
// If no period matches, return false indicating it is not daylight savings time.
   return false;
  }

//+------------------------------------------------------------------+
//|Check if DaylightSavings Dates are available for a certain Year   |
//+------------------------------------------------------------------+
bool CDaylightSavings::DaylightSavings(int Year,datetime &startDate,datetime &endDate)
  {
// Initialize a list to store daylight savings periods.
   getSavings = List();
   bool startDateDetected=false,endDateDetected=false;
// Iterate through all the periods in the list.
   for(int i=0; i<getSavings.Total(); i++)
     {
      dayLight = getSavings.At(i);
      if(Year==Time.ReturnYear(dayLight.StartDate))//Check if a certain year's date is available within the DaylightSavings start dates in the List
        {
         startDate = dayLight.StartDate;
         startDateDetected = true;
        }
      if(Year==Time.ReturnYear(dayLight.EndDate))//Check if a certain year's date is available within the DaylightSavings end dates in the List
        {
         endDate = dayLight.EndDate;
         endDateDetected = true;
        }
      if(startDateDetected&&endDateDetected)//Check if both DaylightSavings start and end dates are found for a certain Year
        {
         return true;
        }
     }

   startDate = D'1970.01.01 00:00:00';//Set a default start date if no DaylightSaving date is found
   endDate = D'1970.01.01 00:00:00';//Set a default end date if no DaylightSaving date is found
   return false;
  }

//+------------------------------------------------------------------+
//|Will adjust the date's timezone depending on DaylightSavings      |
//+------------------------------------------------------------------+
string CDaylightSavings::adjustDaylightSavings(datetime EventDate)
  {
   if(isDaylightSavings(TimeTradeServer()))//Check if the current tradeserver time is already within the DaylightSavings Period
     {
      if(isDaylightSavings(EventDate))//Checks if the event time is during daylight savings
        {
         return TimeToString(EventDate);//normal event time
        }
      else
        {
         return TimeToString((datetime)(EventDate-Time.HoursS()));//event time minus an hour for DST
        }
     }
   else
     {
      if(isDaylightSavings(EventDate))//Checks if the event time is during daylight savings
        {
         return TimeToString((datetime)(Time.HoursS()+EventDate));//event time plus an hour for DST
        }
      else
        {
         return TimeToString(EventDate);//normal event time
        }
     }
  }

//+------------------------------------------------------------------+
//|Destructor                                                        |
//+------------------------------------------------------------------+
CDaylightSavings::~CDaylightSavings(void)
  {
   delete savings;//Delete CArrayObj Pointer
   delete dayLight;//Delete CDaylightSavings Pointer
   delete getSavings;//Delete CArrayObj Pointer
  }
//+------------------------------------------------------------------+
