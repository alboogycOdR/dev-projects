//+------------------------------------------------------------------+
//|                                            HighLowBreakoutEA.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"


//+------------------------------------------------------------------+
//| Include                                                          |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
static input long InpMagicnumber = 54672;  //magicnumber

enum LOT_MODE_ENUM
  {
   LOT_MODE_FIXED,         // fixed lots
   LOT_MODE_MONEY,         // lots based on money
   LOT_MODE_PCT_ACCOUNT    // lots based on % of account
  };

input group "> Lot Sitting "

input LOT_MODE_ENUM InpLotMode = LOT_MODE_FIXED;  // lot mode
input double InpLots = 0.01;        // lots / money / percent

input group "> Breakout Setting "

input int           InpBars = 80;          //bars for high/low
input int           InpIndexFilter = 0;    //index filter in % (0=off)
input int           InpSizeFilterMax = 1300;     //channed size filter max in points (0=off)
input int           InpSizeFilterMin = 100;     //channed size filter min in points (0=off)

input group "> TP - SL - TS "

enum STOPLOSE_MODE_ENUM
  {
   STOPLOSE_MODE_FIXED,     //stop lose on points
   STOPLOSE_MODE_PCT        //stop lose per percent of channel
  };
input STOPLOSE_MODE_ENUM InpStopLossMode = STOPLOSE_MODE_FIXED; //sl mode
input int           InpStopLoss = 350;     //stop loss in points / percent
input bool          InpTrailingSL = true;  //traling stop loss?
input double        InpTrailingSLAmount  = 350; //traling stop amount in points
input int           InpTakeProfit = 0;     //take profit in points (0=off)

input group "> Hour filter "

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input int           InpStartHour = 0;      // start hour  (0=off)
input int           InpStopHour = 25;      // stop hour  (+24=off)
input int           InpCloseHour = 25;      // close hour (+24=off)

input group "> Day of week filter "
input bool InpMonday = true;         // range on InpMonday
input bool InpTuesday = true;         // range on InpTuesday
input bool InpWednesday = true;         // range on InpWednesday
input bool InpThursday = true;         // range on InpThursday
input bool InpFriday = true;         // range on InpFriday

//+------------------------------------------------------------------+
//| global variables                                                 |
//+------------------------------------------------------------------+
double high = 0;   //highest price of the last N bars
double low = 0;    //Lowest price of the last N bars
int highIdx=0;     //index of highest bar
int lowIdx=0;      //index of lowest bar
MqlTick currentTick, previousTick;
CTrade trade;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {

// check for user input
   if(!ChechInputs())
     {
      return INIT_PARAMETERS_INCORRECT;
     }

// set magicnumber
   trade.SetExpertMagicNumber(InpMagicnumber);

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {

   ObjectDelete(NULL,"high");
   ObjectDelete(NULL,"low");
   ObjectDelete(NULL,"text");
   ObjectDelete(NULL,"indexfilter");

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {


   if(InpCloseHour<=CurrentHour())
     {
      ClosePositions(1);
      ClosePositions(2);
     }

// check for new bar open tick
   if(!IsNewBar())
     {
      return;
     }

// grt tick
   previousTick = currentTick;
   if(!SymbolInfoTick(_Symbol,currentTick))
     {
      Print("Failed to get current tivk");
      return;
     }

// count open positions
   int cntBuy, cntSell;
   if(!CountOpenPositions(cntBuy,cntSell))
     {
      return;
     }





// check for buy position
   if(cntBuy==0 && high!=0 && previousTick.ask<high && currentTick.ask>=high && CheckIndexFilter(highIdx) && CheckSizeFilter() && WorkTime() &&  workWeek())
     {
      // calculate stop loss / take profit
      double sl;
      if(InpStopLossMode==0)
        {
         sl = InpStopLoss==0 ? 0 : currentTick.bid - InpStopLoss * _Point;
        }
      else
        {
         sl = currentTick.bid - (((high-low)*InpStopLoss)/100);
        }
      double tp = InpTakeProfit==0 ? 0 : currentTick.bid + InpTakeProfit * _Point;
      if(!NormalizePrice(sl))
        {
         return;
        }
      if(!NormalizePrice(tp))
        {
         return;
        }

      // calculate lots
      double lots;
      if(!CalculateLots(currentTick.bid-sl,lots))
        {
         return;
        }

      // open buy position
      trade.PositionOpen(_Symbol,ORDER_TYPE_BUY,lots,currentTick.ask,sl,tp,"HighLowBreakoutEA");
     }

// check for sell position
   if(cntSell==0 && low!=0 && previousTick.bid>low && currentTick.bid<=low && CheckIndexFilter(lowIdx) && CheckSizeFilter() && WorkTime() &&  workWeek())
     {
      // calculate stop loss / take profit
      double sl;
      if(InpStopLossMode==0)
        {
         sl = InpStopLoss==0 ? 0 : currentTick.ask + InpStopLoss * _Point;
        }
      else
        {
         sl = currentTick.ask + (((high-low)*InpStopLoss)/100);
        }
      double tp = InpTakeProfit==0 ? 0 : currentTick.ask - InpTakeProfit * _Point;
      if(!NormalizePrice(sl))
        {
         return;
        }
      if(!NormalizePrice(tp))
        {
         return;
        }

      //calculate lots
      double lots;
      if(!CalculateLots(sl-currentTick.ask,lots))
        {
         return;
        }

      // open sell position
      trade.PositionOpen(_Symbol,ORDER_TYPE_SELL,lots,currentTick.bid,sl,tp,"HighLowBreakoutEA");
     }

// update stop loss
   if(InpStopLoss>0 && InpTrailingSL)
     {
      if(InpStopLossMode==0)
        {
         UpdateStopLoss(InpStopLoss*_Point);
        }
      else
        {
         UpdateStopLoss(InpTrailingSLAmount*_Point);
        }
     }

// calculate high/low
   highIdx = iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,InpBars,1);
   lowIdx = iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,InpBars,1);
   high = iHigh(_Symbol,PERIOD_CURRENT,highIdx);
   low  = iLow(_Symbol,PERIOD_CURRENT,lowIdx);

   DrawObjects();
  }


