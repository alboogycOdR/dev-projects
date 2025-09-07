//+------------------------------------------------------------------+
//|                                                      NewsTrading |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                            https://www.mql5.com/en/users/kaaiblo |
//+------------------------------------------------------------------+

#include "DaylightSavings.mqh"

//+------------------------------------------------------------------+
//|DaylightSavings_US Class                                          |
//+------------------------------------------------------------------+
class CDaylightSavings_US: public CDaylightSavings
  {

public:

                     CDaylightSavings_US(void);
  };

//+------------------------------------------------------------------+
//|Set Daylight Savings Schedule for the United States               |
//+------------------------------------------------------------------+
void CDaylightSavings::SetDaylightSavings_US()
  {
   savings = new CArrayObj();
//Daylight savings dates to readjust dates in the database for accurate testing in the strategy tester
   savings.Add(new CDaylightSavings(D'2007.03.11 03:00:00',D'2007.11.04 01:00:00'));
   savings.Add(new CDaylightSavings(D'2008.03.09 03:00:00',D'2008.11.02 01:00:00'));
   savings.Add(new CDaylightSavings(D'2009.03.08 03:00:00',D'2009.11.01 01:00:00'));
   savings.Add(new CDaylightSavings(D'2010.03.14 03:00:00',D'2010.11.07 01:00:00'));
   savings.Add(new CDaylightSavings(D'2011.03.13 03:00:00',D'2011.11.06 01:00:00'));
   savings.Add(new CDaylightSavings(D'2012.03.11 03:00:00',D'2012.11.04 01:00:00'));
   savings.Add(new CDaylightSavings(D'2013.03.10 03:00:00',D'2013.11.03 01:00:00'));
   savings.Add(new CDaylightSavings(D'2014.03.09 03:00:00',D'2014.11.02 01:00:00'));
   savings.Add(new CDaylightSavings(D'2015.03.08 03:00:00',D'2015.11.01 01:00:00'));
   savings.Add(new CDaylightSavings(D'2016.03.13 03:00:00',D'2016.11.06 01:00:00'));
   savings.Add(new CDaylightSavings(D'2017.03.12 03:00:00',D'2017.11.05 01:00:00'));
   savings.Add(new CDaylightSavings(D'2018.03.11 03:00:00',D'2018.11.04 01:00:00'));
   savings.Add(new CDaylightSavings(D'2019.03.10 03:00:00',D'2019.11.03 01:00:00'));
   savings.Add(new CDaylightSavings(D'2020.03.08 03:00:00',D'2020.11.01 01:00:00'));
   savings.Add(new CDaylightSavings(D'2021.03.14 03:00:00',D'2021.11.07 01:00:00'));
   savings.Add(new CDaylightSavings(D'2022.03.13 03:00:00',D'2022.11.06 01:00:00'));
   savings.Add(new CDaylightSavings(D'2023.03.12 03:00:00',D'2023.11.05 01:00:00'));
   savings.Add(new CDaylightSavings(D'2024.03.10 03:00:00',D'2024.11.03 01:00:00'));
   savings.Add(new CDaylightSavings(D'2025.03.09 03:00:00',D'2025.11.02 01:00:00'));
   savings.Add(new CDaylightSavings(D'2026.03.08 03:00:00',D'2026.11.01 01:00:00'));
   savings.Add(new CDaylightSavings(D'2027.03.14 03:00:00',D'2027.11.07 01:00:00'));
   savings.Add(new CDaylightSavings(D'2028.03.12 03:00:00',D'2028.11.05 01:00:00'));
   savings.Add(new CDaylightSavings(D'2029.03.11 03:00:00',D'2029.11.04 01:00:00'));
  }

//+------------------------------------------------------------------+
//|Constructor                                                       |
//+------------------------------------------------------------------+
CDaylightSavings_US::CDaylightSavings_US(void)
  {
   SetDaylightSavings_US();
  }
//+------------------------------------------------------------------+
