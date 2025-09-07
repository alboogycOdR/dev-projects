//+------------------------------------------------------------------+
//|                                                  NewsTrading.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include "News.mqh"
CNews NewsObject;
#include "TimeManagement.mqh"
CTimeManagement CTM;
#include "WorkingWithFolders.mqh"
CFolders Folder();//Calling the class's constructor
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   if(!MQLInfoInteger(MQL_TESTER))//Checks whether the program is in the strategy tester
     {
      //Checks whether the database file exists and whether it has been modified in the current date
      if((!CTM.DateisToday((datetime)FileGetInteger(NEWS_DATABASE_FILE,FILE_MODIFY_DATE,true)))||(!FileIsExist(NEWS_DATABASE_FILE,FILE_COMMON)))
        {
         /*
         In the Do while loop below, the code will check if the terminal is connected to the internet.
         If the the program is stopped the loop will break, if the program is not stopped and the terminal
         is connected to the internet the function CreateEconomicDatabase will be called from the News.mqh header file's
         object called NewsObject and the loop will break once called.
         */
         bool done=false;
         do
           {
            if(IsStopped())
              {
               done=true;
              }

            if(!TerminalInfoInteger(TERMINAL_CONNECTED))
              {
               Print("Waiting for connection...");
               Sleep(500);
               continue;
              }
            else
              {
               Print("Connection Successful!");
               NewsObject.CreateEconomicDatabase();//calling the database create function
               done=true;
              }
           }
         while(!done);
        }
     }
   else
     {
      //Checks whether the database file exists
      if(!FileIsExist(NEWS_DATABASE_FILE,FILE_COMMON))
        {
         Print("Necessary Files Do not Exist!");
         Print("Run Program outside of the Strategy Tester");
         Print("Necessary Files Should be Created First");
         return(INIT_FAILED);
        }
      //Checks whether the lastest database date includes the time and date being tested
      datetime lastestdate = CTM.TimePlusOffset(NewsObject.GetLastestNewsDate(),CTM.DaysS());//Day after the lastest recorded time in the database
      if(lastestdate<TimeCurrent())
        {
         Print("Necessary Files OutDated!");
         Print("Database Dates End at: ",lastestdate);
         Print("Dates after %s will not be available for backtest",lastestdate);
         Print("To Update Files:");
         Print("Run Program outside of the Strategy Tester");
        }
     }
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---

  }
//+------------------------------------------------------------------+
