//+------------------------------------------------------------------+
//|                                            CalendarRetriever.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Muller Peter"  
#property link      "https://www.mql5.com/en/users/mullerp04/seller"          
#property version   "1.00"                        
#property script_show_inputs                         
#include <CalendarFile.mqh>           

input datetime StartDate = D'2021.01.01';              // Start date for calendar events
input datetime EndDate = 0;                            // End date (0 means no end date specified)

void OnStart()
{
   string ValueFileName = "Calendar\\News.bin";         // File to store the event data in binary format
   string CountriesFileName = "Calendar\\Countries.txt"; // File to store country data in text format
   CalendarFileWriter* FWrite = new CalendarFileWriter(); // Create an instance of CalendarFileWriter to handle the writing of calendar data

   string base = SymbolInfoString(_Symbol,SYMBOL_CURRENCY_BASE);  // Retrieve the base & profit currency of the current symbol
   string profit = SymbolInfoString(_Symbol,SYMBOL_CURRENCY_PROFIT); 

   if(!FileIsExist("Calendar\\"+base+"Events.txt", FILE_COMMON) && base != NULL) // If the base currency event file does not exist
   {
      FWrite.WriteEventFile("Calendar\\"+base+"Events.txt", base);  // Write the event data for the base currency to a text file
   }

   if(!FileIsExist("Calendar\\"+profit+"Events.txt", FILE_COMMON) && profit != NULL) // If the profit currency event file does not exist
   {
      FWrite.WriteEventFile("Calendar\\"+profit+"Events.txt", profit); // Write the event data for the profit currency to a text file
   }

   FWrite.WriteCountryFile(CountriesFileName); // Write the country data to a text file
   FWrite.WriteValueFile(ValueFileName, StartDate, EndDate); // Write the calendar event data to a binary file for the specified date range

   delete FWrite;   
}
