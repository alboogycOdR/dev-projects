//+------------------------------------------------------------------+
//|                        Goldflight's Round Number auto-trader.mq4 |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+

#property show_inputs
#include <WinUser32.mqh>
#include <stdlib.mqh>
#define  NL    "\n"
#define  highline "Next high round number"
#define  highlinetradetrigger "Next buy trade trigger"
#define  lowline "Next low round number"
#define  lowlinetradetrigger "Next sell trade trigger"





extern string     bs="----Basic stuff----";
   extern double     Lot=0.01;
   extern int        MagicNumber=615046;
   extern string     TradeComment="Round numbers";
   extern bool       CriminalIsECN=TRUE;
   extern int        TradeTriggerPips=15;
   extern bool       ReverseTradeDirection=false;
   extern bool       TakeFirstTrade=true;
   extern bool       TakeSecondTrade=true;
extern string     tpsl="----Stop loss----";
   extern int        StopLoss=20;
extern string     lcs="----Line colours----";
   extern color      BuyLineColour=Green;
   extern color      SellLineColour=Red;
extern string     TSL="----Trailing stop loss----";
   extern int        TrailingStopPips=15;
   extern int        BreakEvenProfitPips=1;
extern string     trs="----Odds and ends----";
   extern int        DisplayGapSize=30;
   extern bool       DeleteLinesOnExit=true;





//Matt's O-R stuff
   int 	            O_R_Setting_max_retries 	= 10;
   double 	         O_R_Setting_sleep_time 		= 4.0; /* seconds */
   double 	         O_R_Setting_sleep_max 		= 15.0; /* seconds */
   

//Round numbers
double            RoundNumberHigh, RoundNumberHighTrigger;
double            RoundNumberLow, RoundNumberLowTrigger;
//Misc stuff
   string            ScreenMessage, Gap;
   bool              RobotDisabled;
   string            DisabledMessage;
   int               Spread;


void DisplayUserFeedback()
{
   ScreenMessage = "";
   
   ScreenMessage = StringConcatenate(ScreenMessage, Gap, NL);
   ScreenMessage = StringConcatenate(ScreenMessage, Gap, "Next high round number = ", DoubleToStr(RoundNumberHigh, Digits), NL);
   ScreenMessage = StringConcatenate(ScreenMessage, Gap, "Next low round number = ", DoubleToStr(RoundNumberLow, Digits), NL);
   ScreenMessage = StringConcatenate(ScreenMessage, Gap, "Lot size = ", Lot, NL);
   ScreenMessage = StringConcatenate(ScreenMessage, Gap, "Stop loss = ", StopLoss, NL);
   ScreenMessage = StringConcatenate(ScreenMessage,Gap, "Magic number = ", MagicNumber, NL);
   ScreenMessage = StringConcatenate(ScreenMessage, Gap, "Trade comment = ", TradeComment, NL);
   double spread = MarketInfo(Symbol(), MODE_SPREAD);
   ScreenMessage = StringConcatenate(ScreenMessage, Gap, "Spread = ", spread, NL);
   
   ScreenMessage= StringConcatenate(ScreenMessage, NL);
   Comment(ScreenMessage);
   
   
}//void DisplayUserFeedback()


//+------------------------------------------------------------------+
//| expert Initialization function                                   |
//+------------------------------------------------------------------+

int init()
{

   int multiplier;
   if(Digits == 2 || Digits == 4) multiplier = 1;
   if(Digits == 3 || Digits == 5) multiplier = 10;
   if(Digits == 6) multiplier = 100;   
   if(Digits == 7) multiplier = 1000;   
   
   TradeTriggerPips*= multiplier;
   StopLoss*= multiplier;
   BreakEvenProfitPips*= multiplier;



   Gap="";
   if (DisplayGapSize >0)
   {
      for (int cc=0; cc< DisplayGapSize; cc++)
      {
         Gap = StringConcatenate(Gap, " ");
      }   
}
   
   GetNextRoundNumbers();
         
   Comment(".........Waiting for a tick");
   start();
    
  }
  
