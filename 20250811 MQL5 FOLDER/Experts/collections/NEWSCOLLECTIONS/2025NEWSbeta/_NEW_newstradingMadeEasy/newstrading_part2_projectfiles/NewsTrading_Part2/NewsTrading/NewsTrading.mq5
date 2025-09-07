//+------------------------------------------------------------------+
//|                                                      NewsTrading |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                            https://www.mql5.com/en/users/kaaiblo |
//+------------------------------------------------------------------+
//--- width and height of the canvas (used for drawing)
#define IMG_WIDTH  200
#define IMG_HEIGHT 100
//--- enable to set color format
ENUM_COLOR_FORMAT clr_format=COLOR_FORMAT_XRGB_NOALPHA;
//--- drawing array (buffer)
uint ExtImg[IMG_WIDTH*IMG_HEIGHT];

#include "News.mqh"
CNews NewsObject;//Class CNews Object 'NewsObject'
#include "TimeManagement.mqh"
CTimeManagement CTM;//Class CTimeManagement Object 'CTM'
#include "WorkingWithFolders.mqh"
CFolders Folder();//Calling Class's Constructor
#include "ChartProperties.mqh"
CChartProperties CChart;//Class CChartProperties Object 'CChart'
#include "RiskManagement.mqh"
CRiskManagement CRisk;//Class CRiskManagement Object 'CRisk'
#include "CommonGraphics.mqh"
CCommonGraphics CGraphics();//Calling Class's Constructor

enum iSeparator
  {
   Delimiter//__________________________
  };

sinput group "+--------| RISK MANAGEMENT |--------+";
input RiskOptions RISK_Type=MINIMUM_LOT;//SELECT RISK OPTION
input RiskFloor RISK_Mini=RiskFloorMin;//RISK FLOOR
input double RISK_Mini_Percent=75;//MAX-RISK [100<-->0.01]%
input RiskCeil  RISK_Maxi=RiskCeilMax;//RISK CEILING
sinput iSeparator iRisk_1=Delimiter;//__________________________
sinput iSeparator iRisk_1L=Delimiter;//PERCENTAGE OF [BALANCE | FREE-MARGIN]
input double Risk_1_PERCENTAGE=3;//[100<-->0.01]%
sinput iSeparator iRisk_2=Delimiter;//__________________________
sinput iSeparator iRisk_2L=Delimiter;//AMOUNT PER [BALANCE | FREE-MARGIN]
input double Risk_2_VALUE=1000;//[BALANCE | FREE-MARGIN]
input double Risk_2_AMOUNT=10;//EACH AMOUNT
sinput iSeparator iRisk_3=Delimiter;//__________________________
sinput iSeparator iRisk_3L=Delimiter;//LOTSIZE PER [BALANCE | FREE-MARGIN]
input double Risk_3_VALUE=1000;//[BALANCE | FREE-MARGIN]
input double Risk_3_LOTSIZE=0.1;//EACH LOTS(VOLUME)
sinput iSeparator iRisk_4=Delimiter;//__________________________
sinput iSeparator iRisk_4L=Delimiter;//CUSTOM LOTSIZE
input double Risk_4_LOTSIZE=0.01;//LOTS(VOLUME)
sinput iSeparator iRisk_5=Delimiter;//__________________________
sinput iSeparator iRisk_5L=Delimiter;//PERCENTAGE OF MAX-RISK
input double Risk_5_PERCENTAGE=1;//[100<-->0.01]%

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---

//Initializing CRiskManagement variable for Risk options
   RiskProfileOption = RISK_Type;
//Initializing CRiskManagement variable for Risk floor
   RiskFloorOption = RISK_Mini;
//Initializing CRiskManagement variable for RiskFloorMax
   RiskFloorPercentage = (RISK_Mini_Percent>100)?100:
                         (RISK_Mini_Percent<0.01)?0.01:RISK_Mini_Percent;//Percentage cannot be more than 100% or less than 0.01%
//Initializing CRiskManagement variable for Risk ceiling
   RiskCeilOption = RISK_Maxi;
//Initializing CRiskManagement variable for Risk options (PERCENTAGE OF BALANCE and PERCENTAGE OF FREE-MARGIN)
   Risk_Profile_1 = (Risk_1_PERCENTAGE>100)?100:
                    (Risk_1_PERCENTAGE<0.01)?0.01:Risk_1_PERCENTAGE;//Percentage cannot be more than 100% or less than 0.01%
//Initializing CRiskManagement variables for Risk options (AMOUNT PER BALANCE and AMOUNT PER FREE-MARGIN)
   Risk_Profile_2.RiskAmountBoF = Risk_2_VALUE;
   Risk_Profile_2.RiskAmount = Risk_2_AMOUNT;
//Initializing CRiskManagement variables for Risk options (LOTSIZE PER BALANCE and LOTSIZE PER FREE-MARGIN)
   Risk_Profile_3.RiskLotBoF = Risk_3_VALUE;
   Risk_Profile_3.RiskLot = Risk_3_LOTSIZE;
//Initializing CRiskManagement variable for Risk option (CUSTOM LOTSIZE)
   Risk_Profile_4 = Risk_4_LOTSIZE;
