//+------------------------------------------------------------------+
//|                                                      NewsTrading |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                            https://www.mql5.com/en/users/kaaiblo |
//+------------------------------------------------------------------+
#include <Trade/SymbolInfo.mqh>
//+------------------------------------------------------------------+
//|SymbolProperties class                                            |
//+------------------------------------------------------------------+
class CSymbolProperties
  {
private:
   double            ASK;//Store Ask Price
   double            BID;//Store Bid Price
   double            LOTSMIN;//Store Minimum Lotsize
   double            LOTSMAX;//Store Maximum Lotsize
   double            LOTSSTEP;//Store Lotsize Step
   double            LOTSLIMIT;//Store Lotsize Limit(Maximum sum of Volume)
   long              SPREAD;//Store Spread value
   long              STOPLEVEL;//Store Stop level
   long              FREEZELEVEL;//Store Freeze level
   long              TIME;//Store time
   long              DIGITS;//Store Digits
   double            POINT;//Store Point
   double            ORDERSVOLUME;//Store Orders volume
   double            POSITIONSVOLUME;//Store Positions volume
   long              CUSTOM;//Store if Symbol is Custom
   long              BACKGROUND_CLR;//Store Symbol's background color

protected:
   CSymbolInfo       CSymbol;//Creating class CSymbolInfo's Object
   bool              SetSymbolName(string SYMBOL)
     {
      //-- If Symbol's name was successfully set.
      if(!CSymbol.Name((SYMBOL==NULL)?Symbol():SYMBOL))
        {
         Print("Invalid Symbol: ",SYMBOL);
         return false;
        }
      return true;
     }

   //-- Retrieve Symbol's name
   string            GetSymbolName()
     {
      return CSymbol.Name();
     }

public:
                     CSymbolProperties(void);//Constructor
   double            Ask(string SYMBOL=NULL);//Retrieve Ask Price
   double            Bid(string SYMBOL=NULL);//Retrieve Bid Price
   double            ContractSize(string SYMBOL=NULL);//Retrieve Contract Size
   double            LotsMin(string SYMBOL=NULL);//Retrieve Min Volume
   double            LotsMax(string SYMBOL=NULL);//Retrieve Max Volume
   double            LotsStep(string SYMBOL=NULL);//Retrieve Volume Step
   double            LotsLimit(string SYMBOL=NULL);//Retrieve Volume Limit
   int               Spread(string SYMBOL=NULL);//Retrieve Spread
   int               StopLevel(string SYMBOL=NULL);//Retrieve Stop Level
   int               FreezeLevel(string SYMBOL=NULL);//Retrieve Freeze Level
   datetime          Time(string SYMBOL=NULL);//Retrieve Symbol's Time
   //-- Normalize Price
   double            NormalizePrice(const double price,string SYMBOL=NULL);
   int               Digits(string SYMBOL=NULL);//Retrieve Symbol's Digits
   double            Point(string SYMBOL=NULL);//Retrieve Symbol's Point
   ENUM_SYMBOL_TRADE_MODE TradeMode(string SYMBOL=NULL);//Retrieve Symbol's Trade Mode
   double            OrdersVolume(string SYMBOL=NULL);//Retrieve Symbol's Orders Volume
   double            PositionsVolume(string SYMBOL=NULL);//Retrieve Symbol's Positions Volume
   string            CurrencyBase(string SYMBOL=NULL);//Retrieve Symbol's Currency Base
   string            CurrencyProfit(string SYMBOL=NULL);//Retrieve Symbol's Currency Profit
   string            CurrencyMargin(string SYMBOL=NULL);//Retrieve Symbol's Currency Margin
   bool              Custom(string SYMBOL=NULL);//Retrieve Symbol's Custom status
   color             SymbolBackground(string SYMBOL=NULL,bool allow_black=false);//Retrieve Symbol's Background color
  };