//+------------------------------------------------------------------+
//| functions                                             |
//+------------------------------------------------------------------+


// check user input
bool ChechInputs()
  {

   if(InpMagicnumber<=0)
     {
      Alert("error");
      return false;
     }
   if(InpLotMode==LOT_MODE_FIXED && (InpLots<=0 || InpLots > 10))
     {
      Alert("error");
      return false;
     }
   if(InpLotMode==LOT_MODE_MONEY && (InpLots<=0 || InpLots > 1000))
     {
      Alert("error");
      return false;
     }
   if(InpLotMode==LOT_MODE_PCT_ACCOUNT && (InpLots<=0 || InpLots > 5))
     {
      Alert("error");
      return false;
     }
   if((InpLotMode==LOT_MODE_MONEY || InpLotMode==LOT_MODE_PCT_ACCOUNT) && InpStopLoss==0)
     {
      Alert("error");
      return false;
     }
   if(InpBars<=0)
     {
      Alert("error");
      return false;
     }
   if(InpIndexFilter<0 || InpIndexFilter>=50)
     {
      Alert("error");
      return false;
     }
   if(InpSizeFilterMax<0)
     {
      Alert("error");
      return false;
     }
   if(InpSizeFilterMin<0)
     {
      Alert("error");
      return false;
     }
   if(InpStopLoss<=0)
     {
      Alert("error");
      return false;
     }
   if(InpTakeProfit<0)
     {
      Alert("error");
      return false;
     }

   return true;
  }

// check if high/low is inside valid index renge
bool CheckIndexFilter(int index)
  {

   if(InpIndexFilter>0 && (index<=round(InpBars*InpIndexFilter*0.01) || index>InpBars-round(InpBars*InpIndexFilter*0.01)))
     {
      return false;
     }
   return true;
  }