//Initializing CRiskManagement variable for Risk option (PERCENTAGE OF MAX-RISK)
   Risk_Profile_5 = (Risk_5_PERCENTAGE>100)?100:
                    (Risk_5_PERCENTAGE<0.01)?0.01:Risk_5_PERCENTAGE;//Percentage cannot be more than 100% or less than 0.01%

   CChart.ChartRefresh();//Load chart configurations
   CGraphics.GraphicsRefresh();//-- Create/Re-create chart objects

   if(!MQLInfoInteger(MQL_TESTER))//Checks whether the program is in the strategy tester
     {
      //--- create OBJ_BITMAP_LABEL object for drawing
      ObjectCreate(0,"STATUS",OBJ_BITMAP_LABEL,0,0,0);
      ObjectSetInteger(0,"STATUS",OBJPROP_XDISTANCE,5);
      ObjectSetInteger(0,"STATUS",OBJPROP_YDISTANCE,22);
      //--- specify the name of the graphical resource
      ObjectSetString(0,"STATUS",OBJPROP_BMPFILE,"::PROGRESS");
      uint   w,h;          // variables for receiving text string sizes
      uint    x,y;          // variables for calculation of the current coordinates of text string anchor points

      /*
      In the Do while loop below, the code will check if the terminal is connected to the internet.
      If the the program is stopped the loop will break, if the program is not stopped and the terminal
      is connected to the internet the function CreateEconomicDatabase will be called from the News.mqh header file's
      object called NewsObject and the loop will break once called.
      */
      bool done=false;
      do
        {
         //--- clear the drawing buffer array
         ArrayFill(ExtImg,0,IMG_WIDTH*IMG_HEIGHT,0);

         if(!TerminalInfoInteger(TERMINAL_CONNECTED))
           {
            //-- integer dots used as a loading animation
            static int dots=0;
            //--- set the font
            TextSetFont("Arial",-150,FW_EXTRABOLD,0);
            TextGetSize("Waiting",w,h);//get text width and height values
            //--- calculate the coordinates of the 'Waiting' text
            x=10;//horizontal alignment
            y=IMG_HEIGHT/2-(h/2);//alignment for the text to be centered vertically
            //--- output the 'Waiting' text to ExtImg[] buffer
            TextOut("Waiting",x,y,TA_LEFT|TA_TOP,ExtImg,IMG_WIDTH,IMG_HEIGHT,ColorToARGB(CChart.SymbolBackground()),clr_format);
            //--- calculate the coordinates for the dots after the 'Waiting' text
            x=w+13;//horizontal alignment
            y=IMG_HEIGHT/2-(h/2);//alignment for the text to be centered vertically
            TextSetFont("Arial",-160,FW_EXTRABOLD,0);
            //--- output of dots to ExtImg[] buffer
            TextOut(StringSubstr("...",0,dots),x,y,TA_LEFT|TA_TOP,ExtImg,IMG_WIDTH,IMG_HEIGHT,ColorToARGB(CChart.SymbolBackground()),clr_format);
            //--- update the graphical resource
            ResourceCreate("::PROGRESS",ExtImg,IMG_WIDTH,IMG_HEIGHT,0,0,IMG_WIDTH,clr_format);
            //--- force chart update
            ChartRedraw();
            dots=(dots==3)?0:dots+1;
            //-- Notify user that program is waiting for connection
            Print("Waiting for connection...");
            Sleep(500);
            continue;
           }
         else
           {
            //--- set the font
            TextSetFont("Arial",-120,FW_EXTRABOLD,0);
            TextGetSize("Getting Ready",w,h);//get text width and height values
            x=20;//horizontal alignment
            y=IMG_HEIGHT/2-(h/2);//alignment for the text to be centered vertically
            //--- output the text 'Getting Ready...' to ExtImg[] buffer
            TextOut("Getting Ready...",x,y,TA_LEFT|TA_TOP,ExtImg,IMG_WIDTH,IMG_HEIGHT,ColorToARGB(CChart.SymbolBackground()),clr_format);
            //--- update the graphical resource
            ResourceCreate("::PROGRESS",ExtImg,IMG_WIDTH,IMG_HEIGHT,0,0,IMG_WIDTH,clr_format);
            //--- force chart update
            ChartRedraw();
            //-- Notify user that connection is successful
            Print("Connection Successful!");
            NewsObject.CreateEconomicDatabase();//calling the database create function
            done=true;
           }
        }
      while(!done&&!IsStopped());
      //-- Delete chart object
      ObjectDelete(0,"STATUS");
      //-- force chart to update
      ChartRedraw();
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
      else
        {
         //Checks whether the lastest database date includes the time and date being tested
         datetime latestdate = CTM.TimePlusOffset(NewsObject.GetLatestNewsDate(),CTM.DaysS());//Day after the lastest recorded time in the database
         if(latestdate<TimeCurrent())
           {
            Print("Necessary Files outdated!");
            Print("To Update Files: Run Program outside of the Strategy Tester");
           }
         Print("Database Dates End at: ",latestdate);
         PrintFormat("Dates after %s will not be available for backtest",TimeToString(latestdate));
        }
     }
//-- the volume calculations and the risk type set by the trader
   Print("Lots: ",CRisk.Volume()," || Risk type: ",CRisk.GetRiskOption());
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