//+------------------------------------------------------------------+
//|Constructor                                                       |
//+------------------------------------------------------------------+
//Initializing Variables
CSymbolProperties::CSymbolProperties(void):ASK(0.0),BID(0.0),
   LOTSMIN(0.0),LOTSMAX(0.0),
   LOTSSTEP(0.0),LOTSLIMIT(0.0),DIGITS(0),
   SPREAD(0),STOPLEVEL(0),ORDERSVOLUME(0.0),
   FREEZELEVEL(0),TIME(0),POINT(0.0),POSITIONSVOLUME(0.0),
   CUSTOM(0),BACKGROUND_CLR(0)
  {
  }

//+------------------------------------------------------------------+
//|Retrieve Ask Price                                                |
//+------------------------------------------------------------------+
double CSymbolProperties::Ask(string SYMBOL=NULL)
  {
   if(SetSymbolName(SYMBOL))//Set Symbol
     {
      if(CSymbol.InfoDouble(SYMBOL_ASK,ASK))
        {
         return ASK;
        }
     }
   Print("Unable to retrieve Symbol's Ask Price");
   return 0.0;
  }

//+------------------------------------------------------------------+
//|Retrieve Bid Price                                                |
//+------------------------------------------------------------------+
double CSymbolProperties::Bid(string SYMBOL=NULL)
  {
   if(SetSymbolName(SYMBOL))//Set Symbol
     {
      if(CSymbol.InfoDouble(SYMBOL_BID,BID))
        {
         return BID;
        }
     }
   Print("Unable to retrieve Symbol's Bid Price");
   return 0.0;
  }

//+------------------------------------------------------------------+
//|Retrieve Contract Size                                            |
//+------------------------------------------------------------------+
double CSymbolProperties::ContractSize(string SYMBOL=NULL)
  {
   if(SetSymbolName(SYMBOL))//Set Symbol
     {
      if(CSymbol.Refresh())
        {
         return CSymbol.ContractSize();
        }
     }
   Print("Unable to retrieve Symbol's Contract size");
   return 0.0;
  }

//+------------------------------------------------------------------+
//|Retrieve Min Volume                                               |
//+------------------------------------------------------------------+
double CSymbolProperties::LotsMin(string SYMBOL=NULL)
  {
   if(SetSymbolName(SYMBOL))//Set Symbol
     {
      if(CSymbol.InfoDouble(SYMBOL_VOLUME_MIN,LOTSMIN))
        {
         return LOTSMIN;
        }
     }
   Print("Unable to retrieve Symbol's LotsMin");
   return 0.0;
  }

//+------------------------------------------------------------------+
//|Retrieve Max Volume                                               |
//+------------------------------------------------------------------+
double CSymbolProperties::LotsMax(string SYMBOL=NULL)
  {
   if(SetSymbolName(SYMBOL))//Set Symbol
     {
      if(CSymbol.InfoDouble(SYMBOL_VOLUME_MAX,LOTSMAX))
        {
         return LOTSMAX;
        }
     }
   Print("Unable to retrieve Symbol's LotsMax");
   return 0.0;
  }

//+------------------------------------------------------------------+
//|Retrieve Volume Step                                              |
//+------------------------------------------------------------------+
double CSymbolProperties::LotsStep(string SYMBOL=NULL)
  {
   if(SetSymbolName(SYMBOL))//Set Symbol
     {
      if(CSymbol.InfoDouble(SYMBOL_VOLUME_STEP,LOTSSTEP))
        {
         return LOTSSTEP;
        }
     }
   Print("Unable to retrieve Symbol's LotsStep");
   return 0.0;
  }

//+------------------------------------------------------------------+
//|Retrieve Volume Limit                                             |
//+------------------------------------------------------------------+
double CSymbolProperties::LotsLimit(string SYMBOL=NULL)
  {
   if(SetSymbolName(SYMBOL))//Set Symbol
     {
      if(CSymbol.InfoDouble(SYMBOL_VOLUME_LIMIT,LOTSLIMIT))
        {
         return LOTSLIMIT;
        }
     }
   Print("Unable to retrieve Symbol's LotsLimit");
   return 0.0;
  }

//+------------------------------------------------------------------+
//|Retrieve Spread                                                   |
//+------------------------------------------------------------------+
int CSymbolProperties::Spread(string SYMBOL=NULL)
  {
   if(SetSymbolName(SYMBOL))//Set Symbol
     {
      if(CSymbol.InfoInteger(SYMBOL_SPREAD,SPREAD))
        {
         return int(SPREAD);
        }
     }
   Print("Unable to retrieve Symbol's Spread");
   return 0;
  }

