//+------------------------------------------------------------------+
//|                                               PendingOrderEA.mq4 |
//|                                       Copyright � 2006, firedave | 
//|                    Partial Function Copyright � 2006, codersguru | 
//|                        Partial Function Copyright � 2006, pengie |
//|                                        http://www.fx-review.com/ | 
//|                                        http://www.forex-tsd.com/ | 
//+------------------------------------------------------------------+

#property copyright "Copyright � 2006, firedave"
#property link      "http://www.fx-review.com"


//----------------------- INCLUDES
#include <stdlib.mqh>


//----------------------- EA PARAMETER
extern string  
         Expert_Name       = "---------- Pending Order EA v1",
         Expert_Name2      = "---------- For current price set EntryLevel = 0";
extern double 
         EntryLevel        = 1.8600,
         Distance          = 100,
         StopLoss          = 50,
         TakeProfit        = 50,
         TrailingStop      = 50;

extern string  
         Order_Setting     = "---------- Order Setting";
extern int
         NumberOfTries     = 5,
         Slippage          = 5,
         MagicNumber       = 1234;

extern string  
         MM_Parameters     = "---------- Money Management";
extern double 
         Lots              = 1;
extern bool 
         MM                = false, //Use Money Management or not
         AccountIsMicro    = false; //Use Micro-Account or not
extern int 
         Risk              = 10; //10%

extern string  
         Testing_Parameters= "---------- Back Test Parameter";
extern bool
         Show_Settings     = true;


//----------------------- GLOBAL VARIABLE
static int 
         TimeFrame         = 0;
string
         TicketComment     = "PendingOrderEA v2",
         LastTrade;
bool
         TradeAllow        = true,
         EntryAllow        = true;         



//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
{

//----------------------- GENERATE MAGIC NUMBER AND TICKET COMMENT
//----------------------- SOURCE : PENGIE
   MagicNumber    = subGenerateMagicNumber(MagicNumber, Symbol(), Period());
	TicketComment  = StringConcatenate(TicketComment, "-", Symbol(), "-", Period());

//----------------------- SHOW EA SETTING ON THE CHART
//----------------------- SOURCE : CODERSGURU
   if(Show_Settings) subPrintDetails();
   else Comment("");
   
   return(0);
}

//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
{
 
//----------------------- PREVENT RE-COUNTING WHILE USER CHANGING TIME FRAME
//----------------------- SOURCE : CODERSGURU
   TimeFrame=Period(); 
   return(0);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int start()
{
   double 
         BuyLevel,
         SellLevel;
                   
   int   
         cnt,
         ticket,
         total;
         
//----------------------- ADJUST LOTS IF USING MONEY MANAGEMENT
   if(MM) Lots = subLotSize();


//----------------------- ENTRY
//----------------------- TOTAL ORDER BASE ON MAGICNUMBER AND SYMBOL
   total = subTotalTrade();

//----------------------- TRAILING STOP SECTION
   if(total>0)
   {
      if(TradeAllow)
      {
         subDeleteOrder();
         TradeAllow = false;
      }
      
      if(TrailingStop>0)
      {
         total = OrdersTotal();
         for(cnt=0;cnt<total;cnt++)
         {
            OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);

            if(OrderType()<=OP_SELL &&
               OrderSymbol()==Symbol() &&
               OrderMagicNumber()==MagicNumber)
            {
               subTrailingStop(OrderType());
            }
         }
      }
   }            

//----------------------- IF NO TRADE
   if(total==0 && EntryAllow) 
   {
//----------------------- SET BUY and SELL PRICE
      if(EntryLevel==0) EntryLevel = Bid;
   
      BuyLevel  = EntryLevel + Distance*Point;
      SellLevel = EntryLevel - Distance*Point;
   
      if((BuyLevel-Ask)<10*Point || (Bid-SellLevel)<10*Point)
      {
         Comment("Invalid Entry Price or Distance");
         return(0);
      }

      ticket = OrderSend(Symbol(),OP_SELLSTOP,Lots,SellLevel,Slippage,SellLevel+StopLoss*Point,SellLevel-TakeProfit*Point
      ,TicketComment,MagicNumber,0,Red);
      
      ticket = OrderSend(Symbol(),OP_BUYSTOP,Lots,BuyLevel,Slippage,BuyLevel-StopLoss*Point,BuyLevel+TakeProfit*Point
      ,TicketComment,MagicNumber,0,Green);
      EntryAllow = false;
      return(0);
   }      
   
   return(0);
}

//----------------------- END PROGRAM

//+------------------------------------------------------------------+
//| FUNCTION DEFINITIONS
//+------------------------------------------------------------------+

//----------------------- MONEY MANAGEMENT FUNCTION  
//----------------------- SOURCE : CODERSGURU
double subLotSize()
{
     double lotMM = MathCeil(AccountFreeMargin() *  Risk / 1000) / 100;
	  
	  if(AccountIsMicro==false) //normal account
	  {
	     if(lotMM < 0.1)                  lotMM = Lots;
	     if((lotMM > 0.5) && (lotMM < 1)) lotMM = 0.5;
	     if(lotMM > 1.0)                  lotMM = MathCeil(lotMM);
	     if(lotMM > 100)                  lotMM = 100;
	  }
	  else //micro account
	  {
	     if(lotMM < 0.01)                 lotMM = Lots;
	     if(lotMM > 1.0)                  lotMM = MathCeil(lotMM);
	     if(lotMM > 100)                  lotMM = 100;
	  }
	  
	  return (lotMM);
}