// check channel size
bool CheckSizeFilter()
  {

   if(InpSizeFilterMax>0 && (high-low)>InpSizeFilterMax*_Point)
     {
      return false;
     }
   if(InpSizeFilterMin>0 && (high-low)<InpSizeFilterMin*_Point)
     {
      return false;
     }
   return true;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawObjects()
  {

   datetime time1 = iTime(_Symbol,PERIOD_CURRENT,InpBars);
   datetime time2 = iTime(_Symbol,PERIOD_CURRENT,1);

// high
   ObjectDelete(NULL,"high");
   ObjectCreate(NULL,"high",OBJ_TREND,0,time1,high,time2,high);
   ObjectSetInteger(NULL,"high",OBJPROP_WIDTH,3);
   ObjectSetInteger(NULL,"high",OBJPROP_COLOR,CheckIndexFilter(highIdx) && CheckSizeFilter() ? clrLime : clrBlack);

// low
   ObjectDelete(NULL,"low");
   ObjectCreate(NULL,"low",OBJ_TREND,0,time1,low,time2,low);
   ObjectSetInteger(NULL,"low",OBJPROP_WIDTH,3);
   ObjectSetInteger(NULL,"low",OBJPROP_COLOR,CheckIndexFilter(lowIdx) && CheckSizeFilter() ? clrLime : clrBlack);

// index filter
   ObjectDelete(NULL,"indexFilter");
   if(InpIndexFilter>0)
     {
      datetime timeIF1 = iTime(_Symbol,PERIOD_CURRENT,(int)(InpBars-round(InpBars*InpIndexFilter*0.01)));
      datetime timeIF2 = iTime(_Symbol,PERIOD_CURRENT,(int)(round(InpBars*InpIndexFilter*0.01)));
      ObjectCreate(NULL,"indexFilter",OBJ_RECTANGLE,0,timeIF1,low,timeIF2,high);
      ObjectSetInteger(NULL,"indexFilter",OBJPROP_BACK,true);
      ObjectSetInteger(NULL,"indexFilter",OBJPROP_FILL,true);
      ObjectSetInteger(NULL,"indexFilter",OBJPROP_COLOR,clrMintCream);
     }

// text
   ObjectDelete(NULL,"text");
   ObjectCreate(NULL,"text",OBJ_TEXT,0,time2,low);
   ObjectSetInteger(NULL,"text",OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(NULL,"text",OBJPROP_COLOR,clrBlack);
   ObjectSetString(NULL,"text",OBJPROP_TEXT,"Bars:"+(string)InpBars+
                   " index filter:"+DoubleToString(round(InpBars*InpIndexFilter*0.01),0)+
                   " high index:"+(string)highIdx+
                   " low index:"+(string)lowIdx+
                   " size:"+DoubleToString((high-low)/_Point,0));

  }

// check if we have a bar open tick
bool IsNewBar()
  {

   static datetime previousTime = 0;
   datetime currentTime = iTime(_Symbol,PERIOD_CURRENT,0);
   if(previousTime!=currentTime)
     {
      previousTime=currentTime;
      return true;
     }
   return false;
  }

// count open position
bool CountOpenPositions(int &cntBuy, int &cntSell)
  {

   cntBuy  = 0;
   cntSell = 0;
   int total = PositionsTotal();
   for(int i=total-1; i>=0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket<=0)
        {
         Print("Print to get position ticket");
         return false;
        }
      if(!PositionSelectByTicket(ticket))
        {
         Print("Failed to get position magicnumber");
         return false;
        }
      long magic;
      if(!PositionGetInteger(POSITION_MAGIC,magic))
        {
         Print("Failed to get Position magicnumber");
         return false;
        }
      if(magic==InpMagicnumber)
        {
         long type;
         if(!PositionGetInteger(POSITION_TYPE,type))
           {
            Print("failed to get position type");
            return false;
           }
         if(type==POSITION_TYPE_BUY)
           {
            cntBuy++;
           }
         if(type==POSITION_TYPE_SELL)
           {
            cntSell++;
           }
        }
     }
   return true;

  }

// normalize price
bool NormalizePrice(double &price)
  {

   double tickSize=0;
   if(!SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE,tickSize))
     {
      Print("Failed to get tick size");
      return false;
     }
   price = NormalizeDouble(MathRound(price/tickSize)*tickSize,_Digits);

   return true;
  }