//+------------------------------------------------------------------+
//|Retrieve Stop Level                                               |
//+------------------------------------------------------------------+
int CSymbolProperties::StopLevel(string SYMBOL=NULL)
  {
   if(SetSymbolName(SYMBOL))//Set Symbol
     {
      if(CSymbol.InfoInteger(SYMBOL_TRADE_STOPS_LEVEL,STOPLEVEL))
        {
         return int(STOPLEVEL);
        }
     }
   Print("Unable to retrieve Symbol's StopLevel");
   return 0;
  }

//+------------------------------------------------------------------+
//|Retrieve Freeze Level                                             |
//+------------------------------------------------------------------+
int CSymbolProperties::FreezeLevel(string SYMBOL=NULL)
  {
   if(SetSymbolName(SYMBOL))//Set Symbol
     {
      if(CSymbol.InfoInteger(SYMBOL_TRADE_FREEZE_LEVEL,FREEZELEVEL))
        {
         return int(FREEZELEVEL);
        }
     }
   Print("Unable to retrieve Symbol's FreezeLevel");
   return 0;
  }

//+------------------------------------------------------------------+
//|Retrieve Symbol's Time                                            |
//+------------------------------------------------------------------+
datetime CSymbolProperties::Time(string SYMBOL=NULL)
  {
   if(SetSymbolName(SYMBOL))//Set Symbol
     {
      if(CSymbol.InfoInteger(SYMBOL_TIME,TIME))
        {
         return datetime(TIME);
        }
     }
   Print("Unable to retrieve Symbol's Time");
   TIME=0;
   return datetime(TIME);
  }

//+------------------------------------------------------------------+
//|Normalize Price                                                   |
//+------------------------------------------------------------------+
double CSymbolProperties::NormalizePrice(const double price,string SYMBOL=NULL)
  {
   if(SetSymbolName(SYMBOL))//Set Symbol
     {
      if(CSymbol.Refresh()&&CSymbol.RefreshRates())
        {
         return CSymbol.NormalizePrice(price);
        }
     }
   Print("Unable to Normalize Symbol's Price");
   return price;
  }

//+------------------------------------------------------------------+
//|Retrieve Symbol's Digits                                          |
//+------------------------------------------------------------------+
int CSymbolProperties::Digits(string SYMBOL=NULL)
  {
   if(SetSymbolName(SYMBOL))//Set Symbol
     {
      if(CSymbol.InfoInteger(SYMBOL_DIGITS,DIGITS))
        {
         return int(DIGITS);
        }
     }
   Print("Unable to retrieve Symbol's Digits");
   return 0;
  }

//+------------------------------------------------------------------+
//|Retrieve Symbol's Point                                           |
//+------------------------------------------------------------------+
double CSymbolProperties::Point(string SYMBOL=NULL)
  {
   if(SetSymbolName(SYMBOL))//Set Symbol
     {
      if(CSymbol.InfoDouble(SYMBOL_POINT,POINT))
        {
         return POINT;
        }
     }
   Print("Unable to retrieve Symbol's Point");
   return 0.0;
  }

//+------------------------------------------------------------------+
//|Retrieve Symbol's Trade Mode                                      |
//+------------------------------------------------------------------+
ENUM_SYMBOL_TRADE_MODE CSymbolProperties::TradeMode(string SYMBOL=NULL)
  {
   if(SetSymbolName(SYMBOL))//Set Symbol
     {
      if(CSymbol.Refresh())
        {
         return CSymbol.TradeMode();
        }
     }
   Print("Unable to retrieve Symbol's TradeMode");
   return SYMBOL_TRADE_MODE_DISABLED;
  }

