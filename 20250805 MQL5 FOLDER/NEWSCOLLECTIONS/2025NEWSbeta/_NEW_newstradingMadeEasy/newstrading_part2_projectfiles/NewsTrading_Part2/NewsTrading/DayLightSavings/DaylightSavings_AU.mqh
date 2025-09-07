//+------------------------------------------------------------------+
//|                                                      NewsTrading |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                            https://www.mql5.com/en/users/kaaiblo |
//+------------------------------------------------------------------+

#include "DaylightSavings.mqh"

//+------------------------------------------------------------------+
//|DaylightSavings_AU class                                          |
//+------------------------------------------------------------------+
class CDaylightSavings_AU: public CDaylightSavings
  {

public:

                     CDaylightSavings_AU(void);
  };

//+------------------------------------------------------------------+
//|Set Daylight Savings Schedule for Australia                       |
//+------------------------------------------------------------------+
void CDaylightSavings::SetDaylightSavings_AU()
  {
   savings = new CArrayObj();
//Daylight savings dates to readjust dates in the database for accurate testing in the strategy tester
   savings.Add(new CDaylightSavings(D'2006.10.29 03:00:00',D'2007.03.25 02:00:00'));
   savings.Add(new CDaylightSavings(D'2007.10.28 03:00:00',D'2008.04.06 02:00:00'));
   savings.Add(new CDaylightSavings(D'2008.10.05 03:00:00',D'2009.04.05 02:00:00'));
   savings.Add(new CDaylightSavings(D'2009.10.04 03:00:00',D'2010.04.04 02:00:00'));
   savings.Add(new CDaylightSavings(D'2010.10.03 03:00:00',D'2011.04.03 02:00:00'));
   savings.Add(new CDaylightSavings(D'2011.10.02 03:00:00',D'2012.04.01 02:00:00'));
   savings.Add(new CDaylightSavings(D'2012.10.07 03:00:00',D'2013.04.07 02:00:00'));
   savings.Add(new CDaylightSavings(D'2013.10.06 03:00:00',D'2014.04.06 02:00:00'));
   savings.Add(new CDaylightSavings(D'2014.10.05 03:00:00',D'2015.04.05 02:00:00'));
   savings.Add(new CDaylightSavings(D'2015.10.04 03:00:00',D'2016.04.03 02:00:00'));
   savings.Add(new CDaylightSavings(D'2016.10.02 03:00:00',D'2017.04.02 02:00:00'));
   savings.Add(new CDaylightSavings(D'2017.10.01 03:00:00',D'2018.04.01 02:00:00'));
   savings.Add(new CDaylightSavings(D'2018.10.07 03:00:00',D'2019.04.07 02:00:00'));
   savings.Add(new CDaylightSavings(D'2019.10.06 03:00:00',D'2020.04.05 02:00:00'));
   savings.Add(new CDaylightSavings(D'2020.10.04 03:00:00',D'2021.04.04 02:00:00'));
   savings.Add(new CDaylightSavings(D'2021.10.03 03:00:00',D'2022.04.03 02:00:00'));
   savings.Add(new CDaylightSavings(D'2022.10.02 03:00:00',D'2023.04.02 02:00:00'));
   savings.Add(new CDaylightSavings(D'2023.10.01 03:00:00',D'2024.04.07 02:00:00'));
   savings.Add(new CDaylightSavings(D'2024.10.06 03:00:00',D'2025.04.06 02:00:00'));
   savings.Add(new CDaylightSavings(D'2025.10.05 03:00:00',D'2026.04.05 02:00:00'));
   savings.Add(new CDaylightSavings(D'2026.10.04 03:00:00',D'2027.04.04 02:00:00'));
   savings.Add(new CDaylightSavings(D'2027.10.03 03:00:00',D'2028.04.02 02:00:00'));
   savings.Add(new CDaylightSavings(D'2028.10.01 03:00:00',D'2029.04.01 02:00:00'));
  }

//+------------------------------------------------------------------+
//|Constructor                                                       |
//+------------------------------------------------------------------+
CDaylightSavings_AU::CDaylightSavings_AU(void)
  {
   SetDaylightSavings_AU();
  }
//+------------------------------------------------------------------+