//+------------------------------------------------------------------+
//| expert Deinitialization function                                 |
//+------------------------------------------------------------------+

int deinit()
{

    if (DeleteLinesOnExit) DeleteLines();
    Comment("");

}


//FOR EACH EXISTING POSITION, DO TRAIL
bool DoesTradeExist()
{
   //Searches for open trades
   Print("REACHED THIS POINT   DoesTradeExist");
   
   if (OrdersTotal() == 0) 
   {
      return(false); //nothing to do
   }   

   bool found = false;
   
   for (int cc = OrdersTotal() - 1; cc >= 0; cc--)
   {
      if (!OrderSelect(cc, SELECT_BY_POS) ) continue;

      if (OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol() ) 
      {
         found = true;
         if (OrderProfit() > 0) 
            TrailingStopLoss();

      }    
   } 
   
   
   return(found);
   
}//End bool DoesTradeExist()



bool SendSingleTrade(int type, string comment, double lotsize, double price, double stop, double take, int magic)
{
   
   int slippage = 10;
   if (Digits == 3 || Digits == 5) 
         slippage = 100;
   
   color col = Red;
   if (type == OP_BUY || type == OP_BUYSTOP) 
         col = Green;
   
   int expiry = 0;
   //if (SendPendingTrades) 
     // expiry = TimeCurrent() + (PendingExpiryMinutes * 60);
   
   
//   if (!CriminalIsECN) 
//         int ticket = OrderSend(Symbol(),type, lotsize, price, slippage, stop, take, comment, magic, expiry, col);
//   
//   
//   //Is a 2 stage criminal
//   if (CriminalIsECN)
//   {
      int ticket = OrderSend(Symbol(),type, lotsize, price, slippage, 0, 0, comment, magic, expiry, col);
	   if (stop != 0)
	   {
		   if (ticket > 0)
		   bool result = OrderModify(ticket, OrderOpenPrice(), stop, take, 0, CLR_NONE);
		   if (!result)
		   {
		       int err=GetLastError();
             Print(Symbol(), " ", type," SL  order modify failed with error(",err,"): ",ErrorDescription(err));               
		   }//if (!result)			  
	   }//if (Sl != 0)
      
      
   //}//if (CriminalIsECN)
   
   //Error trapping for both
   if (ticket < 0)
   {
      string stype;
      if (type == OP_BUY) stype = "OP_BUY";
      if (type == OP_BUYSTOP) stype = "OP_BUYSTOP";
      if (type == OP_SELL) stype = "OP_SELL";
      if (type == OP_SELLSTOP) stype = "OP_SELLSTOP";
      err=GetLastError();
      Alert(Symbol(), " ", stype," Goldflight order send failed with error(",err,"): ",ErrorDescription(err));
      Print(Symbol(), " ", stype," Goldflight order send failed with error(",err,"): ",ErrorDescription(err));
      return(false);
   }//if (ticket < 0)  
   
   //Make sure the trade has appeared in the platform's history to avoid duplicate trades
   O_R_CheckForHistory(ticket); 
   
   //Got this far, so trade send succeeded
   return(true);
 
   
}//End bool SendSingleTrade(int type, string comment, double lotsize, double price, double stop, double take)



