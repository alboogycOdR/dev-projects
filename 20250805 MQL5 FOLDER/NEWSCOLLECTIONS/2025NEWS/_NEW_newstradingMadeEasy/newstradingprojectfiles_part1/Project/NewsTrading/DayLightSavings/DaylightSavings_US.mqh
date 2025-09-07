//+------------------------------------------------------------------+
//|                                                      NewsTrading |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#include <Object.mqh>
#include <Arrays\ArrayObj.mqh>
#include "../TimeManagement.mqh"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CDaylightSavings_US:CObject
  {

private:

   CTimeManagement   Time;
                     CDaylightSavings_US(datetime startdate,datetime enddate);
   CObject           *List() { return savings;}//Gets the list of Daylightsavings time
   datetime          StartDate;
   datetime          EndDate;
   CArrayObj         *savings;
   CArrayObj         *getSavings;
   CDaylightSavings_US      *dayLight;

public:

                     CDaylightSavings_US(void);
                    ~CDaylightSavings_US(void);
   bool              isDaylightSavings(datetime Date);//This function checks if a given date falls within Daylight Savings Time.
   bool              DaylightSavings(int Year,datetime &startDate,datetime &endDate);//Check if DaylightSavings Dates are available for a certain Year
   void              adjustDaylightSavings(datetime EventDate,string &AdjustedDate);//Will adjust the date's timezone depending on DaylightSavings
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CDaylightSavings_US::CDaylightSavings_US(void)
  {
   savings = new CArrayObj();
//Daylight savings dates to readjust dates in the database for accurate testing in the strategy tester
   savings.Add(new CDaylightSavings_US(D'2007.03.11 03:00:00',D'2007.11.04 01:00:00'));
   savings.Add(new CDaylightSavings_US(D'2008.03.09 03:00:00',D'2008.11.02 01:00:00'));
   savings.Add(new CDaylightSavings_US(D'2009.03.08 03:00:00',D'2009.11.01 01:00:00'));
   savings.Add(new CDaylightSavings_US(D'2010.03.14 03:00:00',D'2010.11.07 01:00:00'));
   savings.Add(new CDaylightSavings_US(D'2011.03.13 03:00:00',D'2011.11.06 01:00:00'));
   savings.Add(new CDaylightSavings_US(D'2012.03.11 03:00:00',D'2012.11.04 01:00:00'));
   savings.Add(new CDaylightSavings_US(D'2013.03.10 03:00:00',D'2013.11.03 01:00:00'));
   savings.Add(new CDaylightSavings_US(D'2014.03.09 03:00:00',D'2014.11.02 01:00:00'));
   savings.Add(new CDaylightSavings_US(D'2015.03.08 03:00:00',D'2015.11.01 01:00:00'));
   savings.Add(new CDaylightSavings_US(D'2016.03.13 03:00:00',D'2016.11.06 01:00:00'));
   savings.Add(new CDaylightSavings_US(D'2017.03.12 03:00:00',D'2017.11.05 01:00:00'));
   savings.Add(new CDaylightSavings_US(D'2018.03.11 03:00:00',D'2018.11.04 01:00:00'));
   savings.Add(new CDaylightSavings_US(D'2019.03.10 03:00:00',D'2019.11.03 01:00:00'));
   savings.Add(new CDaylightSavings_US(D'2020.03.08 03:00:00',D'2020.11.01 01:00:00'));
   savings.Add(new CDaylightSavings_US(D'2021.03.14 03:00:00',D'2021.11.07 01:00:00'));
   savings.Add(new CDaylightSavings_US(D'2022.03.13 03:00:00',D'2022.11.06 01:00:00'));
   savings.Add(new CDaylightSavings_US(D'2023.03.12 03:00:00',D'2023.11.05 01:00:00'));
   savings.Add(new CDaylightSavings_US(D'2024.03.10 03:00:00',D'2024.11.03 01:00:00'));
   savings.Add(new CDaylightSavings_US(D'2025.03.09 03:00:00',D'2025.11.02 01:00:00'));
   savings.Add(new CDaylightSavings_US(D'2026.03.08 03:00:00',D'2026.11.01 01:00:00'));
   savings.Add(new CDaylightSavings_US(D'2027.03.14 03:00:00',D'2027.11.07 01:00:00'));
   savings.Add(new CDaylightSavings_US(D'2028.03.12 03:00:00',D'2028.11.05 01:00:00'));
   savings.Add(new CDaylightSavings_US(D'2029.03.11 03:00:00',D'2029.11.04 01:00:00'));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CDaylightSavings_US::CDaylightSavings_US(datetime startdate,datetime enddate)
  {
   StartDate = startdate;
   EndDate = enddate;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CDaylightSavings_US::isDaylightSavings(datetime Date)
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
//|                                                                  |
//+------------------------------------------------------------------+
bool CDaylightSavings_US::DaylightSavings(int Year,datetime &startDate,datetime &endDate)
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
//|                                                                  |
//+------------------------------------------------------------------+
void CDaylightSavings_US::adjustDaylightSavings(datetime EventDate,string &AdjustedDate)
  {
   if(isDaylightSavings(TimeTradeServer()))//Check if the current tradeserver time is already within the DaylightSavings Period
     {
      if(isDaylightSavings(EventDate))//Checks if the event time is during daylight savings
        {
         AdjustedDate = TimeToString(EventDate);//storing normal event time
        }
      else
        {
         AdjustedDate = TimeToString((datetime)(EventDate-Time.HoursS()));//storing event time and removing an hour for DST
        }
     }
   else
     {
      if(isDaylightSavings(EventDate))//Checks if the event time is during daylight savings
        {
         AdjustedDate = TimeToString((datetime)(Time.HoursS()+EventDate));//storing event time and adding an hour for DST
        }
      else
        {
         AdjustedDate = TimeToString(EventDate);//storing normal event time
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CDaylightSavings_US::~CDaylightSavings_US(void)
  {

   delete savings;
   delete dayLight;
   delete getSavings;

  }
//+------------------------------------------------------------------+
