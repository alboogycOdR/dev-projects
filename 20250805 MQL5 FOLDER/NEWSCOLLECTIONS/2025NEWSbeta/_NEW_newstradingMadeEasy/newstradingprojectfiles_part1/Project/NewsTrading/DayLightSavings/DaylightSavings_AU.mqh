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
class CDaylightSavings_AU:CObject
  {

private:

   CTimeManagement   Time;
                     CDaylightSavings_AU(datetime startdate,datetime enddate);
   CObject           *List() { return savings;}//Gets the list of Daylightsavings time
   datetime          StartDate;
   datetime          EndDate;
   CArrayObj         *savings;
   CArrayObj         *getSavings;
   CDaylightSavings_AU      *dayLight;

public:

                     CDaylightSavings_AU(void);
                    ~CDaylightSavings_AU(void);
   bool              isDaylightSavings(datetime Date);//This function checks if a given date falls within Daylight Savings Time.
   bool              DaylightSavings(int Year,datetime &startDate,datetime &endDate);//Check if DaylightSavings Dates are available for a certain Year
   void              adjustDaylightSavings(datetime EventDate,string &AdjustedDate);//Will adjust the date's timezone depending on DaylightSavings
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CDaylightSavings_AU::CDaylightSavings_AU(void)
  {
   savings = new CArrayObj();
//Daylight savings dates to readjust dates in the database for accurate testing in the strategy tester
   savings.Add(new CDaylightSavings_AU(D'2006.10.29 03:00:00',D'2007.03.25 02:00:00'));
   savings.Add(new CDaylightSavings_AU(D'2007.10.28 03:00:00',D'2008.04.06 02:00:00'));
   savings.Add(new CDaylightSavings_AU(D'2008.10.05 03:00:00',D'2009.04.05 02:00:00'));
   savings.Add(new CDaylightSavings_AU(D'2009.10.04 03:00:00',D'2010.04.04 02:00:00'));
   savings.Add(new CDaylightSavings_AU(D'2010.10.03 03:00:00',D'2011.04.03 02:00:00'));
   savings.Add(new CDaylightSavings_AU(D'2011.10.02 03:00:00',D'2012.04.01 02:00:00'));
   savings.Add(new CDaylightSavings_AU(D'2012.10.07 03:00:00',D'2013.04.07 02:00:00'));
   savings.Add(new CDaylightSavings_AU(D'2013.10.06 03:00:00',D'2014.04.06 02:00:00'));
   savings.Add(new CDaylightSavings_AU(D'2014.10.05 03:00:00',D'2015.04.05 02:00:00'));
   savings.Add(new CDaylightSavings_AU(D'2015.10.04 03:00:00',D'2016.04.03 02:00:00'));
   savings.Add(new CDaylightSavings_AU(D'2016.10.02 03:00:00',D'2017.04.02 02:00:00'));
   savings.Add(new CDaylightSavings_AU(D'2017.10.01 03:00:00',D'2018.04.01 02:00:00'));
   savings.Add(new CDaylightSavings_AU(D'2018.10.07 03:00:00',D'2019.04.07 02:00:00'));
   savings.Add(new CDaylightSavings_AU(D'2019.10.06 03:00:00',D'2020.04.05 02:00:00'));
   savings.Add(new CDaylightSavings_AU(D'2020.10.04 03:00:00',D'2021.04.04 02:00:00'));
   savings.Add(new CDaylightSavings_AU(D'2021.10.03 03:00:00',D'2022.04.03 02:00:00'));
   savings.Add(new CDaylightSavings_AU(D'2022.10.02 03:00:00',D'2023.04.02 02:00:00'));
   savings.Add(new CDaylightSavings_AU(D'2023.10.01 03:00:00',D'2024.04.07 02:00:00'));
   savings.Add(new CDaylightSavings_AU(D'2024.10.06 03:00:00',D'2025.04.06 02:00:00'));
   savings.Add(new CDaylightSavings_AU(D'2025.10.05 03:00:00',D'2026.04.05 02:00:00'));
   savings.Add(new CDaylightSavings_AU(D'2026.10.04 03:00:00',D'2027.04.04 02:00:00'));
   savings.Add(new CDaylightSavings_AU(D'2027.10.03 03:00:00',D'2028.04.02 02:00:00'));
   savings.Add(new CDaylightSavings_AU(D'2028.10.01 03:00:00',D'2029.04.01 02:00:00'));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CDaylightSavings_AU::CDaylightSavings_AU(datetime startdate,datetime enddate)
  {
   StartDate = startdate;
   EndDate = enddate;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CDaylightSavings_AU::isDaylightSavings(datetime Date)
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
bool CDaylightSavings_AU::DaylightSavings(int Year,datetime &startDate,datetime &endDate)
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
void CDaylightSavings_AU::adjustDaylightSavings(datetime EventDate,string &AdjustedDate)
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
CDaylightSavings_AU::~CDaylightSavings_AU(void)
  {

   delete savings;
   delete dayLight;
   delete getSavings;

  }
//+------------------------------------------------------------------+
