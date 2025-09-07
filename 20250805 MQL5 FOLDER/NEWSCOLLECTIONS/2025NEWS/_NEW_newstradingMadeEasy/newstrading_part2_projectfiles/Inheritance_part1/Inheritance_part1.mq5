//+------------------------------------------------------------------+
//|                                            Inheritance_part1.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//|(Parent/Base) Class for Generic News Properties                   |
//+------------------------------------------------------------------+
class NewsData
  {
private://Properties are only accessible from this class
   string            Country;//Private variable
   struct EventDetails//Private structure
     {
      int            EventID;
      string         EventName;
      datetime       EventDate;
     };
protected:
   //-- Protected Array Only accessible from this class and its children
   EventDetails      News[];
   //-- Proctected virtual void Function(to be expanded on via child classes)
   virtual void      SetNews();
   //-- Protected Function Only accessible from this class and its children
   void              SetCountry(string myCountry) {Country=myCountry;}
public:
   void              GetNews()//Public function to display 'News' array details
     {
      PrintFormat("+---------- %s ----------+",Country);
      for(uint i=0;i<News.Size();i++)
        {
         Print("ID: ",News[i].EventID," Name: ",News[i].EventName," Date: ",News[i].EventDate);
        }
     }
                     NewsData(void) {}//Class constructor
                    ~NewsData(void) {ArrayFree(News);}//Class destructor
  };


//+------------------------------------------------------------------+
//|(Subclass/Child) for 'NewsData'                                   |
//+------------------------------------------------------------------+
class UnitedStates:private NewsData
//private inheritance from NewsData,
//'UnitedStates' class's objects and children
//will not have access to 'NewsData' class's properties
  {
private:
   virtual void      SetNews()//private Function only Accessible in 'UnitedStates' class
     {
      ArrayResize(News,News.Size()+1,News.Size()+2);
      News[News.Size()-1].EventID = 1;
      News[News.Size()-1].EventName = "NFP(Non-Farm Payrolls)";
      News[News.Size()-1].EventDate = D'2024.01.03 14:00:00';
     }
public:
   void              myNews()//public Function accessible via class's object
     {
      SetCountry("United States");//Calling function from 'NewsData'
      GetNews();//Calling Function from private inherited class 'NewsData'
     }
                     UnitedStates(void) {SetNews();}//Class constructor
  };


//+------------------------------------------------------------------+
//|(Subclass/Child) for 'NewsData'                                   |
//+------------------------------------------------------------------+
class Switzerland: public NewsData
//public inheritance from NewsData
  {
public:
   virtual void      SetNews()//Public Function to set News data
     {
      ArrayResize(News,News.Size()+1,News.Size()+2);//Adjusting News structure array's size
      News[News.Size()-1].EventID = 0;//Setting event id to '0'
      News[News.Size()-1].EventName = "Interest Rate Decision";//Assigning event name
      News[News.Size()-1].EventDate = D'2024.01.06 10:00:00';//Assigning event date
     }
                     Switzerland(void) {SetCountry("Switerland"); SetNews();}//Class construct
  };
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
UnitedStates US;//Create class object
US.myNews();//Retrieve News Results

Switzerland CH;//Create class object
CH.GetNews();//Retrieve News Results
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


  }
//+------------------------------------------------------------------+