// update stop loss
void UpdateStopLoss(double slDistance)
  {

//loop through open positions
   int total = PositionsTotal();
   for(int i=total-1; i>=0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket<=0)
        {
         Print("Failed to get position ticket");
         return;
        }
      if(!PositionSelectByTicket(ticket))
        {
         Print("Failed to select position by ticket");
         return;
        }
      ulong magicnumber;
      if(!PositionGetInteger(POSITION_MAGIC,magicnumber))
        {
         Print("Failed to get position magicnumber");
         return;
        }
      if(InpMagicnumber==magicnumber)
        {

         //get type
         long type;
         if(!PositionGetInteger(POSITION_TYPE,type))
           {
            Print("Failed to get position type");
            return;
           }
         // get current sl and tp
         double currSL, currTP;
         if(!PositionGetDouble(POSITION_SL,currSL))
           {
            Print("Failed to get position stop loss");
            return;
           }
         if(!PositionGetDouble(POSITION_TP,currTP))
           {
            Print("Failed to get position take profit");
            return;
           }

         // calculate stop loss
         double currPrice = type==POSITION_TYPE_BUY ? currentTick.bid : currentTick.ask;
         int n            = type==POSITION_TYPE_BUY ? 1 : -1;
         double newSL     = currPrice - slDistance * n;
         if(!NormalizePrice(newSL))
           {
            return;
           }

         // check if new stop loss is closer to current price than existing stop loss
         if((newSL*n) < (currSL*n) || NormalizeDouble(MathAbs(newSL-currSL),_Digits)<_Point)
           {
            //Print("no new stop loss needed");;
            continue;
           }

         // check foe stop level
         long level = SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
         if(level!=0 && MathAbs(currPrice-newSL)<=level*_Point)
           {
            Print("NEW stop loss inside stop level");
            continue;
           }

         // modify position with new stop loss
         if(!trade.PositionModify(ticket,newSL,currTP))
           {
            Print("Failed to modify position, ticket:",(string)ticket," currSL:",(string)currSL,
                  " newSL:",(string)newSL," currTP:",(string)currTP);
            return;
           }
        }
     }
  }


// calculate lots
bool CalculateLots(double slDistance, double &lots)
  {

   lots = 0.0;
   if(InpLotMode == LOT_MODE_FIXED)
     {
      lots = InpLots;
     }
   else
     {
      double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
      double volumeStep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);

      double riskMoney = InpLotMode==LOT_MODE_MONEY ? InpLots : AccountInfoDouble(ACCOUNT_EQUITY) * InpLots * 0.01;
      double moneyVolumeStep = (slDistance / tickSize) *  tickValue * volumeStep;

      lots = MathFloor(riskMoney/moneyVolumeStep) * volumeStep;
     }

// check calculted lots
   if(!CheckLots(lots))
     {
      return false;
     }

   return true;
  }


// check lots for min, max and step
bool CheckLots(double &lots)
  {

   double min  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double max  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);

   if(lots<min)
     {
      Print("lot size will be set to the minimum allowable volume");
      lots = min;
      return true;
     }
   if(lots>max)
     {
      Print("Lot size qreater than the maximum allowable volume. lots:",lots," max:",max);
      return false;
     }

   lots = (int)MathFloor(lots/step) * step;

   return true;
  }


// find the hour
int CurrentHour()
  {
   MqlDateTime tm;
   TimeCurrent(tm);
   return(tm.hour);
  }

// is in work time or not
bool WorkTime()
  {
   if(CurrentHour()>=InpStartHour && CurrentHour()<=InpStopHour)
     {
      return true;
     }
   else
     {
      return false;
     }
  }


// is in day of week or not
bool workWeek()
  {

   MqlDateTime STime;
   TimeToStruct(TimeCurrent(),STime);
   if((STime.day_of_week == 1 && InpMonday)    ||
      (STime.day_of_week == 2 && InpTuesday)   ||
      (STime.day_of_week == 3 && InpWednesday) ||
      (STime.day_of_week == 4 && InpThursday)  ||
      (STime.day_of_week == 5 && InpFriday))
     {
      return true;
     }
   else
     {
      return false;
     }
  }


// close positions
bool ClosePositions(int all_buy_sell)
  {

   int total = PositionsTotal();
   for(int i=total-1; i>=0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket<=0)
        {
         Print("failed to get position ticket");
         return false;
        }
      if(!PositionSelectByTicket(ticket))
        {
         Print("failed to select position");
         return false;
        }
      long magic;
      if(!PositionGetInteger(POSITION_MAGIC,magic))
        {
         Print("failed to get position magicnumber");
         return false;
        }
      if(magic==InpMagicnumber)
        {
         long type;
         if(!PositionGetInteger(POSITION_TYPE,type))
           {
            Print("Failed to get position type");
            return false;
           }
         if(all_buy_sell==1 && type==POSITION_TYPE_SELL)
           {
            continue;
           }
         if(all_buy_sell==2 && type==POSITION_TYPE_BUY)
           {
            continue;
           }
         trade.PositionClose(ticket);
         if(trade.ResultRetcode()!=TRADE_RETCODE_DONE)
           {
            Print("failed to close position. ticket:",
                  (string)ticket," result:",(string)trade.ResultRetcode(),":",trade.CheckResultRetcodeDescription());
           }
        }
     }
   return true;
  }


//+------------------------------------------------------------------+