void GetNextRoundNumbers()
{
   //Finds the nearest big numbers to the market price.
   //Saves these in RoundNumberHigh[index] and RoundNumberLow[index]
   Print("GetNextRoundNumbers " + TimeCurrent());
   
   
   RefreshRates();
   
   //Jpy pairs
   if (Digits == 2 || Digits == 3)
   {
       Print("Digits == 2 || Digits == 3");
      int price = Ask;//Truncates the quote
      RoundNumberLow = price;
      RoundNumberHigh = price + 1;
      
            
   }//if (Digits == 2 || Digits == 3)

   //non-Jpy pairs
   if (Digits == 4 || Digits == 5)
   {
       Print("Digits == 4 || Digits == 5");
      string sprice = DoubleToStr(Ask, Digits);
      if (Ask >= 10) sprice = StringSubstr(sprice, 0, 5);       
      if (Ask < 10) sprice = StringSubstr(sprice, 0, 4);       
      RoundNumberLow = StrToDouble(sprice);
      RoundNumberHigh = RoundNumberLow + 0.01;
      
      
      
   }//if (Digits == 4 || Digits == 5)

   //Calculate trade trigger levels
   RoundNumberHighTrigger = NormalizeDouble(RoundNumberHigh - (TradeTriggerPips * Point), Digits);
   RoundNumberLowTrigger = NormalizeDouble(RoundNumberLow + (TradeTriggerPips * Point), Digits);
   

   //Draw the lines
   double hl, ll;//Hi-lo lines
   hl = ObjectGet(highline, OBJPROP_PRICE1);
   ll = ObjectGet(lowline, OBJPROP_PRICE1);
   

   Print("BEFORE CHECK  LN 270");
   if (Bid > hl || Bid < ll)
   {
      Print("     LN 272   Bid > hl || Bid < ll ");
      DeleteLines();
      DrawLines(highline, RoundNumberHigh, BuyLineColour, STYLE_SOLID, 2);
      DrawLines(highlinetradetrigger, RoundNumberHighTrigger, BuyLineColour, STYLE_DASH, 1);
      DrawLines(lowline, RoundNumberLow, SellLineColour, STYLE_SOLID, 2);
      DrawLines(lowlinetradetrigger, RoundNumberLowTrigger, SellLineColour, STYLE_DASH, 1);
   }//if (Bid > hl || Bid < ll)
   
   
}//End void GetNextRoundNumbers()

void DeleteLines()
{
   ObjectDelete(highline);
   ObjectDelete(highlinetradetrigger);
   ObjectDelete(lowline);
   ObjectDelete(lowlinetradetrigger);
   
}//void DeleteLines()


void DrawLines(string name, double price, color col, int style, int width)
{

   ObjectDelete(name);
   

   ObjectCreate(name, OBJ_HLINE, 0, TimeCurrent(), price);
   ObjectSet(name, OBJPROP_COLOR, col);
   ObjectSet(name, OBJPROP_WIDTH, width);
   ObjectSet(name, OBJPROP_STYLE, style);
   ObjectSet(name, OBJPROP_RAY, false);
   
   
}//End void DrawLines(string name, double price, color col, int style, int type



