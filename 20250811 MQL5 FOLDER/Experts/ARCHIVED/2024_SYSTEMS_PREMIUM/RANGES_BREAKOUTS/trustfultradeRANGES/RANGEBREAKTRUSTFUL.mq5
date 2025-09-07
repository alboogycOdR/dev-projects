//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+

//   22:29 seconds ; part5


#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"


#include <Trade\Trade.mqh>
input double inpLots = 0.1;
input long inpMagic = 83783783;

input int inpRangeStart = 60; //range start time in minutes;max 1440
//60 ==1am
//120 == 2am
//600 ==10am
//660==11am
//700 ==11:40
//1200 ==8pm 20:00
input int inpRangeDuration = 540; // minutes
//rangestart==60 ==1am    rangeduration 420==7hours == ends at 0800

input int inpRangeClose = 1200;

// input int inpFastPeriod=14;
// input int inpSlowPeriod=21;
input int inpStopLoss = 150;
input int inpTakeProfit = 600;


// int fasthandle,slowhandle;
// double fastbuffer[],slowbuffer[];
// datetime opentimebuy=0,opentimesell=0;
CTrade trade;
enum BREAKOUT_MODE_ENUM {
   one_signal,//one breakout per range
   two_signal//high and low breakout
};

input BREAKOUT_MODE_ENUM inpBreakoutmode = one_signal; //breakout mode


input bool inpMonday = true;
input bool inpTuesday = true;
input bool inpWednesday = true;
input bool inpThursday = true;
input bool inpFriday = true;



struct RANGE_STRUCT {
   datetime          starttime;
   datetime          endtime;
   datetime          closetime;

   double            high;
   double            low;

   bool              f_entry;
   bool              f_high_breakout;
   bool              f_low_breakout;

   RANGE_STRUCT():
      starttime(0),
      endtime(0),
      closetime(0),
      high(0),
      low(DBL_MAX),
      f_entry(false),
      f_high_breakout(false),
      f_low_breakout(false) {} ;
};

RANGE_STRUCT rangeobj;

