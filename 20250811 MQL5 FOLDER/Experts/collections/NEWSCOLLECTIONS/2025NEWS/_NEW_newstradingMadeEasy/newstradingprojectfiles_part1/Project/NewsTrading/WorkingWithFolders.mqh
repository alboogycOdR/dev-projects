//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
#include "CommonVariables.mqh"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CFolders
  {
private:
   bool              CreateFolder(string FolderPath);//Will create a folder with the FolderPath string parameter

public:
                     CFolders(void);//Class's constructor
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CFolders::CFolders(void)
  {
   if(CreateFolder(NEWS_TRADING_FOLDER))//Will create the NewsTrading Folder
     {
      if(CreateFolder(NEWS_CALENDAR_FOLDER))//Will create the NewsCalendar Folder
        {
         if(!CreateFolder(NEWS_CALENDAR_BROKER_FOLDER))//Will create the Broker Folder
           {
            Print("Something went wrong with creating folder: ",NEWS_CALENDAR_BROKER_FOLDER);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Try creating a folder and display a message about that           |
//+------------------------------------------------------------------+
bool CFolders::CreateFolder(string FolderPath)
  {
//--- attempt to create a folder relative to the MQL5\Files path
   if(FolderCreate(FolderPath,FILE_COMMON))
     {
      //--- successful execution
      return true;
     }
   else
     {
      PrintFormat("Failed to create the folder %s. Error code %d",FolderPath,GetLastError());
     }
//--- execution failed
   return false;
  }
//+------------------------------------------------------------------+
