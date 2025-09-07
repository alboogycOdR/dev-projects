//+------------------------------------------------------------------+
//|                                           Test_get_countries.mq5 |
//|                                           Copyright 2021, denkir |
//|                             https://www.mql5.com/en/users/denkir |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, denkir"
#property link      "https://www.mql5.com/en/users/denkir"
#property version   "1.00"
//--- include
#include "..\Include\CalendarInfo.mqh"
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   CiCalendarInfo country_calendar_info;
   if(country_calendar_info.Init())
     {
      //--- 1) get countries (CArrayString)
      CArrayString countries_arr;
      if(country_calendar_info.GetCountries(countries_arr))
        {
         int countries_num = countries_arr.Total();
         if(countries_num > 0)
           {
            ::Print("\n---== CArrayString list ==---");
            ::PrintFormat("   Countries list consists of %d countries.", countries_num);
            ::PrintFormat("   First country: %s", countries_arr.At(0));
            ::PrintFormat("   Last country: %s", countries_arr.At(countries_num - 1));
           }
        }
      //--- 2) get countries (MqlCalendarCountry)
      MqlCalendarCountry countries[];
      if(country_calendar_info.GetCountries(countries))
        {
         int countries_num = ::ArraySize(countries);
         if(countries_num > 0)
           {
            ::Print("\n---== MqlCalendarCountry array ==---");
            ::PrintFormat("   Countries array consists of %d countries.", countries_num);
            ::PrintFormat("   First country: %s", countries[0].name);
            ::PrintFormat("   Last country: %s", countries[countries_num - 1].name);
           }
        }
      //--- 3) get unique continents
      string continent_names[];
      int continents_num = 0;
      if(country_calendar_info.GetUniqueContinents(continent_names))
        {
         continents_num = ::ArraySize(continent_names);
         if(continents_num > 0)
           {
            ::Print("\n---== Unique continent names ==---");
            for(int c_idx = 0; c_idx < continents_num; c_idx++)
              {
               string curr_continent_name = continent_names[c_idx];
               ::PrintFormat("   [%d] - %s", c_idx + 1, curr_continent_name);
              }
           }
        }
      //--- 4) get countries by continent
      if(continents_num)
        {
         ENUM_CONTINENT continents[];
         ::ArrayResize(continents, continents_num);
         ::Print("\n---== Countries by continent ==---");
         for(int c_idx = 0; c_idx < continents_num; c_idx++)
           {
            ENUM_CONTINENT curr_continent =
               SCountryByContinent::ContinentByDescription(continent_names[c_idx]);
            if(countries_arr.Shutdown())
               if(country_calendar_info.GetCountriesByContinent(curr_continent, countries_arr))
                 {
                  int countries_by_continent = countries_arr.Total();
                  ::PrintFormat("   Continent \"%s\" includes %d country(-ies):",
                                continent_names[c_idx], countries_by_continent);
                  for(int c_jdx = 0; c_jdx < countries_by_continent; c_jdx++)
                    {
                     ::PrintFormat("   [%d] - %s", c_jdx + 1,
                                   countries_arr.At(c_jdx));
                    }
                 }
           }
        }
      //--- 5) get country description
      string country_code = "RU";
      SCountryByContinent country_continent_data;
      if(country_continent_data.Init(country_code))
        {
         ::Print("\n---== Country ==---");
         ::PrintFormat("   Name: %s", country_continent_data.Country());
         ::PrintFormat("   Code: %s", country_continent_data.Code());
         ENUM_CONTINENT curr_continent = country_continent_data.Continent();
         ::PrintFormat("   Continent enum: %s", ::EnumToString(curr_continent));
         ::PrintFormat("   Continent description: %s",
                       country_continent_data.ContinentDescription());
        }
     }
  }
//+------------------------------------------------------------------+