MqlTick
prevtick, lasttick;


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit() {



   trade.SetExpertMagicNumber(inpMagic);


//calculate new range if inputs changed
   if(_UninitReason == REASON_PARAMETERS && CountOpenPositions() == 0) {
      CalculateRange();
   }

   DrawObjects();

   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
//---
   ObjectsDeleteAll(NULL, "range");
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ClosePositions() {

   int total = PositionsTotal();

   for(int i = total - 1; i >= 0; i--) {

      if(total != PositionsTotal()) {
         total = PositionsTotal();
         i = total;
         continue;
      }


      ulong ticket = PositionGetTicket(i);

      if(ticket <= 0) {
         Print("failed to get pos ticket");
         return false;
      }
      if(!PositionSelectByTicket(ticket)) {
         Print("failed to select position by ticket");
         return false;

      }

      ulong magicnummber;
      if(!PositionGetInteger(POSITION_MAGIC, magicnummber)) {
         Print("failed to GET position MAGICNUMBER");
         return false;
      }
      if(inpMagic == magicnummber) {
         trade.PositionClose(ticket);

         if(trade.ResultRetcode() != TRADE_RETCODE_DONE) {
            Print("failed to close position ;;result: " + (string)trade.ResultRetcode() + ":" + trade.ResultRetcodeDescription());
            return false;
         }
      }
   }
   return true;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick() {
//---

   prevtick = lasttick;
   SymbolInfoTick(_Symbol, lasttick);

//range calculation
   if(lasttick.time >= rangeobj.starttime && lasttick.time < rangeobj.endtime) {
      rangeobj.f_entry = true;
      //Print("in killzone  ");

      //new H
      if(lasttick.ask > rangeobj.high) {
         rangeobj.high = lasttick.ask;
         DrawObjects();
      }

      //new L
      if(lasttick.bid < rangeobj.low) {
         rangeobj.low = lasttick.bid;
         DrawObjects();
      }


   }

//close positions
   if(inpRangeClose >= 0 && lasttick.time >= rangeobj.closetime) {
      if(!ClosePositions()) {
         return;
      }
   }


   if((inpRangeClose >= 0 && lasttick.time >= rangeobj.closetime && CountOpenPositions() == 0)
         ||(rangeobj.f_high_breakout && rangeobj.f_low_breakout) 
         ||(rangeobj.endtime == 0) 
         ||(rangeobj.endtime != 0 && lasttick.time > rangeobj.endtime && !rangeobj.f_entry)) {
      CalculateRange();
      DrawObjects();
   }


   CheckBreakouts();
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckBreakouts() {
   if(lasttick.time >= rangeobj.endtime  && rangeobj.endtime>0 && rangeobj.f_entry) {
      //check for h brekout
      if(!rangeobj.f_high_breakout && lasttick.ask >= rangeobj.high) {
         rangeobj.f_high_breakout = true;
         if(inpBreakoutmode == one_signal) {
            rangeobj.f_low_breakout = true;
         }
         double sl = inpStopLoss == 0 ? 0 : NormalizeDouble(lasttick.bid - /*(rangeobj.high-rangeobj.low) **/inpStopLoss * Point(), _Digits);
         double tp = inpTakeProfit == 0 ? 0 : NormalizeDouble(lasttick.bid + /*(rangeobj.high-rangeobj.low) **/inpTakeProfit * Point(), _Digits);
         trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, inpLots, lasttick.ask, rangeobj.low, tp, "time range EA");


      }

      //check for l brekout
      if(!rangeobj.f_low_breakout && lasttick.bid <= rangeobj.low) {
         rangeobj.f_low_breakout = true;
         if(inpBreakoutmode == one_signal) {
            rangeobj.f_high_breakout = true;
         }


         double sl = NormalizeDouble(lasttick.ask + /*(rangeobj.high-rangeobj.low) **/inpStopLoss * Point(), _Digits);
         double tp = NormalizeDouble(lasttick.ask - /*(rangeobj.high-rangeobj.low) **/inpTakeProfit * Point(), _Digits);
         trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, inpLots, lasttick.bid, rangeobj.high, tp, "time range EA");


      }



   }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CalculateRange() {
   rangeobj.starttime = 0;
   rangeobj.endtime = 0;
   rangeobj.closetime = 0;
   rangeobj.high = 0.0;
   rangeobj.low = DBL_MAX;
   rangeobj.f_entry = false;
   rangeobj.f_high_breakout = false;
   rangeobj.f_low_breakout = false;


   int time_cycle = 86400;
   rangeobj.starttime = (lasttick.time - (lasttick.time % time_cycle)) + inpRangeStart * 60;
   //Print("start time: "+rangeobj.starttime);
   for(int i = 0; i < 8; i++) {
      MqlDateTime tmp;
      TimeToStruct(rangeobj.starttime, tmp);
      int dow = tmp.day_of_week;

      if(lasttick.time >= rangeobj.starttime || dow == 6 || dow == 0
            || (dow == 1 && !inpMonday)
            || (dow == 2 && !inpTuesday)
            || (dow == 3 && !inpWednesday)
            || (dow == 4 && !inpThursday)
            || (dow == 5 && !inpFriday)

        ) {
         rangeobj.starttime += time_cycle;
      }
   }


   rangeobj.endtime = rangeobj.starttime + inpRangeDuration * 60;

//calc range end
   for(int i = 0; i < 2; i++) {
      MqlDateTime tmp;
      TimeToStruct(rangeobj.endtime, tmp);
      int dow = tmp.day_of_week;

      if(dow == 6 || dow == 0) {
         rangeobj.endtime += time_cycle;
      }
   }
//calc range close
   if(inpRangeClose >= 0) {
      rangeobj.closetime = (rangeobj.endtime - (rangeobj.endtime % time_cycle)) + inpRangeClose * 60;
      for(int i = 0; i < 3; i++) {
         MqlDateTime tmp;
         TimeToStruct(rangeobj.closetime, tmp);
         int dow = tmp.day_of_week;

         if(rangeobj.closetime <= rangeobj.endtime || dow == 6 || dow == 0) {
            rangeobj.closetime += time_cycle;
         }
      }
   }
   DrawObjects();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawObjects() {
   ObjectDelete(NULL, "range start");
   if(rangeobj.starttime > 0) {
      ObjectCreate(NULL, "range start", OBJ_VLINE, 0, rangeobj.starttime, 0);

      ObjectSetString(NULL, "range start", OBJPROP_TOOLTIP, "start of the range \n" +
                      TimeToString(rangeobj.starttime, TIME_DATE | TIME_MINUTES));

      ObjectSetInteger(NULL, "range start", OBJPROP_COLOR, clrBlue);
      ObjectSetInteger(NULL, "range start", OBJPROP_WIDTH, 2);
      ObjectSetInteger(NULL, "range start", OBJPROP_BACK, true);
      ObjectSetString(NULL, "range start", OBJPROP_TEXT, "start of the range" );
   }


   ObjectDelete(NULL, "range end");
   if(rangeobj.endtime > 0) {
      ObjectCreate(NULL, "range end", OBJ_VLINE, 0, rangeobj.endtime, 0);

      ObjectSetString(NULL, "range end", OBJPROP_TOOLTIP, "end of the range \n" +
                      TimeToString(rangeobj.endtime, TIME_DATE | TIME_MINUTES));

      ObjectSetInteger(NULL, "range end", OBJPROP_COLOR, clrDarkBlue);
      ObjectSetInteger(NULL, "range end", OBJPROP_WIDTH, 2);
      ObjectSetInteger(NULL, "range end", OBJPROP_BACK, true);

   }

   ObjectDelete(NULL, "range close");
   if(rangeobj.closetime > 0) {
      ObjectCreate(NULL, "range close", OBJ_VLINE, 0, rangeobj.closetime, 0);

      ObjectSetString(NULL, "range close", OBJPROP_TOOLTIP, "close of the range \n" +
                      TimeToString(rangeobj.closetime, TIME_DATE | TIME_MINUTES));

      ObjectSetInteger(NULL, "range close", OBJPROP_COLOR, clrRed);
      ObjectSetInteger(NULL, "range close", OBJPROP_WIDTH, 2);
      ObjectSetInteger(NULL, "range close", OBJPROP_BACK, true);

   }



//high
   ObjectDelete(NULL, "range high");
   if(rangeobj.high > 0) {

      //Print("rangeobj.high >0");
      ObjectCreate(NULL, "range high", OBJ_TREND, 0
                   , rangeobj.starttime
                   , rangeobj.high
                   , rangeobj.endtime
                   , rangeobj.high);

      ObjectSetString(NULL, "range high", OBJPROP_TOOLTIP
                      , "high of the range \n" +
                      DoubleToString(rangeobj.high, _Digits)) ;

      ObjectSetInteger(NULL, "range high", OBJPROP_COLOR, clrBlue);
      ObjectSetInteger(NULL, "range high", OBJPROP_WIDTH, 2);
      ObjectSetInteger(NULL, "range high", OBJPROP_BACK, true);

      //=====
      ObjectCreate(NULL, "range high", OBJ_TREND, 0
                   , rangeobj.endtime
                   , rangeobj.high
                   , inpRangeClose >= 0 ? rangeobj.closetime : INT_MAX
                   , rangeobj.high);

      ObjectSetString(NULL, "range high", OBJPROP_TOOLTIP
                      , "high of the range \n" +
                      DoubleToString(rangeobj.high, _Digits)) ;

      ObjectSetInteger(NULL, "range high", OBJPROP_COLOR, clrBlue);
      //ObjectSetInteger(NULL,"range high",OBJPROP_WIDTH,2);
      ObjectSetInteger(NULL, "range high", OBJPROP_BACK, true);
      ObjectSetInteger(NULL, "range high", OBJPROP_STYLE, STYLE_DOT);

   }
//Print("rangeobj.low:"+rangeobj.low);


//low
   ObjectDelete(NULL, "range low");
   if(rangeobj.low < DBL_MAX) { // <DBL_MAX

      //Print("rangeobj.low<DBL_MAX");
      ObjectCreate(NULL, "range low", OBJ_TREND, 0
                   , rangeobj.starttime
                   , rangeobj.low
                   , rangeobj.endtime
                   , rangeobj.low);

      ObjectSetString(NULL, "range low", OBJPROP_TOOLTIP
                      , "low of the range \n" +
                      DoubleToString(rangeobj.low, _Digits)) ;

      ObjectSetInteger(NULL, "range low", OBJPROP_COLOR, clrBlue);
      ObjectSetInteger(NULL, "range low", OBJPROP_WIDTH, 2);
      ObjectSetInteger(NULL, "range low", OBJPROP_BACK, true);



      ObjectCreate(NULL, "range low", OBJ_TREND, 0
                   , rangeobj.endtime
                   , rangeobj.low
                   , inpRangeClose >= 0 ? rangeobj.closetime : INT_MAX
                   , rangeobj.low);

      ObjectSetString(NULL, "range low", OBJPROP_TOOLTIP
                      , "low of the range \n" +
                      DoubleToString(rangeobj.low, _Digits)) ;

      ObjectSetInteger(NULL, "range low", OBJPROP_COLOR, clrBlue);
      ObjectSetInteger(NULL, "range low", OBJPROP_WIDTH, 2);
      ObjectSetInteger(NULL, "range low", OBJPROP_BACK, true);

   }

   ChartRedraw();


}
//+------------------------------------------------------------------+
int CountOpenPositions() {
   int counter = 0;
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--) {

      ulong ticket = PositionGetTicket(i);

      if(ticket <= 0) {
         Print("failed to get pos ticket");
         return -1;
      }
      if(!PositionSelectByTicket(ticket)) {
         Print("failed to select position by ticket");
         return -1;

      }

      ulong magicnummber;
      if(!PositionGetInteger(POSITION_MAGIC, magicnummber)) {
         Print("failed to GET position MAGICNUMBER");
         return -1;
      }
      if(inpMagic == magicnummber) {
         counter++;
      }
   }


   return counter;

}
//+------------------------------------------------------------------+
