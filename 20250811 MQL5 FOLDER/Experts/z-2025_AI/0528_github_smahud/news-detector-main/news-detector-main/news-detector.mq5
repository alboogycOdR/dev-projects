#property strict
#property tester_file "news\\newshistory.bin"

#include <News.mqh>

// Global news object
CNews news;

// Input parameters
input int NotifyBeforeSeconds = 300; // Announce 5 minutes before event time
input int AfterEventDelay     = 60;   // 1 minute after event time to switch to next event

// Global state variables
int currentEventIndex = -1;
bool eventAnnounced = false;

//---------------------------------------------------------------------
// OnInit: Load news and find the first upcoming event
//---------------------------------------------------------------------
int OnInit()
{
   // Set GMT offsets (adjust as needed)
   news.GMT_offset_summer = 3600;
   news.GMT_offset_winter = 3600;
   
   int total = news.update();
   Print("Loaded ", total, " news events from newshistory.bin.");
   
   datetime now = TimeCurrent();
   // Find the first event whose time is in the future.
   for (int i = 0; i < total; i++)
   {
      if (news.event[i].time > now)
      {
         currentEventIndex = i;
         break;
      }
   }
   
   if (currentEventIndex >= 0)
   {
      // Determine if the event is a holiday:
      // Here we assume it is a holiday if both forecast_value and actual_value equal 0.
      bool isHoliday = (news.event[currentEventIndex].forecast_value == 0 &&
                        news.event[currentEventIndex].actual_value == 0);
      string holidayStr = isHoliday ? "Holiday" : "NotHoliday";
      
      Print("Next event: ", news.eventname[currentEventIndex], " at ",
            TimeToString(news.event[currentEventIndex].time, TIME_DATE|TIME_SECONDS),
            " (", holidayStr, ")");
   }
   else
   {
      Print("No upcoming events found.");
   }
   
   return INIT_SUCCEEDED;
}

//---------------------------------------------------------------------
// OnTick: Check event timing and announce accordingly
//---------------------------------------------------------------------
void OnTick()
{
   datetime now = TimeCurrent();
   
   // If there is no current event, nothing to do.
   if (currentEventIndex < 0 || currentEventIndex >= ArraySize(news.event))
      return;
   
   datetime eventTime = news.event[currentEventIndex].time;
   
   // If we're within 5 minutes BEFORE the event and haven't announced it yet:
   if (now >= eventTime - NotifyBeforeSeconds && now < eventTime)
   {
      if (!eventAnnounced)
      {
         bool isHoliday = (news.event[currentEventIndex].forecast_value == 0 &&
                           news.event[currentEventIndex].actual_value == 0);
         string holidayStr = isHoliday ? "Holiday" : "NotHoliday";
         Print("Event is coming: ", news.eventname[currentEventIndex], " at ",
               TimeToString(eventTime, TIME_DATE|TIME_SECONDS), " (", holidayStr, ")");
         eventAnnounced = true;
      }
   }
   
   // If we are at least 1 minute AFTER the event:
   if (now >= eventTime + AfterEventDelay)
   {
      currentEventIndex++;  // move to the next event
      eventAnnounced = false; // reset announcement flag
      
      int total = ArraySize(news.event);
      // Skip any events that are already past
      while (currentEventIndex < total && news.event[currentEventIndex].time <= now)
      {
         currentEventIndex++;
      }
      
      if (currentEventIndex < total)
      {
         bool isHoliday = (news.event[currentEventIndex].forecast_value == 0 &&
                           news.event[currentEventIndex].actual_value == 0);
         string holidayStr = isHoliday ? "Holiday" : "NotHoliday";
         Print("Next event: ", news.eventname[currentEventIndex], " at ",
               TimeToString(news.event[currentEventIndex].time, TIME_DATE|TIME_SECONDS),
               " (", holidayStr, ")");
      }
      else
      {
         Print("No more upcoming events.");
      }
   }
}