//----------------------- NUMBER OF ORDER BASE ON SYMBOL AND MAGICNUMBER FUNCTION
int subTotalTrade()
{
   int
      cnt, 
      total = 0;

   for(cnt=0;cnt<OrdersTotal();cnt++)
   {
      OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES);
      if(OrderType()<=OP_SELL &&
         OrderSymbol()==Symbol() &&
         OrderMagicNumber()==MagicNumber) total++;
   }
   return(total);
}


//----------------------- DELETE ORDER FUNCTION
void subDeleteOrder()
{
   int
      cnt, 
      total = 0;

   total = OrdersTotal();
   for(cnt=total-1;cnt>=0;cnt--)
   {
      OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);

      if(OrderSymbol()==Symbol() &&
         OrderMagicNumber()==MagicNumber)
      {
         switch(OrderType())
         {
            case OP_BUYLIMIT :
            case OP_BUYSTOP  :
            case OP_SELLLIMIT:
            case OP_SELLSTOP :
               OrderDelete(OrderTicket());
         }
      }
   }      
}

//----------------------- TRAILING STOP FUNCTION
//----------------------- SOURCE   : CODERSGURU
//----------------------- MODIFIED : FIREDAVE
void subTrailingStop(int Type)
{
   if(Type==OP_BUY)   // buy position is opened   
   {
      if(Bid-OrderOpenPrice()>Point*TrailingStop &&
         OrderStopLoss()<Bid-Point*TrailingStop)
      {
         OrderModify(OrderTicket(),OrderOpenPrice()
         ,Bid-Point*TrailingStop
         ,OrderTakeProfit()
         ,0,Green);

         return(0);
      }
   }

   if(Type==OP_SELL)   // sell position is opened   
   {
      if(OrderOpenPrice()-Ask>Point*TrailingStop)
      {
      if(OrderStopLoss()>Ask+Point*TrailingStop || OrderStopLoss()==0)
      {
         OrderModify(OrderTicket(),OrderOpenPrice(),Ask+Point*TrailingStop,OrderTakeProfit(),0,Red);
         return(0);
      }
      }
   }
}

//----------------------- GENERATE MAGIC NUMBER BASE ON SYMBOL AND TIME FRAME FUNCTION
//----------------------- SOURCE   : PENGIE
//----------------------- MODIFIED : FIREDAVE
int subGenerateMagicNumber(int MagicNumber, string symbol, int timeFrame)
{
   int isymbol = 0;
   if (symbol == "EURUSD")       isymbol = 1;
   else if (symbol == "GBPUSD")  isymbol = 2;
   else if (symbol == "USDJPY")  isymbol = 3;
   else if (symbol == "USDCHF")  isymbol = 4;
   else if (symbol == "AUDUSD")  isymbol = 5;
   else if (symbol == "USDCAD")  isymbol = 6;
   else if (symbol == "EURGBP")  isymbol = 7;
   else if (symbol == "EURJPY")  isymbol = 8;
   else if (symbol == "EURCHF")  isymbol = 9;
   else if (symbol == "EURAUD")  isymbol = 10;
   else if (symbol == "EURCAD")  isymbol = 11;
   else if (symbol == "GBPUSD")  isymbol = 12;
   else if (symbol == "GBPJPY")  isymbol = 13;
   else if (symbol == "GBPCHF")  isymbol = 14;
   else if (symbol == "GBPAUD")  isymbol = 15;
   else if (symbol == "GBPCAD")  isymbol = 16;
   else                          isymbol = 17;
   if(isymbol<10) MagicNumber = MagicNumber * 10;
   return (StrToInteger(StringConcatenate(MagicNumber, isymbol, timeFrame)));
}


//----------------------- PRINT COMMENT FUNCTION
//----------------------- SOURCE : CODERSGURU
void subPrintDetails()
{
   string sComment   = "";
   string sp         = "----------------------------------------\n";
   string NL         = "\n";

   sComment = sp;
   sComment = sComment + "TakeProfit=" + DoubleToStr(TakeProfit,0) + " | ";
   sComment = sComment + "TrailingStop=" + DoubleToStr(TrailingStop,0) + " | ";
   sComment = sComment + "StopLoss=" + DoubleToStr(StopLoss,0) + NL; 
   sComment = sComment + sp;
   sComment = sComment + "Lots=" + DoubleToStr(Lots,2) + " | ";
   sComment = sComment + "MM=" + subBoolToStr(MM) + " | ";
   sComment = sComment + "Risk=" + DoubleToStr(Risk,0) + "%" + NL;
   sComment = sComment + sp;
  
   Comment(sComment);
}


//----------------------- BOOLEN VARIABLE TO STRING FUNCTION
//----------------------- SOURCE : CODERSGURU
string subBoolToStr ( bool value)
{
   if(value) return ("True");
   else return ("False");
}


//----------------------- END FUNCTION