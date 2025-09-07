


// Helper function to convert string to wide char array (ushort)
void StringToWideCharArray(const string &src, ushort &dest[])
{
   int length = StringLen(src);
   ArrayResize(dest, length + 1);  // Resize the destination array to fit the string + null-terminator
   for(int i = 0; i < length; i++) {
      dest[i] = (ushort)src[i];  // Convert each character to a wide character
   }
   dest[length] = 0;  // Null-terminate the wide character array
}

//+------------------------------------------------------------------+
//|          Determine signal with arrow repaint stratey              |
//|  we get the signals from the indicator, then determine how many  |
//|  times theindicator repaints the same signal and it repaints a   |
//|           certain times we place a buy or sell order             |
//+------------------------------------------------------------------+
int ArrowRepaintStratey(double sellValue, double buyValue)
{

   if(buyValue == 0 && sellValue == 0) {
      current_Repaint = 0;
      current_signal_value = 0;
   }
   else { //if there a sinals from indicator
      //we reset repaint values if last signal was buy and current signal is sell and vice versa for last sell and current by
      //this makes sure we only count repaints for the current sinal only
      if((buyValue > 0 && !Last_Signal_buy) || (sellValue > 0 && Last_Signal_buy)) {
         current_Repaint = 0;
         current_signal_value = 0;
      }
      if(buyValue > 0) { //current signal is buy
         Last_Signal_buy = true; //we mke sure that we indicate the signal is a buy for the next call
         //set the current signal value to indicator buy value we dont count the first signal occurence as repaint
         if(current_signal_value == 0)
            current_signal_value = buyValue;
         //if current signal value is different then there was a repaint and we adjust values accordingly
         if(current_signal_value != buyValue) {
            current_Repaint++;
            current_signal_value = buyValue;
         }
         Comment("Buy Repaint: ",current_Repaint);
         Print("Buy Repaint: ",current_Repaint);
         //repaint requirements are met so we reset values and return a buy back so that e can place order
         if(current_Repaint >= Number_Of_Repaint) {
            current_Repaint = 0;
            current_signal_value = 0;
            return OP_BUY;
         }
      }
      if(sellValue > 0) { //current signal is sell
         Last_Signal_buy = false; //we mke sure that we indicate the signal is a sell for the next call
         //set the current signal value to indicator buy value we dont count the first signal occurence as repaint
         if(current_signal_value == 0)
            current_signal_value = sellValue;
         //if current signal value is different then there was a repaint and we adjust values accordingly
         if(current_signal_value != sellValue) {
            current_Repaint++;
            current_signal_value = sellValue;
         }
         Comment("Sell Repaint: ",current_Repaint);
         Print("Sell Repaint: ",current_Repaint);
         //repaint requirements are met so we reset values and return a buy back so that e can place order
         if(current_Repaint >= Number_Of_Repaint) {
            current_Repaint = 0;
            current_signal_value = 0;
            return OP_SELL;
         }
      }
   }
   return -1; //if e get to this point then there as never a signal or repaint taret hasnt been met yet
}