void LookForTradingOpportunity()
{
     Print("====================================");
     Print("look for trading opportunity");
   //if (IsTradeContextBusy() ) return;
   
   double stop, take;
   RefreshRates();
   bool result;
   double hi, lo;
   
   
   hi = ObjectGet(highlinetradetrigger, OBJPROP_PRICE1);
   lo = ObjectGet(lowlinetradetrigger, OBJPROP_PRICE1);
   
   double MinStop = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
   
   //Trade according to Goldflight's original
   if (!ReverseTradeDirection)
   {
      Print("REACHED THIS POINT    !ReverseTradeDirection");
      
      
      //Long
      if (Ask >= hi && Open[0] < hi && hi > 0)
      {
         Print("REACHED THIS POINT   Ask >= hi && Open[0] < hi && hi > 0");
         take = ObjectGet(highline, OBJPROP_PRICE1);            
         //Minimum stop level check
         if (take - Ask < MinStop) return;
      
         if (TakeFirstTrade)
         {
            //First trade with tp
            result = false;
            while (result == false)
            {
               if (StopLoss > 0) stop = NormalizeDouble(Ask - (StopLoss * Point), Digits);
               result = SendSingleTrade(OP_BUY, TradeComment, Lot, Ask, stop, take, MagicNumber);
            }//while (result = false)
         }//if (TakeFirstTrade)
         
         if (TakeSecondTrade)
         {            
            //Second trade. No tp - will close at sl or trailing stop
            result = false;
            while (result == false)
            {
               if (StopLoss > 0) stop = NormalizeDouble(Ask - (StopLoss * Point), Digits);
               result = SendSingleTrade(OP_BUY, TradeComment, Lot, Ask, stop, 0, MagicNumber);
            }//while (result = false)
         }//if (TakeSecondTrade)   
       }//if (Ask >= hi && Open[0] < hi && hi > 0)
    


      //Short
      if (Bid <= lo && Open[0] > lo && lo > 0)
      {

         Print("Bid <= lo && Open[0] > lo && lo > 0");
         take = ObjectGet(lowline, OBJPROP_PRICE1);            
         //Minimum stop level check
         if (Bid - take < MinStop) return;
      
         if (TakeFirstTrade)
         {
            //First trade with tp
            result = false;
            while (!result)
            {
               if (StopLoss > 0) stop = NormalizeDouble(Bid + (StopLoss * Point), Digits);
               result = SendSingleTrade(OP_SELL, TradeComment, Lot, Bid, stop, take, MagicNumber);   
            }//While (!result)
         }//if (TakeFirstTrade)
         
         if (TakeSecondTrade)
         {
            //Second trade. No tp - will close at sl or trailing stop
            result = false;
            while (!result)
            {
               if (StopLoss > 0) stop = NormalizeDouble(Bid + (StopLoss * Point), Digits);
               result = SendSingleTrade(OP_SELL, TradeComment, Lot, Bid, stop, 0, MagicNumber);   
            }//While (!result)
         }//if (TakeSecondTrade)   
      }//if (Bid <= lo && Open[1] > lo && lo > 0)
   }//if (!ReverseTradeDirection)
   
   //Goldflight's original appears to be a loser, so try reversing
   if (ReverseTradeDirection)
   {
      Print("REVERSETRADEDIR");
      //Short
      if (Bid >= hi && Open[0] < hi && hi > 0)
      {
         
         take = ObjectGet(lowline, OBJPROP_PRICE1);            
         //Minimum stop level check
         if (Bid - take < MinStop) return;
      
         if (TakeFirstTrade)
         {
            //First trade with tp
            result = false;
            while (!result)
            {
               if (StopLoss > 0) stop = NormalizeDouble(Bid + (StopLoss * Point), Digits);
               result = SendSingleTrade(OP_SELL, TradeComment, Lot, Bid, stop, take, MagicNumber);   
            }//While (!result)
         }//if (TakeFirstTrade)
         
         if (TakeSecondTrade)
         {
            //Second trade. No tp - will close at sl or trailing stop
            result = false;
            while (!result)
            {
               if (StopLoss > 0) stop = NormalizeDouble(Bid + (StopLoss * Point), Digits);
               result = SendSingleTrade(OP_SELL, TradeComment, Lot, Bid, stop, 0, MagicNumber);   
            }//While (!result)
         }//if (TakeSecondTrade)
      }//if (Bid >= hi && Open[0] < hi && hi > 0)


      //Long
      if (Ask <= lo && Open[0] > lo && lo > 0)
      {
         take = ObjectGet(highline, OBJPROP_PRICE1);            
         //Minimum stop level check
         if (take - Ask < MinStop) return;
      
         if (TakeFirstTrade)
         {
            //First trade with tp
            result = false;
            while (result == false)
            {
               if (StopLoss > 0) stop = NormalizeDouble(Ask - (StopLoss * Point), Digits);
               result = SendSingleTrade(OP_BUY, TradeComment, Lot, Ask, stop, take, MagicNumber);
            }//while (result = false)
         }//if (TakeFirstTrade)
         
         if (TakeSecondTrade)
         {
            //Second trade. No tp - will close at sl or trailing stop
            result = false;
            while (result == false)
            {
               if (StopLoss > 0) stop = NormalizeDouble(Ask - (StopLoss * Point), Digits);
               result = SendSingleTrade(OP_BUY, TradeComment, Lot, Ask, stop, 0, MagicNumber);
            }//while (result = false)
         }//if (TakeSecondTrade)
         
      }//if (Ask <= lo && Open[0] > lo && lo > 0)
   }//if (ReverseTradeDirection)
   

}//void LookForTradingOpportunity()

