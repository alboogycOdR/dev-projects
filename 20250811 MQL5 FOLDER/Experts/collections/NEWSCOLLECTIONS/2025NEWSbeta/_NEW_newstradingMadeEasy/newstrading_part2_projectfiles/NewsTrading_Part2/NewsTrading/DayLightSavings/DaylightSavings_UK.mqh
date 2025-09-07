//+------------------------------------------------------------------+
//|                                                      NewsTrading |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                            https://www.mql5.com/en/users/kaaiblo |
//+------------------------------------------------------------------+

#include "DaylightSavings.mqh"

//+------------------------------------------------------------------+
//|DaylightSavings_UK class                                          |
//+------------------------------------------------------------------+
class CDaylightSavings_UK: public CDaylightSavings
  {

public:

                     CDaylightSavings_UK(void);
  };

//+------------------------------------------------------------------+
//|Set Daylight Savings Schedule for Europe                          |
//+------------------------------------------------------------------+
void CDaylightSavings::SetDaylightSavings_UK()
  {
   savings = new CArrayObj();
//Daylight savings dates to readjust dates in the database for accurate testing in the strategy tester
   savings.Add(new CDaylightSavings(D'2007.03.25 02:00:00',D'2007.10.28 01:00:00'));
   savings.Add(new CDaylightSavings(D'2008.03.30 02:00:00',D'2008.10.26 01:00:00'));
   savings.Add(new CDaylightSavings(D'2009.03.29 02:00:00',D'2009.10.25 01:00:00'));
   savings.Add(new CDaylightSavings(D'2010.03.28 02:00:00',D'2010.10.31 01:00:00'));
   savings.Add(new CDaylightSavings(D'2011.03.27 02:00:00',D'2011.10.30 01:00:00'));
   savings.Add(new CDaylightSavings(D'2012.03.25 02:00:00',D'2012.10.28 01:00:00'));
   savings.Add(new CDaylightSavings(D'2013.03.31 02:00:00',D'2013.10.27 01:00:00'));
   savings.Add(new CDaylightSavings(D'2014.03.30 02:00:00',D'2014.10.26 01:00:00'));
   savings.Add(new CDaylightSavings(D'2015.03.29 02:00:00',D'2015.10.25 01:00:00'));
   savings.Add(new CDaylightSavings(D'2016.03.27 02:00:00',D'2016.10.30 01:00:00'));
   savings.Add(new CDaylightSavings(D'2017.03.26 02:00:00',D'2017.10.29 01:00:00'));
   savings.Add(new CDaylightSavings(D'2018.03.25 02:00:00',D'2018.10.28 01:00:00'));
   savings.Add(new CDaylightSavings(D'2019.03.31 02:00:00',D'2019.10.27 01:00:00'));
   savings.Add(new CDaylightSavings(D'2020.03.29 02:00:00',D'2020.10.25 01:00:00'));
   savings.Add(new CDaylightSavings(D'2021.03.28 02:00:00',D'2021.10.31 01:00:00'));
   savings.Add(new CDaylightSavings(D'2022.03.27 02:00:00',D'2022.10.30 01:00:00'));
   savings.Add(new CDaylightSavings(D'2023.03.26 02:00:00',D'2023.10.29 01:00:00'));
   savings.Add(new CDaylightSavings(D'2024.03.31 02:00:00',D'2024.10.27 01:00:00'));
   savings.Add(new CDaylightSavings(D'2025.03.30 02:00:00',D'2025.10.26 01:00:00'));
   savings.Add(new CDaylightSavings(D'2026.03.29 02:00:00',D'2026.10.25 01:00:00'));
   savings.Add(new CDaylightSavings(D'2027.03.28 02:00:00',D'2027.10.31 01:00:00'));
   savings.Add(new CDaylightSavings(D'2028.03.26 02:00:00',D'2028.10.29 01:00:00'));
   savings.Add(new CDaylightSavings(D'2029.03.25 02:00:00',D'2029.10.28 01:00:00'));
  }

//+------------------------------------------------------------------+
//|Constructor                                                       |
//+------------------------------------------------------------------+
CDaylightSavings_UK::CDaylightSavings_UK(void)
  {
   SetDaylightSavings_UK();
  }
//+------------------------------------------------------------------+