//+------------------------------------------------------------------+
//|Retrieve Symbol's Orders Volume                                   |
//+------------------------------------------------------------------+
double CSymbolProperties::OrdersVolume(string SYMBOL=NULL)
  {
   if(SetSymbolName(SYMBOL))//Set Symbol
     {
      for(int i=0; i<OrdersTotal(); i++)
        {
         if(OrderSelect(OrderGetTicket(i)))
           {
            if(OrderGetString(ORDER_SYMBOL)==GetSymbolName())
              {
               ORDERSVOLUME+=OrderGetDouble(ORDER_VOLUME_CURRENT);
              }
           }
        }
     }
   else
     {
      Print("Unable to retrieve Symbol's OrdersVolume");
      return 0.0;
     }
   return ORDERSVOLUME;
  }

//+------------------------------------------------------------------+
//|Retrieve Symbol's Positions Volume                                |
//+------------------------------------------------------------------+
double CSymbolProperties::PositionsVolume(string SYMBOL=NULL)
  {
   if(SetSymbolName(SYMBOL))//Set Symbol
     {
      for(int i=0; i<PositionsTotal(); i++)
        {
         if(PositionGetTicket(i)>0)
           {
            if(PositionGetString(POSITION_SYMBOL)==GetSymbolName())
              {
               POSITIONSVOLUME+=PositionGetDouble(POSITION_VOLUME);
              }
           }
        }
     }
   else
     {
      Print("Unable to retrieve Symbol's PositionsVolume");
      return 0.0;
     }
   return POSITIONSVOLUME;
  }

//+------------------------------------------------------------------+
//|Retrieve Symbol's Currency Base                                   |
//+------------------------------------------------------------------+
string CSymbolProperties::CurrencyBase(string SYMBOL=NULL)
  {
   if(SetSymbolName(SYMBOL))//Set Symbol
     {
      if(CSymbol.Refresh())
        {
         return CSymbol.CurrencyBase();
        }
     }
   Print("Unable to retrieve Symbol's CurrencyBase");
   return "";
  }
//+------------------------------------------------------------------+
//|Retrieve Symbol's Currency Profit                                 |
//+------------------------------------------------------------------+
string CSymbolProperties::CurrencyProfit(string SYMBOL=NULL)
  {
   if(SetSymbolName(SYMBOL))//Set Symbol
     {
      if(CSymbol.Refresh())
        {
         return CSymbol.CurrencyProfit();
        }
     }
   Print("Unable to retrieve Symbol's CurrencyProfit");
   return "";
  }
//+------------------------------------------------------------------+
//|Retrieve Symbol's Currency Margin                                 |
//+------------------------------------------------------------------+
string CSymbolProperties::CurrencyMargin(string SYMBOL=NULL)
  {
   if(SetSymbolName(SYMBOL))//Set Symbol
     {
      if(CSymbol.Refresh())
        {
         return CSymbol.CurrencyMargin();
        }
     }
   Print("Unable to retrieve Symbol's CurrencyMargin");
   return "";
  }

//+------------------------------------------------------------------+
//|Retrieve Symbol's Custom status                                   |
//+------------------------------------------------------------------+
bool CSymbolProperties::Custom(string SYMBOL=NULL)
  {
   if(SetSymbolName(SYMBOL))//Set Symbol
     {
      if(CSymbol.InfoInteger(SYMBOL_CUSTOM,CUSTOM))
        {
         return bool(CUSTOM);
        }
     }
   Print("Unable to retrieve if Symbol is Custom");
   return false;
  }

//+------------------------------------------------------------------+
//|Retrieve Symbol's Background color                                |
//+------------------------------------------------------------------+
color CSymbolProperties::SymbolBackground(string SYMBOL=NULL,bool allow_black=false)
  {
   if(SetSymbolName(SYMBOL))//Set Symbol
     {
      if(CSymbol.InfoInteger(SYMBOL_BACKGROUND_COLOR,BACKGROUND_CLR))
        {
         /*Avoid any Symbol black background color */
         BACKGROUND_CLR = ((ColorToString(color(BACKGROUND_CLR))=="0,0,0"||
                            color(BACKGROUND_CLR)==clrBlack)&&!allow_black)?
                          long(StringToColor("236,236,236")):BACKGROUND_CLR;
         return color(BACKGROUND_CLR);
        }
     }
   Print("Unable to retrieve Symbol's Background color");
   return color(StringToColor("236,236,236"));//Retrieve a lightish gray color
  }
//+------------------------------------------------------------------+