//+------------------------------------------------------------------+
//|                         PLACE BUY STOP                           |
//+------------------------------------------------------------------+
void Buy_Stop(double bs)
{
   double  Ask=SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double  Bid=SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double stops=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL) * Point();
   //Print("_____________________________");
   //Print(__FUNCTION__);
   long    Ticket;
   double OrderDistance   = NormalizeDouble(Limit * Point(), Digits()); //how far against the current price to place order
   double orderPrice      = NormalizeDouble(Ask+OrderDistance,Digits());
   double StopLoss        = NormalizeDouble(Ask - (SLoss+ MarketInfo(Symbol(),MODE_SPREAD)) * Point(), Digits());
   double orderPrice_Sell = NormalizeDouble(Bid-OrderDistance,Digits());
   double StopLoss_Sell   = NormalizeDouble(Bid + (SLoss+ MarketInfo(Symbol(),MODE_SPREAD)) * Point(), Digits());
   if(Trading_Pattern==Condition_1) {
      if(bs>0 && (Ask==bs || Ask>bs)) {
         Ticket = OrderSend(Symbol(),OP_BUY,lot,Ask,3,StopLoss,0,Comment_,MyMagicNumber,0,Lime);
         ObjectDelete(0,HL_BS);
         if(Ticket<=0)
            Print("BUYSTOP Send Error Code: ",GetLastError()," OP: ",orderPrice_Sell," SL: ",StopLoss_Sell," Bid: ",Bid," Ask: ",Ask);
      }
   }
   else if(Trading_Pattern==Condition_2 || Trading_Pattern==Condition_4) {
      if(bs>0 && (Bid==bs || Bid>bs)) {
         Ticket = OrderSend(Symbol(),OP_SELL,lot,Bid,3,StopLoss_Sell,0,Comment_,MyMagicNumber,0,Lime);
         ObjectDelete(0,HL_BS);
         if(Ticket<=0)
            Print("SELLLIMIT Send Error Code: ",GetLastError()," OP: ",orderPrice," SL: ",StopLoss_Sell," Bid: ",Bid," Ask: ",Ask);
      }
   }
   if(Trading_Pattern==Condition_3) {
      if(bs>0 && (Ask==bs || Ask>bs)) {
         Ticket = OrderSend(Symbol(),OP_BUY,lot,Ask,3,StopLoss,0,Comment_,MyMagicNumber,0,Lime);
         ObjectDelete(0,HL_BS);
         if(Ticket<=0)
            Print("BUYSTOP Send Error Code: ",GetLastError()," OP: ",orderPrice," SL: ",StopLoss_Sell," Bid: ",Bid," Ask: ",Ask);
      }
   }
}
//+------------------------------------------------------------------+
//|                        PLACE SELL STOP                           |
//+------------------------------------------------------------------+
void Sell_Stop(double ss)
{
   double  Ask=SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double  Bid=SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double stops=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL) * Point();
   //Print("_____________________________");
   //Print(__FUNCTION__);
   long    Ticket;
   double OrderDistance  = NormalizeDouble(Limit * Point(), Digits()); //how far against the current price to place order
   double orderPrice     = NormalizeDouble(Bid-OrderDistance,Digits());
   double StopLoss       = NormalizeDouble(Bid + (SLoss+ MarketInfo(Symbol(),MODE_SPREAD)) * Point(), Digits());
   double orderPrice_Buy = NormalizeDouble(Ask+OrderDistance,Digits());
   double StopLoss_Buy   = NormalizeDouble(Ask - (SLoss+ MarketInfo(Symbol(),MODE_SPREAD)) * Point(), Digits());
   if(Trading_Pattern==Condition_1) {
      if(ss>0 && (Bid==ss || Bid<ss)) {
         Ticket = OrderSend(Symbol(),OP_SELL,lot,Bid,3,StopLoss,0,Comment_,MyMagicNumber,0,Lime);
         ObjectDelete(0,HL_SS);
         if(Ticket<=0)
            Print("SELLSTOP Send Error Code: ",GetLastError()," OP: ",orderPrice," SL: ",StopLoss," Bid: ",Bid," Ask: ",Ask);
      }
   }
   else if(Trading_Pattern==Condition_2 || Trading_Pattern==Condition_4) {
      if(ss>0 && (Ask==ss || Ask<ss)) {
         Ticket = OrderSend(Symbol(),OP_BUY,lot,Ask,3,StopLoss_Buy,0,Comment_,MyMagicNumber,0,Lime);
         ObjectDelete(0,HL_SS);
         if(Ticket<=0)
            Print("BUYLIMIT Send Error Code: ",GetLastError()," OP: ",orderPrice_Buy," SL: ",StopLoss_Buy," Bid: ",Bid," Ask: ",Ask);
      }
   }
   if(Trading_Pattern==Condition_3) {
      if(ss>0 && (Bid==ss || Bid<ss)) {
         Ticket=OrderSend(Symbol(),OP_SELL,lot,Bid,3,StopLoss,0,Comment_,MyMagicNumber,0,Lime);
         ObjectDelete(0,HL_SS);
         if(Ticket<=0)
            Print("SELLSTOP Send Error Code: ",GetLastError()," OP: ",orderPrice," SL: ",StopLoss," Bid: ",Bid," Ask: ",Ask);
      }
   }
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string TerminalCompany()
{
   return TerminalInfoString(TERMINAL_COMPANY);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string TerminalName()
{
   return TerminalInfoString(TERMINAL_NAME);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string TerminalPath()
{
   return TerminalInfoString(TERMINAL_PATH);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsExpertEnabled()
{
   return (bool)AccountInfoInteger(ACCOUNT_TRADE_EXPERT);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsConnected()
{
   return (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsOptimization()
{
   return (bool)MQL5InfoInteger(MQL5_OPTIMIZATION);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int Minute()
{
   MqlDateTime tm;
   TimeCurrent(tm);
   return(tm.min);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int Day()
{
   MqlDateTime tm;
   TimeCurrent(tm);
   return(tm.day);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int Year()
{
   MqlDateTime tm;
   TimeCurrent(tm);
   return(tm.year);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsTesting()
{
   return (bool)MQL5InfoInteger(MQL5_TESTING);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsVisualMode()
{
   return (bool)MQL5InfoInteger(MQL5_VISUAL_MODE);
}


//+------------------------------------------------------------------+
//|                         Trailing Stop                            |
//+------------------------------------------------------------------+
void TrailingStop()
  {
   double  Ask=SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double  Bid=SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double stops=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL) * Point();

   double TrailingStart = (trail_start+0.2)*Point()*10 ;
   double TrailingStep = (trail_step+0.2)*Point()*10;

   for(int i = OrdersTotal()-1; i>=0; i--)
      if(OrderSelect(i,SELECT_BY_POS))
         if(OrderSymbol()==Symbol() && OrderMagicNumber()==MyMagicNumber)
           {
            if(OrderType()==OP_BUY)
              {
               if(Bid > (OrderOpenPrice() + TrailingStart) && OrderStopLoss() < OrderOpenPrice() && TrailingStart > 0)
                  if(!OrderModify(OrderTicket(),OrderOpenPrice(), Bid - TrailingStart, OrderTakeProfit(), 0, clrGreen))
                     Print("Order Start Modify Error: ",GetLastError());

               if(Bid > (OrderStopLoss() + 2*TrailingStep) && OrderStopLoss() > OrderOpenPrice() && TrailingStep>0)
                  if(!OrderModify(OrderTicket(),OrderOpenPrice(), OrderStopLoss() + TrailingStep, OrderTakeProfit(), 0, clrGreen))
                     Print("Order Step Modify Error: ",GetLastError());
              }

            if(OrderType()==OP_SELL)
              {
               if(Ask < (OrderOpenPrice() - TrailingStart) && OrderStopLoss() >= OrderOpenPrice() && TrailingStart>0)
                  if(!OrderModify(OrderTicket(),OrderOpenPrice(), Ask + TrailingStart, OrderTakeProfit(), 0, clrRed))
                     Print("Order Start Modify Error: ",GetLastError());

               if(Ask < (OrderStopLoss() - 2*TrailingStep) && OrderStopLoss()<=OrderOpenPrice() && TrailingStep>0)
                  if(!OrderModify(OrderTicket(),OrderOpenPrice(), OrderStopLoss() - TrailingStep, OrderTakeProfit(), 0, clrRed))
                     Print("Order Step Modify Error: ",GetLastError());
              }
           }
  }

//+------------------------------------------------------------------+
//|             Display Account and Chart Info On Chart             |
//+------------------------------------------------------------------+
void DisplayInfo()
  {
   datetime Time[];
   int copied=CopyTime(_Symbol,PERIOD_CURRENT,0,3,Time);
   double Close[];
   int copiedC=CopyClose(_Symbol,PERIOD_CURRENT,0,3,Close);
   double High[];
   int copiedH=CopyHigh(_Symbol,PERIOD_CURRENT,0,3,High);
   double Low[];
   int copiedL=CopyLow(_Symbol,PERIOD_CURRENT,0,3,Low);
   double Open[];
   int copiedO=CopyOpen(_Symbol,PERIOD_CURRENT,0,3,Open);

//if(copied>0)
//   time=Time[0];

   int MinsLeft = (int)(Time[0]+60*Period()-TimeCurrent());  //total time left for bar to close
   int SecsLeft = MinsLeft%60;                               //Secs left for bar to close
   MinsLeft = (MinsLeft-MinsLeft%60)/60;                 //Mins left for bar to close

   Comment("Robot_HAHA_EA ©\n",
           MinsLeft," minutes ",SecsLeft," Seconds left to bar end\n",
           "_______________________________________\n",
           "HAHA_EA_",Year()," ©\n",
           "_______________________________________\n",
           "Broker: ",AccountCompany(),
           "\nActual Server Time: ",TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
           "\n_______________________________________\n",
           "Name: ",AccountName(),
           "\nAccount Number: ",AccountNumber(),
           "\nAccount Currency: ",AccountCurrency(),
           "\nAccount Leverage: ",AccountLeverage(),
           "\nAccount Type: ",AccountServer(),
           "\nBroker Spread : ",MarketInfo(Symbol(), MODE_SPREAD),
           "\n_______________________________________\n",
           "ALL ORDERS: ",OrdersTotal(),
           "\n_______________________________________\n",
           "Account BALANCE: ",AccountBalance(),
           "\nPROFIT+/-: ",AccountProfit(),
           "\nAccount EQUITY: ",AccountEquity(),
           "\nFree MARGIN: ",AccountFreeMargin(),
           "\nUsed MARGIN: ",AccountMargin(),
           "\nHL SS Price : ",DoubleToString(HL_SS_Value,Digits()),
           "\nHL BS Price : ",DoubleToString(HL_BS_Value,Digits()),
           "\n_______________________________________\n",
           "Copyright © 2024 by LB");

//create and move time object
   ObjectDelete("time");
   if(ObjectFind("time")!=0)
     {
      ObjectCreate("time",OBJ_TEXT,0,Time[0],Close[0]+0.0005);
      ObjectSetText("time","                                 <--"+(string)MinsLeft+":"+(string)SecsLeft,13,"Verdana",Yellow);
      return;
     }
   ObjectMove("time",0,Time[0],Close[0]+0.0005);
  }
//+------------------------------------------------------------------+
//|    Calculate and create Fibonacci levels from the daily chart    |
//+------------------------------------------------------------------+
/*void CalculateAndPlaceFibonacci()
  {
   datetime Time[];
   int copied=CopyTime(_Symbol,PERIOD_CURRENT,0,3,Time);
   double Close[];
   int copiedC=CopyClose(_Symbol,PERIOD_CURRENT,0,3,Close);
   double High[];
   int copiedH=CopyHigh(_Symbol,PERIOD_CURRENT,0,3,High);
   double Low[];
   int copiedL=CopyLow(_Symbol,PERIOD_CURRENT,0,3,Low);
   double Open[];
   int copiedO=CopyOpen(_Symbol,PERIOD_CURRENT,0,3,Open);
   int BarIndex=iBarShift(NULL,PERIOD_D1,Time[0])+1; //get the bar index (bar number) of the next daily candle specified by time

//get the high, low and time of the next daily candle
   double high = iHigh(NULL,PERIOD_D1,BarIndex);
   double low  = iLow(NULL,PERIOD_D1,BarIndex);
   int barTime = (int)iTime(NULL,PERIOD_D1,BarIndex);

//if the daily candle is in current week get the high and low of the next second daily
   if(TimeDayOfWeek(barTime)==0)
     {
      high= MathMax(high,iHigh(NULL,PERIOD_D1,BarIndex+1));
      low = MathMin(low,iLow(NULL,PERIOD_D1,BarIndex+1));
     }

   double barSize=high-low; //the bar size

//fibonacci colors for 3 Fibonaccis(up, down and in)
   color FiboColor1 = Red, FiboColor2 = DarkGray, FiboColor3 = SpringGreen;
   CreateFibonacci(barSize,barTime,high,low,FiboColor1,FiboColor2,FiboColor3);
  }*/
//+------------------------------------------------------------------+
//|          Create Fibonaccis using appropriate values              |
//+------------------------------------------------------------------+

/*not used - alister
void CreateFibonacci(double barSize,
                     int barTime,
                     double high,
                     double low,
                     color FiboColor1,
                     color FiboColor3,
                     color FiboColor2)
  {
//--- FiboUP Placement on chart(1st fibo)
//create fibonnacci up or change values if it already exist
   if(ObjectFind("FiboUp")==-1)
      ObjectCreate("FiboUp",OBJ_FIBO,0,barTime,high+barSize,barTime,high);
   else
     {
      ObjectSet("FiboUp",OBJPROP_TIME2,barTime);
      ObjectSet("FiboUp",OBJPROP_TIME1,barTime);
      ObjectSet("FiboUp",OBJPROP_PRICE1,high+barSize);
      ObjectSet("FiboUp",OBJPROP_PRICE2,high);
     }
//set colors and levels
   ObjectSet("FiboUp",OBJPROP_LEVELCOLOR,FiboColor1);
   ObjectSet("FiboUp",OBJPROP_FIBOLEVELS,13);
   ObjectSet("FiboUp",OBJPROP_FIRSTLEVEL,0.0);
//set level descriptions
   ObjectSetFiboDescription("FiboUp",0,"(100.0%) -  %$");
   ObjectSet("FiboUp",211,0.236);
   ObjectSetFiboDescription("FiboUp",1,"(123.6%) -  %$");
   ObjectSet("FiboUp",212,0.382);
   ObjectSetFiboDescription("FiboUp",2,"(138.2%) -  %$");
   ObjectSet("FiboUp",213,0.5);
   ObjectSetFiboDescription("FiboUp",3,"(150.0%) -  %$");
   ObjectSet("FiboUp",214,0.618);
   ObjectSetFiboDescription("FiboUp",4,"(161.8%) -  %$");
   ObjectSet("FiboUp",215,0.764);
   ObjectSetFiboDescription("FiboUp",5,"(176.4%) -  %$");
   ObjectSet("FiboUp",216,1.0);
   ObjectSetFiboDescription("FiboUp",6,"(200.0%) -  %$");
   ObjectSet("FiboUp",217,1.236);
   ObjectSetFiboDescription("FiboUp",7,"(223.6%) -  %$");
   ObjectSet("FiboUp",218,1.5);
   ObjectSetFiboDescription("FiboUp",8,"(250.0%) -  %$");
   ObjectSet("FiboUp",219,1.618);
   ObjectSetFiboDescription("FiboUp",9,"(261.8%) -  %$");
   ObjectSet("FiboUp",220,2.0);
   ObjectSetFiboDescription("FiboUp",10,"(300.0%) -  %$");
   ObjectSet("FiboUp",221,2.5);
   ObjectSetFiboDescription("FiboUp",11,"(350.0%) -  %$");
   ObjectSet("FiboUp",222,3.0);
   ObjectSetFiboDescription("FiboUp",12,"(400.0%) -  %$");
   ObjectSet("FiboUp",223,3.5);
   ObjectSetFiboDescription("FiboUp",13,"(450.0%) -  %$");
   ObjectSet("FiboUp",224,4.0);
   ObjectSetFiboDescription("FiboUp",14,"(500.0%) -  %$");
//make fibonacci rays and set it in the backgroud of the chart
   ObjectSet("FiboUp",OBJPROP_RAY,true);
   ObjectSet("FiboUp",OBJPROP_BACK,true);

//=====================================================================================================
//--- FiboDn Placement on chart(2nd fibo)
//create fibonnacci dow or change values if it already exist
   if(ObjectFind("FiboDn")==-1)
      ObjectCreate("FiboDn",OBJ_FIBO,0,barTime,low-barSize,barTime,low);
   else
     {
      ObjectSet("FiboDn",OBJPROP_TIME2,barTime);
      ObjectSet("FiboDn",OBJPROP_TIME1,barTime);
      ObjectSet("FiboDn",OBJPROP_PRICE1,low-barSize);
      ObjectSet("FiboDn",OBJPROP_PRICE2,low);
     }
//set colors and levels
   ObjectSet("FiboDn",OBJPROP_LEVELCOLOR,FiboColor3);
   ObjectSet("FiboDn",OBJPROP_FIBOLEVELS,19);
   ObjectSet("FiboDn",OBJPROP_FIRSTLEVEL,0.0);
//set level descriptions
   ObjectSetFiboDescription("FiboDn",0,"(0.0%) -  %$");
   ObjectSet("FiboDn",211,0.236);
   ObjectSetFiboDescription("FiboDn",1,"(-23.6%) -  %$");
   ObjectSet("FiboDn",212,0.382);
   ObjectSetFiboDescription("FiboDn",2,"(-38.2%) -  %$");
   ObjectSet("FiboDn",213,0.5);
   ObjectSetFiboDescription("FiboDn",3,"(-50.0%) -  %$");
   ObjectSet("FiboDn",214,0.618);
   ObjectSetFiboDescription("FiboDn",4,"(-61.8%) -  %$");
   ObjectSet("FiboDn",215,0.764);
   ObjectSetFiboDescription("FiboDn",5,"(-76.4%) -  %$");
   ObjectSet("FiboDn",216,1.0);
   ObjectSetFiboDescription("FiboDn",6,"(-100.0%) -  %$");
   ObjectSet("FiboDn",217,1.236);
   ObjectSetFiboDescription("FiboDn",7,"(-123.6%) -  %$");
   ObjectSet("FiboDn",218,1.382);
   ObjectSetFiboDescription("FiboDn",8,"(-138.2%) -  %$");
   ObjectSet("FiboDn",219,1.5);
   ObjectSetFiboDescription("FiboDn",9,"(-150.0%) -  %$");
   ObjectSet("FiboDn",220,1.618);
   ObjectSetFiboDescription("FiboDn",10,"(-161.8%) -  %$");
   ObjectSet("FiboDn",221,1.764);
   ObjectSetFiboDescription("FiboDn",11,"(-176.4%) -  %$");
   ObjectSet("FiboDn",222,2.0);
   ObjectSetFiboDescription("FiboDn",12,"(-200.0%) -  %$");
   ObjectSet("FiboDn",223,2.5);
   ObjectSetFiboDescription("FiboDn",13,"(-250.0%) -  %$");
   ObjectSet("FiboDn",224,3.0);
   ObjectSetFiboDescription("FiboDn",14,"(-300.0%) -  %$");
   ObjectSet("FiboDn",225,3.5);
   ObjectSetFiboDescription("FiboDn",15,"(-350.0%) -  %$");
   ObjectSet("FiboDn",226,4.0);
   ObjectSetFiboDescription("FiboDn",16,"(-400.0%) -  %$");
   ObjectSet("FiboDn",227,4.5);
   ObjectSetFiboDescription("FiboDn",17,"(-450.0%) -  %$");
   ObjectSet("FiboDn",228,5.0);
   ObjectSetFiboDescription("FiboDn",18,"(-500.0%) -  %$");
//make fibonacci rays and set it in the backgroud of the chart
   ObjectSet("FiboDn",OBJPROP_RAY,true);
   ObjectSet("FiboDn",OBJPROP_BACK,true);

//=====================================================================================================
//--- FiboDn Placement on chart(3rd fibo)
//create fibonnacci down or change values if it already exist


   if(ObjectFind(0,"FiboIn")==-1)
      ObjectCreate(0,"FiboIn",OBJ_FIBO,0,barTime,high,barTime+86400,low);
   else
     {
      ObjectSetInteger(0,"FiboIn",OBJPROP_TIME,1,barTime);
      ObjectSetInteger(0,"FiboIn",OBJPROP_TIME,0,barTime+86400);
      ObjectSetDouble(0,"FiboIn",OBJPROP_PRICE,0,high);
      ObjectSetDouble(0,"FiboIn",OBJPROP_PRICE,1,low);
     }
//set colors and levels
   ObjectSetInteger(0, "FiboIn",OBJPROP_LEVELCOLOR,FiboColor2);
   ObjectSetInteger(0, "FiboIn",OBJPROP_LEVELS,7);

//ObjectSetDouble (0, "FiboIn",OBJPROP_FIRST_LEVEL,0.0);



//set level descriptions

   ObjectSetString(0, "FiboIn",OBJPROP_LEVELTEXT,0,"Daily LOW (0.0) -  %$");
   ObjectSetDouble(0, "FiboIn",OBJPROP_LEVELVALUE,211,0.236);

   ObjectSetString(0, "FiboIn",OBJPROP_LEVELTEXT,1,"(23.6) -  %$");
   ObjectSetDouble(0, "FiboIn",OBJPROP_LEVELVALUE,212,0.382);

   ObjectSetString(0, "FiboIn",OBJPROP_LEVELTEXT,2,"(38.2) -  %$");
   ObjectSetDouble(0, "FiboIn",OBJPROP_LEVELVALUE,213,0.5);

   ObjectSetString(0, "FiboIn",OBJPROP_LEVELTEXT,3,"(50.0) -  %$");
   ObjectSetDouble(0, "FiboIn",OBJPROP_LEVELVALUE,214,0.618);

   ObjectSetString(0, "FiboIn",OBJPROP_LEVELTEXT,4,"(61.8) -  %$");
   ObjectSetDouble(0, "FiboIn",OBJPROP_LEVELVALUE,215,0.764);

   ObjectSetString(0, "FiboIn",OBJPROP_LEVELTEXT,5,"(76.4) -  %$");
   ObjectSetDouble(0, "FiboIn",OBJPROP_LEVELVALUE,216,1.0);

   ObjectSetString(0, "FiboIn",OBJPROP_LEVELTEXT,6,"Daily HIGH (100.0) -  %$");

   ObjectSetInteger(0, "FiboIn",OBJPROP_RAY,true);
   ObjectSetInteger(0,"FiboIn",OBJPROP_BACK,true);
  }
  */
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetNextHigherTimeframe(ENUM_TIMEFRAMES timeframe)
  {
   switch(timeframe)
     {
      case PERIOD_M1:
         return PERIOD_M5;
      case PERIOD_M5:
         return PERIOD_M15;
      case PERIOD_M15:
         return PERIOD_M30;
      case PERIOD_M30:
         return PERIOD_H1;
      case PERIOD_H1:
         return PERIOD_H4;
      case PERIOD_H4:
         return PERIOD_D1;
      case PERIOD_D1:
         return PERIOD_W1;
      case PERIOD_W1:
         return PERIOD_MN1;
      case PERIOD_MN1:
         return PERIOD_MN1;  // Monthly is the highest, so return itself
      default:
         return timeframe;   // Return the input if it doesn't match any case
     }
  }
//+------------------------------------------------------------------+
//|     Determine then create or edit the Rcetangle and Trendline    |
//| this creates extra bars at the end of chart for latest 3 bars on |
//|        a higher timeframe using rectangle and trendline          |
//+------------------------------------------------------------------+
void CreateOrEditRectAndTL()
  {

//int HTF = NextTimeFrame(_Period);      //get the higher timeframe
   int      Obj_Color; //color of the rectangle and Trendline objects
   int      time1,time2; //Times of the second Rectangle anchor
   int timeMultiplier=3; //?????

//fill the price buffers with the appropriate values

//double   high[10],low[10],open[10],close[10]; //price buffer for latest 10 bars
//ArrayCopySeries(high,2,Symbol(),HTF);
//ArrayCopySeries(low,1,Symbol(),HTF);
//ArrayCopySeries(open,0,Symbol(),HTF);
//ArrayCopySeries(close,3,Symbol(),HTF);
   double high[10], low[10], open[10], close[10];
   CopyHigh(Symbol(), GetNextHigherTimeframe(PERIOD_CURRENT), 0, 10, high);
   CopyLow(Symbol(), GetNextHigherTimeframe(PERIOD_CURRENT), 0, 10, low);
   CopyOpen(Symbol(), GetNextHigherTimeframe(PERIOD_CURRENT), 0, 10, open);
   CopyClose(Symbol(), GetNextHigherTimeframe(PERIOD_CURRENT), 0, 10, close);


   datetime Time[];
   int copied=CopyTime(_Symbol,PERIOD_CURRENT,0,3,Time);
//if(copied>0)
//   time=Time[0];


   for(int i=2; i>=0; i--)
     {
      //---determine the time for the rectangle anchors
      time1 = (int) Time[0] + Period() * (90 * timeMultiplier);
      time2 = (int) Time[0] + 90 * (Period() * (timeMultiplier + 1));

      //---Determine the color of the objects
      if(open[i]>close[i])
         Obj_Color=170;
      else
         Obj_Color=43520;

      //create the Rectangle and trendlline objects or edit them to the new values if they already exist
      if(ObjectFind("BD"+(string)i)==-1)
         CreateRectangleAndTrendLine("D"+(string)i,time1,time2,open[i],close[i],low[i],high[i],Obj_Color);
      else
         EditRectangleAndTrendLine("D"+(string)i,time1,time2,open[i],close[i],low[i],high[i],Obj_Color);

      timeMultiplier+=2; //add 2 to the time multiplier
     }
  }

//+------------------------------------------------------------------+
//|       Change Rectangle And Trendline Objects properties          |
//+------------------------------------------------------------------+
void EditRectangleAndTrendLine(string ObjName,      //rectangle name
                               int    time1,        //time of the first rectangle anchor point
                               int    time2,        //time of the second rectangle anchor point
                               double Price_Rect1,  //price of the first rectangle anchor point
                               double Price_Rect2,  //price of the second rectangle anchor point
                               double Price_Trend1, //price of the first Trendline anchor point
                               double Price_Trend2, //price of the second Trendline anchor point
                               color  Obj_Color)    //color of the objects
  {
   if(Price_Rect1==Price_Rect2)
      Obj_Color=Gray; //if the two rectangle anchor prices are the same change the color to gray

//---change the rectangle to the appropriate properties
   ObjectSetInteger(0,"B"+ObjName,OBJPROP_TIME,0,time1);
   ObjectSetDouble(0,"B"+ObjName,OBJPROP_PRICE,0,Price_Rect1);
   ObjectSetInteger(0,"B"+ObjName,OBJPROP_TIME,1,time2);
   ObjectSetDouble(0,"B"+ObjName,OBJPROP_PRICE,1,Price_Rect2);
   ObjectSetInteger(0,"B"+ObjName,OBJPROP_BACK,true);
   ObjectSetInteger(0,"B"+ObjName,OBJPROP_COLOR,Obj_Color);

   int Halfway_Time=time1+(time2-time1)/2; //the time halfway through the rectangle object

//change the TrendLine to the appropriate properties between the updated rectangle above
   ObjectSetInteger(0,"S"+ObjName,OBJPROP_TIME,0,Halfway_Time);
   ObjectSetDouble(0,"S"+ObjName,OBJPROP_PRICE,0,Price_Trend1);
   ObjectSetInteger(0,"S"+ObjName,OBJPROP_TIME,1,Halfway_Time);
   ObjectSetDouble(0,"S"+ObjName,OBJPROP_PRICE,1,Price_Trend2);
   ObjectSetInteger(0,"S"+ObjName,OBJPROP_BACK,true);
   ObjectSetInteger(0,"S"+ObjName,OBJPROP_WIDTH,2);
   ObjectSetInteger(0,"S"+ObjName,OBJPROP_COLOR,Obj_Color);
  }

//+------------------------------------------------------------------+
//|       Create Rectangle And Trendline Objects on the chart        |
//+------------------------------------------------------------------+
void CreateRectangleAndTrendLine(string ObjName,      //partial objcts name
                                 int    time1,        //time of the first rectangle anchor point
                                 int    time2,        //time of the second rectangle anchor point
                                 double Price_Rect1,  //price of the first rectangle anchor point
                                 double Price_Rect2,  //price of the second rectangle anchor point
                                 double Price_Trend1, //price of the first Trendline anchor point
                                 double Price_Trend2, //price of the second Trendline anchor point
                                 color  Obj_Color)    //color of the objects
  {
   if(Price_Rect1 == Price_Rect2)
      Obj_Color=Gray;  //if the two rectangle anchor prices are the same change the color to gray

//create the rectangle with the appropriate properties
   ObjectCreate("B"+ObjName,OBJ_RECTANGLE,0,time1,Price_Rect1,time2,Price_Rect2);
   ObjectSet("B"+ObjName,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSet("B"+ObjName,OBJPROP_COLOR,Obj_Color);
   ObjectSet("B"+ObjName,OBJPROP_BACK,true);

   int Halfway_Time=time1+(time2-time1)/2; //the time halfway through the rectangle object

//create the TrendLine with the appropriate properties between the above rectangle
   ObjectCreate("S"+ObjName,OBJ_TREND,0,Halfway_Time,Price_Trend1,Halfway_Time,Price_Trend2);
   ObjectSet("S"+ObjName,OBJPROP_COLOR,Obj_Color);
   ObjectSet("S"+ObjName,OBJPROP_BACK,true);
   ObjectSet("S"+ObjName,OBJPROP_RAY,false);
   ObjectSet("S"+ObjName,OBJPROP_WIDTH,2);
  }

//+------------------------------------------------------------------+
//|              Create Spread object on the chart                   |
//+------------------------------------------------------------------+
void SpreadObject()
  {
   double  Ask=SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double  Bid=SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double stops=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL) * Point();
   string SpreadObjName = "SpreadIndicatorObj"; //Name of the spread object
   string SpreadText="Spread: "+DoubleToString(((Ask-Bid)/_Point*0.1),1)+" pips"; //spread in pips
   if(ObjectFind(0,SpreadObjName)<0)
     {
      ObjectCreate(0,SpreadObjName,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,SpreadObjName,OBJPROP_CORNER,1);
      ObjectSetInteger(0,SpreadObjName,OBJPROP_YDISTANCE,260);
      ObjectSetInteger(0,SpreadObjName,OBJPROP_XDISTANCE,10);
      ObjectSetString(0,SpreadObjName,OBJPROP_TEXT,SpreadText);
 
      ObjectSetString(0,SpreadObjName,OBJPROP_FONT,"Arial");
      ObjectSetInteger(0,SpreadObjName,OBJPROP_FONTSIZE,20);
      ObjectSetInteger(0,SpreadObjName,OBJPROP_COLOR,clrRed);
      
     }
   ObjectSetString(0,SpreadObjName,OBJPROP_TEXT,SpreadText);
//WindowRedraw();
   ChartRedraw();
  }
//+------------------------------------------------------------------+
//|        Get The Time Frame of the Next Higher Timeframe           |
//+------------------------------------------------------------------+
int NextTimeFrame(int TimeFrame)
  {
   switch(TimeFrame)
     {
      case PERIOD_M1:
         return 5;      //next timeframe from 1 min is 5 mins
      case PERIOD_M5:
         return 15;     //next timeframe from 5 mins is 15 mins
      case PERIOD_M15:
         return 30;     //next timeframe from 15 mins is 30 mins
      case PERIOD_M30:
         return 60;     //next timeframe from 30 min is 1 hour
      case PERIOD_H1:
         return 240;    //next timeframe from 1 hour is 4 hours
      case PERIOD_H4:
         return 1440;   //next timeframe from 4 hours is daily
      case PERIOD_D1:
         return 10080;  //next timeframe from 1 day is weekly
      case PERIOD_W1:
         return 43200;  //next timeframe from 1 week is 1 month
      case PERIOD_MN1:
         return 43200;  //theres no higher time frame than monthly so we return monthly instead
      default:
         return NextTimeFrame(_Period); //for current time frame we get the value of current time frame then re-run the function
     }
  }
//+------------------------------------------------------------------+
//|   Set chart properties (colors,candles,levels,grid,lines etc)    |
//+------------------------------------------------------------------+
void SetChartProperties()
  {
   ChartSetInteger(ChartID(), CHART_MODE, CHART_CANDLES);
   ChartSetInteger(ChartID(), CHART_SHOW_ASK_LINE, true);
   ChartSetInteger(ChartID(), CHART_SHOW_BID_LINE, true);
   ChartSetInteger(ChartID(), CHART_SHOW_OHLC, true);
   ChartSetInteger(ChartID(), CHART_SHOW_GRID, false);
   ChartSetInteger(ChartID(), CHART_SHOW_TRADE_LEVELS, true);
   ChartSetInteger(ChartID(), CHART_COLOR_BACKGROUND, White);
   ChartSetInteger(ChartID(), CHART_COLOR_FOREGROUND, Black);
   ChartSetInteger(ChartID(), CHART_COLOR_CHART_DOWN, Black);
   ChartSetInteger(ChartID(), CHART_COLOR_CHART_UP, Black);
   ChartSetInteger(ChartID(), CHART_COLOR_CANDLE_BULL, DarkGreen);
   ChartSetInteger(ChartID(), CHART_COLOR_CANDLE_BEAR, Crimson);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   if(!IsTesting())
     {
      int i;
      for(i=1; i<=40; i++)
         ObjectDelete(0, "Padding_rect"+(string)i);
      for(i=0; i<10; i++)
        {
         ObjectDelete(0, "BD"+(string)i);
         ObjectDelete(0, "SD"+(string)i);
        }
      ObjectDelete(0, "time");
      ObjectDelete(0, "SpreadIndicatorObj");
     }
   ObjectDelete(0, "B3LLogo");
   ObjectDelete(0, "B3LCopy");
   ObjectDelete(0, "FiboUp");
   ObjectDelete(0, "FiboDn");
   ObjectDelete(0, "FiboIn");
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckSignalsSSC()
  {

//get the buy and sell values of the current bar from the indicator
   /*  double sellValue = 0;//High[0];//iCustom(NULL, 0, "super-signals-channel", SignalGap, ShowBars, 2,0);
     double buyValue  = Low[0];//iCustom(NULL, 0, "super-signals-channel", SignalGap, ShowBars, 3,0);

     int order = -1; //order type (-1: No signal, 0:Buy, 1:Sell)

     //make we are not delaying signals or we are delaying signals and there are no delayed signals waiting to be placed then check for signals
     if(!Delay_Signal || DelayedSignalTime == 0)
       {
         if(!Indicator_Arrow_Repaint) order = FilterSSCSignals(sellValue,buyValue); //get signal using Filter and pullback
         else order = ArrowRepaintStratey(sellValue,buyValue);                      //get signal using arrow repaint strategy
       }

     if(Delay_Signal) order = StoreAndPlaceDelayedOrders(order); //if we are delaying orders, store the signal or retrieve the stored signal
     */
//if theres an entry signal and cost to open order is considerate place order using conditions 1-4 if enabled
// if(order >=0 )//&& OrderOpenCost() <= 10000.0 )
//  PlaceOrder(order);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double ShowSpread()
  {
   double Spread= MarketInfo(Symbol(),MODE_SPREAD);
   double PipSpread= Spread;
   return PipSpread;
  }

//+------------------------------------------------------------------+
//|    Determine Price per point and Commission for hisory trades    |
//+------------------------------------------------------------------+
bool CalculatePPAndComission()
  {
   bool AlreadyChckedCC=false;

   for(int i=OrdersHistoryTotal()-1; i>=0; i--)
      if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY))
         if(OrderProfit()!=0.0 && OrderClosePrice()!=OrderOpenPrice()&& OrderSymbol()==Symbol())
           {
            AlreadyChckedCC = true;
            double CostPP = MathAbs(OrderProfit() / (OrderClosePrice() - OrderOpenPrice())); //Profit per point change
            CommPP = (-OrderCommission()) / CostPP;                                          //Commision per point change
            break;
           }
   return AlreadyChckedCC;
  }

//+------------------------------------------------------------------+
//|  Determine the average of last 30 spreads, and add commisions    |
//|  to get the amount it would cost(points) to place a new order    |
//+------------------------------------------------------------------+
double OrderOpenCost()
  {
   double  Ask=SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double  Bid=SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double stops=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL) * Point();
   static int counter = 0;
   if(counter < 30)
      counter ++;
   int j = 29;
   ArrayCopy(spread,spread,0,1,29);
   spread[j]=Ask-Bid;
   double sum=0;
   for(int i=0; i<counter; i++)
     {
      sum+=spread[j];
      j--;
     }
   double Average = sum / counter;

   return (NormalizeDouble(Average + CommPP, Digits() + 1));
  }

//+------------------------------------------------------------------+
//|       Update running Orders (get New order prices and SL)        |
//+------------------------------------------------------------------+
int UpdateOrders()
  {

   double  Ask=SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double  Bid=SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double stops=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL) * Point();


   int OrderCount=0;                                //Number of orders
   for(int i=0; i<OrdersTotal(); i++)               //go through all orders
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))   //select order by position
         if(OrderMagicNumber()==MyMagicNumber)        //check if placed by the EA with magic number
           {
            if(OrderType()==OP_BUYLIMIT || OrderType()==OP_SELLLIMIT)
               continue; //skip limit orders
            if(OrderSymbol()==Symbol())                                         //makes sure the orderis for current chart
              {
               OrderCount++;        //add 1 to number of orders
               switch(OrderType())  //determine order type
                 {
                  //in case of a buy stop order get the new and old price,then update the order to new values
                  case OP_BUYSTOP:
                    {
                     double OrderDistance = NormalizeDouble(Limit * Point(), Digits()); //how far against the current price to place order
                     double openPrice=NormalizeDouble(OrderOpenPrice(),Digits());     //the old order price
                     double NewPrice=NormalizeDouble(Ask+OrderDistance,Digits());     //the new updated price

                     if(! NewPrice<openPrice)
                        break; //go to the next order if new price is lower than the old price

                     //get the new updated stoploss, incase where we need to use virtual stop loss remove stoploss(SL=0)
                     double StopLoss= NormalizeDouble(NewPrice -(SLoss+MarketInfo(Symbol(),MODE_SPREAD)) * Point(),Digits());
                     if(Virtual_Stop_Loss==true)
                        StopLoss = 0;

                     //Update the order to new values and print an error message with details in case of failure
                     if(!OrderModify(OrderTicket(),NewPrice,StopLoss,OrderTakeProfit(),0,Lime))
                        Print("BUYSTOP Modify Error Code: ",GetLastError()," OP: ",NewPrice," SL: ",StopLoss," Bid: ",Bid," Ask: ",Ask);
                     break;
                    }
                  //in case of a sell stop order get the new and old price,then update the order to new values
                  case OP_SELLSTOP:
                    {
                     double OrderDistance = NormalizeDouble(Limit * Point(), Digits()); //how far against the current price to place order
                     double openPrice=NormalizeDouble(OrderOpenPrice(),Digits());     //the old order price
                     double NewPrice=NormalizeDouble(Bid-OrderDistance,Digits());     //the new updated price

                     if(! NewPrice>openPrice)
                        break;  //go to the next order if new price is higher than the old price

                     //get the new updated stoploss, incase where we need to use virtual stop loss remove stoploss(SL=0)
                     double StopLoss= NormalizeDouble(NewPrice+(SLoss+MarketInfo(Symbol(),MODE_SPREAD)) * Point(),Digits());
                     if(Virtual_Stop_Loss==true)
                        StopLoss=0;

                     //Update the order to new values and print an error message with details in case of failure
                     if(!OrderModify(OrderTicket(),NewPrice,StopLoss,OrderTakeProfit(),0,Orange))
                        Print("SELLSTOP Modify Error Code: ",GetLastError()," OP: ",NewPrice," SL: ",StopLoss," Bid: ",Bid," Ask: ",Ask);
                     break;
                    }
                 }
              }
           }

   return OrderCount;
  }

//+------------------------------------------------------------------+
//|           DELETES ALL ORDERS ON CHART PLACED BY THE EA           |
//+------------------------------------------------------------------+
void DeleteAllOrders()
  {
   for(int i=(OrdersTotal()-1);i>=0;i--)
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         if(OrderType()==OP_BUYSTOP|| OrderType()==OP_SELLSTOP || OrderType()==OP_BUYLIMIT || OrderType()==OP_SELLLIMIT)
            if(OrderSymbol()==Symbol() && OrderMagicNumber()==MyMagicNumber)
               if(!OrderDelete(OrderTicket()))
                  Print("Error in Deleting Order. Error code: ", GetLastError());
  }


//+------------------------------------------------------------------+
//|           go through all orders without SL and put SL            |
//+------------------------------------------------------------------+
void checkAndPlaceSL(int Magic)
  {
   for(int i = 0; i < OrdersTotal(); i++)   ///It means go through the code until 0 is less than the open trades (that is 1).
      if(OrderSelect(i,SELECT_BY_POS) == true)
         if(OrderMagicNumber() == Magic)   ////If there is a position already opened by the EA...
           {
            if(OrderType()==OP_BUY && OrderStopLoss() == 0)
               if(!OrderModify(OrderTicket(),OrderOpenPrice(),(NormalizeDouble(OrderOpenPrice() - (SLoss+ MarketInfo(Symbol(),MODE_SPREAD)) * Point(), Digits())),OrderTakeProfit(),0,Lime))
                  Print("Failed to put SL on order ",OrderTicket()," on ",_Symbol," error code: ",GetLastError());

            if(OrderType()==OP_SELL && OrderStopLoss() == 0)
               if(!OrderModify(OrderTicket(), OrderOpenPrice(), (NormalizeDouble(OrderOpenPrice() + (SLoss+ MarketInfo(Symbol(),MODE_SPREAD)) * Point(), Digits())), OrderTakeProfit(), 0, Red))
                  Print("Failed to put SL on order ",OrderTicket()," on ",_Symbol," error code: ",GetLastError());
           }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Order Information                                                |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
long OrderType(ulong pTicket)
{
   bool select = OrderSelect(pTicket);
   if(select == true)
      return(OrderGetInteger(ORDER_TYPE));
   else
      return(WRONG_VALUE);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool       IsTradeContextBusy()
{
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
      return true;
   return false;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
long OrderExpirationTime(ulong pTicket)
{
   bool select = OrderSelect(pTicket);
   if(select == true)
      return(OrderGetInteger(ORDER_TIME_EXPIRATION));
   else
      return(WRONG_VALUE);
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
long OrderExpirationType(ulong pTicket)
{
   bool select = OrderSelect(pTicket);
   if(select == true)
      return(OrderGetInteger(ORDER_TYPE_TIME));
   else
      return(WRONG_VALUE);
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
long OrderMagicNumber(ulong pTicket)
{
   bool select = OrderSelect(pTicket);
   if(select == true)
      return(OrderGetInteger(ORDER_MAGIC));
   else
      return(WRONG_VALUE);
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double OrderVolume(ulong pTicket)
{
   bool select = OrderSelect(pTicket);
   if(select == true)
      return(OrderGetDouble(ORDER_VOLUME_CURRENT));
   else
      return(WRONG_VALUE);
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double OrderOpenPrice(ulong pTicket)
{
   bool select = OrderSelect(pTicket);
   if(select == true)
      return(OrderGetDouble(ORDER_PRICE_OPEN));
   else
      return(WRONG_VALUE);
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double OrderStopLimit(ulong pTicket)
{
   bool select = OrderSelect(pTicket);
   if(select == true)
      return(OrderGetDouble(ORDER_PRICE_STOPLIMIT));
   else
      return(WRONG_VALUE);
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double OrderStopLoss(ulong pTicket)
{
   bool select = OrderSelect(pTicket);
   if(select == true)
      return(OrderGetDouble(ORDER_SL));
   else
      return(WRONG_VALUE);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int TimeDayOfWeek(datetime date)
{
   MqlDateTime tm;
   TimeToStruct(date,tm);
   return(tm.day_of_week);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double OrderTakeProfit(ulong pTicket)
{
   bool select = OrderSelect(pTicket);
   if(select == true)
      return(OrderGetDouble(ORDER_TP));
   else
      return(WRONG_VALUE);
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string OrderComment(ulong pTicket)
{
   bool select = OrderSelect(pTicket);
   if(select == true)
      return(OrderGetString(ORDER_COMMENT));
   else
      return(NULL);
}