//=============================================================================
//                           O_R_CheckForHistory()
//
//  This function is to work around a very annoying and dangerous bug in MT4:
//      immediately after you send a trade, the trade may NOT show up in the
//      order history, even though it exists according to ticket number.
//      As a result, EA's which count history to check for trade entries
//      may give many multiple entries, possibly blowing your account!
//
//  This function will take a ticket number and loop until
//  it is seen in the history.
//
//  RETURN VALUE:
//     TRUE if successful, FALSE otherwise
//
//
//  FEATURES:
//     * Re-trying under some error conditions, sleeping a random
//       time defined by an exponential probability distribution.
//
//     * Displays various error messages on the log for debugging.
//
//  ORIGINAL AUTHOR AND DATE:
//     Matt Kennel, 2010
//
//=============================================================================
bool O_R_CheckForHistory(int ticket)
{
   //My thanks to Matt for this code. He also has the undying gratitude of all users of my trading robots
   
   int lastTicket = OrderTicket();

   int cnt = 0;
   int err = GetLastError(); // so we clear the global variable.
   err = 0;
   bool exit_loop = false;
   bool success=false;

   while (!exit_loop) {
      /* loop through open trades */
      int total=OrdersTotal();
      for(int c = 0; c < total; c++) {
         if(OrderSelect(c,SELECT_BY_POS,MODE_TRADES) == true) {
            if (OrderTicket() == ticket) {
               success = true;
               exit_loop = true;
            }
         }
      }
      if (cnt > 3) {
         /* look through history too, as order may have opened and closed immediately */
         total=OrdersHistoryTotal();
         for(c = 0; c < total; c++) {
            if(OrderSelect(c,SELECT_BY_POS,MODE_HISTORY) == true) {
               if (OrderTicket() == ticket) {
                  success = true;
                  exit_loop = true;
               }
            }
         }
      }

      cnt = cnt+1;
      if (cnt > O_R_Setting_max_retries) {
         exit_loop = true;
      }
      if (!(success || exit_loop)) {
         Print("Did not find #"+ticket+" in history, sleeping, then doing retry #"+cnt);
         O_R_Sleep(O_R_Setting_sleep_time, O_R_Setting_sleep_max);
      }
   }
   // Select back the prior ticket num in case caller was using it.
   if (lastTicket >= 0) {
      OrderSelect(lastTicket, SELECT_BY_TICKET, MODE_TRADES);
   }
   if (!success) {
      Print("Never found #"+ticket+" in history! crap!");
   }
   return(success);
}//End bool O_R_CheckForHistory(int ticket)

//=============================================================================
//                              O_R_Sleep()
//
//  This sleeps a random amount of time defined by an exponential
//  probability distribution. The mean time, in Seconds is given
//  in 'mean_time'.
//  This returns immediately if we are backtesting
//  and does not sleep.
//
//=============================================================================
void O_R_Sleep(double mean_time, double max_time)
{
   if (IsTesting()) {
      return;   // return immediately if backtesting.
   }

   double p = (MathRand()+1) / 32768.0;
   double t = -MathLog(p)*mean_time;
   t = MathMin(t,max_time);
   int ms = t*1000;
   if (ms < 10) {
      ms=10;
   }
   Sleep(ms);
}//End void O_R_Sleep(double mean_time, double max_time)

void TrailingStopLoss()
{
      
   
   
   bool result;
   double sl=OrderStopLoss(); //Stop loss
   double BuyStop=0, SellStop=0;
   double hl, ll;//Hi-lo lines
   hl = ObjectGet(highline, OBJPROP_PRICE1);
   ll = ObjectGet(lowline, OBJPROP_PRICE1);
   
   if (OrderType()==OP_BUY) 
      {
         //Breakeven
         if (OrderStopLoss() < OrderOpenPrice() && Bid >= hl) sl = NormalizeDouble(OrderOpenPrice() + (BreakEvenProfitPips * Point), Digits);         
         {
            result = OrderModify(OrderTicket(),OrderOpenPrice(),sl,OrderTakeProfit(),0,CLR_NONE);
            if (result)
            {
               Print("Trailing stop updated: ", OrderSymbol(), ": SL ", sl, ": Ask ", Ask);
            }//if (result) 
            else
            {
               int err=GetLastError();
               Print(OrderSymbol(), " Buy order modify failed with error(",err,"): ",ErrorDescription(err));
            }//else

         }//if (OrderStopLoss() < OrderOpenPrice()) sl = OrderOpenPrice() && Bid >= hiline)
         
         
         //Trail
		   if (Bid >= OrderOpenPrice() + (TrailingStopPips*Point))
		   {
		       if (OrderStopLoss() < OrderOpenPrice()) sl = OrderOpenPrice();
		       if (Bid > sl +  (TrailingStopPips*Point))
		       {
		          sl= Bid - (TrailingStopPips*Point);
		          while(IsTradeContextBusy()) Sleep(100);
		          result = OrderModify(OrderTicket(),OrderOpenPrice(),sl,OrderTakeProfit(),0,CLR_NONE);
               if (result)
               {
                  Print("Trailing stop updated: ", OrderSymbol(), ": SL ", sl, ": Ask ", Ask);
               }//if (result) 
               else
               {
                  err=GetLastError();
                  Print(OrderSymbol(), " Buy order modify failed with error(",err,"): ",ErrorDescription(err));
               }//else
   
		       }//if (Bid > sl +  (TrailingStopPips*Point))
		   }//if (Bid >= OrderOpenPrice() + (TrailingStopPips*Point))
      }//if (OrderType()==OP_BUY) 

      if (OrderType()==OP_SELL) 
      {
		      
	      //Breakeven
         if (OrderStopLoss() > OrderOpenPrice() && Ask <= ll) sl = NormalizeDouble(OrderOpenPrice() - (BreakEvenProfitPips * Point), Digits);
         {
            if (OrderStopLoss() > OrderOpenPrice()) sl = OrderOpenPrice();
		       result = OrderModify(OrderTicket(),OrderOpenPrice(),sl,OrderTakeProfit(),0,CLR_NONE);
            if (result)
            {
               Print("Trailing stop updated: ", OrderSymbol(), ": SL ", sl, ": Ask ", Ask);
            }//if (result) 
            else
            {
               err=GetLastError();
               Print(OrderSymbol(), " Buy order modify failed with error(",err,"): ",ErrorDescription(err));
            }//else
         }//if (OrderStopLoss() > OrderOpenPrice() && Ask <= lowline) sl = OrderOpenPrice();         

         if (Ask <= OrderOpenPrice() - (TrailingStopPips*Point))
		   {
         	 //Trail
		       if (Ask < sl -  (TrailingStopPips*Point))
		       {
	               sl= Ask + (TrailingStopPips*Point);
  	               while(IsTradeContextBusy()) Sleep(100);
		            result = OrderModify(OrderTicket(),OrderOpenPrice(),sl,OrderTakeProfit(),0,CLR_NONE);
                  if (result)
                  {
                     Print("Trailing stop updated: ", OrderSymbol(), ": SL ", sl, ": Bid ", Bid);
                  }//if (result)
                  else
                  {
                     err=GetLastError();
                     Print(OrderSymbol(), " Sell order modify failed with error(",err,"): ",ErrorDescription(err));
                  }//else
    
		       }//if (Ask < sl -  (TrailingStopPips*Point))
		   }//if (Ask <= OrderOpenPrice() - (TrailingStopPips*Point))
      }//if (OrderType()==OP_SELL) 

      
} // End of TrailingStopLoss sub


//+------------------------------------------------------------------+
//| expert Start function                                            |
//+------------------------------------------------------------------+

int start()
{
    
   Print("REACHED THIS POINT    START 1");
   //Check for open trade.
   if (DoesTradeExist() ) 
   {return;}

   Print("REACHED THIS POINT   START 2");

   GetNextRoundNumbers();
    
   LookForTradingOpportunity();
       
   DisplayUserFeedback();
      
   
}//End start()


